#import "DashboardViewController.h"

#define LOG_FILE @"/var/mobile/Documents/NaverBypass_Diagnostics.log"

@interface DashboardViewController ()
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *statsLabel;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, assign) BOOL uiBuilt;
@end

@implementation DashboardViewController

- (void)loadView {
    // Create a plain UIView as the base view
    UIView *v = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    v.backgroundColor = [UIColor blackColor];
    self.view = v;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"لوحة التحكم";
    self.uiBuilt = NO;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Build UI only once
    if (!self.uiBuilt) {
        [self buildUI];
        self.uiBuilt = YES;
    }

    // Start timer
    [self startTimer];

    // Immediate refresh
    [self refresh];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopTimer];
}

#pragma mark - UI Construction

- (void)buildUI {
    CGFloat w = self.view.frame.size.width;
    if (w == 0) w = [[UIScreen mainScreen] bounds].size.width;
    CGFloat m = 16;
    CGFloat y = 20;

    // === Status Card ===
    UIView *sCard = [[UIView alloc] initWithFrame:CGRectMake(m, y, w - m*2, 70)];
    sCard.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    sCard.layer.cornerRadius = 10;
    sCard.tag = 100;
    [self.view addSubview:sCard];

    UILabel *sTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, sCard.frame.size.width - 32, 18)];
    sTitle.text = @"حالة التطبيق";
    sTitle.font = [UIFont systemFontOfSize:12];
    sTitle.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    sTitle.textAlignment = NSTextAlignmentRight;
    [sCard addSubview:sTitle];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 34, sCard.frame.size.width - 32, 24)];
    self.statusLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.statusLabel.textAlignment = NSTextAlignmentRight;
    self.statusLabel.text = @"في الانتظار...";
    self.statusLabel.textColor = [UIColor grayColor];
    [sCard addSubview:self.statusLabel];
    y += 86;

    // === Stats Card ===
    UIView *stCard = [[UIView alloc] initWithFrame:CGRectMake(m, y, w - m*2, 140)];
    stCard.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    stCard.layer.cornerRadius = 10;
    stCard.tag = 101;
    [self.view addSubview:stCard];

    UILabel *stTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, stCard.frame.size.width - 32, 18)];
    stTitle.text = @"الاحصائيات";
    stTitle.font = [UIFont systemFontOfSize:12];
    stTitle.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    stTitle.textAlignment = NSTextAlignmentRight;
    [stCard addSubview:stTitle];

    self.statsLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 34, stCard.frame.size.width - 32, 96)];
    self.statsLabel.font = [UIFont systemFontOfSize:13];
    self.statsLabel.textColor = [UIColor lightGrayColor];
    self.statsLabel.numberOfLines = 0;
    self.statsLabel.textAlignment = NSTextAlignmentRight;
    self.statsLabel.text = @"افتح Naver Series واضغط على فصل";
    [stCard addSubview:self.statsLabel];
    y += 156;

    // === Log Card ===
    UIView *lCard = [[UIView alloc] initWithFrame:CGRectMake(m, y, w - m*2, 270)];
    lCard.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    lCard.layer.cornerRadius = 10;
    lCard.tag = 102;
    [self.view addSubview:lCard];

    UILabel *lTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, lCard.frame.size.width - 32, 18)];
    lTitle.text = @"سجل الاحداث";
    lTitle.font = [UIFont systemFontOfSize:12];
    lTitle.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    lTitle.textAlignment = NSTextAlignmentRight;
    [lCard addSubview:lTitle];

    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(m, 34, lCard.frame.size.width - m*2, 180)];
    self.logView.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.03 alpha:1.0];
    self.logView.textColor = [UIColor colorWithRed:0.4 green:0.8 blue:0.4 alpha:1.0];
    self.logView.font = [UIFont fontWithName:@"Courier" size:9];
    self.logView.editable = NO;
    self.logView.textAlignment = NSTextAlignmentRight;
    self.logView.text = @"لا يوجد سجل بعد...";
    [lCard addSubview:self.logView];

    UIButton *cpy = [UIButton buttonWithType:UIButtonTypeSystem];
    cpy.frame = CGRectMake(lCard.frame.size.width - m - 60, 222, 55, 26);
    [cpy setTitle:@"نسخ" forState:UIControlStateNormal];
    cpy.titleLabel.font = [UIFont systemFontOfSize:11];
    [cpy setTitleColor:[UIColor colorWithRed:0.3 green:0.5 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    [cpy addTarget:self action:@selector(doCopy) forControlEvents:UIControlEventTouchUpInside];
    [lCard addSubview:cpy];

    UIButton *clr = [UIButton buttonWithType:UIButtonTypeSystem];
    clr.frame = CGRectMake(m, 222, 55, 26);
    [clr setTitle:@"مسح" forState:UIControlStateNormal];
    clr.titleLabel.font = [UIFont systemFontOfSize:11];
    [clr setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [clr addTarget:self action:@selector(doClear) forControlEvents:UIControlEventTouchUpInside];
    [lCard addSubview:clr];
}

#pragma mark - Timer

- (void)startTimer {
    [self stopTimer];
    self.refreshTimer = [NSTimer timerWithTimeInterval:2.0 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.refreshTimer forMode:NSDefaultRunLoopMode];
}

- (void)stopTimer {
    if (self.refreshTimer) {
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
    }
}

#pragma mark - Data

- (void)refresh {
    @try {
        NSString *log = [self readLog];

        // Status
        BOOL blocked = [log containsString:@"BLOCKED"] || [log containsString:@"BAN"];
        BOOL success = [log containsString:@"200"] || [log containsString:@"SPOOF"];
        if (blocked) {
            self.statusLabel.text = @"محظور - خادمي";
            self.statusLabel.textColor = [UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:1.0];
        } else if (success) {
            self.statusLabel.text = @"يعمل - تم التجاوز";
            self.statusLabel.textColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.3 alpha:1.0];
        } else {
            self.statusLabel.text = @"في الانتظار...";
            self.statusLabel.textColor = [UIColor grayColor];
        }

        // Stats
        NSArray *lines = [log componentsSeparatedByString:@"\n"];
        int req=0, blk=0, spf=0, jb=0;
        for (NSString *ln in lines) {
            if ([ln containsString:@"[NETWORK] Request"]) req++;
            if ([ln containsString:@"[ALERT]"]) blk++;
            if ([ln containsString:@"[SPOOF]"]) spf++;
            if ([ln containsString:@"[JB-BYPASS]"]) jb++;
        }
        self.statsLabel.text = [NSString stringWithFormat:
            @"الطلبات: %d | الحظر: %d | التعديل: %d | JB: %d | الاسطر: %lu",
            req, blk, spf, jb, (unsigned long)lines.count];

        // Logs
        NSArray *last = lines.count > 15 ? [lines subarrayWithRange:NSMakeRange(lines.count - 15, 15)] : lines;
        self.logView.text = [last componentsJoinedByString:@"\n"];
        if (self.logView.text.length > 0) {
            [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length - 1, 1)];
        }
    }
    @catch (NSException *e) {
        NSLog(@"[NaverBypass] Dashboard refresh error: %@", e.reason);
    }
}

- (NSString *)readLog {
    if (![[NSFileManager defaultManager] fileExistsAtPath:LOG_FILE]) return @"";
    NSError *e = nil;
    NSString *s = [NSString stringWithContentsOfFile:LOG_FILE encoding:NSUTF8StringEncoding error:&e];
    return e ? @"" : s;
}

- (void)doCopy {
    @try {
        NSString *s = [self readLog];
        if (s.length > 0) {
            UIPasteboard.generalPasteboard.string = s;
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"تم" message:@"تم النسخ" preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"حسنا" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
        }
    }
    @catch (NSException *e) {
        NSLog(@"[NaverBypass] Copy error: %@", e.reason);
    }
}

- (void)doClear {
    @try {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"تأكيد" message:@"مسح السجل؟" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"الغاء" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"مسح" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *act) {
            [[NSFileManager defaultManager] removeItemAtPath:LOG_FILE error:nil];
            [self refresh];
        }]];
        [self presentViewController:a animated:YES completion:nil];
    }
    @catch (NSException *e) {
        NSLog(@"[NaverBypass] Clear error: %@", e.reason);
    }
}

@end
