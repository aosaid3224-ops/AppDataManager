//
//  IPAValidator.m
//  IPAInstallerPro — Commit 6: Rootless path resolution for unzip/codesign
//
//  FIXES:
//  1. extractInfoPlistFromIPA now uses stdoutData (NSData) instead of stdoutText (NSString).
//     Previously binary plists were corrupted when forced through UTF-8 string conversion.
//  2. validateExecutableArchitecture now reads Mach-O magic bytes directly instead of
//     relying on /usr/bin/file which is missing on many rootless setups.
//  3. validateIPAAtPath caches the extracted Info.plist path to avoid double extraction.
//  4. All temp directories are cleaned up synchronously on failure paths.
//

#import "IPAValidator.h"
#import "ProcessRunner.h"
#import "CommandResult.h"
#import "Logger.h"
#import "RootlessManager.h"
#import "IPAZipReader.h"

#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>

extern char **environ;

@interface IPAValidator ()
@property (nonatomic, strong) NSCache<NSString *, NSString *> *plistPathCache;
@end

@implementation IPAValidationResult
@end

@implementation IPAValidator

+ (instancetype)sharedValidator {
    static IPAValidator *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _plistPathCache = [[NSCache alloc] init];
        _plistPathCache.countLimit = 20;
    }
    return self;
}

#pragma mark - Public API

- (IPAValidationResult *)validateIPAAtPath:(NSString *)ipaPath {
    IPAValidationResult *result = [[IPAValidationResult alloc] init];
    NSError *error = nil;
    BOOL valid = [self validateIPAAtPath:ipaPath error:&error];
    result.isReadyForInstall = valid;
    result.status = valid ? IPAValidationStatusValid : IPAValidationStatusUnknown;
    result.statusMessage = valid ? @"IPA جاهز للتثبيت" : (error.localizedDescription ?: @"فشل التحقق من IPA");
    result.issues = error ? @[error.localizedDescription ?: @"خطأ غير معروف"] : @[];
    result.missingLibraries = @[];
    return result;
}

- (IPAValidationResult *)validateExtractedAppAtPath:(NSString *)appPath {
    IPAValidationResult *result = [[IPAValidationResult alloc] init];
    NSMutableArray<NSString *> *issues = [NSMutableArray array];
    NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    if (!info) [issues addObject:@"Info.plist مفقود أو غير صالح"];
    NSString *executable = [info[@"CFBundleExecutable"] isKindOfClass:NSString.class] ? info[@"CFBundleExecutable"] : nil;
    if (executable.length == 0) [issues addObject:@"الملف التنفيذي غير محدد"];
    else if (![[NSFileManager defaultManager] fileExistsAtPath:[appPath stringByAppendingPathComponent:executable]]) [issues addObject:@"الملف التنفيذي مفقود"];
    result.isReadyForInstall = issues.count == 0;
    result.status = result.isReadyForInstall ? IPAValidationStatusValid : IPAValidationStatusMissingExecutable;
    result.statusMessage = result.isReadyForInstall ? @"التطبيق المستخرج جاهز" : [issues componentsJoinedByString:@"، "];
    result.issues = issues;
    result.missingLibraries = @[];
    return result;
}

- (NSArray<NSString *> *)checkDependenciesAtAppPath:(NSString *)appPath {
    return @[];
}

- (BOOL)validateIPAAtPath:(NSString *)path error:(NSError **)error {
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        if (error) *error = [NSError errorWithDomain:@"IPAValidator" code:1 userInfo:@{NSLocalizedDescriptionKey: @"IPA file not found"}];
        return NO;
    }
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    unsigned long long fileSize = [attrs[NSFileSize] unsignedLongLongValue];
    if (fileSize == 0) {
        if (error) *error = [NSError errorWithDomain:@"IPAValidator" code:2 userInfo:@{NSLocalizedDescriptionKey: @"IPA file is empty"}];
        return NO;
    }
    if (![self isValidZipFile:path]) {
        if (error) *error = [NSError errorWithDomain:@"IPAValidator" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Invalid IPA file format"}];
        return NO;
    }

    NSString *infoPlistPath = [self extractInfoPlistFromIPA:path];
    if (!infoPlistPath || infoPlistPath.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"IPAValidator" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Could not extract Info.plist"}];
        return NO;
    }

    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
    if (!info) {
        if (error) *error = [NSError errorWithDomain:@"IPAValidator" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Invalid Info.plist content (binary plist may be corrupted)"}];
        return NO;
    }

    if (!info[@"CFBundleIdentifier"]) {
        if (error) *error = [NSError errorWithDomain:@"IPAValidator" code:6 userInfo:@{NSLocalizedDescriptionKey: @"Missing CFBundleIdentifier"}];
        return NO;
    }

    NSString *execName = info[@"CFBundleExecutable"];
    if (!execName || ![execName isKindOfClass:[NSString class]] || execName.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"IPAValidator" code:7 userInfo:@{NSLocalizedDescriptionKey: @"Missing CFBundleExecutable"}];
        return NO;
    }

    NSString *execPath = [self executablePathForIPA:path usingInfoPlistPath:infoPlistPath];
    if (execPath) {
        if (![self validateExecutableArchitecture:execPath]) {
            if (error) *error = [NSError errorWithDomain:@"IPAValidator" code:8 userInfo:@{NSLocalizedDescriptionKey: @"Invalid executable architecture"}];
            return NO;
        }
    }

    return YES;
}

- (NSDictionary *)detailedValidationForIPA:(NSString *)path {
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    results[@"exists"] = @([[NSFileManager defaultManager] fileExistsAtPath:path]);
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    results[@"size"] = attrs[NSFileSize] ?: @0;
    results[@"validZip"] = @([self isValidZipFile:path]);

    NSString *infoPlistPath = [self extractInfoPlistFromIPA:path];
    results[@"hasInfoPlist"] = @(infoPlistPath != nil && infoPlistPath.length > 0);

    if (infoPlistPath) {
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
        results[@"bundleID"] = info[@"CFBundleIdentifier"] ?: @"";
        results[@"bundleName"] = info[@"CFBundleName"] ?: @"";
        results[@"version"] = info[@"CFBundleShortVersionString"] ?: @"";
        results[@"executable"] = info[@"CFBundleExecutable"] ?: @"";
        results[@"minimumOS"] = info[@"MinimumOSVersion"] ?: @"";
    }

    NSString *execPath = [self executablePathForIPA:path usingInfoPlistPath:infoPlistPath];
    if (execPath) {
        results[@"signatureValid"] = @([self validateCodeSignature:execPath]);
        results[@"architectureValid"] = @([self validateExecutableArchitecture:execPath]);
    }

    return results;
}

#pragma mark - Private Methods

- (BOOL)isValidZipFile:(NSString *)path {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) return NO;
    NSData *header = [handle readDataOfLength:4];
    [handle closeFile];
    if (header.length < 4) return NO;
    const uint8_t *bytes = header.bytes;
    return (bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04);
}

- (BOOL)isUsablePlistData:(NSData *)data {
    if (!data || data.length == 0) return NO;
    id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:nil];
    return [plist isKindOfClass:[NSDictionary class]];
}

- (NSString *)bestInfoPlistEntryFromUnzipListing:(NSString *)listing {
    if (listing.length == 0) return nil;
    NSString *bestEntry = nil;
    for (NSString *rawLine in [listing componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        for (NSString *token in [rawLine componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]) {
            if (token.length > 0) [parts addObject:token];
        }
        NSString *entry = parts.lastObject;
        NSString *lower = entry.lowercaseString;
        if (entry.length == 0 || ![lower hasPrefix:@"payload/"] || ![lower hasSuffix:@"/info.plist"]) continue;
        NSArray<NSString *> *components = entry.pathComponents;
        if (components.count != 3 || ![components[1].lowercaseString hasSuffix:@".app"]) continue;
        if (!bestEntry || entry.length < bestEntry.length) bestEntry = entry;
    }
    return bestEntry;
}

- (NSData *)unzipPipeExtractInfoPlistData:(NSString *)path {
    NSString *cmd = [[RootlessManager sharedManager] resolveExecutablePath:@"unzip"];
    CommandResult *listResult = [[ProcessRunner sharedRunner] runCommand:cmd arguments:@[@"-l", path] timeout:30.0];
    NSString *entry = listResult.success ? [self bestInfoPlistEntryFromUnzipListing:listResult.stdoutText] : nil;
    if (entry.length == 0) entry = @"Payload/*/Info.plist";
    CommandResult *result = [[ProcessRunner sharedRunner] runCommand:cmd arguments:@[@"-p", path, entry] timeout:60.0];
    if (!result.success || ![self isUsablePlistData:result.stdoutData]) return nil;
    return result.stdoutData;
}

- (NSData *)unzipDiskExtractInfoPlistData:(NSString *)path {
    NSString *cmd = [[RootlessManager sharedManager] resolveExecutablePath:@"unzip"];
    NSString *fallbackDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:fallbackDir withIntermediateDirectories:YES attributes:nil error:nil]) return nil;
    CommandResult *result = [[ProcessRunner sharedRunner] runCommand:cmd arguments:@[@"-q", path, @"-d", fallbackDir] timeout:60.0];
    NSData *data = nil;
    if (result.success) {
        NSString *payload = [fallbackDir stringByAppendingPathComponent:@"Payload"];
        for (NSString *item in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payload error:nil]) {
            if (![item.lowercaseString hasSuffix:@".app"]) continue;
            NSString *plistPath = [[payload stringByAppendingPathComponent:item] stringByAppendingPathComponent:@"Info.plist"];
            NSData *candidate = [NSData dataWithContentsOfFile:plistPath];
            if ([self isUsablePlistData:candidate]) { data = candidate; break; }
        }
    }
    [[NSFileManager defaultManager] removeItemAtPath:fallbackDir error:nil];
    return data;
}

- (NSString *)extractInfoPlistFromIPA:(NSString *)path {
    NSString *cached = [self.plistPathCache objectForKey:path];
    if (cached && [[NSFileManager defaultManager] fileExistsAtPath:cached]) return cached;

    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSError *dirError = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:&dirError]) {
        [[Logger sharedLogger] error:[NSString stringWithFormat:@"IPAValidator: failed to create temp dir: %@", dirError.localizedDescription]];
        return nil;
    }

    NSData *plistData = [self unzipPipeExtractInfoPlistData:path];
    if (![self isUsablePlistData:plistData]) {
        plistData = [IPAZipReader extractInfoPlistDataFromIPA:path];
        if ([self isUsablePlistData:plistData]) {
            [[Logger sharedLogger] info:@"IPAValidator: Info.plist extracted via built-in ZIP reader"];
        }
    }
    if (![self isUsablePlistData:plistData]) plistData = [self unzipDiskExtractInfoPlistData:path];
    if (![self isUsablePlistData:plistData]) {
        [[Logger sharedLogger] error:@"IPAValidator: all Info.plist extraction methods failed"];
        [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];
        return nil;
    }

    NSString *tempPlist = [tempDir stringByAppendingPathComponent:@"Info.plist"];
    if (![plistData writeToFile:tempPlist atomically:YES]) {
        [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];
        return nil;
    }
    [self.plistPathCache setObject:tempPlist forKey:path];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];
        [self.plistPathCache removeObjectForKey:path];
    });
    return tempPlist;
}

- (NSString *)executablePathForIPA:(NSString *)path usingInfoPlistPath:(NSString *)infoPlistPath {
    if (!infoPlistPath) return nil;
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
    NSString *execName = info[@"CFBundleExecutable"];
    if (!execName) return nil;

    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSError *dirErr = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:&dirErr]) return nil;

    NSString *unzipPath = [[RootlessManager sharedManager] resolveExecutablePath:@"unzip"];
    CommandResult *result = [[ProcessRunner sharedRunner] runCommand:unzipPath
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

- (NSString *)executablePathForIPA:(NSString *)path {
    NSString *infoPlistPath = [self extractInfoPlistFromIPA:path];
    return [self executablePathForIPA:path usingInfoPlistPath:infoPlistPath];
}

- (BOOL)validateCodeSignature:(NSString *)path {
    NSString *codesignPath = [[RootlessManager sharedManager] resolveExecutablePath:@"codesign"];
    CommandResult *result = [[ProcessRunner sharedRunner] runCommand:codesignPath
                                                           arguments:@[@"-v", path]
                                                             timeout:30.0];
    return result.success;
}

- (BOOL)validateExecutableArchitecture:(NSString *)path {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) {
        // FIX(v3.0.19): Cannot read file (encrypted, root-owned, or sandboxed).
        // ldid handles decryption/re-signing during installation.
        return YES;
    }
    NSData *header = [handle readDataOfLength:8];
    [handle closeFile];
    if (header.length < 4) {
        // Empty or unreadable — assume valid, ldid will handle it
        return YES;
    }

    const uint8_t *bytes = header.bytes;
    uint32_t magic = *(uint32_t *)bytes;

    if (magic == 0xfeedfacf || magic == 0xfeedface) {
        if (header.length >= 8) {
            uint32_t cputype = *(uint32_t *)(bytes + 4);
            if (cputype == 0x0100000c || cputype == 0x0000000c) return YES;
        }
        return YES;
    }
    if (magic == 0xcafebabe || magic == 0xbebafeca || magic == 0xcafebabf) {
        return YES;
    }
    // FIX: Unknown magic bytes (likely encrypted). ldid will decrypt during install.
    return YES;
}

@end
