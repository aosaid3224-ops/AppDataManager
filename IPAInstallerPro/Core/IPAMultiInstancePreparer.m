#import "IPAMultiInstancePreparer.h"
#import "ApplicationManager.h"
#import <spawn.h>
#import <sys/wait.h>
#import <unistd.h>
extern char **environ;

@interface IPAMultiInstancePreparer ()
@property (nonatomic, copy) NSString *unzipPath;
@property (nonatomic, copy) NSString *zipPath;
@end

@implementation IPAMultiInstancePreparer

+ (instancetype)sharedPreparer {
    static IPAMultiInstancePreparer *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _unzipPath = @"/usr/bin/unzip";
    _zipPath = @"/usr/bin/zip";
    return self;
}

- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description {
    return [NSError errorWithDomain:@"IPAMultiInstance" code:code userInfo:@{NSLocalizedDescriptionKey: description ?: @"تعذر تجهيز النسخة المتعددة."}];
}

- (BOOL)run:(NSString *)path arguments:(NSArray<NSString *> *)arguments directory:(NSString *)directory error:(NSError **)error {
    if (path.length == 0) {
        if (error) *error = [self errorWithCode:10 description:@"مسار أداة التجهيز غير صالح."];
        return NO;
    }
    NSMutableArray<NSString *> *argvStrings = nil;
    NSString *spawnPath = path;
    if (directory.length) {
        // iOS does not expose posix_spawn_file_actions_addchdir_np. Use sh only as
        // an argv transport; every user argument remains a separate quoted argv item.
        argvStrings = [NSMutableArray arrayWithObjects:@"/bin/sh", @"-c", @"cd \"$1\" && shift 1 && exec \"$@\"", @"ipa-multi-instance", directory, path, nil];
        [argvStrings addObjectsFromArray:arguments ?: @[]];
        spawnPath = @"/bin/sh";
    } else {
        argvStrings = [NSMutableArray arrayWithObject:path];
        [argvStrings addObjectsFromArray:arguments ?: @[]];
    }
    char **argv = calloc(argvStrings.count + 1, sizeof(char *));
    for (NSUInteger index = 0; index < argvStrings.count; index++) argv[index] = (char *)argvStrings[index].fileSystemRepresentation;
    argv[argvStrings.count] = NULL;
    pid_t pid = 0;
    int spawnError = posix_spawn(&pid, spawnPath.fileSystemRepresentation, NULL, NULL, argv, environ);
    free(argv);
    if (spawnError != 0) {
        if (error) *error = [self errorWithCode:11 description:[NSString stringWithFormat:@"تعذر تشغيل أداة التجهيز (errno=%d).", spawnError]];
        return NO;
    }
    int status = 0;
    while (waitpid(pid, &status, 0) < 0 && errno == EINTR) { }
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        if (error) *error = [self errorWithCode:12 description:@"تعذر تنفيذ أداة تجهيز النسخة."];
        return NO;
    }
    return YES;
}

- (NSString *)uniqueBundleIDForSourceID:(NSString *)sourceID {
    if (sourceID.length == 0) return nil;
    ApplicationManager *manager = [ApplicationManager sharedManager];
    for (NSUInteger index = 2; index < 1000; index++) {
        NSString *candidate = [NSString stringWithFormat:@"%@.multi%lu", sourceID, (unsigned long)index];
        if (![manager appInfoForBundleID:candidate]) return candidate;
    }
    return nil;
}

- (BOOL)rewritePlistAtPath:(NSString *)path sourceID:(NSString *)sourceID targetID:(NSString *)targetID displayName:(NSString *)displayName error:(NSError **)error {
    NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    if (!plist) return YES;
    NSString *oldID = [plist[@"CFBundleIdentifier"] isKindOfClass:NSString.class] ? plist[@"CFBundleIdentifier"] : nil;
    if (oldID.length == 0) return YES;
    NSString *newID = [oldID isEqualToString:sourceID] ? targetID : ([oldID hasPrefix:[sourceID stringByAppendingString:@"."]] ? [targetID stringByAppendingString:[oldID substringFromIndex:sourceID.length]] : oldID);
    plist[@"CFBundleIdentifier"] = newID;
    if ([oldID isEqualToString:sourceID] && displayName.length) {
        plist[@"CFBundleDisplayName"] = [NSString stringWithFormat:@"%@ نسخة", displayName];
        plist[@"CFBundleName"] = [NSString stringWithFormat:@"%@ نسخة", displayName];
    }
    if (![plist writeToFile:path atomically:YES]) {
        if (error) *error = [self errorWithCode:20 description:[NSString stringWithFormat:@"تعذر تحديث هوية %@", path.lastPathComponent]];
        return NO;
    }
    return YES;
}

- (void)prepareIPAAtPath:(NSString *)ipaPath displayName:(NSString *)displayName completion:(IPAMultiInstancePreparationCompletion)completion {
    NSString *source = [ipaPath copy];
    NSString *name = [displayName copy];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *work = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"IPAMultiInstance-%@", NSUUID.UUID.UUIDString]];
        NSString *safeDisplayName = [name stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
        safeDisplayName = [safeDisplayName stringByReplacingOccurrencesOfString:@"\\" withString:@"-"];
        safeDisplayName = [safeDisplayName stringByReplacingOccurrencesOfString:@":" withString:@"-"];
        safeDisplayName = [safeDisplayName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (safeDisplayName.length == 0) safeDisplayName = @"Application";
        NSString *prepared = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.ipa", safeDisplayName, NSUUID.UUID.UUIDString]];
        NSString *preparedPath = nil;
        NSString *targetID = nil;
        NSError *error = nil;
        @try {
            NSDictionary *sourceAttrs = [fm attributesOfItemAtPath:source error:nil];
            if (source.length == 0 || ![sourceAttrs[NSFileType] isEqualToString:NSFileTypeRegular]) error = [self errorWithCode:1 description:@"ملف IPA غير صالح."];
            if (!error && ![self run:self.unzipPath arguments:@[@"-q", @"-o", source, @"-d", work] directory:nil error:&error]) error = error ?: [self errorWithCode:2 description:@"تعذر فتح IPA."];
            NSString *payload = [work stringByAppendingPathComponent:@"Payload"];
            NSArray *entries = [fm contentsOfDirectoryAtPath:payload error:nil];
            NSString *app = nil;
            for (NSString *entry in entries) if ([entry.pathExtension.lowercaseString isEqualToString:@"app"]) { app = [payload stringByAppendingPathComponent:entry]; break; }
            NSString *infoPath = app.length ? [app stringByAppendingPathComponent:@"Info.plist"] : nil;
            NSDictionary *sourceInfo = infoPath.length ? [NSDictionary dictionaryWithContentsOfFile:infoPath] : nil;
            NSString *sourceID = [sourceInfo[@"CFBundleIdentifier"] isKindOfClass:NSString.class] ? sourceInfo[@"CFBundleIdentifier"] : nil;
            if (!error && (app.length == 0 || sourceID.length == 0)) error = [self errorWithCode:3 description:@"تعذر العثور على هوية التطبيق داخل IPA."];
            if (!error) targetID = [self uniqueBundleIDForSourceID:sourceID];
            if (!error && targetID.length == 0) error = [self errorWithCode:4 description:@"تعذر إنشاء Bundle ID فريد للنسخة."];
            if (!error) {
                NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:app];
                NSString *relative = nil;
                while ((relative = [enumerator nextObject])) {
                    NSString *full = [app stringByAppendingPathComponent:relative];
                    if ([relative.lastPathComponent isEqualToString:@"_CodeSignature"] && [fm fileExistsAtPath:full]) { [fm removeItemAtPath:full error:nil]; [enumerator skipDescendants]; continue; }
                    if ([relative.lastPathComponent isEqualToString:@"Info.plist"] && ![self rewritePlistAtPath:full sourceID:sourceID targetID:targetID displayName:name error:&error]) break;
                }
            }
            if (!error && ![fm createDirectoryAtPath:work.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&error]) {}
            if (!error && ![self run:self.zipPath arguments:@[@"-qry", prepared, @"Payload"] directory:work error:&error]) error = error ?: [self errorWithCode:5 description:@"تعذر إنشاء IPA النسخة المتعددة."];
            if (!error) preparedPath = prepared;
        } @catch (NSException *exception) {
            error = [self errorWithCode:99 description:exception.reason];
        }
        [fm removeItemAtPath:work error:nil];
        if (error && prepared.length) [fm removeItemAtPath:prepared error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(preparedPath, targetID, name, error);
        });
    });
}

@end
