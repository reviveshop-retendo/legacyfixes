//
//  FBSystemFix
//  Repair iOS's built-in Facebook account integration (iOS 6-8)
//
//  The Facebook 11.x app still logs in through the system Facebook account
//  stored in Settings. On modern Facebook servers that integration makes three
//  requests that no longer work:
//
//    graph.facebook.com//me/privacy_options  (double slash, old field path)
//    graph.facebook.com/me/links             (field no longer exists)
//    api.facebook.com/method/auth.login      (old system app token)
//
//  The first two make the app crash or hang after login; the third makes the
//  login fail. This tweak registers an NSURLProtocol in the system daemons and
//  rewrites just those requests. It does NOT touch the Facebook app bundle.
//
//  The request/token rewrite is the same technique used by the community
//  FBIntegrationFix project (no license, so this is an independent
//  implementation). The two app tokens are public client tokens that ship
//  inside old Facebook/iOS builds; they are not user credentials.
//

#import <Foundation/Foundation.h>

static NSString *const kLFHandledProperty = @"LegacyFixesFBHandled";

// Access tokens used by the iOS system Facebook integration.
static NSString *const kLFLegacySystemToken =
    @"access_token=213546525407071%7C362ee4c5fe721df3c7d216115b575410";
static NSString *const kLFCurrentSystemToken =
    @"access_token=237759909591655%7C0f140aabedfb65ac27a739ed1a2263b1";

@interface LFFacebookSystemProtocol : NSURLProtocol
@end

@implementation LFFacebookSystemProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if ([NSURLProtocol propertyForKey:kLFHandledProperty inRequest:request]) {
        return NO;
    }

    NSString *host = request.URL.host;
    NSString *path = request.URL.path;
    BOOL isGET = [[request.HTTPMethod ?: @"GET" uppercaseString] isEqualToString:@"GET"];

    if ([host isEqualToString:@"graph.facebook.com"]) {
        if ([path isEqualToString:@"//me/privacy_options"] ||
            [path isEqualToString:@"/me/privacy_options"] ||
            [path isEqualToString:@"/me/links"]) {
            // Only rewrite reads; POSTing to me/links would otherwise be
            // turned into a completely different feed write.
            return isGET;
        }
        return NO;
    }
    if ([host isEqualToString:@"api.facebook.com"]) {
        return [path isEqualToString:@"/method/auth.login"];
    }
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSURLRequest *request = self.request;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url = request.URL;
        NSString *host = url.host;
        NSString *path = url.path;
        NSString *query = url.query;

        NSMutableURLRequest *newRequest = [request mutableCopy];
        BOOL unwrapPrivacyOptions = NO;

        if ([host isEqualToString:@"graph.facebook.com"] &&
            ([path isEqualToString:@"//me/privacy_options"] ||
             [path isEqualToString:@"/me/privacy_options"])) {
            // Old clients ask for "//me/privacy_options"; the modern graph
            // equivalent is "me?fields=privacy_options".
            NSString *newURL = @"https://graph.facebook.com/me?fields=privacy_options";
            if (query.length > 0) {
                newURL = [newURL stringByAppendingFormat:@"&%@", query];
            }
            [newRequest setURL:[NSURL URLWithString:newURL]];
            unwrapPrivacyOptions = YES;
            NSLog(@"[LegacyFixes/FBSystem] rewriting privacy_options request");
        } else if ([host isEqualToString:@"graph.facebook.com"] &&
                   [path isEqualToString:@"/me/links"]) {
            // "me/links" was removed from the graph API; the system
            // integration only needs a feed-shaped "data" array.
            NSString *newURL = @"https://graph.facebook.com/me/feed";
            if (query.length > 0) {
                newURL = [newURL stringByAppendingFormat:@"?%@", query];
            }
            [newRequest setURL:[NSURL URLWithString:newURL]];
            NSLog(@"[LegacyFixes/FBSystem] rewriting me/links request");
        } else if ([host isEqualToString:@"api.facebook.com"] &&
                   [path isEqualToString:@"/method/auth.login"]) {
            NSData *bodyData = [newRequest HTTPBody];
            if (bodyData) {
                NSString *body = [[NSString alloc] initWithData:bodyData
                                                       encoding:NSUTF8StringEncoding];
                if ([body rangeOfString:kLFLegacySystemToken].location != NSNotFound) {
                    NSString *newBody =
                        [body stringByReplacingOccurrencesOfString:kLFLegacySystemToken
                                                        withString:kLFCurrentSystemToken];
                    [newRequest setHTTPBody:[newBody dataUsingEncoding:NSUTF8StringEncoding]];
                    NSLog(@"[LegacyFixes/FBSystem] swapped legacy auth.login token");
                }
            }
        }

        // Prevent the nested request from being intercepted again.
        [NSURLProtocol setProperty:@YES
                            forKey:kLFHandledProperty
                         inRequest:newRequest];

        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:newRequest
                                             returningResponse:&response
                                                         error:&error];

        if (error || !response) {
            [self.client URLProtocol:self didFailWithError:
                error ?: [NSError errorWithDomain:@"LegacyFixesFBSystem"
                                             code:1
                                         userInfo:nil]];
            return;
        }

        if (unwrapPrivacyOptions) {
            NSError *jsonError = nil;
            id json = [NSJSONSerialization JSONObjectWithData:data
                                                      options:0
                                                        error:&jsonError];
            if (!jsonError && [json isKindOfClass:[NSDictionary class]]) {
                id options = [(NSDictionary *)json objectForKey:@"privacy_options"];
                if (options) {
                    NSData *rewritten = [NSJSONSerialization dataWithJSONObject:options
                                                                       options:0
                                                                         error:&jsonError];
                    if (!jsonError && rewritten) {
                        data = rewritten;
                    }
                }
            }
        }

        [self.client URLProtocol:self
              didReceiveResponse:response
              cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:data];
        [self.client URLProtocolDidFinishLoading:self];
    });
}

- (void)stopLoading {
}

@end

%ctor {
    [NSURLProtocol registerClass:[LFFacebookSystemProtocol class]];
    NSLog(@"[LegacyFixes/FBSystem] Facebook system integration fix loaded");
}
