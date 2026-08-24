#import <UIKit/UIKit.h>
#import "PVMediaVaultStore.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^PVMediaVaultRestoreHandler)(PVMediaVaultItem *item, void (^completion)(BOOL success, NSString *message));
typedef void (^PVMediaVaultDeleteHandler)(PVMediaVaultItem *item, void (^completion)(BOOL success, NSString *message));

@interface PVMediaVaultPreviewViewController : UIViewController
@property (nonatomic, strong) PVMediaVaultItem *item;
@property (nonatomic, strong) NSArray<PVMediaVaultItem *> *items;
@property (nonatomic, assign) NSInteger initialIndex;
@property (nonatomic, strong, nullable) UIImage *transitionImage;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, UIImage *> *thumbnailCache;
@property (nonatomic, assign) CGRect transitionFrame;
@property (nonatomic, copy, nullable) PVMediaVaultRestoreHandler restoreHandler;
@property (nonatomic, copy, nullable) PVMediaVaultDeleteHandler deleteHandler;
@end

NS_ASSUME_NONNULL_END
