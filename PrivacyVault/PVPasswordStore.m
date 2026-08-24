#import "PVPasswordStore.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonCryptoError.h>
#import <CommonCrypto/CommonKeyDerivation.h>
#include <sys/stat.h>

static NSString * const PVPasswordService = @"com.aosaid.privacyvault.password-verifiers";
static NSString * const PVPassword1Account = @"password1";
static NSString * const PVPassword2Account = @"password2";
static NSString * const PVFilePassword1Key = @"password1";
static NSString * const PVFilePassword2Key = @"password2";
static const uint8_t PVPasswordVerifierVersion = 1;
static const size_t PVSaltLength = 16;
static const size_t PVDerivedKeyLength = 32;
static const uint32_t PVPBKDF2Iterations = 120000;

@interface PVPasswordStore ()
- (nullable NSData *)verifierForAccount:(NSString *)account;
- (nullable NSData *)fileVerifierForKey:(NSString *)key;
- (BOOL)storeVerifier:(NSData *)verifier account:(NSString *)account error:(NSError **)error;
- (BOOL)storeFileVerifier:(NSData *)verifier key:(NSString *)key error:(NSError **)error;
- (BOOL)deleteVerifierForAccount:(NSString *)account;
- (nullable NSData *)makeVerifierForPassword:(NSString *)password;
- (BOOL)verifyPassword:(NSString *)password account:(NSString *)account fileKey:(NSString *)fileKey error:(NSError **)error;
- (NSString *)verifierFilePath;
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
    if ([self isValidVerifier:password1] && [self isValidVerifier:password2]) return YES;

    NSData *filePassword1 = [self fileVerifierForKey:PVFilePassword1Key];
    NSData *filePassword2 = [self fileVerifierForKey:PVFilePassword2Key];
    return [self isValidVerifier:filePassword1] && [self isValidVerifier:filePassword2];
}

- (BOOL)savePassword1:(NSString *)password1 password2:(NSString *)password2 error:(NSError **)error {
    NSData *verifier1 = [self makeVerifierForPassword:password1];
    NSData *verifier2 = [self makeVerifierForPassword:password2];
    if (!verifier1 || !verifier2) {
        if (error) *error = [NSError errorWithDomain:PVPasswordService code:-1 userInfo:@{NSLocalizedDescriptionKey: @"تعذر إنشاء بيانات التحقق الآمنة"}];
        return NO;
    }

    // The file stores verifier bytes only and is the reliable rootless fallback.
    // Keychain is still attempted as an additional secure storage layer.
    if (![self storeFileVerifier:verifier1 key:PVFilePassword1Key error:error] ||
        ![self storeFileVerifier:verifier2 key:PVFilePassword2Key error:error]) {
        return NO;
    }

    [self storeVerifier:verifier1 account:PVPassword1Account error:nil];
    [self storeVerifier:verifier2 account:PVPassword2Account error:nil];
    return YES;
}

- (BOOL)verifyPassword1:(NSString *)password error:(NSError **)error {
    return [self verifyPassword:password account:PVPassword1Account fileKey:PVFilePassword1Key error:error];
}

- (BOOL)verifyPassword2:(NSString *)password error:(NSError **)error {
    return [self verifyPassword:password account:PVPassword2Account fileKey:PVFilePassword2Key error:error];
}

- (NSData *)makeVerifierForPassword:(NSString *)password {
    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    if (passwordData.length == 0 || passwordData.length > 1024) return nil;

    uint8_t salt[PVSaltLength];
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(salt), salt) != errSecSuccess) return nil;

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
    [verifier appendBytes:&PVPasswordVerifierVersion length:sizeof(PVPasswordVerifierVersion)];
    [verifier appendBytes:salt length:sizeof(salt)];
    [verifier appendBytes:derived length:sizeof(derived)];
    memset(derived, 0, sizeof(derived));
    return verifier;
}

- (BOOL)verifyPassword:(NSString *)password account:(NSString *)account fileKey:(NSString *)fileKey error:(NSError **)error {
    NSData *stored = [self fileVerifierForKey:fileKey];
    if (![self isValidVerifier:stored]) stored = [self verifierForAccount:account];
    if (![self isValidVerifier:stored]) return NO;

    const uint8_t *bytes = stored.bytes;
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

- (BOOL)isValidVerifier:(NSData *)verifier {
    if (verifier.length != (1 + PVSaltLength + PVDerivedKeyLength)) return NO;
    const uint8_t *bytes = verifier.bytes;
    return bytes[0] == PVPasswordVerifierVersion;
}

- (NSString *)verifierFilePath {
    NSString *libraryPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    if (libraryPath.length == 0) libraryPath = @"/var/mobile/Library";
    return [libraryPath stringByAppendingPathComponent:@"Preferences/com.aosaid.privacyvault.verifiers.plist"];
}

- (NSDictionary *)readVerifierFile {
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:[self verifierFilePath]];
    return [dictionary isKindOfClass:[NSDictionary class]] ? dictionary : nil;
}

- (NSData *)fileVerifierForKey:(NSString *)key {
    NSData *data = [[self readVerifierFile] objectForKey:key];
    return [data isKindOfClass:[NSData class]] ? data : nil;
}

- (BOOL)storeFileVerifier:(NSData *)verifier key:(NSString *)key error:(NSError **)error {
    NSString *path = [self verifierFilePath];
    NSString *directory = [path stringByDeletingLastPathComponent];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *fileError = nil;
    if (![fileManager createDirectoryAtPath:directory
                withIntermediateDirectories:YES
                                 attributes:@{NSFilePosixPermissions: @0700}
                                      error:&fileError]) {
        if (error) *error = fileError ?: [NSError errorWithDomain:PVPasswordService code:-2 userInfo:@{NSLocalizedDescriptionKey: @"تعذر إنشاء مساحة التخزين الآمنة"}];
        return NO;
    }

    NSMutableDictionary *dictionary = [[self readVerifierFile] mutableCopy];
    if (!dictionary) dictionary = [NSMutableDictionary dictionary];
    dictionary[key] = verifier;
    if (![dictionary writeToFile:path atomically:YES]) {
        if (error) *error = [NSError errorWithDomain:PVPasswordService code:-3 userInfo:@{NSLocalizedDescriptionKey: @"تعذر كتابة بيانات التحقق الآمنة"}];
        return NO;
    }

    chmod(path.fileSystemRepresentation, S_IRUSR | S_IWUSR);
    [fileManager setAttributes:@{NSFileProtectionKey: NSFileProtectionComplete} ofItemAtPath:path error:nil];
    return YES;
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
    return status == errSecSuccess;
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
