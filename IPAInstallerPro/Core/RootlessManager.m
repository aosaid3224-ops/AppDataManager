//
//  RootlessManager.m
//  IPAInstallerPro — Commit 3: Runtime Environment Discovery
//
//  CHANGES:
//  - Replaced hardcoded /var/jb fallback with RuntimeEnvironment delegation.
//  - resolvePath now uses bootstrapPath dynamically discovered.
//  - isRootlessActive delegates to RuntimeEnvironment.
//  - No public API changes.
//

#import "RootlessManager.h"
#import "RuntimeEnvironment.h"
#import "Logger.h"

@implementation RootlessManager

+ (instancetype)sharedManager {
    static RootlessManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // RuntimeEnvironment is the single source of truth for rootless state.
    }
    return self;
}

#pragma mark - Public API (unchanged signatures)

- (NSString *)resolvePath:(NSString *)path {
    if (!path || path.length == 0) return path;

    RuntimeEnvironment *rt = [RuntimeEnvironment sharedEnvironment];

    // If path already starts with bootstrap path, it's already resolved
    if (rt.bootstrapPath && [path hasPrefix:rt.bootstrapPath]) {
        return path;
    }

    // If the path exists as-is, return it
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }

    // FIX(v3.0.26): In rootless, ALWAYS prepend bootstrap path.
    // resolvePath must be deterministic based on runtime environment (jbroot), NOT file existence.
    // New destinations that don't exist yet must resolve to the same namespace as staging.
    // This ensures staging (/var/jb/var/tmp/...) and destApp (/var/jb/Applications/...)
    // are always on the same logical filesystem, regardless of whether the file exists.
    if (rt.isRootless && rt.bootstrapPath) {
        NSString *resolved;
        if ([path hasPrefix:@"/"]) {
            NSString *relativePath = [path substringFromIndex:1];
            resolved = [rt.bootstrapPath stringByAppendingPathComponent:relativePath];
        } else {
            resolved = [rt.bootstrapPath stringByAppendingPathComponent:path];
        }
        return resolved;
    }

    // Fallback: return original path (caller handles non-existence)
    return path;
}

- (NSString *)rootlessPathForPath:(NSString *)path {
    return [self resolvePath:path];
}

- (NSString *)standardPathForPath:(NSString *)path {
    // Reverse: if path starts with bootstrap path, strip it
    RuntimeEnvironment *rt = [RuntimeEnvironment sharedEnvironment];
    if (rt.bootstrapPath && [path hasPrefix:rt.bootstrapPath]) {
        NSString *relative = [path substringFromIndex:rt.bootstrapPath.length];
        if ([relative hasPrefix:@"/"]) {
            return relative;
        }
        return [@"/" stringByAppendingString:relative];
    }
    return path;
}

- (BOOL)fileExistsAtLogicalPath:(NSString *)path {
    NSString *resolved = [self resolvePath:path];
    return [[NSFileManager defaultManager] fileExistsAtPath:resolved];
}

- (BOOL)createDirectoryAtLogicalPath:(NSString *)path error:(NSError **)error {
    NSString *resolved = [self resolvePath:path];
    return [[NSFileManager defaultManager] createDirectoryAtPath:resolved withIntermediateDirectories:YES attributes:nil error:error];
}

- (BOOL)fileExistsAtRootlessPath:(NSString *)path {
    return [self fileExistsAtLogicalPath:path];
}

- (BOOL)isFileAtPathExecutable:(NSString *)path {
    NSString *resolved = [self resolvePath:path];
    return [[NSFileManager defaultManager] isExecutableFileAtPath:resolved];
}

@end
