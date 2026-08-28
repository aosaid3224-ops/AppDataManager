#import "IPAInstallViewController.h"
#import "InstallationProgressViewController.h"
#import "Core/InstallationEngine.h"
#import "Core/CapabilityManager.h"
#import "Core/Logger.h"
#import "Core/IPAValidator.h"
#import "Core/IPAMultiInstancePreparer.h"

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
@property (nonatomic, strong) UISwitch *multiInstanceSwitch;
@property (nonatomic, strong) UILabel *multiInstanceLabel;
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
    self.title = @"تثبيت IPA";
    self.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:1.0];

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
    self.detailsContainer.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.11 alpha:1.0];
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
        titleLabel.textColor = [UIColor colorWithWhite:0.4 alpha:1.0];
        titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        [self.detailsContainer addSubview:titleLabel];

        UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(160, detailY, self.detailsContainer.bounds.size.width - 176, 22)];
        valueLabel.text = detail[@"value"];
        valueLabel.textColor = [UIColor whiteColor];
        valueLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        valueLabel.textAlignment = NSTextAlignmentRight;
        [self.detailsContainer addSubview:valueLabel];

        detailY += 34;
    }

    y += 220;

    // Isolated multi-instance option. OFF is the default and preserves the normal path.
    UIView *multiRow = [[UIView alloc] initWithFrame:CGRectMake(margin, y, w - margin * 2, 54)];
    multiRow.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.11 alpha:1.0];
    multiRow.layer.cornerRadius = 16.0;
    multiRow.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [self.view addSubview:multiRow];
    self.multiInstanceLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 8, multiRow.bounds.size.width - 92, 38)];
    self.multiInstanceLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.multiInstanceLabel.text = @"نسخ متعددة";
    self.multiInstanceLabel.textColor = UIColor.whiteColor;
    self.multiInstanceLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.multiInstanceLabel.textAlignment = NSTextAlignmentRight;
    self.multiInstanceLabel.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [multiRow addSubview:self.multiInstanceLabel];
    self.multiInstanceSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    self.multiInstanceSwitch.on = NO;
    self.multiInstanceSwitch.onTintColor = [UIColor colorWithRed:0.25 green:0.75 blue:0.42 alpha:1.0];
    self.multiInstanceSwitch.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.multiInstanceSwitch.accessibilityLabel = @"نسخ متعددة";
    self.multiInstanceSwitch.accessibilityHint = @"عند التفعيل سيتم تجهيز نسخة مستقلة بمعرّف حزمة مختلف";
    [multiRow addSubview:self.multiInstanceSwitch];
    self.multiInstanceSwitch.center = CGPointMake(multiRow.bounds.size.width - 48.0, multiRow.bounds.size.height / 2.0);
    self.multiInstanceSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    y += 70;

    // Install button
    self.installButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.installButton.frame = CGRectMake(margin, y, w - margin * 2, 54);
    [self.installButton setTitle:@"تثبيت التطبيق" forState:UIControlStateNormal];
    [self.installButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.installButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.installButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.7 blue:0.5 alpha:1.0];
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
    CapabilityManager *capMgr = [CapabilityManager sharedManager];
    [capMgr scanCapabilities];
    if (!capMgr.canInstallIPA) {
        [self showReadinessAlert:capMgr];
        return;
    }
    if (self.multiInstanceSwitch.isOn) {
        sender.enabled = NO;
        [sender setTitle:@"جاري تجهيز النسخة..." forState:UIControlStateNormal];
        NSString *displayName = self.ipaInfo.displayName ?: self.ipaInfo.name ?: @"التطبيق";
        [[IPAMultiInstancePreparer sharedPreparer] prepareIPAAtPath:self.ipaInfo.filePath displayName:displayName completion:^(NSString *preparedIPAPath, NSString *instanceBundleID, NSString *instanceName, NSError *error) {
            sender.enabled = YES;
            [sender setTitle:@"تثبيت التطبيق" forState:UIControlStateNormal];
            if (error || preparedIPAPath.length == 0) {
                [self showReadinessAlertWithMessage:error.localizedDescription ?: @"تعذر إنشاء نسخة مستقلة؛ لم يتم تسجيل أي تطبيق ولم تتأثر النسخة الأصلية."];
                return;
            }
            NSLog(@"[IPAInstallerPro] multi-instance prepared bundleID=%@ path=%@", instanceBundleID, preparedIPAPath);
            [self presentProgressForIPAPath:preparedIPAPath name:[NSString stringWithFormat:@"%@ نسخة", instanceName ?: displayName]];
        }];
        return;
    }
    // OFF: this is the existing installation path, unchanged.
    [self presentProgressForIPAPath:self.ipaInfo.filePath name:self.ipaInfo.displayName ?: self.ipaInfo.name];
}

- (void)presentProgressForIPAPath:(NSString *)ipaPath name:(NSString *)name {
    InstallationProgressViewController *progressVC = [[InstallationProgressViewController alloc] init];
    progressVC.ipaName = name;
    progressVC.ipaPath = ipaPath;
    progressVC.modalPresentationStyle = UIModalPresentationFullScreen;
    if (self.launchedFromDuplicate) {
        progressVC.dismissOnDuplicateSuccess = YES;
        __weak typeof(self) weakSelf = self;
        __weak InstallationProgressViewController *weakProgressVC = progressVC;
        progressVC.duplicateCompletionHandler = ^(BOOL success, InstallationResult *result) {
            if (!success) return;
            __strong typeof(weakSelf) strongSelf = weakSelf;
            __strong InstallationProgressViewController *strongProgressVC = weakProgressVC;
            if (!strongSelf || !strongProgressVC) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongProgressVC dismissViewControllerAnimated:YES completion:^{
                    [strongSelf dismissViewControllerAnimated:YES completion:^{
                        if (strongSelf.duplicateCompletionHandler) strongSelf.duplicateCompletionHandler(YES);
                    }];
                }];
            });
        };
    }
    [self presentViewController:progressVC animated:YES completion:nil];
}

- (void)showReadinessAlertWithMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تعذر تجهيز النسخة" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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
