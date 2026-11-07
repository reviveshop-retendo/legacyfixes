//
//  TNClient.m
//  TextNow Legacy
//
//  A small client for the same web API the TextNow web app uses. It is not
//  affiliated with TextNow and only talks to www.textnow.com over HTTPS.
//

#import "TNClient.h"
#import "TNKeychain.h"
#import "TNModels.h"

static NSString * const TNCookieKeychainAccount = @"session-cookies";
static NSString * const TNUserAgent =
    @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    @"AppleWebKit/537.36 (KHTML, like Gecko) "
    @"Chrome/120.0.0.0 Safari/537.36";

@interface TNClient ()

@property (nonatomic, copy, readwrite) NSString *username;
@property (nonatomic, assign, readwrite) BOOL isAuthenticated;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, copy) NSString *xsrfToken;
@property (nonatomic, copy) NSString *persistedCookieSignature;

@end

@implementation TNClient

+ (instancetype)sharedClient {
    static TNClient *client = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        client = [[TNClient alloc] init];
    });
    return client;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.HTTPCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        configuration.HTTPShouldSetCookies = YES;
        configuration.timeoutIntervalForRequest = 30.0;
        configuration.timeoutIntervalForResource = 60.0;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        _session = [NSURLSession sessionWithConfiguration:configuration];

        [NSHTTPCookieStorage sharedHTTPCookieStorage].cookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;

        _username = [[NSUserDefaults standardUserDefaults] stringForKey:TNDefaultsUsernameKey];
        [self restoreCookies];
        _xsrfToken = [[self cookieNamed:@"XSRF-TOKEN"] value];
        _isAuthenticated = (_username.length > 0 && [self cookieNamed:@"connect.sid"].value.length > 0);
    }
    return self;
}

#pragma mark - Cookies

- (NSArray *)textNowCookies {
    NSMutableArray *cookies = [NSMutableArray array];
    for (NSHTTPCookie *cookie in [NSHTTPCookieStorage sharedHTTPCookieStorage].cookies) {
        NSString *domain = cookie.domain.lowercaseString;
        if ([domain rangeOfString:@"textnow.com"].location != NSNotFound) {
            [cookies addObject:cookie];
        }
    }
    return cookies;
}

- (NSHTTPCookie *)cookieNamed:(NSString *)name {
    for (NSHTTPCookie *cookie in [self textNowCookies]) {
        if ([cookie.name caseInsensitiveCompare:name] == NSOrderedSame) {
            return cookie;
        }
    }
    return nil;
}

- (void)updateCSRFToken {
    NSHTTPCookie *cookie = [self cookieNamed:@"XSRF-TOKEN"];
    if (cookie.value.length) {
        self.xsrfToken = cookie.value;
    }
}

- (void)persistCookies {
    NSMutableArray *items = [NSMutableArray array];
    NSMutableArray *signatureParts = [NSMutableArray array];
    for (NSHTTPCookie *cookie in [self textNowCookies]) {
        if (!cookie.name.length || !cookie.value.length) {
            continue;
        }
        NSMutableDictionary *item = [NSMutableDictionary dictionary];
        item[@"Name"] = cookie.name;
        item[@"Value"] = cookie.value;
        item[@"Domain"] = cookie.domain ?: @"www.textnow.com";
        item[@"Path"] = cookie.path ?: @"/";
        item[@"Secure"] = @(cookie.isSecure);
        if (cookie.expiresDate) {
            item[@"Expires"] = @([cookie.expiresDate timeIntervalSince1970]);
        }
        [items addObject:item];
        [signatureParts addObject:[NSString stringWithFormat:@"%@=%@;%@;%@",
                                   cookie.name, cookie.value,
                                   cookie.domain ?: @"", cookie.path ?: @""]];
    }

    // Polling calls this after every request. Writing to the Keychain every few
    // seconds is slow on an iPhone 4, so skip it while the cookie jar is stable.
    NSString *signature = [signatureParts componentsJoinedByString:@"|"];
    if ([signature isEqualToString:self.persistedCookieSignature]) {
        return;
    }

    NSData *data = [NSJSONSerialization dataWithJSONObject:items options:0 error:NULL];
    if (data && [TNKeychain setData:data forAccount:TNCookieKeychainAccount]) {
        self.persistedCookieSignature = signature;
    }
}

- (void)restoreCookies {
    NSData *data = [TNKeychain dataForAccount:TNCookieKeychainAccount];
    if (!data.length) {
        return;
    }

    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if (![object isKindOfClass:[NSArray class]]) {
        return;
    }

    for (NSDictionary *item in (NSArray *)object) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *name = TNString(item[@"Name"]);
        NSString *value = TNString(item[@"Value"]);
        if (!name.length || !value.length) {
            continue;
        }

        NSMutableDictionary *properties = [NSMutableDictionary dictionary];
        properties[NSHTTPCookieName] = name;
        properties[NSHTTPCookieValue] = value;
        properties[NSHTTPCookieDomain] = TNString(item[@"Domain"]) ?: @"www.textnow.com";
        properties[NSHTTPCookiePath] = TNString(item[@"Path"]) ?: @"/";
        properties[NSHTTPCookieVersion] = @0;
        if ([item[@"Secure"] boolValue]) {
            properties[NSHTTPCookieSecure] = @"TRUE";
        }
        NSNumber *expires = item[@"Expires"];
        if ([expires isKindOfClass:[NSNumber class]] && [expires doubleValue] > 0) {
            properties[NSHTTPCookieExpires] = [NSDate dateWithTimeIntervalSince1970:[expires doubleValue]];
        }

        NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:properties];
        if (cookie) {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
        }
    }
}

- (void)clearCookies {
    for (NSHTTPCookie *cookie in [self textNowCookies]) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
    }
    [TNKeychain deleteAccount:TNCookieKeychainAccount];
    self.xsrfToken = nil;
    self.persistedCookieSignature = nil;
}

#pragma mark - Requests

- (NSString *)queryStringFromParameters:(NSDictionary *)parameters {
    if (!parameters.count) {
        return @"";
    }
    NSArray *keys = [[parameters allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *key in keys) {
        id value = parameters[key];
        if (value == nil || value == [NSNull null]) {
            continue;
        }
        [parts addObject:[NSString stringWithFormat:@"%@=%@",
                          TNPercentEncode(key), TNPercentEncode([value description])]];
    }
    return [parts componentsJoinedByString:@"&"];
}

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                      path:(NSString *)path
                                     query:(NSDictionary *)query
                                      body:(NSData *)body
                               contentType:(NSString *)contentType
                                    isAPI:(BOOL)isAPI {
    NSString *urlString = [TNBaseURL stringByAppendingString:path];
    NSString *queryString = [self queryStringFromParameters:query];
    if (queryString.length) {
        urlString = [urlString stringByAppendingFormat:@"?%@", queryString];
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        return nil;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                          cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                      timeoutInterval:30.0];
    request.HTTPMethod = method;
    [request setValue:TNUserAgent forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"en-US,en;q=0.9" forHTTPHeaderField:@"Accept-Language"];
    [request setValue:@"https://www.textnow.com/login" forHTTPHeaderField:@"Referer"];
    [request setValue:@"https://www.textnow.com" forHTTPHeaderField:@"Origin"];

    if (isAPI) {
        [request setValue:@"application/json, text/javascript, */*; q=0.01" forHTTPHeaderField:@"Accept"];
        [request setValue:@"XMLHttpRequest" forHTTPHeaderField:@"X-Requested-With"];
        if (self.xsrfToken.length) {
            [request setValue:self.xsrfToken forHTTPHeaderField:@"X-XSRF-TOKEN"];
        }
    } else {
        [request setValue:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
       forHTTPHeaderField:@"Accept"];
    }

    if (body.length) {
        request.HTTPBody = body;
        [request setValue:(contentType ?: @"application/octet-stream") forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)body.length]
       forHTTPHeaderField:@"Content-Length"];
    }

    return request;
}

- (NSError *)networkErrorFromError:(NSError *)error {
    NSString *description = @"Could not reach TextNow. Check your internet connection and try again.";
    switch (error.code) {
        case NSURLErrorNotConnectedToInternet:
            description = @"There is no internet connection.";
            break;
        case NSURLErrorTimedOut:
            description = @"TextNow took too long to respond. Try again.";
            break;
        case NSURLErrorNetworkConnectionLost:
            description = @"The connection to TextNow was lost. Try again.";
            break;
        case NSURLErrorSecureConnectionFailed:
        case NSURLErrorServerCertificateUntrusted:
        case NSURLErrorServerCertificateHasBadDate:
        case NSURLErrorServerCertificateNotYetValid:
            description = @"Could not establish a secure connection to TextNow. Check the device date and time, then try again.";
            break;
        default:
            break;
    }

    return [NSError errorWithDomain:TNErrorDomain
                               code:error.code
                           userInfo:@{
                               NSLocalizedDescriptionKey: description,
                               NSUnderlyingErrorKey: error,
                           }];
}

- (NSError *)errorForStatus:(NSInteger)status json:(id)json data:(NSData *)data {
    NSString *code = nil;
    NSString *serverMessage = nil;

    if ([json isKindOfClass:[NSDictionary class]]) {
        code = TNString(json[@"error_code"]) ?: TNString(json[@"error"]) ?: TNString(json[@"code"]);
        serverMessage = TNString(json[@"message"]) ?: TNString(json[@"error_description"]);
        if (!serverMessage.length) {
            id errors = json[@"errors"];
            if ([errors isKindOfClass:[NSArray class]]) {
                serverMessage = [errors componentsJoinedByString:@"\n"];
            } else if ([errors isKindOfClass:[NSDictionary class]]) {
                NSMutableArray *parts = [NSMutableArray array];
                for (id value in [errors allValues]) {
                    if ([value isKindOfClass:[NSArray class]]) {
                        [parts addObjectsFromArray:value];
                    } else {
                        [parts addObject:[value description]];
                    }
                }
                serverMessage = [parts componentsJoinedByString:@"\n"];
            }
        }
    }

    if (!serverMessage.length && data.length) {
        serverMessage = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (serverMessage.length > 240) {
            serverMessage = [serverMessage substringToIndex:240];
        }
    }

    NSString *description = nil;
    if (status == 401) {
        if ([code isEqualToString:@"INVALID_PASSWORD"]) {
            description = @"Incorrect username or password.";
        } else {
            description = @"Your TextNow session has expired. Sign in again.";
        }
    } else if (status == 403) {
        description = @"TextNow rejected the request. Try signing in at textnow.com in a browser first, then sign in here.";
    } else if (status == 404) {
        description = @"TextNow could not find that conversation.";
    } else if (status == 429) {
        description = @"TextNow is rate-limiting this device. Wait a minute and try again.";
    } else if (status >= 500) {
        description = @"TextNow's servers are having trouble. Try again later.";
    } else if (serverMessage.length) {
        description = serverMessage;
    } else {
        description = [NSString stringWithFormat:@"TextNow returned an error (%ld).", (long)status];
    }

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = description;
    userInfo[@"HTTPStatus"] = @(status);
    if (code.length) {
        userInfo[@"ErrorCode"] = code;
    }

    return [NSError errorWithDomain:TNErrorDomain code:status userInfo:userInfo];
}

- (void)performRequest:(NSURLRequest *)request
                isLogin:(BOOL)isLogin
             completion:(TNCompletion)completion {
    if (!request) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(nil, [NSError errorWithDomain:TNErrorDomain
                                                    code:400
                                                userInfo:@{NSLocalizedDescriptionKey: @"Could not build the TextNow request."}]);
            }
        });
        return;
    }

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data,
                                                                     NSURLResponse *response,
                                                                     NSError *error) {
        [self updateCSRFToken];
        [self persistCookies];

        NSHTTPURLResponse *httpResponse = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? (NSHTTPURLResponse *)response : nil;
        NSInteger status = httpResponse ? httpResponse.statusCode : 0;
        id json = nil;
        if (data.length) {
            json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        }

        NSError *finalError = nil;
        if (error) {
            finalError = [self networkErrorFromError:error];
        } else if (status >= 400) {
            finalError = [self errorForStatus:status json:json data:data];
            if (status == 401 && !isLogin) {
                BOOL wasAuthenticated = self.isAuthenticated;
                self.isAuthenticated = NO;
                if (wasAuthenticated) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter]
                            postNotificationName:TNSessionExpiredNotification object:self];
                    });
                }
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(json, finalError);
            }
        });
    }];
    [task resume];
}

#pragma mark - Session

- (BOOL)hasStoredSession {
    NSString *cookie = [self cookieNamed:@"connect.sid"].value;
    return self.username.length > 0 && cookie.length > 0;
}

- (NSString *)usernameFromJSON:(id)json {
    if (![json isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSDictionary *dictionary = json;
    NSString *username = TNString(dictionary[@"username"]);
    if (username.length) {
        return username;
    }
    for (NSString *key in @[@"user", @"data", @"settings", @"result", @"account"]) {
        id nested = dictionary[key];
        if ([nested isKindOfClass:[NSDictionary class]]) {
            NSString *nestedUsername = TNString(((NSDictionary *)nested)[@"username"]);
            if (nestedUsername.length) {
                return nestedUsername;
            }
        }
    }
    return nil;
}

- (void)seedCSRFWithCompletion:(void (^)(NSError *error))completion {
    NSMutableURLRequest *request = [self requestWithMethod:@"GET"
                                                      path:@"/login"
                                                     query:nil
                                                      body:nil
                                               contentType:nil
                                                     isAPI:NO];

    [self performRequest:request isLogin:YES completion:^(id json, NSError *error) {
        [self updateCSRFToken];
        if (self.xsrfToken.length) {
            completion(nil);
            return;
        }
        if (error) {
            completion(error);
            return;
        }

        // Some deployments only place the token cookie on an API request.
        NSMutableURLRequest *fallback = [self requestWithMethod:@"GET"
                                                           path:@"/api/init"
                                                          query:nil
                                                           body:nil
                                                    contentType:nil
                                                          isAPI:YES];
        [self performRequest:fallback isLogin:YES completion:^(id fallbackJSON, NSError *fallbackError) {
            [self updateCSRFToken];
            if (self.xsrfToken.length) {
                completion(nil);
            } else if (fallbackError) {
                completion(fallbackError);
            } else {
                completion([NSError errorWithDomain:TNErrorDomain
                                               code:400
                                           userInfo:@{NSLocalizedDescriptionKey:
                                                          @"Could not initialize a TextNow session (missing security token)."}]);
            }
        }];
    }];
}

- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
         rememberPassword:(BOOL)remember
               completion:(TNCompletion)completion {
    NSString *trimmedUsername = [username stringByTrimmingCharactersInSet:
                                 [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmedUsername.length || !password.length) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:TNErrorDomain
                                                code:400
                                            userInfo:@{NSLocalizedDescriptionKey:
                                                           @"Enter your username and password."}]);
        }
        return;
    }

    [self clearCookies];
    self.isAuthenticated = NO;
    self.username = nil;

    __weak typeof(self) weakSelf = self;
    [self seedCSRFWithCompletion:^(NSError *seedError) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        if (seedError) {
            if (completion) {
                completion(nil, seedError);
            }
            return;
        }

        NSDictionary *payload = @{@"username": trimmedUsername, @"password": password};
        NSData *body = [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];
        NSMutableURLRequest *request = [self requestWithMethod:@"POST"
                                                          path:@"/api/sessions"
                                                         query:nil
                                                          body:body
                                                   contentType:@"application/json"
                                                         isAPI:YES];

        [self performRequest:request isLogin:YES completion:^(id json, NSError *error) {
            if (error) {
                if (completion) {
                    completion(nil, error);
                }
                return;
            }

            NSString *errorCode = nil;
            if ([json isKindOfClass:[NSDictionary class]]) {
                errorCode = TNString(json[@"error_code"]) ?: TNString(json[@"error"]);
            }
            if (errorCode.length) {
                if (completion) {
                    completion(nil, [self errorForStatus:401 json:json data:nil]);
                }
                return;
            }

            NSString *resolvedUsername = [self usernameFromJSON:json];
            self.username = resolvedUsername.length ? resolvedUsername : trimmedUsername;
            self.isAuthenticated = YES;
            [self persistCookies];

            // /api/sessions returns the account; /api/init confirms the session
            // and gives us the canonical username (usually the TextNow number).
            NSMutableURLRequest *initRequest = [self requestWithMethod:@"GET"
                                                                  path:@"/api/init"
                                                                 query:nil
                                                                  body:nil
                                                           contentType:nil
                                                                 isAPI:YES];
            [self performRequest:initRequest isLogin:YES completion:^(id initJSON, NSError *initError) {
                if (!initError) {
                    NSString *canonical = [self usernameFromJSON:initJSON];
                    if (canonical.length) {
                        self.username = canonical;
                    }
                }

                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setObject:self.username forKey:TNDefaultsUsernameKey];
                [defaults setBool:remember forKey:TNDefaultsRememberKey];
                [defaults synchronize];

                if (remember) {
                    [TNKeychain setPassword:password];
                } else {
                    [TNKeychain deletePassword];
                }

                [self persistCookies];
                if (completion) {
                    completion(json ?: @{}, nil);
                }
            }];
        }];
    }];
}

- (void)validateSessionWithCompletion:(TNCompletion)completion {
    [self updateCSRFToken];
    NSMutableURLRequest *request = [self requestWithMethod:@"GET"
                                                      path:@"/api/init"
                                                     query:nil
                                                      body:nil
                                               contentType:nil
                                                     isAPI:YES];
    [self performRequest:request isLogin:NO completion:^(id json, NSError *error) {
        if (!error) {
            self.isAuthenticated = YES;
            NSString *canonical = [self usernameFromJSON:json];
            if (canonical.length) {
                self.username = canonical;
                [[NSUserDefaults standardUserDefaults] setObject:canonical forKey:TNDefaultsUsernameKey];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            [self persistCookies];
        }
        if (completion) {
            completion(json, error);
        }
    }];
}

- (void)logout {
    self.isAuthenticated = NO;
    self.username = nil;
    [self clearCookies];
    [TNKeychain deletePassword];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:TNDefaultsUsernameKey];
    [defaults setBool:NO forKey:TNDefaultsRememberKey];
    [defaults synchronize];

    [[NSNotificationCenter defaultCenter] postNotificationName:TNLoggedOutNotification object:self];
}

#pragma mark - Conversations

- (NSArray *)arrayFromJSON:(id)json keys:(NSArray *)keys {
    if ([json isKindOfClass:[NSArray class]]) {
        return json;
    }
    if (![json isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSDictionary *dictionary = json;
    for (NSString *key in keys) {
        id value = dictionary[key];
        if ([value isKindOfClass:[NSArray class]]) {
            return value;
        }
        if ([value isKindOfClass:[NSDictionary class]]) {
            for (NSString *nestedKey in keys) {
                id nested = ((NSDictionary *)value)[nestedKey];
                if ([nested isKindOfClass:[NSArray class]]) {
                    return nested;
                }
            }
        }
    }
    return nil;
}

- (NSInteger)statusOfError:(NSError *)error {
    return [error.userInfo[@"HTTPStatus"] integerValue];
}

- (void)fetchConversationsWithCompletion:(TNCompletion)completion {
    NSMutableArray *all = [NSMutableArray array];
    [self fetchConversationPageStartingAt:nil
                              accumulated:all
                                   page:0
                             completion:completion];
}

- (void)fetchConversationPageStartingAt:(NSString *)globalId
                            accumulated:(NSMutableArray *)all
                                 page:(NSInteger)page
                           completion:(TNCompletion)completion {
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[@"page_size"] = @"100";
    if (globalId.length) {
        query[@"global_id_start"] = globalId;
    }

    NSMutableURLRequest *request = [self requestWithMethod:@"GET"
                                                      path:@"/api/v3/contacts"
                                                     query:query
                                                      body:nil
                                               contentType:nil
                                                     isAPI:YES];

    [self performRequest:request isLogin:NO completion:^(id json, NSError *error) {
        if (error) {
            if (page == 0 && [self statusOfError:error] == 404) {
                [self fetchLegacyConversationsWithCompletion:completion];
                return;
            }
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        NSArray *items = [self arrayFromJSON:json keys:@[@"result", @"contacts", @"conversations"]];
        if (!items) {
            if (completion) {
                completion(nil, [NSError errorWithDomain:TNErrorDomain
                                                    code:502
                                                userInfo:@{NSLocalizedDescriptionKey:
                                                               @"TextNow returned an unexpected conversation list."}]);
            }
            return;
        }

        for (NSDictionary *dictionary in items) {
            if (![dictionary isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            TNConversation *conversation = [TNConversation conversationWithDictionary:dictionary];
            if (conversation.contactValue.length) {
                [all addObject:conversation];
            }
        }

        NSString *next = nil;
        if (items.count >= 100) {
            id last = [items lastObject];
            if ([last isKindOfClass:[NSDictionary class]]) {
                next = TNString(((NSDictionary *)last)[@"global_id"]);
            }
        }

        if (next.length && page < 4) {
            [self fetchConversationPageStartingAt:next
                                      accumulated:all
                                           page:page + 1
                                     completion:completion];
            return;
        }

        NSMutableArray *unique = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];
        for (TNConversation *conversation in all) {
            NSString *key = conversation.contactValue.lowercaseString;
            if (key.length && ![seen containsObject:key]) {
                [seen addObject:key];
                [unique addObject:conversation];
            }
        }

        [unique sortUsingComparator:^NSComparisonResult(TNConversation *a, TNConversation *b) {
            if (!a.lastMessageDate && !b.lastMessageDate) {
                return [a.displayName caseInsensitiveCompare:b.displayName];
            }
            if (!a.lastMessageDate) {
                return NSOrderedDescending;
            }
            if (!b.lastMessageDate) {
                return NSOrderedAscending;
            }
            return [b.lastMessageDate compare:a.lastMessageDate];
        }];

        if (completion) {
            completion(unique, nil);
        }
    }];
}

- (void)fetchLegacyConversationsWithCompletion:(TNCompletion)completion {
    NSString *path = [NSString stringWithFormat:@"/api/users/%@/conversations",
                      TNPercentEncode(self.username ?: @"")];
    NSMutableURLRequest *request = [self requestWithMethod:@"GET"
                                                      path:path
                                                     query:@{@"page_size": @"100"}
                                                      body:nil
                                               contentType:nil
                                                     isAPI:YES];
    [self performRequest:request isLogin:NO completion:^(id json, NSError *error) {
        if (error) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }
        NSArray *items = [self arrayFromJSON:json keys:@[@"result", @"conversations", @"contacts"]];
        NSMutableArray *conversations = [NSMutableArray array];
        for (NSDictionary *dictionary in items) {
            if (![dictionary isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            TNConversation *conversation = [TNConversation conversationWithDictionary:dictionary];
            if (conversation.contactValue.length) {
                [conversations addObject:conversation];
            }
        }
        [conversations sortUsingComparator:^NSComparisonResult(TNConversation *a, TNConversation *b) {
            if (!a.lastMessageDate) return NSOrderedDescending;
            if (!b.lastMessageDate) return NSOrderedAscending;
            return [b.lastMessageDate compare:a.lastMessageDate];
        }];
        if (completion) {
            completion(conversations, nil);
        }
    }];
}

#pragma mark - Messages

- (void)fetchMessagesForContact:(NSString *)contactValue
                beforeMessageId:(NSString *)beforeId
                     completion:(TNCompletion)completion {
    if (!contactValue.length || !self.username.length) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:TNErrorDomain
                                                code:400
                                            userInfo:@{NSLocalizedDescriptionKey:
                                                           @"Missing conversation details."}]);
        }
        return;
    }

    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[@"contact_value"] = contactValue;
    query[@"direction"] = @"past";
    query[@"page_size"] = @"30";
    query[@"get_archived"] = @"0";
    if (beforeId.length) {
        query[@"start_message_id"] = beforeId;
    }

    NSString *path = [NSString stringWithFormat:@"/api/users/%@/messages",
                      TNPercentEncode(self.username)];
    NSMutableURLRequest *request = [self requestWithMethod:@"GET"
                                                      path:path
                                                     query:query
                                                      body:nil
                                               contentType:nil
                                                     isAPI:YES];
    [self performRequest:request isLogin:NO completion:^(id json, NSError *error) {
        if (error) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        NSArray *items = [self arrayFromJSON:json keys:@[@"messages", @"result"]];
        if (!items) {
            if (completion) {
                completion(nil, [NSError errorWithDomain:TNErrorDomain
                                                    code:502
                                                userInfo:@{NSLocalizedDescriptionKey:
                                                               @"TextNow returned an unexpected message list."}]);
            }
            return;
        }

        NSMutableArray *messages = [NSMutableArray array];
        for (NSDictionary *dictionary in items) {
            if (![dictionary isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            TNMessage *message = [TNMessage messageWithDictionary:dictionary];
            if (message) {
                [messages addObject:message];
            }
        }

        [messages sortUsingComparator:^NSComparisonResult(TNMessage *a, TNMessage *b) {
            if (!a.date && !b.date) return NSOrderedSame;
            if (!a.date) return NSOrderedAscending;
            if (!b.date) return NSOrderedDescending;
            return [a.date compare:b.date];
        }];

        if (completion) {
            completion(messages, nil);
        }
    }];
}

- (void)sendMessage:(NSString *)text
          toContact:(NSString *)contactValue
         completion:(TNCompletion)completion {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:TNErrorDomain
                                                code:400
                                            userInfo:@{NSLocalizedDescriptionKey: @"Type a message first."}]);
        }
        return;
    }
    if (!contactValue.length || !self.username.length) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:TNErrorDomain
                                                code:400
                                            userInfo:@{NSLocalizedDescriptionKey:
                                                           @"Missing conversation details."}]);
        }
        return;
    }

    NSDictionary *payload = @{
        @"contact_value": contactValue,
        @"contact_type": @2,
        @"message": trimmed,
        @"read": @1,
        @"message_direction": @2,
        @"message_type": @1,
        @"from_name": self.username,
        @"has_video": @NO,
        @"new": @YES,
        @"date": TNISO8601String([NSDate date]),
    };

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSString *bodyString = [NSString stringWithFormat:@"json=%@", TNFormEncode(jsonString)];
    NSData *body = [bodyString dataUsingEncoding:NSUTF8StringEncoding];

    NSString *path = [NSString stringWithFormat:@"/api/users/%@/messages",
                      TNPercentEncode(self.username)];
    NSMutableURLRequest *request = [self requestWithMethod:@"POST"
                                                      path:path
                                                     query:nil
                                                      body:body
                                               contentType:@"application/x-www-form-urlencoded; charset=UTF-8"
                                                     isAPI:YES];
    [self performRequest:request isLogin:NO completion:^(id json, NSError *error) {
        if (completion) {
            completion(error ? nil : (json ?: @{}), error);
        }
    }];
}

- (void)markConversationRead:(NSString *)contactValue
             latestMessageId:(NSString *)messageId
                  completion:(TNCompletion)completion {
    if (!contactValue.length || !messageId.length || !self.username.length) {
        if (completion) {
            completion(@{}, nil);
        }
        return;
    }

    NSString *path = [NSString stringWithFormat:@"/api/users/%@/conversations/%@",
                      TNPercentEncode(self.username), TNPercentEncode(contactValue)];
    NSDictionary *query = @{
        @"latest_message_id": messageId,
        @"http_method": @"PATCH",
    };
    NSData *body = [@"read=true" dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableURLRequest *request = [self requestWithMethod:@"POST"
                                                      path:path
                                                     query:query
                                                      body:body
                                               contentType:@"application/x-www-form-urlencoded; charset=UTF-8"
                                                     isAPI:YES];
    [self performRequest:request isLogin:NO completion:^(id json, NSError *error) {
        if (completion) {
            completion(error ? nil : (json ?: @{}), error);
        }
    }];
}

#pragma mark - Helpers

- (NSString *)normalizedContactValue:(NSString *)raw {
    NSString *trimmed = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) {
        return nil;
    }

    NSMutableString *digits = [NSMutableString string];
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar character = [trimmed characterAtIndex:i];
        if (character >= '0' && character <= '9') {
            [digits appendFormat:@"%C", character];
        }
    }

    if (!digits.length) {
        return nil;
    }
    if ([trimmed hasPrefix:@"+"]) {
        return [@"+" stringByAppendingString:digits];
    }
    if (digits.length == 10) {
        return [@"+1" stringByAppendingString:digits];
    }
    if (digits.length == 11 && [digits hasPrefix:@"1"]) {
        return [@"+" stringByAppendingString:digits];
    }
    if (digits.length >= 7) {
        return [@"+" stringByAppendingString:digits];
    }
    return digits;
}

@end
