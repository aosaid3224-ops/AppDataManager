//
//  CapabilityManager.m
//  IPAInstallerPro — Commit 2: ldid Executable Validator
//
//  CHANGES:
//  - Replaced static fileExistsAtPath checks with ExecutableValidator.
//  - isLDIDAvailable now performs real invocation tests with classification.
//  - isUnzipAvailable and isUICacheAvailable also use ExecutableValidator.
//  - scanCapabilities now produces rich diagnostic data.
//  - No public API changes (signatures identical, behavior enriched).
//

#import "CapabilityManager.h"
#import "ExecutableValidator.h"
#import "ExecutableCapability.h"
#import "RootlessManager.h"
#import "JailbreakEnvironment.h"
#import "Logger.h"

@implementation CapabilityManager

+ (instancetype)sharedManager {
    static CapabilityManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

#pragma mark - Public API (unchanged signatures)

- (BOOL)isLDIDAvailable {
    ExecutableCapability *cap = [[ExecutableValidator sharedValidator] validateLDID];
    return (cap.status == ExecutableCapabilityStatusReady);
}

- (BOOL)isUnzipAvailable {
    ExecutableCapability *cap = [[ExecutableValidator sharedValidator] validateUnzip];
    return (cap.status == ExecutableCapabilityStatusReady);
}

- (BOOL)isUICacheAvailable {
    ExecutableCapability *cap = [[ExecutableValidator sharedValidator] validateUICache];
    return (cap.status == ExecutableCapabilityStatusReady);
}

- (NSDictionary *)scanCapabilities {
    NSMutableDictionary *capabilities = [NSMutableDictionary dictionary];

    // Test ldid with full diagnostics
    ExecutableCapability *ldidCap = [[ExecutableValidator sharedValidator] validateLDID];
    capabilities[@"ldid"] = @{
        @"available": @(ldidCap.status == ExecutableCapabilityStatusReady),
        @"status": @(ldidCap.status),
        @"statusDescription": [ldidCap localizedStatusDescription],
        @"path": ldidCap.resolvedPath ?: @"" ,
        @"diagnostics": [ldidCap diagnosticSnapshot]
    };

    if (ldidCap.status != ExecutableCapabilityStatusReady) {
        [[Logger sharedLogger] error:[NSString stringWithFormat:@"CapabilityManager: ldid not ready — %@ | path=%@ | error=%@",
                                      [ldidCap localizedStatusDescription], ldidCap.resolvedPath, ldidCap.lastErrorMessage]];
    }

    // Test unzip
    ExecutableCapability *unzipCap = [[ExecutableValidator sharedValidator] validateUnzip];
    capabilities[@"unzip"] = @{
        @"available": @(unzipCap.status == ExecutableCapabilityStatusReady),
        @"status": @(unzipCap.status),
        @"statusDescription": [unzipCap localizedStatusDescription],
        @"path": unzipCap.resolvedPath ?: @"",
        @"diagnostics": [unzipCap diagnosticSnapshot]
    };

    // Test uicache
    ExecutableCapability *uicacheCap = [[ExecutableValidator sharedValidator] validateUICache];
    capabilities[@"uicache"] = @{
        @"available": @(uicacheCap.status == ExecutableCapabilityStatusReady),
        @"status": @(uicacheCap.status),
        @"statusDescription": [uicacheCap localizedStatusDescription],
        @"path": uicacheCap.resolvedPath ?: @"",
        @"diagnostics": [uicacheCap diagnosticSnapshot]
    };

    // Check dpkg for dependency management
    BOOL dpkgAvailable = [self isDPKGAvailable];
    capabilities[@"dpkg"] = @{
        @"available": @(dpkgAvailable),
        @"path": dpkgAvailable ? @"/usr/bin/dpkg" : @""
    };

    // Check if we can write to Applications directory
    capabilities[@"canWriteApplications"] = @([self canWriteToApplicationsDirectory]);

    // Check code signing capabilities
    capabilities[@"canSign"] = @(ldidCap.status == ExecutableCapabilityStatusReady);

    // Overall status
    BOOL allReady = (ldidCap.status == ExecutableCapabilityStatusReady) &&
                    (unzipCap.status == ExecutableCapabilityStatusReady) &&
                    (uicacheCap.status == ExecutableCapabilityStatusReady);
    capabilities[@"allReady"] = @(allReady);

    return capabilities;
}

- (NSArray<NSString *> *)missingCapabilities {
    NSMutableArray<NSString *> *missing = [NSMutableArray array];

    ExecutableCapability *ldidCap = [[ExecutableValidator sharedValidator] validateLDID];
    if (ldidCap.status != ExecutableCapabilityStatusReady) {
        [missing addObject:[NSString stringWithFormat:@"ldid (%@)", [ldidCap localizedStatusDescription]]];
    }

    ExecutableCapability *unzipCap = [[ExecutableValidator sharedValidator] validateUnzip];
    if (unzipCap.status != ExecutableCapabilityStatusReady) {
        [missing addObject:[NSString stringWithFormat:@"unzip (%@)", [unzipCap localizedStatusDescription]]];
    }

    ExecutableCapability *uicacheCap = [[ExecutableValidator sharedValidator] validateUICache];
    if (uicacheCap.status != ExecutableCapabilityStatusReady) {
        [missing addObject:[NSString stringWithFormat:@"uicache (%@)", [uicacheCap localizedStatusDescription]]];
    }

    if (![self isDPKGAvailable]) {
        [missing addObject:@"dpkg"];
    }

    return missing;
}

- (NSString *)capabilityStatusDescription {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    ExecutableCapability *ldidCap = [[ExecutableValidator sharedValidator] validateLDID];
    [parts addObject:[NSString stringWithFormat:@"ldid: %@", [ldidCap localizedStatusDescription]]];

    ExecutableCapability *unzipCap = [[ExecutableValidator sharedValidator] validateUnzip];
    [parts addObject:[NSString stringWithFormat:@"unzip: %@", [unzipCap localizedStatusDescription]]];

    ExecutableCapability *uicacheCap = [[ExecutableValidator sharedValidator] validateUICache];
    [parts addObject:[NSString stringWithFormat:@"uicache: %@", [uicacheCap localizedStatusDescription]]];

    return [parts componentsJoinedByString:@"\n"];
}

#pragma mark - Internal Helpers (unchanged logic, enriched logging)

- (BOOL)isDPKGAvailable {
    NSString *dpkgPath = [[RootlessManager sharedManager] resolvePath:@"/usr/bin/dpkg"];
    return [[NSFileManager defaultManager] fileExistsAtPath:dpkgPath];
}

- (BOOL)canWriteToApplicationsDirectory {
    NSString *appsDir = [[RootlessManager sharedManager] resolvePath:@"/Applications"];
    return [[NSFileManager defaultManager] isWritableFileAtPath:appsDir];
}

@end
