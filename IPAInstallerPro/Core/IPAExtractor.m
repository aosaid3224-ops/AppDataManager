//
//  IPAExtractor.m
//  IPAInstallerPro — Commit 2: Binary-safe metadata extraction
//
//  FIX: findAppInfoEntryInListing now prefers CFBundlePackageType == APPL
//  to avoid selecting WatchKit extensions or AppClips as the main app.
//

#import "IPAExtractor.h"
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>
#import "Logger.h"
#import "RootlessManager.h"

extern char **environ;

@implementation IPAExtractedInfo
@end

@implementation IPAExtractor

+ (instancetype)sharedExtractor {
    static IPAExtractor *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

#pragma mark - ZIP entry access

- (NSData *)runUnzipDataForIPA:(NSString *)ipaPath entry:(NSString *)entry {
    if (ipaPath.length == 0 || entry.length == 0) return nil;

    NSString *unzipPath = [[RootlessManager sharedManager] resolvePath:@"/usr/bin/unzip"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:unzipPath]) unzipPath = @"/usr/bin/unzip";
    if (![[NSFileManager defaultManager] fileExistsAtPath:unzipPath]) return nil;

    int pipefd[2];
    if (pipe(pipefd) != 0) return nil;

    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDOUT_FILENO);
    posix_spawn_file_actions_addclose(&actions, pipefd[0]);
    posix_spawn_file_actions_addclose(&actions, pipefd[1]);

    const char *path = unzipPath.UTF8String;
    char *argv[] = {
        (char *)path,
        (char *)"-p",
        (char *)ipaPath.UTF8String,
        (char *)entry.UTF8String,
        NULL
    };

    pid_t pid = 0;
    int spawnStatus = posix_spawn(&pid, path, &actions, NULL, argv, environ);
    posix_spawn_file_actions_destroy(&actions);
    close(pipefd[1]);
    if (spawnStatus != 0) {
        close(pipefd[0]);
        return nil;
    }

    NSMutableData *data = [NSMutableData data];
    uint8_t buffer[32768];
    ssize_t count = 0;
    while ((count = read(pipefd[0], buffer, sizeof(buffer))) > 0) {
        [data appendBytes:buffer length:(NSUInteger)count];
    }
    close(pipefd[0]);

    int waitStatus = 0;
    waitpid(pid, &waitStatus, 0);
    if (!WIFEXITED(waitStatus) || WEXITSTATUS(waitStatus) != 0 || data.length == 0) return nil;
    return [data copy];
}

- (NSString *)findAppInfoEntryInListing:(NSString *)listing ipaPath:(NSString *)ipaPath appRoot:(NSString **)appRootOut {
    NSString *fallbackEntry = nil;
    NSString *fallbackRoot = nil;
    NSString *bestEntry = nil;
    NSString *bestRoot = nil;
    NSArray<NSString *> *lines = [listing componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    for (NSString *rawLine in lines) {
        NSString *entry = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (entry.length == 0) continue;
        NSString *lower = entry.lowercaseString;
        if (![lower hasPrefix:@"payload/"] || ![lower hasSuffix:@"/info.plist"]) continue;

        NSArray<NSString *> *components = [entry pathComponents];
        if (components.count < 3 || ![components[1].lowercaseString hasSuffix:@".app"]) continue;
        NSString *candidateRoot = [NSString stringWithFormat:@"%@/%@", components[0], components[1]];
        if (!fallbackEntry) {
            fallbackEntry = entry;
            fallbackRoot = candidateRoot;
        }

        NSData *candidateData = [self runUnzipDataForIPA:ipaPath entry:entry];
        NSDictionary *candidateInfo = candidateData.length > 0 ? [NSPropertyListSerialization propertyListWithData:candidateData options:NSPropertyListImmutable format:NULL error:nil] : nil;
        if (![candidateInfo isKindOfClass:[NSDictionary class]]) continue;

        NSString *packageType = [candidateInfo[@"CFBundlePackageType"] isKindOfClass:[NSString class]] ? candidateInfo[@"CFBundlePackageType"] : nil;
        NSString *candidateExecutable = [candidateInfo[@"CFBundleExecutable"] isKindOfClass:[NSString class]] ? candidateInfo[@"CFBundleExecutable"] : nil;

        if (packageType && ![packageType isEqualToString:@"APPL"]) continue;
        if (candidateExecutable.length == 0) continue;

        NSString *expectedExecutable = [[candidateRoot stringByAppendingPathComponent:candidateExecutable] lowercaseString];
        BOOL executableExists = NO;
        for (NSString *candidateRawLine in lines) {
            NSString *candidateEntry = [candidateRawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([candidateEntry.lowercaseString isEqualToString:expectedExecutable]) {
                executableExists = YES;
                break;
            }
        }
        if (executableExists) {
            BOOL hasAppTraits = (candidateInfo[@"UIRequiredDeviceCapabilities"] != nil ||
                                 candidateInfo[@"CFBundleIconFiles"] != nil ||
                                 candidateInfo[@"CFBundleIcons"] != nil);
            if (hasAppTraits || !bestEntry) {
                bestEntry = entry;
                bestRoot = candidateRoot;
            }
        }
    }

    if (bestEntry) {
        if (appRootOut) *appRootOut = bestRoot;
        return bestEntry;
    }
    if (appRootOut) *appRootOut = fallbackRoot;
    return fallbackEntry;
}

- (NSString *)findExecutableEntryInListing:(NSString *)listing appRoot:(NSString *)appRoot executable:(NSString *)executable {
    if (appRoot.length == 0 || executable.length == 0) return nil;
    NSString *expected = [[appRoot stringByAppendingPathComponent:executable] stringByStandardizingPath];
    for (NSString *rawLine in [listing componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *entry = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([entry.lowercaseString isEqualToString:expected.lowercaseString]) return entry;
    }
    return nil;
}

- (NSArray<NSString *> *)iconEntriesFromListing:(NSString *)listing appRoot:(NSString *)appRoot info:(NSDictionary *)plist {
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    NSString *iconName = [plist[@"CFBundleIconName"] isKindOfClass:[NSString class]] ? plist[@"CFBundleIconName"] : nil;
    if (iconName.length > 0) [names addObject:iconName];

    NSDictionary *icons = [plist[@"CFBundleIcons"] isKindOfClass:[NSDictionary class]] ? plist[@"CFBundleIcons"] : nil;
    NSDictionary *primary = [icons[@"CFBundlePrimaryIcon"] isKindOfClass:[NSDictionary class]] ? icons[@"CFBundlePrimaryIcon"] : nil;
    NSArray *primaryFiles = [primary[@"CFBundleIconFiles"] isKindOfClass:[NSArray class]] ? primary[@"CFBundleIconFiles"] : nil;
    for (id name in primaryFiles) if ([name isKindOfClass:[NSString class]]) [names addObject:name];

    NSArray *legacyFiles = [plist[@"CFBundleIconFiles"] isKindOfClass:[NSArray class]] ? plist[@"CFBundleIconFiles"] : nil;
    for (id name in legacyFiles) if ([name isKindOfClass:[NSString class]]) [names addObject:name];
    if (names.count == 0) [names addObject:@"AppIcon60x60"];

    NSMutableArray<NSString *> *entries = [NSMutableArray array];
    NSString *prefix = [appRoot stringByAppendingString:@"/"];
    for (NSString *rawLine in [listing componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *entry = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *lower = entry.lowercaseString;
        if (![lower hasPrefix:prefix.lowercaseString]) continue;
        NSString *extension = lower.pathExtension;
        if (![@[@"png", @"jpg", @"jpeg"] containsObject:extension]) continue;

        NSString *base = [[entry.lastPathComponent stringByDeletingPathExtension] lowercaseString];
        for (NSString *desired in names) {
            NSString *desiredBase = [[desired stringByDeletingPathExtension] lowercaseString];
            if ([base isEqualToString:desiredBase] || [base hasPrefix:[desiredBase stringByAppendingString:@"@"]]) {
                [entries addObject:entry];
                break;
            }
        }
    }
    return entries;
}

#pragma mark - Metadata extraction

- (IPAExtractedInfo *)extractInfoFromIPA:(NSString *)ipaPath {
    [[Logger sharedLogger] info:[NSString stringWithFormat:@"Extracting IPA info: %@", ipaPath]];

    IPAExtractedInfo *info = [[IPAExtractedInfo alloc] init];
    info.filePath = ipaPath;

    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:ipaPath error:nil];
    info.fileSize = attrs[@"NSFileSize"] ?: @0;
    info.formattedSize = [self formatFileSize:[info.fileSize longLongValue]];

    NSString *unzipPath = [[RootlessManager sharedManager] resolvePath:@"/usr/bin/unzip"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:unzipPath]) unzipPath = @"/usr/bin/unzip";
    NSString *listingEntry = @"";

    // Read the ZIP directory once through unzip -Z1. This avoids extracting the archive.
    int pipefd[2];
    if (pipe(pipefd) != 0) return info;
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDOUT_FILENO);
    posix_spawn_file_actions_addclose(&actions, pipefd[0]);
    posix_spawn_file_actions_addclose(&actions, pipefd[1]);
    const char *unzipC = unzipPath.UTF8String;
    char *argv[] = {(char *)unzipC, (char *)"-Z1", (char *)ipaPath.UTF8String, NULL};
    pid_t pid = 0;
    int spawnStatus = posix_spawn(&pid, unzipC, &actions, NULL, argv, environ);
    posix_spawn_file_actions_destroy(&actions);
    close(pipefd[1]);
    if (spawnStatus != 0) { close(pipefd[0]); return info; }
    NSMutableData *listingDataRaw = [NSMutableData data];
    uint8_t buffer[32768];
    ssize_t count = 0;
    while ((count = read(pipefd[0], buffer, sizeof(buffer))) > 0) [listingDataRaw appendBytes:buffer length:(NSUInteger)count];
    close(pipefd[0]);
    int status = 0;
    waitpid(pid, &status, 0);
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) return info;
    NSString *listing = [[NSString alloc] initWithData:listingDataRaw encoding:NSUTF8StringEncoding];
    if (listing.length == 0) return info;

    NSString *appRoot = nil;
    listingEntry = [self findAppInfoEntryInListing:listing ipaPath:ipaPath appRoot:&appRoot];
    if (listingEntry.length == 0 || appRoot.length == 0) return info;

    NSData *plistData = [self runUnzipDataForIPA:ipaPath entry:listingEntry];
    NSDictionary *plist = plistData.length > 0 ? [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListImmutable format:NULL error:nil] : nil;
    if (![plist isKindOfClass:[NSDictionary class]]) return info;

    info.rawInfoPlist = plist;
    info.bundleID = [plist[@"CFBundleIdentifier"] isKindOfClass:[NSString class]] ? plist[@"CFBundleIdentifier"] : @"غير معروف";
    info.name = [plist[@"CFBundleName"] isKindOfClass:[NSString class]] ? plist[@"CFBundleName"] : @"غير معروف";
    info.displayName = [plist[@"CFBundleDisplayName"] isKindOfClass:[NSString class]] ? plist[@"CFBundleDisplayName"] : info.name;
    info.version = [plist[@"CFBundleShortVersionString"] isKindOfClass:[NSString class]] ? plist[@"CFBundleShortVersionString"] : @"غير معروف";
    info.buildVersion = [plist[@"CFBundleVersion"] isKindOfClass:[NSString class]] ? plist[@"CFBundleVersion"] : @"غير معروف";
    info.minOSVersion = [plist[@"MinimumOSVersion"] isKindOfClass:[NSString class]] ? plist[@"MinimumOSVersion"] : @"غير محدد";
    info.bundleExecutable = [plist[@"CFBundleExecutable"] isKindOfClass:[NSString class]] ? plist[@"CFBundleExecutable"] : @"";
    info.teamIdentifier = [plist[@"TeamIdentifier"] isKindOfClass:[NSString class]] ? plist[@"TeamIdentifier"] : @"غير موقّع";
    info.supportedDevices = [plist[@"UISupportedDevices"] isKindOfClass:[NSArray class]] ? plist[@"UISupportedDevices"] : @[];

    // Do not extract the main executable while listing files. IPAValidator performs the
    // authoritative executable check only when the user opens the install screen.
    // This keeps the list fast even for very large applications.
    info.architectures = @[];

    NSArray<NSString *> *iconEntries = [self iconEntriesFromListing:listing appRoot:appRoot info:plist];
    for (NSString *iconEntry in iconEntries) {
        NSData *iconData = [self runUnzipDataForIPA:ipaPath entry:iconEntry];
        UIImage *image = [UIImage imageWithData:iconData];
        if (image) { info.icon = image; break; }
    }

    // The old implementation exposed a temporary extracted path that was deleted before use.
    // Keep this nil so callers cannot use a stale path; validation now works from the IPA itself.
    info.appDirectoryPath = nil;
    return info;
}

- (BOOL)containsDangerousPath:(NSString *)path {
    if (!path) return YES;
    if ([path containsString:@".."] || [path containsString:@"~"] || [path hasPrefix:@"/"]) return YES;
    return NO;
}

- (UIImage *)extractIconFromAppDirectory:(NSString *)appDir infoPlist:(NSDictionary *)plist {
    if (appDir.length == 0 || plist.count == 0) return nil;
    NSArray *iconFiles = nil;
    NSDictionary *iconsDict = plist[@"CFBundleIcons"];
    NSDictionary *primaryIcon = iconsDict[@"CFBundlePrimaryIcon"];
    iconFiles = primaryIcon[@"CFBundleIconFiles"];
    if (!iconFiles) iconFiles = plist[@"CFBundleIconFiles"];
    if (!iconFiles || iconFiles.count == 0) iconFiles = @[@"AppIcon60x60"];
    for (NSString *iconName in [iconFiles reverseObjectEnumerator]) {
        for (NSString *scale in @[@"@3x", @"@2x", @""]) {
            for (NSString *ext in @[@".png", @".jpg", @".jpeg"]) {
                NSString *path = [appDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@%@", iconName, scale, ext]];
                if ([[NSFileManager defaultManager] fileExistsAtPath:path]) return [UIImage imageWithContentsOfFile:path];
            }
        }
    }
    return nil;
}

- (NSArray *)extractArchitectures:(NSString *)executablePath {
    NSMutableArray *archs = [NSMutableArray array];
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:executablePath];
    if (!fh) return archs;
    NSData *header = [fh readDataOfLength:8];
    [fh closeFile];
    if (header.length < 8) return archs;
    const unsigned char *bytes = header.bytes;
    uint32_t magic = *(uint32_t *)bytes;
    if (magic == 0xfeedfacf) {
        uint32_t cputype = *(uint32_t *)(bytes + 4);
        if (cputype == 0x0100000c) [archs addObject:@"arm64"];
        else if (cputype == 0x0200000c) [archs addObject:@"arm64e"];
    } else if (magic == 0xcafebabe || magic == 0xbebafeca) {
        [archs addObject:@"universal"];
    }
    return [archs copy];
}

- (NSString *)formatFileSize:(long long)bytes {
    if (bytes < 1024) return [NSString stringWithFormat:@"%lld بايت", bytes];
    if (bytes < 1024 * 1024) return [NSString stringWithFormat:@"%.1f كيلوبايت", bytes / 1024.0];
    if (bytes < 1024 * 1024 * 1024) return [NSString stringWithFormat:@"%.1f ميغابايت", bytes / (1024.0 * 1024.0)];
    return [NSString stringWithFormat:@"%.2f غيغابايت", bytes / (1024.0 * 1024.0 * 1024.0)];
}

@end
