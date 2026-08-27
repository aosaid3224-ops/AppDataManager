//
// IPAStructuralAnalyzer.m
// IPAInstallerPro — Phase 1: Universal IPA Structural Reader
//
// Read-only structural analyzer.
// Extracts IPA to temp, discovers all bundles and executables recursively,
// analyzes Mach-O binaries internally, returns structured result, cleans up.
//

#import "IPAStructuralAnalyzer.h"
#import "IPAStructuralResult.h"
#import "MachOAnalyzer.h"
#import "RootlessManager.h"
#import <sys/stat.h>
#import <spawn.h>
#import <sys/wait.h>
#import <signal.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>

// ============================================
// Mach-O Magic Constants (for quick detection)
// ============================================
#define MH_MAGIC        0xfeedface
#define MH_MAGIC_64     0xfeedfacf
#define MH_CIGAM        0xcefaedfe
#define MH_CIGAM_64     0xcffaedfe
#define FAT_MAGIC       0xcafebabe
#define FAT_CIGAM       0xbebafeca
#define FAT_MAGIC_64    0xcafebabf
#define FAT_CIGAM_64    0xbfbafeca

@interface IPAStructuralAnalyzer ()
- (NSString *)createTempDirectory;
- (BOOL)extractIPA:(NSString *)ipaPath toDirectory:(NSString *)destDir error:(NSString **)error;
- (void)cleanupDirectory:(NSString *)path;
- (NSString *)runCmdOutput:(NSString *)cmd args:(NSArray *)args;
- (BOOL)isMachOMagic:(uint32_t)magic;
- (NSString *)bundleTypeFromPath:(NSString *)path;
- (NSDictionary *)readInfoPlistAtPath:(NSString *)plistPath;
@end

@implementation IPAStructuralAnalyzer

+ (instancetype)sharedAnalyzer {
    static IPAStructuralAnalyzer *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

#pragma mark - Public API

- (IPAStructuralResult *)analyzeIPAAtPath:(NSString *)ipaPath {
    return [self analyzeIPAAtPath:ipaPath keepExtracted:NO];
}

- (IPAStructuralResult *)analyzeIPAAtPath:(NSString *)ipaPath keepExtracted:(BOOL)keep {
    IPAStructuralResult *result = [[IPAStructuralResult alloc] init];
    result.ipaPath = ipaPath;
    result.analysisStartTime = [NSDate date];
    result.success = NO;

    // 1. Validate IPA exists
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:ipaPath]) {
        [result.errors addObject:@"IPA file does not exist"];
        result.analysisEndTime = [NSDate date];
        result.analysisDurationMs = [result.analysisEndTime timeIntervalSinceDate:result.analysisStartTime] * 1000.0;
        return result;
    }

    struct stat st;
    if (stat(ipaPath.UTF8String, &st) == 0) {
        result.ipaSize = st.st_size;
    }

    // 2. Create temp directory
    NSString *tempDir = [self createTempDirectory];
    if (!tempDir) {
        [result.errors addObject:@"Failed to create temporary directory"];
        result.analysisEndTime = [NSDate date];
        result.analysisDurationMs = [result.analysisEndTime timeIntervalSinceDate:result.analysisStartTime] * 1000.0;
        return result;
    }
    result.extractPath = tempDir;

    // 3. Extract IPA
    NSString *extractError = nil;
    if (![self extractIPA:ipaPath toDirectory:tempDir error:&extractError]) {
        [result.errors addObject:[NSString stringWithFormat:@"Extraction failed: %@", extractError ?: @"unknown"]];
        if (!keep) [self cleanupDirectory:tempDir];
        result.analysisEndTime = [NSDate date];
        result.analysisDurationMs = [result.analysisEndTime timeIntervalSinceDate:result.analysisStartTime] * 1000.0;
        return result;
    }

    // 4. Discover Payload directory
    NSString *payloadPath = [tempDir stringByAppendingPathComponent:@"Payload"];
    if (![fm fileExistsAtPath:payloadPath]) {
        [result.errors addObject:@"No Payload directory found in IPA"];
        if (!keep) [self cleanupDirectory:tempDir];
        result.analysisEndTime = [NSDate date];
        result.analysisDurationMs = [result.analysisEndTime timeIntervalSinceDate:result.analysisStartTime] * 1000.0;
        return result;
    }

    // 5. Walk the tree recursively
    NSMutableArray<IPAStructuralBundle *> *bundles = [NSMutableArray array];
    NSMutableArray<IPAStructuralExecutable *> *executables = [NSMutableArray array];
    NSMutableSet<NSString *> *processedExePaths = [NSMutableSet set];

    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:payloadPath];
    NSString *relativePath = nil;

    while ((relativePath = [enumerator nextObject])) {
        NSString *fullPath = [payloadPath stringByAppendingPathComponent:relativePath];

        // Skip symlinks for safety
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
        if (attrs && [attrs[NSFileType] isEqualToString:NSFileTypeSymbolicLink]) {
            [result.warnings addObject:[NSString stringWithFormat:@"Symlink skipped: %@", relativePath]];
            continue;
        }

        BOOL isDirectory = NO;
        BOOL exists = [fm fileExistsAtPath:fullPath isDirectory:&isDirectory];
        if (!exists) continue;

        // ============================================
        // BUNDLE DISCOVERY
        // ============================================
        if (isDirectory) {
            NSString *bundleType = [self bundleTypeFromPath:relativePath];
            if (bundleType) {
                IPAStructuralBundle *bundle = [[IPAStructuralBundle alloc] init];
                bundle.path = fullPath;
                bundle.bundleType = bundleType;

                // Determine nesting level and parent
                NSInteger nestingLevel = 0;
                NSString *parentPath = nil;
                NSArray *components = [relativePath pathComponents];
                for (NSInteger i = components.count - 2; i >= 0; i--) {
                    NSString *comp = components[i];
                    if ([comp.lowercaseString hasSuffix:@".app"] ||
                        [comp.lowercaseString hasSuffix:@".appex"] ||
                        [comp.lowercaseString hasSuffix:@".xpc"] ||
                        [comp.lowercaseString hasSuffix:@".framework"] ||
                        [comp.lowercaseString hasSuffix:@".bundle"]) {
                        nestingLevel++;
                        if (!parentPath) {
                            parentPath = [payloadPath stringByAppendingPathComponent:
                                [[components subarrayWithRange:NSMakeRange(0, i + 1)] componentsJoinedByString:@"/"]];
                        }
                    }
                }
                bundle.nestingLevel = nestingLevel;
                bundle.parentBundlePath = parentPath;

                // Read Info.plist
                NSString *infoPlistPath = [fullPath stringByAppendingPathComponent:@"Info.plist"];
                if ([fm fileExistsAtPath:infoPlistPath]) {
                    NSDictionary *plist = [self readInfoPlistAtPath:infoPlistPath];
                    if (plist) {
                        bundle.bundleIdentifier = plist[@"CFBundleIdentifier"];
                        bundle.executableName = plist[@"CFBundleExecutable"];
                        if (bundle.executableName) {
                            bundle.executablePath = [fullPath stringByAppendingPathComponent:bundle.executableName];
                            bundle.executableExists = [fm fileExistsAtPath:bundle.executablePath];
                        }
                    }
                }

                [bundles addObject:bundle];
            }
            continue;
        }

        // ============================================
        // EXECUTABLE DISCOVERY (Mach-O Magic Check)
        // ============================================
        // Check EVERY file for Mach-O magic, regardless of extension.

        if ([processedExePaths containsObject:fullPath]) continue;

        NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:fullPath];
        if (!fh) continue;

        NSData *magicData = [fh readDataOfLength:4];
        [fh closeFile];

        if (magicData.length < 4) continue;

        uint32_t magic = 0;
        [magicData getBytes:&magic length:4];

        if (![self isMachOMagic:magic]) continue;

        // This is a Mach-O binary. Analyze it.
        [processedExePaths addObject:fullPath];

        MachOAnalysisResult *machoResult = [[MachOAnalyzer sharedAnalyzer] analyzeFileAtPath:fullPath];

        // Convert MachOAnalysisResult to IPAStructuralExecutable
        IPAStructuralExecutable *exec = [[IPAStructuralExecutable alloc] init];
        exec.path = fullPath;
        exec.name = fullPath.lastPathComponent;
        exec.fileSize = machoResult.fileSize;
        exec.machOType = machoResult.machOType;
        exec.machOTypeName = machoResult.machOTypeName;
        exec.uuid = machoResult.uuid;
        exec.minOSVersion = machoResult.minOSVersion;
        exec.sdkVersion = machoResult.sdkVersion;
        exec.platform = machoResult.platform;
        exec.platformName = machoResult.platformName;
        exec.hasCodeSignature = machoResult.hasCodeSignature;
        exec.hasEncryptedSlice = machoResult.hasEncryptedSlice;
        exec.encryptedSliceCount = machoResult.encryptedSliceCount;
        exec.hasEncryptedArm64Slice = machoResult.hasEncryptedArm64Slice;
        exec.encryptedArm64SliceCount = machoResult.encryptedArm64SliceCount;
        exec.parseStatus = (IPAStructuralParseStatus)machoResult.parseStatus;
        exec.parseError = machoResult.parseError;

        // Convert slices
        NSMutableArray *slices = [NSMutableArray array];
        for (MachOSlice *ms in machoResult.slices) {
            IPAStructuralExecutableSlice *slice = [[IPAStructuralExecutableSlice alloc] init];
            slice.cputype = ms.cputype;
            slice.cpusubtype = ms.cpusubtype;
            slice.offset = ms.offset;
            slice.size = ms.size;
            slice.uuid = ms.uuid;
            slice.architectureName = ms.architectureName;
            [slices addObject:slice];
        }
        exec.slices = slices;

        // Convert dependencies
        NSMutableArray *deps = [NSMutableArray array];
        for (MachODependency *md in machoResult.dependencies) {
            IPAStructuralDependency *dep = [[IPAStructuralDependency alloc] init];
            dep.rawInstallName = md.rawInstallName;
            dep.isWeak = md.isWeak;
            dep.sourceExecutablePath = md.sourceExecutablePath;
            [deps addObject:dep];
        }
        exec.dependencies = deps;

        // Convert rpaths
        NSMutableArray *rpaths = [NSMutableArray array];
        for (MachORPath *mr in machoResult.rpaths) {
            IPAStructuralRPath *rp = [[IPAStructuralRPath alloc] init];
            rp.rawPath = mr.rawPath;
            rp.sourceExecutablePath = mr.sourceExecutablePath;
            [rpaths addObject:rp];
        }
        exec.rpaths = rpaths;

        // Convert load commands
        NSMutableArray *lcs = [NSMutableArray array];
        for (MachOLoadCommand *mlc in machoResult.loadCommands) {
            IPAStructuralLoadCommand *lc = [[IPAStructuralLoadCommand alloc] init];
            lc.cmd = mlc.cmd;
            lc.cmdsize = mlc.cmdsize;
            lc.cmdDescription = mlc.cmdDescription;
            [lcs addObject:lc];
        }
        exec.loadCommands = lcs;

        [executables addObject:exec];

        // Log partial failures but don't stop
        if (machoResult.parseStatus == MachOParsePartial) {
            [result.warnings addObject:[NSString stringWithFormat:@"Partial Mach-O parse: %@ — %@",
                fullPath.lastPathComponent, machoResult.parseError ?: @"unknown"]];
        } else if (machoResult.parseStatus == MachOParseFailed) {
            [result.warnings addObject:[NSString stringWithFormat:@"Mach-O parse failed: %@ — %@",
                fullPath.lastPathComponent, machoResult.parseError ?: @"unknown"]];
        }
    }

    // 6. Build result
    result.bundles = [bundles copy];
    result.executables = [executables copy];
    result.success = (result.errors.count == 0);

    // 7. Compute counters
    result.bundleCount = bundles.count;
    result.executableCount = executables.count;

    NSInteger fwCount = 0, dylibCount = 0, appexCount = 0, xpcCount = 0, sliceCount = 0, depCount = 0, rpathCount = 0;
    for (IPAStructuralBundle *b in bundles) {
        if ([b.bundleType isEqualToString:@".framework"]) fwCount++;
        else if ([b.bundleType isEqualToString:@".appex"]) appexCount++;
        else if ([b.bundleType isEqualToString:@".xpc"]) xpcCount++;
    }
    for (IPAStructuralExecutable *e in executables) {
        if ([e.machOTypeName isEqualToString:@"MH_DYLIB"]) dylibCount++;
        sliceCount += e.slices.count;
        depCount += e.dependencies.count;
        rpathCount += e.rpaths.count;
    }
    result.frameworkCount = fwCount;
    result.dylibCount = dylibCount;
    result.appexCount = appexCount;
    result.xpcCount = xpcCount;
    result.sliceCount = sliceCount;
    result.dependencyCount = depCount;
    result.rpathCount = rpathCount;

    // 8. Cleanup
    if (!keep) {
        [self cleanupDirectory:tempDir];
        result.extractPath = nil;
    }

    result.analysisEndTime = [NSDate date];
    result.analysisDurationMs = [result.analysisEndTime timeIntervalSinceDate:result.analysisStartTime] * 1000.0;

    return result;
}

#pragma mark - Helpers

- (NSString *)createTempDirectory {
    NSString *tempDir = NSTemporaryDirectory();
    NSString *unique = [[NSUUID UUID] UUIDString];
    NSString *path = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"IPAInstallerPro_Analyze_%@", unique]];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]) {
        return path;
    }
    return nil;
}

- (void)cleanupDirectory:(NSString *)path {
    if (!path) return;
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:path error:nil];
}

- (BOOL)extractIPA:(NSString *)ipaPath toDirectory:(NSString *)destDir error:(NSString **)error {
    NSString *unzipPath = [[RootlessManager sharedManager] resolvePath:@"/usr/bin/unzip"];
    if (!unzipPath.length || ![[NSFileManager defaultManager] isExecutableFileAtPath:unzipPath]) {
        NSArray<NSString *> *fallbacks = @[@"/var/jb/usr/bin/unzip", @"/var/jb/bin/unzip", @"/usr/bin/unzip"];
        for (NSString *candidate in fallbacks) {
            if ([[NSFileManager defaultManager] isExecutableFileAtPath:candidate]) {
                unzipPath = candidate;
                break;
            }
        }
    }
    if (!unzipPath.length || ![[NSFileManager defaultManager] isExecutableFileAtPath:unzipPath]) {
        if (error) *error = @"Rootless unzip executable not found";
        return NO;
    }
    NSString *output = [self runCmdOutput:unzipPath args:@[@"-o", @"-q", ipaPath, @"-d", destDir]];

    if (output && output.length > 0 &&
        [output rangeOfString:@"error" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        if (error) *error = output;
        return NO;
    }

    NSString *payloadPath = [destDir stringByAppendingPathComponent:@"Payload"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:payloadPath]) {
        if (error) *error = @"Extraction completed but Payload directory not found";
        return NO;
    }

    return YES;
}

- (NSString *)runCmdOutput:(NSString *)cmd args:(NSArray *)args {
    NSMutableArray *cArgs = [NSMutableArray arrayWithObject:cmd ?: @""];
    [cArgs addObjectsFromArray:args ?: @[]];
    char **argv = calloc(cArgs.count + 1, sizeof(char *));
    for (NSUInteger i = 0; i < cArgs.count; i++) argv[i] = strdup([cArgs[i] fileSystemRepresentation]);
    pid_t pid = 0;
    posix_spawn_file_actions_t action;
    posix_spawn_file_actions_init(&action);
    int outPipe[2];
    if (pipe(outPipe) != 0) {
        posix_spawn_file_actions_destroy(&action);
        for (NSUInteger i = 0; i < cArgs.count; i++) free(argv[i]);
        free(argv);
        return nil;
    }
    posix_spawn_file_actions_adddup2(&action, outPipe[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&action, outPipe[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&action, outPipe[0]);
    posix_spawn_file_actions_addclose(&action, outPipe[1]);
    int spawnStatus = posix_spawn(&pid, cmd.fileSystemRepresentation, &action, NULL, argv, NULL);
    posix_spawn_file_actions_destroy(&action);
    for (NSUInteger i = 0; i < cArgs.count; i++) free(argv[i]);
    free(argv);
    close(outPipe[1]);
    if (spawnStatus != 0) {
        close(outPipe[0]);
        return nil;
    }
    int flags = fcntl(outPipe[0], F_GETFL, 0);
    if (flags >= 0) fcntl(outPipe[0], F_SETFL, flags | O_NONBLOCK);
    NSMutableData *data = [NSMutableData data];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:300.0];
    int waitStatus = 0;
    BOOL reaped = NO;
    BOOL timedOut = NO;
    char buffer[4096];
    for (;;) {
        ssize_t n;
        while ((n = read(outPipe[0], buffer, sizeof(buffer))) > 0) [data appendBytes:buffer length:(NSUInteger)n];
        pid_t waited = waitpid(pid, &waitStatus, WNOHANG);
        if (waited == pid) reaped = YES;
        else if (waited < 0 && errno != EINTR) {
            kill(pid, SIGKILL);
            while (waitpid(pid, &waitStatus, 0) < 0 && errno == EINTR) { }
            timedOut = YES;
            reaped = YES;
            break;
        }
        if (reaped) {
            while ((n = read(outPipe[0], buffer, sizeof(buffer))) > 0) [data appendBytes:buffer length:(NSUInteger)n];
            break;
        }
        if ([[NSDate date] compare:deadline] != NSOrderedAscending) {
            timedOut = YES;
            kill(pid, SIGKILL);
            while (waitpid(pid, &waitStatus, 0) < 0 && errno == EINTR) { }
            reaped = YES;
            break;
        }
        usleep(10000);
    }
    close(outPipe[0]);
    if (timedOut || !reaped || !WIFEXITED(waitStatus) || WEXITSTATUS(waitStatus) != 0) return nil;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}

- (BOOL)isMachOMagic:(uint32_t)magic {
    return (magic == MH_MAGIC || magic == MH_MAGIC_64 ||
            magic == MH_CIGAM || magic == MH_CIGAM_64 ||
            magic == FAT_MAGIC || magic == FAT_CIGAM ||
            magic == FAT_MAGIC_64 || magic == FAT_CIGAM_64);
}

- (NSString *)bundleTypeFromPath:(NSString *)path {
    NSString *lower = path.lowercaseString;
    if ([lower hasSuffix:@".app"]) return @".app";
    if ([lower hasSuffix:@".appex"]) return @".appex";
    if ([lower hasSuffix:@".xpc"]) return @".xpc";
    if ([lower hasSuffix:@".framework"]) return @".framework";
    if ([lower hasSuffix:@".bundle"]) return @".bundle";
    return nil;
}

- (NSDictionary *)readInfoPlistAtPath:(NSString *)plistPath {
    NSData *data = [NSData dataWithContentsOfFile:plistPath];
    if (!data) return nil;
    NSError *error = nil;
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data
                                                                    options:NSPropertyListImmutable
                                                                     format:nil
                                                                      error:&error];
    if (error) {
        plist = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    }
    return plist;
}

@end
