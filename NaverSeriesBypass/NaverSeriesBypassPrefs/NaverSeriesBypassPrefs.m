#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>

#define LOG_FILE @"/var/mobile/Documents/NaverBypass_Diagnostics.log"

// ============================================
// DASHBOARD VIEW CONTROLLER (UIViewController)
// ============================================
@interface NaverBypassDashboardVC : UIViewController {
    UILabel *_statusValue;
    UILabel *_statsLabel;
    UITextView *_logView;
    NSTimer *_timer;
}
@end

@implementation NaverBypassDashboardVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"لوحة التحكم";
    self.view.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.06 alpha:1.0];

    CGFloat w = self.view.frame.size.width;
    CGFloat m = 16;
    CGFloat y = 20;

    // Status Card
    UIView *sCard = [self cardAt:y w:w m:m h:70];
    [self label:@"حالة التطبيق" y:12 parent:sCard];
    _statusValue = [self valueLabelAt:34 parent:sCard];
    _statusValue.text = @"في الانتظار...";
    [sCard addSubview:_statusValue];
    [self.view addSubview:sCard];
    y += 86;

    // Stats Card
    UIView *stCard = [self cardAt:y w:w m:m h:130];
    [self label:@"الاحصائيات" y:12 parent:stCard];
    _statsLabel = [self valueLabelAt:34 parent:stCard];
    _statsLabel.numberOfLines = 0;
    _statsLabel.text = @"لم يتم جمع بيانات بعد\nافتح Naver Series واضغط على فصل";
    [stCard addSubview:_statsLabel];
    [self.view addSubview:stCard];
    y += 146;

    // Log Card
    UIView *lCard = [self cardAt:y w:w m:m h:280];
    [self label:@"سجل الاحداث" y:12 parent:lCard];

    _logView = [[UITextView alloc] initWithFrame:CGRectMake(m, 34, lCard.frame.size.width - m*2, 190)];
    _logView.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.03 alpha:1.0];
    _logView.textColor = [UIColor colorWithRed:0.35 green:0.75 blue:0.35 alpha:1.0];
    _logView.font = [UIFont fontWithName:@"Menlo" size:10];
    _logView.editable = NO;
    _logView.textAlignment = NSTextAlignmentRight;
    _logView.layer.cornerRadius = 6;
    _logView.text = @"لا يوجد سجل بعد...";
    [lCard addSubview:_logView];

    UIButton *cpy = [self button:@"نسخ" x:lCard.frame.size.width - m - 60 y:232 color:[UIColor colorWithRed:0.3 green:0.6 blue:1.0 alpha:1.0]];
    [cpy addTarget:self action:@selector(copyLogs) forControlEvents:UIControlEventTouchUpInside];
    [lCard addSubview:cpy];

    UIButton *clr = [self button:@"مسح" x:m y:232 color:[UIColor colorWithRed:0.8 green:0.3 blue:0.3 alpha:1.0]];
    [clr addTarget:self action:@selector(clearLogs) forControlEvents:UIControlEventTouchUpInside];
    [lCard addSubview:clr];

    [self.view addSubview:lCard];

    // Refresh timer
    _timer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
    [self refresh];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (_timer) { [_timer invalidate]; _timer = nil; }
}

// UI Helpers
- (UIView *)cardAt:(CGFloat)y w:(CGFloat)w m:(CGFloat)m h:(CGFloat)h {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(m, y, w - m*2, h)];
    v.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    v.layer.cornerRadius = 12;
    return v;
}

- (void)label:(NSString *)text y:(CGFloat)y parent:(UIView *)p {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, y, p.frame.size.width - 32, 18)];
    l.text = text;
    l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    l.textColor = [UIColor colorWithRed:0.45 green:0.45 blue:0.45 alpha:1.0];
    l.textAlignment = NSTextAlignmentRight;
    [p addSubview:l];
}

- (UILabel *)valueLabelAt:(CGFloat)y parent:(UIView *)p {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, y, p.frame.size.width - 32, 24)];
    l.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    l.textAlignment = NSTextAlignmentRight;
    l.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    return l;
}

- (UIButton *)button:(NSString *)title x:(CGFloat)x y:(CGFloat)y color:(UIColor *)c {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(x, y, 60, 28);
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [b setTitleColor:c forState:UIControlStateNormal];
    return b;
}

// Data
- (void)refresh {
    NSString *log = [self readLog];

    // Status
    BOOL hasBlock = [log containsString:@"BLOCKED"] || [log containsString:@"BAN MESSAGE"];
    BOOL hasSuccess = [log containsString:@"Status: 200"] || [log containsString:@"[SPOOF]"];
    if (hasBlock) {
        _statusValue.text = @"التطبيق محظور - خادمي";
        _statusValue.textColor = [UIColor colorWithRed:0.9 green:0.25 blue:0.25 alpha:1.0];
    } else if (hasSuccess) {
        _statusValue.text = @"يعمل - تم التجاوز";
        _statusValue.textColor = [UIColor colorWithRed:0.25 green:0.8 blue:0.35 alpha:1.0];
    } else {
        _statusValue.text = @"في الانتظار...";
        _statusValue.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    }

    // Stats
    NSArray *lines = [log componentsSeparatedByString:@"\n"];
    int req = 0, blk = 0, spf = 0, jb = 0;
    for (NSString *ln in lines) {
        if ([ln containsString:@"[NETWORK] Request"]) req++;
        if ([ln containsString:@"[ALERT]"]) blk++;
        if ([ln containsString:@"[SPOOF]"]) spf++;
        if ([ln containsString:@"[JB-BYPASS]"]) jb++;
    }
    _statsLabel.text = [NSString stringWithFormat:
        @"الطلبات المرسلة: %d\n"
        @"محاولات الحظر: %d\n"
        @"العناصر المعدلة: %d\n"
        @"تجاوز JB: %d\n"
        @"اجمالي الاسطر: %lu",
        req, blk, spf, jb, (unsigned long)lines.count];

    // Logs
    NSArray *last = lines.count > 18 ? [lines subarrayWithRange:NSMakeRange(lines.count - 18, 18)] : lines;
    _logView.text = [last componentsJoinedByString:@"\n"];
    if (_logView.text.length > 0) {
        [_logView scrollRangeToVisible:NSMakeRange(_logView.text.length - 1, 1)];
    }
}

- (NSString *)readLog {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:LOG_FILE]) return @"";
    NSError *err = nil;
    NSString *c = [NSString stringWithContentsOfFile:LOG_FILE encoding:NSUTF8StringEncoding error:&err];
    return err ? @"" : c;
}

- (void)copyLogs {
    NSString *log = [self readLog];
    if (log.length > 0) {
        UIPasteboard.generalPasteboard.string = log;
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"تم" message:@"تم نسخ السجل" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"حسنا" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }
}

- (void)clearLogs {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"تأكيد" message:@"مسح السجل؟" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"الغاء" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"مسح" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *act) {
        [[NSFileManager defaultManager] removeItemAtPath:LOG_FILE error:nil];
        [self refresh];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

@end

// ============================================
// MAIN LIST CONTROLLER
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

@end
