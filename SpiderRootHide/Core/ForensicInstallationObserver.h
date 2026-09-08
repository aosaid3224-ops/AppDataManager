//
// ForensicInstallationObserver.h
// IPA Installer Pro — Diagnostic/Forensic Mode
//
// Passive observer for an existing transaction. It does not start an install,
// invoke signing, invoke uicache, or alter production behavior.
//

#import <Foundation/Foundation.h>
@class ForensicTransactionReport;
@class OperationLog;

@interface ForensicInstallationObserver : NSObject

/// Start passive observation for an already-created transaction.
/// The observer listens to OperationLog notifications and records filesystem
/// snapshots around each observed record.
- (void)beginObservingTransaction:(NSString *)transactionID
                          ipaPath:(NSString *)ipaPath
                         bundleID:(NSString *)bundleID
                         operationLog:(OperationLog *)operationLog;

/// Stop observation and build a forensic report from all records observed so far.
/// No install, signing, registration, or cleanup operation is performed here.
- (ForensicTransactionReport *)finishObservation;

@property (nonatomic, assign, readonly, getter=isObserving) BOOL observing;
@property (nonatomic, strong, readonly) ForensicTransactionReport *currentReport;
@end
