#import "PVMediaVaultPreviewViewController.h"
#import <AVKit/AVKit.h>

@interface PVMediaVaultPreviewViewController ()
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) AVPlayerViewController *playerController;
@property (nonatomic, strong) UIVisualEffectView *toolbar;
@property (nonatomic, strong) UIButton *restoreButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, assign) BOOL restoring;
@end

@implementation PVMediaVaultPreviewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.view.backgroundColor = UIColor.blackColor;
    self.navigationItem.hidesBackButton = YES;

    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    backButton.translatesAutoresizingMaskIntoConstraints = NO;
    backButton.accessibilityLabel = @"رجوع";
    if (@available(iOS 13.0, *)) [backButton setImage:[UIImage systemImageNamed:@"chevron.backward"] forState:UIControlStateNormal];
    else [backButton setTitle:@"‹" forState:UIControlStateNormal];
    backButton.tintColor = UIColor.whiteColor;
    backButton.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.72];
    backButton.layer.cornerRadius = 21.0;
    [backButton addTarget:self action:@selector(backTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:backButton];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.backgroundColor = UIColor.blackColor;
    [self.view addSubview:contentView];

    NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:self.item];
    if ([self.item.type isEqualToString:@"video"]) {
        self.playerController = [[AVPlayerViewController alloc] init];
        self.playerController.player = [AVPlayer playerWithURL:url];
        self.playerController.showsPlaybackControls = YES;
        [self addChildViewController:self.playerController];
        self.playerController.view.translatesAutoresizingMaskIntoConstraints = NO;
        [contentView addSubview:self.playerController.view];
        [self.playerController didMoveToParentViewController:self];
        [NSLayoutConstraint activateConstraints:@[
            [self.playerController.view.topAnchor constraintEqualToAnchor:contentView.topAnchor],
            [self.playerController.view.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
            [self.playerController.view.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
            [self.playerController.view.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor]
        ]];
    } else {
        self.imageView = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:url.path]];
        self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.imageView.backgroundColor = UIColor.blackColor;
        self.imageView.accessibilityLabel = @"صورة مخفية";
        [contentView addSubview:self.imageView];
        [NSLayoutConstraint activateConstraints:@[
            [self.imageView.topAnchor constraintEqualToAnchor:contentView.topAnchor],
            [self.imageView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
            [self.imageView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
            [self.imageView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor]
        ]];
    }

    UIBlurEffect *blurEffect = nil;
    if (@available(iOS 13.0, *)) blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
    UIVisualEffectView *toolbarBackground = blurEffect ? [[UIVisualEffectView alloc] initWithEffect:blurEffect] : [[UIVisualEffectView alloc] initWithFrame:CGRectZero];
    toolbarBackground.translatesAutoresizingMaskIntoConstraints = NO;
    toolbarBackground.layer.cornerRadius = 22.0;
    toolbarBackground.clipsToBounds = YES;
    self.toolbar = toolbarBackground;
    [self.view addSubview:self.toolbar];

    self.shareButton = [self makeToolbarButtonWithTitle:@"مشاركة" symbol:@"square.and.arrow.up" action:@selector(shareTapped:)];
    self.restoreButton = [self makeToolbarButtonWithTitle:@"استرداد" symbol:@"arrow.uturn.backward.circle" action:@selector(restoreTapped:)];
    [self.toolbar.contentView addSubview:self.shareButton];
    [self.toolbar.contentView addSubview:self.restoreButton];

    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.hidden = YES;
    [self.toolbar.contentView addSubview:self.activityIndicator];

    [NSLayoutConstraint activateConstraints:@[
        [backButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12.0],
        [backButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14.0],
        [backButton.widthAnchor constraintEqualToConstant:42.0],
        [backButton.heightAnchor constraintEqualToConstant:42.0],
        [contentView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.toolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18.0],
        [self.toolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18.0],
        [self.toolbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12.0],
        [self.toolbar.heightAnchor constraintEqualToConstant:68.0],
        [self.shareButton.leadingAnchor constraintEqualToAnchor:self.toolbar.contentView.leadingAnchor constant:18.0],
        [self.shareButton.topAnchor constraintEqualToAnchor:self.toolbar.contentView.topAnchor constant:7.0],
        [self.shareButton.bottomAnchor constraintEqualToAnchor:self.toolbar.contentView.bottomAnchor constant:-7.0],
        [self.shareButton.widthAnchor constraintEqualToConstant:112.0],
        [self.restoreButton.trailingAnchor constraintEqualToAnchor:self.toolbar.contentView.trailingAnchor constant:-18.0],
        [self.restoreButton.topAnchor constraintEqualToAnchor:self.toolbar.contentView.topAnchor constant:7.0],
        [self.restoreButton.bottomAnchor constraintEqualToAnchor:self.toolbar.contentView.bottomAnchor constant:-7.0],
        [self.restoreButton.widthAnchor constraintEqualToConstant:112.0],
        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.toolbar.contentView.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.toolbar.contentView.centerYAnchor]
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    if (self.playerController && !self.playerController.player.rate) [self.playerController.player play];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.playerController.player pause];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (UIButton *)makeToolbarButtonWithTitle:(NSString *)title symbol:(NSString *)symbol action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = UIColor.whiteColor;
    button.layer.cornerRadius = 16.0;
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    button.accessibilityLabel = title;
    if (@available(iOS 13.0, *)) {
        [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
        [button setTitle:[NSString stringWithFormat:@"  %@", title] forState:UIControlStateNormal];
    } else {
        [button setTitle:title forState:UIControlStateNormal];
    }
    button.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)backTapped:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)shareTapped:(UIButton *)sender {
    if (self.restoring) return;
    NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:self.item];
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

- (void)restoreTapped:(UIButton *)sender {
    if (self.restoring || !self.restoreHandler) return;
    self.restoring = YES;
    self.shareButton.enabled = NO;
    self.restoreButton.enabled = NO;
    self.activityIndicator.hidden = NO;
    [self.activityIndicator startAnimating];
    __weak typeof(self) weakSelf = self;
    self.restoreHandler(self.item, ^(BOOL success, NSString *message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.activityIndicator stopAnimating];
            self.activityIndicator.hidden = YES;
            self.restoring = NO;
            self.shareButton.enabled = YES;
            self.restoreButton.enabled = YES;
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
