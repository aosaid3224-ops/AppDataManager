#import "SpiderResearchEvidence.h"

NSString *SpiderEvidenceStateName(SpiderEvidenceState state) {
    switch (state) {
        case SpiderEvidenceStateObserved: return @"OBSERVED";
        case SpiderEvidenceStateSupported: return @"SUPPORTED";
        case SpiderEvidenceStateReproducible: return @"REPRODUCIBLE";
        case SpiderEvidenceStateStronglySupported: return @"STRONGLY_SUPPORTED";
        case SpiderEvidenceStateProven: return @"PROVEN";
        case SpiderEvidenceStateUnknown: return @"UNKNOWN";
        case SpiderEvidenceStateContradicted: return @"CONTRADICTED";
    }
    return @"UNKNOWN";
}

@implementation SpiderResearchEvidence

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"evidenceID": self.evidenceID ?: @"",
        @"sessionID": self.sessionID ?: @"",
        @"experimentID": self.experimentID ?: @"",
        @"checkpointID": self.checkpointID ?: @"",
        @"domain": self.domain ?: @"",
        @"key": self.key ?: @"",
        @"rawValue": self.rawValue ?: [NSNull null],
        @"normalizedValue": self.normalizedValue ?: [NSNull null],
        @"state": SpiderEvidenceStateName(self.state),
        @"sourceComponent": self.sourceComponent ?: @"",
        @"sourceMethod": self.sourceMethod ?: @"",
        @"sourceTarget": self.sourceTarget ?: @"",
        @"reproducibilityKey": self.reproducibilityKey ?: @"",
        @"limitations": self.limitations ?: @[],
        @"confidenceBand": self.confidenceBand ?: @"UNKNOWN"
    };
}

@end
