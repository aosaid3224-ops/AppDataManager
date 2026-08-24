#import <UIKit/UIKit.h>
#import "PVMediaVaultStore.h"

NS_ASSUME_NONNULL_BEGIN

@interface PVMediaVaultBrowserViewController : UIViewController
@property (nonatomic, copy) NSString *mediaType;
@property (nonatomic, copy) NSString *sectionTitle;
@property (nonatomic, strong) NSArray<PVMediaVaultItem *> *items;
@property (nonatomic, copy, nullable) void (^restoreHandler)(PVMediaVaultItem *item);
@end

NS_ASSUME_NONNULL_END
