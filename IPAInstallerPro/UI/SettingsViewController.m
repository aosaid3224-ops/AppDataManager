//
// SettingsViewController.m
// IPA Installer Pro
//
// v2.4 — Frame-based layout for reliability
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
#import <objc/runtime.h>

@interface SettingsViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
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

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat top = 20;
    if (@available(iOS 11.0, *)) {
        top = self.view.safeAreaInsets.top + 20;
    }

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.scrollView];

    UILabel *envHeader = [[UILabel alloc] initWithFrame:CGRectMake(16, top, w - 32, 30)];
    envHeader.text = @"🔧 بيئة التشغيل";
    envHeader.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    envHeader.textColor = [UIColor whiteColor];
    envHeader.textAlignment = NSTextAlignmentRight;
    envHeader.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:envHeader];

    self.envLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, top + 40, w - 32, 200)];
    self.envLabel.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    self.envLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    self.envLabel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    self.envLabel.layer.cornerRadius = 10;
    self.envLabel.clipsToBounds = YES;
    self.envLabel.numberOfLines = 0;
    self.envLabel.textAlignment = NSTextAlignmentRight;
    self.envLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:self.envLabel];

    UILabel *capHeader = [[UILabel alloc] initWithFrame:CGRectMake(16, top + 260, w - 32, 30)];
    capHeader.text = @"⚙️ القدرات";
    capHeader.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    capHeader.textColor = [UIColor whiteColor];
    capHeader.textAlignment = NSTextAlignmentRight;
    capHeader.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:capHeader];

    self.capLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, top + 300, w - 32, 300)];
    self.capLabel.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    self.capLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    self.capLabel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    self.capLabel.layer.cornerRadius = 10;
    self.capLabel.clipsToBounds = YES;
    self.capLabel.numberOfLines = 0;
    self.capLabel.textAlignment = NSTextAlignmentRight;
    self.capLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:self.capLabel];

    // ===== 🔍 زر اختبار Analyzer (مؤقت) =====
    UILabel *testHeader = [[UILabel alloc] initWithFrame:CGRectMake(16, top + 620, w - 32, 30)];
    testHeader.text = @"🧪 اختبار Analyzer";
    testHeader.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    testHeader.textColor = [UIColor whiteColor];
    testHeader.textAlignment = NSTextAlignmentRight;
    testHeader.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:testHeader];

    UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
    testButton.frame = CGRectMake(16, top + 660, w - 32, 50);
    testButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    [testButton setTitle:@"🔍 تحليل IPA في Documents" forState:UIControlStateNormal];
    [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    testButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    testButton.layer.cornerRadius = 12;
    testButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [testButton addTarget:self action:@selector(runAnalyzerTest) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:testButton];

    [self refreshData];
    self.scrollView.contentSize = CGSizeMake(w, top + 750);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    self.scrollView.frame = CGRectMake(0, 0, w, h);
}

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

#pragma mark - Analyzer Test

- (void)runAnalyzerTest {
    NSString *docsPath = @"/var/mobile/Documents";
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:docsPath error:nil];

    NSString *targetIPA = nil;
    for (NSString *f in files) {
        if ([f.pathExtension.lowercaseString isEqualToString:@"ipa"]) {
            targetIPA = [docsPath stringByAppendingPathComponent:f];
            break;
        }
    }

    if (!targetIPA) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"لا يوجد IPA"
                                                                       message:@"ضع ملف IPA في /var/mobile/Documents/"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIAlertController *progress = [UIAlertController alertControllerWithTitle:@"⏳ جاري التحليل..."
                                                                      message:targetIPA.lastPathComponent
                                                               preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progress animated:YES completion:nil];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        IPAStructuralResult *result = [[IPAStructuralAnalyzer sharedAnalyzer] analyzeIPAAtPath:targetIPA];

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

- (void)showRawResultViewer {
    UIViewController *vc = [[UIViewController alloc] init];
    vc.title = @"📋 التحليل الخام";
    vc.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:1.0];

    CGFloat w = vc.view.bounds.size.width;
    CGFloat h = vc.view.bounds.size.height;
    CGFloat safeTop = 0;
    if (@available(iOS 11.0, *)) {
        safeTop = vc.view.safeAreaInsets.top;
    }

    // Segment control
    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"📄 Report", @"🧾 JSON"]];
    seg.frame = CGRectMake(16, safeTop + 8, w - 32, 32);
    seg.selectedSegmentIndex = 0;
    seg.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    seg.tintColor = [UIColor systemBlueColor];
    if (@available(iOS 13.0, *)) {
        seg.selectedSegmentTintColor = [UIColor systemBlueColor];
        [seg setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateNormal];
        [seg setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
    }
    [seg addTarget:self action:@selector(rawSegmentChanged:) forControlEvents:UIControlEventValueChanged];
    [vc.view addSubview:seg];

    // TextView
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

    // Close button
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
