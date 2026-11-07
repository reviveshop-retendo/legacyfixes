//
//  TNModels.h
//  TextNow Legacy
//

#import <Foundation/Foundation.h>

@class TNConversation;

@interface TNConversation : NSObject

@property (nonatomic, copy) NSString *contactValue;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *lastMessage;
@property (nonatomic, copy) NSString *lastMessageId;
@property (nonatomic, strong) NSDate *lastMessageDate;
@property (nonatomic, assign) NSInteger lastMessageDirection;
@property (nonatomic, assign) NSInteger unreadCount;

+ (instancetype)conversationWithDictionary:(NSDictionary *)dictionary;

/** Contact name if TextNow knows one, otherwise a formatted phone number. */
- (NSString *)displayName;

/** Last-message preview, with "You: " when the last message was outgoing. */
- (NSString *)previewText;

@end


@interface TNMessage : NSObject

@property (nonatomic, copy) NSString *messageId;
@property (nonatomic, copy) NSString *contactValue;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, assign) NSInteger messageType;
@property (nonatomic, assign) NSInteger direction;
@property (nonatomic, assign) BOOL read;

+ (instancetype)messageWithDictionary:(NSDictionary *)dictionary;

- (BOOL)isOutgoing;
- (NSString *)displayText;

@end
