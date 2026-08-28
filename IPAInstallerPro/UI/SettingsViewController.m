//
// SettingsViewController.m
// IPA Installer Pro
//

#import "SettingsViewController.h"
#import "CapabilityManager.h"
#import "JailbreakEnvironment.h"
#import "IPTheme.h"

@interface SettingsViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *envLabel;
@property (nonatomic, strong) UILabel *capLabel;
@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"الإعدادات";
    self.view.backgroundColor = [IPTheme backgroundColor];
    [self setupScrollView];
    [self setupEnvironmentSection];
    [self setupCapabilitiesSection];
    [self refreshData];
}

- (UILabel *)sectionTitle:(NSString *)title {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    label.textColor = UIColor.whiteColor;
    label.textAlignment = NSTextAlignmentRight;
    return label;
}

- (UILabel *)cardLabel {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    label.textColor = [UIColor colorWithWhite:0.76 alpha:1.0];
    label.backgroundColor = [IPTheme cardColor];
    label.layer.cornerRadius = 16;
    label.layer.borderWidth = 0.7;
    label.layer.borderColor = [IPTheme subtleBorderColor].CGColor;
    label.clipsToBounds = YES;
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentRight;
    label.lineBreakMode = NSLineBreakByCharWrapping;
    label.layoutMargins = UIEdgeInsetsMake(14, 14, 14, 14);
    return label;
}

- (void)setupScrollView {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.directionalLockEnabled = YES;
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor]
    ]];
}

- (void)setupEnvironmentSection {
    UILabel *header = [self sectionTitle:@"بيئة التشغيل"];
    self.envLabel = [self cardLabel];
    [self.contentView addSubview:header];
    [self.contentView addSubview:self.envLabel];
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:18],
        [header.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18],
        [header.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18],
        [self.envLabel.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:10],
        [self.envLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.envLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.envLabel.heightAnchor constraintGreaterThanOrEqualToConstant:92]
    ]];
}

- (void)setupCapabilitiesSection {
    UILabel *header = [self sectionTitle:@"جاهزية التثبيت"];
    self.capLabel = [self cardLabel];
    [self.contentView addSubview:header];
    [self.contentView addSubview:self.capLabel];
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.envLabel.bottomAnchor constant:24],
        [header.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18],
        [header.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18],
        [self.capLabel.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:10],
        [self.capLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.capLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.capLabel.heightAnchor constraintGreaterThanOrEqualToConstant:110],
        [self.capLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-24]
    ]];
}

- (NSString *)value:(NSString *)value fallback:(NSString *)fallback {
    return value.length > 0 ? value : fallback;
}

- (void)refreshData {
    JailbreakEnvironment *env = [JailbreakEnvironment sharedEnvironment];
    CapabilityManager *cap = [CapabilityManager sharedManager];

    self.envLabel.text = [NSString stringWithFormat:
        @"إصدار iOS: %@\nالجهاز: %@\nالبيئة: %@%@",
        [self value:env.osVersion fallback:@"غير معروف"],
        [self value:env.deviceModel fallback:@"غير معروف"],
        [self value:env.jailbreakType fallback:@"غير معروف"],
        env.isRootless ? @" · Rootless" : @""];

    NSMutableString *status = [NSMutableString stringWithFormat:@"%@\n\n", [cap installationReadinessStatus]];
    for (Capability *item in [cap allCapabilities]) {
        [status appendFormat:@"%@ %@\n", item.isAvailable ? @"متاح" : @"غير متاح", item.name ?: @"أداة"];
    }
    self.capLabel.text = status;
}

@end
