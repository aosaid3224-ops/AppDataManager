#import <Foundation/Foundation.h>

@interface InstallationLogger : NSObject
+ (instancetype)sharedLogger;
- (void)logEvent:(NSString *)eventType bundleID:(NSString *)bundleID appName:(NSString *)appName details:(NSDictionary *)details;
- (NSArray<NSDictionary *> *)allInstallationLogs;
- (NSArray<NSDictionary *> *)installationLogsForBundleID:(NSString *)bundleID;
- (NSDictionary *)lastInstallationLogForBundleID:(NSString *)bundleID;
- (void)clearAllLogs;
- (void)clearLogsForBundleID:(NSString *)bundleID;
- (NSString *)generateInstallationReport;
@end
