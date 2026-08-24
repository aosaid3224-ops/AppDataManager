#import "PVVaultViewController.h"
#import "PVSettingsViewController.h"
#import "PVMediaLibraryViewController.h"

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

    UIButton *mediaButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [mediaButton setTitle:@"إخفاء الصور والفيديوهات" forState:UIControlStateNormal];
    mediaButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [mediaButton addTarget:self action:@selector(mediaLibraryTapped:) forControlEvents:UIControlEventTouchUpInside];
    mediaButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:mediaButton];

    UIButton *settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    settingsButton.frame = CGRectMake(0, 0, 40, 40);
    settingsButton.accessibilityLabel = @"الإعدادات";
    if (@available(iOS 13.0, *)) {
        [settingsButton setImage:[UIImage systemImageNamed:@"gearshape.fill"] forState:UIControlStateNormal];
    } else {
        [settingsButton setTitle:@"⚙" forState:UIControlStateNormal];
    }
    [settingsButton addTarget:self action:@selector(settingsTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:settingsButton];

    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-64],
        [mediaButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [mediaButton.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:20]
    ]];
}

- (void)mediaLibraryTapped:(UIButton *)sender {
    PVMediaLibraryViewController *controller = [[PVMediaLibraryViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)settingsTapped:(UIButton *)sender {
    PVSettingsViewController *controller = [[PVSettingsViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

@end
