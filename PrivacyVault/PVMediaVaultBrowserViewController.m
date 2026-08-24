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
@property (nonatomic, strong) UIBarButtonItem *selectionBarButton;
@property (nonatomic, strong) UIVisualEffectView *selectionToolbar;
@property (nonatomic, strong) UIStackView *selectionStack;
@property (nonatomic, strong) UILabel *selectionCountLabel;
@property (nonatomic, strong) UIButton *selectAllButton;
@property (nonatomic, strong) UIButton *bulkRestoreButton;
@property (nonatomic, strong) UIButton *bulkDeleteButton;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedIdentifiers;
@property (nonatomic, assign) BOOL selectionMode;
@property (nonatomic, assign) BOOL bulkOperationInProgress;
@end

@implementation PVMediaVaultBrowserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.title = @"";
    self.navigationItem.backButtonTitle = @"";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.selectedIdentifiers = [NSMutableSet set];
    self.selectionBarButton = [[UIBarButtonItem alloc] initWithTitle:@"تحديد" style:UIBarButtonItemStylePlain target:self action:@selector(selectionButtonTapped:)];
    self.selectionBarButton.accessibilityLabel = @"الدخول إلى وضع التحديد";
    self.navigationItem.rightBarButtonItem = self.selectionBarButton;

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
    self.mediaSegmentedControl.hidden = self.mediaType.length > 0;

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

    UIBlurEffect *toolbarBlur = nil;
    if (@available(iOS 13.0, *)) toolbarBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    self.selectionToolbar = toolbarBlur ? [[UIVisualEffectView alloc] initWithEffect:toolbarBlur] : [[UIVisualEffectView alloc] initWithFrame:CGRectZero];
    self.selectionToolbar.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionToolbar.layer.cornerRadius = 18.0;
    self.selectionToolbar.clipsToBounds = YES;
    [self.view addSubview:self.selectionToolbar];

    self.bulkDeleteButton = [self selectionButtonWithTitle:@"حذف المحدد" action:@selector(bulkDeleteTapped:)];
    self.bulkRestoreButton = [self selectionButtonWithTitle:@"استرداد المحدد" action:@selector(bulkRestoreTapped:)];
    self.selectAllButton = [self selectionButtonWithTitle:@"تحديد الكل" action:@selector(selectAllTapped:)];
    self.selectionCountLabel = [[UILabel alloc] init];
    self.selectionCountLabel.textAlignment = NSTextAlignmentCenter;
    self.selectionCountLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    self.selectionCountLabel.textColor = [UIColor secondaryLabelColor];
    self.selectionCountLabel.numberOfLines = 2;
    self.selectionCountLabel.adjustsFontSizeToFitWidth = YES;
    self.selectionCountLabel.minimumScaleFactor = 0.72;
    self.selectionCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.bulkDeleteButton, self.bulkRestoreButton, self.selectionCountLabel, self.selectAllButton]];
    self.selectionStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionStack.axis = UILayoutConstraintAxisHorizontal;
    self.selectionStack.alignment = UIStackViewAlignmentFill;
    self.selectionStack.distribution = UIStackViewDistributionFillEqually;
    self.selectionStack.spacing = 2.0;
    self.selectionStack.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [self.selectionToolbar.contentView addSubview:self.selectionStack];

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
        [self.emptyLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24.0],
        [self.selectionToolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12.0],
        [self.selectionToolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12.0],
        [self.selectionToolbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10.0],
        [self.selectionToolbar.heightAnchor constraintEqualToConstant:58.0],
        [self.selectionStack.leadingAnchor constraintEqualToAnchor:self.selectionToolbar.contentView.leadingAnchor constant:6.0],
        [self.selectionStack.trailingAnchor constraintEqualToAnchor:self.selectionToolbar.contentView.trailingAnchor constant:-6.0],
        [self.selectionStack.topAnchor constraintEqualToAnchor:self.selectionToolbar.contentView.topAnchor constant:5.0],
        [self.selectionStack.bottomAnchor constraintEqualToAnchor:self.selectionToolbar.contentView.bottomAnchor constant:-5.0]
    ]];
    self.selectionToolbar.alpha = 0.0;
    self.selectionToolbar.hidden = YES;
    [self rebuildVisibleItemsAnimated:NO];
}

- (UIButton *)selectionButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.68;
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    [button setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor tertiaryLabelColor] forState:UIControlStateDisabled];
    button.accessibilityTraits = UIAccessibilityTraitButton;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self rebuildVisibleItemsAnimated:NO];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    if (sender.selectedSegmentIndex == self.selectedTab) return;
    self.selectedTab = sender.selectedSegmentIndex;
    [self.selectedIdentifiers removeAllObjects];
    [self rebuildVisibleItemsAnimated:YES];
}

- (void)rebuildVisibleItemsAnimated:(BOOL)animated {
    NSMutableArray<PVMediaVaultItem *> *filtered = [NSMutableArray array];
    for (PVMediaVaultItem *item in self.items) {
        BOOL matches = self.selectedTab == 0 || (self.selectedTab == 1 && [item.type isEqualToString:@"image"]) || (self.selectedTab == 2 && [item.type isEqualToString:@"video"]);
        if (matches) [filtered addObject:item];
    }
    self.visibleItems = [filtered copy];
    NSMutableSet *validIdentifiers = [NSMutableSet set];
    for (PVMediaVaultItem *item in self.visibleItems) [validIdentifiers addObject:[self identifierForItem:item]];
    [self.selectedIdentifiers intersectSet:validIdentifiers];
    self.emptyLabel.hidden = self.visibleItems.count > 0;
    [self updateSelectionUIAnimated:NO];
    if (animated) {
        [UIView transitionWithView:self.collectionView duration:0.16 options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState animations:^{ [self.collectionView reloadData]; } completion:nil];
    } else {
        [self.collectionView reloadData];
    }
}

- (NSString *)identifierForItem:(PVMediaVaultItem *)item {
    return item.identifier.length > 0 ? item.identifier : (item.path ?: @"");
}

- (BOOL)isItemSelected:(PVMediaVaultItem *)item {
    return [self.selectedIdentifiers containsObject:[self identifierForItem:item]];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView { return 1; }
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section { return self.visibleItems.count; }

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PVVaultGridCell" forIndexPath:indexPath];
    for (UIView *subview in [cell.contentView.subviews copy]) [subview removeFromSuperview];
    PVMediaVaultItem *item = self.visibleItems[indexPath.item];
    cell.accessibilityIdentifier = [self identifierForItem:item];
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
        shade.userInteractionEnabled = NO;
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
        durationLabel.userInteractionEnabled = NO;
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
    if (self.selectionMode) [self addSelectionIndicatorForItem:item toCell:cell];
    return cell;
}

- (void)addSelectionIndicatorForItem:(PVMediaVaultItem *)item toCell:(UICollectionViewCell *)cell {
    BOOL selected = [self isItemSelected:item];
    UIView *badge = [[UIView alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.tag = 8101;
    badge.backgroundColor = selected ? [UIColor systemBlueColor] : [UIColor colorWithWhite:0.0 alpha:0.30];
    badge.layer.cornerRadius = 13.0;
    badge.layer.borderWidth = 1.5;
    badge.layer.borderColor = UIColor.whiteColor.CGColor;
    badge.userInteractionEnabled = NO;
    [cell.contentView addSubview:badge];
    [NSLayoutConstraint activateConstraints:@[
        [badge.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:7.0],
        [badge.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-7.0],
        [badge.widthAnchor constraintEqualToConstant:26.0],
        [badge.heightAnchor constraintEqualToConstant:26.0]
    ]];
    if (selected) {
        UIImageView *check = nil;
        if (@available(iOS 13.0, *)) check = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark"]];
        if (!check) return;
        check.translatesAutoresizingMaskIntoConstraints = NO;
        check.tintColor = UIColor.whiteColor;
        check.contentMode = UIViewContentModeScaleAspectFit;
        [badge addSubview:check];
        [NSLayoutConstraint activateConstraints:@[
            [check.centerXAnchor constraintEqualToAnchor:badge.centerXAnchor],
            [check.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],
            [check.widthAnchor constraintEqualToConstant:14.0],
            [check.heightAnchor constraintEqualToConstant:14.0]
        ]];
    }
}

- (UIImage *)cachedThumbnailForItem:(PVMediaVaultItem *)item {
    return [PVBrowserThumbnailCache() objectForKey:[self identifierForItem:item]];
}

- (void)loadThumbnailForItem:(PVMediaVaultItem *)item intoImageView:(UIImageView *)imageView cell:(UICollectionViewCell *)cell {
    NSString *key = [self identifierForItem:item];
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
            if ([cell.accessibilityIdentifier isEqualToString:key] && thumbnail) imageView.image = thumbnail;
        });
    });
}

- (NSString *)cachedDurationForItem:(PVMediaVaultItem *)item {
    return [PVBrowserDurationCache() objectForKey:[self identifierForItem:item]];
}

- (void)loadDurationForItem:(PVMediaVaultItem *)item intoLabel:(UILabel *)label cell:(UICollectionViewCell *)cell {
    NSString *key = [self identifierForItem:item];
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
            if ([cell.accessibilityIdentifier isEqualToString:key]) label.text = [NSString stringWithFormat:@"▶ %@", duration];
        });
    });
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *)layout;
    CGFloat width = CGRectGetWidth(collectionView.bounds) - flowLayout.sectionInset.left - flowLayout.sectionInset.right - flowLayout.minimumInteritemSpacing * 2.0;
    CGFloat side = floor(width / 3.0);
    return CGSizeMake(side, side);
}

- (void)selectionButtonTapped:(UIBarButtonItem *)sender {
    if (self.bulkOperationInProgress) return;
    if (self.selectionMode) [self exitSelectionMode];
    else [self enterSelectionMode];
}

- (void)enterSelectionMode {
    self.selectionMode = YES;
    [self.selectedIdentifiers removeAllObjects];
    self.selectionBarButton.title = @"إلغاء";
    self.selectionBarButton.accessibilityLabel = @"الخروج من وضع التحديد";
    [self.collectionView reloadData];
    [self updateSelectionUIAnimated:YES];
}

- (void)exitSelectionMode {
    if (self.bulkOperationInProgress) return;
    self.selectionMode = NO;
    [self.selectedIdentifiers removeAllObjects];
    self.selectionBarButton.title = @"تحديد";
    self.selectionBarButton.accessibilityLabel = @"الدخول إلى وضع التحديد";
    [self.collectionView reloadData];
    [self updateSelectionUIAnimated:YES];
}

- (void)updateSelectionUIAnimated:(BOOL)animated {
    NSUInteger count = self.selectedIdentifiers.count;
    NSUInteger total = self.visibleItems.count;
    self.selectionCountLabel.text = count == 0 ? @"لم يتم تحديد أي عنصر" : [NSString stringWithFormat:@"تم تحديد %lu عنصر", (unsigned long)count];
    self.selectAllButton.enabled = total > 0 && !self.bulkOperationInProgress;
    self.bulkDeleteButton.enabled = count > 0 && !self.bulkOperationInProgress;
    self.bulkRestoreButton.enabled = count > 0 && !self.bulkOperationInProgress;
    BOOL allSelected = total > 0 && count == total;
    [self.bulkDeleteButton setTitle:allSelected ? @"حذف الكل" : @"حذف المحدد" forState:UIControlStateNormal];
    [self.bulkRestoreButton setTitle:allSelected ? @"استرداد الكل" : @"استرداد المحدد" forState:UIControlStateNormal];
    [self.selectAllButton setTitle:allSelected ? @"إلغاء تحديد الكل" : @"تحديد الكل" forState:UIControlStateNormal];
    if (!self.selectionMode) {
        self.selectionToolbar.hidden = YES;
        self.selectionToolbar.alpha = 0.0;
        return;
    }
    self.selectionToolbar.hidden = NO;
    void (^changes)(void) = ^{ self.selectionToolbar.alpha = 1.0; };
    if (animated) [UIView animateWithDuration:0.18 animations:changes];
    else changes();
}

- (void)selectAllTapped:(UIButton *)sender {
    if (!self.selectionMode || self.bulkOperationInProgress) return;
    BOOL shouldClear = self.visibleItems.count > 0 && self.selectedIdentifiers.count == self.visibleItems.count;
    if (shouldClear) [self.selectedIdentifiers removeAllObjects];
    else for (PVMediaVaultItem *item in self.visibleItems) [self.selectedIdentifiers addObject:[self identifierForItem:item]];
    [self.collectionView reloadData];
    [self updateSelectionUIAnimated:YES];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item >= self.visibleItems.count) return;
    PVMediaVaultItem *item = self.visibleItems[indexPath.item];
    if (self.selectionMode) {
        NSString *identifier = [self identifierForItem:item];
        if ([self.selectedIdentifiers containsObject:identifier]) [self.selectedIdentifiers removeObject:identifier];
        else [self.selectedIdentifiers addObject:identifier];
        [collectionView reloadItemsAtIndexPaths:@[indexPath]];
        [self updateSelectionUIAnimated:YES];
        return;
    }
    PVMediaVaultPreviewViewController *preview = [[PVMediaVaultPreviewViewController alloc] init];
    preview.item = item;
    preview.items = self.visibleItems;
    preview.initialIndex = indexPath.item;
    UICollectionViewCell *selectedCell = [collectionView cellForItemAtIndexPath:indexPath];
    UIImageView *selectedImageView = (UIImageView *)[selectedCell.contentView viewWithTag:8100];
    NSMutableDictionary<NSString *, UIImage *> *preloadedThumbnails = [NSMutableDictionary dictionary];
    for (PVMediaVaultItem *candidate in self.visibleItems) {
        UIImage *cached = [PVBrowserThumbnailCache() objectForKey:[self identifierForItem:candidate]];
        if (cached && candidate.identifier.length > 0) preloadedThumbnails[candidate.identifier] = cached;
    }
    if (selectedImageView.image && item.identifier.length > 0) preloadedThumbnails[item.identifier] = selectedImageView.image;
    preview.thumbnailCache = [preloadedThumbnails copy];
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

- (NSArray<PVMediaVaultItem *> *)selectedItemsSnapshot {
    NSMutableArray<PVMediaVaultItem *> *result = [NSMutableArray array];
    for (PVMediaVaultItem *item in self.visibleItems) if ([self isItemSelected:item]) [result addObject:item];
    return [result copy];
}

- (void)bulkDeleteTapped:(UIButton *)sender {
    if (self.bulkOperationInProgress) return;
    NSArray<PVMediaVaultItem *> *selected = [self selectedItemsSnapshot];
    if (selected.count == 0) return;
    NSString *title = [NSString stringWithFormat:@"حذف %lu عنصرًا؟", (unsigned long)selected.count];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:@"سيتم حذف النسخ الموجودة داخل PrivacyVault فقط." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"حذف" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [weakSelf performBulkDelete:selected];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performBulkDelete:(NSArray<PVMediaVaultItem *> *)selected {
    self.bulkOperationInProgress = YES;
    [self updateSelectionUIAnimated:NO];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSMutableArray<PVMediaVaultItem *> *succeeded = [NSMutableArray array];
        NSMutableArray<NSString *> *failures = [NSMutableArray array];
        for (PVMediaVaultItem *item in selected) {
            NSError *error = nil;
            if ([[PVMediaVaultStore sharedStore] removeItem:item error:&error]) [succeeded addObject:item];
            else [failures addObject:error.localizedDescription ?: @"تعذر حذف عنصر واحد"];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableArray *updated = [self.items mutableCopy];
            for (PVMediaVaultItem *item in succeeded) {
                [updated removeObject:item];
                [self.selectedIdentifiers removeObject:[self identifierForItem:item]];
            }
            self.items = [updated copy];
            self.bulkOperationInProgress = NO;
            [self rebuildVisibleItemsAnimated:NO];
            if (failures.count > 0) {
                [self showBulkResultWithSuccess:succeeded.count failureCount:failures.count action:@"الحذف"];
            } else {
                [self exitSelectionMode];
            }
        });
    });
}

- (void)bulkRestoreTapped:(UIButton *)sender {
    if (self.bulkOperationInProgress) return;
    NSArray<PVMediaVaultItem *> *selected = [self selectedItemsSnapshot];
    if (selected.count == 0) return;
    NSString *title = [NSString stringWithFormat:@"استرداد %lu عنصرًا؟", (unsigned long)selected.count];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:@"سيتم استرداد العناصر المحددة إلى تطبيق الصور بعد التحقق من كل عنصر." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"استرداد" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf performBulkRestore:selected];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performBulkRestore:(NSArray<PVMediaVaultItem *> *)selected {
    self.bulkOperationInProgress = YES;
    [self updateSelectionUIAnimated:NO];
    [self restoreItemsSequentially:selected index:0 successCount:0 failureCount:0];
}

- (void)restoreItemsSequentially:(NSArray<PVMediaVaultItem *> *)items index:(NSUInteger)index successCount:(NSUInteger)successCount failureCount:(NSUInteger)failureCount {
    if (index >= items.count) {
        self.bulkOperationInProgress = NO;
        [self updateSelectionUIAnimated:NO];
        if (failureCount > 0) [self showBulkResultWithSuccess:successCount failureCount:failureCount action:@"الاسترداد"];
        else [self exitSelectionMode];
        return;
    }
    PVMediaVaultItem *item = items[index];
    __weak typeof(self) weakSelf = self;
    [self restoreItemDirectly:item completion:^(BOOL success, NSString *message) {
        PVMediaVaultBrowserViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        NSUInteger nextSuccessCount = success ? successCount + 1 : successCount;
        NSUInteger nextFailureCount = success ? failureCount : failureCount + 1;
        if (success) [strongSelf.selectedIdentifiers removeObject:[strongSelf identifierForItem:item]];
        [strongSelf restoreItemsSequentially:items index:index + 1 successCount:nextSuccessCount failureCount:nextFailureCount];
    }];
}

- (void)showBulkResultWithSuccess:(NSUInteger)successCount failureCount:(NSUInteger)failureCount action:(NSString *)action {
    [self updateSelectionUIAnimated:NO];
    NSString *message = [NSString stringWithFormat:@"اكتمل %@ لـ%lu عنصر، وفشل لـ%lu عنصر. العناصر الفاشلة بقيت محفوظة.", action, (unsigned long)successCount, (unsigned long)failureCount];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"نتيجة العملية" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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
