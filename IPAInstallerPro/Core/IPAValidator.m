//
//  IPAValidator.m
//  IPAInstallerPro — Commit 1: Process Execution Abstraction
//
//  CHANGES:
//  - Replaced raw posix_spawn/waitpid in runCmdOutput: with ProcessRunner.
//  - Exit code, signal, stderr, and duration are now captured.
//  - No public API changes.
//

#import "IPAValidator.h"
#import "ProcessRunner.h"
#import "CommandResult.h"
#import "Logger.h"

#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>

extern char **environ;

@implementation IPAValidationResult
@end

@implementation IPAValidator

- (IPAValidationResult *)validateIPAAtPath:(NSString *)ipaPath {
    IPAValidationResult *result = [[IPAValidationResult alloc] init];
    NSError *error = nil;
    BOOL valid = [self validateIPAAtPath:ipaPath error:&error];
    result.isReadyForInstall = valid;
    result.status = valid ? IPAValidationStatusValid : IPAValidationStatusUnknown;
    result.statusMessage = valid ? @"IPA صالحة وجاهزة للتحقق" : (error.localizedDescription ?: @"تعذر التحقق من IPA");
    result.issues = error ? @[error.localizedDescription ?: @"خطأ غير معروف"] : @[];
    result.missingLibraries = @[];
    return result;
}

- (IPAValidationResult *)validateExtractedAppAtPath:(NSString *)appPath {
    IPAValidationResult *result = [[IPAValidationResult alloc] init];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    NSString *executable = [info[@"CFBundleExecutable"] isKindOfClass:NSString.class] ? info[@"CFBundleExecutable"] : nil;
    NSString *execPath = executable.length ? [appPath stringByAppendingPathComponent:executable] : nil;
    BOOL valid = appPath.length > 0 && [fm fileExistsAtPath:appPath] && info != nil && executable.length > 0 && [fm isExecutableFileAtPath:execPath];
    result.isReadyForInstall = valid;
    result.status = valid ? IPAValidationStatusValid : (info ? IPAValidationStatusMissingExecutable : IPAValidationStatusMissingInfoPlist);
    result.statusMessage = valid ? @"حزمة التطبيق المستخرجة صالحة" : @"حزمة التطبيق المستخرجة غير مكتملة";
    result.issues = valid ? @[] : @[result.statusMessage];
    result.missingLibraries = @[];
    return result;
}

- (NSArray<NSString *> *)checkDependenciesAtAppPath:(NSString *)appPath {
    if (appPath.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:appPath]) return @[];
    return @[];
}

+ (instancetype)sharedValidator {
    static IPAValidator *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

#pragma mark - Public API

- (BOOL)validateIPAAtPath:(NSString *)path error:(NSError **)error {
    // Check file exists
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        if (error) {
            *error = [NSError errorWithDomain:@"IPAValidator" code:1 userInfo:@{NSLocalizedDescriptionKey: @"IPA file not found"}];
        }
        return NO;
    }

    // Check file size
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    unsigned long long fileSize = [attrs[NSFileSize] unsignedLongLongValue];
    if (fileSize == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"IPAValidator" code:2 userInfo:@{NSLocalizedDescriptionKey: @"IPA file is empty"}];
        }
        return NO;
    }

    // Check if it's a valid zip file
    if (![self isValidZipFile:path]) {
        if (error) {
            *error = [NSError errorWithDomain:@"IPAValidator" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Invalid IPA file format"}];
        }
        return NO;
    }

    // Extract and validate Info.plist
    NSString *infoPlist = [self extractInfoPlistFromIPA:path];
    if (!infoPlist || infoPlist.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"IPAValidator" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Could not extract Info.plist"}];
        }
        return NO;
    }

    // Validate Info.plist content
    NSData *plistData = [infoPlist dataUsingEncoding:NSUTF8StringEncoding];
    if (!plistData) {
        if (error) {
            *error = [NSError errorWithDomain:@"IPAValidator" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Invalid Info.plist content"}];
        }
        return NO;
    }

    // Check required fields
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPlist];
    if (!info[@"CFBundleIdentifier"]) {
        if (error) {
            *error = [NSError errorWithDomain:@"IPAValidator" code:6 userInfo:@{NSLocalizedDescriptionKey: @"Missing CFBundleIdentifier"}];
        }
        return NO;
    }

    if (!info[@"CFBundleExecutable"]) {
        if (error) {
            *error = [NSError errorWithDomain:@"IPAValidator" code:7 userInfo:@{NSLocalizedDescriptionKey: @"Missing CFBundleExecutable"}];
        }
        return NO;
    }

    // Validate executable architecture
    NSString *execPath = [self executablePathForIPA:path];
    if (execPath) {
        if (![self validateExecutableArchitecture:execPath]) {
            if (error) {
                *error = [NSError errorWithDomain:@"IPAValidator" code:8 userInfo:@{NSLocalizedDescriptionKey: @"Invalid executable architecture"}];
            }
            return NO;
        }
    }

    return YES;
}

- (NSDictionary *)detailedValidationForIPA:(NSString *)path {
    NSMutableDictionary *results = [NSMutableDictionary dictionary];

    // Basic checks
    results[@"exists"] = @([[NSFileManager defaultManager] fileExistsAtPath:path]);

    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    results[@"size"] = attrs[NSFileSize] ?: @0;

    // Zip validation
    results[@"validZip"] = @([self isValidZipFile:path]);

    // Info.plist
    NSString *infoPlist = [self extractInfoPlistFromIPA:path];
    results[@"hasInfoPlist"] = @(infoPlist != nil && infoPlist.length > 0);

    if (infoPlist) {
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPlist];
        results[@"bundleID"] = info[@"CFBundleIdentifier"] ?: @"";
        results[@"bundleName"] = info[@"CFBundleName"] ?: @"";
        results[@"version"] = info[@"CFBundleShortVersionString"] ?: @"";
        results[@"executable"] = info[@"CFBundleExecutable"] ?: @"";
        results[@"minimumOS"] = info[@"MinimumOSVersion"] ?: @"";
    }

    // Check code signature
    NSString *execPath = [self executablePathForIPA:path];
    if (execPath) {
        results[@"signatureValid"] = @([self validateCodeSignature:execPath]);
        results[@"architectureValid"] = @([self validateExecutableArchitecture:execPath]);
    }

    return results;
}

#pragma mark - Private Methods

- (BOOL)isValidZipFile:(NSString *)path {
    // Check zip magic number
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) return NO;

    NSData *header = [handle readDataOfLength:4];
    [handle closeFile];

    if (header.length < 4) return NO;

    const uint8_t *bytes = header.bytes;
    // ZIP magic: 50 4B 03 04
    return (bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04);
}

- (NSString *)extractInfoPlistFromIPA:(NSString *)path {
    // Create temporary directory
    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:nil];

    // Extract Info.plist using ProcessRunner (replaces raw posix_spawn)
    NSString *cmd = @"/usr/bin/unzip";
    NSArray<NSString *> *args = @[@"-p", path, @"Payload/*/Info.plist"];
    CommandResult *result = [[ProcessRunner sharedRunner] runCommand:cmd arguments:args timeout:60.0];

    if (!result.success) {
        [[Logger sharedLogger] error:[NSString stringWithFormat:@"IPAValidator: unzip failed | category=%@ | exit=%d | stderr=%@",
                                      result.failureCategory, result.exitCode, result.stderrText]];
        [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];
        return nil;
    }

    NSString *infoPlist = result.stdoutText;
    if (!infoPlist || infoPlist.length == 0) {
        [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];
        return nil;
    }

    // Write to temp file for plist parsing
    NSString *tempPlist = [tempDir stringByAppendingPathComponent:@"Info.plist"];
    [infoPlist writeToFile:tempPlist atomically:YES encoding:NSUTF8StringEncoding error:nil];

    // Clean up temp dir after a delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];
    });

    return tempPlist;
}

- (NSString *)executablePathForIPA:(NSString *)path {
    NSString *infoPlist = [self extractInfoPlistFromIPA:path];
    if (!infoPlist) return nil;

    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPlist];
    NSString *execName = info[@"CFBundleExecutable"];
    if (!execName) return nil;

    // Extract the app bundle to find executable
    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:nil];

    CommandResult *result = [[ProcessRunner sharedRunner] runCommand:@"/usr/bin/unzip"
                                                           arguments:@[@"-q", path, @"-d", tempDir]
                                                             timeout:60.0];
    if (!result.success) {
        [[Logger sharedLogger] error:[NSString stringWithFormat:@"IPAValidator: unzip bundle failed | category=%@ | exit=%d",
                                      result.failureCategory, result.exitCode]];
        [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];
        return nil;
    }

    NSString *payloadPath = [tempDir stringByAppendingPathComponent:@"Payload"];
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadPath error:nil];
    for (NSString *item in contents) {
        if ([item hasSuffix:@".app"]) {
            NSString *appPath = [payloadPath stringByAppendingPathComponent:item];
            NSString *execPath = [appPath stringByAppendingPathComponent:execName];
            if ([[NSFileManager defaultManager] fileExistsAtPath:execPath]) {
                // Clean up after delay
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                    [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];
                });
                return execPath;
            }
        }
    }

    [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];
    return nil;
}

- (BOOL)validateCodeSignature:(NSString *)path {
    CommandResult *result = [[ProcessRunner sharedRunner] runCommand:@"/usr/bin/codesign"
                                                           arguments:@[@"-v", path]
                                                             timeout:30.0];
    // codesign -v returns 0 if valid, non-zero if invalid
    return result.success;
}

- (BOOL)validateExecutableArchitecture:(NSString *)path {
    CommandResult *result = [[ProcessRunner sharedRunner] runCommand:@"/usr/bin/file"
                                                           arguments:@[path]
                                                             timeout:30.0];
    if (!result.success) return NO;

    NSString *output = result.stdoutText;
    if (!output || output.length == 0) return NO;

    // Check for valid architectures
    return ([output containsString:@"Mach-O"] ||
            [output containsString:@"ARM64"] ||
            [output containsString:@"ARMv7"] ||
            [output containsString:@"x86_64"]);
}

#pragma mark - Legacy runCmdOutput: (REMOVED)
// The raw posix_spawn implementation previously here has been replaced by ProcessRunner.
// All call sites now use [[ProcessRunner sharedRunner] runCommand:arguments:timeout:].

@end
