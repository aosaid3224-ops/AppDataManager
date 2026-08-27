//
// ForensicInstallationPipeline.h
// IPA Installer Pro — Diagnostic/Forensic Mode
//
// This API is intentionally separate from InstallationEngine. It is not called
// by the production UI and is not a replacement provider yet. It runs one
// diagnostic transaction, observes actual records, and returns evidence.
//

#import <Foundation/Foundation.h>
@class ForensicTransactionReport;
@class InstallationResult;
@class RuntimeDiagnosticsResult;

@interface ForensicInstallationPipeline : NSObject
+ (instancetype)sharedPipeline;

/// Runs one diagnostic installation using the existing direct provider while
/// passively capturing every OperationLog event. If launchAfterInstall is YES,
/// the existing RuntimeDiagnostics observer is invoked only after registration
/// evidence has been collected.
- (void)runIPAAtPath:(NSString *)ipaPath
   launchAfterInstall:(BOOL)launchAfterInstall
           completion:(void (^)(ForensicTransactionReport *report,
                                InstallationResult *installationResult,
                                RuntimeDiagnosticsResult *runtimeResult))completion;
@end
