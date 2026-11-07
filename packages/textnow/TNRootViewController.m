//
//  TNRootViewController.m
//  TextNow Legacy
//

#import "TNRootViewController.h"
#import "TNLoginViewController.h"
#import "TNConversationsViewController.h"
#import "TNClient.h"
#import "TNKeychain.h"
#import "TN.h"

@interface TNRootViewController ()

@property (nonatomic, strong) UIViewController *currentController;
@property (nonatomic, strong) UIView *launchView;
@property (nonatomic, assign) BOOL started;
@property (nonatomic, assign) BOOL handlingAuthentication;

@end

@implementation TNRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];

    UIView *launch = [[UIView alloc] initWithFrame:self.view.bounds];
    launch.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    launch.backgroundColor = [UIColor whiteColor];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20.0, 0.0, self.view.bounds.size.width - 40.0, 50.0)];
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    title.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds) - 30.0);
    title.text = @"TextNow";
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont boldSystemFontOfSize:38.0];
    title.textColor = TNTealColor();
    title.backgroundColor = [UIColor clearColor];
    [launch addSubview:title];

    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    spinner.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds) + 28.0);
    spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [spinner startAnimating];
    [launch addSubview:spinner];

    [self.view addSubview:launch];
    self.launchView = launch;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sessionExpired:)
                                                 name:TNSessionExpiredNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loggedOut:)
                                                 name:TNLoggedOutNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.started) {
        return;
    }
    self.started = YES;
    [self start];
}

- (void)start {
    TNClient *client = [TNClient sharedClient];
    if (![client hasStoredSession]) {
        [self showLoginWithMessage:nil];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [client validateSessionWithCompletion:^(id result, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        if (!error) {
            [self showConversations];
            return;
        }

        NSInteger status = [error.userInfo[@"HTTPStatus"] integerValue];
        if (status == 401) {
            [self attemptSavedLoginWithMessage:@"Your TextNow session expired. Signing in again…"];
        } else {
            // Offline or a temporary server problem: keep the stored session and
            // let the conversation screen show its own retry state.
            [self showConversations];
        }
    }];
}

- (void)attemptSavedLoginWithMessage:(NSString *)message {
    if (self.handlingAuthentication) {
        return;
    }

    NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:TNDefaultsUsernameKey];
    NSString *password = [TNKeychain password];
    if (!username.length || !password.length) {
        [self showLoginWithMessage:message];
        return;
    }

    self.handlingAuthentication = YES;
    __weak typeof(self) weakSelf = self;
    [[TNClient sharedClient] loginWithUsername:username
                                      password:password
                              rememberPassword:YES
                                    completion:^(id result, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        self.handlingAuthentication = NO;
        if (error) {
            [self showLoginWithMessage:error.localizedDescription];
        } else {
            [self showConversations];
        }
    }];
}

- (void)showLoginWithMessage:(NSString *)message {
    if ([self.currentController isKindOfClass:[TNLoginViewController class]]) {
        return;
    }

    TNLoginViewController *login = [[TNLoginViewController alloc] init];
    login.message = message;

    __weak typeof(self) weakSelf = self;
    login.onSignIn = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (self) {
            [self showConversations];
        }
    };
    [self swapToController:login];
}

- (void)showConversations {
    TNConversationsViewController *conversations = [[TNConversationsViewController alloc] init];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:conversations];
    navigation.navigationBar.translucent = NO;
    [self swapToController:navigation];
}

- (void)swapToController:(UIViewController *)controller {
    if (controller == self.currentController) {
        return;
    }

    [self.launchView removeFromSuperview];
    self.launchView = nil;

    [controller willMoveToParentViewController:self];
    [self addChildViewController:controller];
    controller.view.frame = self.view.bounds;
    controller.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UIViewController *previous = self.currentController;
    self.currentController = controller;

    if (!previous) {
        [self.view addSubview:controller.view];
        [controller didMoveToParentViewController:self];
        return;
    }

    [self transitionFromViewController:previous
                      toViewController:controller
                              duration:0.22
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:nil
                            completion:^(BOOL finished) {
        [previous removeFromParentViewController];
        [controller didMoveToParentViewController:self];
    }];
}

- (void)sessionExpired:(NSNotification *)notification {
    if (self.handlingAuthentication) {
        return;
    }
    if ([self.currentController isKindOfClass:[TNLoginViewController class]]) {
        return;
    }
    [self attemptSavedLoginWithMessage:@"Your TextNow session expired. Signing in again…"];
}

- (void)loggedOut:(NSNotification *)notification {
    [self showLoginWithMessage:nil];
}

@end
