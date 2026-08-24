#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PVMediaVaultItem : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *filename;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) NSUInteger byteSize;
+ (nullable instancetype)itemFromDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;
@end

@interface PVMediaVaultStore : NSObject
+ (instancetype)sharedStore;
- (NSArray<PVMediaVaultItem *> *)items;
- (BOOL)importFileAtURL:(NSURL *)sourceURL identifier:(NSString *)identifier type:(NSString *)type originalFilename:(NSString *)originalFilename error:(NSError **)error;
- (BOOL)verifyItem:(PVMediaVaultItem *)item error:(NSError **)error;
- (BOOL)removeItem:(PVMediaVaultItem *)item error:(NSError **)error;
- (NSURL *)urlForItem:(PVMediaVaultItem *)item;
@end

NS_ASSUME_NONNULL_END
