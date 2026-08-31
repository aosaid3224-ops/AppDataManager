//
//  ExecutableValidator.m
//  IPAInstallerPro — Commit 2: ldid Executable Validator
//

#import "ExecutableValidator.h"
#import "ExecutableCapability.h"
#import "ProcessRunner.h"
#import "CommandResult.h"
#import "RootlessManager.h"
#import "Logger.h"

#include <unistd.h>
#include <errno.h>

@interface ExecutableValidator ()
@property (nonatomic, strong) dispatch_queue_t validationQueue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, ExecutableCapability *> *cache;
@property (nonatomic, strong) NSDate *lastCacheReset;
@end

@implementation ExecutableValidator

+ (instancetype)sharedValidator {
    static ExecutableValidator *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _validationQueue = dispatch_queue_create("com.spider.executablevalidator", DISPATCH_QUEUE_SERIAL);
        _cache = [NSMutableDictionary dictionary];
        _lastCacheReset = [NSDate date];
    }
    return self;
}

#pragma mark - Public API

- (ExecutableCapability *)validateExecutableNamed:(NSString *)name {
    if (name.length == 0) {
        ExecutableCapability *cap = [[ExecutableCapability alloc] initWithExecutableName:@"" searchedPaths:@[]];
        [cap markStatus:ExecutableCapabilityStatusUnknownError errorMessage:@"اسم الأداة فارغ"];
        return cap;
    }

    // Check cache (valid for 60 seconds)
    __block ExecutableCapability *cached = nil;
    dispatch_sync(self.validationQueue, ^{
        cached = self.cache[name];
        if (cached && [[NSDate date] timeIntervalSinceDate:cached.testTimestamp] < 60.0) {
            [[Logger sharedLogger] info:[NSString stringWithFormat:@"ExecutableValidator: using cached result for %@", name]];
        } else {
            cached = nil;
        }
    });

    if (cached) return cached;

    // Build search paths
    NSArray<NSString *> *searchPaths = [self buildSearchPathsForName:name];
    ExecutableCapability *cap = [[ExecutableCapability alloc] initWithExecutableName:name searchedPaths:searchPaths];

    // Phase 1: Discovery — find first existing and executable path
    NSString *foundPath = nil;
    BOOL foundExists = NO;
    BOOL foundExecutable = NO;

    for (NSString *dir in searchPaths) {
        NSString *candidate = [dir stringByAppendingPathComponent:name];
        int acc = access(candidate.fileSystemRepresentation, F_OK);
        if (acc == 0) {
            foundPath = candidate;
            foundExists = YES;
            int xok = access(candidate.fileSystemRepresentation, X_OK);
            foundExecutable = (xok == 0);
            [cap markFoundAtPath:candidate exists:foundExists executable:foundExecutable];

            if (foundExecutable) {
                break; // Found a candidate we can try to run
            }
        }
    }

    if (!foundPath) {
        [cap markStatus:ExecutableCapabilityStatusNotFound
           errorMessage:[NSString stringWithFormat:@"لم يُعثر على %@ في أي من المسارات المُفحصة (%lu مسار)", name, (unsigned long)searchPaths.count]];
        [self cacheResult:cap forName:name];
        [[Logger sharedLogger] error:[NSString stringWithFormat:@"ExecutableValidator: %@ NOT_FOUND in %lu paths", name, (unsigned long)searchPaths.count]];
        return cap;
    }

    if (!foundExecutable) {
        [cap markStatus:ExecutableCapabilityStatusNotExecutable
           errorMessage:[NSString stringWithFormat:@"%@ موجود في %@ لكنه غير قابل للتنفيذ", name, foundPath]];
        [self cacheResult:cap forName:name];
        [[Logger sharedLogger] error:[NSString stringWithFormat:@"ExecutableValidator: %@ NOT_EXECUTABLE at %@", name, foundPath]];
        return cap;
    }

    // Phase 2: Invocation test — actually run the binary
    ExecutableCapability *testedCap = [self runInvocationTestForExecutable:name
                                                                      atPath:foundPath
                                                            startingCapability:cap];
    [self cacheResult:testedCap forName:name];
    return testedCap;
}

- (ExecutableCapability *)validateLDID {
    ExecutableCapability *cap = [self validateExecutableNamed:@"ldid"];

    // If basic validation succeeded, do ldid-specific tests
    if (cap.status == ExecutableCapabilityStatusReady) {
        // Test 1: ldid -v (version flag)
        CommandResult *vResult = [[ProcessRunner sharedRunner] runCommand:cap.resolvedPath
                                                                arguments:@[@"-v"]
                                                                  timeout:5.0];
        if (vResult.success || ([vResult.stdoutText containsString:@"ldid"] || [vResult.stderrText containsString:@"ldid"])) {
            // ldid -v worked or produced ldid-related output
            [[Logger sharedLogger] info:[NSString stringWithFormat:@"ExecutableValidator: ldid -v test passed at %@", cap.resolvedPath]];
            return cap;
        }

        // Test 2: ldid without args (should print usage to stderr)
        CommandResult *bareResult = [[ProcessRunner sharedRunner] runCommand:cap.resolvedPath
                                                                   arguments:@[]
                                                                     timeout:5.0];
        NSString *combined = [NSString stringWithFormat:@"%@ %@", bareResult.stdoutText, bareResult.stderrText];
        if ([combined containsString:@"ldid"] || [combined containsString:@"Usage"] || [combined containsString:@"usage"]) {
            [[Logger sharedLogger] info:[NSString stringWithFormat:@"ExecutableValidator: ldid bare test passed at %@", cap.resolvedPath]];
            return cap;
        }

        // If we get here, the binary runs but doesn't behave like ldid
        [cap markStatus:ExecutableCapabilityStatusInvalidOutput
           errorMessage:@"الأداة تعمل لكنها لا تُنتج خرجًا متوقعًا (قد تكون نسخة غير متوافقة)"];
        [[Logger sharedLogger] warning:[NSString stringWithFormat:@"ExecutableValidator: ldid INVALID_OUTPUT at %@ | stdout=%@ | stderr=%@",
                                        cap.resolvedPath, bareResult.stdoutText, bareResult.stderrText]];
    }

    return cap;
}

- (ExecutableCapability *)validateUnzip {
    return [self validateExecutableNamed:@"unzip"];
}

- (ExecutableCapability *)validateUICache {
    return [self validateExecutableNamed:@"uicache"];
}

- (NSString *)findExecutableNamed:(NSString *)name {
    NSArray<NSString *> *paths = [self buildSearchPathsForName:name];
    for (NSString *dir in paths) {
        NSString *candidate = [dir stringByAppendingPathComponent:name];
        if (access(candidate.fileSystemRepresentation, F_OK) == 0) {
            return candidate;
        }
    }
    return nil;
}

- (NSArray<NSString *> *)currentSearchPaths {
    return [self buildSearchPathsForName:@""];
}

#pragma mark - Private

- (NSArray<NSString *> *)buildSearchPathsForName:(NSString *)name {
    NSMutableSet<NSString *> *paths = [NSMutableSet set];

    // 1. PATH environment variable
    const char *pathEnv = getenv("PATH");
    if (pathEnv) {
        NSString *pathStr = [NSString stringWithUTF8String:pathEnv];
        NSArray *pathComponents = [pathStr componentsSeparatedByString:@":"];
        for (NSString *p in pathComponents) {
            if (p.length > 0) [paths addObject:p];
        }
    }

    // 2. Standard Unix paths
    [paths addObject:@"/usr/bin"];
    [paths addObject:@"/bin"];
    [paths addObject:@"/usr/local/bin"];

    // 3. Rootless paths via RootlessManager
    NSString *resolvedBin = [[RootlessManager sharedManager] resolvePath:@"/usr/bin"];
    if (resolvedBin.length > 0 && ![resolvedBin isEqualToString:@"/usr/bin"]) {
        [paths addObject:resolvedBin];
    }

    // 4. Known Rootless bootstrap paths (fallback)
    [paths addObject:@"/var/jb/usr/bin"];
    [paths addObject:@"/var/jb/bin"];
    [paths addObject:@"/var/LIY/usr/bin"];
    [paths addObject:@"/var/LIY/bin"];

    // 5. Procursus and other bootstrap paths (future-proofing)
    [paths addObject:@"/opt/procursus/bin"];
    [paths addObject:@"/opt/procursus/usr/bin"];

    // 6. ElleKit / other bootstrap paths
    [paths addObject:@"/usr/local/bin"];

    // Remove duplicates and empty strings, preserve order
    NSMutableArray<NSString *> *ordered = [NSMutableArray array];
    for (NSString *p in paths) {
        if (p.length > 0 && ![ordered containsObject:p]) {
            [ordered addObject:p];
        }
    }

    return ordered;
}

- (ExecutableCapability *)runInvocationTestForExecutable:(NSString *)name
                                                    atPath:(NSString *)path
                                          startingCapability:(ExecutableCapability *)cap {
    NSDate *start = [NSDate date];

    // Try "name -v" first (version flag is common)
    CommandResult *result = [[ProcessRunner sharedRunner] runCommand:path
                                                           arguments:@[@"-v"]
                                                             timeout:5.0];
    NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:start];

    [cap markInvocationResultWithSpawnError:result.spawnError
                                   exitCode:result.exitCode
                               signalNumber:result.signalNumber
                                     output:[NSString stringWithFormat:@"%@ %@", result.stdoutText, result.stderrText]
                                   duration:duration];

    if (result.spawnError != 0) {
        // Invocation failed at spawn level
        return cap;
    }

    if (result.timedOut) {
        [cap markStatus:ExecutableCapabilityStatusTimeout
           errorMessage:@"انتهت مهلة اختبار تشغيل الأداة"];
        return cap;
    }

    // spawn succeeded — check if output is reasonable
    NSString *combined = [NSString stringWithFormat:@"%@ %@", result.stdoutText, result.stderrText];
    BOOL outputLooksValid = (combined.length > 0) || (result.exitCode == 0);

    // For most tools, -v either succeeds (exit 0) or prints version info (exit may be 0 or non-zero)
    // If -v produced no output and exit was non-zero, try without args
    if (!outputLooksValid && result.exitCode != 0) {
        NSDate *bareStart = [NSDate date];
        CommandResult *bareResult = [[ProcessRunner sharedRunner] runCommand:path
                                                                   arguments:@[]
                                                                     timeout:5.0];
        NSTimeInterval bareDuration = [[NSDate date] timeIntervalSinceDate:bareStart];
        duration += bareDuration;

        combined = [NSString stringWithFormat:@"%@ %@", bareResult.stdoutText, bareResult.stderrText];
        outputLooksValid = (combined.length > 0);

        [cap markInvocationResultWithSpawnError:bareResult.spawnError
                                       exitCode:bareResult.exitCode
                                   signalNumber:bareResult.signalNumber
                                         output:combined
                                       duration:duration];

        if (bareResult.spawnError != 0) {
            return cap;
        }
        if (bareResult.timedOut) {
            [cap markStatus:ExecutableCapabilityStatusTimeout
               errorMessage:@"انتهت مهلة الاختبار الثاني"];
            return cap;
        }
    }

    if (!outputLooksValid) {
        [cap markStatus:ExecutableCapabilityStatusInvalidOutput
           errorMessage:@"الأداة تعمل لكنها لا تُنتج أي خرج متوقع"];
        [[Logger sharedLogger] warning:[NSString stringWithFormat:@"ExecutableValidator: %@ INVALID_OUTPUT at %@", name, path]];
        return cap;
    }

    // All checks passed
    [cap markReadyWithPath:path output:combined duration:duration];
    [[Logger sharedLogger] info:[NSString stringWithFormat:@"ExecutableValidator: %@ READY at %@ (%.3fs)", name, path, duration]];
    return cap;
}

- (void)cacheResult:(ExecutableCapability *)cap forName:(NSString *)name {
    dispatch_async(self.validationQueue, ^{
        self.cache[name] = cap;
    });
}

- (void)invalidateCache {
    dispatch_async(self.validationQueue, ^{
        [self.cache removeAllObjects];
        self.lastCacheReset = [NSDate date];
    });
}

@end
