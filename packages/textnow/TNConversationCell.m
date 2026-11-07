//
//  TNConversationCell.m
//  TextNow Legacy
//

#import "TNConversationCell.h"
#import "TN.h"
#import <QuartzCore/QuartzCore.h>

@interface TNConversationCell ()

@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *previewLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *badgeLabel;

@end

@implementation TNConversationCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.contentView.backgroundColor = [UIColor whiteColor];

        UIView *selected = [[UIView alloc] initWithFrame:self.bounds];
        selected.backgroundColor = [UIColor colorWithRed:0.94 green:0.97 blue:0.97 alpha:1.0];
        self.selectedBackgroundView = selected;

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [UIFont boldSystemFontOfSize:17.0];
        _nameLabel.textColor = [UIColor colorWithRed:0.10 green:0.11 blue:0.13 alpha:1.0];
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _nameLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_nameLabel];

        _previewLabel = [[UILabel alloc] init];
        _previewLabel.font = [UIFont systemFontOfSize:14.0];
        _previewLabel.textColor = TNGrayTextColor();
        _previewLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _previewLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_previewLabel];

        _timeLabel = [[UILabel alloc] init];
        _timeLabel.font = [UIFont systemFontOfSize:12.0];
        _timeLabel.textColor = TNGrayTextColor();
        _timeLabel.textAlignment = NSTextAlignmentRight;
        _timeLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_timeLabel];

        _badgeLabel = [[UILabel alloc] init];
        _badgeLabel.font = [UIFont boldSystemFontOfSize:10.5];
        _badgeLabel.textColor = [UIColor whiteColor];
        _badgeLabel.backgroundColor = TNTealColor();
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        _badgeLabel.layer.cornerRadius = 9.0;
        _badgeLabel.clipsToBounds = YES;
        [self.contentView addSubview:_badgeLabel];
    }
    return self;
}

- (void)setConversation:(TNConversation *)conversation {
    _conversation = conversation;

    self.nameLabel.text = conversation.displayName;
    self.previewLabel.text = conversation.previewText;
    self.timeLabel.text = TNRelativeDateString(conversation.lastMessageDate);

    if (conversation.unreadCount > 0) {
        self.badgeLabel.hidden = NO;
        self.badgeLabel.text = conversation.unreadCount > 99
            ? @"99+"
            : [NSString stringWithFormat:@"%ld", (long)conversation.unreadCount];
        self.previewLabel.textColor = [UIColor colorWithRed:0.20 green:0.22 blue:0.25 alpha:1.0];
    } else {
        self.badgeLabel.hidden = YES;
        self.badgeLabel.text = nil;
        self.previewLabel.textColor = TNGrayTextColor();
    }

    self.accessibilityLabel = [NSString stringWithFormat:@"%@. %@. %@",
                               conversation.displayName,
                               conversation.previewText ?: @"",
                               self.timeLabel.text ?: @""];

    [self setNeedsLayout];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.conversation = nil;
    self.nameLabel.text = nil;
    self.previewLabel.text = nil;
    self.timeLabel.text = nil;
    self.badgeLabel.text = nil;
    self.badgeLabel.hidden = YES;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = self.contentView.bounds.size.width;
    CGFloat right = 16.0;
    CGFloat timeWidth = 68.0;

    self.nameLabel.frame = CGRectMake(16.0, 12.0,
                                      width - 16.0 - right - timeWidth - 8.0, 22.0);
    self.timeLabel.frame = CGRectMake(width - right - timeWidth, 14.0, timeWidth, 18.0);

    CGFloat badgeWidth = self.badgeLabel.hidden ? 0.0 : 28.0;
    CGFloat previewWidth = width - 16.0 - right - badgeWidth;
    self.previewLabel.frame = CGRectMake(16.0, 37.0, previewWidth, 20.0);

    if (!self.badgeLabel.hidden) {
        self.badgeLabel.frame = CGRectMake(width - right - 22.0, 38.0, 22.0, 18.0);
    }
}

@end
