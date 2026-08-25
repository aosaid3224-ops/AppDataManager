#import "AppDetailsViewController.h"
#import "Core/InstallationEngine.h"
#import "Core/IPAExportManager.h"
#import "Core/Logger.h"

@interface AppDetailsViewController ()
@property (nonatomic, strong) AppInfo *appInfo;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *bundleLabel;
@property (nonatomic, strong) UIButton *openButton;
@property (nonatomic, strong) UIButton *exportButton;
@property (nonatomic, strong) UIButton *deleteButton;
@end

@implementation AppDetailsViewController

- (instancetype)initWithAppInfo:(AppInfo *)appInfo {
    self = [super init];
    if (self) { _appInfo = appInfo; }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"معلومات التطبيق";
    self.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:1.0];
    [self setupViews];
}

- (void)setupViews {
    CGFloat w = self.view.bounds.size.width;
    CGFloat y = 20;
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    self.iconView = [[UIImageView alloc] initWithFrame:CGRectMake((w - 80) / 2, y, 80, 80)];
    self.iconView.layer.cornerRadius = 18;
    self.iconView.layer.masksToBounds = YES;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    if (self.appInfo.icon) {
        self.iconView.image = self.appInfo.icon;
    } else {
        self.iconView.image = [[UIImage systemImageNamed:@"app"] imageWithTintColor:[UIColor colorWithWhite:0.3 alpha:1.0]];
    }
    [self.scrollView addSubview:self.iconView];
    y += 100;

    self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w - 40, 28)];
    self.nameLabel.text = self.appInfo.name;
    self.nameLabel.textColor = [UIColor whiteColor];
    self.nameLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    self.nameLabel.textAlignment = NSTextAlignmentCenter;
    [self.scrollView addSubview:self.nameLabel];
    y += 36;

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(20, y, w - 40, 160)];
    card.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.11 alpha:1.0];
    card.layer.cornerRadius = 18;
    [self.scrollView addSubview:card];

    NSArray *details = @[
        @{@"title": @"معرّف الحزمة", @"value": self.appInfo.bundleID},
        @{@"title": @"الإصدار", @"value": self.appInfo.version},
        @{@"title": @"النوع", @"value": self.appInfo.isSystemApp ? @"نظام" : @"مستخدم"},
        @{@"title": @"الحماية", @"value": self.appInfo.isProtected ? @"محمي ✓" : @"غير محمي"},
    ];
    CGFloat dy = 14;
    for (NSDictionary *d in details) {
        UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(16, dy, 140, 22)];
        tl.text = d[@"title"];
        tl.textColor = [UIColor colorWithWhite:0.4 alpha:1.0];
        tl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        [card addSubview:tl];
        UILabel *vl = [[UILabel alloc] initWithFrame:CGRectMake(160, dy, card.bounds.size.width - 176, 22)];
        vl.text = d[@"value"];
        vl.textColor = [UIColor whiteColor];
        vl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        vl.textAlignment = NSTextAlignmentRight;
        [card addSubview:vl];
        dy += 34;
    }
    y += 180;

    self.openButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.openButton.frame = CGRectMake(20, y, w - 40, 52);
    [self.openButton setTitle:@"فتح التطبيق" forState:UIControlStateNormal];
    [self.openButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.openButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.openButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.6 blue:0.9 alpha:1.0];
    self.openButton.layer.cornerRadius = 14;
    [self.openButton addTarget:self action:@selector(openTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.openButton];
    y += 68;

    self.exportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.exportButton.frame = CGRectMake(20, y, w - 40, 52);
    [self.exportButton setTitle:@"استخراج IPA" forState:UIControlStateNormal];
    [self.exportButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.exportButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.exportButton.backgroundColor = [UIColor colorWithRed:0.43 green:0.30 blue:0.82 alpha:1.0];
    self.exportButton.layer.cornerRadius = 14;
    [self.exportButton addTarget:self action:@selector(exportTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.exportButton];
    y += 68;

    if (!self.appInfo.isProtected) {
        self.deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.deleteButton.frame = CGRectMake(20, y, w - 40, 52);
        [self.deleteButton setTitle:@"حذف التطبيق" forState:UIControlStateNormal];
        [self.deleteButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.deleteButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        self.deleteButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.25 blue:0.25 alpha:1.0];
        self.deleteButton.layer.cornerRadius = 14;
        [self.deleteButton addTarget:self action:@selector(deleteTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.scrollView addSubview:self.deleteButton];
    }
    self.scrollView.contentSize = CGSizeMake(w, y + 120);
}

- (void)openTapped:(UIButton *)sender {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://", self.appInfo.bundleID]];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تعذر الفتح"
            message:@"لا يوجد رابط URL scheme لهذا التطبيق" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)exportTapped:(UIButton *)sender {
    if (self.appInfo.bundlePath.length == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تعذر استخراج IPA"
            message:@"مسار التطبيق غير متاح من النظام" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    sender.enabled = NO;
    [sender setTitle:@"جارٍ استخراج IPA…" forState:UIControlStateNormal];
    NSString *suggestedName = self.appInfo.name.length > 0 ? self.appInfo.name : self.appInfo.bundleID;
    [[IPAExportManager sharedManager] exportApplicationAtPath:self.appInfo.bundlePath
                                                suggestedName:suggestedName
                                                   completion:^(NSURL *ipaURL, NSError *error) {
        sender.enabled = YES;
        [sender setTitle:@"استخراج IPA" forState:UIControlStateNormal];
        if (!ipaURL || error) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"فشل استخراج IPA"
                message:error.localizedDescription ?: @"تعذر إنشاء ملف IPA" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }

        UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[ipaURL]
                                                                             applicationActivities:nil];
        share.excludedActivityTypes = @[UIActivityTypeAssignToContact, UIActivityTypeAddToReadingList];
        share.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
            [[NSFileManager defaultManager] removeItemAtURL:ipaURL error:nil];
        };
        if (share.popoverPresentationController) {
            share.popoverPresentationController.sourceView = sender;
            share.popoverPresentationController.sourceRect = sender.bounds;
        }
        [self presentViewController:share animated:YES completion:nil];
    }];
}

- (void)deleteTapped:(UIButton *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تأكيد الحذف"
        message:[NSString stringWithFormat:@"هل أنت متأكد من حذف %@؟ لا يمكن التراجع.", self.appInfo.name]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"حذف" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *_) {
        NSString *appPath = self.appInfo.bundlePath;
        void (^done)(BOOL, NSString *) = ^(BOOL success, NSString *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    UIAlertController *ok = [UIAlertController alertControllerWithTitle:@"تم الحذف"
                        message:[NSString stringWithFormat:@"تم حذف %@ بنجاح", self.appInfo.name]
                        preferredStyle:UIAlertControllerStyleAlert];
                    [ok addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
                        [self.navigationController popViewControllerAnimated:YES];
                    }]];
                    [self presentViewController:ok animated:YES completion:nil];
                } else {
                    UIAlertController *err = [UIAlertController alertControllerWithTitle:@"فشل الحذف"
                        message:error preferredStyle:UIAlertControllerStyleAlert];
                    [err addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:err animated:YES completion:nil];
                }
            });
        };
        if (appPath && appPath.length > 0) {
            [[InstallationEngine sharedEngine] uninstallAppAtPath:appPath bundleID:self.appInfo.bundleID completion:done];
        } else {
            [[InstallationEngine sharedEngine] uninstallAppWithBundleID:self.appInfo.bundleID completion:done];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
