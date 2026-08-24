#import <UIKit/UIKit.h>
#import "PVMediaVaultStore.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^PVMediaVaultRestoreHandler)(PVMediaVaultItem *item, void (^completion)(BOOL success, NSString *message));

@interface PVMediaVaultPreviewViewController : UIViewController
@property (nonatomic, strong) PVMediaVaultItem *item;
@property (nonatomic, strong) NSArray<PVMediaVaultItem *> *items;
@property (nonatomic, assign) NSInteger initialIndex;
@property (nonatomic, copy, nullable) PVMediaVaultRestoreHandler restoreHandler;
@end

NS_ASSUME_NONNULL_END
