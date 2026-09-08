#import <Foundation/Foundation.h>

@interface RootlessManager : NSObject
+ (instancetype)sharedManager;
- (NSString *)resolvePath:(NSString *)logicalPath;
- (BOOL)fileExistsAtLogicalPath:(NSString *)path;
- (BOOL)createDirectoryAtLogicalPath:(NSString *)path error:(NSError **)error;
@end
