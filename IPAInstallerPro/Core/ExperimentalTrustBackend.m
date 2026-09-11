#import "ExperimentalTrustBackend.h"
#import "SignatureAnalyzer.h"
#import "MachOAnalyzer.h"
#import "ForensicRegistrationProbe.h"
#import "RuntimeEnvironment.h"

@implementation ExperimentalTrustBackend

- (NSString *)backendName { return @"ExperimentalTrustBackend"; }

- (TrustBackendResult *)evaluateApplicationAtPath:(NSString *)appPath bundleID:(NSString *)bundleID {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath] ?: @{};
    NSString *executableName = info[@"CFBundleExecutable"];
    NSString *executablePath = executableName.length ? [appPath stringByAppendingPathComponent:executableName] : @"";

    BOOL appExists = appPath.length && [fm fileExistsAtPath:appPath isDirectory:NULL];
    BOOL executableExists = executablePath.length && [fm isExecutableFileAtPath:executablePath];
    SignatureInfo *signature = executableExists ? [[SignatureAnalyzer sharedAnalyzer] analyzeSignatureAtPath:executablePath] : nil;
    MachOAnalysisResult *machO = executableExists ? [[MachOAnalyzer sharedAnalyzer] analyzeFileAtPath:executablePath] : nil;
    NSDictionary *entitlements = executableExists ? [[SignatureAnalyzer sharedAnalyzer] extractEntitlementsAtPath:executablePath] : @{};

    NSDictionary *registration = bundleID.length ? [[ForensicRegistrationProbe sharedProbe] launchServicesFactsForBundleID:bundleID] : @{};
    RuntimeEnvironment *runtime = [RuntimeEnvironment sharedEnvironment];
    BOOL jailbreakRuntime = runtime.bootstrapPath.length > 0 || runtime.jailbreakType != SpiderJailbreakTypeUnknown;

    NSString *profilePath = [appPath stringByAppendingPathComponent:@"embedded.mobileprovision"];
    BOOL profilePresent = [fm fileExistsAtPath:profilePath];
    NSString *signatureEvidence = signature ? (signature.isSigned ? @"PRESENT" : @"ABSENT") : @"UNKNOWN";
    NSString *registrationEvidence = registration.count ? ([registration[@"registered"] boolValue] ? @"PRESENT" : @"ABSENT") : @"UNKNOWN";
    NSString *runtimeEvidence = jailbreakRuntime ? @"JAILBREAK_RUNTIME_PRESENT" : @"UNKNOWN";
    NSString *stockEvidence = @"UNKNOWN";
    NSString *persistentEvidence = @"UNKNOWN";

    NSMutableDictionary *evidence = [NSMutableDictionary dictionary];
    evidence[@"applicationPath"] = appPath ?: @"";
    evidence[@"applicationExists"] = @(appExists);
    evidence[@"bundleID"] = bundleID ?: @"";
    evidence[@"executable"] = executableName ?: @"UNKNOWN";
    evidence[@"executablePath"] = executablePath ?: @"";
    evidence[@"executableExists"] = @(executableExists);
    evidence[@"signatureEvidence"] = signatureEvidence;
    evidence[@"registrationEvidence"] = registrationEvidence;
    evidence[@"runtimeEvidence"] = runtimeEvidence;
    evidence[@"stockExecutionEvidence"] = stockEvidence;
    evidence[@"persistentExecutionEvidence"] = persistentEvidence;
    evidence[@"profilePresent"] = @(profilePresent);
    evidence[@"teamIdentifier"] = signature.teamID ?: @"UNKNOWN";
    evidence[@"signatureIdentifier"] = signature.identifier ?: @"UNKNOWN";
    evidence[@"signatureAuthority"] = signature.authority ?: @"UNKNOWN";
    evidence[@"signatureStatus"] = signature.signatureStatus ?: @"UNKNOWN";
    evidence[@"isAdHocSigned"] = signature ? @(signature.isAdHocSigned) : @"UNKNOWN";
    evidence[@"entitlementsPresent"] = @(entitlements.count > 0);
    evidence[@"machOType"] = machO.machOTypeName ?: @"UNKNOWN";
    evidence[@"architecture"] = machO.slices.firstObject.architectureName ?: @"UNKNOWN";
    evidence[@"hasCodeSignature"] = machO ? @(machO.hasCodeSignature) : @"UNKNOWN";
    evidence[@"nestedCodeEvidence"] = @"NOT_EVALUATED";
    evidence[@"jailbreakBootstrapPath"] = runtime.bootstrapPath ?: @"UNKNOWN";
    evidence[@"registrationFacts"] = registration ?: @{};

    NSString *reason = nil;
    if (!appExists || !executableExists) {
        reason = @"Application or executable could not be inspected";
    } else if (!profilePresent) {
        reason = @"No embedded provisioning profile was found; Stock Execution evidence remains UNKNOWN";
    } else {
        reason = @"Evidence collected; presence of a profile alone does not prove Stock Execution Trust";
    }

    NSString *output = [NSString stringWithFormat:
                        @"[EXECUTION TRUST]\nBackend: %@\nSignature Evidence: %@\nRegistration Evidence: %@\nRuntime Evidence: %@\nStock Evidence: %@\nPersistent Evidence: %@\nTrust State: UNKNOWN\nReason: %@",
                        self.backendName, signatureEvidence, registrationEvidence, runtimeEvidence, stockEvidence, persistentEvidence, reason];
    evidence[@"formattedSummary"] = output;

    return [TrustBackendResult resultWithState:TrustBackendStateUnknown
                                   backendName:self.backendName
                                     available:YES
                          supportedCapabilities:@[@"read-only signature evidence", @"read-only Mach-O evidence", @"read-only registration evidence", @"read-only runtime evidence"]
                                         reason:reason
                             verificationResult:NO
                    persistentExecutionAvailable:NO
                                        evidence:evidence];
}

@end
