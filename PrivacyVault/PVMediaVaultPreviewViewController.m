#import "PVMediaVaultPreviewViewController.h"
#import <AVKit/AVKit.h>

@interface PVMediaVaultPreviewViewController () <UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *pagingScrollView;
@property (nonatomic, strong) NSMutableArray<UIView *> *pageViews;
@property (nonatomic, strong) UILabel *counterLabel;
@property (nonatomic, strong) UIVisualEffectView *actionBar;
@property (nonatomic, strong) UIButton *restoreButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) UIButton *infoButton;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) AVPlayerViewController *activePlayerController;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) BOOL didSetInitialOffset;
@property (nonatomic, assign) BOOL restoring;
@end

@implementation PVMediaVaultPreviewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.navigationItem.hidesBackButton = YES;
    self.currentIndex = MAX(0, MIN(self.initialIndex, (NSInteger)self.items.count - 1));
    self.pageViews = [NSMutableArray array];

    self.pagingScrollView = [[UIScrollView alloc] init];
    self.pagingScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.pagingScrollView.backgroundColor = UIColor.blackColor;
    self.pagingScrollView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    self.pagingScrollView.pagingEnabled = YES;
    self.pagingScrollView.delegate = self;
    self.pagingScrollView.showsHorizontalScrollIndicator = NO;
    self.pagingScrollView.showsVerticalScrollIndicator = NO;
    self.pagingScrollView.directionalLockEnabled = YES;
    self.pagingScrollView.alwaysBounceVertical = NO;
    [self.view addSubview:self.pagingScrollView];

    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    backButton.translatesAutoresizingMaskIntoConstraints = NO;
    backButton.accessibilityLabel = @"رجوع";
    if (@available(iOS 13.0, *)) [backButton setImage:[UIImage systemImageNamed:@"chevron.backward"] forState:UIControlStateNormal];
    else [backButton setTitle:@"‹" forState:UIControlStateNormal];
    backButton.tintColor = UIColor.whiteColor;
    backButton.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.82];
    backButton.layer.cornerRadius = 21.0;
    [backButton addTarget:self action:@selector(backTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:backButton];

    self.counterLabel = [[UILabel alloc] init];
    self.counterLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.counterLabel.textAlignment = NSTextAlignmentCenter;
    self.counterLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.90];
    self.counterLabel.font = [UIFont monospacedDigitSystemFontOfSize:14.0 weight:UIFontWeightSemibold];
    self.counterLabel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.72];
    self.counterLabel.layer.cornerRadius = 15.0;
    self.counterLabel.clipsToBounds = YES;
    [self.view addSubview:self.counterLabel];

    UIBlurEffect *blur = nil;
    if (@available(iOS 13.0, *)) blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
    self.actionBar = blur ? [[UIVisualEffectView alloc] initWithEffect:blur] : [[UIVisualEffectView alloc] initWithFrame:CGRectZero];
    self.actionBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionBar.layer.cornerRadius = 34.0;
    self.actionBar.clipsToBounds = YES;
    [self.view addSubview:self.actionBar];

    self.restoreButton = [self makeIconButton:@"arrow.uturn.backward.circle" label:@"استرداد" action:@selector(restoreTapped:)];
    self.infoButton = [self makeIconButton:@"info.circle" label:@"معلومات" action:@selector(infoTapped:)];
    self.shareButton = [self makeIconButton:@"square.and.arrow.up" label:@"مشاركة" action:@selector(shareTapped:)];
    self.shareButton.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.90];
    self.shareButton.layer.cornerRadius = 34.0;
    self.shareButton.clipsToBounds = YES;
    [self.actionBar.contentView addSubview:self.restoreButton];
    [self.actionBar.contentView addSubview:self.infoButton];
    [self.view addSubview:self.shareButton];

    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.color = UIColor.whiteColor;
    self.activityIndicator.hidden = YES;
    [self.actionBar.contentView addSubview:self.activityIndicator];

    [NSLayoutConstraint activateConstraints:@[
        [self.pagingScrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.pagingScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.pagingScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.pagingScrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [backButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12.0],
        [backButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14.0],
        [backButton.widthAnchor constraintEqualToConstant:42.0],
        [backButton.heightAnchor constraintEqualToConstant:42.0],
        [self.counterLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:18.0],
        [self.counterLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.counterLabel.widthAnchor constraintGreaterThanOrEqualToConstant:66.0],
        [self.counterLabel.heightAnchor constraintEqualToConstant:30.0],
        [self.actionBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:76.0],
        [self.actionBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-76.0],
        [self.actionBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-14.0],
        [self.actionBar.heightAnchor constraintEqualToConstant:68.0],
        [self.restoreButton.leadingAnchor constraintEqualToAnchor:self.actionBar.contentView.leadingAnchor constant:12.0],
        [self.restoreButton.topAnchor constraintEqualToAnchor:self.actionBar.contentView.topAnchor constant:4.0],
        [self.restoreButton.bottomAnchor constraintEqualToAnchor:self.actionBar.contentView.bottomAnchor constant:-4.0],
        [self.restoreButton.widthAnchor constraintEqualToConstant:94.0],
        [self.infoButton.centerXAnchor constraintEqualToAnchor:self.actionBar.contentView.centerXAnchor],
        [self.infoButton.topAnchor constraintEqualToAnchor:self.actionBar.contentView.topAnchor constant:4.0],
        [self.infoButton.bottomAnchor constraintEqualToAnchor:self.actionBar.contentView.bottomAnchor constant:-4.0],
        [self.infoButton.widthAnchor constraintEqualToConstant:94.0],
        [self.shareButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18.0],
        [self.shareButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-14.0],
        [self.shareButton.widthAnchor constraintEqualToConstant:62.0],
        [self.shareButton.heightAnchor constraintEqualToConstant:68.0],
        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.actionBar.contentView.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.actionBar.contentView.centerYAnchor]
    ]];

    [self buildPages];
    [self updateCounter];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize pageSize = self.pagingScrollView.bounds.size;
    self.pagingScrollView.contentSize = CGSizeMake(pageSize.width * self.pageViews.count, pageSize.height);
    [self.pageViews enumerateObjectsUsingBlock:^(UIView *page, NSUInteger index, BOOL *stop) {
        page.frame = CGRectMake(pageSize.width * index, 0.0, pageSize.width, pageSize.height);
    }];
    if (!self.didSetInitialOffset && pageSize.width > 0.0 && self.pageViews.count > 0) {
        self.didSetInitialOffset = YES;
        [self.pagingScrollView setContentOffset:CGPointMake(pageSize.width * self.currentIndex, 0.0) animated:NO];
        [self activateCurrentPage];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [self activateCurrentPage];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopActivePlayer];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)buildPages {
    for (UIView *page in self.pageViews) [page removeFromSuperview];
    [self.pageViews removeAllObjects];
    for (PVMediaVaultItem *item in self.items) {
        UIView *page = [[UIView alloc] initWithFrame:CGRectZero];
        page.backgroundColor = UIColor.blackColor;
        page.tag = 7000 + self.pageViews.count;
        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.tag = 7100;
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.backgroundColor = UIColor.blackColor;
        imageView.clipsToBounds = YES;
        [page addSubview:imageView];
        [NSLayoutConstraint activateConstraints:@[
            [imageView.topAnchor constraintEqualToAnchor:page.topAnchor],
            [imageView.leadingAnchor constraintEqualToAnchor:page.leadingAnchor],
            [imageView.trailingAnchor constraintEqualToAnchor:page.trailingAnchor],
            [imageView.bottomAnchor constraintEqualToAnchor:page.bottomAnchor]
        ]];
        if ([item.type isEqualToString:@"video"]) {
            if (@available(iOS 13.0, *)) {
                imageView.image = [UIImage systemImageNamed:@"video.fill"];
                imageView.tintColor = [UIColor colorWithWhite:0.60 alpha:1.0];
            }
        }
        [self.pagingScrollView addSubview:page];
        [self.pageViews addObject:page];
    }
}

- (UIButton *)makeIconButton:(NSString *)symbol label:(NSString *)label action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = [UIColor colorWithRed:0.12 green:0.56 blue:1.0 alpha:1.0];
    button.accessibilityLabel = label;
    if (@available(iOS 13.0, *)) {
        [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    }
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)updateCounter {
    self.counterLabel.text = self.items.count > 0 ? [NSString stringWithFormat:@"%ld / %lu", (long)self.currentIndex + 1, (unsigned long)self.items.count] : @"0";
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self updateCurrentIndexFromScrollPosition];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self updateCurrentIndexFromScrollPosition];
}

- (void)updateCurrentIndexFromScrollPosition {
    CGFloat width = self.pagingScrollView.bounds.size.width;
    if (width <= 0.0 || self.pageViews.count == 0) return;
    NSInteger newIndex = (NSInteger)llround(self.pagingScrollView.contentOffset.x / width);
    newIndex = MAX(0, MIN(newIndex, (NSInteger)self.pageViews.count - 1));
    if (newIndex != self.currentIndex) {
        [self stopActivePlayer];
        self.currentIndex = newIndex;
        self.item = self.items[newIndex];
        [self updateCounter];
        [self activateCurrentPage];
    }
}

- (void)activateCurrentPage {
    if (self.currentIndex < 0 || self.currentIndex >= self.items.count) return;
    PVMediaVaultItem *item = self.items[self.currentIndex];
    UIView *page = self.pageViews[self.currentIndex];
    UIImageView *imageView = [page viewWithTag:7100];
    if ([item.type isEqualToString:@"video"]) {
        [self stopActivePlayer];
        NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:item];
        if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) return;
        self.activePlayerController = [[AVPlayerViewController alloc] init];
        self.activePlayerController.view.backgroundColor = UIColor.blackColor;
        self.activePlayerController.showsPlaybackControls = YES;
        self.activePlayerController.player = [AVPlayer playerWithURL:url];
        [self addChildViewController:self.activePlayerController];
        self.activePlayerController.view.frame = page.bounds;
        self.activePlayerController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [page addSubview:self.activePlayerController.view];
        [self.activePlayerController didMoveToParentViewController:self];
        [self.activePlayerController.player play];
    } else {
        [self loadImageForItem:item intoImageView:imageView];
    }
}

- (void)loadImageForItem:(PVMediaVaultItem *)item intoImageView:(UIImageView *)imageView {
    NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:item];
    imageView.image = nil;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *image = [UIImage imageWithContentsOfFile:url.path];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (imageView.superview) imageView.image = image;
        });
    });
}

- (void)stopActivePlayer {
    [self.activePlayerController.player pause];
    [self.activePlayerController willMoveToParentViewController:nil];
    [self.activePlayerController.view removeFromSuperview];
    [self.activePlayerController removeFromParentViewController];
    self.activePlayerController = nil;
}

- (void)backTapped:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)shareTapped:(UIButton *)sender {
    if (self.restoring || self.currentIndex >= self.items.count) return;
    NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:self.items[self.currentIndex]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        [self showMessage:@"تعذر العثور على ملف الوسائط داخل PrivacyVault."];
        return;
    }
    UIActivityViewController *shareController = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        shareController.popoverPresentationController.sourceView = self.shareButton;
        shareController.popoverPresentationController.sourceRect = self.shareButton.bounds;
    }
    [self presentViewController:shareController animated:YES completion:nil];
}

- (void)infoTapped:(UIButton *)sender {
    if (self.currentIndex >= self.items.count) return;
    PVMediaVaultItem *item = self.items[self.currentIndex];
    NSString *type = [item.type isEqualToString:@"video"] ? @"فيديو" : @"صورة";
    NSString *message = [NSString stringWithFormat:@"النوع: %@\nتم حفظه داخل PrivacyVault بأمان.", type];
    [self showMessage:message];
}

- (void)restoreTapped:(UIButton *)sender {
    if (self.restoring || self.currentIndex >= self.items.count || !self.restoreHandler) return;
    self.restoring = YES;
    self.restoreButton.enabled = NO;
    self.shareButton.enabled = NO;
    self.infoButton.enabled = NO;
    self.activityIndicator.hidden = NO;
    [self.activityIndicator startAnimating];
    PVMediaVaultItem *restoreItem = self.items[self.currentIndex];
    __weak typeof(self) weakSelf = self;
    self.restoreHandler(restoreItem, ^(BOOL success, NSString *message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.activityIndicator stopAnimating];
            self.activityIndicator.hidden = YES;
            self.restoring = NO;
            self.restoreButton.enabled = YES;
            self.shareButton.enabled = YES;
            self.infoButton.enabled = YES;
            if (success) {
                [self.navigationController popViewControllerAnimated:YES];
            } else {
                [self showMessage:message ?: @"فشل الاسترداد؛ بقيت نسخة PrivacyVault دون تغيير."];
            }
        });
    });
}

- (void)showMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"PrivacyVault" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
