#import "IPAInstallViewController.h"
#import "InstallationProgressViewController.h"
#import "Core/InstallationEngine.h"
#import "Core/CapabilityManager.h"
#import "Core/Logger.h"
#import "Core/IPAValidator.h"

@interface IPAInstallViewController ()
@property (nonatomic, strong) IPAExtractedInfo *ipaInfo;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UIView *detailsContainer;
@property (nonatomic, strong) UIButton *installButton;
@property (nonatomic, strong) UILabel *validationLabel;
@property (nonatomic, strong) UIActivityIndicatorView *validationSpinner;
@property (nonatomic, assign) BOOL isValidated;
@property (nonatomic, assign) BOOL isValid;
@end

@implementation IPAInstallViewController

- (instancetype)initWithIPAInfo:(IPAExtractedInfo *)info {
    self = [super init];
    if (self) {
        _ipaInfo = info;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"تفاصيل IPA";
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.view.backgroundColor = [UIColor colorWithRed:0.025 green:0.027 blue:0.05 alpha:1.0];

    [self setupViews];
    [self validateIPA];
}

- (void)setupViews {
    CGFloat margin = 20;
    CGFloat y = 20;
    CGFloat w = self.view.bounds.size.width;

    // Icon
    self.iconView = [[UIImageView alloc] initWithFrame:CGRectMake((w - 90) / 2, y, 90, 90)];
    self.iconView.layer.cornerRadius = 20;
    self.iconView.layer.masksToBounds = YES;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    UIImage *icon = self.ipaInfo.icon;
    if (icon) {
        self.iconView.image = icon;
    } else {
        self.iconView.image = [[UIImage systemImageNamed:@"doc.zipper"] imageWithTintColor:[UIColor colorWithWhite:0.3 alpha:1.0]];
    }
    [self.view addSubview:self.iconView];

    y += 110;

    // Name
    self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, w - margin * 2, 30)];
    self.nameLabel.text = self.ipaInfo.displayName ?: self.ipaInfo.name;
    self.nameLabel.textColor = [UIColor whiteColor];
    self.nameLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    self.nameLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.nameLabel];

    y += 38;

    // Validation status
    self.validationSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.validationSpinner.center = CGPointMake(w / 2, y + 10);
    self.validationSpinner.color = [UIColor colorWithWhite:0.5 alpha:1.0];
    [self.validationSpinner startAnimating];
    [self.view addSubview:self.validationSpinner];

    self.validationLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, w - margin * 2, 22)];
    self.validationLabel.text = @"جاري التحقق...";
    self.validationLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    self.validationLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.validationLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.validationLabel];

    y += 50;

    // Details container
    self.detailsContainer = [[UIView alloc] initWithFrame:CGRectMake(margin, y, w - margin * 2, 200)];
    self.detailsContainer.backgroundColor = [UIColor colorWithRed:0.07 green:0.075 blue:0.13 alpha:1.0];
    self.detailsContainer.layer.borderWidth = 1.0;
    self.detailsContainer.layer.borderColor = [UIColor colorWithWhite:0.18 alpha:1.0].CGColor;
    self.detailsContainer.layer.cornerRadius = 18;
    [self.view addSubview:self.detailsContainer];

    NSArray *details = @[
        @{@"title": @"معرّف الحزمة", @"value": self.ipaInfo.bundleID ?: @"غير معروف"},
        @{@"title": @"الإصدار", @"value": self.ipaInfo.version ?: @"غير معروف"},
        @{@"title": @"الحجم", @"value": self.ipaInfo.formattedSize ?: @"غير معروف"},
        @{@"title": @"الحد الأدنى لنظام iOS", @"value": self.ipaInfo.minOSVersion ?: @"غير محدد"},
        @{@"title": @"الفريق", @"value": self.ipaInfo.teamIdentifier ?: @"غير موقّع"},
    ];

    CGFloat detailY = 14;
    for (NSDictionary *detail in details) {
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, detailY, 140, 22)];
        titleLabel.text = detail[@"title"];
        titleLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        titleLabel.textAlignment = NSTextAlignmentRight;
        [self.detailsContainer addSubview:titleLabel];

        UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(160, detailY, self.detailsContainer.bounds.size.width - 176, 22)];
        valueLabel.text = detail[@"value"];
        valueLabel.textColor = [UIColor whiteColor];
        valueLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        valueLabel.textAlignment = NSTextAlignmentLeft;
        valueLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
        [self.detailsContainer addSubview:valueLabel];

        detailY += 34;
    }

    y += 220;

    // Install button
    self.installButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.installButton.frame = CGRectMake(margin, y, w - margin * 2, 54);
    [self.installButton setTitle:@"تثبيت التطبيق" forState:UIControlStateNormal];
    [self.installButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.installButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.installButton.backgroundColor = [UIColor colorWithRed:0.42 green:0.45 blue:0.95 alpha:1.0];
    self.installButton.layer.borderWidth = 1.0;
    self.installButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
    self.installButton.layer.cornerRadius = 14;
    self.installButton.enabled = NO;
    self.installButton.alpha = 0.5;
    [self.installButton addTarget:self action:@selector(installTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.installButton];
}

- (void)validateIPA {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        IPAValidationResult *result = [[IPAValidator sharedValidator] validateIPAAtPath:self.ipaInfo.filePath];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.validationSpinner stopAnimating];
            self.isValidated = YES;
            self.isValid = result.isReadyForInstall;

            if (result.isReadyForInstall) {
                // Check for missing dependencies
                NSArray<NSString *> *missingLibs = [[IPAValidator sharedValidator] checkDependenciesAtAppPath:self.ipaInfo.appDirectoryPath];
                if (missingLibs.count > 0) {
                    NSString *libsList = [missingLibs componentsJoinedByString:@", "];
                    self.validationLabel.text = [NSString stringWithFormat:@"⚠️ جاهز لكن ينقص: %@", libsList];
                    self.validationLabel.textColor = [UIColor colorWithRed:1.0 green:0.6 blue:0.0 alpha:1.0];
                    self.installButton.enabled = YES;
                    self.installButton.alpha = 1.0;
                    // Show alert about missing libraries
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"مكتبات مفقودة"
                                                                                 message:[NSString stringWithFormat:@"التطبيق يحتاج هذه المكتبات:\n%@\n\nقد لا يعمل التطبيق بدونها. هل تريد الاستمرار؟", libsList]
                                                                          preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"تثبيت" style:UIAlertActionStyleDefault handler:nil]];
                    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                        self.installButton.enabled = NO;
                        self.installButton.alpha = 0.5;
                    }]];
                    [self presentViewController:alert animated:YES completion:nil];
                } else {
                    self.validationLabel.text = @"جاهز للتثبيت ✓";
                    self.validationLabel.textColor = [UIColor colorWithRed:0.3 green:0.7 blue:0.5 alpha:1.0];
                    self.installButton.enabled = YES;
                    self.installButton.alpha = 1.0;
                }
            } else {
                self.validationLabel.text = result.statusMessage;
                self.validationLabel.textColor = [UIColor colorWithRed:0.9 green:0.4 blue:0.3 alpha:1.0];
                self.installButton.enabled = NO;
                self.installButton.alpha = 0.5;
                [self.installButton setTitle:@"لا يمكن التثبيت" forState:UIControlStateNormal];
                self.installButton.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
            }
        });
    });
}

- (void)installTapped:(UIButton *)sender {
    if (!self.isValid) return;

    // Check installation readiness
    CapabilityManager *capMgr = [CapabilityManager sharedManager];
    [capMgr scanCapabilities];

    if (!capMgr.canInstallIPA) {
        [self showReadinessAlert:capMgr];
        return;
    }

    // Show progress
    InstallationProgressViewController *progressVC = [[InstallationProgressViewController alloc] init];
    progressVC.ipaName = self.ipaInfo.displayName ?: self.ipaInfo.name;
    progressVC.ipaPath = self.ipaInfo.filePath;
    progressVC.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:progressVC animated:YES completion:nil];
}

- (void)showReadinessAlert:(CapabilityManager *)capMgr {
    NSString *status = [capMgr installationReadinessStatus];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"جاهزية التثبيت"
        message:status
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
