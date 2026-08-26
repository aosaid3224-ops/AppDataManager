//
// InstallationEngine.h
// IPA Installer Pro
//
// v2.1 — Standalone engine with OperationLog as source of truth
//

#import <Foundation/Foundation.h>
#import "InstallationProvider.h"

typedef NS_ENUM(NSInteger, InstallationStage) {
    InstallationStageIdle = 0,
    InstallationStagePreparing = 1,
    InstallationStageValidating = 2,
    InstallationStageInstalling = 3,
    InstallationStageRegistering = 4,
    InstallationStageCompleted = 5,
    InstallationStageFailed = 6
};

@interface InstallationEngine : NSObject
+ (instancetype)sharedEngine;

// Provider management
- (NSArray<id<InstallationProvider>> *)availableProviders;
- (id<InstallationProvider>)bestProvider;
- (NSString *)currentProviderName;
- (NSString *)stageDescription:(InstallationStage)stage;

// Main install — OperationLog is created internally, exposed via delegate
- (void)installIPA:(NSString *)ipaPath
     progressBlock:(void (^)(InstallationStage stage, NSString *statusMessage, float progress))progressBlock
        completion:(void (^)(InstallationResult *result))completion;

- (void)uninstallAppWithBundleID:(NSString *)bundleID
                      completion:(void (^)(BOOL success, NSString *error))completion;
- (void)uninstallAppAtPath:(NSString *)appPath bundleID:(NSString *)bundleID
                    completion:(void (^)(BOOL success, NSString *error))completion;


// Transaction state
@property (nonatomic, readonly, assign) BOOL isInstalling;

// Transaction access for UI
- (NSString *)activeTransactionID;
- (NSString *)transactionReport:(NSString *)txnID;
- (OperationLog *)operationLog;

// Prepare transaction ID before installIPA so UI can sync with OperationLog
- (void)prepareTransactionWithID:(NSString *)txnID;

// Clears only an idle/failed transaction marker. It never interrupts a live install.
- (BOOL)resetFailedInstallationState;
@end
