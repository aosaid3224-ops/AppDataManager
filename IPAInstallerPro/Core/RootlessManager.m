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
        _isRootlessActive = [RuntimeEnvironment sharedEnvironment].isRootless;
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

    // If rootless, try prepending bootstrap path
    if (rt.isRootless && rt.bootstrapPath) {
        NSString *resolved = [rt.bootstrapPath stringByAppendingPathComponent:path];
        if ([[NSFileManager defaultManager] fileExistsAtPath:resolved]) {
            return resolved;
        }

        // Also try without leading slash (e.g., /usr/bin/ldid → /var/jb/usr/bin/ldid)
        if ([path hasPrefix:@"/"]) {
            NSString *relativePath = [path substringFromIndex:1];
            NSString *altResolved = [rt.bootstrapPath stringByAppendingPathComponent:relativePath];
            if ([[NSFileManager defaultManager] fileExistsAtPath:altResolved]) {
                return altResolved;
            }
        }
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

- (BOOL)fileExistsAtRootlessPath:(NSString *)path {
    NSString *resolved = [self resolvePath:path];
    return [[NSFileManager defaultManager] fileExistsAtPath:resolved];
}

- (BOOL)isFileAtPathExecutable:(NSString *)path {
    NSString *resolved = [self resolvePath:path];
    return [[NSFileManager defaultManager] isExecutableFileAtPath:resolved];
}

@end
