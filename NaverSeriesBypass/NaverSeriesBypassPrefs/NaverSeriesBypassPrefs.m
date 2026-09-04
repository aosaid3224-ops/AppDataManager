#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>

#define LOG_FILE @"/var/mobile/Documents/NaverBypass_Diagnostics.log"

@interface NaverSeriesBypassPrefsListController : PSListController
@property (nonatomic, strong) UILabel *statusValue;
@property (nonatomic, strong) UILabel *statsLabel;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) NSTimer *timer;
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

    // Build header view and attach to table
    UIView *header = [self buildHeaderView];
    self.table.tableHeaderView = header;

    // Timer
    self.timer = [NSTimer scheduledTimerWithTimeInterval:2.0 
                                                    target:self 
                                                  selector:@selector(refresh) 
                                                  userInfo:nil 
                                                   repeats:YES];
    [self refresh];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.timer invalidate];
}

- (UIView *)buildHeaderView {
    CGFloat w = self.view.frame.size.width;
    CGFloat margin = 16;
    CGFloat y = 0;

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 520)];
    container.backgroundColor = [UIColor clearColor];

    // === Status Card ===
    UIView *statusCard = [[UIView alloc] initWithFrame:CGRectMake(margin, y, w - margin*2, 70)];
    statusCard.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    statusCard.layer.cornerRadius = 10;

    UILabel *statusTitle = [[UILabel alloc] initWithFrame:CGRectMake(margin, 12, statusCard.frame.size.width - margin*2, 18)];
    statusTitle.text = @"حالة التطبيق";
    statusTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    statusTitle.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    statusTitle.textAlignment = NSTextAlignmentRight;

    self.statusValue = [[UILabel alloc] initWithFrame:CGRectMake(margin, 34, statusCard.frame.size.width - margin*2, 24)];
    self.statusValue.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.statusValue.textAlignment = NSTextAlignmentRight;
    self.statusValue.text = @"في الانتظار...";
    self.statusValue.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];

    [statusCard addSubview:statusTitle];
    [statusCard addSubview:self.statusValue];
    [container addSubview:statusCard];
    y += 86;

    // === Stats Card ===
    UIView *statsCard = [[UIView alloc] initWithFrame:CGRectMake(margin, y, w - margin*2, 140)];
    statsCard.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    statsCard.layer.cornerRadius = 10;

    UILabel *statsTitle = [[UILabel alloc] initWithFrame:CGRectMake(margin, 12, statsCard.frame.size.width - margin*2, 18)];
    statsTitle.text = @"الاحصائيات";
    statsTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    statsTitle.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    statsTitle.textAlignment = NSTextAlignmentRight;

    self.statsLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, 36, statsCard.frame.size.width - margin*2, 96)];
    self.statsLabel.font = [UIFont systemFontOfSize:13];
    self.statsLabel.textColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:1.0];
    self.statsLabel.numberOfLines = 0;
    self.statsLabel.textAlignment = NSTextAlignmentRight;
    self.statsLabel.text = @"لم يتم جمع بيانات بعد\nافتح Naver Series واضغط على فصل";

    [statsCard addSubview:statsTitle];
    [statsCard addSubview:self.statsLabel];
    [container addSubview:statsCard];
    y += 156;

    // === Log Card ===
    UIView *logCard = [[UIView alloc] initWithFrame:CGRectMake(margin, y, w - margin*2, 260)];
    logCard.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    logCard.layer.cornerRadius = 10;

    UILabel *logTitle = [[UILabel alloc] initWithFrame:CGRectMake(margin, 12, logCard.frame.size.width - margin*2, 18)];
    logTitle.text = @"سجل الاحداث";
    logTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    logTitle.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    logTitle.textAlignment = NSTextAlignmentRight;

    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(margin, 36, logCard.frame.size.width - margin*2, 170)];
    self.logView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.06 alpha:1.0];
    self.logView.textColor = [UIColor colorWithRed:0.4 green:0.8 blue:0.4 alpha:1.0];
    self.logView.font = [UIFont fontWithName:@"Menlo" size:10];
    self.logView.editable = NO;
    self.logView.textAlignment = NSTextAlignmentRight;
    self.logView.layer.cornerRadius = 6;
    self.logView.text = @"لا يوجد سجل بعد...";

    // Buttons
    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(logCard.frame.size.width - margin - 70, 214, 60, 28);
    [copyBtn setTitle:@"نسخ" forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [copyBtn setTitleColor:[UIColor colorWithRed:0.3 green:0.6 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    [copyBtn addTarget:self action:@selector(copyLogs) forControlEvents:UIControlEventTouchUpInside];

    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(margin, 214, 60, 28);
    [clearBtn setTitle:@"مسح" forState:UIControlStateNormal];
    clearBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [clearBtn setTitleColor:[UIColor colorWithRed:0.8 green:0.3 blue:0.3 alpha:1.0] forState:UIControlStateNormal];
    [clearBtn addTarget:self action:@selector(clearLogs) forControlEvents:UIControlEventTouchUpInside];

    [logCard addSubview:logTitle];
    [logCard addSubview:self.logView];
    [logCard addSubview:copyBtn];
    [logCard addSubview:clearBtn];
    [container addSubview:logCard];

    // Update container height
    CGRect cf = container.frame;
    cf.size.height = y + 276;
    container.frame = cf;

    return container;
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
        self.statusValue.textColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:1.0];
    } else if (hasSuccess) {
        self.statusValue.text = @"يعمل - تم التجاوز";
        self.statusValue.textColor = [UIColor colorWithRed:0.25 green:0.75 blue:0.35 alpha:1.0];
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
        NSRange bottom = NSMakeRange(self.logView.text.length - 1, 1);
        [self.logView scrollRangeToVisible:bottom];
    }
}

- (NSString *)readLog {
    if (![[NSFileManager defaultManager] fileExistsAtPath:LOG_FILE]) {
        return @"";
    }
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
