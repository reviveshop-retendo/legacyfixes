//
//  TNConversationsViewController.m
//  TextNow Legacy
//

#import "TNConversationsViewController.h"
#import "TNConversationCell.h"
#import "TNThreadViewController.h"
#import "TNSettingsViewController.h"
#import "TNClient.h"
#import "TNModels.h"
#import "TN.h"

@interface TNConversationsViewController () <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSArray *conversations;
@property (nonatomic, strong) NSTimer *pollTimer;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL didLoadOnce;

@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UIActivityIndicatorView *emptySpinner;
@property (nonatomic, strong) UILabel *emptyTitle;
@property (nonatomic, strong) UILabel *emptyDetail;

@end

@implementation TNConversationsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Messages";
    self.view.backgroundColor = [UIColor whiteColor];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

    UIButton *settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    settingsButton.frame = CGRectMake(0, 0, 58, 30);
    [settingsButton setTitle:@"Settings" forState:UIControlStateNormal];
    settingsButton.titleLabel.font = [UIFont systemFontOfSize:15.0];
    [settingsButton addTarget:self action:@selector(settingsTapped) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:settingsButton];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
                             target:self
                             action:@selector(composeTapped)];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 72.0;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.separatorColor = TNSeparatorColor();
    [self.view addSubview:self.tableView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = TNTealColor();
    [self.refreshControl addTarget:self action:@selector(refreshPulled) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];

    [self buildEmptyView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)dealloc {
    [self.pollTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildEmptyView {
    self.emptyView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.emptyView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.emptyView.backgroundColor = [UIColor whiteColor];
    self.emptyView.userInteractionEnabled = NO;
    self.emptyView.hidden = YES;
    [self.view addSubview:self.emptyView];

    CGFloat width = self.view.bounds.size.width;
    CGFloat centerY = self.view.bounds.size.height * 0.38;

    self.emptySpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.emptySpinner.center = CGPointMake(width / 2.0, centerY - 54.0);
    self.emptySpinner.hidesWhenStopped = YES;
    [self.emptyView addSubview:self.emptySpinner];

    self.emptyTitle = [[UILabel alloc] initWithFrame:CGRectMake(28.0, centerY - 20.0, width - 56.0, 24.0)];
    self.emptyTitle.textAlignment = NSTextAlignmentCenter;
    self.emptyTitle.font = [UIFont boldSystemFontOfSize:17.0];
    self.emptyTitle.textColor = [UIColor colorWithRed:0.20 green:0.22 blue:0.25 alpha:1.0];
    self.emptyTitle.backgroundColor = [UIColor clearColor];
    [self.emptyView addSubview:self.emptyTitle];

    self.emptyDetail = [[UILabel alloc] initWithFrame:CGRectMake(28.0, centerY + 10.0, width - 56.0, 72.0)];
    self.emptyDetail.textAlignment = NSTextAlignmentCenter;
    self.emptyDetail.numberOfLines = 0;
    self.emptyDetail.font = [UIFont systemFontOfSize:13.5];
    self.emptyDetail.textColor = TNGrayTextColor();
    self.emptyDetail.backgroundColor = [UIColor clearColor];
    [self.emptyView addSubview:self.emptyDetail];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self startPolling];
    [self reloadConversations:NO];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.pollTimer invalidate];
    self.pollTimer = nil;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.pollTimer invalidate];
    self.pollTimer = nil;
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    if (self.view.window) {
        [self reloadConversations:NO];
    }
}

- (void)startPolling {
    [self.pollTimer invalidate];
    self.pollTimer = [NSTimer timerWithTimeInterval:6.0
                                            target:self
                                          selector:@selector(pollTimerFired:)
                                          userInfo:nil
                                           repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.pollTimer forMode:NSRunLoopCommonModes];
}

- (void)pollTimerFired:(NSTimer *)timer {
    if (!self.loading) {
        [self reloadConversations:NO];
    }
}

- (void)refreshPulled {
    [self reloadConversations:YES];
}

- (void)reloadConversations:(BOOL)userInitiated {
    if (self.loading) {
        [self.refreshControl endRefreshing];
        return;
    }

    self.loading = YES;
    [self updateEmptyStateWithError:nil];

    __weak typeof(self) weakSelf = self;
    [[TNClient sharedClient] fetchConversationsWithCompletion:^(id result, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        self.loading = NO;
        [self.refreshControl endRefreshing];

        if ([result isKindOfClass:[NSArray class]]) {
            self.conversations = result;
            self.didLoadOnce = YES;
            [self.tableView reloadData];
            [self updateEmptyStateWithError:nil];
        } else {
            [self updateEmptyStateWithError:error];
            if (userInitiated && self.conversations.count > 0 && error) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't Refresh"
                                                                message:error.localizedDescription
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                [alert show];
            }
        }
    }];
}

- (void)updateEmptyStateWithError:(NSError *)error {
    BOOL empty = self.conversations.count == 0;
    self.emptyView.hidden = !empty;

    if (!empty) {
        [self.emptySpinner stopAnimating];
        return;
    }

    if (self.loading) {
        self.emptyTitle.text = @"Loading messages…";
        self.emptyDetail.text = @"Fetching your TextNow conversations.";
        [self.emptySpinner startAnimating];
    } else if (error) {
        self.emptyTitle.text = @"Couldn't load messages";
        self.emptyDetail.text = error.localizedDescription;
        [self.emptySpinner stopAnimating];
    } else {
        self.emptyTitle.text = @"No conversations yet";
        self.emptyDetail.text = @"When someone texts your TextNow number, the conversation will appear here.";
        [self.emptySpinner stopAnimating];
    }
}

#pragma mark - Actions

- (void)settingsTapped {
    TNSettingsViewController *settings = [[TNSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:settings];
    navigation.navigationBar.translucent = NO;
    [self presentViewController:navigation animated:YES completion:nil];
}

- (void)composeTapped {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"New Message"
                                                    message:@"Enter a phone number"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Open", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField *field = [alert textFieldAtIndex:0];
    field.keyboardType = UIKeyboardTypePhonePad;
    field.placeholder = @"+1 555 123 4567";
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) {
        return;
    }

    NSString *raw = [[alertView textFieldAtIndex:0] text];
    NSString *number = [[TNClient sharedClient] normalizedContactValue:raw];
    if (!number.length) {
        UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Invalid Number"
                                                             message:@"Enter a phone number, for example +1 555 123 4567."
                                                            delegate:nil
                                                   cancelButtonTitle:@"OK"
                                                   otherButtonTitles:nil];
        [errorAlert show];
        return;
    }

    TNConversation *conversation = [[TNConversation alloc] init];
    conversation.contactValue = number;
    conversation.name = nil;
    [self openConversation:conversation];
}

- (void)openConversation:(TNConversation *)conversation {
    TNThreadViewController *thread = [[TNThreadViewController alloc] initWithConversation:conversation];
    [self.navigationController pushViewController:thread animated:YES];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.conversations.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"TNConversationCell";
    TNConversationCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[TNConversationCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    if (indexPath.row < (NSInteger)self.conversations.count) {
        cell.conversation = self.conversations[indexPath.row];
    }
    if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
        cell.separatorInset = UIEdgeInsetsMake(0, 16, 0, 0);
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.conversations.count) {
        return;
    }
    [self openConversation:self.conversations[indexPath.row]];
}

@end
