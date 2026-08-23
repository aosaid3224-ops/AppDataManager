#import "AppDataManager.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/statvfs.h>
#import "rootless.h"

@interface AppDataManager ()
@property (nonatomic, strong) NSCache *sizeCache;
@property (nonatomic, strong) NSCache *iconCache;
@property (nonatomic, strong) NSArray *cachedApps;
@end

@implementation AppDataManager

+ (instancetype)sharedManager {
    static AppDataManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sizeCache = [[NSCache alloc] init];
        _sizeCache.countLimit = 500;
        _iconCache = [[NSCache alloc] init];
        _iconCache.countLimit = 200;
    }
    return self;
}

#pragma mark - Fast App Listing

- (NSArray *)allInstalledApplications {
    if (self.cachedApps) return self.cachedApps;

    Class LSApplicationWorkspace_class = objc_getClass("LSApplicationWorkspace");
    if (!LSApplicationWorkspace_class) return @[];

    id workspace = [LSApplicationWorkspace_class performSelector:@selector(defaultWorkspace)];
    if (!workspace) return @[];

    NSArray *apps = nil;
    @try {
        apps = [workspace performSelector:@selector(allInstalledApplications)];
    } @catch (NSException *e) { return @[]; }

    if (!apps || apps.count == 0) return @[];

    NSMutableArray *appList = [NSMutableArray array];
    for (id app in apps) {
        @try {
            NSString *bundleID = nil;
            NSString *name = nil;

            if ([app respondsToSelector:@selector(bundleIdentifier)]) {
                bundleID = [app performSelector:@selector(bundleIdentifier)];
            }
            if ([app respondsToSelector:@selector(localizedName)]) {
                name = [app performSelector:@selector(localizedName)];
            }

            if (!bundleID || !name) continue;

            NSString *appType = @"User";
            if ([app respondsToSelector:@selector(applicationType)]) {
                appType = [app performSelector:@selector(applicationType)] ?: @"User";
            }

            NSString *sizeStr = @"Calculating...";
            NSNumber *cachedSize = [self.sizeCache objectForKey:bundleID];
            if (cachedSize) {
                sizeStr = [self formatBytes:[cachedSize unsignedLongLongValue]];
            }

            [appList addObject:@{
                @"name": name,
                @"bundleID": bundleID,
                @"type": appType,
                @"size": cachedSize ?: @(0),
                @"sizeString": sizeStr,
                @"hasBackup": @([self availableBackupsForBundleID:bundleID].count > 0),
                @"isSystemApp": @([self isSystemApp:bundleID])
            }];
        } @catch (NSException *e) { continue; }
    }

    NSArray *sorted = [appList sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] compare:b[@"name"]];
    }];

    self.cachedApps = sorted;
    return sorted;
}

#pragma mark - Data Paths (Comprehensive)

- (NSString *)dataPathForBundleID:(NSString *)bundleID {
    if (!bundleID) return nil;

    @try {
        void *handle = dlopen("/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager", RTLD_LAZY);
        if (handle) {
            Class MCMAppDataContainer = NSClassFromString(@"MCMAppDataContainer");
            if (MCMAppDataContainer && [MCMAppDataContainer respondsToSelector:@selector(containerWithIdentifier:error:)]) {
                NSError *error = nil;
                id container = [MCMAppDataContainer performSelector:@selector(containerWithIdentifier:error:)
                                                        withObject:bundleID
                                                        withObject:error];
                if (container && [container respondsToSelector:@selector(path)]) {
                    NSString *path = [container performSelector:@selector(path)];
                    if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
                        return path;
                    }
                }
            }
        }
    } @catch (NSException *e) {}

    @try {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *dataRoot = @"/var/mobile/Containers/Data/Application";
        NSArray *folders = [fm contentsOfDirectoryAtPath:dataRoot error:nil];

        for (NSString *folder in folders) {
            NSString *plistPath = [dataRoot stringByAppendingPathComponent:
                [folder stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
            if ([fm fileExistsAtPath:plistPath]) {
                NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:plistPath];
                if ([plist[@"MCMMetadataIdentifier"] isEqualToString:bundleID]) {
                    return [dataRoot stringByAppendingPathComponent:folder];
                }
            }
        }
    } @catch (NSException *e) {}

    return nil;
}

- (NSArray *)groupContainerPathsForBundleID:(NSString *)bundleID {
    if (!bundleID) return @[];

    NSMutableArray *paths = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];

    @try {
        Class LSApplicationProxy_class = objc_getClass("LSApplicationProxy");
        if (LSApplicationProxy_class && [LSApplicationProxy_class respondsToSelector:@selector(applicationProxyForIdentifier:)]) {
            id proxy = [LSApplicationProxy_class performSelector:@selector(applicationProxyForIdentifier:) withObject:bundleID];
            if (proxy && [proxy respondsToSelector:@selector(groupContainerURLs)]) {
                NSDictionary *groupURLs = [proxy performSelector:@selector(groupContainerURLs)];
                for (NSString *groupID in groupURLs) {
                    NSURL *url = groupURLs[groupID];
                    NSString *path = [url path];
                    if (path && [fm fileExistsAtPath:path]) {
                        [paths addObject:path];
                    }
                }
            }
            if (proxy && [proxy respondsToSelector:@selector(entitlements)]) {
                NSDictionary *entitlements = [proxy performSelector:@selector(entitlements)];
                NSArray *groupIDs = entitlements[@"com.apple.security.application-groups"];
                if (groupIDs) {
                    for (NSString *groupID in groupIDs) {
                        NSString *groupPath = [self pathForGroupIdentifier:groupID];
                        if (groupPath && ![paths containsObject:groupPath]) {
                            [paths addObject:groupPath];
                        }
                    }
                }
            }
        }
    } @catch (NSException *e) {}

    NSString *groupRoot = @"/var/mobile/Containers/Shared/AppGroup";
    if ([fm fileExistsAtPath:groupRoot]) {
        NSArray *folders = [fm contentsOfDirectoryAtPath:groupRoot error:nil];
        for (NSString *folder in folders) {
            NSString *plistPath = [groupRoot stringByAppendingPathComponent:
                [folder stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
            if ([fm fileExistsAtPath:plistPath]) {
                NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:plistPath];
                NSString *identifier = plist[@"MCMMetadataIdentifier"];
                if (identifier && (
                    [identifier isEqualToString:bundleID] ||
                    [identifier rangeOfString:bundleID options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [bundleID rangeOfString:identifier options:NSCaseInsensitiveSearch].location != NSNotFound
                )) {
                    NSString *fullPath = [groupRoot stringByAppendingPathComponent:folder];
                    if (![paths containsObject:fullPath]) {
                        [paths addObject:fullPath];
                    }
                }
            }
        }
    }

    NSString *pluginRoot = @"/var/mobile/Containers/Data/PluginKitPlugin";
    if ([fm fileExistsAtPath:pluginRoot]) {
        NSArray *folders = [fm contentsOfDirectoryAtPath:pluginRoot error:nil];
        for (NSString *folder in folders) {
            NSString *plistPath = [pluginRoot stringByAppendingPathComponent:
                [folder stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
            if ([fm fileExistsAtPath:plistPath]) {
                NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:plistPath];
                NSString *identifier = plist[@"MCMMetadataIdentifier"];
                if (identifier && (
                    [identifier isEqualToString:bundleID] ||
                    [identifier rangeOfString:bundleID options:NSCaseInsensitiveSearch].location != NSNotFound
                )) {
                    NSString *fullPath = [pluginRoot stringByAppendingPathComponent:folder];
                    if (![paths containsObject:fullPath]) {
                        [paths addObject:fullPath];
                    }
                }
            }
        }
    }

    return paths;
}

- (NSString *)pathForGroupIdentifier:(NSString *)groupID {
    if (!groupID) return nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *groupRoot = @"/var/mobile/Containers/Shared/AppGroup";
    if (![fm fileExistsAtPath:groupRoot]) return nil;

    NSArray *folders = [fm contentsOfDirectoryAtPath:groupRoot error:nil];
    for (NSString *folder in folders) {
        NSString *plistPath = [groupRoot stringByAppendingPathComponent:
            [folder stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
        if ([fm fileExistsAtPath:plistPath]) {
            NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:plistPath];
            if ([plist[@"MCMMetadataIdentifier"] isEqualToString:groupID]) {
                return [groupRoot stringByAppendingPathComponent:folder];
            }
        }
    }
    return nil;
}

- (NSArray *)allDataPathsForBundleID:(NSString *)bundleID {
    if (!bundleID) return @[];
    NSMutableArray *allPaths = [NSMutableArray array];

    NSString *mainPath = [self dataPathForBundleID:bundleID];
    if (mainPath) [allPaths addObject:mainPath];

    NSArray *groupPaths = [self groupContainerPathsForBundleID:bundleID];
    [allPaths addObjectsFromArray:groupPaths];

    return allPaths;
}

#pragma mark - Size Calculation (Accurate)

- (unsigned long long)dataSizeForBundleID:(NSString *)bundleID {
    return [self accurateDataSizeForBundleID:bundleID];
}

- (unsigned long long)accurateDataSizeForBundleID:(NSString *)bundleID {
    NSArray *paths = [self allDataPathsForBundleID:bundleID];
    if (paths.count == 0) return 0;

    NSFileManager *fm = [NSFileManager defaultManager];
    unsigned long long totalSize = 0;

    for (NSString *path in paths) {
        NSArray *contents = [fm subpathsAtPath:path];
        for (NSString *item in contents) {
            @try {
                NSString *fullPath = [path stringByAppendingPathComponent:item];
                NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
                if (attrs) totalSize += [attrs fileSize];
            } @catch (NSException *e) { continue; }
        }
    }

    return totalSize;
}

- (NSString *)formatBytes:(unsigned long long)bytes {
    if (bytes == 0) return @"0 B";
    NSArray *units = @[@"B", @"KB", @"MB", @"GB", @"TB"];
    double size = (double)bytes;
    int unitIndex = 0;

    while (size >= 1024 && unitIndex < units.count - 1) {
        size /= 1024;
        unitIndex++;
    }

    if (unitIndex == 0) return [NSString stringWithFormat:@"%.0f %@", size, units[unitIndex]];
    if (unitIndex >= 3) return [NSString stringWithFormat:@"%.2f %@", size, units[unitIndex]];
    return [NSString stringWithFormat:@"%.2f %@", size, units[unitIndex]];
}

#pragma mark - Backup & Restore (Comprehensive)

- (NSString *)backupDirectory {
    NSString *backupPath = ROOT_PATH_NS(@"/var/mobile/Documents/AppDataBackups");
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:backupPath]) {
        [fm createDirectoryAtPath:backupPath
        withIntermediateDirectories:YES
                         attributes:@{NSFileOwnerAccountName: @"mobile", NSFileGroupOwnerAccountName: @"mobile"}
                              error:nil];
    }
    return backupPath;
}

- (BOOL)backupAppData:(NSString *)bundleID {
    if (!bundleID) return NO;

    NSArray *allPaths = [self allDataPathsForBundleID:bundleID];
    if (allPaths.count == 0) return NO;

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];

    NSString *backupName = [NSString stringWithFormat:@"%@_%@", bundleID, timestamp];
    NSString *backupBasePath = [[self backupDirectory] stringByAppendingPathComponent:backupName];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;

    [fm createDirectoryAtPath:backupBasePath withIntermediateDirectories:YES attributes:nil error:nil];

    NSMutableDictionary *manifest = [NSMutableDictionary dictionary];
    manifest[@"bundleID"] = bundleID;
    manifest[@"date"] = [NSDate date];
    manifest[@"timestamp"] = timestamp;
    manifest[@"paths"] = [NSMutableArray array];

    BOOL overallSuccess = YES;

    for (NSString *sourcePath in allPaths) {
        NSString *folderName = [sourcePath lastPathComponent];
        NSString *destPath = [backupBasePath stringByAppendingPathComponent:folderName];

        NSError *copyError = nil;
        BOOL success = [fm copyItemAtPath:sourcePath toPath:destPath error:&copyError];

        if (success) {
            [manifest[@"paths"] addObject:@{
                @"source": sourcePath,
                @"backup": destPath,
                @"folderName": folderName
            }];
        } else {
            NSLog(@"[AppDataManager] ⚠️ Failed to backup path %@: %@", sourcePath, copyError);
            overallSuccess = NO;
        }
    }

    NSString *manifestPath = [backupBasePath stringByAppendingPathComponent:@"_manifest.plist"];
    [manifest writeToFile:manifestPath atomically:YES];

    if (overallSuccess) {
        NSLog(@"[AppDataManager] ✅ Comprehensive backup created: %@", backupBasePath);
    }

    return overallSuccess || [manifest[@"paths"] count] > 0;
}

- (BOOL)wipeAppData:(NSString *)bundleID {
    if (!bundleID) return NO;
    if ([self isSystemApp:bundleID]) {
        NSLog(@"[AppDataManager] ⛔ Cannot wipe system app: %@", bundleID);
        return NO;
    }

    [self killApp:bundleID];
    [NSThread sleepForTimeInterval:0.5];

    NSArray *allPaths = [self allDataPathsForBundleID:bundleID];
    if (allPaths.count == 0) return NO;

    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL overallSuccess = YES;

    for (NSString *dataPath in allPaths) {
        NSError *error = nil;
        NSArray *contents = [fm contentsOfDirectoryAtPath:dataPath error:&error];
        if (error) {
            NSLog(@"[AppDataManager] ❌ Error reading directory %@: %@", dataPath, error);
            continue;
        }

        for (NSString *item in contents) {
            if ([item isEqualToString:@".com.apple.mobile_container_manager.metadata.plist"]) continue;

            NSString *fullPath = [dataPath stringByAppendingPathComponent:item];
            NSError *err = nil;
            [fm setAttributes:@{NSFilePosixPermissions: @0777} ofItemAtPath:fullPath error:nil];
            BOOL success = [fm removeItemAtPath:fullPath error:&err];
            if (!success) {
                [fm setAttributes:@{NSFilePosixPermissions: @0777} ofItemAtPath:[fullPath stringByDeletingLastPathComponent] error:nil];
                NSError *finalErr = nil;
                [fm removeItemAtPath:fullPath error:&finalErr];
                if ([fm fileExistsAtPath:fullPath]) {
                    overallSuccess = NO;
                }
            }
        }
    }

    [self clearAppCaches:bundleID];
    [self.sizeCache removeObjectForKey:bundleID];
    [self clearCache];

    NSLog(@"[AppDataManager] %@ Wiped data for: %@", overallSuccess ? @"✅" : @"⚠️", bundleID);
    return overallSuccess;
}

- (NSArray *)availableBackupsForBundleID:(NSString *)bundleID {
    if (!bundleID) return @[];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *backupDir = [self backupDirectory];
    NSArray *contents = [fm contentsOfDirectoryAtPath:backupDir error:nil];

    NSMutableArray *backups = [NSMutableArray array];
    for (NSString *item in contents) {
        if ([item hasPrefix:bundleID]) {
            NSString *fullPath = [backupDir stringByAppendingPathComponent:item];
            NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];

            NSString *manifestPath = [fullPath stringByAppendingPathComponent:@"_manifest.plist"];
            NSDictionary *manifest = [NSDictionary dictionaryWithContentsOfFile:manifestPath];
            NSDate *backupDate = manifest[@"date"] ?: attrs[NSFileCreationDate] ?: attrs[NSFileModificationDate] ?: [NSDate date];

            unsigned long long size = 0;
            NSArray *subpaths = [fm subpathsAtPath:fullPath];
            for (NSString *sub in subpaths) {
                if ([sub isEqualToString:@"_manifest.plist"]) continue;
                NSDictionary *subAttrs = [fm attributesOfItemAtPath:[fullPath stringByAppendingPathComponent:sub] error:nil];
                size += [subAttrs fileSize];
            }

            [backups addObject:@{
                @"path": fullPath,
                @"name": item,
                @"date": backupDate,
                @"size": @(size),
                @"sizeString": [self formatBytes:size],
                @"manifest": manifest ?: @{}
            }];
        }
    }

    return [backups sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"date"] compare:a[@"date"]];
    }];
}

- (BOOL)restoreAppData:(NSString *)bundleID fromBackup:(NSString *)backupPath {
    if (!bundleID || !backupPath) {
        NSLog(@"[AppDataManager] ❌ Invalid parameters for restore");
        return NO;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:backupPath]) {
        NSLog(@"[AppDataManager] ❌ Backup path does not exist: %@", backupPath);
        return NO;
    }

    [self killApp:bundleID];
    [NSThread sleepForTimeInterval:0.5];

    NSString *manifestPath = [backupPath stringByAppendingPathComponent:@"_manifest.plist"];
    NSDictionary *manifest = [NSDictionary dictionaryWithContentsOfFile:manifestPath];
    NSArray *manifestPaths = manifest[@"paths"];

    NSLog(@"[AppDataManager] 🧹 Wiping existing data for %@...", bundleID);
    [self wipeAppData:bundleID];
    [NSThread sleepForTimeInterval:0.3];

    BOOL allSuccess = YES;

    if (manifestPaths && manifestPaths.count > 0) {
        for (NSDictionary *pathInfo in manifestPaths) {
            NSString *srcPath = [backupPath stringByAppendingPathComponent:pathInfo[@"folderName"]];
            NSString *dstPath = pathInfo[@"source"];

            if (![fm fileExistsAtPath:dstPath]) {
                [fm createDirectoryAtPath:dstPath withIntermediateDirectories:YES attributes:nil error:nil];
            }

            NSError *copyErr = nil;
            NSArray *contents = [fm contentsOfDirectoryAtPath:srcPath error:&copyErr];
            if (contents) {
                for (NSString *item in contents) {
                    if ([item isEqualToString:@"_manifest.plist"]) continue;
                    NSString *itemSrc = [srcPath stringByAppendingPathComponent:item];
                    NSString *itemDst = [dstPath stringByAppendingPathComponent:item];

                    if ([fm fileExistsAtPath:itemDst]) {
                        [fm removeItemAtPath:itemDst error:nil];
                    }

                    NSError *err = nil;
                    BOOL copied = [fm copyItemAtPath:itemSrc toPath:itemDst error:&err];
                    if (copied) {
                        [self setFullPermissions:itemDst];
                    } else {
                        NSData *fileData = [NSData dataWithContentsOfFile:itemSrc];
                        if (fileData && [fileData writeToFile:itemDst atomically:YES]) {
                            [self setFullPermissions:itemDst];
                        } else {
                            NSLog(@"[AppDataManager] ⚠️ Failed to restore %@", item);
                            allSuccess = NO;
                        }
                    }
                }
            }
            [self setFullPermissions:dstPath];
        }
    } else {
        NSString *dataPath = [self dataPathForBundleID:bundleID];
        if (!dataPath) {
            NSLog(@"[AppDataManager] ❌ Could not find data path for %@", bundleID);
            return NO;
        }

        if (![fm fileExistsAtPath:dataPath]) {
            [fm createDirectoryAtPath:dataPath withIntermediateDirectories:YES attributes:nil error:nil];
        }

        NSArray *contents = [fm contentsOfDirectoryAtPath:backupPath error:nil];
        for (NSString *item in contents) {
            if ([item isEqualToString:@"_manifest.plist"]) continue;
            NSString *srcPath = [backupPath stringByAppendingPathComponent:item];
            NSString *dstPath = [dataPath stringByAppendingPathComponent:item];

            if ([fm fileExistsAtPath:dstPath]) [fm removeItemAtPath:dstPath error:nil];

            NSError *err = nil;
            BOOL copied = [fm copyItemAtPath:srcPath toPath:dstPath error:&err];
            if (copied) {
                [self setFullPermissions:dstPath];
            } else {
                NSData *fileData = [NSData dataWithContentsOfFile:srcPath];
                if (fileData && [fileData writeToFile:dstPath atomically:YES]) {
                    [self setFullPermissions:dstPath];
                } else {
                    allSuccess = NO;
                }
            }
        }
        [self setFullPermissions:dataPath];
    }

    [NSThread sleepForTimeInterval:0.3];
    [self killApp:bundleID];
    [self clearAppCaches:bundleID];

    NSLog(@"[AppDataManager] %@ Restored data for %@", allSuccess ? @"✅" : @"⚠️", bundleID);
    return allSuccess;
}

- (BOOL)deleteBackup:(NSString *)backupPath {
    if (!backupPath) return NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    BOOL success = [fm removeItemAtPath:backupPath error:&error];
    if (success) {
        NSLog(@"[AppDataManager] ✅ Deleted backup: %@", backupPath);
    } else {
        NSLog(@"[AppDataManager] ❌ Failed to delete backup: %@", error);
    }
    return success;
}

- (BOOL)deleteAllBackups {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *backupDir = [self backupDirectory];
    NSArray *contents = [fm contentsOfDirectoryAtPath:backupDir error:nil];
    BOOL allSuccess = YES;

    for (NSString *item in contents) {
        NSString *fullPath = [backupDir stringByAppendingPathComponent:item];
        NSError *err = nil;
        if (![fm removeItemAtPath:fullPath error:&err]) {
            allSuccess = NO;
        }
    }

    return allSuccess;
}

- (NSString *)exportBackupsToZip:(NSError **)error {
    return [self backupDirectory];
}

#pragma mark - Disk Space (Accurate)

- (unsigned long long)totalFreeSpace {
    struct statvfs buf;
    if (statvfs([ROOT_PATH_NS(@"/var") UTF8String], &buf) == 0) {
        return (unsigned long long)buf.f_bavail * buf.f_frsize;
    }
    return 0;
}

- (unsigned long long)totalDiskSpace {
    struct statvfs buf;
    if (statvfs([ROOT_PATH_NS(@"/var") UTF8String], &buf) == 0) {
        return (unsigned long long)buf.f_blocks * buf.f_frsize;
    }
    return 0;
}

#pragma mark - System App Check

- (BOOL)isSystemApp:(NSString *)bundleID {
    if (!bundleID) return NO;
    NSArray *systemApps = @[
        @"com.apple.springboard", @"com.apple.Preferences",
        @"com.apple.mobilesafari", @"com.apple.MobileSMS",
        @"com.apple.mobilephone", @"com.apple.camera",
        @"com.apple.mobilemail", @"com.apple.Maps",
        @"com.apple.mobilecal", @"com.apple.mobileslideshow",
        @"com.apple.AppStore", @"com.apple.ios.StoreKitUIService",
        @"com.apple.Health", @"com.apple.mobiletimer",
        @"com.apple.weather", @"com.apple.news",
        @"com.apple.podcasts", @"com.apple.music",
        @"com.apple.mobileipod", @"com.apple.Passbook",
        @"com.apple.mobilewallet", @"com.apple.stocks",
        @"com.apple.Home", @"com.apple.findmy",
        @"com.apple.shortcuts", @"com.apple.translate",
        @"com.apple.compass", @"com.apple.measure",
        @"com.apple.calculator", @"com.apple.dictionary",
        @"com.apple.videos", @"com.apple.iBooks",
        @"com.apple.Pages", @"com.apple.Numbers",
        @"com.apple.Keynote", @"com.apple.mobileme.fmip1",
        @"com.apple.mobileme.fmf1", @"com.apple.gamecenter",
        @"com.apple.mobilegarageband", @"com.apple.clips",
        @"com.apple.iMovie", @"com.apple.mobilenotes",
        @"com.apple.reminders", @"com.apple.mobilephone",
        @"com.apple.facetime", @"com.apple.mobilesms",
        @"com.apple.mobilesafari", @"com.apple.mobilemail"
    ];
    return [systemApps containsObject:bundleID];
}

#pragma mark - UI Support Methods

- (UIImage *)iconForBundleID:(NSString *)bundleID {
    if (!bundleID) return nil;
    UIImage *cached = [self.iconCache objectForKey:bundleID];
    if (cached) return cached;

    UIImage *icon = nil;
    @try {
        Class LSApplicationProxy_class = objc_getClass("LSApplicationProxy");
        if (LSApplicationProxy_class && [LSApplicationProxy_class respondsToSelector:@selector(applicationProxyForIdentifier:)]) {
            id proxy = [LSApplicationProxy_class performSelector:@selector(applicationProxyForIdentifier:) withObject:bundleID];
            if (proxy) {
                NSArray *variants = @[@(0), @(1), @(2), @(10)];
                for (NSNumber *variant in variants) {
                    if ([proxy respondsToSelector:@selector(iconDataForVariant:)]) {
                        NSData *iconData = [proxy performSelector:@selector(iconDataForVariant:) withObject:variant];
                        if (iconData) {
                            icon = [UIImage imageWithData:iconData];
                            if (icon) break;
                        }
                    }
                }
                if (!icon && [proxy respondsToSelector:@selector(iconForDisplayIdentifier:withFormat:)]) {
                    icon = [proxy performSelector:@selector(iconForDisplayIdentifier:withFormat:) withObject:bundleID withObject:@(10)];
                }
            }
        }
    } @catch (NSException *e) {}

    if (!icon) {
        @try {
            NSString *appPath = nil;
            Class LSApplicationProxy_class = objc_getClass("LSApplicationProxy");
            if (LSApplicationProxy_class && [LSApplicationProxy_class respondsToSelector:@selector(applicationProxyForIdentifier:)]) {
                id proxy = [LSApplicationProxy_class performSelector:@selector(applicationProxyForIdentifier:) withObject:bundleID];
                if (proxy && [proxy respondsToSelector:@selector(bundleURL)]) {
                    NSURL *bundleURL = [proxy performSelector:@selector(bundleURL)];
                    appPath = [bundleURL path];
                }
            }

            if (appPath) {
                NSBundle *bundle = [NSBundle bundleWithPath:appPath];
                if (bundle) {
                    NSDictionary *info = [bundle infoDictionary];
                    NSArray *iconFiles = info[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"];
                    if (!iconFiles) iconFiles = info[@"CFBundleIconFiles"];
                    if (!iconFiles) iconFiles = @[info[@"CFBundleIconFile"] ?: @"AppIcon60x60"];
                    if (iconFiles && iconFiles.count > 0) {
                        for (NSString *iconName in [iconFiles reverseObjectEnumerator]) {
                            NSString *iconPath3x = [appPath stringByAppendingPathComponent:[iconName stringByAppendingString:@"@3x.png"]];
                            NSString *iconPath2x = [appPath stringByAppendingPathComponent:[iconName stringByAppendingString:@"@2x.png"]];
                            NSString *iconPath = [appPath stringByAppendingPathComponent:[iconName stringByAppendingString:@".png"]];

                            if ([[NSFileManager defaultManager] fileExistsAtPath:iconPath3x]) {
                                icon = [UIImage imageWithContentsOfFile:iconPath3x];
                            } else if ([[NSFileManager defaultManager] fileExistsAtPath:iconPath2x]) {
                                icon = [UIImage imageWithContentsOfFile:iconPath2x];
                            } else if ([[NSFileManager defaultManager] fileExistsAtPath:iconPath]) {
                                icon = [UIImage imageWithContentsOfFile:iconPath];
                            }
                            if (icon) break;
                        }
                    }
                }
            }
        } @catch (NSException *e) {}
    }

    if (icon) [self.iconCache setObject:icon forKey:bundleID];
    return icon;
}

- (NSString *)versionForBundleID:(NSString *)bundleID {
    if (!bundleID) return @"Unknown";
    Class LSApplicationProxy_class = objc_getClass("LSApplicationProxy");
    if (LSApplicationProxy_class && [LSApplicationProxy_class respondsToSelector:@selector(applicationProxyForIdentifier:)]) {
        id proxy = [LSApplicationProxy_class performSelector:@selector(applicationProxyForIdentifier:) withObject:bundleID];
        if (proxy && [proxy respondsToSelector:@selector(shortVersionString)]) {
            return [proxy performSelector:@selector(shortVersionString)] ?: @"Unknown";
        }
    }
    return @"Unknown";
}

- (NSString *)documentsPathForBundleID:(NSString *)bundleID {
    NSString *dataPath = [self dataPathForBundleID:bundleID];
    if (!dataPath) return nil;
    return [dataPath stringByAppendingPathComponent:@"Documents"];
}

- (NSUInteger)documentsCountForBundleID:(NSString *)bundleID {
    NSString *docsPath = [self documentsPathForBundleID:bundleID];
    if (!docsPath) return 0;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:docsPath error:nil];
    return contents.count;
}

- (NSDate *)lastBackupDateForBundleID:(NSString *)bundleID {
    NSArray *backups = [self availableBackupsForBundleID:bundleID];
    if (backups.count == 0) return nil;
    return backups[0][@"date"];
}

- (unsigned long long)totalBackupsSize {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *backupDir = [self backupDirectory];
    NSArray *contents = [fm contentsOfDirectoryAtPath:backupDir error:nil];
    unsigned long long total = 0;
    for (NSString *item in contents) {
        NSString *fullPath = [backupDir stringByAppendingPathComponent:item];
        NSArray *subpaths = [fm subpathsAtPath:fullPath];
        for (NSString *sub in subpaths) {
            if ([sub isEqualToString:@"_manifest.plist"]) continue;
            NSDictionary *attrs = [fm attributesOfItemAtPath:[fullPath stringByAppendingPathComponent:sub] error:nil];
            total += [attrs fileSize];
        }
    }
    return total;
}

- (unsigned long long)totalAppsDataSize {
    NSArray *apps = self.cachedApps ?: [self allInstalledApplications];
    unsigned long long total = 0;
    for (NSDictionary *app in apps) {
        total += [app[@"size"] unsignedLongLongValue];
    }
    return total;
}

- (void)clearCache {
    self.cachedApps = nil;
    [self.sizeCache removeAllObjects];
    [self.iconCache removeAllObjects];
}

- (BOOL)killApp:(NSString *)bundleID {
    if (!bundleID) return NO;

    NSLog(@"[AppDataManager] 💀 Killing app: %@", bundleID);

    @try {
        void *fbHandle = dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices", RTLD_LAZY);
        if (fbHandle) {
            Class FBSSystemService_class = NSClassFromString(@"FBSSystemService");
            if (FBSSystemService_class && [FBSSystemService_class respondsToSelector:@selector(sharedService)]) {
                id service = [FBSSystemService_class performSelector:@selector(sharedService)];
                SEL killSel = @selector(terminateApplication:forReason:andReport:completion:);
                if (service && [service respondsToSelector:killSel]) {
                    NSMethodSignature *sig = [service methodSignatureForSelector:killSel];
                    if (sig) {
                        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                        [inv setSelector:killSel];
                        [inv setTarget:service];
                        NSString *bid = bundleID;
                        NSNumber *reason = @(1);
                        NSNumber *report = @(NO);
                        [inv setArgument:&bid atIndex:2];
                        [inv setArgument:&reason atIndex:3];
                        [inv setArgument:&report atIndex:4];
                        [inv invoke];
                    }
                    NSLog(@"[AppDataManager] ✅ Killed via FrontBoardServices");
                    return YES;
                }
            }
        }
    } @catch (NSException *e) {}

    @try {
        Class LSApplicationWorkspace_class = objc_getClass("LSApplicationWorkspace");
        if (LSApplicationWorkspace_class && [LSApplicationWorkspace_class respondsToSelector:@selector(defaultWorkspace)]) {
            id workspace = [LSApplicationWorkspace_class performSelector:@selector(defaultWorkspace)];
            if (workspace && [workspace respondsToSelector:@selector(closeApplicationWithBundleID:)]) {
                [workspace performSelector:@selector(closeApplicationWithBundleID:) withObject:bundleID];
                NSLog(@"[AppDataManager] ✅ Killed via LSApplicationWorkspace");
                return YES;
            }
        }
    } @catch (NSException *e) {}

    NSLog(@"[AppDataManager] ⚠️ Could not kill app: %@", bundleID);
    return NO;
}

- (void)clearAppCaches:(NSString *)bundleID {
    if (!bundleID) return;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *paths = [self allDataPathsForBundleID:bundleID];
    for (NSString *path in paths) {
        NSString *cachesPath = [path stringByAppendingPathComponent:@"Library/Caches"];
        if ([fm fileExistsAtPath:cachesPath]) {
            NSArray *cacheContents = [fm contentsOfDirectoryAtPath:cachesPath error:nil];
            for (NSString *item in cacheContents) {
                NSString *fullPath = [cachesPath stringByAppendingPathComponent:item];
                [fm removeItemAtPath:fullPath error:nil];
            }
        }
        NSString *tmpPath = [path stringByAppendingPathComponent:@"tmp"];
        if ([fm fileExistsAtPath:tmpPath]) {
            NSArray *tmpContents = [fm contentsOfDirectoryAtPath:tmpPath error:nil];
            for (NSString *item in tmpContents) {
                NSString *fullPath = [tmpPath stringByAppendingPathComponent:item];
                [fm removeItemAtPath:fullPath error:nil];
            }
        }
    }
}

- (void)setFullPermissions:(NSString *)path {
    if (!path) return;
    NSFileManager *fm = [NSFileManager defaultManager];

    [fm setAttributes:@{
        NSFileOwnerAccountName: @"mobile",
        NSFileGroupOwnerAccountName: @"mobile",
        NSFilePosixPermissions: @0755
    } ofItemAtPath:path error:nil];

    BOOL isDir = NO;
    if ([fm fileExistsAtPath:path isDirectory:&isDir] && isDir) {
        NSArray *contents = [fm contentsOfDirectoryAtPath:path error:nil];
        for (NSString *item in contents) {
            NSString *fullPath = [path stringByAppendingPathComponent:item];
            [self setFullPermissions:fullPath];
        }
    }
}

@end
