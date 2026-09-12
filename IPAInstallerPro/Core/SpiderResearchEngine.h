#import <Foundation/Foundation.h>
#import "SpiderResearchSession.h"
#import "TrustBackend.h"

NS_ASSUME_NONNULL_BEGIN

@interface SpiderResearchStore : NSObject
+ (instancetype)sharedStore;
- (BOOL)saveSession:(SpiderResearchSession *)session error:(NSError **)error;
- (NSDictionary *)aggregateStatisticsForBundleID:(NSString *)bundleID;
@end

@interface SpiderResearchEngine : NSObject
+ (instancetype)sharedEngine;
- (SpiderResearchSession *)runReadOnlySessionForApplicationAtPath:(NSString *)appPath
                                                           bundleID:(NSString *)bundleID
                                                        trustResult:(TrustBackendResult *)trustResult;
@end

NS_ASSUME_NONNULL_END
