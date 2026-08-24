#import <UIKit/UIKit.h>
#import "PVMediaVaultStore.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^PVMediaVaultBrowserRestoreHandler)(PVMediaVaultItem *item, void (^completion)(BOOL success, NSString *message));

@interface PVMediaVaultBrowserViewController : UIViewController
@property (nonatomic, copy) NSString *mediaType;
@property (nonatomic, copy) NSString *sectionTitle;
@property (nonatomic, strong) NSArray<PVMediaVaultItem *> *items;
@property (nonatomic, copy, nullable) PVMediaVaultBrowserRestoreHandler restoreHandler;
@end

NS_ASSUME_NONNULL_END
