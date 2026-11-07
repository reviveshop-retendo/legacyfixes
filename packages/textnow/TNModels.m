//
//  TNModels.m
//  TextNow Legacy
//

#import "TNModels.h"
#import "TN.h"

NSString * const TNErrorDomain = @"com.legacyfixes.textnow";
NSString * const TNSessionExpiredNotification = @"TNSessionExpiredNotification";
NSString * const TNLoggedOutNotification = @"TNLoggedOutNotification";

#pragma mark - Value helpers

NSString *TNString(id value) {
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value stringValue];
    }
    return nil;
}

NSString *TNPercentEncode(NSString *value) {
    static NSCharacterSet *allowed = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allowed = [NSCharacterSet characterSetWithCharactersInString:
                   @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    });
    if (!value.length) {
        return @"";
    }
    return [value stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: value;
}

NSString *TNFormEncode(NSString *value) {
    return TNPercentEncode(value);
}

static id TNFirstValue(NSDictionary *dictionary, NSArray *keys) {
    for (NSString *key in keys) {
        id value = dictionary[key];
        if (value && value != [NSNull null]) {
            return value;
        }
    }
    return nil;
}

static NSDate *TNDateFromString(NSString *string) {
    if (!string.length) {
        return nil;
    }

    static NSArray *formats = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formats = @[
            @"yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            @"yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            @"yyyy-MM-dd'T'HH:mm:ssXXXXX",
            @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            @"yyyy-MM-dd'T'HH:mm:ss'Z'",
            @"yyyy-MM-dd'T'HH:mm:ss.SSS",
            @"yyyy-MM-dd'T'HH:mm:ss",
            @"yyyy-MM-dd HH:mm:ss",
            @"yyyy-MM-dd",
        ];
    });

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];

    for (NSString *format in formats) {
        formatter.dateFormat = format;
        NSDate *date = [formatter dateFromString:string];
        if (date) {
            return date;
        }
    }
    return nil;
}

NSDate *TNDateFromObject(id value) {
    if ([value isKindOfClass:[NSDate class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        double number = [value doubleValue];
        if (number <= 0) {
            return nil;
        }
        if (number > 100000000000.0) {
            number /= 1000.0;
        }
        return [NSDate dateWithTimeIntervalSince1970:number];
    }
    NSString *string = TNString(value);
    if (!string.length) {
        return nil;
    }
    NSDate *date = TNDateFromString(string);
    if (date) {
        return date;
    }
    double number = [string doubleValue];
    if (number > 0) {
        if (number > 100000000000.0) {
            number /= 1000.0;
        }
        return [NSDate dateWithTimeIntervalSince1970:number];
    }
    return nil;
}

NSString *TNISO8601String(NSDate *date) {
    if (!date) {
        date = [NSDate date];
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    return [formatter stringFromDate:date];
}

static NSDate *TNStartOfDay(NSDate *date) {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *start = nil;
    [calendar rangeOfUnit:NSCalendarUnitDay startDate:&start interval:NULL forDate:date];
    return start ?: date;
}

NSString *TNTimeString(NSDate *date) {
    if (!date) {
        return @"";
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale currentLocale];
    formatter.dateFormat = @"h:mm a";
    return [formatter stringFromDate:date];
}

static NSInteger TNDayDifference(NSDate *from, NSDate *to) {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:NSCalendarUnitDay
                                               fromDate:TNStartOfDay(from)
                                                 toDate:TNStartOfDay(to)
                                                options:0];
    return components.day;
}

NSString *TNRelativeDateString(NSDate *date) {
    if (!date) {
        return @"";
    }

    NSDate *now = [NSDate date];
    NSInteger days = TNDayDifference(date, now);
    if (days <= 0) {
        return TNTimeString(date);
    }
    if (days == 1) {
        return @"Yesterday";
    }
    if (days < 7) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale currentLocale];
        formatter.dateFormat = @"EEE";
        return [formatter stringFromDate:date];
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale currentLocale];
    formatter.dateFormat = @"M/d/yy";
    return [formatter stringFromDate:date];
}

NSString *TNThreadTimestampString(NSDate *date) {
    if (!date) {
        return @"";
    }
    NSDate *now = [NSDate date];
    if (TNDayDifference(date, now) == 0) {
        return TNTimeString(date);
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale currentLocale];
    formatter.dateFormat = @"M/d/yy h:mm a";
    return [formatter stringFromDate:date];
}

NSString *TNFormattedPhoneNumber(NSString *number) {
    NSString *trimmed = [number stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) {
        return @"";
    }

    NSMutableString *digits = [NSMutableString string];
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar character = [trimmed characterAtIndex:i];
        if (character >= '0' && character <= '9') {
            [digits appendFormat:@"%C", character];
        }
    }

    if (digits.length == 11 && [digits hasPrefix:@"1"]) {
        NSString *area = [digits substringWithRange:NSMakeRange(1, 3)];
        NSString *prefix = [digits substringWithRange:NSMakeRange(4, 3)];
        NSString *line = [digits substringWithRange:NSMakeRange(7, 4)];
        return [NSString stringWithFormat:@"(%@) %@-%@", area, prefix, line];
    }
    if (digits.length == 10) {
        NSString *area = [digits substringWithRange:NSMakeRange(0, 3)];
        NSString *prefix = [digits substringWithRange:NSMakeRange(3, 3)];
        NSString *line = [digits substringWithRange:NSMakeRange(6, 4)];
        return [NSString stringWithFormat:@"(%@) %@-%@", area, prefix, line];
    }
    return trimmed;
}

NSString *TNPreviewText(NSString *text, NSInteger messageType) {
    if (messageType == 2) {
        return @"[Photo]";
    }
    if (messageType == 4) {
        return @"[Video]";
    }
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) {
        return @"[Empty message]";
    }
    NSString *singleLine = [trimmed stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    return singleLine;
}

#pragma mark - Conversation

@implementation TNConversation

+ (instancetype)conversationWithDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    TNConversation *conversation = [[TNConversation alloc] init];

    conversation.contactValue = TNString(TNFirstValue(dictionary, @[
        @"contact_value", @"e164_contact_value", @"number", @"phone_number"
    ]));
    conversation.name = TNString(TNFirstValue(dictionary, @[
        @"name", @"contact_name", @"display_name", @"full_name"
    ]));

    id lastMessage = TNFirstValue(dictionary, @[@"last_message", @"latest_message"]);
    NSDictionary *lastDictionary = [lastMessage isKindOfClass:[NSDictionary class]] ? lastMessage : nil;

    if (lastDictionary) {
        conversation.lastMessage = TNString(TNFirstValue(lastDictionary, @[@"message", @"text", @"content"]));
        conversation.lastMessageDate = TNDateFromObject(TNFirstValue(lastDictionary, @[@"date", @"created_at"]));
        conversation.lastMessageId = TNString(TNFirstValue(lastDictionary, @[@"id", @"message_id"]));
        conversation.lastMessageDirection = [TNFirstValue(lastDictionary, @[@"message_direction", @"direction"]) integerValue];
    } else {
        conversation.lastMessage = TNString(lastMessage);
        if (!conversation.lastMessage.length) {
            conversation.lastMessage = TNString(TNFirstValue(dictionary, @[@"message", @"preview"]));
        }
        conversation.lastMessageDate = TNDateFromObject(TNFirstValue(dictionary, @[
            @"last_message_date", @"latest_message_date", @"last_activity", @"updated_at", @"date"
        ]));
        conversation.lastMessageId = TNString(TNFirstValue(dictionary, @[
            @"last_message_id", @"latest_message_id", @"message_id"
        ]));
        conversation.lastMessageDirection = [TNFirstValue(dictionary, @[
            @"last_message_direction", @"message_direction", @"direction"
        ]) integerValue];
    }

    conversation.unreadCount = [TNFirstValue(dictionary, @[
        @"unread_count", @"unread", @"num_unread", @"unread_messages"
    ]) integerValue];

    if (conversation.unreadCount == 0) {
        id read = TNFirstValue(dictionary, @[@"read"]);
        if ([read isKindOfClass:[NSNumber class]] && ![read boolValue]) {
            conversation.unreadCount = 1;
        }
    }

    if (!conversation.lastMessageDate) {
        conversation.lastMessageDate = TNDateFromObject(TNFirstValue(dictionary, @[
            @"created_at", @"timestamp"
        ]));
    }

    return conversation;
}

- (NSString *)displayName {
    NSString *trimmed = [self.name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length) {
        return trimmed;
    }
    NSString *formatted = TNFormattedPhoneNumber(self.contactValue);
    return formatted.length ? formatted : (self.contactValue ?: @"Unknown");
}

- (NSString *)previewText {
    NSString *preview = TNPreviewText(self.lastMessage, 0);
    if (self.lastMessageDirection == 2 && preview.length) {
        return [@"You: " stringByAppendingString:preview];
    }
    return preview;
}

@end

#pragma mark - Message

@implementation TNMessage

+ (instancetype)messageWithDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    TNMessage *message = [[TNMessage alloc] init];
    message.messageId = TNString(TNFirstValue(dictionary, @[@"id", @"message_id"]));
    message.contactValue = TNString(TNFirstValue(dictionary, @[
        @"contact_value", @"e164_contact_value", @"number"
    ]));
    message.text = TNString(TNFirstValue(dictionary, @[@"message", @"text", @"content"]));
    message.date = TNDateFromObject(TNFirstValue(dictionary, @[@"date", @"created_at", @"timestamp"]));
    message.messageType = [TNFirstValue(dictionary, @[@"message_type", @"type"]) integerValue];
    if (message.messageType == 0) {
        message.messageType = 1;
    }
    message.direction = [TNFirstValue(dictionary, @[@"message_direction", @"direction"]) integerValue];

    id read = TNFirstValue(dictionary, @[@"read"]);
    message.read = [read respondsToSelector:@selector(boolValue)] ? [read boolValue] : YES;

    return message;
}

- (BOOL)isOutgoing {
    return self.direction == 2;
}

- (NSString *)displayText {
    if (self.messageType == 2) {
        return @"[Photo]";
    }
    if (self.messageType == 4) {
        return @"[Video]";
    }
    NSString *trimmed = [self.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length ? trimmed : @"[Empty message]";
}

@end
