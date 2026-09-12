#import <Foundation/Foundation.h>
#import "SpiderResearchSession.h"
#import "TrustBackend.h"

NS_ASSUME_NONNULL_BEGIN

@interface SpiderResearchOrchestrator : NSObject
+ (instancetype)sharedOrchestrator;
- (SpiderResearchSession *)buildReadOnlySessionForApplicationAtPath:(NSString *)appPath
                                                            bundleID:(NSString *)bundleID
                                                            trustResult:(TrustBackendResult *)trustResult;
@end

NS_ASSUME_NONNULL_END
