#import <Foundation/Foundation.h>

@interface Capability : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, assign) BOOL isAvailable;
@property (nonatomic, strong) NSString *version;
@property (nonatomic, strong) NSString *statusMessage;
@property (nonatomic, strong) NSString *path;
@end

@interface CapabilityManager : NSObject
+ (instancetype)sharedManager;
- (NSDictionary *)scanCapabilities;
- (NSArray *)allCapabilities;
- (Capability *)capabilityForIdentifier:(NSString *)identifier;
- (BOOL)isUnzipAvailable;
- (BOOL)isLDIDAvailable;
- (BOOL)isUICacheAvailable;
- (BOOL)isRootHelperAvailable;
- (BOOL)isSystemInstallationAvailable;
- (BOOL)isDirectInstallationAvailable;
- (NSString *)installationReadinessStatus;
- (NSString *)capabilityStatusString;
- (NSString *)capabilityStatusDescription;
- (BOOL)canInstallIPA;
@end
