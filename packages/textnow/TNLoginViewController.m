//
//  TNLoginViewController.m
//  TextNow Legacy
//

#import "TNLoginViewController.h"
#import "TNClient.h"
#import "TNKeychain.h"
#import "TN.h"
#import <QuartzCore/QuartzCore.h>

@interface TNLoginViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UITextField *usernameField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UISwitch *rememberSwitch;
@property (nonatomic, strong) UIButton *signInButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *errorLabel;

@end

@implementation TNLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    CGFloat width = self.view.bounds.size.width;
    CGFloat side = 20.0;
    CGFloat contentWidth = width - side * 2.0;

    UILabel *wordmark = [[UILabel alloc] initWithFrame:CGRectMake(side, 34.0, contentWidth, 50.0)];
    wordmark.text = @"TextNow";
    wordmark.textAlignment = NSTextAlignmentCenter;
    wordmark.font = [UIFont boldSystemFontOfSize:42.0];
    wordmark.textColor = TNTealColor();
    wordmark.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:wordmark];

    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(side, 84.0, contentWidth, 20.0)];
    subtitle.text = @"LEGACY  ·  for iOS 7";
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.font = [UIFont systemFontOfSize:12.0];
    subtitle.textColor = TNGrayTextColor();
    subtitle.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:subtitle];

    self.usernameField = [[UITextField alloc] initWithFrame:CGRectMake(side, 124.0, contentWidth, 46.0)];
    self.usernameField.placeholder = @"Phone number, email or username";
    self.usernameField.font = [UIFont systemFontOfSize:16.0];
    self.usernameField.textColor = [UIColor colorWithRed:0.10 green:0.11 blue:0.13 alpha:1.0];
    self.usernameField.backgroundColor = TNFieldColor();
    self.usernameField.borderStyle = UITextBorderStyleNone;
    self.usernameField.layer.cornerRadius = 8.0;
    self.usernameField.clipsToBounds = YES;
    self.usernameField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 46)];
    self.usernameField.leftViewMode = UITextFieldViewModeAlways;
    self.usernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.usernameField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.usernameField.keyboardType = UIKeyboardTypeEmailAddress;
    self.usernameField.returnKeyType = UIReturnKeyNext;
    self.usernameField.delegate = self;
    [self.scrollView addSubview:self.usernameField];

    self.passwordField = [[UITextField alloc] initWithFrame:CGRectMake(side, 180.0, contentWidth, 46.0)];
    self.passwordField.placeholder = @"Password";
    self.passwordField.font = [UIFont systemFontOfSize:16.0];
    self.passwordField.textColor = [UIColor colorWithRed:0.10 green:0.11 blue:0.13 alpha:1.0];
    self.passwordField.backgroundColor = TNFieldColor();
    self.passwordField.borderStyle = UITextBorderStyleNone;
    self.passwordField.layer.cornerRadius = 8.0;
    self.passwordField.clipsToBounds = YES;
    self.passwordField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 46)];
    self.passwordField.leftViewMode = UITextFieldViewModeAlways;
    self.passwordField.secureTextEntry = YES;
    self.passwordField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.passwordField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.passwordField.returnKeyType = UIReturnKeyGo;
    self.passwordField.delegate = self;
    [self.scrollView addSubview:self.passwordField];

    UILabel *rememberLabel = [[UILabel alloc] initWithFrame:CGRectMake(side, 238.0, contentWidth - 60.0, 32.0)];
    rememberLabel.text = @"Remember password";
    rememberLabel.font = [UIFont systemFontOfSize:15.0];
    rememberLabel.textColor = [UIColor colorWithRed:0.20 green:0.22 blue:0.25 alpha:1.0];
    rememberLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:rememberLabel];

    self.rememberSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(width - side - 51.0, 238.0, 51.0, 31.0)];
    self.rememberSwitch.onTintColor = TNTealColor();
    [self.scrollView addSubview:self.rememberSwitch];

    self.signInButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.signInButton.frame = CGRectMake(side, 288.0, contentWidth, 48.0);
    self.signInButton.backgroundColor = TNTealColor();
    self.signInButton.layer.cornerRadius = 8.0;
    self.signInButton.titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
    [self.signInButton setTitle:@"Sign In" forState:UIControlStateNormal];
    [self.signInButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.signInButton addTarget:self action:@selector(signInTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.signInButton];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.center = CGPointMake(CGRectGetMidX(self.signInButton.bounds), CGRectGetMidY(self.signInButton.bounds));
    [self.signInButton addSubview:self.spinner];

    self.errorLabel = [[UILabel alloc] initWithFrame:CGRectMake(side, 346.0, contentWidth, 58.0)];
    self.errorLabel.font = [UIFont systemFontOfSize:13.0];
    self.errorLabel.textColor = [UIColor colorWithRed:0.78 green:0.16 blue:0.16 alpha:1.0];
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.errorLabel];

    UILabel *footer = [[UILabel alloc] initWithFrame:CGRectMake(side, 416.0, contentWidth, 30.0)];
    footer.text = @"Unofficial client. Not affiliated with TextNow.";
    footer.font = [UIFont systemFontOfSize:11.0];
    footer.textColor = TNGrayTextColor();
    footer.textAlignment = NSTextAlignmentCenter;
    footer.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:footer];

    self.scrollView.contentSize = CGSizeMake(width, 470.0);

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.usernameField.text = [defaults stringForKey:TNDefaultsUsernameKey];

    BOOL remember = [defaults boolForKey:TNDefaultsRememberKey];
    NSString *savedPassword = [TNKeychain password];
    if (remember && savedPassword.length) {
        self.passwordField.text = savedPassword;
    }
    self.rememberSwitch.on = remember && savedPassword.length > 0;

    self.errorLabel.text = self.message;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChange:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChange:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.usernameField.text.length) {
        [self.usernameField becomeFirstResponder];
    } else if (!self.passwordField.text.length) {
        [self.passwordField becomeFirstResponder];
    }
}

- (void)keyboardWillChange:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    keyboardFrame = [self.view convertRect:keyboardFrame fromView:nil];

    CGFloat overlap = 0.0;
    if ([notification.name isEqualToString:UIKeyboardWillShowNotification]) {
        overlap = MAX(0.0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(keyboardFrame));
    }

    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];

    [UIView animateWithDuration:duration
                          delay:0.0
                        options:(UIViewAnimationOptions)(curve << 16)
                     animations:^{
        self.scrollView.contentInset = UIEdgeInsetsMake(0, 0, overlap, 0);
        self.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, overlap, 0);
    } completion:nil];

    if (overlap > 0.0) {
        [self.scrollView scrollRectToVisible:CGRectMake(0, 280.0, self.view.bounds.size.width, 60.0)
                                    animated:YES];
    }
}

- (void)showError:(NSString *)message {
    self.errorLabel.text = message;
}

- (void)setLoading:(BOOL)loading {
    self.usernameField.enabled = !loading;
    self.passwordField.enabled = !loading;
    self.rememberSwitch.enabled = !loading;
    self.signInButton.enabled = !loading;

    if (loading) {
        [self.signInButton setTitle:@"" forState:UIControlStateNormal];
        [self.spinner startAnimating];
    } else {
        [self.signInButton setTitle:@"Sign In" forState:UIControlStateNormal];
        [self.spinner stopAnimating];
    }
}

- (void)signInTapped {
    [self.view endEditing:YES];

    NSString *username = [self.usernameField.text stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *password = self.passwordField.text;

    if (!username.length) {
        [self showError:@"Enter your phone number, email or username."];
        return;
    }
    if (!password.length) {
        [self showError:@"Enter your password."];
        return;
    }

    [self showError:nil];
    [self setLoading:YES];

    __weak typeof(self) weakSelf = self;
    [[TNClient sharedClient] loginWithUsername:username
                                      password:password
                              rememberPassword:self.rememberSwitch.isOn
                                    completion:^(id result, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        [self setLoading:NO];
        if (error) {
            [self showError:error.localizedDescription];
            return;
        }
        if (self.onSignIn) {
            self.onSignIn();
        }
    }];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.usernameField) {
        [self.passwordField becomeFirstResponder];
        return NO;
    }
    [self signInTapped];
    return NO;
}

@end
