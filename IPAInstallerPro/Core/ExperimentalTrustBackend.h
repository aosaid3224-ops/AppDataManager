#import <Foundation/Foundation.h>
#import "TrustBackend.h"

NS_ASSUME_NONNULL_BEGIN

@interface ExperimentalTrustBackend : NSObject <TrustBackend>
@property (nonatomic, readonly, copy) NSString *backendName;
@end

NS_ASSUME_NONNULL_END
