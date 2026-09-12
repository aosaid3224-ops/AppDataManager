#import "SpiderResearchSession.h"

@implementation SpiderStateCheckpoint
- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"checkpointID": self.checkpointID ?: @"",
        @"name": self.name ?: @"",
        @"environmentID": self.environmentID ?: @"",
        @"state": self.state ?: @"UNKNOWN",
        @"capturedAt": self.capturedAt ?: [NSDate date],
        @"environment": self.environment ?: @{}
    };
}
@end

@implementation SpiderResearchSession

- (instancetype)init {
    self = [super init];
    if (self) {
        _schemaVersion = @"1";
        _createdAt = [NSDate date];
        _classification = @"UNKNOWN";
        _confidenceBand = @"UNKNOWN";
        _checkpoints = [NSMutableArray array];
        _evidenceRecords = [NSMutableArray array];
    }
    return self;
}

- (void)addCheckpoint:(SpiderStateCheckpoint *)checkpoint {
    if (checkpoint) [self.checkpoints addObject:checkpoint];
}

- (void)addEvidence:(SpiderResearchEvidence *)evidence {
    if (evidence) [self.evidenceRecords addObject:evidence];
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableArray *checkpoints = [NSMutableArray arrayWithCapacity:self.checkpoints.count];
    for (SpiderStateCheckpoint *checkpoint in self.checkpoints) [checkpoints addObject:checkpoint.dictionaryRepresentation];
    NSMutableArray *evidence = [NSMutableArray arrayWithCapacity:self.evidenceRecords.count];
    for (SpiderResearchEvidence *record in self.evidenceRecords) [evidence addObject:record.dictionaryRepresentation];
    return @{
        @"sessionID": self.sessionID ?: @"",
        @"schemaVersion": self.schemaVersion ?: @"1",
        @"experimentID": self.experimentID ?: @"",
        @"targetBundleID": self.targetBundleID ?: @"",
        @"targetPath": self.targetPath ?: @"",
        @"createdAt": self.createdAt ?: [NSDate date],
        @"classification": self.classification ?: @"UNKNOWN",
        @"confidenceBand": self.confidenceBand ?: @"UNKNOWN",
        @"terminalReason": self.terminalReason ?: @"",
        @"checkpoints": checkpoints,
        @"evidenceRecords": evidence
    };
}

- (NSString *)summary {
    return [NSString stringWithFormat:@"Research Session: %@\nExperiment: %@\nCheckpoint: %@\nEvidence Records: %lu\nClassification: %@\nConfidence: %@\nReason: %@",
            self.sessionID ?: @"UNKNOWN", self.experimentID ?: @"UNKNOWN", self.checkpoints.lastObject.name ?: @"UNKNOWN", (unsigned long)self.evidenceRecords.count, self.classification ?: @"UNKNOWN", self.confidenceBand ?: @"UNKNOWN", self.terminalReason ?: @"UNKNOWN"];
}

@end
