#import "IPAExportManager.h"
#import "RootlessManager.h"
#import <spawn.h>
#import <sys/stat.h>
#import <sys/wait.h>
#import <unistd.h>

extern char **environ;

static NSString *IPAExportErrorDomain = @"com.aosaid.ipainstallerpro.export";

@interface IPAExportManager ()
@property (nonatomic, strong) NSString *cpPath;
@property (nonatomic, strong) NSString *zipPath;
@property (nonatomic, strong) NSString *shellPath;
@end

@implementation IPAExportManager

+ (instancetype)sharedManager {
    static IPAExportManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        RootlessManager *rootless = [RootlessManager sharedManager];
        _cpPath = [rootless resolvePath:@"/bin/cp"];
        _zipPath = [rootless resolvePath:@"/usr/bin/zip"];
        _shellPath = [rootless resolvePath:@"/bin/sh"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:_shellPath]) _shellPath = @"/bin/sh";
    }
    return self;
}

- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description {
    return [NSError errorWithDomain:IPAExportErrorDomain
                                code:code
                            userInfo:@{NSLocalizedDescriptionKey: description ?: @"تعذر استخراج IPA"}];
}

- (BOOL)isDirectoryWithoutSymlinkAtPath:(NSString *)path {
    struct stat st;
    if (lstat(path.fileSystemRepresentation, &st) != 0) return NO;
    return S_ISDIR(st.st_mode);
}

- (BOOL)runCommand:(NSString *)command
              args:(NSArray<NSString *> *)args
    workingDirectory:(NSString *)workingDirectory
              error:(NSError **)error {
    if (command.length == 0 || ![[NSFileManager defaultManager] isExecutableFileAtPath:command]) {
        if (error) *error = [self errorWithCode:10 description:@"أداة الأرشفة المطلوبة غير موجودة أو غير قابلة للتنفيذ"];
        return NO;
    }

    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    NSString *spawnCommand = command;
    NSMutableArray<NSString *> *argvStrings = [NSMutableArray arrayWithObject:command];
    if (workingDirectory.length > 0) {
        if (![[NSFileManager defaultManager] isExecutableFileAtPath:self.shellPath]) {
            posix_spawn_file_actions_destroy(&actions);
            if (error) *error = [self errorWithCode:11 description:@"أداة تشغيل الأوامر غير متاحة لإنشاء مجلد العمل"];
            return NO;
        }
        // Do not interpolate paths into shell source. They are passed as
        // positional arguments, so spaces and user-provided Unicode are safe.
        spawnCommand = self.shellPath;
        argvStrings = [NSMutableArray arrayWithObjects:self.shellPath,
                       @"-c", @"cd \"$1\" && shift && exec \"$@\"",
                       @"ipa-export", workingDirectory, command, nil];
        [argvStrings addObjectsFromArray:args ?: @[]];
    } else {
        [argvStrings addObjectsFromArray:args ?: @[]];
    }
    char **argv = calloc(argvStrings.count + 1, sizeof(char *));
    for (NSUInteger i = 0; i < argvStrings.count; i++) {
        argv[i] = (char *)argvStrings[i].fileSystemRepresentation;
    }
    argv[argvStrings.count] = NULL;

    pid_t pid = 0;
    int spawnStatus = posix_spawn(&pid, spawnCommand.fileSystemRepresentation, &actions, NULL, argv, environ);
    free(argv);
    posix_spawn_file_actions_destroy(&actions);
    if (spawnStatus != 0) {
        if (error) *error = [self errorWithCode:12 description:[NSString stringWithFormat:@"تعذر تشغيل أداة الأرشفة (errno=%d)", spawnStatus]];
        return NO;
    }

    int waitStatus = 0;
    if (waitpid(pid, &waitStatus, 0) < 0 || !WIFEXITED(waitStatus) || WEXITSTATUS(waitStatus) != 0) {
        if (error) *error = [self errorWithCode:13 description:[NSString stringWithFormat:@"فشلت عملية إنشاء ملف IPA (exit=%d)", WIFEXITED(waitStatus) ? WEXITSTATUS(waitStatus) : -1]];
        return NO;
    }
    return YES;
}

- (void)exportApplicationAtPath:(NSString *)bundlePath
                  suggestedName:(NSString *)suggestedName
                     completion:(IPAExportCompletion)completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *error = nil;
        NSString *workDirectory = nil;
        NSURL *resultURL = nil;

        @try {
            if (bundlePath.length == 0 || ![self isDirectoryWithoutSymlinkAtPath:bundlePath]) {
                error = [self errorWithCode:1 description:@"مسار التطبيق غير صالح أو غير متاح للقراءة"];
            }

            NSString *infoPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
            NSDictionary *info = error ? nil : [NSDictionary dictionaryWithContentsOfFile:infoPath];
            NSString *executableName = [info[@"CFBundleExecutable"] isKindOfClass:[NSString class]] ? info[@"CFBundleExecutable"] : nil;
            if (!error && (info.count == 0 || executableName.length == 0)) {
                error = [self errorWithCode:2 description:@"Info.plist أو اسم executable غير صالح"];
            }

            NSString *executablePath = executableName.length > 0 ? [bundlePath stringByAppendingPathComponent:executableName] : nil;
            if (!error && (!executablePath.length || ![fm isReadableFileAtPath:executablePath])) {
                error = [self errorWithCode:3 description:@"ملف executable الرئيسي غير موجود أو غير قابل للقراءة"];
            }

            if (!error && ![fm isExecutableFileAtPath:self.zipPath]) {
                error = [self errorWithCode:4 description:@"أداة zip غير مثبتة؛ لا يمكن إنشاء IPA"];
            }

            if (!error) {
                NSString *uuid = [NSUUID UUID].UUIDString;
                workDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"IPAExport-%@", uuid]];
                NSString *payloadDirectory = [workDirectory stringByAppendingPathComponent:@"Payload"];
                if (![fm createDirectoryAtPath:payloadDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
                    if (!error) error = [self errorWithCode:5 description:@"تعذر إنشاء مساحة مؤقتة للتصدير"];
                }

                NSString *bundleName = bundlePath.lastPathComponent;
                NSString *copiedBundle = [payloadDirectory stringByAppendingPathComponent:bundleName];
                if (!error) {
                    // Copy only the selected bundle; no files outside it are included.
                    BOOL copied = [self runCommand:self.cpPath
                                              args:@[@"-Rp", bundlePath, copiedBundle]
                                  workingDirectory:nil
                                              error:&error];
                    if (!copied && !error) error = [self errorWithCode:6 description:@"فشل نسخ التطبيق إلى مساحة التصدير"];
                    if (!copied && [fm fileExistsAtPath:copiedBundle]) [fm removeItemAtPath:copiedBundle error:nil];
                }

                NSString *copiedInfoPath = [copiedBundle stringByAppendingPathComponent:@"Info.plist"];
                NSString *copiedExecutablePath = executableName.length > 0 ? [copiedBundle stringByAppendingPathComponent:executableName] : nil;
                if (!error && (![fm fileExistsAtPath:copiedInfoPath] || ![fm isReadableFileAtPath:copiedExecutablePath])) {
                    error = [self errorWithCode:7 description:@"فشل التحقق من النسخة قبل إنشاء IPA"];
                }

                NSString *safeName = suggestedName.length > 0 ? suggestedName : (info[@"CFBundleIdentifier"] ?: bundleName.stringByDeletingPathExtension);
                safeName = [safeName stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
                safeName = [safeName stringByReplacingOccurrencesOfString:@":" withString:@"-"];
                safeName = [safeName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (safeName.length == 0) safeName = @"Application";
                NSString *outputName = [safeName.pathExtension.lowercaseString isEqualToString:@"ipa"] ? safeName : [safeName stringByAppendingPathExtension:@"ipa"];
                NSString *outputPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", uuid, outputName]];

                if (!error) {
                    BOOL zipped = [self runCommand:self.zipPath
                                              args:@[@"-qry", outputPath, @"Payload"]
                                  workingDirectory:workDirectory
                                              error:&error];
                    NSDictionary *attrs = [fm attributesOfItemAtPath:outputPath error:nil];
                    if (!zipped || ![fm isReadableFileAtPath:outputPath] || [attrs[@"NSFileSize"] unsignedLongLongValue] < 22) {
                        if (!error) error = [self errorWithCode:8 description:@"تم إنشاء أرشيف غير صالح أو فارغ"];
                    } else {
                        resultURL = [NSURL fileURLWithPath:outputPath];
                    }
                }
            }
        } @catch (NSException *exception) {
            error = [self errorWithCode:9 description:[NSString stringWithFormat:@"حدث خطأ أثناء استخراج IPA: %@", exception.reason ?: @"غير معروف"]];
        }

        if (workDirectory.length > 0) [fm removeItemAtPath:workDirectory error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(resultURL, error);
        });
    });
}

@end
