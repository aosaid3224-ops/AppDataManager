//
// SettingsViewController.m
// IPA Installer Pro
//
// v2.5 — Auto Layout, clean analyzer test section
//

#import "SettingsViewController.h"
#import "CapabilityManager.h"
#import "JailbreakEnvironment.h"
#import "RootlessManager.h"
#import "Logger.h"
#import "IPAStructuralAnalyzer.h"
#import "IPAStructuralResult.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface SettingsViewController () <UIDocumentPickerDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *envLabel;
@property (nonatomic, strong) UILabel *capLabel;
@property (nonatomic, copy) NSString *lastReportText;
@property (nonatomic, copy) NSString *lastJsonText;
@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"الإعدادات";
    self.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:1.0];

    [self setupScrollView];
    [self setupEnvironmentSection];
    [self setupCapabilitiesSection];
    [self setupAnalyzerSection];
    [self refreshData];
}

#pragma mark - ScrollView + ContentView

- (void)setupScrollView {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentView.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.contentView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor]
    ]];}

#pragma mark - Environment Section

- (void)setupEnvironmentSection {
    UILabel *header = [[UILabel alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.text = @"🔧 بيئة التشغيل";
    header.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    header.textColor = [UIColor whiteColor];
    header.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:header];

    self.envLabel = [[UILabel alloc] init];
    self.envLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.envLabel.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    self.envLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    self.envLabel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    self.envLabel.layer.cornerRadius = 10;
    self.envLabel.clipsToBounds = YES;
    self.envLabel.numberOfLines = 0;
    self.envLabel.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:self.envLabel];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16],
        [header.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [header.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [self.envLabel.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:8],
        [self.envLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.envLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.envLabel.heightAnchor constraintGreaterThanOrEqualToConstant:180]
    ]];}

#pragma mark - Capabilities Section

- (void)setupCapabilitiesSection {
    UILabel *header = [[UILabel alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.text = @"⚙️ القدرات";
    header.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    header.textColor = [UIColor whiteColor];
    header.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:header];

    self.capLabel = [[UILabel alloc] init];
    self.capLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.capLabel.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    self.capLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    self.capLabel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    self.capLabel.layer.cornerRadius = 10;
    self.capLabel.clipsToBounds = YES;
    self.capLabel.numberOfLines = 0;
    self.capLabel.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:self.capLabel];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.envLabel.bottomAnchor constant:24],
        [header.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [header.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [self.capLabel.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:8],
        [self.capLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.capLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.capLabel.heightAnchor constraintGreaterThanOrEqualToConstant:260]
    ]];}

#pragma mark - Analyzer Test Section

- (void)setupAnalyzerSection {
    UILabel *header = [[UILabel alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.text = @"🧪 اختبار Analyzer";
    header.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    header.textColor = [UIColor whiteColor];
    header.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:header];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    [btn setTitle:@"🔍 اختيار وتحليل IPA" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    btn.layer.cornerRadius = 12;
    [btn addTarget:self action:@selector(pickIPAFile) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:btn];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.capLabel.bottomAnchor constant:32],
        [header.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [header.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [btn.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:12],
        [btn.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [btn.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [btn.heightAnchor constraintEqualToConstant:52],
        [btn.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-24]
    ]];}

#pragma mark - Data

- (void)refreshData {
    JailbreakEnvironment *env = [JailbreakEnvironment sharedEnvironment];
    CapabilityManager *cap = [CapabilityManager sharedManager];

    NSMutableString *envStr = [NSMutableString string];
    [envStr appendFormat:@"Jailbreak: %@\n", env.jailbreakType ?: @"Unknown"];
    [envStr appendFormat:@"Rootless: %@\n", env.isRootless ? @"Yes" : @"No"];
    [envStr appendFormat:@"OS Version: %@\n", env.osVersion ?: @"Unknown"];
    [envStr appendFormat:@"Device: %@\n", env.deviceModel ?: @"Unknown"];
    [envStr appendFormat:@"Applications: %@\n", env.applicationsPath ?: @"N/A"];
    [envStr appendFormat:@"usr/bin: %@\n", env.usrBinPath ?: @"N/A"];
    [envStr appendFormat:@"Documents: %@\n", env.mobileDocumentsPath ?: @"N/A"];
    [envStr appendFormat:@"Root Path: %@\n", env.rootPath ?: @"N/A"];

    self.envLabel.text = envStr;

    NSMutableString *capStr = [NSMutableString string];
    [capStr appendFormat:@"%@\n", [cap installationReadinessStatus]];
    [capStr appendString:@"\n=== Tools ===\n"];
    for (Capability *c in [cap allCapabilities]) {
        NSString *icon = c.isAvailable ? @"✅" : @"❌";
        [capStr appendFormat:@"%@ %@: %@\n", icon, c.name, c.statusMessage];
    }

    self.capLabel.text = capStr;
}

#pragma mark - IPA File Picker

- (void)pickIPAFile {
    NSArray *types = @[@"public.item", @"public.data"];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:types inMode:UIDocumentPickerModeOpen];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count == 0) return;

    NSURL *url = urls[0];
    NSString *path = url.path;

    if (![path.pathExtension.lowercaseString isEqualToString:@"ipa"]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ملف غير صالح"
                                                                       message:@"الملف المختار ليس IPA. اختر ملفًا ينتهي بـ .ipa"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIAlertController *progress = [UIAlertController alertControllerWithTitle:@"⏳ جاري التحليل..."
                                                                      message:url.lastPathComponent
                                                               preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progress animated:YES completion:nil];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        IPAStructuralResult *result = [[IPAStructuralAnalyzer sharedAnalyzer] analyzeIPAAtPath:path];

        NSString *jsonPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ipa_analysis.json"];
        [[result jsonRepresentation] writeToFile:jsonPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

        self.lastReportText = [result summaryReport];
        self.lastJsonText = [result jsonRepresentation];

        dispatch_async(dispatch_get_main_queue(), ^{
            [progress dismissViewControllerAnimated:YES completion:^{
                [self showRawResultViewer];
            }];
        });
    });
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    // User cancelled
}

#pragma mark - Raw Result Viewer

- (void)showRawResultViewer {
    UIViewController *vc = [[UIViewController alloc] init];
    vc.title = @"📋 لوغات التحليل الخام";
    vc.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:1.0];

    CGFloat w = vc.view.bounds.size.width;
    CGFloat h = vc.view.bounds.size.height;
    CGFloat safeTop = 0;
    if (@available(iOS 11.0, *)) {
        safeTop = vc.view.safeAreaInsets.top;
    }

    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"📄 Report", @"🧾 JSON"]];
    seg.frame = CGRectMake(16, safeTop + 8, w - 32, 32);
    seg.selectedSegmentIndex = 0;
    seg.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    if (@available(iOS 13.0, *)) {
        seg.selectedSegmentTintColor = [UIColor systemBlueColor];
        [seg setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateNormal];
        [seg setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
    } else {
        seg.tintColor = [UIColor systemBlueColor];
    }
    [seg addTarget:self action:@selector(rawSegmentChanged:) forControlEvents:UIControlEventValueChanged];
    [vc.view addSubview:seg];

    UITextView *tv = [[UITextView alloc] initWithFrame:CGRectMake(8, safeTop + 48, w - 16, h - safeTop - 100)];
    tv.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1.0];
    tv.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    tv.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    tv.editable = NO;
    tv.selectable = YES;
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.text = self.lastReportText ?: @"No data";
    tv.tag = 9001;
    [vc.view addSubview:tv];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(16, h - 44, w - 32, 36);
    closeBtn.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    [closeBtn setTitle:@"❌ إغلاق" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    closeBtn.layer.cornerRadius = 8;
    closeBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [closeBtn addTarget:self action:@selector(closeRawViewer:) forControlEvents:UIControlEventTouchUpInside];
    [vc.view addSubview:closeBtn];

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.navigationBar.barStyle = UIBarStyleBlack;
    nav.navigationBar.tintColor = [UIColor whiteColor];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)rawSegmentChanged:(UISegmentedControl *)sender {
    UIViewController *presented = self.presentedViewController;
    if ([presented isKindOfClass:[UINavigationController class]]) {
        UIViewController *top = [(UINavigationController *)presented topViewController];
        for (UIView *v in top.view.subviews) {
            if ([v isKindOfClass:[UITextView class]] && v.tag == 9001) {
                UITextView *tv = (UITextView *)v;
                tv.text = (sender.selectedSegmentIndex == 0) ? self.lastReportText : self.lastJsonText;
                break;
            }
        }
    }
}

- (void)closeRawViewer:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
