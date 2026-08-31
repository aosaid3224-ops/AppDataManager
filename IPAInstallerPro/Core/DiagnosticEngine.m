//
//  DiagnosticEngine.m
//  IPAInstallerPro — Commit 1: Process Execution Abstraction
//
//  CHANGES:
//  - Replaced raw posix_spawn/waitpid with ProcessRunner.
//  - Exit codes, signals, stderr, and duration are now captured and logged.
//  - No public API changes.
//

#import "DiagnosticEngine.h"
#import "ProcessRunner.h"
#import "CommandResult.h"
#import "Logger.h"

#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>

extern char **environ;

@interface DiagnosticEngine ()
@end

@implementation DiagnosticEngine

+ (instancetype)sharedEngine {
    static DiagnosticEngine *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

#pragma mark - Public API (unchanged signatures)

- (NSString *)runOutput:(NSString *)cmd {
    // Original: used posix_spawn with waitpid(pid, NULL, 0), ignoring exit code.
    // Now: uses ProcessRunner, captures full result, logs failure details.
    CommandResult *result = [[ProcessRunner sharedRunner] runCommand:cmd
                                                           arguments:@[]
                                                             timeout:30.0];
    if (!result.success) {
        [[Logger sharedLogger] error:[NSString stringWithFormat:@"DiagnosticEngine: %@ failed | category=%@ | exit=%d | stderr=%@",
                                      cmd.lastPathComponent, result.failureCategory, result.exitCode, result.stderrText]];
    }
    return result.stdoutText;
}

- (BOOL)runCommand:(NSString *)cmd arguments:(NSArray<NSString *> *)args output:(NSString **)output {
    // Original: used raw posix_spawn, merged stdout+stderr, ignored exit code.
    // Now: uses ProcessRunner, captures full result, returns NO on failure.
    CommandResult *result = [[ProcessRunner sharedRunner] runCommand:cmd
                                                           arguments:args
                                                             timeout:30.0];
    if (output) {
        *output = result.stdoutText;
    }
    if (!result.success) {
        [[Logger sharedLogger] error:[NSString stringWithFormat:@"DiagnosticEngine: %@ failed | category=%@ | exit=%d | signal=%d | stderr=%@",
                                      cmd.lastPathComponent, result.failureCategory, result.exitCode, result.signalNumber, result.stderrText]];
    }
    return result.success;
}

- (BOOL)runCommand:(NSString *)cmd arguments:(NSArray<NSString *> *)args output:(NSString **)output timeout:(NSTimeInterval)timeout {
    // Same as above with caller-specified timeout.
    CommandResult *result = [[ProcessRunner sharedRunner] runCommand:cmd
                                                           arguments:args
                                                             timeout:timeout];
    if (output) {
        *output = result.stdoutText;
    }
    if (!result.success) {
        [[Logger sharedLogger] error:[NSString stringWithFormat:@"DiagnosticEngine: %@ failed | category=%@ | exit=%d | signal=%d | stderr=%@",
                                      cmd.lastPathComponent, result.failureCategory, result.exitCode, result.signalNumber, result.stderrText]];
    }
    return result.success;
}

#pragma mark - Diagnostics

- (NSDictionary *)runDiagnosticsForBundleID:(NSString *)bundleID {
    NSMutableDictionary *results = [NSMutableDictionary dictionary];

    // Check if app is installed
    NSString *appPath = [self pathForBundleID:bundleID];
    results[@"appPath"] = appPath ?: @"NOT_FOUND";

    // Check executable
    if (appPath) {
        NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
        NSString *execName = info[@"CFBundleExecutable"];

        if (execName) {
            NSString *execPath = [appPath stringByAppendingPathComponent:execName];
            results[@"executablePath"] = execPath;
            results[@"executableExists"] = @([[NSFileManager defaultManager] fileExistsAtPath:execPath]);

            // Check code signature
            NSString *csopsOutput = [self runOutput:[NSString stringWithFormat:@"csops -p %@", execPath]];
            results[@"codeSignature"] = csopsOutput ?: @"N/A";

            // Check entitlements
            NSString *entitlements = [self runOutput:[NSString stringWithFormat:@"ldid -e %@", execPath]];
            results[@"entitlements"] = entitlements ?: @"N/A";

            // Check if binary is signed
            NSString *codesignOutput = [self runOutput:[NSString stringWithFormat:@"codesign -d -v %@ 2>&1", execPath]];
            results[@"codesignInfo"] = codesignOutput ?: @"N/A";
        }
    }

    // Check dylib dependencies
    NSString *otoolOutput = [self runOutput:[NSString stringWithFormat:@"otool -L %@", appPath]];
    results[@"dylibs"] = otoolOutput ?: @"N/A";

    // Check for common issues
    NSMutableArray<NSString *> *issues = [NSMutableArray array];

    if (!appPath) {
        [issues addObject:@"App not found in file system"];
    }

    if (results[@"executableExists"] && ![results[@"executableExists"] boolValue]) {
        [issues addObject:@"Executable missing"];
    }

    NSString *cs = results[@"codeSignature"];
    if (!cs || [cs isEqualToString:@"N/A"] || [cs length] == 0) {
        [issues addObject:@"No code signature detected"];
    }

    NSString *ent = results[@"entitlements"];
    if (!ent || [ent isEqualToString:@"N/A"] || [ent length] == 0) {
        [issues addObject:@"No entitlements found"];
    }

    results[@"issues"] = issues;
    results[@"status"] = (issues.count == 0) ? @"HEALTHY" : @"ISSUES_FOUND";

    return results;
}

- (NSString *)pathForBundleID:(NSString *)bundleID {
    NSArray *paths = @[@"/var/containers/Bundle/Application",
                       @"/var/jb/Applications"];

    for (NSString *basePath in paths) {
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:nil];
        for (NSString *folder in contents) {
            NSString *appPath = [basePath stringByAppendingPathComponent:folder];
            NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
            NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
            if ([info[@"CFBundleIdentifier"] isEqualToString:bundleID]) {
                return appPath;
            }
        }
    }
    return nil;
}

- (NSArray<NSString *> *)checkFilePermissions:(NSString *)path {
    NSMutableArray<NSString *> *issues = [NSMutableArray array];

    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL exists = [fm fileExistsAtPath:path isDirectory:&isDir];

    if (!exists) {
        [issues addObject:@"Path does not exist"];
        return issues;
    }

    // Check if path is readable
    if (![fm isReadableFileAtPath:path]) {
        [issues addObject:@"Path is not readable"];
    }

    // Check if path is writable (for directories)
    if (isDir && ![fm isWritableFileAtPath:path]) {
        [issues addObject:@"Directory is not writable"];
    }

    // Check ownership
    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
    NSString *owner = attrs[NSFileOwnerAccountName];
    if (![owner isEqualToString:@"root"] && ![owner isEqualToString:@"mobile"]) {
        [issues addObject:[NSString stringWithFormat:@"Unexpected owner: %@", owner]];
    }

    return issues;
}

- (NSArray<NSString *> *)checkEntitlements:(NSString *)path {
    NSMutableArray<NSString *> *issues = [NSMutableArray array];

    NSString *entitlements = [self runOutput:[NSString stringWithFormat:@"ldid -e %@", path]];

    if (!entitlements || entitlements.length == 0) {
        [issues addObject:@"No entitlements found"];
        return issues;
    }

    // Check for required entitlements
    NSArray<NSString *> *requiredEntitlements = @[
        @"com.apple.security.application-groups",
        @"get-task-allow",
        @"task_for_pid-allow"
    ];

    for (NSString *ent in requiredEntitlements) {
        if (![entitlements containsString:ent]) {
            [issues addObject:[NSString stringWithFormat:@"Missing entitlement: %@", ent]];
        }
    }

    return issues;
}

- (NSArray<NSString *> *)checkDylibDependencies:(NSString *)path {
    NSMutableArray<NSString *> *issues = [NSMutableArray array];

    NSString *output = [self runOutput:[NSString stringWithFormat:@"otool -L %@", path]];

    if (!output || output.length == 0) {
        [issues addObject:@"Could not analyze dependencies"];
        return issues;
    }

    // Check for common problematic dylibs
    NSArray<NSString *> *problematicDylibs = @[
        @"/System/Library/PrivateFrameworks",
        @"/usr/lib/libSystem.B.dylib"
    ];

    for (NSString *dylib in problematicDylibs) {
        if ([output containsString:dylib]) {
            [issues addObject:[NSString stringWithFormat:@"Links to private framework: %@", dylib]];
        }
    }

    return issues;
}

- (NSArray<NSString *> *)runFullDiagnosticForBundleID:(NSString *)bundleID {
    NSMutableArray<NSString *> *allIssues = [NSMutableArray array];

    NSString *appPath = [self pathForBundleID:bundleID];
    if (!appPath) {
        [allIssues addObject:@"App not found"];
        return allIssues;
    }

    // File permissions
    [allIssues addObjectsFromArray:[self checkFilePermissions:appPath]];

    // Check executable
    NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    NSString *execName = info[@"CFBundleExecutable"];
    if (execName) {
        NSString *execPath = [appPath stringByAppendingPathComponent:execName];
        [allIssues addObjectsFromArray:[self checkEntitlements:execPath]];
        [allIssues addObjectsFromArray:[self checkDylibDependencies:execPath]];
    }

    return allIssues;
}

@end
