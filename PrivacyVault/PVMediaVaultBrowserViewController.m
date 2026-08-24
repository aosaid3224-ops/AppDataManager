#import "PVMediaVaultBrowserViewController.h"
#import <QuickLook/QuickLook.h>
#import <Photos/Photos.h>

@interface PVMediaVaultBrowserViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, QLPreviewControllerDataSource>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) QLPreviewController *previewController;
@property (nonatomic, strong) PVMediaVaultItem *previewItem;
@end

@implementation PVMediaVaultBrowserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.title = self.sectionTitle ?: @"العناصر المخفية";
    if (@available(iOS 13.0, *)) self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    else self.view.backgroundColor = [UIColor whiteColor];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 10.0;
    layout.minimumLineSpacing = 14.0;
    layout.sectionInset = UIEdgeInsetsMake(18, 14, 28, 14);
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"PVVaultGridCell"];
    [self.view addSubview:self.collectionView];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"لا توجد عناصر مخفية هنا";
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor secondaryLabelColor];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.emptyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.emptyLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.emptyLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24]
    ]];
    [self refreshEmptyState];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self refreshEmptyState];
    [self.collectionView reloadData];
}

- (void)refreshEmptyState {
    self.emptyLabel.hidden = self.items.count > 0;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.items.count;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PVVaultGridCell" forIndexPath:indexPath];
    for (UIView *subview in [cell.contentView.subviews copy]) [subview removeFromSuperview];
    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    cell.layer.cornerRadius = 16.0;
    cell.clipsToBounds = YES;

    PVMediaVaultItem *item = self.items[indexPath.item];
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    UIImage *preview = nil;
    if ([item.type isEqualToString:@"image"]) preview = [UIImage imageWithContentsOfFile:[[PVMediaVaultStore sharedStore] urlForItem:item].path];
    if (!preview) {
        if (@available(iOS 13.0, *)) preview = [UIImage systemImageNamed:[item.type isEqualToString:@"video"] ? @"video.fill" : @"photo.fill"];
    }
    imageView.image = preview;
    imageView.tintColor = [UIColor systemBlueColor];
    [cell.contentView addSubview:imageView];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.text = item.filename;
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    nameLabel.textColor = [UIColor labelColor];
    nameLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [cell.contentView addSubview:nameLabel];

    UILabel *typeLabel = [[UILabel alloc] init];
    typeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    typeLabel.text = [item.type isEqualToString:@"video"] ? @"فيديو" : @"صورة";
    typeLabel.textAlignment = NSTextAlignmentCenter;
    typeLabel.font = [UIFont systemFontOfSize:10];
    typeLabel.textColor = [UIColor secondaryLabelColor];
    [cell.contentView addSubview:typeLabel];

    [NSLayoutConstraint activateConstraints:@[
        [imageView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
        [imageView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
        [imageView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
        [imageView.bottomAnchor constraintEqualToAnchor:typeLabel.topAnchor constant:-2],
        [typeLabel.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:4],
        [typeLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-4],
        [typeLabel.bottomAnchor constraintEqualToAnchor:nameLabel.topAnchor constant:-1],
        [nameLabel.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:4],
        [nameLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-4],
        [nameLabel.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-6]
    ]];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *)layout;
    CGFloat availableWidth = CGRectGetWidth(collectionView.bounds) - flowLayout.sectionInset.left - flowLayout.sectionInset.right - (flowLayout.minimumInteritemSpacing * 2.0);
    return CGSizeMake(floor(availableWidth / 3.0), 154.0);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item >= self.items.count) return;
    [self showActionsForItem:self.items[indexPath.item]];
}

- (void)showActionsForItem:(PVMediaVaultItem *)item {
    UIAlertController *actions = [UIAlertController alertControllerWithTitle:item.filename message:@"اختر الإجراء المطلوب" preferredStyle:UIAlertControllerStyleActionSheet];
    [actions addAction:[UIAlertAction actionWithTitle:@"فتح" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self openItem:item];
    }]];
    [actions addAction:[UIAlertAction actionWithTitle:@"مشاركة" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self shareItem:item];
    }]];
    [actions addAction:[UIAlertAction actionWithTitle:@"استرداد إلى تطبيق الصور" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        if (self.restoreHandler) self.restoreHandler(item);
        else [self restoreItemDirectly:item];
    }]];
    [actions addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        actions.popoverPresentationController.sourceView = self.view;
        actions.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    }
    [self presentViewController:actions animated:YES completion:nil];
}

- (void)openItem:(PVMediaVaultItem *)item {
    self.previewItem = item;
    self.previewController = [[QLPreviewController alloc] init];
    self.previewController.dataSource = self;
    [self presentViewController:self.previewController animated:YES completion:nil];
}

- (void)shareItem:(PVMediaVaultItem *)item {
    NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:item];
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        [self showMessage:@"تعذر العثور على ملف الوسائط داخل PrivacyVault."];
        return;
    }
    UIActivityViewController *shareController = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        shareController.popoverPresentationController.sourceView = self.view;
        shareController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    }
    [self presentViewController:shareController animated:YES completion:nil];
}

- (void)restoreItemDirectly:(PVMediaVaultItem *)item {
    NSError *verificationError = nil;
    if (![[PVMediaVaultStore sharedStore] verifyItem:item error:&verificationError]) {
        [self showMessage:verificationError.localizedDescription ?: @"نسخة الوسائط غير مكتملة؛ لم تتم إزالتها."];
        return;
    }
    PHAuthorizationStatus authorizationStatus;
    if (@available(iOS 14.0, *)) authorizationStatus = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
    else authorizationStatus = [PHPhotoLibrary authorizationStatus];
    if (authorizationStatus != PHAuthorizationStatusAuthorized && authorizationStatus != PHAuthorizationStatusLimited) {
        [self showMessage:@"يلزم السماح بإضافة الوسائط إلى تطبيق الصور قبل الاسترداد."];
        return;
    }
    NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:item];
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
                [self showMessage:error.localizedDescription ?: @"فشل الاسترداد؛ بقيت نسخة Vault دون تغيير."];
                return;
            }
            PHFetchResult<PHAsset *> *createdAssets = [PHAsset fetchAssetsWithLocalIdentifiers:@[createdIdentifier] options:nil];
            if (createdAssets.count == 0) {
                [self showMessage:@"تعذر التحقق من العنصر المسترد؛ بقيت نسخة Vault دون تغيير."];
                return;
            }
            NSError *removeError = nil;
            if (![[PVMediaVaultStore sharedStore] removeItem:item error:&removeError]) {
                [self showMessage:@"تم الاسترداد، لكن تعذر إزالة نسخة Vault؛ بقيت النسخة للحماية."];
                return;
            }
            NSMutableArray *updatedItems = [self.items mutableCopy];
            [updatedItems removeObject:item];
            self.items = [updatedItems copy];
            [self refreshEmptyState];
            [self.collectionView reloadData];
            [self showMessage:@"تم استرداد العنصر وإزالة نسخة Vault."];
        });
    }];
}

- (void)showMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"PrivacyVault" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return self.previewItem ? 1 : 0;
}

- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    return [[PVMediaVaultStore sharedStore] urlForItem:self.previewItem];
}

@end
