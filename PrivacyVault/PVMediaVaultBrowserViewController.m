#import "PVMediaVaultBrowserViewController.h"
#import <QuickLook/QuickLook.h>

@interface PVMediaVaultBrowserViewController () <UICollectionViewDataSource, UICollectionViewDelegate, QLPreviewControllerDataSource>
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
    layout.minimumInteritemSpacing = 8.0;
    layout.minimumLineSpacing = 12.0;
    layout.sectionInset = UIEdgeInsetsMake(16, 12, 24, 12);
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
    self.emptyLabel.hidden = self.items.count > 0;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.emptyLabel.hidden = self.items.count > 0;
    [self.collectionView reloadData];
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
    cell.layer.cornerRadius = 14.0;
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

    UIButton *restoreButton = [UIButton buttonWithType:UIButtonTypeSystem];
    restoreButton.translatesAutoresizingMaskIntoConstraints = NO;
    [restoreButton setTitle:@"استرداد" forState:UIControlStateNormal];
    restoreButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    restoreButton.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.9];
    restoreButton.layer.cornerRadius = 8.0;
    restoreButton.tag = indexPath.item;
    [restoreButton addTarget:self action:@selector(restoreTapped:) forControlEvents:UIControlEventTouchUpInside];
    [cell.contentView addSubview:restoreButton];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.text = item.filename;
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    nameLabel.textColor = [UIColor labelColor];
    nameLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [cell.contentView addSubview:nameLabel];

    [NSLayoutConstraint activateConstraints:@[
        [imageView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
        [imageView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
        [imageView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
        [imageView.bottomAnchor constraintEqualToAnchor:nameLabel.topAnchor constant:-4],
        [nameLabel.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:4],
        [nameLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-4],
        [nameLabel.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-5],
        [restoreButton.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:6],
        [restoreButton.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:6],
        [restoreButton.heightAnchor constraintEqualToConstant:28],
        [restoreButton.widthAnchor constraintEqualToConstant:58]
    ]];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *)layout;
    CGFloat availableWidth = CGRectGetWidth(collectionView.bounds) - flowLayout.sectionInset.left - flowLayout.sectionInset.right - (flowLayout.minimumInteritemSpacing * 2.0);
    CGFloat width = floor(availableWidth / 3.0);
    return CGSizeMake(MAX(width, 90.0), 132.0);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item >= self.items.count) return;
    self.previewItem = self.items[indexPath.item];
    self.previewController = [[QLPreviewController alloc] init];
    self.previewController.dataSource = self;
    [self presentViewController:self.previewController animated:YES completion:nil];
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return self.previewItem ? 1 : 0;
}

- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    return [self urlForPreviewItem:self.previewItem];
}

- (NSURL *)urlForPreviewItem:(PVMediaVaultItem *)item {
    return [[PVMediaVaultStore sharedStore] urlForItem:item];
}

- (void)restoreTapped:(UIButton *)sender {
    if (sender.tag >= self.items.count) return;
    if (self.restoreHandler) self.restoreHandler(self.items[sender.tag]);
}

@end
