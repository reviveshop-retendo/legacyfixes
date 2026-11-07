//
//  TNThreadViewController.m
//  TextNow Legacy
//

#import "TNThreadViewController.h"
#import "TNMessageCell.h"
#import "TNClient.h"
#import "TN.h"
#import <QuartzCore/QuartzCore.h>

@interface TNThreadViewController () <UITableViewDataSource, UITableViewDelegate, UITextViewDelegate>

@property (nonatomic, strong) TNConversation *conversation;
@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *inputBar;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIButton *earlierButton;

@property (nonatomic, strong) NSTimer *pollTimer;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL loadingEarlier;
@property (nonatomic, assign) BOOL sending;
@property (nonatomic, assign) BOOL markingRead;
@property (nonatomic, assign) BOOL canLoadEarlier;
@property (nonatomic, assign) BOOL didInitialLoad;
@property (nonatomic, assign) CGFloat keyboardHeight;
@property (nonatomic, copy) NSString *lastErrorText;

@end

@implementation TNThreadViewController

- (instancetype)initWithConversation:(TNConversation *)conversation {
    self = [super init];
    if (self) {
        _conversation = conversation;
        _messages = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = self.conversation.displayName;
    self.view.backgroundColor = [UIColor whiteColor];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:self.tableView];

    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(24.0, 0.0, self.view.bounds.size.width - 48.0, 80.0)];
    self.emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.emptyLabel.center = CGPointMake(CGRectGetMidX(self.view.bounds),
                                         self.view.bounds.size.height * 0.36);
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [UIFont systemFontOfSize:14.0];
    self.emptyLabel.textColor = TNGrayTextColor();
    self.emptyLabel.backgroundColor = [UIColor clearColor];
    self.emptyLabel.userInteractionEnabled = NO;
    self.emptyLabel.text = @"No messages yet\nSend a message to start the conversation.";
    [self.view addSubview:self.emptyLabel];

    self.inputBar = [[UIView alloc] initWithFrame:CGRectMake(0,
                                                             self.view.bounds.size.height - 46.0,
                                                             self.view.bounds.size.width,
                                                             46.0)];
    self.inputBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.inputBar.backgroundColor = [UIColor colorWithRed:0.97 green:0.975 blue:0.98 alpha:1.0];
    [self.view addSubview:self.inputBar];

    UIView *topBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.inputBar.bounds.size.width, 0.5)];
    topBorder.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    topBorder.backgroundColor = TNSeparatorColor();
    [self.inputBar addSubview:topBorder];

    CGFloat sendWidth = 54.0;
    self.textView = [[UITextView alloc] initWithFrame:CGRectMake(8.0, 6.0,
                                                                self.inputBar.bounds.size.width - 8.0 - sendWidth,
                                                                34.0)];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.textView.backgroundColor = [UIColor whiteColor];
    self.textView.layer.cornerRadius = 8.0;
    self.textView.layer.borderWidth = 1.0;
    self.textView.layer.borderColor = TNSeparatorColor().CGColor;
    self.textView.font = [UIFont systemFontOfSize:15.0];
    self.textView.textColor = [UIColor colorWithRed:0.10 green:0.11 blue:0.13 alpha:1.0];
    self.textView.contentInset = UIEdgeInsetsMake(5.0, 4.0, 5.0, 4.0);
    self.textView.delegate = self;
    self.textView.scrollEnabled = YES;
    [self.inputBar addSubview:self.textView];

    self.placeholderLabel = [[UILabel alloc] initWithFrame:CGRectMake(13.0, 6.0, 120.0, 34.0)];
    self.placeholderLabel.font = [UIFont systemFontOfSize:15.0];
    self.placeholderLabel.textColor = [UIColor colorWithWhite:0.62 alpha:1.0];
    self.placeholderLabel.text = @"Message";
    self.placeholderLabel.userInteractionEnabled = NO;
    self.placeholderLabel.backgroundColor = [UIColor clearColor];
    [self.inputBar addSubview:self.placeholderLabel];

    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendButton.frame = CGRectMake(self.inputBar.bounds.size.width - sendWidth + 2.0, 6.0, sendWidth - 6.0, 34.0);
    self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    self.sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
    [self.sendButton setTitle:@"Send" forState:UIControlStateNormal];
    [self.sendButton setTitleColor:TNTealColor() forState:UIControlStateNormal];
    [self.sendButton setTitleColor:[UIColor colorWithWhite:0.7 alpha:1.0] forState:UIControlStateDisabled];
    self.sendButton.enabled = NO;
    [self.sendButton addTarget:self action:@selector(sendTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.inputBar addSubview:self.sendButton];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChange:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChange:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)dealloc {
    [self.pollTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self startPolling];
    [self reloadMessagesInitial:!self.didInitialLoad];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.pollTimer invalidate];
    self.pollTimer = nil;
    [self.view endEditing:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.pollTimer invalidate];
    self.pollTimer = nil;
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    if (self.view.window) {
        [self reloadMessagesInitial:NO];
    }
}

- (void)startPolling {
    [self.pollTimer invalidate];
    self.pollTimer = [NSTimer timerWithTimeInterval:4.0
                                            target:self
                                          selector:@selector(pollTimerFired:)
                                          userInfo:nil
                                           repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.pollTimer forMode:NSRunLoopCommonModes];
}

- (void)pollTimerFired:(NSTimer *)timer {
    if (!self.loading && !self.sending) {
        [self reloadMessagesInitial:NO];
    }
}

#pragma mark - Loading

- (BOOL)isNearBottom {
    CGFloat visibleBottom = self.tableView.contentOffset.y + self.tableView.bounds.size.height;
    return visibleBottom >= self.tableView.contentSize.height - 70.0;
}

- (void)reloadMessagesInitial:(BOOL)initial {
    if (self.loading) {
        return;
    }
    self.loading = YES;
    if (self.messages.count == 0) {
        [self updateEmptyState];
    }

    BOOL wasNearBottom = [self isNearBottom];

    __weak typeof(self) weakSelf = self;
    [[TNClient sharedClient] fetchMessagesForContact:self.conversation.contactValue
                                     beforeMessageId:nil
                                          completion:^(id result, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        self.loading = NO;

        if ([result isKindOfClass:[NSArray class]]) {
            self.lastErrorText = nil;
            NSArray *fetched = result;
            BOOL treatAsInitial = initial || !self.didInitialLoad;
            if (treatAsInitial) {
                self.messages = [fetched mutableCopy];
                self.didInitialLoad = YES;
                self.canLoadEarlier = fetched.count >= 30;
            } else {
                [self mergeMessages:fetched];
            }

            [self.tableView reloadData];
            [self updateTableHeader];
            [self updateEmptyState];

            if (treatAsInitial) {
                [self scrollToBottomAnimated:NO];
            } else if (wasNearBottom) {
                [self scrollToBottomAnimated:YES];
            }
            [self markReadIfNeeded];
        } else {
            self.lastErrorText = error.localizedDescription;
            [self updateEmptyState];
        }
    }];
}

- (void)mergeMessages:(NSArray *)newMessages {
    NSMutableDictionary *indexById = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < self.messages.count; i++) {
        TNMessage *message = self.messages[i];
        if (message.messageId.length) {
            indexById[message.messageId] = @(i);
        }
    }

    for (TNMessage *message in newMessages) {
        if (![message isKindOfClass:[TNMessage class]]) {
            continue;
        }
        NSNumber *index = message.messageId.length ? indexById[message.messageId] : nil;
        if (index) {
            self.messages[[index unsignedIntegerValue]] = message;
        } else {
            [self.messages addObject:message];
            if (message.messageId.length) {
                indexById[message.messageId] = @(self.messages.count - 1);
            }
        }
    }

    [self.messages sortUsingComparator:^NSComparisonResult(TNMessage *a, TNMessage *b) {
        if (!a.date && !b.date) return NSOrderedSame;
        if (!a.date) return NSOrderedAscending;
        if (!b.date) return NSOrderedDescending;
        return [a.date compare:b.date];
    }];
}

- (void)loadEarlierMessages {
    if (self.loadingEarlier || self.messages.count == 0) {
        return;
    }

    TNMessage *oldest = self.messages[0];
    if (!oldest.messageId.length) {
        self.canLoadEarlier = NO;
        [self updateTableHeader];
        return;
    }

    self.loadingEarlier = YES;
    self.earlierButton.enabled = NO;
    [self.earlierButton setTitle:@"Loading…" forState:UIControlStateNormal];

    CGSize oldContentSize = self.tableView.contentSize;
    CGFloat oldOffset = self.tableView.contentOffset.y;

    __weak typeof(self) weakSelf = self;
    [[TNClient sharedClient] fetchMessagesForContact:self.conversation.contactValue
                                     beforeMessageId:oldest.messageId
                                          completion:^(id result, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        self.loadingEarlier = NO;

        if ([result isKindOfClass:[NSArray class]]) {
            NSArray *older = result;
            self.canLoadEarlier = older.count >= 30;
            [self mergeMessages:older];
            [self.tableView reloadData];
            [self updateTableHeader];
            [self.tableView layoutIfNeeded];

            CGFloat delta = self.tableView.contentSize.height - oldContentSize.height;
            self.tableView.contentOffset = CGPointMake(0, MAX(0, oldOffset + delta));
        } else {
            self.earlierButton.enabled = YES;
            [self.earlierButton setTitle:@"Load Earlier Messages" forState:UIControlStateNormal];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't Load Messages"
                                                            message:error.localizedDescription
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
    }];
}

- (void)updateTableHeader {
    if (!self.canLoadEarlier) {
        self.tableView.tableHeaderView = nil;
        self.earlierButton = nil;
        return;
    }

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 40.0)];
    header.backgroundColor = [UIColor whiteColor];

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = header.bounds;
    button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    button.titleLabel.font = [UIFont systemFontOfSize:13.0];
    [button setTitle:@"Load Earlier Messages" forState:UIControlStateNormal];
    [button setTitleColor:TNTealColor() forState:UIControlStateNormal];
    [button addTarget:self action:@selector(loadEarlierMessages) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:button];

    self.earlierButton = button;
    self.tableView.tableHeaderView = header;
}

- (void)updateEmptyState {
    BOOL empty = self.messages.count == 0;
    self.emptyLabel.hidden = !empty;
    if (!empty) {
        return;
    }

    if (self.loading && !self.didInitialLoad) {
        self.emptyLabel.text = @"Loading messages…";
    } else if (self.lastErrorText.length) {
        self.emptyLabel.text = self.lastErrorText;
    } else if (self.didInitialLoad) {
        self.emptyLabel.text = @"No messages yet\nSend a message to start the conversation.";
    }
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView layoutIfNeeded];
        CGFloat offset = self.tableView.contentSize.height - self.tableView.bounds.size.height;
        if (offset < 0.0) {
            offset = 0.0;
        }
        [self.tableView setContentOffset:CGPointMake(0, offset) animated:animated];
    });
}

#pragma mark - Read state

- (void)markReadIfNeeded {
    if (self.markingRead || self.messages.count == 0) {
        return;
    }

    BOOL hasUnreadIncoming = NO;
    for (TNMessage *message in self.messages) {
        if (!message.isOutgoing && !message.read) {
            hasUnreadIncoming = YES;
            break;
        }
    }
    if (!hasUnreadIncoming) {
        return;
    }

    TNMessage *latest = [self.messages lastObject];
    if (!latest.messageId.length) {
        return;
    }

    self.markingRead = YES;
    __weak typeof(self) weakSelf = self;
    [[TNClient sharedClient] markConversationRead:self.conversation.contactValue
                                  latestMessageId:latest.messageId
                                       completion:^(id result, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        self.markingRead = NO;
        if (!error) {
            for (TNMessage *message in self.messages) {
                message.read = YES;
            }
            self.conversation.unreadCount = 0;
        }
    }];
}

#pragma mark - Sending

- (void)updateSendState {
    NSString *text = [self.textView.text stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.sendButton.enabled = !self.sending && text.length > 0;
    self.placeholderLabel.hidden = self.textView.text.length > 0;
}

- (void)sendTapped {
    if (self.sending) {
        return;
    }

    NSString *text = [self.textView.text stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!text.length) {
        return;
    }

    self.textView.text = @"";
    [self updateSendState];
    self.sending = YES;
    [self updateSendState];

    __weak typeof(self) weakSelf = self;
    [[TNClient sharedClient] sendMessage:text
                               toContact:self.conversation.contactValue
                              completion:^(id result, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        self.sending = NO;
        if (error) {
            if (!self.textView.text.length) {
                self.textView.text = text;
            }
            [self updateSendState];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Message Not Sent"
                                                            message:error.localizedDescription
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }

        [self updateSendState];
        [self reloadMessagesInitial:NO];
    }];
}

#pragma mark - Keyboard

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
        self.keyboardHeight = overlap;
        [self layoutForKeyboard];
    } completion:^(BOOL finished) {
        if (overlap == 0.0) {
            [self scrollToBottomAnimated:NO];
        }
    }];
}

- (void)layoutForKeyboard {
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    CGFloat barHeight = 46.0;
    CGFloat bottom = self.keyboardHeight;

    self.inputBar.frame = CGRectMake(0, height - bottom - barHeight, width, barHeight);
    self.tableView.frame = CGRectMake(0, 0, width, height - bottom - barHeight);
    self.emptyLabel.center = CGPointMake(width / 2.0, (height - bottom) * 0.36);
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    [self updateSendState];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= (NSInteger)self.messages.count) {
        return 44.0;
    }
    return [TNMessageCell heightForMessage:self.messages[indexPath.row] width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"TNMessageCell";
    TNMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[TNMessageCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    if (indexPath.row < (NSInteger)self.messages.count) {
        cell.message = self.messages[indexPath.row];
    }
    return cell;
}

@end
