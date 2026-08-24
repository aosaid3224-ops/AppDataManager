#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// MARK: - Preferences Framework Forward Declarations
@interface PSSpecifier : NSObject
+ (instancetype)preferenceSpecifierNamed:(NSString *)name
                                  target:(id)target
                                     set:(SEL)set
                                     get:(SEL)get
                                  detail:(Class)detail
                                    cell:(int)cell
                                    edit:(Class)edit;
@end

@interface PSListController : UIViewController
- (NSArray *)specifiers;
@end

@interface PSUIPrefsListController : PSListController
@end

// MARK: - PVPasswordViewController (forward declaration)
@interface PVPasswordViewController : UIViewController
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UILabel *statusLabel;
@end

// MARK: - PVDummyViewController (forward declaration)
@interface PVDummyViewController : UIViewController
@end

// MARK: - PVEntryViewController
@interface PVEntryViewController : UIViewController
@end

@implementation PVEntryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"التشخيص";

    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }

    UILabel *label = [[UILabel alloc] init];
    label.text = @"التشخيص غير متاح حالياً.";
    label.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) {
        label.textColor = [UIColor secondaryLabelColor];
    } else {
        label.textColor = [UIColor grayColor];
    }
    label.numberOfLines = 0;
    label.font = [UIFont systemFontOfSize:16];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [label.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [label.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40]
    ]];

    UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(handleTripleTap:)];
    tripleTap.numberOfTapsRequired = 3;
    [self.view addGestureRecognizer:tripleTap];
}

- (void)handleTripleTap:(UITapGestureRecognizer *)gesture {
    PVPasswordViewController *vc = [[PVPasswordViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

@end

// MARK: - PVPasswordViewController
@implementation PVPasswordViewController

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
    NSString *correct = @"1234";

    if ([input isEqualToString:correct]) {
        self.statusLabel.text = @"";
        PVDummyViewController *vc = [[PVDummyViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    } else {
        self.statusLabel.text = @"كلمة المرور غير صحيحة";
        self.passwordField.text = @"";
        [self.passwordField becomeFirstResponder];
    }
}

@end

// MARK: - PVDummyViewController
@implementation PVDummyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"المستودع";

    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }

    UILabel *label = [[UILabel alloc] init];
    label.text = @"لا توجد بيانات لعرضها هنا";
    label.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) {
        label.textColor = [UIColor labelColor];
    } else {
        label.textColor = [UIColor blackColor];
    }
    label.font = [UIFont systemFontOfSize:18];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

@end

// MARK: - Hooks
%group iOS15Up
%hook PSUIPrefsListController
- (NSArray *)specifiers {
    NSArray *orig = %orig;
    NSMutableArray *mutableSpecifiers = orig ? [orig mutableCopy] : [NSMutableArray array];

    BOOL alreadyAdded = NO;
    for (id spec in mutableSpecifiers) {
        if ([spec isKindOfClass:%c(PSSpecifier)]) {
            NSString *name = nil;
            @try { name = [spec valueForKey:@"name"]; } @catch (NSException *e) {}
            if ([name isEqualToString:@"التشخيص"]) { alreadyAdded = YES; break; }
        }
    }

    if (!alreadyAdded) {
        PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:@"التشخيص"
                                                           target:self
                                                              set:NULL
                                                              get:NULL
                                                           detail:[PVEntryViewController class]
                                                             cell:1
                                                             edit:Nil];
        [mutableSpecifiers addObject:spec];
    }

    return mutableSpecifiers;
}
%end
%end

%group iOS14Down
%hook PSListController
- (NSArray *)specifiers {
    NSArray *orig = %orig;
    NSString *className = NSStringFromClass([self class]);
    if (![className isEqualToString:@"PSListController"] && ![className hasSuffix:@"RootController"]) {
        return orig;
    }

    NSMutableArray *mutableSpecifiers = orig ? [orig mutableCopy] : [NSMutableArray array];

    BOOL alreadyAdded = NO;
    for (id spec in mutableSpecifiers) {
        NSString *name = nil;
        @try { name = [spec valueForKey:@"name"]; } @catch (NSException *e) {}
        if ([name isEqualToString:@"التشخيص"]) { alreadyAdded = YES; break; }
    }

    if (!alreadyAdded) {
        PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:@"التشخيص"
                                                           target:self
                                                              set:NULL
                                                              get:NULL
                                                           detail:[PVEntryViewController class]
                                                             cell:1
                                                             edit:Nil];
        [mutableSpecifiers addObject:spec];
    }

    return mutableSpecifiers;
}
%end
%end

%ctor {
    if (%c(PSUIPrefsListController)) {
        %init(iOS15Up);
    } else {
        %init(iOS14Down);
    }
}
