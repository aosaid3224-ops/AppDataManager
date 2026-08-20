//
//  IPAValidator.m
//  IPAInstallerPro
//

#import "IPAValidator.h"
#import "RootlessManager.h"
#import <Foundation/Foundation.h>
#import <spawn.h>
#import <sys/wait.h>
#import <unistd.h>
#import <fcntl.h>

extern char **environ;

@interface IPAValidator ()
@property (nonatomic, strong) NSString *ldidPath;
@property (nonatomic, strong) NSString *otoolPath;
@property (nonatomic, strong) NSString *lipoPath;
@property (nonatomic, strong) NSString *unzipPath;
@property (nonatomic, strong) NSString *devNullPath;
@end

@implementation IPAValidationResult
@end

@implementation IPAValidator

+ (instancetype)sharedValidator {
    static IPAValidator *s = nil;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [[self alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        RootlessManager *rm = [RootlessManager sharedManager];
        self.ldidPath  = [rm resolvePath:@"/usr/bin/ldid"];
        self.otoolPath = [rm resolvePath:@"/usr/bin/otool"];
        self.lipoPath  = [rm resolvePath:@"/usr/bin/lipo"];
        self.unzipPath = [rm resolvePath:@"/usr/bin/unzip"];
        self.devNullPath = [rm resolvePath:@"/dev/null"];
    }
    return self;
}

#pragma mark - Direct posix_spawn (NO /bin/sh wrapper)

- (BOOL)runCmd:(NSString *)cmd args:(NSArray<NSString *> *)args {
    return [self runCmd:cmd args:args stdin:nil stdout:nil stderrToDevNull:YES];
}

- (BOOL)runCmd:(NSString *)cmd args:(NSArray<NSString *> *)args stderrToDevNull:(BOOL)errNull {
    return [self runCmd:cmd args:args stdin:nil stdout:nil stderrToDevNull:errNull];
}

- (BOOL)runCmd:(NSString *)cmd args:(NSArray<NSString *> *)args stdin:(NSString *)inPath stdout:(NSString *)outPath stderrToDevNull:(BOOL)errNull {
    if (!cmd || cmd.length == 0) return NO;

    pid_t pid;
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);

    // Redirect stderr to /dev/null if requested
    if (errNull && self.devNullPath) {
        int fd = open([self.devNullPath UTF8String], O_WRONLY);
        if (fd >= 0) {
            posix_spawn_file_actions_adddup2(&actions, fd, STDERR_FILENO);
            posix_spawn_file_actions_addclose(&actions, fd);
        }
    }

    // Redirect stdout to file if requested
    if (outPath) {
        int fd = open([outPath UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd >= 0) {
            posix_spawn_file_actions_adddup2(&actions, fd, STDOUT_FILENO);
            posix_spawn_file_actions_addclose(&actions, fd);
        }
    }

    // Redirect stdin from file if requested
    if (inPath) {
        int fd = open([inPath UTF8String], O_RDONLY);
        if (fd >= 0) {
            posix_spawn_file_actions_adddup2(&actions, fd, STDIN_FILENO);
            posix_spawn_file_actions_addclose(&actions, fd);
        }
    }

    // Build argv
    const char *path = [cmd UTF8String];
    int argc = (int)args.count + 2;
    char **argv = malloc(argc * sizeof(char *));
    argv[0] = (char *)path;
    for (NSUInteger i = 0; i < args.count; i++) {
        argv[i + 1] = (char *)[args[i] UTF8String];
    }
    argv[args.count + 1] = NULL;

    int st = posix_spawn(&pid, path, &actions, NULL, argv, environ);
    free(argv);
    posix_spawn_file_actions_destroy(&actions);

    if (st != 0) return NO;

    int ws;
    waitpid(pid, &ws, 0);
    return (WIFEXITED(ws) && WEXITSTATUS(ws) == 0);
}

- (NSString *)runCmdOutput:(NSString *)cmd args:(NSArray<NSString *> *)args {
    if (!cmd || cmd.length == 0) return nil;

    int pipefd[2];
    if (pipe(pipefd) != 0) return nil;

    pid_t pid;
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDOUT_FILENO);
    posix_spawn_file_actions_addclose(&actions, pipefd[0]);
    posix_spawn_file_actions_addclose(&actions, pipefd[1]);

    // Redirect stderr to /dev/null
    if (self.devNullPath) {
        int fd = open([self.devNullPath UTF8String], O_WRONLY);
        if (fd >= 0) {
            posix_spawn_file_actions_adddup2(&actions, fd, STDERR_FILENO);
            posix_spawn_file_actions_addclose(&actions, fd);
        }
    }

    const char *path = [cmd UTF8String];
    int argc = (int)args.count + 2;
    char **argv = malloc(argc * sizeof(char *));
    argv[0] = (char *)path;
    for (NSUInteger i = 0; i < args.count; i++) {
        argv[i + 1] = (char *)[args[i] UTF8String];
    }
    argv[args.count + 1] = NULL;

    int st = posix_spawn(&pid, path, &actions, NULL, argv, environ);
    free(argv);
    posix_spawn_file_actions_destroy(&actions);
    close(pipefd[1]);

    if (st != 0) {
        close(pipefd[0]);
        return nil;
    }

    NSMutableString *output = [NSMutableString string];
    char buf[4096];
    ssize_t n;
    while ((n = read(pipefd[0], buf, sizeof(buf) - 1)) > 0) {
        buf[n] = '\0';
        [output appendString:[NSString stringWithUTF8String:buf]];
    }
    close(pipefd[0]);
    waitpid(pid, NULL, 0);
    return output;
}

#pragma mark - Main Validation

- (IPAValidationResult *)validateIPAAtPath:(NSString *)ipaPath {
    NSMutableArray *errors = [NSMutableArray array];
    NSMutableArray *warnings = [NSMutableArray array];
    NSMutableArray *missing = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm fileExistsAtPath:ipaPath]) {
        [errors addObject:@"IPA not found"];
        return [self result:IPAValidationStatusInvalidZip errors:errors warnings:warnings missing:missing ready:NO];
    }
    if (![fm isReadableFileAtPath:ipaPath]) {
        [errors addObject:@"IPA not readable"];
        return [self result:IPAValidationStatusInvalidZip errors:errors warnings:warnings missing:missing ready:NO];
    }

    // Check ZIP magic number
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:ipaPath];
    if (!fh) {
        [errors addObject:@"Cannot open IPA"];
        return [self result:IPAValidationStatusInvalidZip errors:errors warnings:warnings missing:missing ready:NO];
    }
    NSData *header = [fh readDataOfLength:4];
    [fh closeFile];
    if (header.length < 4) {
        [errors addObject:@"IPA empty/corrupt"];
        return [self result:IPAValidationStatusInvalidZip errors:errors warnings:warnings missing:missing ready:NO];
    }
    const unsigned char *b = (const unsigned char *)header.bytes;
    if (b[0] != 0x50 || b[1] != 0x4B || b[2] != 0x03 || b[3] != 0x04) {
        [errors addObject:@"Not a valid ZIP"];
        return [self result:IPAValidationStatusInvalidZip errors:errors warnings:warnings missing:missing ready:NO];
    }

    // Read the ZIP directory only. Do not unpack a large IPA during preflight.
    NSString *listing = [self runCmdOutput:self.unzipPath args:@[@"-Z1", ipaPath]];
    if (listing.length == 0) {
        [errors addObject:@"Unable to read IPA directory"];
        return [self result:IPAValidationStatusInvalidZip errors:errors warnings:warnings missing:missing ready:NO];
    }

    NSString *infoEntry = nil;
    NSString *appRootEntry = nil;
    NSString *fallbackInfoEntry = nil;
    NSString *fallbackAppRootEntry = nil;
    NSString *probeDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [fm createDirectoryAtPath:probeDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSArray<NSString *> *listingLines = [listing componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSUInteger probeIndex = 0;

    for (NSString *rawLine in listingLines) {
        NSString *entry = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *lowerEntry = entry.lowercaseString;
        if (![lowerEntry hasPrefix:@"payload/"] || ![lowerEntry hasSuffix:@"/info.plist"]) continue;
        NSArray<NSString *> *components = [entry pathComponents];
        if (components.count < 3 || ![components[1].lowercaseString hasSuffix:@".app"]) continue;

        NSString *candidateRoot = [NSString stringWithFormat:@"%@/%@", components[0], components[1]];
        if (!fallbackInfoEntry) {
            fallbackInfoEntry = entry;
            fallbackAppRootEntry = candidateRoot;
        }

        NSString *probePath = [probeDir stringByAppendingPathComponent:[NSString stringWithFormat:@"candidate-%lu.plist", (unsigned long)probeIndex++]];
        BOOL probeExtracted = [self runCmd:self.unzipPath args:@[@"-p", ipaPath, entry] stdin:nil stdout:probePath stderrToDevNull:YES];
        NSDictionary *candidateInfo = probeExtracted ? [NSDictionary dictionaryWithContentsOfFile:probePath] : nil;
        [fm removeItemAtPath:probePath error:nil];
        NSString *candidateExecutable = [candidateInfo[@"CFBundleExecutable"] isKindOfClass:[NSString class]] ? candidateInfo[@"CFBundleExecutable"] : nil;
        if (candidateExecutable.length == 0) continue;

        NSString *expectedExecutable = [[candidateRoot stringByAppendingPathComponent:candidateExecutable] lowercaseString];
        BOOL executableEntryExists = NO;
        for (NSString *candidateRawLine in listingLines) {
            NSString *candidateEntry = [candidateRawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([candidateEntry.lowercaseString isEqualToString:expectedExecutable]) {
                executableEntryExists = YES;
                break;
            }
        }
        if (executableEntryExists) {
            infoEntry = entry;
            appRootEntry = candidateRoot;
            break;
        }
    }
    [fm removeItemAtPath:probeDir error:nil];
    if (!infoEntry) {
        infoEntry = fallbackInfoEntry;
        appRootEntry = fallbackAppRootEntry;
    }

    if (!infoEntry || !appRootEntry) {
        [errors addObject:@"No .app Info.plist in Payload"];
        return [self result:IPAValidationStatusMissingAppBundle errors:errors warnings:warnings missing:missing ready:NO];
    }

    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSString *appPath = [tmp stringByAppendingPathComponent:[appRootEntry lastPathComponent]];
    [fm createDirectoryAtPath:appPath withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
    BOOL infoExtracted = [self runCmd:self.unzipPath
                                 args:@[@"-p", ipaPath, infoEntry]
                               stdin:nil
                              stdout:infoPath
                   stderrToDevNull:YES];
    if (!infoExtracted || ![fm fileExistsAtPath:infoPath]) {
        [errors addObject:@"Info.plist extraction failed"];
        [fm removeItemAtPath:tmp error:nil];
        return [self result:IPAValidationStatusMissingInfoPlist errors:errors warnings:warnings missing:missing ready:NO];
    }

    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    NSString *executable = [info[@"CFBundleExecutable"] isKindOfClass:[NSString class]] ? info[@"CFBundleExecutable"] : nil;
    NSString *executableEntry = nil;
    if (executable.length > 0) {
        NSString *expectedEntry = [appRootEntry stringByAppendingPathComponent:executable];
        for (NSString *rawLine in [listing componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
            NSString *entry = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([entry.lowercaseString isEqualToString:expectedEntry.lowercaseString]) {
                executableEntry = entry;
                break;
            }
        }
    }

    if (executableEntry.length == 0) {
        [errors addObject:[NSString stringWithFormat:@"Executable %@ is not present in IPA directory", executable ?: @"(unknown)"]];
        [fm removeItemAtPath:tmp error:nil];
        return [self result:IPAValidationStatusMissingExecutable errors:errors warnings:warnings missing:missing ready:NO];
    }

    NSString *executablePath = [appPath stringByAppendingPathComponent:executable];
    BOOL executableExtracted = [self runCmd:self.unzipPath
                                      args:@[@"-p", ipaPath, executableEntry]
                                    stdin:nil
                                   stdout:executablePath
                        stderrToDevNull:YES];
    NSDictionary *executableAttrs = [fm attributesOfItemAtPath:executablePath error:nil];
    unsigned long long executableSize = [executableAttrs[@"NSFileSize"] unsignedLongLongValue];
    if (!executableExtracted || executableSize == 0) {
        [errors addObject:[NSString stringWithFormat:@"Executable %@ extraction failed", executable]];
        [fm removeItemAtPath:tmp error:nil];
        return [self result:IPAValidationStatusMissingExecutable errors:errors warnings:warnings missing:missing ready:NO];
    }

    IPAValidationResult *res = [self validateExtractedAppAtPath:appPath];
    [fm removeItemAtPath:tmp error:nil];
    return res;
}

- (IPAValidationResult *)validateExtractedAppAtPath:(NSString *)appPath {
    NSMutableArray *errors = [NSMutableArray array];      // CRITICAL: blocks install
    NSMutableArray *warnings = [NSMutableArray array];    // NON-CRITICAL: does NOT block install
    NSMutableArray *missing = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
    if (![fm fileExistsAtPath:infoPath]) {
        [errors addObject:@"Info.plist missing"];
        return [self result:IPAValidationStatusMissingInfoPlist errors:errors warnings:warnings missing:missing ready:NO];
    }
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    if (!info) {
        [errors addObject:@"Info.plist corrupt"];
        return [self result:IPAValidationStatusMissingInfoPlist errors:errors warnings:warnings missing:missing ready:NO];
    }

    NSString *bundleID = info[@"CFBundleIdentifier"];
    NSString *exeName = info[@"CFBundleExecutable"];
    id minOS = info[@"MinimumOSVersion"];
    NSArray *supportedDevices = info[@"UISupportedDevices"];

    if (!bundleID || bundleID.length == 0) {
        [errors addObject:@"BundleID missing"];
        return [self result:IPAValidationStatusInvalidBundleID errors:errors warnings:warnings missing:missing ready:NO];
    }
    if (!exeName || exeName.length == 0) {
        [errors addObject:@"Executable missing"];
        return [self result:IPAValidationStatusMissingExecutable errors:errors warnings:warnings missing:missing ready:NO];
    }

    NSString *exePath = [appPath stringByAppendingPathComponent:exeName];
    if (![fm fileExistsAtPath:exePath]) {
        [errors addObject:[NSString stringWithFormat:@"Executable %@ missing", exeName]];
        return [self result:IPAValidationStatusMissingExecutable errors:errors warnings:warnings missing:missing ready:NO];
    }
    if (![fm isReadableFileAtPath:exePath]) {
        [errors addObject:[NSString stringWithFormat:@"Executable %@ not readable", exeName]];
    }

    NSArray *archs = [self archsFor:exePath];
    if (archs.count == 0) [warnings addObject:@"Cannot determine architecture"];
    else {
        BOOL hasArm64 = NO;
        for (NSString *a in archs) if ([a containsString:@"arm64"]) hasArm64 = YES;
        if (!hasArm64) [warnings addObject:@"No arm64 support - may not work on modern devices"];
    }

    if (minOS) {
        NSString *mos = [minOS isKindOfClass:[NSString class]] ? (NSString*)minOS : [minOS stringValue];
        NSInteger maj = [[[mos componentsSeparatedByString:@"."] firstObject] integerValue];
        if (maj > 15) [warnings addObject:[NSString stringWithFormat:@"Requires iOS %@+", mos]];
    }

    if ([fm fileExistsAtPath:self.ldidPath]) {
        if (![self isSigned:exePath]) [warnings addObject:@"Not signed - will re-sign during install"];
    }

    if ([fm fileExistsAtPath:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"]]) {
        [warnings addObject:@"Has Apple provisioning - will remove and re-sign"];
    }

    if (supportedDevices && supportedDevices.count > 0) [warnings addObject:@"Device restrictions present"];

    if ([fm fileExistsAtPath:self.ldidPath]) {
        NSDictionary *ents = [self extractEnts:exePath];
        if (ents && ents[@"com.apple.private.security.container-required"] && [ents[@"com.apple.private.security.container-required"] boolValue]) {
            [warnings addObject:@"Requires special security container - may need adjustment"];
        }
    }

    NSString *fwPath = [appPath stringByAppendingPathComponent:@"Frameworks"];
    if ([fm fileExistsAtPath:fwPath]) {
        for (NSString *item in [fm contentsOfDirectoryAtPath:fwPath error:nil]) {
            NSString *ip = [fwPath stringByAppendingPathComponent:item];
            BOOL isDir = NO;
            [fm fileExistsAtPath:ip isDirectory:&isDir];
            if ([item hasSuffix:@".dylib"] || [item hasSuffix:@".so"]) {
                if (![fm isReadableFileAtPath:ip]) [errors addObject:[NSString stringWithFormat:@"Frameworks/%@ unreadable", item]];
                else if ([fm fileExistsAtPath:self.ldidPath] && ![self isSigned:ip]) [warnings addObject:[NSString stringWithFormat:@"Frameworks/%@ unsigned - will sign during install", item]];
            } else if (isDir && [item hasSuffix:@".framework"]) {
                NSString *fn = [item stringByDeletingPathExtension];
                NSString *fep = [ip stringByAppendingPathComponent:fn];
                if ([fm fileExistsAtPath:fep] && ![fm isReadableFileAtPath:fep]) [errors addObject:[NSString stringWithFormat:@"Frameworks/%@/%@ unreadable", item, fn]];
            }
        }
    }

    NSArray *deps = [self checkDependenciesAtAppPath:appPath];
    for (NSString *dep in deps) {
        if (![dep hasPrefix:@"@rpath/"] && ![dep hasPrefix:@"@executable_path/"] && ![dep hasPrefix:@"/usr/lib/"] && ![dep hasPrefix:@"/System/Library/"]) {
            [warnings addObject:[NSString stringWithFormat:@"External dependency: %@ - may not be available", dep]];
        }
    }

    if ([fm fileExistsAtPath:[appPath stringByAppendingPathComponent:@"PlugIns"]]) [warnings addObject:@"Has PlugIns - may need extra signing"];

    // CRITICAL: ready = YES if no errors, even if warnings exist
    BOOL ready = (errors.count == 0);

    // Merge warnings into errors for UI display (backward compatibility)
    NSMutableArray *allIssues = [NSMutableArray arrayWithArray:errors];
    [allIssues addObjectsFromArray:warnings];

    IPAValidationStatus status = ready ? IPAValidationStatusValid : IPAValidationStatusIncompatibleArchitecture;
    return [self result:status errors:errors warnings:warnings missing:missing ready:ready];
}

- (IPAValidationResult *)result:(IPAValidationStatus)status errors:(NSArray *)errors warnings:(NSArray *)warnings missing:(NSArray *)missing ready:(BOOL)ready {
    IPAValidationResult *r = [[IPAValidationResult alloc] init];
    r.status = status;
    r.issues = errors;  // Only errors, not warnings
    r.missingLibraries = missing;
    r.isReadyForInstall = ready;
    if (status == IPAValidationStatusValid) r.statusMessage = @"Valid for install";
    else if (status == IPAValidationStatusInvalidZip) r.statusMessage = @"Invalid ZIP";
    else if (status == IPAValidationStatusMissingPayload) r.statusMessage = @"Payload missing";
    else if (status == IPAValidationStatusMissingAppBundle) r.statusMessage = @".app missing";
    else if (status == IPAValidationStatusMissingInfoPlist) r.statusMessage = @"Info.plist missing";
    else if (status == IPAValidationStatusMissingExecutable) r.statusMessage = @"Executable missing";
    else if (status == IPAValidationStatusInvalidBundleID) r.statusMessage = @"Invalid BundleID";
    else r.statusMessage = @"Has errors - cannot install";
    return r;
}

- (NSArray *)archsFor:(NSString *)path {
    NSMutableArray *a = [NSMutableArray array];
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.lipoPath]) return a;
    NSString *output = [self runCmdOutput:self.lipoPath args:@[@"-info", path]];
    if (!output) return a;
    if ([output containsString:@"arm64e"]) [a addObject:@"arm64e"];
    if ([output containsString:@"arm64"] && ![output containsString:@"arm64e"]) [a addObject:@"arm64"];
    if ([output containsString:@"armv7s"]) [a addObject:@"armv7s"];
    if ([output containsString:@"armv7"]) [a addObject:@"armv7"];
    return a;
}

- (BOOL)isSigned:(NSString *)path {
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.ldidPath]) return YES;
    return [self runCmd:self.ldidPath args:@[@"-e", path] stdin:nil stdout:nil stderrToDevNull:YES];
}

- (NSDictionary *)extractEnts:(NSString *)path {
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.ldidPath]) return nil;
    NSString *tp = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ents.plist"];
    if ([self runCmd:self.ldidPath args:@[@"-e", path] stdin:nil stdout:tp stderrToDevNull:YES]) {
        NSData *d = [NSData dataWithContentsOfFile:tp];
        [[NSFileManager defaultManager] removeItemAtPath:tp error:nil];
        if (d.length > 10) {
            id obj = [NSPropertyListSerialization propertyListWithData:d options:0 format:NULL error:nil];
            if ([obj isKindOfClass:[NSDictionary class]]) return obj;
        }
    }
    return nil;
}

- (NSArray *)checkDependenciesAtAppPath:(NSString *)appPath {
    NSMutableArray *d = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    NSString *en = info[@"CFBundleExecutable"];
    if (!en) return d;
    NSString *ep = [appPath stringByAppendingPathComponent:en];
    if (![fm fileExistsAtPath:ep] || ![fm fileExistsAtPath:self.otoolPath]) return d;

    NSString *output = [self runCmdOutput:self.otoolPath args:@[@"-L", ep]];
    if (!output) return d;

    NSArray *lines = [output componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSString *t = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([t hasPrefix:@"\t"]) {
            NSRange r = [t rangeOfString:@" ("];
            if (r.location != NSNotFound) [d addObject:[t substringWithRange:NSMakeRange(1, r.location - 1)]];
        }
    }
    return d;
}

@end
