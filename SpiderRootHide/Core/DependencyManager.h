#import <Foundation/Foundation.h>

@interface Dependency : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *packageID;
@property (nonatomic, strong) NSString *descriptionText;
@property (nonatomic, strong) NSString *repoURL;
@property (nonatomic, assign) BOOL isInstalled;
@property (nonatomic, strong) NSString *version;
@end

@interface DependencyManager : NSObject
+ (instancetype)sharedManager;
- (NSArray<Dependency *> *)allDependencies;
- (Dependency *)dependencyForPackageID:(NSString *)packageID;
- (BOOL)isPackageInstalled:(NSString *)packageID;
- (BOOL)isBinaryAvailable:(NSString *)binaryName;
- (void)refreshStatus;
@end
