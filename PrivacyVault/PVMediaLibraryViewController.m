#import "PVMediaLibraryViewController.h"
#import "PVMediaVaultStore.h"
#import <Photos/Photos.h>

@interface PVMediaLibraryViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *statisticsLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *importButton;
@property (nonatomic, strong) NSArray<PHAsset *> *photoAssets;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedIdentifiers;
@property (nonatomic, strong) NSArray<PVMediaVaultItem *> *vaultItems;
@property (nonatomic, assign) BOOL busy;
@end

@implementation PVMediaLibraryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"إخفاء الصور والفيديوهات";
    self.selectedIdentifiers = [NSMutableSet set];
    self.photoAssets = @[];
    self.vaultItems = @[];
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }

    self.statisticsLabel = [[UILabel alloc] init];
    self.statisticsLabel.textAlignment = NSTextAlignmentRight;
    self.statisticsLabel.numberOfLines = 0;
    self.statisticsLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.statisticsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statisticsLabel];

    self.importButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.importButton setTitle:@"إضافة المحدد إلى PrivacyVault" forState:UIControlStateNormal];
    self.importButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.importButton addTarget:self action:@selector(importSelectedTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.importButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.importButton];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.textAlignment = NSTextAlignmentRight;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 76.0;
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.statisticsLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [self.statisticsLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.statisticsLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.importButton.topAnchor constraintEqualToAnchor:self.statisticsLabel.bottomAnchor constant:10],
        [self.importButton.trailingAnchor constraintEqualToAnchor:self.statisticsLabel.trailingAnchor],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.importButton.bottomAnchor constant:4],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.statisticsLabel.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.statisticsLabel.trailingAnchor],
        [self.tableView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:8],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self updateStatistics];
    [self requestPhotoAccessIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self reloadVaultItems];
    if ([self hasPhotoAccess]) [self reloadPhotoAssets];
}

- (void)requestPhotoAccessIfNeeded {
    if (@available(iOS 14.0, *)) {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
        if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
            [self reloadPhotoAssets];
            return;
        }
        if (status == PHAuthorizationStatusDenied || status == PHAuthorizationStatusRestricted) {
            [self showPhotoPermissionMessage];
            return;
        }
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite handler:^(PHAuthorizationStatus newStatus) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (newStatus == PHAuthorizationStatusAuthorized || newStatus == PHAuthorizationStatusLimited) {
                    [self reloadPhotoAssets];
                } else {
                    [self showPhotoPermissionMessage];
                }
            });
        }];
    } else {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        if (status == PHAuthorizationStatusAuthorized) {
            [self reloadPhotoAssets];
        } else if (status == PHAuthorizationStatusNotDetermined) {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus newStatus) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (newStatus == PHAuthorizationStatusAuthorized) [self reloadPhotoAssets];
                    else [self showPhotoPermissionMessage];
                });
            }];
        } else {
            [self showPhotoPermissionMessage];
        }
    }
}

- (BOOL)hasPhotoAccess {
    if (@available(iOS 14.0, *)) {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
        return status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited;
    }
    return [PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized;
}

- (void)showPhotoPermissionMessage {
    self.statisticsLabel.text = @"الصور: غير متاح\nالفيديوهات: غير متاح\nالمحدد: 0";
    self.statusLabel.textColor = [UIColor systemRedColor];
    self.statusLabel.text = @"يلزم السماح للتطبيق بالوصول إلى مكتبة الصور لعرض العناصر واستيرادها.";
    self.importButton.enabled = NO;
    [self.tableView reloadData];
}

- (void)reloadPhotoAssets {
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    PHFetchResult<PHAsset *> *images = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:options];
    PHFetchResult<PHAsset *> *videos = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeVideo options:options];
    NSMutableArray<PHAsset *> *assets = [NSMutableArray arrayWithCapacity:images.count + videos.count];
    [images enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL *stop) { [assets addObject:asset]; }];
    [videos enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL *stop) { [assets addObject:asset]; }];
    self.photoAssets = [assets sortedArrayUsingComparator:^NSComparisonResult(PHAsset *left, PHAsset *right) {
        NSDate *leftDate = left.creationDate ?: [NSDate distantPast];
        NSDate *rightDate = right.creationDate ?: [NSDate distantPast];
        return [rightDate compare:leftDate];
    }];
    NSMutableSet *availableIdentifiers = [NSMutableSet setWithCapacity:self.photoAssets.count];
    for (PHAsset *asset in self.photoAssets) [availableIdentifiers addObject:asset.localIdentifier];
    [self.selectedIdentifiers intersectSet:availableIdentifiers];
    [self updateStatistics];
    [self.tableView reloadData];
}

- (void)reloadVaultItems {
    self.vaultItems = [PVMediaVaultStore sharedStore].items;
    [self updateStatistics];
    [self.tableView reloadData];
}

- (void)updateStatistics {
    NSUInteger imageCount = 0;
    NSUInteger videoCount = 0;
    for (PHAsset *asset in self.photoAssets) {
        if (asset.mediaType == PHAssetMediaTypeVideo) videoCount++;
        else if (asset.mediaType == PHAssetMediaTypeImage) imageCount++;
    }
    self.statisticsLabel.text = [NSString stringWithFormat:@"الصور: %lu\nالفيديوهات: %lu\nالمحدد: %lu", (unsigned long)imageCount, (unsigned long)videoCount, (unsigned long)self.selectedIdentifiers.count];
    self.importButton.enabled = self.selectedIdentifiers.count > 0 && !self.busy && [self hasPhotoAccess];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? self.photoAssets.count : self.vaultItems.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"مكتبة الصور والفيديوهات" : @"داخل PrivacyVault";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"PVMediaCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    cell.textLabel.textAlignment = NSTextAlignmentRight;
    cell.detailTextLabel.textAlignment = NSTextAlignmentRight;
    cell.imageView.image = nil;

    if (indexPath.section == 0) {
        PHAsset *asset = self.photoAssets[indexPath.row];
        cell.textLabel.text = asset.mediaType == PHAssetMediaTypeVideo ? @"فيديو" : @"صورة";
        cell.detailTextLabel.text = asset.creationDate ? [NSDateFormatter localizedStringFromDate:asset.creationDate dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle] : @"";
        cell.accessoryType = [self.selectedIdentifiers containsObject:asset.localIdentifier] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        PHImageRequestOptions *imageOptions = [[PHImageRequestOptions alloc] init];
        imageOptions.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
        imageOptions.resizeMode = PHImageRequestOptionsResizeModeFast;
        imageOptions.networkAccessAllowed = NO;
        NSIndexPath *requestedPath = [indexPath copy];
        [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(60, 60) contentMode:PHImageContentModeAspectFill options:imageOptions resultHandler:^(UIImage *result, NSDictionary *info) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UITableViewCell *visibleCell = [self.tableView cellForRowAtIndexPath:requestedPath];
                if (visibleCell) visibleCell.imageView.image = result;
                [visibleCell setNeedsLayout];
            });
        }];
    } else {
        PVMediaVaultItem *item = self.vaultItems[indexPath.row];
        cell.textLabel.text = item.filename;
        NSString *kind = [item.type isEqualToString:@"video"] ? @"فيديو" : @"صورة";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ — %@ بايت", kind, [NSNumber numberWithUnsignedInteger:item.byteSize]];
        UIButton *restoreButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [restoreButton setTitle:@"استرداد" forState:UIControlStateNormal];
        restoreButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        restoreButton.tag = indexPath.row;
        [restoreButton addTarget:self action:@selector(restoreButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [restoreButton sizeToFit];
        cell.accessoryView = restoreButton;
        NSString *symbolName = [item.type isEqualToString:@"video"] ? @"video.fill" : @"photo.fill";
        if (@available(iOS 13.0, *)) cell.imageView.image = [UIImage systemImageNamed:symbolName];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 0 || self.busy) return;
    PHAsset *asset = self.photoAssets[indexPath.row];
    if ([self.selectedIdentifiers containsObject:asset.localIdentifier]) [self.selectedIdentifiers removeObject:asset.localIdentifier];
    else [self.selectedIdentifiers addObject:asset.localIdentifier];
    [self updateStatistics];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)importSelectedTapped:(UIButton *)sender {
    if (self.busy || self.selectedIdentifiers.count == 0) return;
    NSMutableArray<PHAsset *> *selectedAssets = [NSMutableArray array];
    for (PHAsset *asset in self.photoAssets) if ([self.selectedIdentifiers containsObject:asset.localIdentifier]) [selectedAssets addObject:asset];
    if (selectedAssets.count == 0) return;
    self.busy = YES;
    [self updateStatistics];
    self.statusLabel.textColor = [UIColor labelColor];
    self.statusLabel.text = @"جارٍ نسخ العناصر والتحقق منها…";
    [self importAssets:selectedAssets atIndex:0 importedIdentifiers:[NSMutableArray array] completion:^(BOOL success, NSArray<NSString *> *importedIdentifiers, NSError *error) {
        if (!success) {
            for (NSString *identifier in importedIdentifiers) {
                for (PVMediaVaultItem *item in [PVMediaVaultStore sharedStore].items) {
                    if ([item.identifier isEqualToString:identifier]) [[PVMediaVaultStore sharedStore] removeItem:item error:nil];
                }
            }
            self.busy = NO;
            self.statusLabel.textColor = [UIColor systemRedColor];
            self.statusLabel.text = error.localizedDescription ?: @"فشل استيراد عنصر؛ لم تتم إزالة أي أصل من الصور.";
            [self updateStatistics];
            [self reloadVaultItems];
            return;
        }
        [self verifyImportedIdentifiers:importedIdentifiers completion:^(BOOL verified, NSError *verifyError) {
            if (!verified) {
                self.busy = NO;
                self.statusLabel.textColor = [UIColor systemRedColor];
                self.statusLabel.text = verifyError.localizedDescription ?: @"فشل التحقق؛ لم تتم إزالة أي أصل من الصور.";
                [self updateStatistics];
                [self reloadVaultItems];
                return;
            }
            [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
                [PHAssetChangeRequest deleteAssets:selectedAssets];
            } completionHandler:^(BOOL deletionSuccess, NSError *deletionError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.busy = NO;
                    [self.selectedIdentifiers removeAllObjects];
                    if (deletionSuccess) {
                        self.statusLabel.textColor = [UIColor systemGreenColor];
                        self.statusLabel.text = @"تمت الإضافة والتحقق وإزالة الأصول من مكتبة الصور.";
                    } else {
                        self.statusLabel.textColor = [UIColor systemOrangeColor];
                        self.statusLabel.text = @"تم حفظ العناصر والتحقق منها، لكن تعذر إزالة الأصول من مكتبة الصور؛ بقيت النسختان محفوظتين.";
                    }
                    [self reloadPhotoAssets];
                    [self reloadVaultItems];
                });
            }];
        }];
    }];
}

- (void)importAssets:(NSArray<PHAsset *> *)assets atIndex:(NSUInteger)index importedIdentifiers:(NSMutableArray<NSString *> *)importedIdentifiers completion:(void (^)(BOOL success, NSArray<NSString *> *importedIdentifiers, NSError *error))completion {
    if (index >= assets.count) {
        completion(YES, [importedIdentifiers copy], nil);
        return;
    }
    PHAsset *asset = assets[index];
    PHAssetResource *resource = [PHAssetResource assetResourcesForAsset:asset].firstObject;
    if (!resource) {
        completion(NO, [importedIdentifiers copy], [NSError errorWithDomain:@"com.aosaid.privacyvault.media" code:20 userInfo:@{NSLocalizedDescriptionKey: @"تعذر قراءة مورد الصورة أو الفيديو"}]);
        return;
    }
    NSString *extension = resource.originalFilename.pathExtension.lowercaseString;
    if (extension.length == 0) extension = asset.mediaType == PHAssetMediaTypeVideo ? @"mov" : @"jpg";
    NSString *temporaryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"PVVault-%@.%@", [[NSUUID UUID] UUIDString], extension]];
    NSURL *temporaryURL = [NSURL fileURLWithPath:temporaryPath];
    PHAssetResourceRequestOptions *options = [[PHAssetResourceRequestOptions alloc] init];
    options.networkAccessAllowed = YES;
    [[PHAssetResourceManager defaultManager] writeDataForAssetResource:resource toFile:temporaryURL options:options completionHandler:^(NSError *error) {
        if (error) {
            completion(NO, [importedIdentifiers copy], [NSError errorWithDomain:error.domain code:error.code userInfo:@{NSLocalizedDescriptionKey: @"تعذر تحميل العنصر من مكتبة الصور"}]);
            return;
        }
        NSString *type = asset.mediaType == PHAssetMediaTypeVideo ? @"video" : @"image";
        NSError *importError = nil;
        BOOL imported = [[PVMediaVaultStore sharedStore] importFileAtURL:temporaryURL identifier:asset.localIdentifier type:type originalFilename:resource.originalFilename error:&importError];
        [[NSFileManager defaultManager] removeItemAtURL:temporaryURL error:nil];
        if (!imported) {
            completion(NO, [importedIdentifiers copy], importError ?: [NSError errorWithDomain:@"com.aosaid.privacyvault.media" code:21 userInfo:@{NSLocalizedDescriptionKey: @"فشل حفظ العنصر داخل PrivacyVault"}]);
            return;
        }
        [importedIdentifiers addObject:asset.localIdentifier];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self importAssets:assets atIndex:index + 1 importedIdentifiers:importedIdentifiers completion:completion];
        });
    }];
}

- (void)verifyImportedIdentifiers:(NSArray<NSString *> *)identifiers completion:(void (^)(BOOL verified, NSError *error))completion {
    for (NSString *identifier in identifiers) {
        PVMediaVaultItem *matchingItem = nil;
        for (PVMediaVaultItem *item in [PVMediaVaultStore sharedStore].items) if ([item.identifier isEqualToString:identifier]) { matchingItem = item; break; }
        if (!matchingItem || ![[PVMediaVaultStore sharedStore] verifyItem:matchingItem error:nil]) {
            completion(NO, [NSError errorWithDomain:@"com.aosaid.privacyvault.media" code:22 userInfo:@{NSLocalizedDescriptionKey: @"فشل التحقق من نسخة داخل PrivacyVault؛ لم يتم حذف الأصل"}]);
            return;
        }
    }
    completion(YES, nil);
}

- (void)restoreButtonTapped:(UIButton *)sender {
    if (self.busy || sender.tag >= self.vaultItems.count) return;
    [self restoreItem:self.vaultItems[sender.tag]];
}

- (void)restoreItem:(PVMediaVaultItem *)item {
    if (![[PVMediaVaultStore sharedStore] verifyItem:item error:nil]) {
        self.statusLabel.textColor = [UIColor systemRedColor];
        self.statusLabel.text = @"نسخة PrivacyVault غير مكتملة؛ لم تتم إزالتها.";
        return;
    }
    if (![self hasPhotoAccess]) {
        self.statusLabel.textColor = [UIColor systemRedColor];
        self.statusLabel.text = @"لا توجد صلاحية لإضافة العنصر إلى مكتبة الصور.";
        return;
    }
    NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:item];
    self.busy = YES;
    [self updateStatistics];
    self.statusLabel.textColor = [UIColor labelColor];
    self.statusLabel.text = @"جارٍ استرداد العنصر والتحقق منه…";
    __block NSString *createdIdentifier = nil;
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
        PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
        PHAssetResourceType resourceType = [item.type isEqualToString:@"video"] ? PHAssetResourceTypeVideo : PHAssetResourceTypePhoto;
        [request addResourceWithType:resourceType fileURL:url options:options];
        createdIdentifier = request.placeholderForCreatedAsset.localIdentifier;
    } completionHandler:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success || createdIdentifier.length == 0) {
                self.busy = NO;
                self.statusLabel.textColor = [UIColor systemRedColor];
                self.statusLabel.text = error.localizedDescription ?: @"فشل الاسترداد؛ بقيت نسخة PrivacyVault دون تغيير.";
                [self updateStatistics];
                return;
            }
            PHFetchResult<PHAsset *> *createdAssets = [PHAsset fetchAssetsWithLocalIdentifiers:@[createdIdentifier] options:nil];
            if (createdAssets.count == 0) {
                self.busy = NO;
                self.statusLabel.textColor = [UIColor systemRedColor];
                self.statusLabel.text = @"لم يتم التحقق من العنصر المسترد؛ بقيت نسخة PrivacyVault دون تغيير.";
                [self updateStatistics];
                return;
            }
            NSError *removeError = nil;
            if (![[PVMediaVaultStore sharedStore] removeItem:item error:&removeError]) {
                self.busy = NO;
                self.statusLabel.textColor = [UIColor systemOrangeColor];
                self.statusLabel.text = @"تم استرداد العنصر، لكن تعذر إزالة نسخة PrivacyVault؛ بقيت النسخة للحماية.";
                [self reloadVaultItems];
                return;
            }
            self.busy = NO;
            self.statusLabel.textColor = [UIColor systemGreenColor];
            self.statusLabel.text = @"تم استرداد العنصر والتحقق منه وإزالة نسخة PrivacyVault.";
            [self reloadPhotoAssets];
            [self reloadVaultItems];
        });
    }];
}

@end
