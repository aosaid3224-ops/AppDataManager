#import "PVVaultViewController.h"
#import "PVSettingsViewController.h"
#import "PVMediaLibraryViewController.h"
#import "PVMediaVaultBrowserViewController.h"
#import "PVMediaVaultStore.h"

@interface PVVaultViewController ()
@property (nonatomic, strong) UIButton *imagesCard;
@property (nonatomic, strong) UIButton *videosCard;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *importButton;
@end

@implementation PVVaultViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"المستودع";
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    if (@available(iOS 13.0, *)) self.view.backgroundColor = [UIColor systemBackgroundColor];
    else self.view.backgroundColor = [UIColor whiteColor];

    UIButton *settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    settingsButton.frame = CGRectMake(0, 0, 40, 40);
    settingsButton.accessibilityLabel = @"الإعدادات";
    if (@available(iOS 13.0, *)) [settingsButton setImage:[UIImage systemImageNamed:@"gearshape.fill"] forState:UIControlStateNormal];
    else [settingsButton setTitle:@"⚙" forState:UIControlStateNormal];
    [settingsButton addTarget:self action:@selector(settingsTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:settingsButton];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"PrivacyVault";
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:titleLabel];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.text = @"مكتبتك الخاصة، مرتبة وآمنة";
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
    self.subtitleLabel.font = [UIFont systemFontOfSize:15];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.subtitleLabel];

    self.imagesCard = [self makeMediaCardWithIcon:@"photo.on.rectangle.angled" title:@"الصور" tag:1];
    self.videosCard = [self makeMediaCardWithIcon:@"video.fill" title:@"الفيديوهات" tag:2];
    [self.view addSubview:self.imagesCard];
    [self.view addSubview:self.videosCard];

    self.importButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.importButton setTitle:@"إضافة من تطبيق الصور" forState:UIControlStateNormal];
    self.importButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.importButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.importButton addTarget:self action:@selector(importTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.importButton];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:82],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [self.imagesCard.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:34],
        [self.imagesCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.imagesCard.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.5 constant:-30],
        [self.imagesCard.heightAnchor constraintEqualToConstant:190],
        [self.videosCard.topAnchor constraintEqualToAnchor:self.imagesCard.topAnchor],
        [self.videosCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.videosCard.leadingAnchor constraintEqualToAnchor:self.imagesCard.trailingAnchor constant:20],
        [self.videosCard.heightAnchor constraintEqualToAnchor:self.imagesCard.heightAnchor],
        [self.importButton.topAnchor constraintEqualToAnchor:self.imagesCard.bottomAnchor constant:24],
        [self.importButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
    ]];
}

- (UIButton *)makeMediaCardWithIcon:(NSString *)iconName title:(NSString *)title tag:(NSInteger)tag {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = tag;
    button.accessibilityLabel = title;
    button.layer.cornerRadius = 22.0;
    button.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        button.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        button.tintColor = [UIColor systemBlueColor];
    } else {
        button.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0];
    }
    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    if (@available(iOS 13.0, *)) iconView.image = [UIImage systemImageNamed:iconName];
    [button addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:19];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [button addSubview:titleLabel];

    UILabel *countLabel = [[UILabel alloc] init];
    countLabel.tag = 100 + tag;
    countLabel.textAlignment = NSTextAlignmentCenter;
    countLabel.textColor = [UIColor secondaryLabelColor];
    countLabel.font = [UIFont systemFontOfSize:13];
    countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [button addSubview:countLabel];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.topAnchor constraintEqualToAnchor:button.topAnchor constant:30],
        [iconView.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [iconView.widthAnchor constraintEqualToConstant:64],
        [iconView.heightAnchor constraintEqualToConstant:64],
        [titleLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:14],
        [titleLabel.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:8],
        [titleLabel.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-8],
        [countLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:7],
        [countLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [countLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor]
    ]];
    [button addTarget:self action:@selector(mediaCardTapped:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self updateCardCounts];
}

- (void)updateCardCounts {
    NSArray<PVMediaVaultItem *> *items = [PVMediaVaultStore sharedStore].items;
    NSUInteger images = 0;
    NSUInteger videos = 0;
    for (PVMediaVaultItem *item in items) {
        if ([item.type isEqualToString:@"video"]) videos++;
        else images++;
    }
    UILabel *imageCount = [self.imagesCard viewWithTag:101];
    UILabel *videoCount = [self.videosCard viewWithTag:102];
    imageCount.text = [NSString stringWithFormat:@"%lu عنصر مخفي", (unsigned long)images];
    videoCount.text = [NSString stringWithFormat:@"%lu عنصر مخفي", (unsigned long)videos];
}

- (void)mediaCardTapped:(UIButton *)sender {
    NSArray<PVMediaVaultItem *> *allItems = [PVMediaVaultStore sharedStore].items;
    NSString *type = sender.tag == 2 ? @"video" : @"image";
    NSMutableArray<PVMediaVaultItem *> *filteredItems = [NSMutableArray array];
    for (PVMediaVaultItem *item in allItems) if ([item.type isEqualToString:type]) [filteredItems addObject:item];
    PVMediaVaultBrowserViewController *browser = [[PVMediaVaultBrowserViewController alloc] init];
    browser.items = [filteredItems copy];
    browser.sectionTitle = sender.tag == 2 ? @"الفيديوهات المخفية" : @"الصور المخفية";
    [self.navigationController pushViewController:browser animated:YES];
}

- (void)importTapped:(UIButton *)sender {
    PVMediaLibraryViewController *controller = [[PVMediaLibraryViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)settingsTapped:(UIButton *)sender {
    PVSettingsViewController *controller = [[PVSettingsViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

@end
