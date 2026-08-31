//
//  ExecutableValidator.h
//  IPAInstallerPro — Commit 2: ldid Executable Validator
//
//  Dynamic executable discovery and validation.
//  Rules:
//    - Never assumes a single path.
//    - Always tests invocation (not just file existence).
//    - Always classifies failure with precision.
//    - Always uses ProcessRunner (never raw posix_spawn).
//    - Never touches UI.
//

#import <Foundation/Foundation.h>
@class ExecutableCapability;

@interface ExecutableValidator : NSObject

+ (instancetype)sharedValidator;

/// Validate a specific executable by name (e.g., @"ldid").
/// Searches PATH, standard paths, and Rootless paths dynamically.
/// @param name Executable name (e.g., @"ldid", @"unzip", @"uicache").
/// @return ExecutableCapability with full diagnostic evidence.
- (ExecutableCapability *)validateExecutableNamed:(NSString *)name;

/// Validate ldid specifically (convenience method with ldid-specific tests).
- (ExecutableCapability *)validateLDID;

/// Validate unzip specifically.
- (ExecutableCapability *)validateUnzip;

/// Validate uicache specifically.
- (ExecutableCapability *)validateUICache;

/// Returns the first found absolute path for the executable, or nil.
- (NSString *)findExecutableNamed:(NSString *)name;

/// Returns all search paths that will be used for discovery.
- (NSArray<NSString *> *)currentSearchPaths;

@end
