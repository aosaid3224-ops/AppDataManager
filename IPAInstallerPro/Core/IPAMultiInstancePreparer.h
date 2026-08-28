#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^IPAMultiInstancePreparationCompletion)(NSString * _Nullable preparedIPAPath, NSString * _Nullable instanceBundleID, NSString * _Nullable instanceName, NSError * _Nullable error);

@interface IPAMultiInstancePreparer : NSObject
+ (instancetype)sharedPreparer;
- (void)prepareIPAAtPath:(NSString *)ipaPath
            displayName:(NSString *)displayName
             completion:(IPAMultiInstancePreparationCompletion)completion;
@end

NS_ASSUME_NONNULL_END
