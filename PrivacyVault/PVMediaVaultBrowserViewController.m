#import "PVMediaVaultBrowserViewController.h"
#import "PVMediaVaultPreviewViewController.h"
#import <Photos/Photos.h>

@interface PVMediaVaultBrowserViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UILabel *emptyLabel;
@end

@implementation PVMediaVaultBrowserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.title = @"";
    self.navigationItem.backButtonTitle = @"";
    if (@available(iOS 13.0, *)) self.view.backgroundColor = [UIColor systemBackgroundColor];
    else self.view.backgroundColor = [UIColor blackColor];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 5.0;
    layout.minimumLineSpacing = 5.0;
    layout.sectionInset = UIEdgeInsetsMake(10.0, 5.0, 20.0, 5.0);
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) self.collectionView.backgroundColor = UIColor.systemBackgroundColor;
    else self.collectionView.backgroundColor = UIColor.blackColor;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"PVVaultGridCell"];
    [self.view addSubview:self.collectionView];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"لا توجد عناصر مخفية هنا";
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightMedium];
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
        [self.emptyLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [self.emptyLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24.0]
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

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PVVaultGridCell" forIndexPath:indexPath];
    for (UIView *subview in [cell.contentView.subviews copy]) [subview removeFromSuperview];
    cell.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    cell.layer.cornerRadius = 14.0;
    cell.clipsToBounds = YES;
    cell.accessibilityLabel = @"وسائط مخفية";
    cell.accessibilityTraits = UIAccessibilityTraitButton;

    PVMediaVaultItem *item = self.items[indexPath.item];
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    imageView.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1.0];
    UIImage *preview = nil;
    if ([item.type isEqualToString:@"image"]) {
        preview = [UIImage imageWithContentsOfFile:[[PVMediaVaultStore sharedStore] urlForItem:item].path];
    }
    if (!preview) {
        if (@available(iOS 13.0, *)) {
            preview = [UIImage systemImageNamed:[item.type isEqualToString:@"video"] ? @"video.fill" : @"photo.fill"];
            imageView.contentMode = UIViewContentModeScaleAspectFit;
            imageView.tintColor = [UIColor colorWithWhite:0.72 alpha:1.0];
        }
    }
    imageView.image = preview;
    [cell.contentView addSubview:imageView];
    [NSLayoutConstraint activateConstraints:@[
        [imageView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
        [imageView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
        [imageView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
        [imageView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor]
    ]];

    if ([item.type isEqualToString:@"video"]) {
        if (@available(iOS 13.0, *)) {
            UIImageView *playBadge = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"play.circle.fill"]];
        playBadge.translatesAutoresizingMaskIntoConstraints = NO;
        playBadge.tintColor = [UIColor colorWithWhite:1.0 alpha:0.92];
        playBadge.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.28];
        playBadge.layer.cornerRadius = 18.0;
        playBadge.clipsToBounds = YES;
        [cell.contentView addSubview:playBadge];
            [NSLayoutConstraint activateConstraints:@[
                [playBadge.centerXAnchor constraintEqualToAnchor:cell.contentView.centerXAnchor],
                [playBadge.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
                [playBadge.widthAnchor constraintEqualToConstant:36.0],
                [playBadge.heightAnchor constraintEqualToConstant:36.0]
            ]];
        }
    }
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *)layout;
    CGFloat availableWidth = CGRectGetWidth(collectionView.bounds) - flowLayout.sectionInset.left - flowLayout.sectionInset.right - (flowLayout.minimumInteritemSpacing * 2.0);
    CGFloat side = floor(availableWidth / 3.0);
    return CGSizeMake(side, side);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item >= self.items.count) return;
    PVMediaVaultItem *item = self.items[indexPath.item];
    PVMediaVaultPreviewViewController *preview = [[PVMediaVaultPreviewViewController alloc] init];
    preview.item = item;
    __weak typeof(self) weakSelf = self;
    preview.restoreHandler = ^(PVMediaVaultItem *restoreItem, void (^completion)(BOOL success, NSString *message)) {
        [weakSelf restoreItemDirectly:restoreItem completion:completion];
    };
    [self.navigationController pushViewController:preview animated:YES];
}

- (void)restoreItemDirectly:(PVMediaVaultItem *)item completion:(void (^)(BOOL success, NSString *message))completion {
    NSError *verificationError = nil;
    if (![[PVMediaVaultStore sharedStore] verifyItem:item error:&verificationError]) {
        completion(NO, verificationError.localizedDescription ?: @"نسخة الوسائط غير مكتملة؛ بقيت نسخة PrivacyVault دون تغيير.");
        return;
    }
    PHAuthorizationStatus authorizationStatus;
    if (@available(iOS 14.0, *)) authorizationStatus = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
    else authorizationStatus = [PHPhotoLibrary authorizationStatus];
    if (authorizationStatus != PHAuthorizationStatusAuthorized && authorizationStatus != PHAuthorizationStatusLimited) {
        completion(NO, @"يلزم السماح بإضافة الوسائط إلى تطبيق الصور قبل الاسترداد.");
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
                completion(NO, error.localizedDescription ?: @"فشل الاسترداد؛ بقيت نسخة PrivacyVault دون تغيير.");
                return;
            }
            PHFetchResult<PHAsset *> *createdAssets = [PHAsset fetchAssetsWithLocalIdentifiers:@[createdIdentifier] options:nil];
            if (createdAssets.count == 0) {
                completion(NO, @"تعذر التحقق من العنصر المسترد؛ بقيت نسخة PrivacyVault دون تغيير.");
                return;
            }
            NSError *removeError = nil;
            if (![[PVMediaVaultStore sharedStore] removeItem:item error:&removeError]) {
                completion(NO, @"تم الاسترداد، لكن تعذر إزالة نسخة PrivacyVault؛ بقيت النسخة للحماية.");
                return;
            }
            NSMutableArray *updatedItems = [self.items mutableCopy];
            [updatedItems removeObject:item];
            self.items = [updatedItems copy];
            [self refreshEmptyState];
            [self.collectionView reloadData];
            completion(YES, @"تم استرداد العنصر إلى تطبيق الصور.");
        });
    }];
}

@end
