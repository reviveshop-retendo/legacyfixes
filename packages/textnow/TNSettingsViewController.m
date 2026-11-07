//
//  TNSettingsViewController.m
//  TextNow Legacy
//

#import "TNSettingsViewController.h"
#import "TNClient.h"
#import "TNKeychain.h"
#import "TN.h"

@interface TNSettingsViewController () <UIAlertViewDelegate>

@property (nonatomic, assign) BOOL confirmingLogout;

@end

@implementation TNSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Settings";
    self.tableView.backgroundColor = [UIColor colorWithRed:0.95 green:0.955 blue:0.965 alpha:1.0];
    self.tableView.separatorColor = TNSeparatorColor();

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                             target:self
                             action:@selector(doneTapped)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)doneTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 2;
    }
    if (section == 1) {
        return 1;
    }
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"Account";
    }
    if (section == 1) {
        return @"Security";
    }
    return @"About";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"Your credentials are sent directly to TextNow over HTTPS. This app does not use a proxy server.";
    }
    if (section == 1) {
        return @"Stores your password in the iOS Keychain. Off by default. Turning this off deletes the saved password.";
    }
    return @"TextNow Legacy is an unofficial client that talks to www.textnow.com. It is not affiliated with or endorsed by TextNow. Use your own account and follow TextNow's terms.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            static NSString *identifier = @"TNValueCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            cell.textLabel.text = @"Signed in as";
            cell.detailTextLabel.text = [TNClient sharedClient].username ?: @"Not signed in";
            return cell;
        }

        static NSString *logoutIdentifier = @"TNLogoutCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:logoutIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:logoutIdentifier];
        }
        cell.textLabel.text = @"Log Out";
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = [UIColor colorWithRed:0.78 green:0.16 blue:0.16 alpha:1.0];
        return cell;
    }

    if (indexPath.section == 1) {
        static NSString *identifier = @"TNSwitchCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
            toggle.onTintColor = TNTealColor();
            [toggle addTarget:self action:@selector(rememberSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
        }
        cell.textLabel.text = @"Remember Password";
        UISwitch *toggle = (UISwitch *)cell.accessoryView;
        toggle.on = [TNKeychain password].length > 0;
        return cell;
    }

    static NSString *versionIdentifier = @"TNVersionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:versionIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:versionIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *version = info[@"CFBundleShortVersionString"] ?: @"1.0.0";
    NSString *build = info[@"CFBundleVersion"] ?: version;
    cell.textLabel.text = @"Version";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ (%@)", version, build];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0 && indexPath.row == 1) {
        self.confirmingLogout = YES;
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Log Out?"
                                                        message:@"Your saved TextNow session will be removed from this device."
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"Log Out", nil];
        [alert show];
    }
}

#pragma mark - Actions

- (void)rememberSwitchChanged:(UISwitch *)toggle {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (toggle.isOn) {
        if (![TNKeychain password].length) {
            toggle.on = NO;
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Password Not Saved"
                                                            message:@"To store your password, sign out and sign in again with Remember Password turned on."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }
        [defaults setBool:YES forKey:TNDefaultsRememberKey];
    } else {
        [TNKeychain deletePassword];
        [defaults setBool:NO forKey:TNDefaultsRememberKey];
    }
    [defaults synchronize];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (!self.confirmingLogout || buttonIndex == alertView.cancelButtonIndex) {
        self.confirmingLogout = NO;
        return;
    }
    self.confirmingLogout = NO;

    UIViewController *presenter = self.navigationController ?: self;
    [presenter dismissViewControllerAnimated:YES completion:^{
        [[TNClient sharedClient] logout];
    }];
}

@end
