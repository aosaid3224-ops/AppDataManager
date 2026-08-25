#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MachORPathRepair : NSObject

+ (instancetype)sharedRepair;

/// Repairs only clearly non-portable build-host LC_RPATH values in an app bundle.
/// Returns NO when an unsafe rpath is detected but cannot be represented safely
/// in the existing load-command slot. No bundle identifier is special-cased.
- (BOOL)repairAppAtPath:(NSString *)appPath
          changedPaths:(NSArray<NSString *> * _Nullable * _Nullable)changedPaths
                 error:(NSString * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
