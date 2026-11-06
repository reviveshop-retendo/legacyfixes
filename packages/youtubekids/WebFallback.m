//
//  YouTube Kids web fallback
//
//  Implemented in a plain Objective-C translation unit. Logos compiles .xm
//  files as Objective-C++, which drags in the C++ exception personality for
//  blocks/classes on armv7; keeping this in .m avoids that linker dependency.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LFEngine.h"

static BOOL gFallbackPresented = NO;

static NSString *LFStringConfig(NSString *key, NSString *fallback) {
    id value = LFConfigValue(key);
    return [value isKindOfClass:[NSString class]] && [value length] > 0 ? value : fallback;
}

static UIViewController *LFTopViewController(void) {
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    UIViewController *controller = window.rootViewController;

    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    if ([controller isKindOfClass:[UINavigationController class]]) {
        controller = [(UINavigationController *)controller topViewController];
    } else if ([controller isKindOfClass:[UITabBarController class]]) {
        controller = [(UITabBarController *)controller selectedViewController];
    }
    return controller;
}

@interface LFYouTubeKidsWebController : UIViewController <UIWebViewDelegate>
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, copy) NSString *homeURL;
@end

@implementation LFYouTubeKidsWebController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"YouTube Kids";

    self.webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                    UIViewAutoresizingFlexibleHeight;
    self.webView.scalesPageToFit = YES;
    self.webView.delegate = self;
    [self.view addSubview:self.webView];

    UIBarButtonItem *reload = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                             target:self
                             action:@selector(reload)];
    self.navigationItem.rightBarButtonItem = reload;

    [self loadHome];
}

- (void)loadHome {
    NSURL *url = [NSURL URLWithString:self.homeURL];
    if (!url) {
        return;
    }
    [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)reload {
    [self loadHome];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    // -999 is the normal "cancelled because a new load started" error.
    if ([error code] == NSURLErrorCancelled) {
        return;
    }

    NSString *message = [NSString stringWithFormat:
        @"Could not load YouTube Kids.\n\n%@\n\n"
         "On iOS 6/7 this usually means the system cannot negotiate modern "
         "TLS. Install a TLS 1.2 backport (for example TLSFix) and try again.",
        [error localizedDescription]];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Web fallback"
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

@end

static void LFPresentYouTubeKidsFallback(void) {
    if (gFallbackPresented) {
        return;
    }

    UIViewController *top = LFTopViewController();
    if (!top) {
        return;
    }

    gFallbackPresented = YES;

    LFYouTubeKidsWebController *web = [[LFYouTubeKidsWebController alloc] init];
    web.homeURL = LFStringConfig(@"WebFallbackURL", @"https://www.youtubekids.com/");

    UINavigationController *navigation =
        [[UINavigationController alloc] initWithRootViewController:web];

    [top presentViewController:navigation animated:YES completion:nil];
}

static void LFScheduleYouTubeKidsFallback(void) {
    if (![LFConfigValue(@"WebFallback") boolValue]) {
        return;
    }

    double delay = 2.0;
    id configured = LFConfigValue(@"WebFallbackDelay");
    if ([configured respondsToSelector:@selector(doubleValue)] &&
        [configured doubleValue] >= 0.0) {
        delay = [configured doubleValue];
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        LFPresentYouTubeKidsFallback();
    });
}

void LFYouTubeKidsInstallFallback(void) {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserverForName:UIApplicationDidFinishLaunchingNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *note) {
        LFScheduleYouTubeKidsFallback();
    }];
    [center addObserverForName:UIApplicationDidBecomeActiveNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *note) {
        LFScheduleYouTubeKidsFallback();
    }];
}
