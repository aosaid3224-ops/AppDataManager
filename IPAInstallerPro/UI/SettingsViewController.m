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

@interface SettingsViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UILabel *envLabel;
@property (nonatomic, strong) UILabel *capLabel;
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

    // ScrollView
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.scrollView];

    // Environment Header
    UILabel *envHeader = [[UILabel alloc] initWithFrame:CGRectMake(16, top, w - 32, 30)];
    envHeader.text = @"🔧 بيئة التشغيل";
    envHeader.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    envHeader.textColor = [UIColor whiteColor];
    envHeader.textAlignment = NSTextAlignmentRight;
    envHeader.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:envHeader];

    // Environment Info
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

    // Capabilities Header
    UILabel *capHeader = [[UILabel alloc] initWithFrame:CGRectMake(16, top + 260, w - 32, 30)];
    capHeader.text = @"⚙️ القدرات";
    capHeader.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    capHeader.textColor = [UIColor whiteColor];
    capHeader.textAlignment = NSTextAlignmentRight;
    capHeader.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:capHeader];

    // Capabilities Info
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
    // ==========================================

    [self refreshData];

    // Set scroll content size (زودناها للزر)
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

#pragma mark - Analyzer Test (مؤقت)

- (void)runAnalyzerTest {
    // ابحث عن أول IPA في Documents
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
                                                                       message:@"ضع ملف IPA في /var/mobile/Documents/ وجرب مرة ثانية"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // شغل التحليل في background
    UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:@"جاري التحليل..."
                                                                           message:targetIPA.lastPathComponent
                                                                    preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progressAlert animated:YES completion:nil];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"🔍 [Analyzer Test] بدأ تحليل: %@", targetIPA);

        IPAStructuralResult *result = [[IPAStructuralAnalyzer sharedAnalyzer] analyzeIPAAtPath:targetIPA];

        // احفظ JSON
        NSString *jsonPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ipa_analysis.json"];
        [[result jsonRepresentation] writeToFile:jsonPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

        NSLog(@"🔍 [Analyzer Test] انتهى التحليل. JSON: %@", jsonPath);
        NSLog(@"\n========== ANALYZER REPORT ==========\n%@", [result summaryReport]);

        dispatch_async(dispatch_get_main_queue(), ^{
            [progressAlert dismissViewControllerAnimated:YES completion:^{
                NSString *msg = [NSString stringWithFormat:
                    @"✅ Success: %@\n"
                    @"⏱ Duration: %.1f ms\n\n"
                    @"📦 Bundles: %ld\n"
                    @"⚙️ Executables: %ld\n"
                    @"📚 Frameworks: %ld\n"
                    @"🔗 Dependencies: %ld\n"
                    @"🍕 Slices: %ld\n\n"
                    @"📄 JSON saved to:\n%@",
                    result.success ? @"YES" : @"NO",
                    result.analysisDurationMs,
                    (long)result.bundleCount,
                    (long)result.executableCount,
                    (long)result.frameworkCount,
                    (long)result.dependencyCount,
                    (long)result.sliceCount,
                    jsonPath];

                UIAlertController *resultAlert = [UIAlertController alertControllerWithTitle:@"✅ نتيجة التحليل"
                                                                                     message:msg
                                                                              preferredStyle:UIAlertControllerStyleAlert];
                [resultAlert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:resultAlert animated:YES completion:nil];
            }];
        });
    });
}

@end
