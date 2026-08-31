//
//  IPAStructuralAnalyzer.m
//  IPAInstallerPro — Commit 1: Process Execution Abstraction
//
//  CHANGES:
//  - Replaced raw posix_spawn/waitpid in runCmdOutput: with ProcessRunner.
//  - FIXES BUG C-9: previously passed NULL environ to posix_spawn; now uses
//    ProcessRunner which always passes environ.
//  - Exit code, signal, stderr, and duration are now captured.
//  - No public API changes.
//

#import "IPAStructuralAnalyzer.h"
#import "ProcessRunner.h"
#import "CommandResult.h"
#import "Logger.h"

#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>

extern char **environ;

@interface IPAStructuralAnalyzer ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *cachedAnalyses;
@property (nonatomic, strong) dispatch_queue_t analysisQueue;
@end

@implementation IPAStructuralAnalyzer

+ (instancetype)sharedAnalyzer {
    static IPAStructuralAnalyzer *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cachedAnalyses = [NSMutableDictionary dictionary];
        _analysisQueue = dispatch_queue_create("com.spider.structuralanalyzer", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - Public API

- (IPAStructuralResult *)analyzeIPAAtPath:(NSString *)path {
    // Check cache
    __block IPAStructuralResult *cachedResult = nil;
    dispatch_sync(self.analysisQueue, ^{
        NSNumber *cached = self.cachedAnalyses[path];
        if (cached && cached.boolValue) {
            // Return cached result if available
            cachedResult = [self cachedResultForPath:path];
        }
    });

    if (cachedResult) return cachedResult;

    IPAStructuralResult *result = [[IPAStructuralResult alloc] init];
    result.ipaPath = path;

    // Extract and analyze structure
    [self extractAndAnalyzeIPA:path result:result];

    // Cache result
    dispatch_async(self.analysisQueue, ^{
        self.cachedAnalyses[path] = @YES;
        [self cacheResult:result forPath:path];
    });

    return result;
}

- (NSArray<NSString *> *)listContentsOfIPA:(NSString *)path {
    CommandResult *result = [[ProcessRunner sharedRunner] runCommand:@"/usr/bin/unzip"
                                                           arguments:@[@"-Z1", path]
                                                             timeout:30.0];
    if (!result.success) {
        [[Logger sharedLogger] error:[NSString stringWithFormat:@"IPAStructuralAnalyzer: unzip -Z1 failed | category=%@ | exit=%d | stderr=%@",
                                      result.failureCategory, result.exitCode, result.stderrText]];
        return @[];
    }

    NSString *output = result.stdoutText;
    if (!output || output.length == 0) return @[];

    return [output componentsSeparatedByString:@"\n"];
}

- (NSDictionary *)extractInfoPlistFromIPA:(NSString *)path {
    CommandResult *result = [[ProcessRunner sharedRunner] runCommand:@"/usr/bin/unzip"
                                                           arguments:@[@"-p", path, @"Payload/*/Info.plist"]
                                                             timeout:30.0];
    if (!result.success) {
        [[Logger sharedLogger] error:[NSString stringWithFormat:@"IPAStructuralAnalyzer: unzip Info.plist failed | category=%@ | exit=%d",
                                      result.failureCategory, result.exitCode]];
        return nil;
    }

    NSString *plistContent = result.stdoutText;
    if (!plistContent || plistContent.length == 0) return nil;

    // Write to temp file and parse
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [plistContent writeToFile:tempPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:tempPath];

    [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];

    return info;
}

- (NSArray<NSString *> *)findExecutablesInIPA:(NSString *)path {
    NSArray *contents = [self listContentsOfIPA:path];
    NSMutableArray<NSString *> *executables = [NSMutableArray array];

    for (NSString *item in contents) {
        if ([item hasSuffix:@""] && ![item containsString:@"Frameworks/"] && ![item containsString:@"PlugIns/"]) {
            // Potential main executable
            [executables addObject:item];
        }
    }

    return executables;
}

- (NSArray<NSString *> *)findFrameworksInIPA:(NSString *)path {
    NSArray *contents = [self listContentsOfIPA:path];
    NSMutableArray<NSString *> *frameworks = [NSMutableArray array];

    for (NSString *item in contents) {
        if ([item containsString:@"Frameworks/"] && [item hasSuffix:@".framework/"]) {
            [frameworks addObject:item];
        }
    }

    return frameworks;
}

- (NSArray<NSString *> *)findPlugInsInIPA:(NSString *)path {
    NSArray *contents = [self listContentsOfIPA:path];
    NSMutableArray<NSString *> *plugins = [NSMutableArray array];

    for (NSString *item in contents) {
        if ([item containsString:@"PlugIns/"] && [item hasSuffix:@".appex/"]) {
            [plugins addObject:item];
        }
    }

    return plugins;
}

- (NSArray<NSString *> *)findDylibsInIPA:(NSString *)path {
    NSArray *contents = [self listContentsOfIPA:path];
    NSMutableArray<NSString *> *dylibs = [NSMutableArray array];

    for (NSString *item in contents) {
        if ([item hasSuffix:@".dylib"]) {
            [dylibs addObject:item];
        }
    }

    return dylibs;
}

- (BOOL)hasWatchExtension:(NSString *)path {
    NSArray *plugins = [self findPlugInsInIPA:path];
    for (NSString *plugin in plugins) {
        if ([plugin containsString:@"watchkit"]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)hasAppClips:(NSString *)path {
    NSDictionary *info = [self extractInfoPlistFromIPA:path];
    if (!info) return NO;

    // Check for App Clips configuration
    return info[@"NSAppClip"] != nil;
}

#pragma mark - Private Methods

- (void)extractAndAnalyzeIPA:(NSString *)path result:(IPAStructuralResult *)result {
    // Create temporary extraction directory
    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:nil];

    // Extract IPA
    CommandResult *extractResult = [[ProcessRunner sharedRunner] runCommand:@"/usr/bin/unzip"
                                                                   arguments:@[@"-q", path, @"-d", tempDir]
                                                                     timeout:60.0];
    if (!extractResult.success) {
        [[Logger sharedLogger] error:[NSString stringWithFormat:@"IPAStructuralAnalyzer: unzip extraction failed | category=%@ | exit=%d | stderr=%@",
                                      extractResult.failureCategory, extractResult.exitCode, extractResult.stderrText]];
        result.error = [NSString stringWithFormat:@"Extraction failed: %@", extractResult.failureCategory];
        [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];
        return;
    }

    // Find Payload directory
    NSString *payloadPath = [tempDir stringByAppendingPathComponent:@"Payload"];
    NSArray *payloadContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadPath error:nil];

    for (NSString *item in payloadContents) {
        if ([item hasSuffix:@".app"]) {
            NSString *appPath = [payloadPath stringByAppendingPathComponent:item];
            [self analyzeAppBundle:appPath result:result];
            break;
        }
    }

    // Clean up
    [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];
}

- (void)analyzeAppBundle:(NSString *)appPath result:(IPAStructuralResult *)result {
    // Analyze main executable
    NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];

    if (info) {
        result.bundleID = info[@"CFBundleIdentifier"];
        result.bundleName = info[@"CFBundleName"];
        result.version = info[@"CFBundleShortVersionString"];
        result.executableName = info[@"CFBundleExecutable"];
    }

    // Find all Mach-O binaries
    [self findMachOBinariesInDirectory:appPath result:result];

    // Analyze frameworks
    NSString *frameworksPath = [appPath stringByAppendingPathComponent:@"Frameworks"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:frameworksPath]) {
        NSArray *frameworks = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:frameworksPath error:nil];
        for (NSString *framework in frameworks) {
            if ([framework hasSuffix:@".framework"]) {
                NSString *frameworkPath = [frameworksPath stringByAppendingPathComponent:framework];
                [self analyzeFramework:frameworkPath result:result];
            }
        }
    }

    // Analyze plug-ins
    NSString *pluginsPath = [appPath stringByAppendingPathComponent:@"PlugIns"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:pluginsPath]) {
        NSArray *plugins = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pluginsPath error:nil];
        for (NSString *plugin in plugins) {
            if ([plugin hasSuffix:@".appex"]) {
                NSString *pluginPath = [pluginsPath stringByAppendingPathComponent:plugin];
                [self analyzePlugIn:pluginPath result:result];
            }
        }
    }
}

- (void)findMachOBinariesInDirectory:(NSString *)directory result:(IPAStructuralResult *)result {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:directory error:nil];

    for (NSString *item in contents) {
        NSString *itemPath = [directory stringByAppendingPathComponent:item];

        BOOL isDir = NO;
        [fm fileExistsAtPath:itemPath isDirectory:&isDir];

        if (isDir && [item hasSuffix:@".framework"]) {
            // Analyze framework binary
            NSString *frameworkName = [item stringByDeletingPathExtension];
            NSString *binaryPath = [itemPath stringByAppendingPathComponent:frameworkName];
            if ([fm fileExistsAtPath:binaryPath]) {
                [result addMachOBinary:binaryPath];
            }
        } else if (isDir && [item hasSuffix:@".appex"]) {
            // Analyze plug-in binary
            NSString *infoPath = [itemPath stringByAppendingPathComponent:@"Info.plist"];
            NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
            NSString *execName = info[@"CFBundleExecutable"];
            if (execName) {
                NSString *binaryPath = [itemPath stringByAppendingPathComponent:execName];
                if ([fm fileExistsAtPath:binaryPath]) {
                    [result addMachOBinary:binaryPath];
                }
            }
        } else if (!isDir) {
            // Check if it's a Mach-O binary
            if ([self isMachOBinary:itemPath]) {
                [result addMachOBinary:itemPath];
            }
        }
    }
}

- (BOOL)isMachOBinary:(NSString *)path {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) return NO;

    NSData *header = [handle readDataOfLength:4];
    [handle closeFile];

    if (header.length < 4) return NO;

    const uint32_t *magic = header.bytes;
    // MH_MAGIC_64 = 0xfeedfacf, MH_MAGIC = 0xfeedface, FAT_MAGIC = 0xcafebabe, FAT_MAGIC_64 = 0xcafebabf
    return (*magic == 0xfeedfacf || *magic == 0xfeedface ||
            *magic == 0xcafebabe || *magic == 0xcafebabf);
}

- (void)analyzeFramework:(NSString *)frameworkPath result:(IPAStructuralResult *)result {
    NSString *frameworkName = [frameworkPath lastPathComponent];
    NSString *binaryName = [frameworkName stringByDeletingPathExtension];
    NSString *binaryPath = [frameworkPath stringByAppendingPathComponent:binaryName];

    if ([[NSFileManager defaultManager] fileExistsAtPath:binaryPath]) {
        [result addFramework:frameworkPath withBinary:binaryPath];
    }
}

- (void)analyzePlugIn:(NSString *)pluginPath result:(IPAStructuralResult *)result {
    NSString *infoPath = [pluginPath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    NSString *execName = info[@"CFBundleExecutable"];

    if (execName) {
        NSString *binaryPath = [pluginPath stringByAppendingPathComponent:execName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:binaryPath]) {
            [result addPlugIn:pluginPath withBinary:binaryPath];
        }
    }
}

- (IPAStructuralResult *)cachedResultForPath:(NSString *)path {
    // Implementation would retrieve from persistent cache if implemented
    return nil;
}

- (void)cacheResult:(IPAStructuralResult *)result forPath:(NSString *)path {
    // Implementation would store to persistent cache if implemented
}

#pragma mark - Legacy runCmdOutput: (REMOVED)
// The raw posix_spawn implementation previously here has been replaced by ProcessRunner.
// FIXES BUG C-9: previously passed NULL environ; ProcessRunner always passes environ.

@end
