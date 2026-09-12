#import "SpiderResearchEngine.h"
#import "SpiderResearchOrchestrator.h"

@interface SpiderResearchStore ()
@property (nonatomic, copy) NSString *directoryPath;
@end

static id SpiderResearchPlistSafeValue(id value) {
    if (!value || value == [NSNull null]) return @"UNKNOWN";
    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSDate class]] || [value isKindOfClass:[NSData class]]) return value;
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *safe = [NSMutableArray arrayWithCapacity:[value count]];
        for (id item in value) [safe addObject:SpiderResearchPlistSafeValue(item)];
        return safe;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *safe = [NSMutableDictionary dictionaryWithCapacity:[value count]];
        for (id key in value) {
            if (![key isKindOfClass:[NSString class]]) continue;
            safe[key] = SpiderResearchPlistSafeValue(value[key]);
        }
        return safe;
    }
    return [value description] ?: @"UNKNOWN";
}

@implementation SpiderResearchStore

+ (instancetype)sharedStore {
    static SpiderResearchStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ store = [[self alloc] init]; });
    return store;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *root = library.firstObject ?: NSTemporaryDirectory();
        _directoryPath = [root stringByAppendingPathComponent:@"Spider/ResearchSessions"];
        [[NSFileManager defaultManager] createDirectoryAtPath:_directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return self;
}

- (BOOL)saveSession:(SpiderResearchSession *)session error:(NSError **)error {
    if (!session.sessionID.length) return NO;
    NSString *path = [self.directoryPath stringByAppendingPathComponent:[session.sessionID stringByAppendingPathExtension:@"plist"]];
    NSDictionary *safeDictionary = SpiderResearchPlistSafeValue(session.dictionaryRepresentation);
    if (![NSPropertyListSerialization propertyList:safeDictionary isValidForFormat:NSPropertyListBinaryFormat]) {
        if (error) *error = [NSError errorWithDomain:@"SpiderResearchStore" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Research session contains no valid property-list representation"}];
        return NO;
    }
    BOOL saved = [safeDictionary writeToFile:path atomically:YES];
    if (!saved && error) *error = [NSError errorWithDomain:@"SpiderResearchStore" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Research session persistence failed"}];
    return saved;
}

- (NSDictionary *)aggregateStatisticsForBundleID:(NSString *)bundleID {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.directoryPath error:nil] ?: @[];
    NSUInteger sessions = 0, evidence = 0, observed = 0, unknown = 0, contradictions = 0;
    NSMutableSet *environments = [NSMutableSet set];
    NSMutableDictionary *classificationCounts = [NSMutableDictionary dictionary];
    for (NSString *file in files) {
        if (![file.pathExtension isEqualToString:@"plist"]) continue;
        NSDictionary *session = [NSDictionary dictionaryWithContentsOfFile:[self.directoryPath stringByAppendingPathComponent:file]];
        if (![session isKindOfClass:[NSDictionary class]] || ![session[@"targetBundleID"] isEqual:bundleID]) continue;
        sessions++;
        NSString *classification = session[@"classification"] ?: @"UNKNOWN";
        classificationCounts[classification] = @([classificationCounts[classification] unsignedIntegerValue] + 1);
        for (NSDictionary *checkpoint in session[@"checkpoints"] ?: @[]) {
            if (checkpoint[@"environmentID"]) [environments addObject:checkpoint[@"environmentID"]];
        }
        for (NSDictionary *record in session[@"evidenceRecords"] ?: @[]) {
            evidence++;
            NSString *state = record[@"state"] ?: @"UNKNOWN";
            if ([state isEqualToString:@"UNKNOWN"]) unknown++;
            else if ([state isEqualToString:@"CONTRADICTED"]) contradictions++;
            else observed++;
        }
    }
    return @{
        @"bundleID": bundleID ?: @"",
        @"sessionCount": @(sessions),
        @"uniqueEnvironmentCount": @(environments.count),
        @"evidenceCount": @(evidence),
        @"observedEvidenceCount": @(observed),
        @"unknownEvidenceCount": @(unknown),
        @"contradictedEvidenceCount": @(contradictions),
        @"observedEvidenceRatio": @(evidence ? (double)observed / (double)evidence : 0.0),
        @"classificationCounts": classificationCounts
    };
}

@end

@implementation SpiderResearchEngine

+ (instancetype)sharedEngine {
    static SpiderResearchEngine *engine;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ engine = [[self alloc] init]; });
    return engine;
}

- (SpiderResearchSession *)runReadOnlySessionForApplicationAtPath:(NSString *)appPath
                                                           bundleID:(NSString *)bundleID
                                                        trustResult:(TrustBackendResult *)trustResult {
    SpiderResearchSession *session = [[SpiderResearchOrchestrator sharedOrchestrator] buildReadOnlySessionForApplicationAtPath:appPath bundleID:bundleID trustResult:trustResult];
    [session.experiments addObjectsFromArray:@[
        @{ @"experimentID": @"E1-artifact-evidence", @"state": @"OBSERVED", @"readOnly": @YES },
        @{ @"experimentID": @"E2-runtime-environment", @"state": @"OBSERVED", @"readOnly": @YES },
        @{ @"experimentID": @"E3-jailbreak-launchability", @"state": @"OBSERVED", @"readOnly": @YES },
        @{ @"experimentID": @"E4-stock-execution", @"state": @"AWAITING_EXTERNAL_OBSERVATION", @"readOnly": @YES },
        @{ @"experimentID": @"E5-reboot-persistence", @"state": @"AWAITING_EXTERNAL_OBSERVATION", @"readOnly": @YES }
    ]];

    for (SpiderResearchEvidence *record in session.evidenceRecords) {
        [session.differentialResults addObject:@{
            @"checkpointID": record.checkpointID ?: @"",
            @"key": record.key ?: @"",
            @"change": record.state == SpiderEvidenceStateUnknown ? @"UNAVAILABLE" : @"OBSERVED_AT_CHECKPOINT",
            @"baseline": @"NOT_CAPTURED_IN_M1",
            @"current": record.normalizedValue ?: [NSNull null]
        }];
    }

    [session.candidateMechanisms addObject:@{
        @"mechanismID": @"candidate-stock-execution-trust",
        @"status": @"HYPOTHESIS",
        @"supportingEvidence": @[],
        @"contradictingEvidence": @[],
        @"requiredObservation": @"A direct stock-boot launch observation is required",
        @"confidence": @"UNKNOWN"
    }];

    NSUInteger total = session.evidenceRecords.count, observed = 0, unknown = 0, contradicted = 0;
    for (SpiderResearchEvidence *record in session.evidenceRecords) {
        if (record.state == SpiderEvidenceStateUnknown) unknown++;
        else if (record.state == SpiderEvidenceStateContradicted) contradicted++;
        else observed++;
    }
    session.statistics = @{
        @"evidenceCount": @(total),
        @"observedEvidenceCount": @(observed),
        @"unknownEvidenceCount": @(unknown),
        @"contradictedEvidenceCount": @(contradicted),
        @"observedEvidenceRatio": @(total ? (double)observed / (double)total : 0.0),
        @"unknownEvidenceRatio": @(total ? (double)unknown / (double)total : 0.0),
        @"reproducibleEvidenceCount": @0,
        @"provenStockExecution": @NO,
        @"provenRebootPersistence": @NO,
        @"classificationPolicy": @"Conservative: UNKNOWN is never promoted to VERIFIED"
    };
    NSError *saveError = nil;
    BOOL saved = [[SpiderResearchStore sharedStore] saveSession:session error:&saveError];
    NSMutableDictionary *statistics = [session.statistics mutableCopy];
    [statistics addEntriesFromDictionary:@{
        @"persisted": @(saved),
        @"aggregate": [[SpiderResearchStore sharedStore] aggregateStatisticsForBundleID:bundleID] ?: @{},
        @"persistenceError": saveError.localizedDescription ?: @""
    }];
    session.statistics = statistics;
    NSError *finalSaveError = nil;
    BOOL finalSaved = [[SpiderResearchStore sharedStore] saveSession:session error:&finalSaveError];
    session.statistics = [session.statistics mutableCopy];
    NSMutableDictionary *finalStatistics = [session.statistics mutableCopy];
    finalStatistics[@"persistedFinal"] = @(finalSaved);
    if (finalSaveError) finalStatistics[@"finalPersistenceError"] = finalSaveError.localizedDescription;
    session.statistics = finalStatistics;
    [[SpiderResearchStore sharedStore] saveSession:session error:nil];
    return session;
}

@end
