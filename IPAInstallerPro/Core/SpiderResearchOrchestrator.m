#import "SpiderResearchOrchestrator.h"
#import "RuntimeEnvironment.h"

@implementation SpiderResearchOrchestrator

+ (instancetype)sharedOrchestrator {
    static SpiderResearchOrchestrator *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (SpiderResearchSession *)buildReadOnlySessionForApplicationAtPath:(NSString *)appPath
                                                            bundleID:(NSString *)bundleID
                                                         trustResult:(TrustBackendResult *)trustResult {
    SpiderResearchSession *session = [[SpiderResearchSession alloc] init];
    session.sessionID = [[NSUUID UUID] UUIDString];
    session.experimentID = @"M1-read-only-trust-evidence";
    session.targetBundleID = bundleID ?: @"";
    session.targetPath = appPath ?: @"";
    session.terminalReason = trustResult.reason ?: @"UNKNOWN";

    RuntimeEnvironment *environment = [RuntimeEnvironment sharedEnvironment];
    NSString *environmentID = [NSString stringWithFormat:@"%@|%@|%@|%@", environment.iosVersion ?: @"UNKNOWN", environment.architecture ?: @"UNKNOWN", environment.jailbreakTypeName ?: @"UNKNOWN", environment.bootstrapPath ?: @"none"];
    SpiderStateCheckpoint *checkpoint = [[SpiderStateCheckpoint alloc] init];
    checkpoint.checkpointID = [[NSUUID UUID] UUIDString];
    checkpoint.name = @"POST-EXECUTION-TRUST-ASSESSMENT";
    checkpoint.environmentID = environmentID;
    checkpoint.state = @"JAILBREAK_RUNTIME";
    checkpoint.environment = @{
        @"iosVersion": environment.iosVersion ?: @"UNKNOWN",
        @"architecture": environment.architecture ?: @"UNKNOWN",
        @"jailbreakType": environment.jailbreakTypeName ?: @"UNKNOWN",
        @"rootless": @(environment.isRootless),
        @"bootstrapPath": environment.bootstrapPath ?: @"UNKNOWN"
    };
    [session addCheckpoint:checkpoint];

    NSDictionary *values = trustResult.evidence ?: @{};
    [values enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        if ([key isEqualToString:@"formattedSummary"] || [key isEqualToString:@"registrationFacts"] || [key isEqualToString:@"provisioningEvidence"] || [key isEqualToString:@"entitlementValues"]) return;
        SpiderResearchEvidence *record = [[SpiderResearchEvidence alloc] init];
        record.evidenceID = [[NSUUID UUID] UUIDString];
        record.sessionID = session.sessionID;
        record.experimentID = session.experimentID;
        record.checkpointID = checkpoint.checkpointID;
        record.domain = @"execution-trust";
        record.key = key;
        record.rawValue = value ?: [NSNull null];
        record.normalizedValue = value ?: [NSNull null];
        record.state = [value isEqual:@"UNKNOWN"] ? SpiderEvidenceStateUnknown : SpiderEvidenceStateObserved;
        record.sourceComponent = trustResult.backendName ?: @"ExperimentalTrustBackend";
        record.sourceMethod = @"evaluateApplicationAtPath:bundleID:";
        record.sourceTarget = appPath ?: @"";
        record.reproducibilityKey = [NSString stringWithFormat:@"%@|%@|%@", bundleID ?: @"", key, environmentID];
        record.limitations = @[];
        record.confidenceBand = record.state == SpiderEvidenceStateUnknown ? @"UNKNOWN" : @"LOW";
        [session addEvidence:record];
    }];

    session.classification = @"SIGNED/REGISTERED/JAILBREAK-LAUNCHABLE: OBSERVED; STOCK-EXECUTABLE/REBOOT-PERSISTENT/PERSISTENT-TRUST: UNKNOWN";
    session.confidenceBand = @"LOW";
    return session;
}

@end
