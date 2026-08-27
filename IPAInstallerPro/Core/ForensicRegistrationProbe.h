//
// ForensicRegistrationProbe.h
// IPA Installer Pro — Diagnostic/Forensic Mode
//
// Read-only registration evidence. It never calls uicache -p/-a/-r and never
// changes LaunchServices state.
//

#import <Foundation/Foundation.h>
@class OperationLog;

@interface ForensicRegistrationProbe : NSObject
+ (instancetype)sharedProbe;

/// Queries uicache and LaunchServices for one Bundle ID. The returned dictionary
/// contains raw command evidence and does not infer install success from one
/// source alone.
- (NSDictionary *)probeBundleID:(NSString *)bundleID
                   transactionID:(NSString *)transactionID
                    operationLog:(OperationLog *)operationLog
                    logicalPath:(NSString *)logicalPath
                   resolvedPath:(NSString *)resolvedPath;
@end
