//
//  InstallationProvider.h
//  IPAInstallerPro
//
//  Unified Provider Contract v2.0
//  Every provider MUST produce: Execution + Verification + Evidence = Result
//

#import <Foundation/Foundation.h>

@class InstallationResult;
@class OperationLog;

@protocol InstallationProvider <NSObject>
@required
- (NSString *)providerName;
- (NSString *)providerDescription;
- (BOOL)isAvailable;
- (NSInteger)priority;

// Unified install: provider receives OperationLog to record every real operation
- (void)installIPA:(NSString *)ipaPath
      transactionID:(NSString *)txnID
       operationLog:(OperationLog *)opLog
         completion:(void (^)(InstallationResult *result))completion;

- (void)uninstallAppWithBundleID:(NSString *)bundleID
                      completion:(void (^)(BOOL success, NSString *error))completion;
- (void)uninstallAppAtPath:(NSString *)appPath bundleID:(NSString *)bundleID
                      completion:(void (^)(BOOL success, NSString *error))completion;
@end

// ============================================================
// InstallationResult — MUST contain evidence, not just success flag
// ============================================================
@interface InstallationResult : NSObject
@property (nonatomic, assign) BOOL success;
@property (nonatomic, strong) NSString *message;
@property (nonatomic, strong) NSString *detailedOutput;
@property (nonatomic, strong) NSString *bundleID;
@property (nonatomic, strong) NSString *providerName;
@property (nonatomic, strong) NSString *transactionID;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSDictionary *evidence; // stat results, access checks, etc.

+ (InstallationResult *)successResult:(NSString *)msg
                           provider:(NSString *)provider
                        transaction:(NSString *)txnID
                           evidence:(NSDictionary *)evidence;

+ (InstallationResult *)failureResult:(NSString *)msg
                             provider:(NSString *)provider
                          transaction:(NSString *)txnID
                                error:(NSError *)error
                             evidence:(NSDictionary *)evidence;
@end
