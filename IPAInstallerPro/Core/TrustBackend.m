#import "TrustBackend.h"

NSString *TrustBackendStateName(TrustBackendState state) {
    switch (state) {
        case TrustBackendStateUnavailable: return @"Unavailable";
        case TrustBackendStateAvailable: return @"Available";
        case TrustBackendStatePrepared: return @"Prepared";
        case TrustBackendStateVerified: return @"Verified";
        case TrustBackendStateUnsupported: return @"Unsupported";
        case TrustBackendStateUnknown: return @"Unknown";
        case TrustBackendStateError: return @"Error";
    }
    return @"Unknown";
}

@implementation TrustBackendResult

+ (instancetype)resultWithState:(TrustBackendState)state
                    backendName:(NSString *)backendName
                      available:(BOOL)available
           supportedCapabilities:(NSArray<NSString *> *)capabilities
                          reason:(NSString *)reason
              verificationResult:(BOOL)verificationResult
     persistentExecutionAvailable:(BOOL)persistentExecutionAvailable
                         evidence:(NSDictionary *)evidence {
    TrustBackendResult *result = [[self alloc] init];
    result.state = state;
    result.backendName = backendName ?: @"UNKNOWN";
    result.available = available;
    result.supportedCapabilities = capabilities ?: @[];
    result.reason = reason ?: @"UNKNOWN";
    result.verificationResult = verificationResult;
    result.persistentExecutionAvailable = persistentExecutionAvailable;
    result.evidence = evidence ?: @{};
    return result;
}

@end
