#import "PVMediaVaultPreviewViewController.h"
#import <AVKit/AVKit.h>

@interface PVMediaInfoSheetViewController : UIViewController
@property (nonatomic, strong) PVMediaVaultItem *item;
@end

@implementation PVMediaInfoSheetViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.title = @"معلومات العنصر";

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 16.0;
    [self.view addSubview:stack];

    UILabel *header = [[UILabel alloc] init];
    header.text = @"معلومات العنصر";
    header.textAlignment = NSTextAlignmentRight;
    header.font = [UIFont systemFontOfSize:24.0 weight:UIFontWeightBold];
    [stack addArrangedSubview:header];

    UILabel *filename = [[UILabel alloc] init];
    filename.text = [NSString stringWithFormat:@"الاسم\n%@", self.item.filename ?: @"غير معروف"];
    filename.numberOfLines = 0;
    filename.textAlignment = NSTextAlignmentRight;
    filename.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    [stack addArrangedSubview:filename];

    NSString *type = [self.item.type isEqualToString:@"video"] ? @"فيديو" : @"صورة";
    double megabytes = ((double)self.item.byteSize / 1024.0 / 1024.0);
    UILabel *details = [[UILabel alloc] init];
    details.text = [NSString stringWithFormat:@"النوع: %@\nالحجم: %.2f ميغابايت\nالحالة: محفوظ داخل PrivacyVault", type, megabytes];
    details.numberOfLines = 0;
    details.textAlignment = NSTextAlignmentRight;
    details.textColor = [UIColor secondaryLabelColor];
    details.font = [UIFont systemFontOfSize:16.0];
    [stack addArrangedSubview:details];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeButton setTitle:@"تم" forState:UIControlStateNormal];
    closeButton.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    [closeButton addTarget:self action:@selector(closeTapped:) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:closeButton];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0],
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24.0]
    ]];
    self.preferredContentSize = CGSizeMake(UIViewNoIntrinsicMetric, 270.0);
}

- (void)closeTapped:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@interface PVMediaZoomAnimator : NSObject <UIViewControllerAnimatedTransitioning>
@property (nonatomic, assign) BOOL presenting;
@end

@implementation PVMediaZoomAnimator

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return 0.28;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIView *container = transitionContext.containerView;
    UIViewController *appearing = self.presenting ? toViewController : fromViewController;
    UIViewController *underlying = self.presenting ? fromViewController : toViewController;
    if (self.presenting) [container addSubview:toViewController.view];
    else [container insertSubview:toViewController.view belowSubview:fromViewController.view];

    PVMediaVaultPreviewViewController *preview = (PVMediaVaultPreviewViewController *)(self.presenting ? toViewController : fromViewController);
    UIImageView *transitionImageView = nil;
    if (preview.transitionImage) {
        transitionImageView = [[UIImageView alloc] initWithImage:preview.transitionImage];
        transitionImageView.contentMode = UIViewContentModeScaleAspectFill;
        transitionImageView.clipsToBounds = YES;
        transitionImageView.backgroundColor = UIColor.blackColor;
        CGRect sourceFrame = [underlying.view convertRect:preview.transitionFrame toView:container];
        transitionImageView.frame = self.presenting ? sourceFrame : appearing.view.bounds;
        [container addSubview:transitionImageView];
    }

    if (self.presenting) {
        toViewController.view.alpha = 0.0;
        [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            toViewController.view.alpha = 1.0;
            if (transitionImageView) transitionImageView.frame = toViewController.view.bounds;
        } completion:^(BOOL finished) {
            [transitionImageView removeFromSuperview];
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
    } else {
        fromViewController.view.alpha = 1.0;
        CGRect sourceFrame = [underlying.view convertRect:preview.transitionFrame toView:container];
        [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            fromViewController.view.alpha = 0.0;
            if (transitionImageView) transitionImageView.frame = sourceFrame;
        } completion:^(BOOL finished) {
            [transitionImageView removeFromSuperview];
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
    }
}

@end

@interface PVMediaVaultPreviewViewController () <UIScrollViewDelegate, UIViewControllerTransitioningDelegate>
@property (nonatomic, strong) UIScrollView *pagingScrollView;
@property (nonatomic, strong) NSMutableArray<UIView *> *pageViews;
@property (nonatomic, strong) UILabel *counterLabel;
@property (nonatomic, strong) UIVisualEffectView *actionBar;
@property (nonatomic, strong) UIButton *restoreButton;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) UIButton *infoButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) AVPlayerViewController *activePlayerController;
@property (nonatomic, strong) AVPlayerItem *pendingPlayerItem;
@property (nonatomic, assign) NSInteger activePlayerIndex;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) BOOL didSetInitialOffset;
@property (nonatomic, assign) BOOL controlsVisible;
@property (nonatomic, assign) BOOL restoring;
@end

@implementation PVMediaVaultPreviewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.modalPresentationStyle = UIModalPresentationFullScreen;
    self.transitioningDelegate = self;
    self.view.backgroundColor = UIColor.blackColor;
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.navigationItem.hidesBackButton = YES;
    self.activePlayerIndex = NSNotFound;
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
    self.deleteButton = [self makeIconButton:@"trash" label:@"حذف" action:@selector(deleteTapped:)];
    self.infoButton = [self makeIconButton:@"info.circle" label:@"معلومات" action:@selector(infoTapped:)];
    self.shareButton = [self makeIconButton:@"square.and.arrow.up" label:@"مشاركة" action:@selector(shareTapped:)];
    self.shareButton.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.90];
    self.shareButton.layer.cornerRadius = 34.0;
    self.shareButton.clipsToBounds = YES;
    [self.actionBar.contentView addSubview:self.restoreButton];
    [self.actionBar.contentView addSubview:self.deleteButton];
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
        [self.restoreButton.leadingAnchor constraintEqualToAnchor:self.actionBar.contentView.leadingAnchor constant:6.0],
        [self.restoreButton.topAnchor constraintEqualToAnchor:self.actionBar.contentView.topAnchor constant:4.0],
        [self.restoreButton.bottomAnchor constraintEqualToAnchor:self.actionBar.contentView.bottomAnchor constant:-4.0],
        [self.restoreButton.widthAnchor constraintEqualToConstant:78.0],
        [self.deleteButton.centerXAnchor constraintEqualToAnchor:self.actionBar.contentView.centerXAnchor],
        [self.deleteButton.topAnchor constraintEqualToAnchor:self.actionBar.contentView.topAnchor constant:4.0],
        [self.deleteButton.bottomAnchor constraintEqualToAnchor:self.actionBar.contentView.bottomAnchor constant:-4.0],
        [self.deleteButton.widthAnchor constraintEqualToConstant:78.0],
        [self.infoButton.trailingAnchor constraintEqualToAnchor:self.actionBar.contentView.trailingAnchor constant:-6.0],
        [self.infoButton.topAnchor constraintEqualToAnchor:self.actionBar.contentView.topAnchor constant:4.0],
        [self.infoButton.bottomAnchor constraintEqualToAnchor:self.actionBar.contentView.bottomAnchor constant:-4.0],
        [self.infoButton.widthAnchor constraintEqualToConstant:78.0],
        [self.shareButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18.0],
        [self.shareButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-14.0],
        [self.shareButton.widthAnchor constraintEqualToConstant:62.0],
        [self.shareButton.heightAnchor constraintEqualToConstant:68.0],
        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.actionBar.contentView.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.actionBar.contentView.centerYAnchor]
    ]];

    self.actionBar.alpha = 0.0;
    self.shareButton.alpha = 0.0;
    self.controlsVisible = NO;
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
        [self preloadAdjacentPages];
    }
}

- (void)buildPages {
    for (UIView *page in self.pageViews) [page removeFromSuperview];
    [self.pageViews removeAllObjects];
    for (PVMediaVaultItem *item in self.items) {
        UIView *page = [[UIView alloc] initWithFrame:CGRectZero];
        page.backgroundColor = UIColor.blackColor;
        page.tag = 7000 + self.pageViews.count;
        page.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(contentTapped:)];
        tap.cancelsTouchesInView = NO;
        [page addGestureRecognizer:tap];
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
    [self preloadAdjacentPages];
}

- (UIButton *)makeIconButton:
(NSString *)symbol label:(NSString *)label action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = [UIColor colorWithRed:0.12 green:0.56 blue:1.0 alpha:1.0];
    button.accessibilityLabel = label;
    if (@available(iOS 13.0, *)) [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)updateCounter {
    self.counterLabel.text = self.items.count > 0 ? [NSString stringWithFormat:@"%ld / %lu", (long)self.currentIndex + 1, (unsigned long)self.items.count] : @"0";
}

- (void)contentTapped:(UITapGestureRecognizer *)gesture {
    if (self.restoring) return;
    [self setControlsVisible:!self.controlsVisible animated:YES];
}

- (void)setControlsVisible:(BOOL)visible animated:(BOOL)animated {
    self.controlsVisible = visible;
    void (^changes)(void) = ^{
        self.actionBar.alpha = visible ? 1.0 : 0.0;
        self.shareButton.alpha = visible ? 1.0 : 0.0;
    };
    if (animated) [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:changes completion:nil];
    else changes();
    if (visible && self.currentIndex >= 0 && self.currentIndex < self.items.count && [self.items[self.currentIndex].type isEqualToString:@"video"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.controlsVisible && !self.restoring) [self setControlsVisible:NO animated:YES];
        });
    }
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
        [self setControlsVisible:NO animated:YES];
        [self activateCurrentPage];
    }
}

- (void)activateCurrentPage {
    if (self.currentIndex < 0 || self.currentIndex >= self.items.count) return;
    PVMediaVaultItem *item = self.items[self.currentIndex];
    UIView *page = self.pageViews[self.currentIndex];
    UIImageView *imageView = [page viewWithTag:7100];
    if ([item.type isEqualToString:@"video"]) {
        if (self.activePlayerController && self.activePlayerIndex == self.currentIndex) return;
        [self stopActivePlayer];
        NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:item];
        if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) return;
        self.activePlayerController = [[AVPlayerViewController alloc] init];
        self.activePlayerIndex = self.currentIndex;
        self.activePlayerController.view.backgroundColor = UIColor.clearColor;
        self.activePlayerController.showsPlaybackControls = YES;
        self.pendingPlayerItem = [AVPlayerItem playerItemWithURL:url];
        [self.pendingPlayerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionInitial context:NULL];
        self.activePlayerController.player = [AVPlayer playerWithPlayerItem:self.pendingPlayerItem];
    } else {
        [self loadImageForItem:item intoImageView:imageView];
    }
}

- (void)preloadAdjacentPages {
    if (self.items.count == 0) return;
    NSInteger first = MAX(0, self.currentIndex - 1);
    NSInteger last = MIN((NSInteger)self.items.count - 1, self.currentIndex + 1);
    for (NSInteger index = first; index <= last; index++) {
        PVMediaVaultItem *item = self.items[index];
        UIView *page = self.pageViews[index];
        UIImageView *imageView = [page viewWithTag:7100];
        if ([item.type isEqualToString:@"video"]) [self loadVideoPreviewForItem:item intoImageView:imageView];
        else [self loadImageForItem:item intoImageView:imageView];
    }
}

- (void)loadVideoPreviewForItem:(PVMediaVaultItem *)item intoImageView:(UIImageView *)imageView {
    NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:item];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        AVAsset *asset = [AVAsset assetWithURL:url];
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        generator.maximumSize = CGSizeMake(1440.0, 1440.0);
        CGImageRef imageRef = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(0.05, 600) actualTime:NULL error:NULL];
        UIImage *image = imageRef ? [UIImage imageWithCGImage:imageRef] : nil;
        if (imageRef) CGImageRelease(imageRef);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (image && imageView.superview && !self.activePlayerController) imageView.image = image;
        });
    });
}

- (void)loadImageForItem:(PVMediaVaultItem *)item intoImageView:(UIImageView *)imageView {
    NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:item];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *image = [UIImage imageWithContentsOfFile:url.path];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (imageView.superview) imageView.image = image;
        });
    });
}

- (void)attachActivePlayerIfReady {
    if (!self.activePlayerController || !self.pendingPlayerItem || self.pendingPlayerItem.status != AVPlayerItemStatusReadyToPlay) return;
    if (self.activePlayerController.parentViewController) return;
    if (self.currentIndex < 0 || self.currentIndex >= self.pageViews.count) return;
    UIView *page = self.pageViews[self.currentIndex];
    [self addChildViewController:self.activePlayerController];
    self.activePlayerController.view.frame = page.bounds;
    self.activePlayerController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [page addSubview:self.activePlayerController.view];
    [self.activePlayerController didMoveToParentViewController:self];
    [self.activePlayerController.player play];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (![keyPath isEqualToString:@"status"] || object != self.pendingPlayerItem) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.pendingPlayerItem.status == AVPlayerItemStatusReadyToPlay) [self attachActivePlayerIfReady];
    });
}

- (void)stopActivePlayer {
    [self.pendingPlayerItem removeObserver:self forKeyPath:@"status"];
    self.pendingPlayerItem = nil;
    [self.activePlayerController.player pause];
    [self.activePlayerController willMoveToParentViewController:nil];
    [self.activePlayerController.view removeFromSuperview];
    [self.activePlayerController removeFromParentViewController];
    self.activePlayerController = nil;
    self.activePlayerIndex = NSNotFound;
}

- (void)backTapped:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
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
    PVMediaInfoSheetViewController *sheet = [[PVMediaInfoSheetViewController alloc] init];
    sheet.item = self.items[self.currentIndex];
    sheet.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)restoreTapped:(UIButton *)sender {
    if (self.restoring || self.currentIndex >= self.items.count || !self.restoreHandler) return;
    self.restoring = YES;
    self.restoreButton.enabled = NO;
    self.deleteButton.enabled = NO;
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
            self.deleteButton.enabled = YES;
            self.shareButton.enabled = YES;
            self.infoButton.enabled = YES;
            if (success) [self dismissViewControllerAnimated:YES completion:nil];
            else [self showMessage:message ?: @"فشل الاسترداد؛ بقيت نسخة PrivacyVault دون تغيير."];
        });
    });
}

- (void)deleteTapped:(UIButton *)sender {
    if (self.restoring || self.currentIndex >= self.items.count) return;
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"حذف العنصر؟" message:@"سيتم حذف نسخة العنصر من PrivacyVault فقط. لن يتم تعديل مكتبة الصور." preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"حذف" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self performDeleteForItem:self.items[self.currentIndex]];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)performDeleteForItem:(PVMediaVaultItem *)item {
    self.restoring = YES;
    self.restoreButton.enabled = NO;
    self.deleteButton.enabled = NO;
    self.shareButton.enabled = NO;
    self.infoButton.enabled = NO;
    self.activityIndicator.hidden = NO;
    [self.activityIndicator startAnimating];
    __weak typeof(self) weakSelf = self;
    void (^completion)(BOOL, NSString *) = ^(BOOL success, NSString *message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.activityIndicator stopAnimating];
            self.activityIndicator.hidden = YES;
            self.restoring = NO;
            self.restoreButton.enabled = YES;
            self.deleteButton.enabled = YES;
            self.shareButton.enabled = YES;
            self.infoButton.enabled = YES;
            if (success) [self dismissViewControllerAnimated:YES completion:nil];
            else [self showMessage:message ?: @"تعذر حذف العنصر؛ بقيت نسخة PrivacyVault دون تغيير."];
        });
    };
    if (self.deleteHandler) {
        self.deleteHandler(item, completion);
    } else {
        NSError *error = nil;
        BOOL success = [[PVMediaVaultStore sharedStore] removeItem:item error:&error];
        completion(success, error.localizedDescription ?: @"تعذر حذف العنصر؛ بقيت نسخة PrivacyVault دون تغيير.");
    }
}

- (void)showMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"PrivacyVault" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source {
    PVMediaZoomAnimator *animator = [[PVMediaZoomAnimator alloc] init];
    animator.presenting = YES;
    return animator;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    PVMediaZoomAnimator *animator = [[PVMediaZoomAnimator alloc] init];
    animator.presenting = NO;
    return animator;
}

@end
