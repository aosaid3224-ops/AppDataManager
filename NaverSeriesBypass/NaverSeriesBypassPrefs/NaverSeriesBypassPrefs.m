#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>

#define LOG_FILE @"/var/mobile/Documents/NaverBypass_Diagnostics.log"
#define PREFS_FILE @"/var/mobile/Library/Preferences/com.aosaid.naverseriesbypass.plist"

@interface NaverSeriesBypassPrefsListController : PSListController
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *statsLabel;
@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) NSTimer *refreshTimer;
@end

@implementation NaverSeriesBypassPrefsListController

- (id)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"نافر سيريس بايباس";

    // Arabic RTL
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;

    // Setup UI
    [self setupStatusView];
    [self setupStatsView];
    [self setupLogView];

    // Start live refresh
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 
                                                         target:self 
                                                       selector:@selector(refreshAll) 
                                                       userInfo:nil 
                                                        repeats:YES];
    [self refreshAll];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.refreshTimer invalidate];
}

// ============================================
// STATUS VIEW - حالة التطبيق
// ============================================
- (void)setupStatusView {
    UIView *statusContainer = [[UIView alloc] initWithFrame:CGRectMake(15, 100, self.view.frame.size.width - 30, 80)];
    statusContainer.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    statusContainer.layer.cornerRadius = 12;
    statusContainer.layer.borderWidth = 1;
    statusContainer.layer.borderColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.22 alpha:1.0].CGColor;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, statusContainer.frame.size.width - 30, 20)];
    titleLabel.text = @"حالة التطبيق";
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentRight;

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 35, statusContainer.frame.size.width - 30, 30)];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:20];
    self.statusLabel.textAlignment = NSTextAlignmentRight;
    self.statusLabel.text = @"جاري التحقق...";

    [statusContainer addSubview:titleLabel];
    [statusContainer addSubview:self.statusLabel];
    [self.view addSubview:statusContainer];
}

// ============================================
// STATS VIEW - الإحصائيات
// ============================================
- (void)setupStatsView {
    UIView *statsContainer = [[UIView alloc] initWithFrame:CGRectMake(15, 190, self.view.frame.size.width - 30, 120)];
    statsContainer.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    statsContainer.layer.cornerRadius = 12;
    statsContainer.layer.borderWidth = 1;
    statsContainer.layer.borderColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.22 alpha:1.0].CGColor;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, statsContainer.frame.size.width - 30, 20)];
    titleLabel.text = @"الإحصائيات";
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentRight;

    self.statsLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 35, statsContainer.frame.size.width - 30, 75)];
    self.statsLabel.font = [UIFont systemFontOfSize:13];
    self.statsLabel.textColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:1.0];
    self.statsLabel.numberOfLines = 0;
    self.statsLabel.textAlignment = NSTextAlignmentRight;
    self.statsLabel.text = @"جاري جمع البيانات...";

    [statsContainer addSubview:titleLabel];
    [statsContainer addSubview:self.statsLabel];
    [self.view addSubview:statsContainer];
}

// ============================================
// LOG VIEW - سجل الأحداث
// ============================================
- (void)setupLogView {
    UIView *logContainer = [[UIView alloc] initWithFrame:CGRectMake(15, 320, self.view.frame.size.width - 30, 280)];
    logContainer.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.07 alpha:1.0];
    logContainer.layer.cornerRadius = 12;
    logContainer.layer.borderWidth = 1;
    logContainer.layer.borderColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.22 alpha:1.0].CGColor;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, logContainer.frame.size.width - 30, 20)];
    titleLabel.text = @"سجل الأحداث (Logs)";
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentRight;

    self.logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 35, logContainer.frame.size.width - 20, 200)];
    self.logTextView.backgroundColor = [UIColor clearColor];
    self.logTextView.textColor = [UIColor colorWithRed:0.4 green:0.8 blue:0.4 alpha:1.0];
    self.logTextView.font = [UIFont fontWithName:@"Menlo" size:10];
    self.logTextView.editable = NO;
    self.logTextView.textAlignment = NSTextAlignmentRight;
    self.logTextView.layoutManager.allowsNonContiguousLayout = NO;

    // Buttons
    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(logContainer.frame.size.width - 100, 240, 85, 30);
    [copyBtn setTitle:@"📋 نسخ" forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [copyBtn addTarget:self action:@selector(copyLogs) forControlEvents:UIControlEventTouchUpInside];

    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(15, 240, 85, 30);
    [clearBtn setTitle:@"🗑 مسح" forState:UIControlStateNormal];
    clearBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [clearBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [clearBtn addTarget:self action:@selector(clearLogs) forControlEvents:UIControlEventTouchUpInside];

    [logContainer addSubview:titleLabel];
    [logContainer addSubview:self.logTextView];
    [logContainer addSubview:copyBtn];
    [logContainer addSubview:clearBtn];
    [self.view addSubview:logContainer];
}

// ============================================
// REFRESH ALL - تحديث كل شيء
// ============================================
- (void)refreshAll {
    [self updateStatus];
    [self updateStats];
    [self updateLogs];
}

- (void)updateStatus {
    NSString *logContent = [self readLogFile];

    BOOL hasBlock = [logContent containsString:@"BLOCKED!"] || 
                    [logContent containsString:@"BAN MESSAGE"] ||
                    [logContent containsString:@"차단"];

    BOOL hasSuccess = [logContent containsString:@"Response Status: 200"] ||
                      [logContent containsString:@"[SPOOF]"];

    if (hasBlock) {
        self.statusLabel.text = @"❌ التطبيق محظور (خادمي)";
        self.statusLabel.textColor = [UIColor redColor];
    } else if (hasSuccess) {
        self.statusLabel.text = @"✅ التطبيق يعمل (تم التجاوز)";
        self.statusLabel.textColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0];
    } else {
        self.statusLabel.text = @"⏳ في انتظار الاستخدام...";
        self.statusLabel.textColor = [UIColor orangeColor];
    }
}

- (void)updateStats {
    NSString *logContent = [self readLogFile];

    int totalRequests = 0;
    int blockedRequests = 0;
    int spoofedItems = 0;
    int jbBypass = 0;

    NSArray *lines = [logContent componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        if ([line containsString:@"[NETWORK] Request"]) totalRequests++;
        if ([line containsString:@"[ALERT] BLOCKED"]) blockedRequests++;
        if ([line containsString:@"[SPOOF]"]) spoofedItems++;
        if ([line containsString:@"[JB-BYPASS]"]) jbBypass++;
    }

    NSString *stats = [NSString stringWithFormat:
        @"📊 الطلبات المرسلة: %d\n"
        @"🚫 محاولات الحظر: %d\n"
        @"🔧 عناصر تم تغييرها: %d\n"
        @"🛡️ JB-Bypass: %d\n"
        @"📄 إجمالي الأسطر: %lu",
        totalRequests, blockedRequests, spoofedItems, jbBypass, (unsigned long)lines.count];

    self.statsLabel.text = stats;
}

- (void)updateLogs {
    NSString *logContent = [self readLogFile];

    // Get last 30 lines
    NSArray *lines = [logContent componentsSeparatedByString:@"\n"];
    NSArray *lastLines = lines;
    if (lines.count > 30) {
        lastLines = [lines subarrayWithRange:NSMakeRange(lines.count - 30, 30)];
    }

    NSString *display = [lastLines componentsJoinedByString:@"\n"];
    self.logTextView.text = display;

    // Auto-scroll to bottom
    if (self.logTextView.text.length > 0) {
        NSRange bottom = NSMakeRange(self.logTextView.text.length - 1, 1);
        [self.logTextView scrollRangeToVisible:bottom];
    }
}

// ============================================
// HELPERS
// ============================================
- (NSString *)readLogFile {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:LOG_FILE]) {
        return @"لا يوجد سجل بعد.\nافتح تطبيق Naver Series واضغط على فصل.";
    }

    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:LOG_FILE 
                                                   encoding:NSUTF8StringEncoding 
                                                      error:&error];
    if (error) {
        return [NSString stringWithFormat:@"خطأ في القراءة: %@", error.localizedDescription];
    }

    return content.length > 0 ? content : @"السجل فارغ.";
}

- (void)copyLogs {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = [self readLogFile];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تم" 
                                                                   message:@"تم نسخ السجل إلى الحافظة" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)clearLogs {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تأكيد" 
                                                                   message:@"هل تريد مسح السجل؟" 
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"مسح" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:LOG_FILE error:nil];
        [self refreshAll];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

@end
