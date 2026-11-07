//
//  TNKeychain.h
//  TextNow Legacy
//

#import <Foundation/Foundation.h>

@interface TNKeychain : NSObject

+ (BOOL)setData:(NSData *)data forAccount:(NSString *)account;
+ (NSData *)dataForAccount:(NSString *)account;
+ (BOOL)deleteAccount:(NSString *)account;

+ (BOOL)setPassword:(NSString *)password;
+ (NSString *)password;
+ (void)deletePassword;

@end
