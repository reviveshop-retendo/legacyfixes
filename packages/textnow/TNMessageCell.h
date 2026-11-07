//
//  TNMessageCell.h
//  TextNow Legacy
//

#import <UIKit/UIKit.h>
#import "TNModels.h"

@interface TNMessageCell : UITableViewCell

@property (nonatomic, strong) TNMessage *message;

+ (CGFloat)heightForMessage:(TNMessage *)message width:(CGFloat)width;

@end
