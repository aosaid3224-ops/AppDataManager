#import "PVPassword2ViewController.h"
#import "PVVaultViewController.h"

@interface PVPassword2ViewController ()
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation PVPassword2ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"المصادقة";

    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"أدخل كلمة المرور";
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:titleLabel];

    self.passwordField = [[UITextField alloc] init];
    self.passwordField.secureTextEntry = YES;
    self.passwordField.borderStyle = UITextBorderStyleRoundedRect;
    self.passwordField.placeholder = @"كلمة المرور";
    self.passwordField.textAlignment = NSTextAlignmentCenter;
    self.passwordField.returnKeyType = UIReturnKeyGo;
    self.passwordField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.passwordField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.passwordField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.passwordField];

    UIButton *submitBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [submitBtn setTitle:@"فتح" forState:UIControlStateNormal];
    submitBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [submitBtn addTarget:self action:@selector(submitTapped:) forControlEvents:UIControlEventTouchUpInside];
    submitBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:submitBtn];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"";
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = [UIColor systemRedColor];
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:60],

        [self.passwordField.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.passwordField.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:30],
        [self.passwordField.widthAnchor constraintEqualToConstant:220],
        [self.passwordField.heightAnchor constraintEqualToConstant:44],

        [submitBtn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [submitBtn.topAnchor constraintEqualToAnchor:self.passwordField.bottomAnchor constant:20],

        [self.statusLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.statusLabel.topAnchor constraintEqualToAnchor:submitBtn.bottomAnchor constant:16]
    ]];

    [self.passwordField becomeFirstResponder];
}

- (void)submitTapped:(UIButton *)sender {
    NSString *input = self.passwordField.text;
    NSString *correct = @"5678";

    if ([input isEqualToString:correct]) {
        self.statusLabel.text = @"";
        PVVaultViewController *vc = [[PVVaultViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    } else {
        self.statusLabel.text = @"كلمة المرور غير صحيحة";
        self.passwordField.text = @"";
        [self.passwordField becomeFirstResponder];
    }
}

@end
