//
//  CapabilityManager.m
//  IPAInstallerPro — Commit 4: Diagnostics Fix
//
//  CHANGES:
//  - Added allCapabilities (returns Capability objects with rich status).
//  - Added installationReadinessStatus (human-readable summary).
//  - Added canInstallIPA (checks all critical tools).
//  - Added isRootHelperAvailable, isSystemInstallationAvailable, isDirectInstallationAvailable.
//  - Fixed isDPKGAvailable: now uses ExecutableValidator (real invocation test).
//  - statusMessage now uses ExecutableCapability.localizedStatusDescription (Arabic, precise).
//

#import "CapabilityManager.h"
#import "ExecutableValidator.h"
#import "ExecutableCapability.h"
#import "RootlessManager.h"
#import "JailbreakEnvironment.h"
#import "Logger.h"

@interface CapabilityManager ()
@property (nonatomic, strong) NSArray<Capability *> *cachedCapabilities;
@property (nonatomic, strong) NSDate *lastScanTime;
@end

@implementation CapabilityManager

+ (instancetype)sharedManager {
    static CapabilityManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

#pragma mark - Public API

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

- (BOOL)isRootHelperAvailable {
    // Root helper is the setuid binary (helper.c) — check if it exists and is executable
    NSString *helperPath = @"/usr/bin/ipainstallerpro_helper";
    if (![[NSFileManager defaultManager] fileExistsAtPath:helperPath]) {
        helperPath = @"/var/jb/usr/bin/ipainstallerpro_helper";
    }
    return [[NSFileManager defaultManager] isExecutableFileAtPath:helperPath];
}

- (BOOL)isSystemInstallationAvailable {
    // System installation requires root helper
    return [self isRootHelperAvailable];
}

- (BOOL)isDirectInstallationAvailable {
    // Direct installation requires ldid + unzip + uicache + write access
    return [self canInstallIPA];
}

- (BOOL)canInstallIPA {
    BOOL ldid = [self isLDIDAvailable];
    BOOL unzip = [self isUnzipAvailable];
    BOOL uicache = [self isUICacheAvailable];
    BOOL canWrite = [self canWriteToApplicationsDirectory];
    return (ldid && unzip && uicache && canWrite);
}

- (NSString *)installationReadinessStatus {
    if ([self canInstallIPA]) {
        return @"✅ جاهز للتثبيت";
    }

    NSMutableArray<NSString *> *issues = [NSMutableArray array];

    ExecutableCapability *ldidCap = [[ExecutableValidator sharedValidator] validateLDID];
    if (ldidCap.status != ExecutableCapabilityStatusReady) {
        [issues addObject:[NSString stringWithFormat:@"ldid: %@", [ldidCap localizedStatusDescription]]];
    }

    ExecutableCapability *unzipCap = [[ExecutableValidator sharedValidator] validateUnzip];
    if (unzipCap.status != ExecutableCapabilityStatusReady) {
        [issues addObject:[NSString stringWithFormat:@"unzip: %@", [unzipCap localizedStatusDescription]]];
    }

    ExecutableCapability *uicacheCap = [[ExecutableValidator sharedValidator] validateUICache];
    if (uicacheCap.status != ExecutableCapabilityStatusReady) {
        [issues addObject:[NSString stringWithFormat:@"uicache: %@", [uicacheCap localizedStatusDescription]]];
    }

    if (![self canWriteToApplicationsDirectory]) {
        [issues addObject:@"لا يمكن الكتابة إلى مجلد Applications"];
    }

    if (issues.count == 0) {
        return @"⚠️ جاهز جزئيًا";
    }

    return [NSString stringWithFormat:@"❌ غير جاهز:
%@", [issues componentsJoinedByString:@"\n"]];
}

- (NSArray<Capability *> *)allCapabilities {
    // Return cached results if fresh (< 30 seconds)
    if (self.cachedCapabilities && self.lastScanTime &&
        [[NSDate date] timeIntervalSinceDate:self.lastScanTime] < 30.0) {
        return self.cachedCapabilities;
    }

    NSMutableArray<Capability *> *caps = [NSMutableArray array];

    // ldid
    ExecutableCapability *ldidCap = [[ExecutableValidator sharedValidator] validateLDID];
    Capability *ldid = [[Capability alloc] init];
    ldid.name = @"ldid";
    ldid.identifier = @"ldid";
    ldid.isAvailable = (ldidCap.status == ExecutableCapabilityStatusReady);
    ldid.statusMessage = [ldidCap localizedStatusDescription]; // Arabic, precise classification
    ldid.path = ldidCap.resolvedPath ?: @"";
    ldid.version = @""; // Could be populated from ldid -v output if needed
    [caps addObject:ldid];

    // unzip
    ExecutableCapability *unzipCap = [[ExecutableValidator sharedValidator] validateUnzip];
    Capability *unzip = [[Capability alloc] init];
    unzip.name = @"unzip";
    unzip.identifier = @"unzip";
    unzip.isAvailable = (unzipCap.status == ExecutableCapabilityStatusReady);
    unzip.statusMessage = [unzipCap localizedStatusDescription];
    unzip.path = unzipCap.resolvedPath ?: @"";
    [caps addObject:unzip];

    // uicache
    ExecutableCapability *uicacheCap = [[ExecutableValidator sharedValidator] validateUICache];
    Capability *uicache = [[Capability alloc] init];
    uicache.name = @"uicache";
    uicache.identifier = @"uicache";
    uicache.isAvailable = (uicacheCap.status == ExecutableCapabilityStatusReady);
    uicache.statusMessage = [uicacheCap localizedStatusDescription];
    uicache.path = uicacheCap.resolvedPath ?: @"";
    [caps addObject:uicache];

    // dpkg
    ExecutableCapability *dpkgCap = [self validateDPKG];
    Capability *dpkg = [[Capability alloc] init];
    dpkg.name = @"dpkg";
    dpkg.identifier = @"dpkg";
    dpkg.isAvailable = (dpkgCap.status == ExecutableCapabilityStatusReady);
    dpkg.statusMessage = [dpkgCap localizedStatusDescription];
    dpkg.path = dpkgCap.resolvedPath ?: @"";
    [caps addObject:dpkg];

    // Root helper
    Capability *helper = [[Capability alloc] init];
    helper.name = @"Root Helper";
    helper.identifier = @"root_helper";
    helper.isAvailable = [self isRootHelperAvailable];
    helper.statusMessage = helper.isAvailable ? @"جاهز" : @"غير موجود";
    helper.path = @"/usr/bin/ipainstallerpro_helper";
    [caps addObject:helper];

    self.cachedCapabilities = caps;
    self.lastScanTime = [NSDate date];

    return caps;
}

- (Capability *)capabilityForIdentifier:(NSString *)identifier {
    for (Capability *c in [self allCapabilities]) {
        if ([c.identifier isEqualToString:identifier]) {
            return c;
        }
    }
    return nil;
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

    // Test dpkg with ExecutableValidator (FIXED)
    ExecutableCapability *dpkgCap = [self validateDPKG];
    capabilities[@"dpkg"] = @{
        @"available": @(dpkgCap.status == ExecutableCapabilityStatusReady),
        @"status": @(dpkgCap.status),
        @"statusDescription": [dpkgCap localizedStatusDescription],
        @"path": dpkgCap.resolvedPath ?: @"",
        @"diagnostics": [dpkgCap diagnosticSnapshot]
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

    ExecutableCapability *dpkgCap = [self validateDPKG];
    if (dpkgCap.status != ExecutableCapabilityStatusReady) {
        [missing addObject:[NSString stringWithFormat:@"dpkg (%@)", [dpkgCap localizedStatusDescription]]];
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

    ExecutableCapability *dpkgCap = [self validateDPKG];
    [parts addObject:[NSString stringWithFormat:@"dpkg: %@", [dpkgCap localizedStatusDescription]]];

    return [parts componentsJoinedByString:@"\n"];
}

- (NSString *)capabilityStatusString {
    return [self capabilityStatusDescription];
}

#pragma mark - Internal Helpers

- (ExecutableCapability *)validateDPKG {
    // Use ExecutableValidator for real invocation test
    ExecutableCapability *cap = [[ExecutableValidator sharedValidator] validateExecutableNamed:@"dpkg"];
    return cap;
}

- (BOOL)isDPKGAvailable {
    ExecutableCapability *cap = [self validateDPKG];
    return (cap.status == ExecutableCapabilityStatusReady);
}

- (BOOL)canWriteToApplicationsDirectory {
    NSString *appsDir = [[RootlessManager sharedManager] resolvePath:@"/Applications"];
    return [[NSFileManager defaultManager] isWritableFileAtPath:appsDir];
}

@end
