//
//  TNClient.h
//  TextNow Legacy
//

#import <Foundation/Foundation.h>
#import "TN.h"

typedef void (^TNCompletion)(id result, NSError *error);

@interface TNClient : NSObject

@property (nonatomic, copy, readonly) NSString *username;
@property (nonatomic, assign, readonly) BOOL isAuthenticated;

+ (instancetype)sharedClient;

- (BOOL)hasStoredSession;
- (void)validateSessionWithCompletion:(TNCompletion)completion;
- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
         rememberPassword:(BOOL)remember
               completion:(TNCompletion)completion;
- (void)logout;

- (void)fetchConversationsWithCompletion:(TNCompletion)completion;
- (void)fetchMessagesForContact:(NSString *)contactValue
                beforeMessageId:(NSString *)beforeId
                     completion:(TNCompletion)completion;
- (void)sendMessage:(NSString *)text
          toContact:(NSString *)contactValue
         completion:(TNCompletion)completion;
- (void)markConversationRead:(NSString *)contactValue
             latestMessageId:(NSString *)messageId
                  completion:(TNCompletion)completion;

- (NSString *)normalizedContactValue:(NSString *)raw;

@end
