#import "PVMediaVaultBrowserViewController.h"
#import "PVMediaVaultPreviewViewController.h"
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

@interface PVMediaVaultBrowserViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSArray<PVMediaVaultItem *> *visibleItems;
@property (nonatomic, strong) UIView *tabBar;
@property (nonatomic, strong) NSArray<UIButton *> *tabButtons;
@property (nonatomic, assign) NSInteger selectedTab;
@end

@implementation PVMediaVaultBrowserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.title = @"";
    self.navigationItem.backButtonTitle = @"";
    if (@available(iOS 13.0, *)) self.view.backgroundColor = UIColor.systemBackgroundColor;
    else self.view.backgroundColor = UIColor.whiteColor;

    if ([self.mediaType isEqualToString:@"image"]) self.selectedTab = 1;
    else if ([self.mediaType isEqualToString:@"video"]) self.selectedTab = 2;
    else self.selectedTab = 0;

    self.tabBar = [[UIView alloc] init];
    self.tabBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabBar.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    self.tabBar.layer.cornerRadius = 13.0;
    self.tabBar.clipsToBounds = YES;
    [self.view addSubview:self.tabBar];

    NSArray<NSString *> *titles = @[@"الكل", @"الصور", @"الفيديوهات"];
    NSMutableArray<UIButton *> *buttons = [NSMutableArray arrayWithCapacity:titles.count];
    for (NSInteger index = 0; index < titles.count; index++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.tag = index;
        [button setTitle:titles[index] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
        [button addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.tabBar addSubview:button];
        [buttons addObject:button];
    }
    self.tabButtons = [buttons copy];
    [NSLayoutConstraint activateConstraints:@[
        [self.tabBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10.0],
        [self.tabBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14.0],
        [self.tabBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-14.0],
        [self.tabBar.heightAnchor constraintEqualToConstant:46.0]
    ]];
    for (NSInteger index = 0; index < buttons.count; index++) {
        UIButton *button = buttons[index];
        NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
            [button.topAnchor constraintEqualToAnchor:self.tabBar.topAnchor constant:4.0],
            [button.bottomAnchor constraintEqualToAnchor:self.tabBar.bottomAnchor constant:-4.0],
            [button.widthAnchor constraintEqualToAnchor:self.tabBar.widthAnchor multiplier:1.0 / 3.0]
        ]];
        if (index == 0) [constraints addObject:[button.leadingAnchor constraintEqualToAnchor:self.tabBar.leadingAnchor]];
        else [constraints addObject:[button.leadingAnchor constraintEqualToAnchor:buttons[index - 1].trailingAnchor]];
        [NSLayoutConstraint activateConstraints:constraints];
    }
    [self updateTabAppearanceAnimated:NO];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 5.0;
    layout.minimumLineSpacing = 5.0;
    layout.sectionInset = UIEdgeInsetsMake(10.0, 5.0, 20.0, 5.0);
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
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
        [self.collectionView.topAnchor constraintEqualToAnchor:self.tabBar.bottomAnchor constant:4.0],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.collectionView.centerYAnchor],
        [self.emptyLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [self.emptyLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24.0]
    ]];
    [self rebuildVisibleItems];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self rebuildVisibleItems];
}

- (void)tabTapped:(UIButton *)sender {
    if (self.selectedTab == sender.tag) return;
    self.selectedTab = sender.tag;
    [self updateTabAppearanceAnimated:YES];
    [self rebuildVisibleItems];
}

- (void)updateTabAppearanceAnimated:(BOOL)animated {
    void (^changes)(void) = ^{
        for (UIButton *button in self.tabButtons) {
            BOOL selected = button.tag == self.selectedTab;
            button.backgroundColor = selected ? [UIColor colorWithRed:0.12 green:0.56 blue:1.0 alpha:1.0] : UIColor.clearColor;
            [button setTitleColor:selected ? UIColor.whiteColor : [UIColor colorWithWhite:0.72 alpha:1.0] forState:UIControlStateNormal];
            button.layer.cornerRadius = 10.0;
        }
    };
    if (animated) [UIView animateWithDuration:0.20 animations:changes];
    else changes();
}

- (void)rebuildVisibleItems {
    NSMutableArray<PVMediaVaultItem *> *filtered = [NSMutableArray array];
    for (PVMediaVaultItem *item in self.items) {
        if (self.selectedTab == 0 || (self.selectedTab == 1 && [item.type isEqualToString:@"image"]) || (self.selectedTab == 2 && [item.type isEqualToString:@"video"])) [filtered addObject:item];
    }
    self.visibleItems = [filtered copy];
    self.emptyLabel.hidden = self.visibleItems.count > 0;
    [self.collectionView reloadData];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView { return 1; }
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section { return self.visibleItems.count; }

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PVVaultGridCell" forIndexPath:indexPath];
    for (UIView *subview in [cell.contentView.subviews copy]) [subview removeFromSuperview];
    PVMediaVaultItem *item = self.visibleItems[indexPath.item];
    cell.accessibilityIdentifier = item.identifier;
    cell.accessibilityLabel = [item.type isEqualToString:@"video"] ? @"فيديو مخفي" : @"صورة مخفية";
    cell.accessibilityTraits = UIAccessibilityTraitButton;
    cell.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    cell.layer.cornerRadius = 12.0;
    cell.clipsToBounds = YES;

    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    imageView.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1.0];
    imageView.tag = 8100;
    imageView.image = [self fallbackThumbnailForItem:item];
    [cell.contentView addSubview:imageView];
    [NSLayoutConstraint activateConstraints:@[
        [imageView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
        [imageView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
        [imageView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
        [imageView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor]
    ]];

    if ([item.type isEqualToString:@"video"]) {
        UILabel *durationLabel = [[UILabel alloc] init];
        durationLabel.translatesAutoresizingMaskIntoConstraints = NO;
        durationLabel.text = @"▶ --:--";
        durationLabel.textColor = UIColor.whiteColor;
        durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:11.0 weight:UIFontWeightSemibold];
        durationLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.72];
        durationLabel.textAlignment = NSTextAlignmentCenter;
        durationLabel.layer.cornerRadius = 8.0;
        durationLabel.clipsToBounds = YES;
        [cell.contentView addSubview:durationLabel];
        [NSLayoutConstraint activateConstraints:@[
            [durationLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-6.0],
            [durationLabel.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-6.0],
            [durationLabel.heightAnchor constraintEqualToConstant:22.0],
            [durationLabel.widthAnchor constraintGreaterThanOrEqualToConstant:54.0]
        ]];
        [self loadDurationForItem:item intoLabel:durationLabel cell:cell];
    }
    [self loadThumbnailForItem:item intoImageView:imageView cell:cell];
    return cell;
}

- (UIImage *)fallbackThumbnailForItem:(PVMediaVaultItem *)item {
    if (@available(iOS 13.0, *)) {
        UIImage *image = [UIImage systemImageNamed:[item.type isEqualToString:@"video"] ? @"video.fill" : @"photo.fill"];
        return image;
    }
    return nil;
}

- (void)loadThumbnailForItem:(PVMediaVaultItem *)item intoImageView:(UIImageView *)imageView cell:(UICollectionViewCell *)cell {
    NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:item];
    NSString *identifier = item.identifier;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *thumbnail = nil;
        if ([item.type isEqualToString:@"video"]) {
            AVAsset *asset = [AVAsset assetWithURL:url];
            AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
            generator.appliesPreferredTrackTransform = YES;
            generator.maximumSize = CGSizeMake(720.0, 720.0);
            CMTime time = CMTimeMakeWithSeconds(0.05, 600);
            CGImageRef imageRef = [generator copyCGImageAtTime:time actualTime:NULL error:NULL];
            if (imageRef) {
                thumbnail = [UIImage imageWithCGImage:imageRef];
                CGImageRelease(imageRef);
            }
        } else {
            thumbnail = [UIImage imageWithContentsOfFile:url.path];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (thumbnail && [cell.accessibilityIdentifier isEqualToString:identifier]) imageView.image = thumbnail;
        });
    });
}

- (void)loadDurationForItem:(PVMediaVaultItem *)item intoLabel:(UILabel *)label cell:(UICollectionViewCell *)cell {
    NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:item];
    NSString *identifier = item.identifier;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        AVAsset *asset = [AVAsset assetWithURL:url];
        Float64 seconds = CMTimeGetSeconds(asset.duration);
        NSString *duration = @"--:--";
        if (isfinite(seconds) && seconds >= 0.0) {
            NSInteger total = (NSInteger)llround(seconds);
            duration = [NSString stringWithFormat:@"%02ld:%02ld", (long)(total / 60), (long)(total % 60)];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([cell.accessibilityIdentifier isEqualToString:identifier]) label.text = [NSString stringWithFormat:@"▶ %@", duration];
        });
    });
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *)layout;
    CGFloat width = CGRectGetWidth(collectionView.bounds) - flowLayout.sectionInset.left - flowLayout.sectionInset.right - flowLayout.minimumInteritemSpacing * 2.0;
    CGFloat side = floor(width / 3.0);
    return CGSizeMake(side, side);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item >= self.visibleItems.count) return;
    PVMediaVaultItem *item = self.visibleItems[indexPath.item];
    PVMediaVaultPreviewViewController *preview = [[PVMediaVaultPreviewViewController alloc] init];
    preview.item = item;
    preview.items = self.visibleItems;
    preview.initialIndex = indexPath.item;
    UICollectionViewCell *selectedCell = [collectionView cellForItemAtIndexPath:indexPath];
    UIImageView *selectedImageView = [selectedCell.contentView viewWithTag:8100];
    preview.transitionImage = selectedImageView.image;
    preview.transitionFrame = [selectedCell convertRect:selectedCell.bounds toView:self.view];
    preview.modalPresentationStyle = UIModalPresentationFullScreen;
    __weak typeof(self) weakSelf = self;
    preview.restoreHandler = ^(PVMediaVaultItem *restoreItem, void (^completion)(BOOL success, NSString *message)) {
        [weakSelf restoreItemDirectly:restoreItem completion:completion];
    };
    preview.deleteHandler = ^(PVMediaVaultItem *deleteItem, void (^completion)(BOOL success, NSString *message)) {
        [weakSelf deleteItemDirectly:deleteItem completion:completion];
    };
    [self presentViewController:preview animated:YES completion:nil];
}

- (void)deleteItemDirectly:(PVMediaVaultItem *)item completion:(void (^)(BOOL success, NSString *message))completion {
    NSError *error = nil;
    BOOL success = [[PVMediaVaultStore sharedStore] removeItem:item error:&error];
    if (success) {
        NSMutableArray *updated = [self.items mutableCopy];
        [updated removeObject:item];
        self.items = [updated copy];
        [self rebuildVisibleItems];
        completion(YES, @"تم حذف العنصر.");
    } else {
        completion(NO, error.localizedDescription ?: @"تعذر حذف العنصر؛ بقيت النسخة دون تغيير.");
    }
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
            [self rebuildVisibleItems];
            completion(YES, @"تم استرداد العنصر إلى تطبيق الصور.");
        });
    }];
}

@end
