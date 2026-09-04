#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>

#define LOG_FILE @"/var/mobile/Documents/NaverBypass_Diagnostics.log"

@interface NaverSeriesBypassPrefsListController : PSListController
@property (nonatomic, strong) UIView *statusCard;
@property (nonatomic, strong) UILabel *statusTitle;
@property (nonatomic, strong) UILabel *statusValue;
@property (nonatomic, strong) UIView *statsCard;
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
    self.view.backgroundColor = [UIColor colorWithRed:0.96 green:0.96 blue:0.97 alpha:1.0];

    [self buildUI];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
    [self refresh];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.timer invalidate];
}

- (void)buildUI {
    CGFloat w = self.view.frame.size.width;
    CGFloat margin = 16;
    CGFloat top = 100;

    // Status Card
    self.statusCard = [[UIView alloc] initWithFrame:CGRectMake(margin, top, w - margin*2, 60)];
    self.statusCard.backgroundColor = [UIColor whiteColor];
    self.statusCard.layer.cornerRadius = 8;
    self.statusCard.layer.shadowColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.06].CGColor;
    self.statusCard.layer.shadowOffset = CGSizeMake(0, 2);
    self.statusCard.layer.shadowRadius = 4;

    self.statusTitle = [[UILabel alloc] initWithFrame:CGRectMake(margin, 12, w - margin*4, 18)];
    self.statusTitle.text = @"حالة التطبيق";
    self.statusTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.statusTitle.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
    self.statusTitle.textAlignment = NSTextAlignmentRight;

    self.statusValue = [[UILabel alloc] initWithFrame:CGRectMake(margin, 32, w - margin*4, 22)];
    self.statusValue.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.statusValue.textAlignment = NSTextAlignmentRight;

    [self.statusCard addSubview:self.statusTitle];
    [self.statusCard addSubview:self.statusValue];
    [self.view addSubview:self.statusCard];

    // Stats Card
    top += 76;
    self.statsCard = [[UIView alloc] initWithFrame:CGRectMake(margin, top, w - margin*2, 130)];
    self.statsCard.backgroundColor = [UIColor whiteColor];
    self.statsCard.layer.cornerRadius = 8;
    self.statsCard.layer.shadowColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.06].CGColor;
    self.statsCard.layer.shadowOffset = CGSizeMake(0, 2);
    self.statsCard.layer.shadowRadius = 4;

    UILabel *statsTitle = [[UILabel alloc] initWithFrame:CGRectMake(margin, 12, w - margin*4, 18)];
    statsTitle.text = @"الاحصائيات";
    statsTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    statsTitle.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
    statsTitle.textAlignment = NSTextAlignmentRight;

    self.statsLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, 36, w - margin*4, 86)];
    self.statsLabel.font = [UIFont systemFontOfSize:13];
    self.statsLabel.textColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
    self.statsLabel.numberOfLines = 0;
    self.statsLabel.textAlignment = NSTextAlignmentRight;
    self.statsLabel.lineBreakMode = NSLineBreakByWordWrapping;

    [self.statsCard addSubview:statsTitle];
    [self.statsCard addSubview:self.statsLabel];
    [self.view addSubview:self.statsCard];

    // Log Card
    top += 146;
    UIView *logCard = [[UIView alloc] initWithFrame:CGRectMake(margin, top, w - margin*2, 240)];
    logCard.backgroundColor = [UIColor whiteColor];
    logCard.layer.cornerRadius = 8;
    logCard.layer.shadowColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.06].CGColor;
    logCard.layer.shadowOffset = CGSizeMake(0, 2);
    logCard.layer.shadowRadius = 4;

    UILabel *logTitle = [[UILabel alloc] initWithFrame:CGRectMake(margin, 12, w - margin*4, 18)];
    logTitle.text = @"سجل الاحداث";
    logTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    logTitle.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
    logTitle.textAlignment = NSTextAlignmentRight;

    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(margin, 36, w - margin*4, 160)];
    self.logView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.06 alpha:1.0];
    self.logView.textColor = [UIColor colorWithRed:0.6 green:0.85 blue:0.6 alpha:1.0];
    self.logView.font = [UIFont fontWithName:@"SFMono-Regular" size:10];
    self.logView.editable = NO;
    self.logView.textAlignment = NSTextAlignmentRight;
    self.logView.layer.cornerRadius = 4;

    // Buttons row
    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(w - margin*2 - 80, 204, 70, 28);
    [copyBtn setTitle:@"نسخ" forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [copyBtn setTitleColor:[UIColor colorWithRed:0.2 green:0.5 blue:0.8 alpha:1.0] forState:UIControlStateNormal];
    copyBtn.backgroundColor = [UIColor colorWithRed:0.93 green:0.95 blue:0.98 alpha:1.0];
    copyBtn.layer.cornerRadius = 4;
    [copyBtn addTarget:self action:@selector(copyLogs) forControlEvents:UIControlEventTouchUpInside];

    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(margin, 204, 70, 28);
    [clearBtn setTitle:@"مسح" forState:UIControlStateNormal];
    clearBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [clearBtn setTitleColor:[UIColor colorWithRed:0.7 green:0.2 blue:0.2 alpha:1.0] forState:UIControlStateNormal];
    clearBtn.backgroundColor = [UIColor colorWithRed:0.98 green:0.93 blue:0.93 alpha:1.0];
    clearBtn.layer.cornerRadius = 4;
    [clearBtn addTarget:self action:@selector(clearLogs) forControlEvents:UIControlEventTouchUpInside];

    [logCard addSubview:logTitle];
    [logCard addSubview:self.logView];
    [logCard addSubview:copyBtn];
    [logCard addSubview:clearBtn];
    [self.view addSubview:logCard];

    // Footer
    top += 256;
    UILabel *footer = [[UILabel alloc] initWithFrame:CGRectMake(margin, top, w - margin*2, 30)];
    footer.text = @"الاصدار 2.1  |  المطور: aosaid";
    footer.font = [UIFont systemFontOfSize:11];
    footer.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    footer.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:footer];
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
        self.statusValue.textColor = [UIColor colorWithRed:0.75 green:0.2 blue:0.2 alpha:1.0];
        self.statusCard.layer.borderColor = [UIColor colorWithRed:0.9 green:0.7 blue:0.7 alpha:1.0].CGColor;
        self.statusCard.layer.borderWidth = 1;
    } else if (hasSuccess) {
        self.statusValue.text = @"يعمل - تم التجاوز";
        self.statusValue.textColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.3 alpha:1.0];
        self.statusCard.layer.borderColor = [UIColor colorWithRed:0.7 green:0.9 blue:0.7 alpha:1.0].CGColor;
        self.statusCard.layer.borderWidth = 1;
    } else {
        self.statusValue.text = @"في الانتظار...";
        self.statusValue.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
        self.statusCard.layer.borderWidth = 0;
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
    NSArray *last = lines.count > 25 ? [lines subarrayWithRange:NSMakeRange(lines.count - 25, 25)] : lines;
    self.logView.text = [last componentsJoinedByString:@"\n"];

    if (self.logView.text.length > 0) {
        NSRange bottom = NSMakeRange(self.logView.text.length - 1, 1);
        [self.logView scrollRangeToVisible:bottom];
    }
}

- (NSString *)readLog {
    if (![[NSFileManager defaultManager] fileExistsAtPath:LOG_FILE]) {
        return @"لا يوجد سجل بعد. افتح Naver Series واضغط على فصل.";
    }
    NSError *err = nil;
    NSString *content = [NSString stringWithContentsOfFile:LOG_FILE encoding:NSUTF8StringEncoding error:&err];
    return err ? @"خطأ في القراءة" : (content.length > 0 ? content : @"السجل فارغ");
}

- (void)copyLogs {
    UIPasteboard.generalPasteboard.string = [self readLog];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تم" message:@"تم نسخ السجل" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسنا" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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
