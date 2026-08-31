//
//  RuntimeEnvironment.h
//  IPAInstallerPro — Commit 3: Runtime Environment Discovery
//
//  Dynamic discovery of the jailbreak/bootstrap runtime environment.
//  Never assumes a single path. Uses multiple heuristics.
//  No UI logic. No state machine. Pure discovery.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SpiderJailbreakType) {
    SpiderJailbreakTypeUnknown,
    SpiderJailbreakTypeCheckra1n,
    SpiderJailbreakTypeUnc0ver,
    SpiderJailbreakTypeDopamine,
    SpiderJailbreakTypePalera1n,
    SpiderJailbreakTypeTaurine,
    SpiderJailbreakTypeOdyssey,
    SpiderJailbreakTypeXinaA15,
    SpiderJailbreakTypeOther
};

@interface RuntimeEnvironment : NSObject

+ (instancetype)sharedEnvironment;

/// The detected bootstrap root path (e.g., /var/jb, /var/LIY, /opt/procursus, or nil).
@property (nonatomic, copy, readonly) NSString *bootstrapPath;

/// Whether the environment is rootless (determined by bootstrap indicators).
@property (nonatomic, assign, readonly) BOOL isRootless;

/// Detected jailbreak type.
@property (nonatomic, assign, readonly) SpiderJailbreakType jailbreakType;

/// Human-readable jailbreak type name.
@property (nonatomic, copy, readonly) NSString *jailbreakTypeName;

/// iOS version string.
@property (nonatomic, copy, readonly) NSString *iosVersion;

/// Device architecture (e.g., arm64, arm64e).
@property (nonatomic, copy, readonly) NSString *architecture;

/// Ordered array of binary search paths (PATH + bootstrap bins).
@property (nonatomic, copy, readonly) NSArray<NSString *> *binSearchPaths;

/// Library search paths (DYLD_LIBRARY_PATH + bootstrap libs).
@property (nonatomic, copy, readonly) NSArray<NSString *> *librarySearchPaths;

/// Full environment variables dictionary for subprocess spawning.
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *environmentVariables;

/// Whether the environment was successfully characterized.
@property (nonatomic, assign, readonly) BOOL isCharacterized;

/// Diagnostic snapshot of the environment (for logging, no sensitive data).
- (NSDictionary *)diagnosticSnapshot;

/// Resolve a logical path to an absolute path using bootstrapPath.
/// @param logicalPath e.g., @"/usr/bin/ldid"
/// @return Absolute path, or original if no bootstrap detected.
- (NSString *)resolvePath:(NSString *)logicalPath;

@end
