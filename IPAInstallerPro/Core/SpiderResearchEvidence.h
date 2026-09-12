#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SpiderEvidenceState) {
    SpiderEvidenceStateObserved = 0,
    SpiderEvidenceStateSupported,
    SpiderEvidenceStateReproducible,
    SpiderEvidenceStateStronglySupported,
    SpiderEvidenceStateProven,
    SpiderEvidenceStateUnknown,
    SpiderEvidenceStateContradicted
};

FOUNDATION_EXPORT NSString *SpiderEvidenceStateName(SpiderEvidenceState state);

@interface SpiderResearchEvidence : NSObject
@property (nonatomic, copy) NSString *evidenceID;
@property (nonatomic, copy) NSString *sessionID;
@property (nonatomic, copy) NSString *experimentID;
@property (nonatomic, copy) NSString *checkpointID;
@property (nonatomic, copy) NSString *domain;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, strong) id rawValue;
@property (nonatomic, strong) id normalizedValue;
@property (nonatomic, assign) SpiderEvidenceState state;
@property (nonatomic, copy) NSString *sourceComponent;
@property (nonatomic, copy) NSString *sourceMethod;
@property (nonatomic, copy) NSString *sourceTarget;
@property (nonatomic, copy) NSString *reproducibilityKey;
@property (nonatomic, copy) NSArray<NSString *> *limitations;
@property (nonatomic, copy) NSString *confidenceBand;
- (NSDictionary *)dictionaryRepresentation;
@end

NS_ASSUME_NONNULL_END
