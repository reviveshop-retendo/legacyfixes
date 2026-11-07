//
//  TNAppDelegate.m
//  TextNow Legacy
//

#import "TNAppDelegate.h"
#import "TNRootViewController.h"
#import "TN.h"

@implementation TNAppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[UINavigationBar appearance] setBarTintColor:[UIColor whiteColor]];
    [[UINavigationBar appearance] setTintColor:TNTealColor()];
    [[UINavigationBar appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [UIColor colorWithRed:0.10 green:0.11 blue:0.13 alpha:1.0]
    }];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.tintColor = TNTealColor();
    self.window.rootViewController = [[TNRootViewController alloc] init];
    [self.window makeKeyAndVisible];

    return YES;
}

@end
