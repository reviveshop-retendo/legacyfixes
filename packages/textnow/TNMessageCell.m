//
//  TNMessageCell.m
//  TextNow Legacy
//

#import "TNMessageCell.h"
#import "TN.h"
#import <QuartzCore/QuartzCore.h>

static UIFont *TNMessageFont(void) {
    return [UIFont systemFontOfSize:15.5];
}

static CGFloat TNMessageHorizontalMargin(void) {
    return 12.0;
}

static CGFloat TNMessageMaxBubbleWidth(CGFloat width) {
    return MIN(250.0, width * 0.75);
}

@interface TNMessageCell ()

@property (nonatomic, strong) UIView *bubbleView;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UILabel *timeLabel;

@end

@implementation TNMessageCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];

        _bubbleView = [[UIView alloc] init];
        _bubbleView.layer.cornerRadius = 16.0;
        _bubbleView.clipsToBounds = YES;
        [self.contentView addSubview:_bubbleView];

        _messageLabel = [[UILabel alloc] init];
        _messageLabel.font = TNMessageFont();
        _messageLabel.numberOfLines = 0;
        _messageLabel.backgroundColor = [UIColor clearColor];
        [_bubbleView addSubview:_messageLabel];

        _timeLabel = [[UILabel alloc] init];
        _timeLabel.font = [UIFont systemFontOfSize:10.5];
        _timeLabel.textColor = TNGrayTextColor();
        _timeLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_timeLabel];
    }
    return self;
}

- (void)setMessage:(TNMessage *)message {
    _message = message;

    self.messageLabel.text = message.displayText;
    self.timeLabel.text = TNThreadTimestampString(message.date);

    if (message.isOutgoing) {
        self.bubbleView.backgroundColor = TNTealColor();
        self.messageLabel.textColor = [UIColor whiteColor];
    } else {
        self.bubbleView.backgroundColor = TNIncomingBubbleColor();
        self.messageLabel.textColor = [UIColor colorWithRed:0.10 green:0.11 blue:0.13 alpha:1.0];
    }

    [self setNeedsLayout];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.message = nil;
    self.messageLabel.text = nil;
    self.timeLabel.text = nil;
}

+ (CGSize)textSizeForMessage:(TNMessage *)message width:(CGFloat)width {
    CGFloat textWidth = TNMessageMaxBubbleWidth(width) - 20.0;
    NSString *text = message.displayText ?: @"";
    CGRect rect = [text boundingRectWithSize:CGSizeMake(textWidth, CGFLOAT_MAX)
                                     options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                  attributes:@{NSFontAttributeName: TNMessageFont()}
                                     context:nil];
    CGFloat height = ceil(rect.size.height);
    if (height < 19.0) {
        height = 19.0;
    }
    return CGSizeMake(ceil(rect.size.width), height);
}

+ (CGFloat)heightForMessage:(TNMessage *)message width:(CGFloat)width {
    CGSize size = [self textSizeForMessage:message width:width];
    return size.height + 14.0 + 26.0;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = self.contentView.bounds.size.width;
    CGSize textSize = [[self class] textSizeForMessage:self.message width:width];

    CGFloat bubbleWidth = textSize.width + 20.0;
    CGFloat bubbleHeight = textSize.height + 14.0;
    CGFloat bubbleY = 4.0;

    BOOL outgoing = [self.message isOutgoing];
    CGFloat bubbleX = outgoing
        ? width - TNMessageHorizontalMargin() - bubbleWidth
        : TNMessageHorizontalMargin();

    self.bubbleView.frame = CGRectMake(bubbleX, bubbleY, bubbleWidth, bubbleHeight);
    self.messageLabel.frame = CGRectMake(10.0, 7.0, textSize.width, textSize.height);

    CGFloat timeY = CGRectGetMaxY(self.bubbleView.frame) + 2.0;
    if (outgoing) {
        self.timeLabel.textAlignment = NSTextAlignmentRight;
        self.timeLabel.frame = CGRectMake(width - TNMessageHorizontalMargin() - 100.0, timeY, 100.0, 13.0);
    } else {
        self.timeLabel.textAlignment = NSTextAlignmentLeft;
        self.timeLabel.frame = CGRectMake(TNMessageHorizontalMargin(), timeY, 100.0, 13.0);
    }
}

@end
