#import "PVPasswordStore.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonKeyDerivation.h>
#import <CommonCrypto/CommonCryptor.h>

static NSString * const PVPasswordService = @"com.aosaid.privacyvault.password-verifiers";
static NSString * const PVPassword1Account = @"password1";
static NSString * const PVPassword2Account = @"password2";
static const uint32_t PVPasswordVerifierVersion = 1;
static const size_t PVSaltLength = 16;
static const size_t PVDerivedKeyLength = 32;
static const uint32_t PVPBKDF2Iterations = 120000;

@interface PVPasswordStore ()
- (nullable NSData *)verifierForAccount:(NSString *)account;
- (BOOL)storeVerifier:(NSData *)verifier account:(NSString *)account error:(NSError **)error;
- (BOOL)deleteVerifierForAccount:(NSString *)account;
- (nullable NSData *)makeVerifierForPassword:(NSString *)password;
- (BOOL)verifyPassword:(NSString *)password account:(NSString *)account error:(NSError **)error;
@end

@implementation PVPasswordStore

+ (instancetype)sharedStore {
    static PVPasswordStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ store = [[self alloc] init]; });
    return store;
}

- (BOOL)isConfigured {
    NSData *password1 = [self verifierForAccount:PVPassword1Account];
    NSData *password2 = [self verifierForAccount:PVPassword2Account];
    return password1.length == (1 + PVSaltLength + PVDerivedKeyLength) &&
           password2.length == (1 + PVSaltLength + PVDerivedKeyLength);
}

- (BOOL)savePassword1:(NSString *)password1 password2:(NSString *)password2 error:(NSError **)error {
    NSData *verifier1 = [self makeVerifierForPassword:password1];
    NSData *verifier2 = [self makeVerifierForPassword:password2];
    if (!verifier1 || !verifier2) {
        if (error) *error = [NSError errorWithDomain:PVPasswordService code:-1 userInfo:@{NSLocalizedDescriptionKey: @"تعذر إنشاء بيانات التحقق الآمنة"}];
        return NO;
    }

    if (![self storeVerifier:verifier1 account:PVPassword1Account error:error]) {
        return NO;
    }
    if (![self storeVerifier:verifier2 account:PVPassword2Account error:error]) {
        [self deleteVerifierForAccount:PVPassword1Account];
        return NO;
    }
    return YES;
}

- (BOOL)verifyPassword1:(NSString *)password error:(NSError **)error {
    return [self verifyPassword:password account:PVPassword1Account error:error];
}

- (BOOL)verifyPassword2:(NSString *)password error:(NSError **)error {
    return [self verifyPassword:password account:PVPassword2Account error:error];
}

- (NSData *)makeVerifierForPassword:(NSString *)password {
    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    if (passwordData.length == 0 || passwordData.length > 1024) return nil;

    uint8_t salt[PVSaltLength];
    int randomStatus = SecRandomCopyBytes(kSecRandomDefault, sizeof(salt), salt);
    if (randomStatus != errSecSuccess) return nil;

    uint8_t derived[PVDerivedKeyLength];
    int status = CCKeyDerivationPBKDF(kCCPBKDF2,
                                      passwordData.bytes,
                                      passwordData.length,
                                      salt,
                                      sizeof(salt),
                                      kCCPRFHmacAlgSHA256,
                                      PVPBKDF2Iterations,
                                      derived,
                                      sizeof(derived));
    if (status != kCCSuccess) return nil;

    NSMutableData *verifier = [NSMutableData dataWithCapacity:1 + sizeof(salt) + sizeof(derived)];
    uint8_t version = (uint8_t)PVPasswordVerifierVersion;
    [verifier appendBytes:&version length:sizeof(version)];
    [verifier appendBytes:salt length:sizeof(salt)];
    [verifier appendBytes:derived length:sizeof(derived)];
    memset(derived, 0, sizeof(derived));
    return verifier;
}

- (BOOL)verifyPassword:(NSString *)password account:(NSString *)account error:(NSError **)error {
    NSData *stored = [self verifierForAccount:account];
    if (stored.length != (1 + PVSaltLength + PVDerivedKeyLength)) return NO;

    const uint8_t *bytes = stored.bytes;
    if (bytes[0] != PVPasswordVerifierVersion) return NO;
    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    if (passwordData.length == 0 || passwordData.length > 1024) return NO;

    uint8_t derived[PVDerivedKeyLength];
    int status = CCKeyDerivationPBKDF(kCCPBKDF2,
                                      passwordData.bytes,
                                      passwordData.length,
                                      bytes + 1,
                                      PVSaltLength,
                                      kCCPRFHmacAlgSHA256,
                                      PVPBKDF2Iterations,
                                      derived,
                                      sizeof(derived));
    if (status != kCCSuccess) {
        memset(derived, 0, sizeof(derived));
        if (error) *error = [NSError errorWithDomain:PVPasswordService code:status userInfo:@{NSLocalizedDescriptionKey: @"تعذر التحقق من كلمة المرور"}];
        return NO;
    }

    const uint8_t *expected = bytes + 1 + PVSaltLength;
    uint8_t difference = 0;
    for (size_t index = 0; index < PVDerivedKeyLength; index++) {
        difference |= (uint8_t)(derived[index] ^ expected[index]);
    }
    memset(derived, 0, sizeof(derived));
    return difference == 0;
}

- (NSData *)verifierForAccount:(NSString *)account {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: PVPasswordService,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || !result) return nil;
    return [(__bridge NSData *)result copy];
}

- (BOOL)storeVerifier:(NSData *)verifier account:(NSString *)account error:(NSError **)error {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: PVPasswordService,
        (__bridge id)kSecAttrAccount: account
    };
    NSDictionary *attributes = @{
        (__bridge id)kSecValueData: verifier,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    };
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
    if (status == errSecItemNotFound) {
        NSMutableDictionary *item = [query mutableCopy];
        [item addEntriesFromDictionary:attributes];
        status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
    }
    if (status != errSecSuccess) {
        if (error) *error = [NSError errorWithDomain:PVPasswordService code:status userInfo:@{NSLocalizedDescriptionKey: @"تعذر حفظ بيانات التحقق في Keychain"}];
        return NO;
    }
    return YES;
}

- (BOOL)deleteVerifierForAccount:(NSString *)account {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: PVPasswordService,
        (__bridge id)kSecAttrAccount: account
    };
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    return status == errSecSuccess || status == errSecItemNotFound;
}

@end
