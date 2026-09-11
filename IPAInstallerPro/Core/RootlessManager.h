#import <Foundation/Foundation.h>

@interface RootlessManager : NSObject
+ (instancetype)sharedManager;
- (NSString *)resolvePath:(NSString *)logicalPath;
- (NSString *)resolveExecutablePath:(NSString *)toolName;
- (BOOL)fileExistsAtLogicalPath:(NSString *)path;
- (BOOL)createDirectoryAtLogicalPath:(NSString *)path error:(NSError **)error;
@end
