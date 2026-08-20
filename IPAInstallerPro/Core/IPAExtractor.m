#import "IPAExtractor.h"
#include <spawn.h>
#include <sys/wait.h>
#import "Logger.h"
#import "RootlessManager.h"

@implementation IPAExtractedInfo
@end

@implementation IPAExtractor

+ (instancetype)sharedExtractor {
    static IPAExtractor *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (IPAExtractedInfo *)extractInfoFromIPA:(NSString *)ipaPath {
    [[Logger sharedLogger] info:[NSString stringWithFormat:@"Extracting IPA info: %@", ipaPath]];

    IPAExtractedInfo *info = [[IPAExtractedInfo alloc] init];
    info.filePath = ipaPath;

    // File size
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:ipaPath error:nil];
    info.fileSize = attrs[@"NSFileSize"] ?: @0;
    info.formattedSize = [self formatFileSize:[info.fileSize longLongValue]];

    // Create temp dir
    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:nil];

    // Unzip selective
    NSString *unzipPathStr = [[RootlessManager sharedManager] resolvePath:@"/usr/bin/unzip"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:unzipPathStr]) {
        unzipPathStr = @"/usr/bin/unzip";
    }
    const char *unzipPath = [unzipPathStr UTF8String];
    const char *selArgs[] = { unzipPath, "-q", "-o", "-j", [ipaPath UTF8String], "Payload/*/Info.plist", "-d", [tempDir UTF8String], NULL };
    pid_t selPid;
    int selStatus;
    posix_spawn(&selPid, unzipPath, NULL, NULL, (char **)selArgs, NULL);
    waitpid(selPid, &selStatus, 0);

    // Alternative: extract full payload
    NSString *payloadDir = [tempDir stringByAppendingPathComponent:@"Payload"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:payloadDir]) {
        const char *fullArgs[] = { unzipPath, "-q", "-o", [ipaPath UTF8String], "-d", [tempDir UTF8String], NULL };
        pid_t fullPid;
        int fullStatus;
        posix_spawn(&fullPid, unzipPath, NULL, NULL, (char **)fullArgs, NULL);
        waitpid(fullPid, &fullStatus, 0);
    }

    payloadDir = [tempDir stringByAppendingPathComponent:@"Payload"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:payloadDir]) {
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadDir error:nil];
        for (NSString *item in contents) {
            if ([item.pathExtension.lowercaseString isEqualToString:@"app"]) {
                // SECURITY: Reject paths with traversal
                if ([self containsDangerousPath:item]) {
                    [[Logger sharedLogger] error:[NSString stringWithFormat:@"Dangerous path in IPA: %@", item]];
                    info.bundleID = @"INVALID_PATH";
                    break;
                }
                NSString *appDir = [payloadDir stringByAppendingPathComponent:item];
                info.appDirectoryPath = appDir;
                NSString *plistPath = [appDir stringByAppendingPathComponent:@"Info.plist"];
                NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:plistPath];
                if (plist) {
                    info.rawInfoPlist = plist;
                    info.bundleID = plist[@"CFBundleIdentifier"] ?: @"غير معروف";
                    info.name = plist[@"CFBundleName"] ?: @"غير معروف";
                    info.displayName = plist[@"CFBundleDisplayName"] ?: info.name;
                    info.version = plist[@"CFBundleShortVersionString"] ?: @"غير معروف";
                    info.buildVersion = plist[@"CFBundleVersion"] ?: @"غير معروف";
                    info.minOSVersion = plist[@"MinimumOSVersion"] ?: @"غير محدد";
                    info.bundleExecutable = plist[@"CFBundleExecutable"] ?: @"";
                    info.teamIdentifier = plist[@"TeamIdentifier"] ?: @"غير موقّع";
                    info.supportedDevices = plist[@"UISupportedDevices"] ?: @[];

                    // Extract architectures from executable
                    if (info.bundleExecutable.length > 0) {
                        info.architectures = [self extractArchitectures:[appDir stringByAppendingPathComponent:info.bundleExecutable]];
                    }

                    // Extract icon
                    info.icon = [self extractIconFromAppDirectory:appDir infoPlist:plist];
                }
                break;
            }
        }
    }

    // Cleanup
    [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];
    return info;
}

- (BOOL)containsDangerousPath:(NSString *)path {
    if (!path) return YES;
    if ([path containsString:@".."]) return YES;
    if ([path containsString:@"~"]) return YES;
    if ([path hasPrefix:@"/"]) return YES;
    return NO;
}

- (UIImage *)extractIconFromAppDirectory:(NSString *)appDir infoPlist:(NSDictionary *)plist {
    NSArray *iconFiles = nil;

    NSDictionary *iconsDict = plist[@"CFBundleIcons"];
    if (iconsDict) {
        NSDictionary *primaryIcon = iconsDict[@"CFBundlePrimaryIcon"];
        if (primaryIcon) {
            iconFiles = primaryIcon[@"CFBundleIconFiles"];
        }
    }

    if (!iconFiles) {
        iconFiles = plist[@"CFBundleIconFiles"];
    }

    if (!iconFiles || iconFiles.count == 0) {
        iconFiles = @[@"AppIcon60x60"];
    }

    NSArray *scales = @[@"@3x", @"@2x", @""];
    NSArray *extensions = @[@".png", @".jpg", @".jpeg"];

    for (NSString *iconName in [iconFiles reverseObjectEnumerator]) {
        for (NSString *scale in scales) {
            for (NSString *ext in extensions) {
                NSString *path = [appDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@%@", iconName, scale, ext]];
                if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                    return [UIImage imageWithContentsOfFile:path];
                }
            }
        }
    }

    // Try Assets.car (simplified - just check existence)
    NSString *assetsPath = [appDir stringByAppendingPathComponent:@"Assets.car"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:assetsPath]) {
        [[Logger sharedLogger] debug:@"Assets.car found but parsing not implemented"];
    }

    return nil;
}

- (NSArray *)extractArchitectures:(NSString *)executablePath {
    NSMutableArray *archs = [NSMutableArray array];
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:executablePath];
    if (!fh) return archs;

    NSData *header = [fh readDataOfLength:8];
    [fh closeFile];
    if (header.length < 4) return archs;

    const unsigned char *bytes = (const unsigned char *)header.bytes;
    uint32_t magic = *(uint32_t *)bytes;

    if (magic == 0xfeedfacf) { // MH_MAGIC_64
        uint32_t cputype = *(uint32_t *)(bytes + 4);
        if (cputype == 0x0100000c) { // CPU_TYPE_ARM64
            [archs addObject:@"arm64"];
        } else if (cputype == 0x0200000c) { // CPU_TYPE_ARM64_64 (arm64e)
            [archs addObject:@"arm64e"];
        }
    } else if (magic == 0xcafebabe || magic == 0xbebafeca) { // FAT binary
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
