#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PVPasswordStore : NSObject

+ (instancetype)sharedStore;
- (BOOL)isConfigured;
- (BOOL)savePassword1:(NSString *)password1 password2:(NSString *)password2 error:(NSError * _Nullable * _Nullable)error;
- (BOOL)verifyPassword1:(NSString *)password error:(NSError * _Nullable * _Nullable)error;
- (BOOL)verifyPassword2:(NSString *)password error:(NSError * _Nullable * _Nullable)error;
- (BOOL)changePassword1From:(NSString *)currentPassword to:(NSString *)newPassword error:(NSError * _Nullable * _Nullable)error;
- (BOOL)changePassword2From:(NSString *)currentPassword to:(NSString *)newPassword error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
