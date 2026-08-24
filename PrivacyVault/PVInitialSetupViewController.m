#import "PVInitialSetupViewController.h"
#import "PVPasswordStore.h"

@interface PVInitialSetupViewController ()
@property (nonatomic, strong) UITextField *password1Field;
@property (nonatomic, strong) UITextField *password1ConfirmationField;
@property (nonatomic, strong) UITextField *password2Field;
@property (nonatomic, strong) UITextField *password2ConfirmationField;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation PVInitialSetupViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"الإعداد الأولي";
    self.navigationItem.hidesBackButton = YES;

    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }

    UILabel *heading = [[UILabel alloc] init];
    heading.text = @"إنشاء كلمات المرور";
    heading.font = [UIFont boldSystemFontOfSize:22];
    heading.textAlignment = NSTextAlignmentCenter;
    heading.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:heading];

    UILabel *message = [[UILabel alloc] init];
    message.text = @"أنشئ كلمتي المرور للوصول إلى PrivacyVault";
    message.font = [UIFont systemFontOfSize:15];
    message.textAlignment = NSTextAlignmentCenter;
    message.numberOfLines = 0;
    if (@available(iOS 13.0, *)) message.textColor = [UIColor secondaryLabelColor];
    message.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:message];

    self.password1Field = [self makePasswordField:@"كلمة المرور الأولى"];
    self.password1ConfirmationField = [self makePasswordField:@"تأكيد كلمة المرور الأولى"];
    self.password2Field = [self makePasswordField:@"كلمة المرور الثانية"];
    self.password2ConfirmationField = [self makePasswordField:@"تأكيد كلمة المرور الثانية"];

    UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [saveButton setTitle:@"حفظ والإكمال" forState:UIControlStateNormal];
    saveButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [saveButton addTarget:self action:@selector(saveTapped:) forControlEvents:UIControlEventTouchUpInside];
    saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:saveButton];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textColor = [UIColor systemRedColor];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [heading.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [heading.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24],
        [message.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [message.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:10],
        [message.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:28],
        [message.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-28],
        [self.password1Field.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.password1Field.topAnchor constraintEqualToAnchor:message.bottomAnchor constant:22],
        [self.password1Field.widthAnchor constraintEqualToConstant:280],
        [self.password1Field.heightAnchor constraintEqualToConstant:42],
        [self.password1ConfirmationField.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.password1ConfirmationField.topAnchor constraintEqualToAnchor:self.password1Field.bottomAnchor constant:10],
        [self.password1ConfirmationField.widthAnchor constraintEqualToAnchor:self.password1Field.widthAnchor],
        [self.password1ConfirmationField.heightAnchor constraintEqualToAnchor:self.password1Field.heightAnchor],
        [self.password2Field.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.password2Field.topAnchor constraintEqualToAnchor:self.password1ConfirmationField.bottomAnchor constant:20],
        [self.password2Field.widthAnchor constraintEqualToAnchor:self.password1Field.widthAnchor],
        [self.password2Field.heightAnchor constraintEqualToAnchor:self.password1Field.heightAnchor],
        [self.password2ConfirmationField.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.password2ConfirmationField.topAnchor constraintEqualToAnchor:self.password2Field.bottomAnchor constant:10],
        [self.password2ConfirmationField.widthAnchor constraintEqualToAnchor:self.password1Field.widthAnchor],
        [self.password2ConfirmationField.heightAnchor constraintEqualToAnchor:self.password1Field.heightAnchor],
        [saveButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [saveButton.topAnchor constraintEqualToAnchor:self.password2ConfirmationField.bottomAnchor constant:20],
        [self.statusLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.statusLabel.topAnchor constraintEqualToAnchor:saveButton.bottomAnchor constant:12],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24]
    ]];

    [self.password1Field becomeFirstResponder];
}

- (UITextField *)makePasswordField:(NSString *)placeholder {
    UITextField *field = [[UITextField alloc] init];
    field.secureTextEntry = YES;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.placeholder = placeholder;
    field.textAlignment = NSTextAlignmentCenter;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.returnKeyType = UIReturnKeyNext;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:field];
    return field;
}

- (void)saveTapped:(UIButton *)sender {
    NSString *password1 = self.password1Field.text ?: @"";
    NSString *password1Confirmation = self.password1ConfirmationField.text ?: @"";
    NSString *password2 = self.password2Field.text ?: @"";
    NSString *password2Confirmation = self.password2ConfirmationField.text ?: @"";

    if (password1.length < 4 || password2.length < 4) {
        self.statusLabel.text = @"يجب أن تتكون كل كلمة مرور من 4 محارف على الأقل";
        return;
    }
    if (![password1 isEqualToString:password1Confirmation]) {
        self.statusLabel.text = @"تأكيد كلمة المرور الأولى غير مطابق";
        return;
    }
    if (![password2 isEqualToString:password2Confirmation]) {
        self.statusLabel.text = @"تأكيد كلمة المرور الثانية غير مطابق";
        return;
    }
    if ([password1 isEqualToString:password2]) {
        self.statusLabel.text = @"يجب أن تكون كلمتا المرور مختلفتين";
        return;
    }

    NSError *error = nil;
    BOOL saved = [[PVPasswordStore sharedStore] savePassword1:password1 password2:password2 error:&error];
    if (!saved) {
        self.statusLabel.text = error.localizedDescription ?: @"تعذر حفظ الإعداد";
        return;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"PVInitialSetupCompleted" object:nil];
}

@end
