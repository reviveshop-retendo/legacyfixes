//
//  TNLoginViewController.h
//  TextNow Legacy
//

#import <UIKit/UIKit.h>

@interface TNLoginViewController : UIViewController

@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) void (^onSignIn)(void);

@end
