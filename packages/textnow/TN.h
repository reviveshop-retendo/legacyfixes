//
//  TN.h
//  TextNow Legacy
//
//  Shared constants and small helpers.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

extern NSString * const TNErrorDomain;
extern NSString * const TNSessionExpiredNotification;
extern NSString * const TNLoggedOutNotification;

static NSString * const TNBaseURL = @"https://www.textnow.com";
static NSString * const TNDefaultsUsernameKey = @"TNUsername";
static NSString * const TNDefaultsRememberKey = @"TNRememberPassword";

static inline UIColor *TNTealColor(void) {
    return [UIColor colorWithRed:0.00 green:0.62 blue:0.59 alpha:1.0];
}

static inline UIColor *TNIncomingBubbleColor(void) {
    return [UIColor colorWithRed:0.91 green:0.92 blue:0.94 alpha:1.0];
}

static inline UIColor *TNGrayTextColor(void) {
    return [UIColor colorWithRed:0.44 green:0.47 blue:0.52 alpha:1.0];
}

static inline UIColor *TNSeparatorColor(void) {
    return [UIColor colorWithRed:0.88 green:0.89 blue:0.91 alpha:1.0];
}

static inline UIColor *TNFieldColor(void) {
    return [UIColor colorWithRed:0.96 green:0.965 blue:0.97 alpha:1.0];
}

/** Coerces a JSON value into a string without ever returning a non-string object. */
NSString *TNString(id value);

/** Percent-encodes a single URL path or query component. */
NSString *TNPercentEncode(NSString *value);

/** Percent-encodes a value for an application/x-www-form-urlencoded body. */
NSString *TNFormEncode(NSString *value);

/** Returns a UTC ISO-8601 timestamp suitable for the TextNow send API. */
NSString *TNISO8601String(NSDate *date);

/** Parses the several date shapes TextNow uses (ISO strings or epoch numbers). */
NSDate *TNDateFromObject(id value);

/** Short time such as 3:42 PM. */
NSString *TNTimeString(NSDate *date);

/** List-cell timestamp: time today, Yesterday, weekday, or a short date. */
NSString *TNRelativeDateString(NSDate *date);

/** Chat timestamp: time today, otherwise a short date and time. */
NSString *TNThreadTimestampString(NSDate *date);

/** Formats +1XXXXXXXXXX as (XXX) XXX-XXXX; leaves other numbers alone. */
NSString *TNFormattedPhoneNumber(NSString *number);

/** Turns a message body/type into a short list preview. */
NSString *TNPreviewText(NSString *text, NSInteger messageType);
