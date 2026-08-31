//
//  CapabilityManager.m
//  IPAInstallerPro — Commit 4b: Fix Applications path
//

#import "CapabilityManager.h"
#import "ExecutableValidator.h"
#import "ExecutableCapability.h"
#import "RootlessManager.h"
#import "JailbreakEnvironment.h"
#import "RuntimeEnvironment.h"
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

- (BOOL)isLDIDAvailable {
    return ([[ExecutableValidator sharedValidator] validateLDID].status == ExecutableCapabilityStatusReady);
}

- (BOOL)isUnzipAvailable {
    return ([[ExecutableValidator sharedValidator] validateUnzip].status == ExecutableCapabilityStatusReady);
}

- (BOOL)isUICacheAvailable {
    return ([[ExecutableValidator sharedValidator] validateUICache].status == ExecutableCapabilityStatusReady);
}

- (BOOL)isRootHelperAvailable {
    NSString *p = @"/usr/bin/ipainstallerpro_helper";
    if (![[NSFileManager defaultManager] fileExistsAtPath:p]) {
        p = @"/var/jb/usr/bin/ipainstallerpro_helper";
    }
    return [[NSFileManager defaultManager] isExecutableFileAtPath:p];
}

- (BOOL)isSystemInstallationAvailable {
    return [self isRootHelperAvailable];
}

- (BOOL)isDirectInstallationAvailable {
    return [self canInstallIPA];
}

- (BOOL)canInstallIPA {
    return ([self isLDIDAvailable] && [self isUnzipAvailable] && [self isUICacheAvailable] && [self canWriteToApplicationsDirectory]);
}

- (NSString *)installationReadinessStatus {
    if ([self canInstallIPA]) return @"✅ مُفعّل";
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
    if (issues.count == 0) return @"⚠️ جاهز جزئيًا";
    return [NSString stringWithFormat:@"❌ غير جاهز:\n%@", [issues componentsJoinedByString:@"\n"]];
}

- (NSArray<Capability *> *)allCapabilities {
    if (self.cachedCapabilities && self.lastScanTime && [[NSDate date] timeIntervalSinceDate:self.lastScanTime] < 30.0) {
        return self.cachedCapabilities;
    }
    NSMutableArray<Capability *> *caps = [NSMutableArray array];

    ExecutableCapability *ldidCap = [[ExecutableValidator sharedValidator] validateLDID];
    Capability *ldid = [[Capability alloc] init];
    ldid.name = @"ldid"; ldid.identifier = @"ldid";
    ldid.isAvailable = (ldidCap.status == ExecutableCapabilityStatusReady);
    ldid.statusMessage = [ldidCap localizedStatusDescription];
    ldid.path = ldidCap.resolvedPath ?: @"";
    [caps addObject:ldid];

    ExecutableCapability *unzipCap = [[ExecutableValidator sharedValidator] validateUnzip];
    Capability *unzip = [[Capability alloc] init];
    unzip.name = @"unzip"; unzip.identifier = @"unzip";
    unzip.isAvailable = (unzipCap.status == ExecutableCapabilityStatusReady);
    unzip.statusMessage = [unzipCap localizedStatusDescription];
    unzip.path = unzipCap.resolvedPath ?: @"";
    [caps addObject:unzip];

    ExecutableCapability *uicacheCap = [[ExecutableValidator sharedValidator] validateUICache];
    Capability *uicache = [[Capability alloc] init];
    uicache.name = @"uicache"; uicache.identifier = @"uicache";
    uicache.isAvailable = (uicacheCap.status == ExecutableCapabilityStatusReady);
    uicache.statusMessage = [uicacheCap localizedStatusDescription];
    uicache.path = uicacheCap.resolvedPath ?: @"";
    [caps addObject:uicache];

    ExecutableCapability *dpkgCap = [self validateDPKG];
    Capability *dpkg = [[Capability alloc] init];
    dpkg.name = @"dpkg"; dpkg.identifier = @"dpkg";
    dpkg.isAvailable = (dpkgCap.status == ExecutableCapabilityStatusReady);
    dpkg.statusMessage = [dpkgCap localizedStatusDescription];
    dpkg.path = dpkgCap.resolvedPath ?: @"";
    [caps addObject:dpkg];

    Capability *helper = [[Capability alloc] init];
    helper.name = @"Root Helper"; helper.identifier = @"root_helper";
    helper.isAvailable = [self isRootHelperAvailable];
    helper.statusMessage = helper.isAvailable ? @"مُفعّل" : @"غير موجود";
    helper.path = @"/usr/bin/ipainstallerpro_helper";
    [caps addObject:helper];

    self.cachedCapabilities = caps;
    self.lastScanTime = [NSDate date];
    return caps;
}

- (Capability *)capabilityForIdentifier:(NSString *)identifier {
    for (Capability *c in [self allCapabilities]) {
        if ([c.identifier isEqualToString:identifier]) return c;
    }
    return nil;
}

- (NSDictionary *)scanCapabilities {
    NSMutableDictionary *capabilities = [NSMutableDictionary dictionary];
    ExecutableCapability *ldidCap = [[ExecutableValidator sharedValidator] validateLDID];
    capabilities[@"ldid"] = @{
        @"available": @(ldidCap.status == ExecutableCapabilityStatusReady),
        @"status": @(ldidCap.status),
        @"statusDescription": [ldidCap localizedStatusDescription],
        @"path": ldidCap.resolvedPath ?: @"",
        @"diagnostics": [ldidCap diagnosticSnapshot]
    };
    ExecutableCapability *unzipCap = [[ExecutableValidator sharedValidator] validateUnzip];
    capabilities[@"unzip"] = @{
        @"available": @(unzipCap.status == ExecutableCapabilityStatusReady),
        @"status": @(unzipCap.status),
        @"statusDescription": [unzipCap localizedStatusDescription],
        @"path": unzipCap.resolvedPath ?: @"",
        @"diagnostics": [unzipCap diagnosticSnapshot]
    };
    ExecutableCapability *uicacheCap = [[ExecutableValidator sharedValidator] validateUICache];
    capabilities[@"uicache"] = @{
        @"available": @(uicacheCap.status == ExecutableCapabilityStatusReady),
        @"status": @(uicacheCap.status),
        @"statusDescription": [uicacheCap localizedStatusDescription],
        @"path": uicacheCap.resolvedPath ?: @"",
        @"diagnostics": [uicacheCap diagnosticSnapshot]
    };
    ExecutableCapability *dpkgCap = [self validateDPKG];
    capabilities[@"dpkg"] = @{
        @"available": @(dpkgCap.status == ExecutableCapabilityStatusReady),
        @"status": @(dpkgCap.status),
        @"statusDescription": [dpkgCap localizedStatusDescription],
        @"path": dpkgCap.resolvedPath ?: @"",
        @"diagnostics": [dpkgCap diagnosticSnapshot]
    };
    capabilities[@"canWriteApplications"] = @([self canWriteToApplicationsDirectory]);
    capabilities[@"canSign"] = @(ldidCap.status == ExecutableCapabilityStatusReady);
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
    [parts addObject:[NSString stringWithFormat:@"ldid: %@", [[[ExecutableValidator sharedValidator] validateLDID] localizedStatusDescription]]];
    [parts addObject:[NSString stringWithFormat:@"unzip: %@", [[[ExecutableValidator sharedValidator] validateUnzip] localizedStatusDescription]]];
    [parts addObject:[NSString stringWithFormat:@"uicache: %@", [[[ExecutableValidator sharedValidator] validateUICache] localizedStatusDescription]]];
    [parts addObject:[NSString stringWithFormat:@"dpkg: %@", [[self validateDPKG] localizedStatusDescription]]];
    return [parts componentsJoinedByString:@"\n"];
}

- (NSString *)capabilityStatusString {
    return [self capabilityStatusDescription];
}

#pragma mark - Internal Helpers

- (ExecutableCapability *)validateDPKG {
    return [[ExecutableValidator sharedValidator] validateExecutableNamed:@"dpkg"];
}

- (BOOL)isDPKGAvailable {
    return ([self validateDPKG].status == ExecutableCapabilityStatusReady);
}

- (BOOL)canWriteToApplicationsDirectory {
    RuntimeEnvironment *rt = [RuntimeEnvironment sharedEnvironment];
    NSString *appsDir;
    if (rt.isRootless && rt.bootstrapPath) {
        appsDir = [rt.bootstrapPath stringByAppendingPathComponent:@"Applications"];
    } else {
        appsDir = @"/Applications";
    }
    return [[NSFileManager defaultManager] isWritableFileAtPath:appsDir];
}

@end
