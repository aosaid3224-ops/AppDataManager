#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TrustBackendState) {
    TrustBackendStateUnavailable = 0,
    TrustBackendStateAvailable,
    TrustBackendStatePrepared,
    TrustBackendStateVerified,
    TrustBackendStateUnsupported,
    TrustBackendStateUnknown,
    TrustBackendStateError
};

FOUNDATION_EXPORT NSString *TrustBackendStateName(TrustBackendState state);

@interface TrustBackendResult : NSObject
@property (nonatomic, assign) TrustBackendState state;
@property (nonatomic, copy) NSString *backendName;
@property (nonatomic, assign) BOOL available;
@property (nonatomic, copy) NSArray<NSString *> *supportedCapabilities;
@property (nonatomic, copy) NSString *reason;
@property (nonatomic, assign) BOOL verificationResult;
@property (nonatomic, assign) BOOL persistentExecutionAvailable;
@property (nonatomic, copy) NSDictionary *evidence;
+ (instancetype)resultWithState:(TrustBackendState)state
                    backendName:(NSString *)backendName
                      available:(BOOL)available
           supportedCapabilities:(NSArray<NSString *> *)capabilities
                          reason:(NSString *)reason
              verificationResult:(BOOL)verificationResult
     persistentExecutionAvailable:(BOOL)persistentExecutionAvailable
                         evidence:(NSDictionary *)evidence;
@end

@protocol TrustBackend <NSObject>
@property (nonatomic, readonly, copy) NSString *backendName;
- (TrustBackendResult *)evaluateApplicationAtPath:(NSString *)appPath
                                         bundleID:(NSString *)bundleID;
@end

NS_ASSUME_NONNULL_END
