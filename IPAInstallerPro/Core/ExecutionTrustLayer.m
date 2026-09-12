#import "ExecutionTrustLayer.h"
#import "OperationLog.h"
#import "ExperimentalTrustBackend.h"
#import "SpiderResearchEngine.h"

@interface ExecutionTrustLayer ()
@property (nonatomic, strong, readwrite, nullable) id<TrustBackend> backend;
@end

@implementation ExecutionTrustLayer

+ (instancetype)sharedLayer {
    static ExecutionTrustLayer *sharedLayer;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // The default backend is read-only and experimental. It collects
        // measurable evidence but never claims Stock Trust or persistence.
        sharedLayer = [[self alloc] initWithBackend:[[ExperimentalTrustBackend alloc] init]];
    });
    return sharedLayer;
}

- (instancetype)initWithBackend:(id<TrustBackend>)backend {
    self = [super init];
    if (self) _backend = backend;
    return self;
}

- (TrustBackendResult *)evaluateApplicationAtPath:(NSString *)appPath
                                         bundleID:(NSString *)bundleID
                                      operationLog:(OperationLog *)operationLog
                                     transactionID:(NSString *)transactionID {
    TrustBackendResult *result = nil;
    if (self.backend) {
        @try {
            result = [self.backend evaluateApplicationAtPath:appPath ?: @"" bundleID:bundleID ?: @""];
        } @catch (NSException *exception) {
            result = [TrustBackendResult resultWithState:TrustBackendStateError
                                             backendName:self.backend.backendName ?: @"UNKNOWN"
                                               available:YES
                                    supportedCapabilities:@[]
                                                   reason:[NSString stringWithFormat:@"Trust backend raised an exception: %@", exception.reason ?: @"UNKNOWN"]
                                       verificationResult:NO
                              persistentExecutionAvailable:NO
                                                  evidence:@{}];
        }
    }
    if (!result) {
        result = [TrustBackendResult resultWithState:TrustBackendStateUnavailable
                                         backendName:@"NONE"
                                           available:NO
                                supportedCapabilities:@[]
                                               reason:@"No real Stock Execution Trust Backend is available in this environment"
                                   verificationResult:NO
                          persistentExecutionAvailable:NO
                                              evidence:@{ @"appPath": appPath ?: @"", @"bundleID": bundleID ?: @"" }];
    }

    SpiderResearchSession *researchSession = nil;
    @try {
        researchSession = [[SpiderResearchEngine sharedEngine] runReadOnlySessionForApplicationAtPath:appPath bundleID:bundleID trustResult:result];
    } @catch (NSException *exception) {
        NSLog(@"[SpiderResearchEngine] Research session failed without affecting installation: %@", exception.reason ?: @"UNKNOWN");
    }
    if (!researchSession) {
        researchSession = [[SpiderResearchSession alloc] init];
        researchSession.sessionID = [[NSUUID UUID] UUIDString];
        researchSession.experimentID = @"M1-read-only-trust-evidence";
        researchSession.targetBundleID = bundleID ?: @"";
        researchSession.targetPath = appPath ?: @"";
        researchSession.classification = @"UNKNOWN";
        researchSession.confidenceBand = @"UNKNOWN";
        researchSession.terminalReason = @"Research engine unavailable; installation result unchanged";
    }
    if (operationLog && transactionID.length) {
        NSString *recordID = [operationLog beginPhase:OperationPhaseVerify
                                             operation:@"execution trust assessment"
                                                target:bundleID ?: @""
                                                 input:appPath ?: @""
                                         transactionID:transactionID];
        NSString *availability = result.available ? @"AVAILABLE" : @"NOT AVAILABLE";
        NSString *persistent = result.persistentExecutionAvailable ? @"YES" : @"NOT AVAILABLE";
        NSString *output = [NSString stringWithFormat:@"Persistent Execution: %@\nTrust State: %@\nBackend: %@\n%@",
                            persistent, TrustBackendStateName(result.state), result.backendName ?: @"UNKNOWN", researchSession.summary];
        NSMutableDictionary *context = [NSMutableDictionary dictionaryWithDictionary:result.evidence ?: @{}];
        context[@"availability"] = availability;
        context[@"backendName"] = result.backendName ?: @"UNKNOWN";
        context[@"supportedCapabilities"] = result.supportedCapabilities ?: @[];
        context[@"trustState"] = TrustBackendStateName(result.state);
        context[@"verificationResult"] = @(result.verificationResult);
        context[@"persistentExecutionAvailable"] = @(result.persistentExecutionAvailable);
        context[@"researchSession"] = researchSession.dictionaryRepresentation;
        [operationLog endPhase:recordID
                       exitCode:0
                      rawOutput:output
                       rawError:result.reason ?: @"UNKNOWN"
                   verification:result.persistentExecutionAvailable ? @"Stock Execution Trust verified" : @"Stock Execution Trust not verified; installation result is unchanged"
                       verified:NO
                       duration:0
                        context:context];
    }
    return result;
}

@end
