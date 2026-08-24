#import "PVPassword1ViewController.h"
#import "PVDummyViewController.h"
#import "PVPasswordStore.h"

@interface PVPassword1ViewController ()
@property (nonatomic, strong) UITextField *passwordField;
@end

@implementation PVPassword1ViewController

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

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:60],

        [self.passwordField.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.passwordField.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:30],
        [self.passwordField.widthAnchor constraintEqualToConstant:220],
        [self.passwordField.heightAnchor constraintEqualToConstant:44],

        [submitBtn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [submitBtn.topAnchor constraintEqualToAnchor:self.passwordField.bottomAnchor constant:20],

        [submitBtn.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20]
    ]];

    [self.passwordField becomeFirstResponder];
}

- (void)submitTapped:(UIButton *)sender {
    NSString *input = self.passwordField.text ?: @"";
    BOOL valid = [[PVPasswordStore sharedStore] verifyPassword1:input error:nil];

    if (valid) {
        PVDummyViewController *vc = [[PVDummyViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    } else {
        self.passwordField.text = @"";
        [self.passwordField resignFirstResponder];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end
