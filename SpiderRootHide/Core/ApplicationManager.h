#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface AppInfo : NSObject
@property (nonatomic, strong) NSString *bundleID;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *version;
@property (nonatomic, strong) NSString *appType;
@property (nonatomic, strong) NSString *bundlePath;
@property (nonatomic, strong) UIImage *icon;
@property (nonatomic, assign) BOOL isSystemApp;
@property (nonatomic, assign) BOOL isProtected;
@end

@interface ApplicationManager : NSObject
+ (instancetype)sharedManager;
- (NSArray<AppInfo *> *)allInstalledApplications;
- (NSArray<AppInfo *> *)userApplications;
- (NSArray<AppInfo *> *)systemApplications;
- (AppInfo *)appInfoForBundleID:(NSString *)bundleID;
- (UIImage *)iconForBundleID:(NSString *)bundleID;
- (NSString *)versionForBundleID:(NSString *)bundleID;
- (BOOL)isSystemApp:(NSString *)bundleID;
- (BOOL)isProtectedApp:(NSString *)bundleID;
- (void)killApp:(NSString *)bundleID;
@end
