#import "PVMediaVaultBrowserViewController.h"
#import "PVMediaVaultPreviewViewController.h"
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

static NSCache *PVBrowserThumbnailCache(void) {
    static NSCache *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cache = [[NSCache alloc] init]; cache.countLimit = 160; });
    return cache;
}

static NSCache *PVBrowserDurationCache(void) {
    static NSCache *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cache = [[NSCache alloc] init]; cache.countLimit = 160; });
    return cache;
}

@interface PVMediaVaultBrowserViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UISegmentedControl *mediaSegmentedControl;
@property (nonatomic, strong) NSArray<PVMediaVaultItem *> *visibleItems;
@property (nonatomic, assign) NSInteger selectedTab;
@end

@implementation PVMediaVaultBrowserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.title = @"";
    self.navigationItem.backButtonTitle = @"";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    if ([self.mediaType isEqualToString:@"image"]) self.selectedTab = 1;
    else if ([self.mediaType isEqualToString:@"video"]) self.selectedTab = 2;
    else self.selectedTab = 0;

    self.mediaSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"الكل", @"الصور", @"الفيديوهات"]];
    self.mediaSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.mediaSegmentedControl.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.mediaSegmentedControl.selectedSegmentIndex = self.selectedTab;
    self.mediaSegmentedControl.apportionsSegmentWidthsByContent = NO;
    self.mediaSegmentedControl.backgroundColor = [UIColor secondarySystemBackgroundColor];
    if (@available(iOS 13.0, *)) {
        self.mediaSegmentedControl.selectedSegmentTintColor = [UIColor systemBlueColor];
        [self.mediaSegmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor secondaryLabelColor], NSFontAttributeName: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold]} forState:UIControlStateNormal];
        [self.mediaSegmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor, NSFontAttributeName: [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold]} forState:UIControlStateSelected];
    }
    [self.mediaSegmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.mediaSegmentedControl];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 2.0;
    layout.minimumLineSpacing = 2.0;
    layout.sectionInset = UIEdgeInsetsMake(2.0, 2.0, 12.0, 2.0);
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.delaysContentTouches = NO;
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"PVVaultGridCell"];
    [self.view addSubview:self.collectionView];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.text = @"لا توجد وسائط مخفية";
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    self.emptyLabel.textColor = [UIColor secondaryLabelColor];
    [self.view addSubview:self.emptyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.mediaSegmentedControl.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10.0],
        [self.mediaSegmentedControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14.0],
        [self.mediaSegmentedControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-14.0],
        [self.mediaSegmentedControl.heightAnchor constraintEqualToConstant:38.0],
        [self.collectionView.topAnchor constraintEqualToAnchor:self.mediaSegmentedControl.bottomAnchor constant:8.0],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.collectionView.centerYAnchor],
        [self.emptyLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [self.emptyLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24.0]
    ]];
    [self rebuildVisibleItemsAnimated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self rebuildVisibleItemsAnimated:NO];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    if (sender.selectedSegmentIndex == self.selectedTab) return;
    self.selectedTab = sender.selectedSegmentIndex;
    [self rebuildVisibleItemsAnimated:YES];
}

- (void)rebuildVisibleItemsAnimated:(BOOL)animated {
    NSMutableArray<PVMediaVaultItem *> *filtered = [NSMutableArray array];
    for (PVMediaVaultItem *item in self.items) {
        BOOL matches = self.selectedTab == 0 || (self.selectedTab == 1 && [item.type isEqualToString:@"image"]) || (self.selectedTab == 2 && [item.type isEqualToString:@"video"]);
        if (matches) [filtered addObject:item];
    }
    self.visibleItems = [filtered copy];
    self.emptyLabel.hidden = self.visibleItems.count > 0;
    if (animated) {
        [UIView transitionWithView:self.collectionView duration:0.16 options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState animations:^{ [self.collectionView reloadData]; } completion:nil];
    } else {
        [self.collectionView reloadData];
    }
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
    cell.layer.cornerRadius = 8.0;
    cell.clipsToBounds = YES;

    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.tag = 8100;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    imageView.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1.0];
    imageView.image = [self cachedThumbnailForItem:item];
    [cell.contentView addSubview:imageView];
    [NSLayoutConstraint activateConstraints:@[
        [imageView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
        [imageView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
        [imageView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
        [imageView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor]
    ]];

    if ([item.type isEqualToString:@"video"]) {
        UIView *shade = [[UIView alloc] init];
        shade.translatesAutoresizingMaskIntoConstraints = NO;
        shade.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.10];
        [cell.contentView addSubview:shade];
        [NSLayoutConstraint activateConstraints:@[
            [shade.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
            [shade.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
            [shade.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
            [shade.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor]
        ]];
        UILabel *durationLabel = [[UILabel alloc] init];
        durationLabel.translatesAutoresizingMaskIntoConstraints = NO;
        durationLabel.text = [NSString stringWithFormat:@"▶ %@", [self cachedDurationForItem:item] ?: @"--:--"];
        durationLabel.textColor = UIColor.whiteColor;
        durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:11.0 weight:UIFontWeightSemibold];
        durationLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.68];
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

- (UIImage *)cachedThumbnailForItem:(PVMediaVaultItem *)item {
    UIImage *thumbnail = [PVBrowserThumbnailCache() objectForKey:item.identifier ?: item.path];
    if (thumbnail) return thumbnail;
    if ([item.type isEqualToString:@"video"]) return nil;
    return nil;
}

- (void)loadThumbnailForItem:(PVMediaVaultItem *)item intoImageView:(UIImageView *)imageView cell:(UICollectionViewCell *)cell {
    NSString *key = item.identifier ?: item.path;
    UIImage *cached = [PVBrowserThumbnailCache() objectForKey:key];
    if (cached) { imageView.image = cached; return; }
    NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:item];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *thumbnail = nil;
        if ([item.type isEqualToString:@"video"]) {
            AVAsset *asset = [AVAsset assetWithURL:url];
            AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
            generator.appliesPreferredTrackTransform = YES;
            generator.maximumSize = CGSizeMake(900.0, 900.0);
            CGImageRef imageRef = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(0.05, 600) actualTime:NULL error:NULL];
            if (imageRef) { thumbnail = [UIImage imageWithCGImage:imageRef]; CGImageRelease(imageRef); }
        } else {
            thumbnail = [UIImage imageWithContentsOfFile:url.path];
        }
        if (thumbnail) [PVBrowserThumbnailCache() setObject:thumbnail forKey:key];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([cell.accessibilityIdentifier isEqualToString:item.identifier] && thumbnail) imageView.image = thumbnail;
        });
    });
}

- (NSString *)cachedDurationForItem:(PVMediaVaultItem *)item {
    return [PVBrowserDurationCache() objectForKey:item.identifier ?: item.path];
}

- (void)loadDurationForItem:(PVMediaVaultItem *)item intoLabel:(UILabel *)label cell:(UICollectionViewCell *)cell {
    NSString *key = item.identifier ?: item.path;
    NSString *cached = [self cachedDurationForItem:item];
    if (cached) { label.text = [NSString stringWithFormat:@"▶ %@", cached]; return; }
    NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:item];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        AVAsset *asset = [AVAsset assetWithURL:url];
        Float64 seconds = CMTimeGetSeconds(asset.duration);
        NSString *duration = @"--:--";
        if (isfinite(seconds) && seconds >= 0.0) {
            NSInteger total = (NSInteger)llround(seconds);
            duration = [NSString stringWithFormat:@"%02ld:%02ld", (long)(total / 60), (long)(total % 60)];
        }
        [PVBrowserDurationCache() setObject:duration forKey:key];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([cell.accessibilityIdentifier isEqualToString:item.identifier]) label.text = [NSString stringWithFormat:@"▶ %@", duration];
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
    UIImageView *selectedImageView = (UIImageView *)[selectedCell.contentView viewWithTag:8100];
    preview.transitionImage = selectedImageView.image;
    preview.transitionFrame = [selectedCell convertRect:selectedCell.bounds toView:self.view];
    preview.modalPresentationStyle = UIModalPresentationFullScreen;
    preview.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
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
    if (!success) { completion(NO, error.localizedDescription ?: @"تعذر حذف العنصر؛ بقيت النسخة دون تغيير."); return; }
    NSMutableArray *updated = [self.items mutableCopy];
    [updated removeObject:item];
    self.items = [updated copy];
    [self rebuildVisibleItemsAnimated:NO];
    completion(YES, @"تم حذف العنصر.");
}

- (void)restoreItemDirectly:(PVMediaVaultItem *)item completion:(void (^)(BOOL success, NSString *message))completion {
    NSError *verificationError = nil;
    if (![[PVMediaVaultStore sharedStore] verifyItem:item error:&verificationError]) { completion(NO, verificationError.localizedDescription ?: @"نسخة الوسائط غير مكتملة؛ بقيت نسخة PrivacyVault دون تغيير."); return; }
    PHAuthorizationStatus status;
    if (@available(iOS 14.0, *)) status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
    else status = [PHPhotoLibrary authorizationStatus];
    if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) { completion(NO, @"يلزم السماح بإضافة الوسائط إلى تطبيق الصور قبل الاسترداد."); return; }
    NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:item];
    __block NSString *createdIdentifier = nil;
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
        PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
        [request addResourceWithType:[item.type isEqualToString:@"video"] ? PHAssetResourceTypeVideo : PHAssetResourceTypePhoto fileURL:url options:options];
        createdIdentifier = request.placeholderForCreatedAsset.localIdentifier;
    } completionHandler:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success || createdIdentifier.length == 0) { completion(NO, error.localizedDescription ?: @"فشل الاسترداد؛ بقيت نسخة PrivacyVault دون تغيير."); return; }
            PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsWithLocalIdentifiers:@[createdIdentifier] options:nil];
            if (assets.count == 0) { completion(NO, @"تعذر التحقق من العنصر المسترد؛ بقيت نسخة PrivacyVault دون تغيير."); return; }
            NSError *removeError = nil;
            if (![[PVMediaVaultStore sharedStore] removeItem:item error:&removeError]) { completion(NO, @"تم الاسترداد، لكن تعذر إزالة نسخة PrivacyVault؛ بقيت النسخة للحماية."); return; }
            NSMutableArray *updated = [self.items mutableCopy];
            [updated removeObject:item];
            self.items = [updated copy];
            [self rebuildVisibleItemsAnimated:NO];
            completion(YES, @"تم استرداد العنصر إلى تطبيق الصور.");
        });
    }];
}

@end
