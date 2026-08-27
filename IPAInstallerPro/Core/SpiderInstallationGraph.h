#import <Foundation/Foundation.h>
#import "IPAStructuralResult.h"

typedef NS_ENUM(NSInteger, SpiderBundleRole) {
    SpiderBundleRoleUnknown = 0,
    SpiderBundleRoleHostApplication,
    SpiderBundleRoleAppExtension,
    SpiderBundleRoleXPCService,
    SpiderBundleRoleFramework,
    SpiderBundleRoleDylib,
    SpiderBundleRoleResourceBundle
};

@interface SpiderBundleNode : NSObject
@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) NSString *bundleIdentifier;
@property (nonatomic, strong) NSString *executablePath;
@property (nonatomic, strong) NSString *roleName;
@property (nonatomic, assign) SpiderBundleRole role;
@property (nonatomic, assign) BOOL launchCritical;
@property (nonatomic, assign) BOOL executableExists;
@property (nonatomic, assign) BOOL machOValid;
@property (nonatomic, assign) BOOL arm64Compatible;
@property (nonatomic, assign) BOOL hasCodeSignature;
@property (nonatomic, strong) NSArray<NSString *> *fatalFindings;
@property (nonatomic, strong) NSArray<NSString *> *warnings;
- (NSDictionary *)evidence;
@end

@interface SpiderInstallationGraph : NSObject
@property (nonatomic, strong) NSArray<SpiderBundleNode *> *nodes;
@property (nonatomic, strong) NSArray<NSString *> *fatalFindings;
@property (nonatomic, strong) NSArray<NSString *> *warnings;
@property (nonatomic, assign, readonly) BOOL coherent;
+ (instancetype)graphFromStructuralResult:(IPAStructuralResult *)result;
- (NSDictionary *)evidence;
- (NSString *)summary;
@end
