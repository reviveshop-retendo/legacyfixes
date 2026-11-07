//
//  LFEngine.m
//  LegacyFixes shared runtime
//
//  This file is compiled into every per-app tweak. It intentionally uses
//  only APIs that exist on iOS 6 (no os_log, no UIAlertController hard
//  references, no blocks-based NSURLSession fiddling).
//

#import "LFEngine.h"

#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>
#import <sys/stat.h>

static NSDictionary *gConfig = nil;
static NSString *gBundleID = nil;
static NSString *gLogPath = nil;
static NSLock *gLogLock = nil;

static NSString *gSpoofedSystemVersion = nil;
static NSString *gUserAgent = nil;
static NSArray *gAlertPatterns = nil;
static BOOL gBypassPinning = NO;
static NSDictionary *gInfoOverrides = nil;
static NSDictionary *gMergedInfoDictionary = nil;

#pragma mark - Logging

static NSString *LFLogDirectory(void) {
    return @"/var/mobile/Library/Logs/LegacyFixes";
}

static void LFEnsureLogPath(void) {
    if (gLogPath) {
        return;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = LFLogDirectory();
    NSError *error = nil;

    if (![fm createDirectoryAtPath:dir
       withIntermediateDirectories:YES
                        attributes:nil
                             error:&error]) {
        // Sandboxed/odd setups: /tmp is always writable.
        dir = @"/tmp";
    }

    NSString *name = [NSString stringWithFormat:@"%@.log", gBundleID ?: @"unknown"];
    gLogPath = [[dir stringByAppendingPathComponent:name] copy];
}

void LFLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSLog(@"[LegacyFixes] %@", message);

    LFEnsureLogPath();
    if (!gLogPath) {
        return;
    }

    if (!gLogLock) {
        gLogLock = [[NSLock alloc] init];
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *line = [NSString stringWithFormat:@"%@ %@\n",
                      [formatter stringFromDate:[NSDate date]], message];

    [gLogLock lock];
    @try {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSDictionary *attributes = [fm attributesOfItemAtPath:gLogPath error:NULL];
        if (attributes && [attributes fileSize] > 512 * 1024) {
            [fm removeItemAtPath:gLogPath error:NULL];
        }
        if (![fm fileExistsAtPath:gLogPath]) {
            [fm createFileAtPath:gLogPath contents:nil attributes:nil];
        }
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:gLogPath];
        [handle seekToEndOfFile];
        [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
    } @catch (NSException *exception) {
        NSLog(@"[LegacyFixes] log write failed: %@", exception);
    } @finally {
        [gLogLock unlock];
    }
}

NSString *LFLogPath(void) {
    LFEnsureLogPath();
    return gLogPath;
}

#pragma mark - Configuration

static NSDictionary *LFReadPlist(NSString *path) {
    if (!path) {
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        return nil;
    }
    id object = [NSPropertyListSerialization propertyListWithData:data
                                                          options:NSPropertyListImmutable
                                                           format:NULL
                                                            error:NULL];
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}

static NSMutableDictionary *LFDeepMerge(NSDictionary *base, NSDictionary *override) {
    NSMutableDictionary *result = base ? [base mutableCopy] : [NSMutableDictionary dictionary];
    for (id key in override) {
        id oldValue = result[key];
        id newValue = override[key];
        if ([oldValue isKindOfClass:[NSDictionary class]] &&
            [newValue isKindOfClass:[NSDictionary class]]) {
            result[key] = LFDeepMerge(oldValue, newValue);
        } else {
            result[key] = newValue;
        }
    }
    return result;
}

NSDictionary *LFConfig(void) {
    return gConfig;
}

id LFConfigValue(NSString *key) {
    return gConfig[key];
}

#pragma mark - Generic compatibility hooks

static NSString *(*LFOriginalSystemVersion)(id, SEL);

static NSString *LFSystemVersion(id self, SEL _cmd) {
    if (gSpoofedSystemVersion.length > 0) {
        return gSpoofedSystemVersion;
    }
    return LFOriginalSystemVersion ? LFOriginalSystemVersion(self, _cmd) : nil;
}

static void LFInstallSystemVersionSpoof(void) {
    MSHookMessageEx([UIDevice class],
                    @selector(systemVersion),
                    (IMP)LFSystemVersion,
                    (IMP *)&LFOriginalSystemVersion);
    LFLog(@"spoofing -[UIDevice systemVersion] as %@", gSpoofedSystemVersion);
}

static void (*LFOriginalSetValue)(id, SEL, id, id);

static void LFSetValue(id self, SEL _cmd, id value, id field) {
    if (gUserAgent.length > 0 &&
        [field isKindOfClass:[NSString class]] &&
        [(NSString *)field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
        value = gUserAgent;
    }
    if (LFOriginalSetValue) {
        LFOriginalSetValue(self, _cmd, value, field);
    }
}

static void (*LFOriginalSetAllHeaders)(id, SEL, id);

static void LFSetAllHeaders(id self, SEL _cmd, NSDictionary *headers) {
    if (gUserAgent.length > 0 && [headers isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *copy = [headers mutableCopy];
        for (NSString *key in [headers allKeys]) {
            if ([key isKindOfClass:[NSString class]] &&
                [key caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
                copy[key] = gUserAgent;
            }
        }
        headers = copy;
    }
    if (LFOriginalSetAllHeaders) {
        LFOriginalSetAllHeaders(self, _cmd, headers);
    }
}

static void LFInstallUserAgentOverride(void) {
    MSHookMessageEx([NSMutableURLRequest class],
                    @selector(setValue:forHTTPHeaderField:),
                    (IMP)LFSetValue,
                    (IMP *)&LFOriginalSetValue);
    MSHookMessageEx([NSMutableURLRequest class],
                    @selector(setAllHTTPHeaderFields:),
                    (IMP)LFSetAllHeaders,
                    (IMP *)&LFOriginalSetAllHeaders);
    LFLog(@"overriding User-Agent as %@", gUserAgent);
}

static BOOL LFAlertMatchesPatterns(NSString *title, NSString *message) {
    if (gAlertPatterns.count == 0) {
        return NO;
    }

    NSString *text = [NSString stringWithFormat:@"%@ %@", title ?: @"", message ?: @""];
    for (id pattern in gAlertPatterns) {
        if (![pattern isKindOfClass:[NSString class]] || [(NSString *)pattern length] == 0) {
            continue;
        }
        if ([text rangeOfString:pattern
                        options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static void (*LFOriginalAlertShow)(id, SEL);

static void LFAlertShow(id self, SEL _cmd) {
    BOOL suppress = NO;
    NSString *title = nil;
    NSString *message = nil;

    @try {
        UIAlertView *alert = (UIAlertView *)self;
        title = alert.title;
        message = alert.message;
        suppress = LFAlertMatchesPatterns(title, message);
    } @catch (NSException *exception) {
        suppress = NO;
    }

    if (suppress) {
        LFLog(@"suppressed UIAlertView: %@ / %@", title, message);
        return;
    }

    if (LFOriginalAlertShow) {
        LFOriginalAlertShow(self, _cmd);
    }
}

static void (*LFOriginalPresentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));

static void LFPresentViewController(id self,
                                    SEL _cmd,
                                    UIViewController *controller,
                                    BOOL animated,
                                    void (^completion)(void)) {
    if (controller &&
        [controller isKindOfClass:NSClassFromString(@"UIAlertController")]) {
        UIAlertController *alert = (UIAlertController *)controller;
        if (LFAlertMatchesPatterns(alert.title, alert.message)) {
            LFLog(@"suppressed UIAlertController: %@ / %@", alert.title, alert.message);
            return;
        }
    }

    if (LFOriginalPresentViewController) {
        LFOriginalPresentViewController(self, _cmd, controller, animated, completion);
    }
}

static void LFInstallAlertSuppression(void) {
    MSHookMessageEx([UIAlertView class],
                    @selector(show),
                    (IMP)LFAlertShow,
                    (IMP *)&LFOriginalAlertShow);

    if (NSClassFromString(@"UIAlertController")) {
        MSHookMessageEx([UIViewController class],
                        @selector(presentViewController:animated:completion:),
                        (IMP)LFPresentViewController,
                        (IMP *)&LFOriginalPresentViewController);
    }

    LFLog(@"suppressing alerts matching: %@", [gAlertPatterns componentsJoinedByString:@", "]);
}

static OSStatus (*LFOriginalSecTrustEvaluate)(SecTrustRef, SecTrustResultType *);

static OSStatus LFSecTrustEvaluate(SecTrustRef trust, SecTrustResultType *result) {
    if (gBypassPinning) {
        if (result) {
            *result = kSecTrustResultProceed;
        }
        return errSecSuccess;
    }
    return LFOriginalSecTrustEvaluate ? LFOriginalSecTrustEvaluate(trust, result) : errSecSuccess;
}

static void LFInstallCertificatePinningBypass(void) {
    void *symbol = dlsym(RTLD_DEFAULT, "SecTrustEvaluate");
    if (!symbol) {
        LFLog(@"could not find SecTrustEvaluate; pinning bypass disabled");
        return;
    }
    MSHookFunction(symbol, (void *)LFSecTrustEvaluate, (void **)&LFOriginalSecTrustEvaluate);
    LFLog(@"certificate pinning bypass enabled");
}

#pragma mark - Info.plist overrides

//
// Some legacy apps gate features on their own Info.plist version fields
// (Facebook's FBAppVersion/FBPlatformVersion, Messenger, etc.). Editing the
// signed app bundle is fragile and breaks code-signing checks, so override the
// values in-process instead. This is how the public Facebook v11 fix is applied
// without touching the .app.
//
// Config:
//   <key>InfoPlistOverrides</key>
//   <dict>
//       <key>FBAppVersion</key><string>544.0.0.57.70</string>
//   </dict>
//

static id (*LFOriginalInfoPlistObject)(id, SEL, NSString *);
static NSDictionary *(*LFOriginalInfoDictionary)(id, SEL);
static CFDictionaryRef (*LFOriginalCFBundleGetInfoDictionary)(CFBundleRef);
static CFTypeRef (*LFOriginalCFBundleGetValueForInfoDictionaryKey)(CFBundleRef, CFStringRef);
static CFMutableDictionaryRef gMergedCFInfoDictionary = NULL;
static NSLock *gInfoLock = nil;

static BOOL LFIsMainBundle(id bundle) {
    return bundle != nil && bundle == [NSBundle mainBundle];
}

static BOOL LFIsMainCFBundle(CFBundleRef bundle) {
    return bundle != NULL && bundle == CFBundleGetMainBundle();
}

static void LFBuildMergedCFInfoDictionary(CFDictionaryRef info) {
    if (gMergedCFInfoDictionary) {
        return;
    }
    if (info) {
        gMergedCFInfoDictionary = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, info);
    } else {
        gMergedCFInfoDictionary = CFDictionaryCreateMutable(
            kCFAllocatorDefault, 0,
            &kCFTypeDictionaryKeyCallBacks,
            &kCFTypeDictionaryValueCallBacks);
    }
    for (NSString *key in gInfoOverrides) {
        CFDictionarySetValue(gMergedCFInfoDictionary,
                             (__bridge CFStringRef)key,
                             (__bridge CFTypeRef)gInfoOverrides[key]);
    }
}

static CFDictionaryRef LFCFBundleGetInfoDictionary(CFBundleRef bundle) {
    CFDictionaryRef info = LFOriginalCFBundleGetInfoDictionary
                               ? LFOriginalCFBundleGetInfoDictionary(bundle)
                               : NULL;
    if (!LFIsMainCFBundle(bundle)) {
        return info;
    }

    [gInfoLock lock];
    LFBuildMergedCFInfoDictionary(info);
    CFDictionaryRef merged = gMergedCFInfoDictionary;
    [gInfoLock unlock];
    return merged;
}

static CFTypeRef LFCFBundleGetValueForInfoDictionaryKey(CFBundleRef bundle, CFStringRef key) {
    if (LFIsMainCFBundle(bundle) && key) {
        NSString *stringKey = (__bridge NSString *)key;
        id override = gInfoOverrides[stringKey];
        if (override) {
            return (__bridge CFTypeRef)override;
        }
    }
    return LFOriginalCFBundleGetValueForInfoDictionaryKey
               ? LFOriginalCFBundleGetValueForInfoDictionaryKey(bundle, key)
               : NULL;
}

static id LFInfoPlistObject(id self, SEL _cmd, NSString *key) {
    if (LFIsMainBundle(self) && [key isKindOfClass:[NSString class]]) {
        id override = gInfoOverrides[key];
        if (override) {
            return override;
        }
    }
    return LFOriginalInfoPlistObject ? LFOriginalInfoPlistObject(self, _cmd, key) : nil;
}

static NSDictionary *LFInfoDictionary(id self, SEL _cmd) {
    NSDictionary *info = LFOriginalInfoDictionary
                             ? LFOriginalInfoDictionary(self, _cmd)
                             : nil;

    if (!LFIsMainBundle(self)) {
        return info;
    }

    [gInfoLock lock];
    if (!gMergedInfoDictionary) {
        NSMutableDictionary *merged = info ? [info mutableCopy]
                                           : [NSMutableDictionary dictionary];
        [merged addEntriesFromDictionary:gInfoOverrides];
        gMergedInfoDictionary = [merged copy];
    }
    NSDictionary *result = gMergedInfoDictionary;
    [gInfoLock unlock];
    return result;
}

static void LFInstallInfoPlistOverrides(void) {
    if (!gInfoLock) {
        gInfoLock = [[NSLock alloc] init];
    }

    MSHookMessageEx([NSBundle class],
                    @selector(objectForInfoDictionaryKey:),
                    (IMP)LFInfoPlistObject,
                    (IMP *)&LFOriginalInfoPlistObject);
    MSHookMessageEx([NSBundle class],
                    @selector(infoDictionary),
                    (IMP)LFInfoDictionary,
                    (IMP *)&LFOriginalInfoDictionary);

    // Some legacy apps read their version straight out of CoreFoundation
    // (CFBundleGetValueForInfoDictionaryKey / CFBundleGetInfoDictionary)
    // instead of going through NSBundle, so hook both paths too.
    void *getInfoDictionary = dlsym(RTLD_DEFAULT, "CFBundleGetInfoDictionary");
    if (getInfoDictionary) {
        MSHookFunction(getInfoDictionary,
                       (void *)LFCFBundleGetInfoDictionary,
                       (void **)&LFOriginalCFBundleGetInfoDictionary);
    } else {
        LFLog(@"CFBundleGetInfoDictionary not found");
    }

    void *getValue = dlsym(RTLD_DEFAULT, "CFBundleGetValueForInfoDictionaryKey");
    if (getValue) {
        MSHookFunction(getValue,
                       (void *)LFCFBundleGetValueForInfoDictionaryKey,
                       (void **)&LFOriginalCFBundleGetValueForInfoDictionaryKey);
    } else {
        LFLog(@"CFBundleGetValueForInfoDictionaryKey not found");
    }

    LFLog(@"overriding Info.plist keys: %@",
          [[gInfoOverrides allKeys] componentsJoinedByString:@", "]);
}

#pragma mark - Config-driven method patches

static void LFDumpClassList(NSString *filter) {
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    if (!classes) {
        return;
    }

    LFLog(@"=== class dump start (%u classes) ===", count);
    for (unsigned int i = 0; i < count; i++) {
        NSString *name = NSStringFromClass(classes[i]);
        if (filter.length > 0 &&
            [name rangeOfString:filter options:NSCaseInsensitiveSearch].location == NSNotFound) {
            continue;
        }
        LFLog(@"class %@", name);
    }
    LFLog(@"=== class dump end ===");
    free(classes);
}

static void LFDumpMethodsForClass(NSString *className) {
    Class cls = objc_getClass([className UTF8String]);
    if (!cls) {
        LFLog(@"cannot dump %@: class not found", className);
        return;
    }

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        LFLog(@"  -[%@ %@] %s", className,
              NSStringFromSelector(method_getName(methods[i])),
              method_getTypeEncoding(methods[i]));
    }
    free(methods);

    Method *classMethods = class_copyMethodList(object_getClass(cls), &count);
    for (unsigned int i = 0; i < count; i++) {
        LFLog(@"  +[%@ %@] %s", className,
              NSStringFromSelector(method_getName(classMethods[i])),
              method_getTypeEncoding(classMethods[i]));
    }
    free(classMethods);
}

static BOOL LFIsFalse(id value) {
    return [value isKindOfClass:[NSNumber class]] && ![value boolValue];
}

static void LFInstallPatchRule(NSDictionary *rule) {
    NSString *className = rule[@"Class"];
    NSString *selectorName = rule[@"Selector"];
    if (![className isKindOfClass:[NSString class]] ||
        ![selectorName isKindOfClass:[NSString class]]) {
        LFLog(@"skipping invalid patch rule: %@", rule);
        return;
    }

    BOOL isClassMethod = [rule[@"ClassMethod"] boolValue];
    BOOL shouldLog = [rule[@"Log"] boolValue];
    id returnValue = rule[@"Return"];
    BOOL callOriginal = [rule[@"Original"] boolValue] || (returnValue == nil);

    Class cls = objc_getClass([className UTF8String]);
    if (!cls) {
        LFLog(@"skipping patch %@[%@ %@]: class not found",
              isClassMethod ? @"+" : @"-", className, selectorName);
        return;
    }

    SEL selector = NSSelectorFromString(selectorName);
    Method method = isClassMethod ? class_getClassMethod(cls, selector)
                                  : class_getInstanceMethod(cls, selector);
    if (!method) {
        LFLog(@"skipping patch %@[%@ %@]: method not found",
              isClassMethod ? @"+" : @"-", className, selectorName);
        return;
    }

    if (method_getNumberOfArguments(method) != 2) {
        // V1 only supports zero-argument methods. There is no safe, portable
        // way to forward arbitrary scalar/float args from a block on armv7.
        LFLog(@"skipping patch %@[%@ %@]: only zero-argument methods are supported",
              isClassMethod ? @"+" : @"-", className, selectorName);
        return;
    }

    char *returnType = method_copyReturnType(method);
    char type = returnType ? returnType[0] : '\0';
    free(returnType);

    if (returnValue == [NSNull null]) {
        returnValue = nil;
    }

    Class hookClass = isClassMethod ? object_getClass(cls) : cls;
    __block IMP originalIMP = NULL;
    IMP replacement = NULL;

    if (type == 'v') {
        replacement = imp_implementationWithBlock(^(id self) {
            if (shouldLog) {
                LFLog(@"[patch] -[%@ %@]", className, selectorName);
            }
            if (callOriginal && originalIMP) {
                ((void (*)(id, SEL))originalIMP)(self, selector);
            }
        });
    } else if (type == 'B' || type == 'c') {
        BOOL value = [returnValue respondsToSelector:@selector(boolValue)]
                         ? [returnValue boolValue] : NO;
        replacement = imp_implementationWithBlock(^BOOL(id self) {
            if (shouldLog) {
                LFLog(@"[patch] -[%@ %@] -> %d", className, selectorName, (int)value);
            }
            if (callOriginal && originalIMP) {
                return ((BOOL (*)(id, SEL))originalIMP)(self, selector);
            }
            return value;
        });
    } else if (type == 'i' || type == 's' || type == 'l' || type == 'q' ||
               type == 'C' || type == 'S' || type == 'I' || type == 'L' || type == 'Q') {
        NSInteger value = [returnValue respondsToSelector:@selector(integerValue)]
                              ? [returnValue integerValue] : 0;
        replacement = imp_implementationWithBlock(^NSInteger(id self) {
            if (shouldLog) {
                LFLog(@"[patch] -[%@ %@] -> %ld", className, selectorName, (long)value);
            }
            if (callOriginal && originalIMP) {
                return ((NSInteger (*)(id, SEL))originalIMP)(self, selector);
            }
            return value;
        });
    } else if (type == 'f' || type == 'd') {
        double value = [returnValue respondsToSelector:@selector(doubleValue)]
                           ? [returnValue doubleValue] : 0.0;
        replacement = imp_implementationWithBlock(^double(id self) {
            if (shouldLog) {
                LFLog(@"[patch] -[%@ %@] -> %f", className, selectorName, value);
            }
            if (callOriginal && originalIMP) {
                return ((double (*)(id, SEL))originalIMP)(self, selector);
            }
            return value;
        });
    } else if (type == '@' || type == '#') {
        id value = returnValue;
        replacement = imp_implementationWithBlock(^id(id self) {
            if (shouldLog) {
                LFLog(@"[patch] -[%@ %@] -> %@", className, selectorName, value);
            }
            if (callOriginal && originalIMP) {
                return ((id (*)(id, SEL))originalIMP)(self, selector);
            }
            return value;
        });
    } else {
        LFLog(@"skipping patch %@[%@ %@]: unsupported return type '%c'",
              isClassMethod ? @"+" : @"-", className, selectorName, type);
        return;
    }

    if (!replacement) {
        return;
    }

    MSHookMessageEx(hookClass, selector, replacement, &originalIMP);
    LFLog(@"installed patch %@[%@ %@] (%@)",
          isClassMethod ? @"+" : @"-", className, selectorName,
          callOriginal ? @"log only" : [NSString stringWithFormat:@"-> %@", returnValue]);
}

static void LFInstallPatchRules(NSArray *rules) {
    if (![rules isKindOfClass:[NSArray class]]) {
        return;
    }

    for (id rule in rules) {
        if (![rule isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        if (LFIsFalse(rule[@"Enabled"])) {
            continue;
        }
        @try {
            LFInstallPatchRule(rule);
        } @catch (NSException *exception) {
            LFLog(@"patch rule threw: %@ (%@)", rule, exception);
        }
    }
}

#pragma mark - Bootstrap

static void LFApplyConfiguration(void) {
    if (LFIsFalse(gConfig[@"Enabled"])) {
        LFLog(@"disabled by configuration; doing nothing");
        return;
    }

    NSString *spoofedVersion = gConfig[@"SystemVersion"];
    if ([spoofedVersion isKindOfClass:[NSString class]] && spoofedVersion.length > 0) {
        gSpoofedSystemVersion = [spoofedVersion copy];
        LFInstallSystemVersionSpoof();
    }

    NSDictionary *infoOverrides = gConfig[@"InfoPlistOverrides"];
    if ([infoOverrides isKindOfClass:[NSDictionary class]] && infoOverrides.count > 0) {
        gInfoOverrides = [infoOverrides copy];
        LFInstallInfoPlistOverrides();
    }

    NSString *userAgent = gConfig[@"UserAgent"];
    if ([userAgent isKindOfClass:[NSString class]] && userAgent.length > 0) {
        gUserAgent = [userAgent copy];
        LFInstallUserAgentOverride();
    }

    NSArray *patterns = gConfig[@"SuppressAlerts"];
    if ([patterns isKindOfClass:[NSArray class]] && patterns.count > 0) {
        gAlertPatterns = [patterns copy];
        LFInstallAlertSuppression();
    }

    if ([gConfig[@"BypassCertPinning"] boolValue]) {
        gBypassPinning = YES;
        LFInstallCertificatePinningBypass();
    }

    if ([gConfig[@"DumpClasses"] boolValue]) {
        NSString *filter = gConfig[@"DumpClassesFilter"];
        LFDumpClassList([filter isKindOfClass:[NSString class]] ? filter : nil);
    }

    id classesToDump = gConfig[@"DumpMethodsForClasses"];
    if ([classesToDump isKindOfClass:[NSArray class]]) {
        for (id className in classesToDump) {
            if ([className isKindOfClass:[NSString class]]) {
                LFDumpMethodsForClass(className);
            }
        }
    }

    LFInstallPatchRules(gConfig[@"Patches"]);
}

static void LFStartLocked(NSString *bundleID) {
    gBundleID = [bundleID copy];
    gLogLock = [[NSLock alloc] init];
    LFEnsureLogPath();

    NSString *safeBundle = bundleID ?: @"unknown";
    NSString *defaultsPath = [NSString stringWithFormat:
        @"/Library/Application Support/LegacyFixes/Patches/%@.plist", safeBundle];
    NSString *userPath = [NSString stringWithFormat:
        @"/var/mobile/Library/Preferences/com.legacyfixes.%@.plist", safeBundle];

    NSDictionary *defaults = LFReadPlist(defaultsPath);
    NSDictionary *user = LFReadPlist(userPath);

    gConfig = LFDeepMerge(defaults ?: @{}, user ?: @{});

    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    LFLog(@"=== LegacyFixes %@ ===", safeBundle);
    LFLog(@"device iOS %@, app %@ %@",
          [[UIDevice currentDevice] systemVersion],
          info[@"CFBundleShortVersionString"] ?: @"?",
          info[@"CFBundleVersion"] ?: @"?");
    LFLog(@"defaults: %@ (%@)", defaultsPath, defaults ? @"found" : @"missing");
    LFLog(@"user prefs: %@ (%@)", userPath, user ? @"found" : @"missing");
    LFLog(@"log file: %@", gLogPath);

    LFApplyConfiguration();

    if (gInfoOverrides.count > 0) {
        for (NSString *key in gInfoOverrides) {
            LFLog(@"effective Info.plist[%@] = %@",
                  key,
                  [[NSBundle mainBundle] objectForInfoDictionaryKey:key] ?: @"(nil)");
        }
    }

    LFLog(@"=== ready ===");
}

void LFStart(NSString *bundleID) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        LFStartLocked(bundleID);
    });
}
