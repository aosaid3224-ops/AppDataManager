#import "PVChangePasswordsViewController.h"
#import "PVPasswordStore.h"

@interface PVChangePasswordsViewController ()
@property (nonatomic, strong) UITextField *password1CurrentField;
@property (nonatomic, strong) UITextField *password1NewField;
@property (nonatomic, strong) UITextField *password1ConfirmationField;
@property (nonatomic, strong) UILabel *password1StatusLabel;
@property (nonatomic, strong) UITextField *password2CurrentField;
@property (nonatomic, strong) UITextField *password2NewField;
@property (nonatomic, strong) UITextField *password2ConfirmationField;
@property (nonatomic, strong) UILabel *password2StatusLabel;
@end

@implementation PVChangePasswordsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"تغيير كلمات المرور";
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scrollView];
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:contentView];

    UILabel *password1Header = [self makeHeader:@"كلمة المرور الأولى"];
    [contentView addSubview:password1Header];
    self.password1CurrentField = [self makeField:@"كلمة المرور الحالية"];
    self.password1NewField = [self makeField:@"كلمة المرور الجديدة"];
    self.password1ConfirmationField = [self makeField:@"تأكيد كلمة المرور الجديدة"];
    [contentView addSubview:self.password1CurrentField];
    [contentView addSubview:self.password1NewField];
    [contentView addSubview:self.password1ConfirmationField];
    UIButton *password1Button = [self makeButton:@"حفظ كلمة المرور الأولى" action:@selector(savePassword1Tapped:)];
    [contentView addSubview:password1Button];
    self.password1StatusLabel = [self makeStatusLabel];
    [contentView addSubview:self.password1StatusLabel];

    UILabel *password2Header = [self makeHeader:@"كلمة المرور الثانية"];
    [contentView addSubview:password2Header];
    self.password2CurrentField = [self makeField:@"كلمة المرور الحالية"];
    self.password2NewField = [self makeField:@"كلمة المرور الجديدة"];
    self.password2ConfirmationField = [self makeField:@"تأكيد كلمة المرور الجديدة"];
    [contentView addSubview:self.password2CurrentField];
    [contentView addSubview:self.password2NewField];
    [contentView addSubview:self.password2ConfirmationField];
    UIButton *password2Button = [self makeButton:@"حفظ كلمة المرور الثانية" action:@selector(savePassword2Tapped:)];
    [contentView addSubview:password2Button];
    self.password2StatusLabel = [self makeStatusLabel];
    [contentView addSubview:self.password2StatusLabel];

    NSDictionary *views = NSDictionaryOfVariableBindings(scrollView, contentView, password1Header, password1Button, password2Header, password2Button);
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [contentView.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],
        [password1Header.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20],
        [password1Header.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24],
        [password1Header.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24],
        [self.password1CurrentField.topAnchor constraintEqualToAnchor:password1Header.bottomAnchor constant:12],
        [self.password1CurrentField.leadingAnchor constraintEqualToAnchor:password1Header.leadingAnchor],
        [self.password1CurrentField.trailingAnchor constraintEqualToAnchor:password1Header.trailingAnchor],
        [self.password1CurrentField.heightAnchor constraintEqualToConstant:44],
        [self.password1NewField.topAnchor constraintEqualToAnchor:self.password1CurrentField.bottomAnchor constant:10],
        [self.password1NewField.leadingAnchor constraintEqualToAnchor:password1Header.leadingAnchor],
        [self.password1NewField.trailingAnchor constraintEqualToAnchor:password1Header.trailingAnchor],
        [self.password1NewField.heightAnchor constraintEqualToAnchor:self.password1CurrentField.heightAnchor],
        [self.password1ConfirmationField.topAnchor constraintEqualToAnchor:self.password1NewField.bottomAnchor constant:10],
        [self.password1ConfirmationField.leadingAnchor constraintEqualToAnchor:password1Header.leadingAnchor],
        [self.password1ConfirmationField.trailingAnchor constraintEqualToAnchor:password1Header.trailingAnchor],
        [self.password1ConfirmationField.heightAnchor constraintEqualToAnchor:self.password1CurrentField.heightAnchor],
        [password1Button.topAnchor constraintEqualToAnchor:self.password1ConfirmationField.bottomAnchor constant:14],
        [password1Button.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.password1StatusLabel.topAnchor constraintEqualToAnchor:password1Button.bottomAnchor constant:8],
        [self.password1StatusLabel.leadingAnchor constraintEqualToAnchor:password1Header.leadingAnchor],
        [self.password1StatusLabel.trailingAnchor constraintEqualToAnchor:password1Header.trailingAnchor],
        [password2Header.topAnchor constraintEqualToAnchor:self.password1StatusLabel.bottomAnchor constant:28],
        [password2Header.leadingAnchor constraintEqualToAnchor:password1Header.leadingAnchor],
        [password2Header.trailingAnchor constraintEqualToAnchor:password1Header.trailingAnchor],
        [self.password2CurrentField.topAnchor constraintEqualToAnchor:password2Header.bottomAnchor constant:12],
        [self.password2CurrentField.leadingAnchor constraintEqualToAnchor:password2Header.leadingAnchor],
        [self.password2CurrentField.trailingAnchor constraintEqualToAnchor:password2Header.trailingAnchor],
        [self.password2CurrentField.heightAnchor constraintEqualToAnchor:self.password1CurrentField.heightAnchor],
        [self.password2NewField.topAnchor constraintEqualToAnchor:self.password2CurrentField.bottomAnchor constant:10],
        [self.password2NewField.leadingAnchor constraintEqualToAnchor:password2Header.leadingAnchor],
        [self.password2NewField.trailingAnchor constraintEqualToAnchor:password2Header.trailingAnchor],
        [self.password2NewField.heightAnchor constraintEqualToAnchor:self.password1CurrentField.heightAnchor],
        [self.password2ConfirmationField.topAnchor constraintEqualToAnchor:self.password2NewField.bottomAnchor constant:10],
        [self.password2ConfirmationField.leadingAnchor constraintEqualToAnchor:password2Header.leadingAnchor],
        [self.password2ConfirmationField.trailingAnchor constraintEqualToAnchor:password2Header.trailingAnchor],
        [self.password2ConfirmationField.heightAnchor constraintEqualToAnchor:self.password1CurrentField.heightAnchor],
        [password2Button.topAnchor constraintEqualToAnchor:self.password2ConfirmationField.bottomAnchor constant:14],
        [password2Button.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.password2StatusLabel.topAnchor constraintEqualToAnchor:password2Button.bottomAnchor constant:8],
        [self.password2StatusLabel.leadingAnchor constraintEqualToAnchor:password2Header.leadingAnchor],
        [self.password2StatusLabel.trailingAnchor constraintEqualToAnchor:password2Header.trailingAnchor],
        [self.password2StatusLabel.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-28]
    ]];

    (void)views;
}

- (UILabel *)makeHeader:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont boldSystemFontOfSize:20];
    label.textAlignment = NSTextAlignmentRight;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (UITextField *)makeField:(NSString *)placeholder {
    UITextField *field = [[UITextField alloc] init];
    field.placeholder = placeholder;
    field.secureTextEntry = YES;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.textAlignment = NSTextAlignmentRight;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    return field;
}

- (UIButton *)makeButton:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

- (UILabel *)makeStatusLabel {
    UILabel *label = [[UILabel alloc] init];
    label.textAlignment = NSTextAlignmentRight;
    label.numberOfLines = 0;
    label.font = [UIFont systemFontOfSize:14];
    label.textColor = [UIColor systemRedColor];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (void)savePassword1Tapped:(UIButton *)sender {
    NSString *current = self.password1CurrentField.text ?: @"";
    NSString *newPassword = self.password1NewField.text ?: @"";
    NSString *confirmation = self.password1ConfirmationField.text ?: @"";
    self.password1StatusLabel.text = [self validateAndSavePassword1From:current newPassword:newPassword confirmation:confirmation];
    if ([self.password1StatusLabel.text isEqualToString:@"تم تغيير كلمة المرور الأولى بنجاح"]) {
        [self clearFields:@[self.password1CurrentField, self.password1NewField, self.password1ConfirmationField]];
        self.password1StatusLabel.textColor = [UIColor systemGreenColor];
    }
}

- (void)savePassword2Tapped:(UIButton *)sender {
    NSString *current = self.password2CurrentField.text ?: @"";
    NSString *newPassword = self.password2NewField.text ?: @"";
    NSString *confirmation = self.password2ConfirmationField.text ?: @"";
    self.password2StatusLabel.text = [self validateAndSavePassword2From:current newPassword:newPassword confirmation:confirmation];
    if ([self.password2StatusLabel.text isEqualToString:@"تم تغيير كلمة المرور الثانية بنجاح"]) {
        [self clearFields:@[self.password2CurrentField, self.password2NewField, self.password2ConfirmationField]];
        self.password2StatusLabel.textColor = [UIColor systemGreenColor];
    }
}

- (NSString *)validateAndSavePassword1From:(NSString *)current newPassword:(NSString *)newPassword confirmation:(NSString *)confirmation {
    if (newPassword.length < 4) return @"كلمة المرور الجديدة يجب أن تتكون من 4 محارف على الأقل";
    if (![newPassword isEqualToString:confirmation]) return @"تأكيد كلمة المرور الجديدة غير مطابق";
    if ([current isEqualToString:newPassword]) return @"يجب أن تختلف كلمة المرور الجديدة عن الحالية";
    NSError *error = nil;
    if (![[PVPasswordStore sharedStore] changePassword1From:current to:newPassword error:&error]) return error.localizedDescription ?: @"تعذر تغيير كلمة المرور الأولى";
    return @"تم تغيير كلمة المرور الأولى بنجاح";
}

- (NSString *)validateAndSavePassword2From:(NSString *)current newPassword:(NSString *)newPassword confirmation:(NSString *)confirmation {
    if (newPassword.length < 4) return @"كلمة المرور الجديدة يجب أن تتكون من 4 محارف على الأقل";
    if (![newPassword isEqualToString:confirmation]) return @"تأكيد كلمة المرور الجديدة غير مطابق";
    if ([current isEqualToString:newPassword]) return @"يجب أن تختلف كلمة المرور الجديدة عن الحالية";
    NSError *error = nil;
    if (![[PVPasswordStore sharedStore] changePassword2From:current to:newPassword error:&error]) return error.localizedDescription ?: @"تعذر تغيير كلمة المرور الثانية";
    return @"تم تغيير كلمة المرور الثانية بنجاح";
}

- (void)clearFields:(NSArray<UITextField *> *)fields {
    for (UITextField *field in fields) field.text = @"";
}

@end
