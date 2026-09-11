#import <Foundation/Foundation.h>
#import "TrustBackend.h"

@class OperationLog;

NS_ASSUME_NONNULL_BEGIN

@interface ExecutionTrustLayer : NSObject
+ (instancetype)sharedLayer;
- (instancetype)initWithBackend:(nullable id<TrustBackend>)backend;
@property (nonatomic, strong, readonly, nullable) id<TrustBackend> backend;
- (TrustBackendResult *)evaluateApplicationAtPath:(NSString *)appPath
                                         bundleID:(NSString *)bundleID
                                      operationLog:(nullable OperationLog *)operationLog
                                     transactionID:(NSString *)transactionID;
@end

NS_ASSUME_NONNULL_END
