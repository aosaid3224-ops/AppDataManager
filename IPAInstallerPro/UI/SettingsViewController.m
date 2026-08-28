//
// SettingsViewController.m
// IPA Installer Pro
//
// v2.5 — Auto Layout, clean analyzer test section
//

#import "SettingsViewController.h"
#import "CapabilityManager.h"
#import "JailbreakEnvironment.h"
#import "RootlessManager.h"
#import "IPTheme.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

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

#pragma mark - ScrollView + ContentView

- (void)setupScrollView {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentView.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.contentView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor]
    ]];}

#pragma mark - Environment Section

- (void)setupEnvironmentSection {
    UILabel *header = [[UILabel alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.text = @"🔧 بيئة التشغيل";
    header.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    header.textColor = [UIColor whiteColor];
    header.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:header];

    self.envLabel = [[UILabel alloc] init];
    self.envLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.envLabel.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    self.envLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    self.envLabel.backgroundColor = [IPTheme cardColor]; self.envLabel.layer.borderWidth = 0.7; self.envLabel.layer.borderColor = [IPTheme subtleBorderColor].CGColor;
    self.envLabel.layer.cornerRadius = 16;
    self.envLabel.clipsToBounds = YES;
    self.envLabel.numberOfLines = 0;
    self.envLabel.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:self.envLabel];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16],
        [header.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [header.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [self.envLabel.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:8],
        [self.envLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.envLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.envLabel.heightAnchor constraintGreaterThanOrEqualToConstant:180]
    ]];}

#pragma mark - Capabilities Section

- (void)setupCapabilitiesSection {
    UILabel *header = [[UILabel alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.text = @"⚙️ القدرات";
    header.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    header.textColor = [UIColor whiteColor];
    header.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:header];

    self.capLabel = [[UILabel alloc] init];
    self.capLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.capLabel.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    self.capLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    self.capLabel.backgroundColor = [IPTheme cardColor]; self.capLabel.layer.borderWidth = 0.7; self.capLabel.layer.borderColor = [IPTheme subtleBorderColor].CGColor;
    self.capLabel.layer.cornerRadius = 16;
    self.capLabel.clipsToBounds = YES;
    self.capLabel.numberOfLines = 0;
    self.capLabel.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:self.capLabel];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.envLabel.bottomAnchor constant:24],
        [header.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [header.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [self.capLabel.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:8],
        [self.capLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.capLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.capLabel.heightAnchor constraintGreaterThanOrEqualToConstant:260]
    ]];}

#pragma mark - Data

- (void)refreshData {
    JailbreakEnvironment *env = [JailbreakEnvironment sharedEnvironment];
    CapabilityManager *cap = [CapabilityManager sharedManager];

    NSMutableString *envStr = [NSMutableString string];
    [envStr appendFormat:@"Jailbreak: %@\n", env.jailbreakType ?: @"Unknown"];
    [envStr appendFormat:@"Rootless: %@\n", env.isRootless ? @"Yes" : @"No"];
    [envStr appendFormat:@"OS Version: %@\n", env.osVersion ?: @"Unknown"];
    [envStr appendFormat:@"Device: %@\n", env.deviceModel ?: @"Unknown"];
    [envStr appendFormat:@"Applications: %@\n", env.applicationsPath ?: @"N/A"];
    [envStr appendFormat:@"usr/bin: %@\n", env.usrBinPath ?: @"N/A"];
    [envStr appendFormat:@"Documents: %@\n", env.mobileDocumentsPath ?: @"N/A"];
    [envStr appendFormat:@"Root Path: %@\n", env.rootPath ?: @"N/A"];

    self.envLabel.text = envStr;

    NSMutableString *capStr = [NSMutableString string];
    [capStr appendFormat:@"%@\n", [cap installationReadinessStatus]];
    [capStr appendString:@"\n=== Tools ===\n"];
    for (Capability *c in [cap allCapabilities]) {
        NSString *icon = c.isAvailable ? @"✅" : @"❌";
        [capStr appendFormat:@"%@ %@: %@\n", icon, c.name, c.statusMessage];
    }

    self.capLabel.text = capStr;
}

@end
