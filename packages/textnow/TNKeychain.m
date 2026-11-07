//
//  TNKeychain.m
//  TextNow Legacy
//

#import "TNKeychain.h"
#import <Security/Security.h>

static NSString * const TNKeychainService = @"com.legacyfixes.textnow";
static NSString * const TNPasswordAccount = @"account-password";

@implementation TNKeychain

+ (NSDictionary *)baseQueryForAccount:(NSString *)account {
    return @{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: TNKeychainService,
        (__bridge id)kSecAttrAccount: account,
    };
}

+ (BOOL)setData:(NSData *)data forAccount:(NSString *)account {
    if (!account.length || !data) {
        return NO;
    }

    NSDictionary *query = [self baseQueryForAccount:account];
    SecItemDelete((__bridge CFDictionaryRef)query);

    NSMutableDictionary *item = [query mutableCopy];
    item[(__bridge id)kSecValueData] = data;
    item[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlocked;

    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
    return status == errSecSuccess;
}

+ (NSData *)dataForAccount:(NSString *)account {
    if (!account.length) {
        return nil;
    }

    NSMutableDictionary *query = [[self baseQueryForAccount:account] mutableCopy];
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || result == NULL) {
        return nil;
    }
    return (__bridge_transfer NSData *)result;
}

+ (BOOL)deleteAccount:(NSString *)account {
    if (!account.length) {
        return NO;
    }
    NSDictionary *query = [self baseQueryForAccount:account];
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    return status == errSecSuccess || status == errSecItemNotFound;
}

+ (BOOL)setPassword:(NSString *)password {
    if (!password.length) {
        [self deletePassword];
        return YES;
    }
    NSData *data = [password dataUsingEncoding:NSUTF8StringEncoding];
    return [self setData:data forAccount:TNPasswordAccount];
}

+ (NSString *)password {
    NSData *data = [self dataForAccount:TNPasswordAccount];
    if (!data.length) {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (void)deletePassword {
    [self deleteAccount:TNPasswordAccount];
}

@end
