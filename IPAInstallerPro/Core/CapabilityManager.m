//
// CapabilityManager.m
// IPA Installer Pro
//
// v2.1 — Standalone: Only system tools, no external dependencies
//

#import "CapabilityManager.h"
#import "RootlessManager.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@implementation Capability
@end

@interface CapabilityManager ()
@property (nonatomic, strong) NSMutableArray<Capability *> *capabilities;
@property (nonatomic, strong) NSMutableDictionary<NSString *, Capability *> *capabilityMap;
@end

@implementation CapabilityManager

+ (instancetype)sharedManager {
    static CapabilityManager *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _capabilities = [NSMutableArray array];
        _capabilityMap = [NSMutableDictionary dictionary];
        [self scanCapabilities];
    }
    return self;
}

- (void)scanCapabilities {
    [self.capabilities removeAllObjects];
    [self.capabilityMap removeAllObjects];

    RootlessManager *rm = [RootlessManager sharedManager];
    NSFileManager *fm = [NSFileManager defaultManager];

    // Scan each tool
    [self scanTool:@"ldid" identifier:@"ldid" path:[rm resolvePath:@"/usr/bin/ldid"] required:YES];
    [self scanTool:@"uicache" identifier:@"uicache" path:[rm resolvePath:@"/usr/bin/uicache"] required:YES];
    [self scanTool:@"unzip" identifier:@"unzip" path:[rm resolvePath:@"/usr/bin/unzip"] required:YES];
    [self scanTool:@"chmod" identifier:@"chmod" path:[rm resolvePath:@"/usr/bin/chmod"] required:YES];
    [self scanTool:@"chown" identifier:@"chown" path:[rm resolvePath:@"/usr/sbin/chown"] required:YES];
    [self scanTool:@"cp" identifier:@"cp" path:[rm resolvePath:@"/bin/cp"] required:YES];
    [self scanTool:@"rm" identifier:@"rm" path:[rm resolvePath:@"/bin/rm"] required:YES];
    [self scanTool:@"mkdir" identifier:@"mkdir" path:[rm resolvePath:@"/bin/mkdir"] required:YES];

    // Root helper (optional but recommended)
    NSString *h1 = [rm resolvePath:@"/usr/bin/ipainstallerpro_helper"];
    NSString *h2 = @"/usr/bin/ipainstallerpro_helper";
    NSString *h3 = @"/var/jb/usr/bin/ipainstallerpro_helper";
    BOOL hasHelper = [fm fileExistsAtPath:h1] || [fm fileExistsAtPath:h2] || [fm fileExistsAtPath:h3];
    [self addCapability:@"Root Helper" identifier:@"root_helper" available:hasHelper path:(hasHelper ? (h1 ?: h2 ?: h3) : @"Not found") required:NO];

    // LSApplicationWorkspace (for verification only)
    Class LS = objc_getClass("LSApplicationWorkspace");
    [self addCapability:@"LSApplicationWorkspace" identifier:@"ls_workspace" available:(LS != nil) path:@"System" required:NO];

    NSLog(@"[IPAInstallerPro] Capabilities scanned: %lu tools", (unsigned long)self.capabilities.count);
}

- (void)scanTool:(NSString *)name identifier:(NSString *)identifier path:(NSString *)path required:(BOOL)required {
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
    [self addCapability:name identifier:identifier available:exists path:(exists ? path : @"Not found") required:required];
}

- (void)addCapability:(NSString *)name identifier:(NSString *)identifier available:(BOOL)available path:(NSString *)path required:(BOOL)required {
    Capability *cap = [[Capability alloc] init];
    cap.name = name;
    cap.identifier = identifier;
    cap.isAvailable = available;
    cap.path = path;
    cap.statusMessage = available ? @"Available" : (required ? @"Required — not found" : @"Optional — not found");
    [self.capabilities addObject:cap];
    self.capabilityMap[identifier] = cap;
}

- (NSArray *)allCapabilities {
    return [self.capabilities copy];
}

- (Capability *)capabilityForIdentifier:(NSString *)identifier {
    return self.capabilityMap[identifier];
}

- (BOOL)isUnzipAvailable {
    return [self capabilityForIdentifier:@"unzip"].isAvailable;
}

- (BOOL)isLDIDAvailable {
    return [self capabilityForIdentifier:@"ldid"].isAvailable;
}

- (BOOL)isUICacheAvailable {
    return [self capabilityForIdentifier:@"uicache"].isAvailable;
}

- (BOOL)isRootHelperAvailable {
    return [self capabilityForIdentifier:@"root_helper"].isAvailable;
}

- (BOOL)isSystemInstallationAvailable {
    // System install via LSApplicationWorkspace (optional fallback)
    Class LS = objc_getClass("LSApplicationWorkspace");
    return (LS != nil);
}

- (BOOL)isDirectInstallationAvailable {
    // Direct install requires ldid + uicache + unzip
    return [self isLDIDAvailable] && [self isUICacheAvailable] && [self isUnzipAvailable];
}

- (NSString *)installationReadinessStatus {
    if ([self isDirectInstallationAvailable]) {
        if ([self isRootHelperAvailable]) {
            return @"✅ Ready — Full standalone mode with root helper";
        } else {
            return @"✅ Ready — Standalone mode (no root helper, some operations may be limited)";
        }
    }
    NSMutableString *missing = [NSMutableString stringWithString:@"❌ Missing required tools: "];
    if (![self isLDIDAvailable]) [missing appendString:@"ldid "];
    if (![self isUICacheAvailable]) [missing appendString:@"uicache "];
    if (![self isUnzipAvailable]) [missing appendString:@"unzip "];
    return missing;
}

- (NSString *)capabilityStatusString {
    NSMutableString *status = [NSMutableString string];
    [status appendString:@"\n=== Capability Status ===\n"];
    for (Capability *cap in self.capabilities) {
        NSString *icon = cap.isAvailable ? @"✅" : ([cap.identifier isEqualToString:@"root_helper"] || [cap.identifier isEqualToString:@"ls_workspace"] ? @"⚠️" : @"❌");
        [status appendFormat:@"%@ %@: %@ (%@)\n", icon, cap.name, cap.statusMessage, cap.path];
    }
    return status;
}

- (BOOL)canInstallIPA {
    return [self isDirectInstallationAvailable];
}

@end
