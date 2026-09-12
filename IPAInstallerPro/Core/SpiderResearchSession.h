#import <Foundation/Foundation.h>
#import "SpiderResearchEvidence.h"

NS_ASSUME_NONNULL_BEGIN

@interface SpiderStateCheckpoint : NSObject
@property (nonatomic, copy) NSString *checkpointID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *environmentID;
@property (nonatomic, copy) NSString *state;
@property (nonatomic, copy) NSDate *capturedAt;
@property (nonatomic, copy) NSDictionary *environment;
- (NSDictionary *)dictionaryRepresentation;
@end

@interface SpiderResearchSession : NSObject
@property (nonatomic, copy) NSString *sessionID;
@property (nonatomic, copy) NSString *schemaVersion;
@property (nonatomic, copy) NSString *experimentID;
@property (nonatomic, copy) NSString *targetBundleID;
@property (nonatomic, copy) NSString *targetPath;
@property (nonatomic, copy) NSDate *createdAt;
@property (nonatomic, copy) NSString *classification;
@property (nonatomic, copy) NSString *confidenceBand;
@property (nonatomic, copy) NSString *terminalReason;
@property (nonatomic, strong) NSMutableArray<SpiderStateCheckpoint *> *checkpoints;
@property (nonatomic, strong) NSMutableArray<SpiderResearchEvidence *> *evidenceRecords;
- (void)addCheckpoint:(SpiderStateCheckpoint *)checkpoint;
- (void)addEvidence:(SpiderResearchEvidence *)evidence;
- (NSDictionary *)dictionaryRepresentation;
- (NSString *)summary;
@end

NS_ASSUME_NONNULL_END
