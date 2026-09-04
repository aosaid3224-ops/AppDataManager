#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>

#define LOG_FILE @"/var/mobile/Documents/NaverBypass_Diagnostics.log"

// ============================================
// DASHBOARD VIEW CONTROLLER
// ============================================
@interface NaverBypassDashboardVC : UIViewController
@property (nonatomic, strong) UILabel *statusValue;
@property (nonatomic, strong) UILabel *statsLabel;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation NaverBypassDashboardVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"لوحة التحكم";
    self.view.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.06 alpha:1.0];

    // Close button
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"اغلاق" style:UIBarButtonItemStylePlain target:self action:@selector(close)];

    [self buildUI];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
    [self refresh];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.timer invalidate];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)buildUI {
    CGFloat w = self.view.frame.size.width;
    CGFloat margin = 16;
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];

    CGFloat y = 20;

    // === STATUS ===
    UIView *statusCard = [self cardWithY:y width:w margin:margin height:70];
    [self addTitle:@"حالة التطبيق" to:statusCard];
    self.statusValue = [[UILabel alloc] initWithFrame:CGRectMake(margin, 34, statusCard.frame.size.width - margin*2, 24)];
    self.statusValue.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.statusValue.textAlignment = NSTextAlignmentRight;
    self.statusValue.text = @"في الانتظار...";
    self.statusValue.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    [statusCard addSubview:self.statusValue];
    [scroll addSubview:statusCard];
    y += 86;

    // === STATS ===
    UIView *statsCard = [self cardWithY:y width:w margin:margin height:130];
    [self addTitle:@"الاحصائيات" to:statsCard];
    self.statsLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, 34, statsCard.frame.size.width - margin*2, 88)];
    self.statsLabel.font = [UIFont systemFontOfSize:13];
    self.statsLabel.textColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:1.0];
    self.statsLabel.numberOfLines = 0;
    self.statsLabel.textAlignment = NSTextAlignmentRight;
    self.statsLabel.text = @"لم يتم جمع بيانات بعد\nافتح Naver Series واضغط على فصل";
    [statsCard addSubview:self.statsLabel];
    [scroll addSubview:statsCard];
    y += 146;

    // === LOGS ===
    UIView *logCard = [self cardWithY:y width:w margin:margin height:300];
    [self addTitle:@"سجل الاحداث" to:logCard];

    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(margin, 34, logCard.frame.size.width - margin*2, 210)];
    self.logView.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.03 alpha:1.0];
    self.logView.textColor = [UIColor colorWithRed:0.35 green:0.75 blue:0.35 alpha:1.0];
    self.logView.font = [UIFont fontWithName:@"Menlo" size:10];
    self.logView.editable = NO;
    self.logView.textAlignment = NSTextAlignmentRight;
    self.logView.layer.cornerRadius = 6;
    self.logView.text = @"لا يوجد سجل بعد...";
    [logCard addSubview:self.logView];

    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(logCard.frame.size.width - margin - 70, 252, 60, 28);
    [copyBtn setTitle:@"نسخ" forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [copyBtn setTitleColor:[UIColor colorWithRed:0.3 green:0.6 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    [copyBtn addTarget:self action:@selector(copyLogs) forControlEvents:UIControlEventTouchUpInside];
    [logCard addSubview:copyBtn];

    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(margin, 252, 60, 28);
    [clearBtn setTitle:@"مسح" forState:UIControlStateNormal];
    clearBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [clearBtn setTitleColor:[UIColor colorWithRed:0.8 green:0.3 blue:0.3 alpha:1.0] forState:UIControlStateNormal];
    [clearBtn addTarget:self action:@selector(clearLogs) forControlEvents:UIControlEventTouchUpInside];
    [logCard addSubview:clearBtn];

    [scroll addSubview:logCard];
    y += 316;

    scroll.contentSize = CGSizeMake(w, y + 20);
}

- (UIView *)cardWithY:(CGFloat)y width:(CGFloat)w margin:(CGFloat)margin height:(CGFloat)h {
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(margin, y, w - margin*2, h)];
    card.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    card.layer.cornerRadius = 12;
    return card;
}

- (void)addTitle:(NSString *)title to:(UIView *)view {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, view.frame.size.width - 32, 18)];
    label.text = title;
    label.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    label.textColor = [UIColor colorWithRed:0.45 green:0.45 blue:0.45 alpha:1.0];
    label.textAlignment = NSTextAlignmentRight;
    [view addSubview:label];
}

- (void)refresh {
    [self updateStatus];
    [self updateStats];
    [self updateLogs];
}

- (void)updateStatus {
    NSString *log = [self readLog];
    BOOL hasBlock = [log containsString:@"BLOCKED"] || [log containsString:@"BAN MESSAGE"];
    BOOL hasSuccess = [log containsString:@"Status: 200"] || [log containsString:@"[SPOOF]"];

    if (hasBlock) {
        self.statusValue.text = @"التطبيق محظور - خادمي";
        self.statusValue.textColor = [UIColor colorWithRed:0.9 green:0.25 blue:0.25 alpha:1.0];
    } else if (hasSuccess) {
        self.statusValue.text = @"يعمل - تم التجاوز";
        self.statusValue.textColor = [UIColor colorWithRed:0.25 green:0.8 blue:0.35 alpha:1.0];
    } else {
        self.statusValue.text = @"في الانتظار...";
        self.statusValue.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    }
}

- (void)updateStats {
    NSString *log = [self readLog];
    NSArray *lines = [log componentsSeparatedByString:@"\n"];
    int requests = 0, blocks = 0, spoofs = 0, jb = 0;
    for (NSString *line in lines) {
        if ([line containsString:@"[NETWORK] Request"]) requests++;
        if ([line containsString:@"[ALERT]"]) blocks++;
        if ([line containsString:@"[SPOOF]"]) spoofs++;
        if ([line containsString:@"[JB-BYPASS]"]) jb++;
    }
    NSString *stats = [NSString stringWithFormat:
        @"الطلبات المرسلة: %d\n"
        @"محاولات الحظر: %d\n"
        @"العناصر المعدلة: %d\n"
        @"تجاوز JB: %d\n"
        @"اجمالي الاسطر: %lu",
        requests, blocks, spoofs, jb, (unsigned long)lines.count];
    self.statsLabel.text = stats;
}

- (void)updateLogs {
    NSString *log = [self readLog];
    NSArray *lines = [log componentsSeparatedByString:@"\n"];
    NSArray *last = lines.count > 20 ? [lines subarrayWithRange:NSMakeRange(lines.count - 20, 20)] : lines;
    self.logView.text = [last componentsJoinedByString:@"\n"];
    if (self.logView.text.length > 0) {
        [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length - 1, 1)];
    }
}

- (NSString *)readLog {
    if (![[NSFileManager defaultManager] fileExistsAtPath:LOG_FILE]) return @"";
    NSError *err = nil;
    NSString *content = [NSString stringWithContentsOfFile:LOG_FILE encoding:NSUTF8StringEncoding error:&err];
    return err ? @"" : content;
}

- (void)copyLogs {
    NSString *log = [self readLog];
    if (log.length > 0) {
        UIPasteboard.generalPasteboard.string = log;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تم" message:@"تم نسخ السجل" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"حسنا" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)clearLogs {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تأكيد" message:@"مسح السجل؟" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"الغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"مسح" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [[NSFileManager defaultManager] removeItemAtPath:LOG_FILE error:nil];
        [self refresh];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

// ============================================
// MAIN PREFERENCES LIST CONTROLLER
// ============================================
@interface NaverSeriesBypassPrefsListController : PSListController
@end

@implementation NaverSeriesBypassPrefsListController

- (id)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)openDashboard {
    NaverBypassDashboardVC *dashboard = [[NaverBypassDashboardVC alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:dashboard];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

@end
