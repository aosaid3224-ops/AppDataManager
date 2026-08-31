//
//  JailbreakEnvironment.m
//  IPAInstallerPro — Commit 3: Runtime Environment Discovery
//
//  CHANGES:
//  - Replaced static path checks with RuntimeEnvironment dynamic discovery.
//  - isRootless, rootPath, and jailbreakType now delegate to RuntimeEnvironment.
//  - Added iOS version and architecture exposure.
//  - No public API changes.
//

#import "JailbreakEnvironment.h"
#import "RuntimeEnvironment.h"
#import "Logger.h"

@implementation JailbreakEnvironment

+ (instancetype)sharedEnvironment {
    static JailbreakEnvironment *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self detectEnvironment];
    }
    return self;
}

- (void)detectEnvironment {
    NSDate *start = [NSDate date];

    // Delegate to RuntimeEnvironment for all discovery
    RuntimeEnvironment *rt = [RuntimeEnvironment sharedEnvironment];
    _isRootless = rt.isRootless;
    _rootPath = rt.bootstrapPath ?: @"";
    _jailbreakType = rt.jailbreakTypeName;
    _isJailbroken = (rt.jailbreakType != SpiderJailbreakTypeUnknown) || rt.isRootless;

    // Expose system info from RuntimeEnvironment
    _iosVersion = rt.iosVersion;
    _architecture = rt.architecture;

    // Log discovery results
    NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:start];
    [[Logger sharedLogger] info:[NSString stringWithFormat:@"JailbreakEnvironment: detected in %.3fs | jailbroken=%@ | rootless=%@ | type=%@ | root=%@ | iOS=%@ | arch=%@",
                                 duration,
                                 _isJailbroken ? @"YES" : @"NO",
                                 _isRootless ? @"YES" : @"NO",
                                 _jailbreakType,
                                 _rootPath,
                                 _iosVersion,
                                 _architecture]];

    // Log warning if not characterized
    if (!rt.isCharacterized) {
        [[Logger sharedLogger] warning:@"JailbreakEnvironment: RuntimeEnvironment could not characterize the system"];
    }
}

- (NSDictionary *)environmentInfo {
    RuntimeEnvironment *rt = [RuntimeEnvironment sharedEnvironment];
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"isJailbroken"] = @(self.isJailbroken);
    info[@"isRootless"] = @(self.isRootless);
    info[@"jailbreakType"] = self.jailbreakType ?: @"Unknown";
    info[@"rootPath"] = self.rootPath ?: @"";
    info[@"iosVersion"] = self.iosVersion ?: @"";
    info[@"architecture"] = self.architecture ?: @"";
    info[@"bootstrapPath"] = rt.bootstrapPath ?: @"none";
    info[@"binSearchPathsCount"] = @(rt.binSearchPaths.count);
    info[@"librarySearchPathsCount"] = @(rt.librarySearchPaths.count);
    return info;
}

@end
