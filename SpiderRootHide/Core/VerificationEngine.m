#import "VerificationEngine.h"
#import <objc/runtime.h>
#import "Logger.h"

@implementation VerificationResult
@end

@implementation VerificationEngine

+ (instancetype)sharedEngine {
    static VerificationEngine *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (VerificationResult *)verifyInstallation:(NSString *)bundleID {
    VerificationResult *result = [[VerificationResult alloc] init];
    result.bundleID = bundleID;
    result.isInstalled = [self isAppInstalled:bundleID];
    result.appName = [self appNameForBundleID:bundleID];

    if (result.isInstalled) {
        [[Logger sharedLogger] info:[NSString stringWithFormat:@"Verification: %@ installed successfully", bundleID]];
    } else {
        result.errorMessage = @"التطبيق غير مسجل في النظام بعد التثبيت";
        [[Logger sharedLogger] error:[NSString stringWithFormat:@"Verification: %@ NOT found after install", bundleID]];
    }

    return result;
}

- (BOOL)isAppInstalled:(NSString *)bundleID {
    if (!bundleID) return NO;
    Class LSApplicationWorkspace_class = objc_getClass("LSApplicationWorkspace");
    if (!LSApplicationWorkspace_class) return NO;
    id workspace = [LSApplicationWorkspace_class performSelector:@selector(defaultWorkspace)];
    if (!workspace) return NO;

    NSArray *allApps = nil;
    @try {
        allApps = [workspace performSelector:@selector(allInstalledApplications)];
    } @catch (NSException *e) { return NO; }

    for (id app in allApps) {
        @try {
            NSString *bid = [app performSelector:@selector(bundleIdentifier)];
            if ([bid isEqualToString:bundleID]) return YES;
        } @catch (NSException *e) { continue; }
    }
    return NO;
}

- (NSString *)appNameForBundleID:(NSString *)bundleID {
    if (!bundleID) return nil;
    Class LSApplicationProxy_class = objc_getClass("LSApplicationProxy");
    if (LSApplicationProxy_class && [LSApplicationProxy_class respondsToSelector:@selector(applicationProxyForIdentifier:)]) {
        id proxy = [LSApplicationProxy_class performSelector:@selector(applicationProxyForIdentifier:) withObject:bundleID];
        if (proxy && [proxy respondsToSelector:@selector(localizedName)]) {
            return [proxy performSelector:@selector(localizedName)];
        }
    }
    return nil;
}

@end
