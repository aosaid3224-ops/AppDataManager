//
//  RuntimeEnvironment.m
//  IPAInstallerPro — Commit 3: Runtime Environment Discovery
//

#import "RuntimeEnvironment.h"
#import "Logger.h"

#include <sys/sysctl.h>
#include <sys/utsname.h>
#include <unistd.h>

@interface RuntimeEnvironment ()
@property (nonatomic, copy, readwrite) NSString *bootstrapPath;
@property (nonatomic, assign, readwrite) BOOL isRootless;
@property (nonatomic, assign, readwrite) SpiderJailbreakType jailbreakType;
@property (nonatomic, copy, readwrite) NSString *jailbreakTypeName;
@property (nonatomic, copy, readwrite) NSString *iosVersion;
@property (nonatomic, copy, readwrite) NSString *architecture;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *binSearchPaths;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *librarySearchPaths;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSString *> *environmentVariables;
@property (nonatomic, assign, readwrite) BOOL isCharacterized;
@end

@implementation RuntimeEnvironment

+ (instancetype)sharedEnvironment {
    static RuntimeEnvironment *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self characterizeEnvironment];
    }
    return self;
}

#pragma mark - Discovery

- (void)characterizeEnvironment {
    NSDate *start = [NSDate date];

    // 1. Basic system info
    _iosVersion = [self detectIOSVersion];
    _architecture = [self detectArchitecture];

    // 2. Bootstrap path discovery (highest priority first)
    _bootstrapPath = [self detectBootstrapPath];
    _isRootless = (_bootstrapPath != nil);

    // 3. Jailbreak type discovery
    _jailbreakType = [self detectJailbreakType];
    _jailbreakTypeName = [self nameForJailbreakType:_jailbreakType];

    // 4. Build search paths
    _binSearchPaths = [self buildBinSearchPaths];
    _librarySearchPaths = [self buildLibrarySearchPaths];

    // 5. Build environment variables
    _environmentVariables = [self buildEnvironmentVariables];

    _isCharacterized = YES;

    NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:start];
    [[Logger sharedLogger] info:[NSString stringWithFormat:@"RuntimeEnvironment: characterized in %.3fs | rootless=%@ | bootstrap=%@ | type=%@ | iOS=%@ | arch=%@",
                                 duration,
                                 _isRootless ? @"YES" : @"NO",
                                 _bootstrapPath ?: @"none",
                                 _jailbreakTypeName,
                                 _iosVersion,
                                 _architecture]];
}

#pragma mark - Bootstrap Path Detection

- (NSString *)detectBootstrapPath {
    NSFileManager *fm = [NSFileManager defaultManager];

    // Priority 1: Environment variables
    const char *procursusRoot = getenv("PROCURSUS_ROOT");
    if (procursusRoot) {
        NSString *path = [NSString stringWithUTF8String:procursusRoot];
        if ([fm fileExistsAtPath:path]) return path;
    }

    const char *rootPath = getenv("ROOT_PATH");
    if (rootPath) {
        NSString *path = [NSString stringWithUTF8String:rootPath];
        if ([fm fileExistsAtPath:path]) return path;
    }

    // Priority 2: Signature files (strong indicators)
    NSArray<NSString *> *signaturePaths = @[
        @"/var/jb/.procursus_strapped",
        @"/var/jb/.installed_dopamine",
        @"/var/jb/.bootstrapped",
        @"/var/LIY/.installed_palera1n",
    ];
    for (NSString *sig in signaturePaths) {
        if ([fm fileExistsAtPath:sig]) {
            // Extract bootstrap root from signature path
            NSString *parent = [sig stringByDeletingLastPathComponent];
            if ([parent isEqualToString:@"/var/jb"] || [parent isEqualToString:@"/var/LIY"]) {
                return parent;
            }
        }
    }

    // Priority 3: Executable presence (which dpkg is real?)
    // If /usr/bin/dpkg exists and is executable, likely not rootless (or old-style)
    // If /var/jb/usr/bin/dpkg exists and is executable, likely rootless Procursus
    NSString *jbDpkg = @"/var/jb/usr/bin/dpkg";
    NSString *liDpkg = @"/var/LIY/usr/bin/dpkg";
    NSString *optDpkg = @"/opt/procursus/bin/dpkg";
    NSString *usrDpkg = @"/usr/bin/dpkg";

    if (access(jbDpkg.fileSystemRepresentation, X_OK) == 0) {
        return @"/var/jb";
    }
    if (access(liDpkg.fileSystemRepresentation, X_OK) == 0) {
        return @"/var/LIY";
    }
    if (access(optDpkg.fileSystemRepresentation, X_OK) == 0) {
        return @"/opt/procursus";
    }

    // Priority 4: Directory presence (weaker indicator)
    if ([fm fileExistsAtPath:@"/var/jb"]) {
        // Additional check: does it look like a real bootstrap?
        if ([fm fileExistsAtPath:@"/var/jb/usr/bin"] || [fm fileExistsAtPath:@"/var/jb/bin"]) {
            return @"/var/jb";
        }
    }
    if ([fm fileExistsAtPath:@"/var/LIY"]) {
        if ([fm fileExistsAtPath:@"/var/LIY/usr/bin"] || [fm fileExistsAtPath:@"/var/LIY/bin"]) {
            return @"/var/LIY";
        }
    }
    if ([fm fileExistsAtPath:@"/opt/procursus"]) {
        return @"/opt/procursus";
    }

    // Priority 5: Check if /usr/bin/dpkg exists but /var/jb does not
    // This suggests an old-style (non-rootless) jailbreak
    if (access(usrDpkg.fileSystemRepresentation, X_OK) == 0) {
        // Old-style jailbreak, no rootless bootstrap
        return nil;
    }

    // No bootstrap detected
    return nil;
}

#pragma mark - Jailbreak Type Detection

- (SpiderJailbreakType)detectJailbreakType {
    NSFileManager *fm = [NSFileManager defaultManager];

    // Dopamine indicators
    if ([fm fileExistsAtPath:@"/var/jb/.installed_dopamine"] ||
        [fm fileExistsAtPath:@"/var/jb/usr/share/dopamine"] ||
        [fm fileExistsAtPath:@"/usr/share/dopamine"]) {
        return SpiderJailbreakTypeDopamine;
    }

    // Palera1n indicators
    if ([fm fileExistsAtPath:@"/var/LIY/.installed_palera1n"] ||
        [fm fileExistsAtPath:@"/var/LIY/usr/share/palera1n"]) {
        return SpiderJailbreakTypePalera1n;
    }

    // Checkra1n indicators
    if ([fm fileExistsAtPath:@"/usr/lib/libhooker.dylib"] ||
        [fm fileExistsAtPath:@"/usr/lib/libsubstitute.dylib"] ||
        [fm fileExistsAtPath:@"/var/checkra1n"]) {
        return SpiderJailbreakTypeCheckra1n;
    }

    // Unc0ver indicators
    if ([fm fileExistsAtPath:@"/usr/share/unc0ver"] ||
        [fm fileExistsAtPath:@"/var/unc0ver"]) {
        return SpiderJailbreakTypeUnc0ver;
    }

    // Taurine/Odyssey indicators
    if ([fm fileExistsAtPath:@"/usr/share/libhooker"] ||
        [fm fileExistsAtPath:@"/var/libexec/libhooker"]) {
        // Could be Taurine or Odyssey, check further
        if ([fm fileExistsAtPath:@"/usr/share/taurine"]) {
            return SpiderJailbreakTypeTaurine;
        }
        if ([fm fileExistsAtPath:@"/usr/share/odyssey"]) {
            return SpiderJailbreakTypeOdyssey;
        }
        return SpiderJailbreakTypeTaurine; // Default to Taurine for libhooker
    }

    // XinaA15 indicators
    if ([fm fileExistsAtPath:@"/var/xina"] ||
        [fm fileExistsAtPath:@"/usr/share/xina"]) {
        return SpiderJailbreakTypeXinaA15;
    }

    // If rootless but no specific type detected
    if (self.isRootless) {
        return SpiderJailbreakTypeOther;
    }

    // If not rootless but dpkg exists, likely old-style jailbreak
    if (access("/usr/bin/dpkg", X_OK) == 0) {
        return SpiderJailbreakTypeOther;
    }

    return SpiderJailbreakTypeUnknown;
}

- (NSString *)nameForJailbreakType:(SpiderJailbreakType)type {
    switch (type) {
        case SpiderJailbreakTypeCheckra1n: return @"Checkra1n";
        case SpiderJailbreakTypeUnc0ver: return @"Unc0ver";
        case SpiderJailbreakTypeDopamine: return @"Dopamine";
        case SpiderJailbreakTypePalera1n: return @"Palera1n";
        case SpiderJailbreakTypeTaurine: return @"Taurine";
        case SpiderJailbreakTypeOdyssey: return @"Odyssey";
        case SpiderJailbreakTypeXinaA15: return @"XinaA15";
        case SpiderJailbreakTypeOther: return @"Other";
        case SpiderJailbreakTypeUnknown: return @"Unknown";
    }
}

#pragma mark - System Info

- (NSString *)detectIOSVersion {
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    return [NSString stringWithFormat:@"%ld.%ld.%ld", (long)version.majorVersion, (long)version.minorVersion, (long)version.patchVersion];
}

- (NSString *)detectArchitecture {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *machine = [NSString stringWithUTF8String:systemInfo.machine];

    // Map machine identifier to architecture
    if ([machine hasPrefix:@"iPhone"] || [machine hasPrefix:@"iPad"] || [machine hasPrefix:@"iPod"]) {
        // Check CPU type via sysctl
        size_t size;
        cpu_type_t cpuType;
        size = sizeof(cpuType);
        if (sysctlbyname("hw.cputype", &cpuType, &size, NULL, 0) == 0) {
            if (cpuType == CPU_TYPE_ARM64) {
                // Check for ARM64e
                cpu_subtype_t cpuSubtype;
                size = sizeof(cpuSubtype);
                if (sysctlbyname("hw.cpusubtype", &cpuSubtype, &size, NULL, 0) == 0) {
                    if (cpuSubtype == CPU_SUBTYPE_ARM64E) {
                        return @"arm64e";
                    }
                }
                return @"arm64";
            }
        }
    }

    return machine; // Fallback to raw machine identifier
}

#pragma mark - Search Paths

- (NSArray<NSString *> *)buildBinSearchPaths {
    NSMutableOrderedSet<NSString *> *paths = [NSMutableOrderedSet orderedSet];

    // 1. PATH environment variable
    const char *pathEnv = getenv("PATH");
    if (pathEnv) {
        NSString *pathStr = [NSString stringWithUTF8String:pathEnv];
        for (NSString *p in [pathStr componentsSeparatedByString:@":"]) {
            if (p.length > 0) [paths addObject:p];
        }
    }

    // 2. Bootstrap binary paths (if detected)
    if (self.bootstrapPath) {
        [paths addObject:[self.bootstrapPath stringByAppendingPathComponent:@"usr/bin"]];
        [paths addObject:[self.bootstrapPath stringByAppendingPathComponent:@"bin"]];
        [paths addObject:[self.bootstrapPath stringByAppendingPathComponent:@"usr/local/bin"]];
    }

    // 3. Standard paths
    [paths addObject:@"/usr/bin"];
    [paths addObject:@"/bin"];
    [paths addObject:@"/usr/local/bin"];
    [paths addObject:@"/opt/procursus/bin"];

    // 4. Fallback rootless paths (in case bootstrap not detected but tools exist)
    [paths addObject:@"/var/jb/usr/bin"];
    [paths addObject:@"/var/jb/bin"];
    [paths addObject:@"/var/LIY/usr/bin"];
    [paths addObject:@"/var/LIY/bin"];

    return paths.array;
}

- (NSArray<NSString *> *)buildLibrarySearchPaths {
    NSMutableOrderedSet<NSString *> *paths = [NSMutableOrderedSet orderedSet];

    // 1. DYLD_LIBRARY_PATH
    const char *ldPath = getenv("DYLD_LIBRARY_PATH");
    if (ldPath) {
        NSString *pathStr = [NSString stringWithUTF8String:ldPath];
        for (NSString *p in [pathStr componentsSeparatedByString:@":"]) {
            if (p.length > 0) [paths addObject:p];
        }
    }

    // 2. Bootstrap library paths
    if (self.bootstrapPath) {
        [paths addObject:[self.bootstrapPath stringByAppendingPathComponent:@"usr/lib"]];
        [paths addObject:[self.bootstrapPath stringByAppendingPathComponent:@"lib"]];
    }

    // 3. Standard paths
    [paths addObject:@"/usr/lib"];
    [paths addObject:@"/usr/local/lib"];
    [paths addObject:@"/opt/procursus/lib"];
    [paths addObject:@"/var/jb/usr/lib"];
    [paths addObject:@"/var/LIY/usr/lib"];

    return paths.array;
}

- (NSDictionary<NSString *, NSString *> *)buildEnvironmentVariables {
    NSMutableDictionary<NSString *, NSString *> *env = [NSMutableDictionary dictionary];

    // Start with current environment
    extern char **environ;
    for (char **ep = environ; *ep != NULL; ep++) {
        NSString *pair = [NSString stringWithUTF8String:*ep];
        NSRange eq = [pair rangeOfString:@"="];
        if (eq.location != NSNotFound) {
            NSString *key = [pair substringToIndex:eq.location];
            NSString *val = [pair substringFromIndex:eq.location + 1];
            env[key] = val;
        }
    }

    // Ensure PATH includes bootstrap paths
    NSMutableOrderedSet<NSString *> *pathSet = [NSMutableOrderedSet orderedSet];
    NSString *existingPath = env[@"PATH"];
    if (existingPath) {
        for (NSString *p in [existingPath componentsSeparatedByString:@":"]) {
            if (p.length > 0) [pathSet addObject:p];
        }
    }
    for (NSString *p in self.binSearchPaths) {
        [pathSet addObject:p];
    }
    env[@"PATH"] = [pathSet.array componentsJoinedByString:@":"];

    // Ensure DYLD_LIBRARY_PATH includes bootstrap libraries
    NSMutableOrderedSet<NSString *> *ldSet = [NSMutableOrderedSet orderedSet];
    NSString *existingLD = env[@"DYLD_LIBRARY_PATH"];
    if (existingLD) {
        for (NSString *p in [existingLD componentsSeparatedByString:@":"]) {
            if (p.length > 0) [ldSet addObject:p];
        }
    }
    for (NSString *p in self.librarySearchPaths) {
        [ldSet addObject:p];
    }
    if (ldSet.count > 0) {
        env[@"DYLD_LIBRARY_PATH"] = [ldSet.array componentsJoinedByString:@":"];
    }

    return env;
}

#pragma mark - Path Resolution

- (NSString *)resolvePath:(NSString *)logicalPath {
    if (!logicalPath || logicalPath.length == 0) return logicalPath;

    // If path already starts with bootstrap path, return as-is
    if (self.bootstrapPath && [logicalPath hasPrefix:self.bootstrapPath]) {
        return logicalPath;
    }

    // If the logical path exists as-is, return it
    if ([[NSFileManager defaultManager] fileExistsAtPath:logicalPath]) {
        return logicalPath;
    }

    // If rootless, prepend bootstrap path
    if (self.isRootless && self.bootstrapPath) {
        NSString *resolved = [self.bootstrapPath stringByAppendingPathComponent:logicalPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath:resolved]) {
            return resolved;
        }
    }

    // Return original (caller will handle non-existence)
    return logicalPath;
}

#pragma mark - Diagnostics

- (NSDictionary *)diagnosticSnapshot {
    return @{
        @"isRootless": @(self.isRootless),
        @"bootstrapPath": self.bootstrapPath ?: @"none",
        @"jailbreakType": self.jailbreakTypeName,
        @"iosVersion": self.iosVersion,
        @"architecture": self.architecture,
        @"binSearchPathsCount": @(self.binSearchPaths.count),
        @"librarySearchPathsCount": @(self.librarySearchPaths.count),
        @"isCharacterized": @(self.isCharacterized)
    };
}

@end
