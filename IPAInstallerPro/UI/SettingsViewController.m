//
//  SettingsViewController.m
//  IPAInstallerPro — Redesigned Settings UI
//

#import "SettingsViewController.h"
#import "CapabilityManager.h"
#import "JailbreakEnvironment.h"
#import "IPTheme.h"
#import <objc/runtime.h>
#import "RuntimeEnvironment.h"

@interface SettingsViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *mainStack;
@property (nonatomic, strong) UIView *envCard;
@property (nonatomic, strong) UIView *capCard;
@property (nonatomic, strong) UIView *aboutCard;
@end

@implementation SettingsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"الإعدادات";
    self.view.backgroundColor = [IPTheme backgroundColor];
    [self setupUI];
    [self refreshData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshData];
}

#pragma mark - UI Setup

- (void)setupUI {
    // ScrollView
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor]
    ]];

    // Main Stack
    self.mainStack = [[UIStackView alloc] init];
    self.mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainStack.axis = UILayoutConstraintAxisVertical;
    self.mainStack.spacing = 20;
    self.mainStack.alignment = UIStackViewAlignmentFill;
    [self.scrollView addSubview:self.mainStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.mainStack.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:16],
        [self.mainStack.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.mainStack.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.mainStack.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-24],
        [self.mainStack.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor]
    ]];

    // Build Cards
    self.envCard = [self buildEnvironmentCard];
    self.capCard = [self buildCapabilitiesCard];
    self.aboutCard = [self buildAboutCard];

    [self.mainStack addArrangedSubview:self.envCard];
    [self.mainStack addArrangedSubview:self.capCard];
    [self.mainStack addArrangedSubview:self.aboutCard];
}

#pragma mark - Card Builders

- (UIView *)buildEnvironmentCard {
    UIView *card = [self baseCard];

    // Header
    UIView *header = [self cardHeaderWithTitle:@"بيئة التشغيل"
                                      subtitle:@"معلومات النظام والجلبريك"
                                          icon:@"terminal.fill"];
    [card addSubview:header];

    // Divider
    UIView *divider = [self divider];
    [card addSubview:divider];

    // Info Rows Stack
    UIStackView *rows = [[UIStackView alloc] init];
    rows.translatesAutoresizingMaskIntoConstraints = NO;
    rows.axis = UILayoutConstraintAxisVertical;
    rows.spacing = 0;
    [card addSubview:rows];

    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],

        [divider.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:12],
        [divider.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [divider.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [divider.heightAnchor constraintEqualToConstant:0.5],

        [rows.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:8],
        [rows.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [rows.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [rows.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]
    ]];

    // Store reference to populate later
    objc_setAssociatedObject(card, @"rowsStack", rows, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    return card;
}

- (UIView *)buildCapabilitiesCard {
    UIView *card = [self baseCard];

    // Header
    UIView *header = [self cardHeaderWithTitle:@"القدرات"
                                      subtitle:@"حالة الأدوات والخدمات المتوفرة"
                                          icon:@"checkmark.shield.fill"];
    [card addSubview:header];

    // Divider
    UIView *divider = [self divider];
    [card addSubview:divider];

    // Tools Rows Stack
    UIStackView *rows = [[UIStackView alloc] init];
    rows.translatesAutoresizingMaskIntoConstraints = NO;
    rows.axis = UILayoutConstraintAxisVertical;
    rows.spacing = 0;
    [card addSubview:rows];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],

        [divider.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:12],
        [divider.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [divider.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [divider.heightAnchor constraintEqualToConstant:0.5],

        [rows.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:8],
        [rows.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [rows.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [rows.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]
    ]];

    objc_setAssociatedObject(card, @"rowsStack", rows, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    return card;
}

- (UIView *)buildAboutCard {
    UIView *card = [self baseCard];
    card.userInteractionEnabled = YES;

    // Tap gesture
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showAbout)];
    [card addGestureRecognizer:tap];

    // Icon
    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.image = [UIImage systemImageNamed:@"info.circle.fill"];
    iconView.tintColor = [IPTheme accentColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:iconView];

    // Labels
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"حول الأداة";
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentRight;
    [card addSubview:titleLabel];

    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subLabel.text = @"معلومات عن IPAInstallerPro";
    subLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    subLabel.textColor = [IPTheme mutedTextColor];
    subLabel.textAlignment = NSTextAlignmentRight;
    [card addSubview:subLabel];

    // Chevron
    UIImageView *chevron = [[UIImageView alloc] init];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.image = [UIImage systemImageNamed:@"chevron.left"];
    chevron.tintColor = [UIColor colorWithWhite:0.4 alpha:1];
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:chevron];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [iconView.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:28],
        [iconView.heightAnchor constraintEqualToConstant:28],

        [chevron.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [chevron.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [chevron.widthAnchor constraintEqualToConstant:14],
        [chevron.heightAnchor constraintEqualToConstant:14],

        [titleLabel.trailingAnchor constraintEqualToAnchor:chevron.leadingAnchor constant:-12],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:12],
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],

        [subLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        [subLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]
    ]];

    // Height
    [card.heightAnchor constraintGreaterThanOrEqualToConstant:72].active = YES;

    return card;
}

#pragma mark - Helpers

- (UIView *)baseCard {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [IPTheme cardColor];
    card.layer.cornerRadius = 16;
    card.layer.borderWidth = 0.5;
    card.layer.borderColor = [IPTheme subtleBorderColor].CGColor;
    card.clipsToBounds = YES;
    return card;
}

- (UIView *)divider {
    UIView *v = [[UIView alloc] init];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    v.backgroundColor = [IPTheme dividerColor];
    return v;
}

- (UIView *)cardHeaderWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)iconName {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    // Icon background
    UIView *iconBg = [[UIView alloc] init];
    iconBg.translatesAutoresizingMaskIntoConstraints = NO;
    iconBg.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1];
    iconBg.layer.cornerRadius = 10;
    [container addSubview:iconBg];

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.image = [UIImage systemImageNamed:iconName];
    iconView.tintColor = [IPTheme accentColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconBg addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentRight;
    [container addSubview:titleLabel];

    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subLabel.text = subtitle;
    subLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    subLabel.textColor = [IPTheme mutedTextColor];
    subLabel.textAlignment = NSTextAlignmentRight;
    [container addSubview:subLabel];

    [NSLayoutConstraint activateConstraints:@[
        [iconBg.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [iconBg.topAnchor constraintEqualToAnchor:container.topAnchor],
        [iconBg.widthAnchor constraintEqualToConstant:40],
        [iconBg.heightAnchor constraintEqualToConstant:40],

        [iconView.centerXAnchor constraintEqualToAnchor:iconBg.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconBg.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:22],
        [iconView.heightAnchor constraintEqualToConstant:22],

        [titleLabel.trailingAnchor constraintEqualToAnchor:iconBg.leadingAnchor constant:-12],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:2],

        [subLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        [subLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    return container;
}

- (UIView *)infoRowWithLabel:(NSString *)label value:(NSString *)value icon:(NSString *)iconName {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    // Icon
    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.image = [UIImage systemImageNamed:iconName];
    iconView.tintColor = [IPTheme mutedTextColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [row addSubview:iconView];

    // Label
    UILabel *labelLbl = [[UILabel alloc] init];
    labelLbl.translatesAutoresizingMaskIntoConstraints = NO;
    labelLbl.text = label;
    labelLbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    labelLbl.textColor = [IPTheme mutedTextColor];
    labelLbl.textAlignment = NSTextAlignmentRight;
    [row addSubview:labelLbl];

    // Value
    UILabel *valueLbl = [[UILabel alloc] init];
    valueLbl.translatesAutoresizingMaskIntoConstraints = NO;
    valueLbl.text = value ?: @"غير معروف";
    valueLbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    valueLbl.textColor = [UIColor whiteColor];
    valueLbl.textAlignment = NSTextAlignmentLeft;
    valueLbl.numberOfLines = 1;
    valueLbl.adjustsFontSizeToFitWidth = YES;
    valueLbl.minimumScaleFactor = 0.7;
    [row addSubview:valueLbl];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:18],
        [iconView.heightAnchor constraintEqualToConstant:18],

        [labelLbl.trailingAnchor constraintEqualToAnchor:iconView.leadingAnchor constant:-10],
        [labelLbl.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],

        [valueLbl.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [valueLbl.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [valueLbl.trailingAnchor constraintLessThanOrEqualToAnchor:labelLbl.leadingAnchor constant:-12],

        [row.heightAnchor constraintEqualToConstant:42]
    ]];

    return row;
}

- (UIView *)toolRowWithName:(NSString *)name path:(NSString *)path available:(BOOL)available {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    // Status indicator
    UIView *statusDot = [[UIView alloc] init];
    statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    statusDot.backgroundColor = available ? [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1] : [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1];
    statusDot.layer.cornerRadius = 5;
    [row addSubview:statusDot];

    // Name
    UILabel *nameLbl = [[UILabel alloc] init];
    nameLbl.translatesAutoresizingMaskIntoConstraints = NO;
    nameLbl.text = name;
    nameLbl.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    nameLbl.textColor = [UIColor whiteColor];
    nameLbl.textAlignment = NSTextAlignmentRight;
    [row addSubview:nameLbl];

    // Status text
    UILabel *statusLbl = [[UILabel alloc] init];
    statusLbl.translatesAutoresizingMaskIntoConstraints = NO;
    statusLbl.text = available ? @"متوفر" : @"غير متوفر";
    statusLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    statusLbl.textColor = available ? [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1] : [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1];
    statusLbl.textAlignment = NSTextAlignmentRight;
    [row addSubview:statusLbl];

    // Path
    UILabel *pathLbl = [[UILabel alloc] init];
    pathLbl.translatesAutoresizingMaskIntoConstraints = NO;
    pathLbl.text = path ?: @"";
    pathLbl.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    pathLbl.textColor = [UIColor colorWithWhite:0.5 alpha:1];
    pathLbl.textAlignment = NSTextAlignmentRight;
    pathLbl.numberOfLines = 1;
    [row addSubview:pathLbl];

    // Chevron
    UIImageView *chevron = [[UIImageView alloc] init];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.image = [UIImage systemImageNamed:@"chevron.left"];
    chevron.tintColor = [UIColor colorWithWhite:0.3 alpha:1];
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    [row addSubview:chevron];

    [NSLayoutConstraint activateConstraints:@[
        [statusDot.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [statusDot.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [statusDot.widthAnchor constraintEqualToConstant:10],
        [statusDot.heightAnchor constraintEqualToConstant:10],

        [nameLbl.trailingAnchor constraintEqualToAnchor:statusDot.leadingAnchor constant:-10],
        [nameLbl.topAnchor constraintEqualToAnchor:row.topAnchor constant:10],

        [statusLbl.trailingAnchor constraintEqualToAnchor:nameLbl.trailingAnchor],
        [statusLbl.topAnchor constraintEqualToAnchor:nameLbl.bottomAnchor constant:2],
        [statusLbl.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-10],

        [pathLbl.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [pathLbl.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [pathLbl.trailingAnchor constraintLessThanOrEqualToAnchor:nameLbl.leadingAnchor constant:-12],

        [chevron.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [chevron.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [chevron.widthAnchor constraintEqualToConstant:14],
        [chevron.heightAnchor constraintEqualToConstant:14],

        [row.heightAnchor constraintEqualToConstant:56]
    ]];

    // Separator
    UIView *sep = [[UIView alloc] init];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    sep.backgroundColor = [IPTheme dividerColor];
    [row addSubview:sep];
    [NSLayoutConstraint activateConstraints:@[
        [sep.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:8],
        [sep.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-8],
        [sep.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [sep.heightAnchor constraintEqualToConstant:0.5]
    ]];

    return row;
}

#pragma mark - Data Refresh

- (void)refreshData {
    JailbreakEnvironment *env = [JailbreakEnvironment sharedEnvironment];
    CapabilityManager *cap = [CapabilityManager sharedManager];

    // --- Environment Card ---
    UIStackView *envRows = objc_getAssociatedObject(self.envCard, @"rowsStack");
    [self clearStack:envRows];

    NSDictionary *envData = @{
        @"حالة الجلبريك": env.jailbreakType ?: @"غير معروف",
        @"الجهاز": env.deviceModel ?: @"غير معروف",
        @"إصدار iOS": env.iosVersion ?: @"غير معروف",
        @"المعمارية": env.architecture ?: @"غير محدد",
        @"مسار التطبيقات": env.applicationsPath ?: @"غير موقع",
        @"مسار المستندات": env.mobileDocumentsPath ?: @"غير موقع",
        @"مسار الروت": env.rootPath ?: @"غير موجود"
    };

    NSArray *order = @[@"حالة الجلبريك", @"الجهاز", @"إصدار iOS", @"المعمارية",
                       @"مسار التطبيقات", @"مسار المستندات", @"مسار الروت"];

    NSDictionary *icons = @{
        @"حالة الجلبريك": @"checkmark.circle.fill",
        @"الجهاز": @"iphone",
        @"إصدار iOS": @"number.circle.fill",
        @"المعمارية": @"cpu",
        @"مسار التطبيقات": @"folder.fill",
        @"مسار المستندات": @"doc.fill",
        @"مسار الروت": @"number.sign"
    };

    for (NSString *key in order) {
        UIView *row = [self infoRowWithLabel:key value:envData[key] icon:icons[key]];
        [envRows addArrangedSubview:row];
    }

    // --- Capabilities Card ---
    UIStackView *capRows = objc_getAssociatedObject(self.capCard, @"rowsStack");
    [self clearStack:capRows];

    for (Capability *c in [cap allCapabilities]) {
        UIView *row = [self toolRowWithName:c.name path:c.path available:c.isAvailable];
        [capRows addArrangedSubview:row];
    }
}

- (void)clearStack:(UIStackView *)stack {
    NSArray *views = [stack.arrangedSubviews copy];
    for (UIView *v in views) {
        [stack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
}

#pragma mark - Actions

- (void)showAbout {
    NSString *message = @"هذه الأداة متاحة حاليًا كنسخة تجريبية وليست الإصدار النهائي.\n\nقد تواجه بعض الأخطاء أو المشاكل أثناء الاستخدام، ونهدف من خلال هذه المرحلة إلى اختبار الأداة وتحسين استقرارها وتطوير ميزاتها.\n\nإذا واجهت أي خلل، أو لديك ملاحظة أو اقتراح لتحسين الأداة، نرجو منك مشاركة تجربتك معنا. ملاحظاتك تساعدنا على اكتشاف المشاكل ومعالجتها قبل إطلاق الإصدار النهائي.\n\nللتواصل والإبلاغ عن المشاكل:\nX: @Zainqkvd";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"حول الأداة" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
