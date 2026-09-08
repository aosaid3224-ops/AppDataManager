#import <Foundation/Foundation.h>

@interface VerificationResult : NSObject
@property (nonatomic, assign) BOOL isInstalled;
@property (nonatomic, strong) NSString *bundleID;
@property (nonatomic, strong) NSString *appName;
@property (nonatomic, strong) NSString *errorMessage;
@end

@interface VerificationEngine : NSObject
+ (instancetype)sharedEngine;
- (VerificationResult *)verifyInstallation:(NSString *)bundleID;
- (BOOL)isAppInstalled:(NSString *)bundleID;
- (NSString *)appNameForBundleID:(NSString *)bundleID;
@end
