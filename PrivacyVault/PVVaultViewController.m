#import "PVVaultViewController.h"
#import "PVSettingsViewController.h"

@implementation PVVaultViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"المستودع";

    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }

    UILabel *label = [[UILabel alloc] init];
    label.text = @"واجهة PrivacyVault";
    label.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) {
        label.textColor = [UIColor labelColor];
    } else {
        label.textColor = [UIColor blackColor];
    }
    label.font = [UIFont systemFontOfSize:20];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:label];

    UIButton *settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [settingsButton setTitle:@"الإعدادات" forState:UIControlStateNormal];
    settingsButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [settingsButton addTarget:self action:@selector(settingsTapped:) forControlEvents:UIControlEventTouchUpInside];
    settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:settingsButton];

    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-28],
        [settingsButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [settingsButton.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:24]
    ]];
}

- (void)settingsTapped:(UIButton *)sender {
    PVSettingsViewController *controller = [[PVSettingsViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

@end
