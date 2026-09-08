#import "InstallationLogger.h"
#import "JailbreakEnvironment.h"
#import <UIKit/UIKit.h>

static NSString * const kInstallationLogsKey = @"IPAInstallerPro_InstallationLogs_v1";

@interface InstallationLogger ()
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *logs;
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@implementation InstallationLogger

+ (instancetype)sharedLogger {
    static InstallationLogger *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.aosaid.installationlogger", DISPATCH_QUEUE_SERIAL);
        [self loadLogs];
    }
    return self;
}

- (void)loadLogs {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:kInstallationLogsKey];
    _logs = saved ? [saved mutableCopy] : [NSMutableArray array];
}

- (void)saveLogs {
    [[NSUserDefaults standardUserDefaults] setObject:[self.logs copy] forKey:kInstallationLogsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)logEvent:(NSString *)eventType bundleID:(NSString *)bundleID appName:(NSString *)appName details:(NSDictionary *)details {
    dispatch_async(self.queue, ^{
        NSMutableDictionary *log = [NSMutableDictionary dictionary];
        log[@"eventType"] = eventType ?: @"UNKNOWN";
        log[@"bundleID"] = bundleID ?: @"unknown";
        log[@"appName"] = appName ?: @"Unknown";
        log[@"timestamp"] = [[NSDate date] description];
        log[@"iosVersion"] = [[UIDevice currentDevice] systemVersion] ?: @"Unknown";
        log[@"jailbreakType"] = [JailbreakEnvironment sharedEnvironment].jailbreakType ?: @"Unknown";
        if (details) [log addEntriesFromDictionary:details];
        [self.logs addObject:log];
        if (self.logs.count > 100) {
            [self.logs removeObjectsInRange:NSMakeRange(0, self.logs.count - 100)];
        }
        [self saveLogs];
    });
}

- (NSArray<NSDictionary *> *)allInstallationLogs {
    __block NSArray<NSDictionary *> *result;
    dispatch_sync(self.queue, ^{ result = [self.logs copy]; });
    return result;
}

- (NSArray<NSDictionary *> *)installationLogsForBundleID:(NSString *)bundleID {
    return [[self allInstallationLogs] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"bundleID == %@", bundleID]];
}

- (NSDictionary *)lastInstallationLogForBundleID:(NSString *)bundleID {
    NSArray *logs = [self installationLogsForBundleID:bundleID];
    return logs.lastObject;
}

- (void)clearAllLogs {
    dispatch_async(self.queue, ^{ [self.logs removeAllObjects]; [self saveLogs]; });
}

- (void)clearLogsForBundleID:(NSString *)bundleID {
    dispatch_async(self.queue, ^{
        [self.logs filterUsingPredicate:[NSPredicate predicateWithFormat:@"bundleID != %@", bundleID]];
        [self saveLogs];
    });
}

- (NSString *)generateInstallationReport {
    NSMutableString *report = [NSMutableString string];
    [report appendString:@"📦 IPA Installer Pro — Installation Logs\n"];
    [report appendString:@"=====================================\n\n"];
    for (NSDictionary *log in [self allInstallationLogs]) {
        [report appendFormat:@"[%@] %@ — %@\n", log[@"eventType"], log[@"timestamp"], log[@"appName"]];
    }
    return report;
}

@end
