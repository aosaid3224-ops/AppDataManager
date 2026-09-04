#import "DashboardViewController.h"

#define LOG_FILE @"/var/mobile/Documents/NaverBypass_Diagnostics.log"

@interface DashboardViewController () {
    UILabel *_statusLabel;
    UILabel *_statsLabel;
    UITextView *_logView;
    NSTimer *_timer;
}
@end

@implementation DashboardViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"لوحة التحكم";
    self.view.backgroundColor = [UIColor blackColor];

    CGFloat w = self.view.frame.size.width;
    CGFloat m = 16;
    CGFloat y = 20;

    // Status
    UIView *sCard = [self card:y w:w h:70];
    [self addTitle:@"حالة التطبيق" to:sCard];
    _statusLabel = [self addValue:@"في الانتظار..." to:sCard y:34 color:[UIColor grayColor]];
    [self.view addSubview:sCard];
    y += 86;

    // Stats
    UIView *stCard = [self card:y w:w h:140];
    [self addTitle:@"الاحصائيات" to:stCard];
    _statsLabel = [self addValue:@"افتح Naver Series واضغط على فصل" to:stCard y:34 color:[UIColor lightGrayColor]];
    _statsLabel.numberOfLines = 0;
    [self.view addSubview:stCard];
    y += 156;

    // Logs
    UIView *lCard = [self card:y w:w h:270];
    [self addTitle:@"سجل الاحداث" to:lCard];

    _logView = [[UITextView alloc] initWithFrame:CGRectMake(m, 34, lCard.frame.size.width - m*2, 180)];
    _logView.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.03 alpha:1.0];
    _logView.textColor = [UIColor colorWithRed:0.4 green:0.8 blue:0.4 alpha:1.0];
    _logView.font = [UIFont fontWithName:@"Courier" size:9];
    _logView.editable = NO;
    _logView.textAlignment = NSTextAlignmentRight;
    _logView.text = @"لا يوجد سجل بعد...";
    [lCard addSubview:_logView];

    UIButton *cpy = [self btn:@"نسخ" x:lCard.frame.size.width - m - 60 y:222 color:[UIColor colorWithRed:0.3 green:0.5 blue:1.0 alpha:1.0]];
    [cpy addTarget:self action:@selector(doCopy) forControlEvents:UIControlEventTouchUpInside];
    [lCard addSubview:cpy];

    UIButton *clr = [self btn:@"مسح" x:m y:222 color:[UIColor redColor]];
    [clr addTarget:self action:@selector(doClear) forControlEvents:UIControlEventTouchUpInside];
    [lCard addSubview:clr];

    [self.view addSubview:lCard];

    _timer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
    [self refresh];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (_timer) { [_timer invalidate]; _timer = nil; }
}

// MARK: - UI Helpers
- (UIView *)card:(CGFloat)y w:(CGFloat)w h:(CGFloat)h {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(16, y, w - 32, h)];
    v.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    v.layer.cornerRadius = 10;
    return v;
}

- (void)addTitle:(NSString *)text to:(UIView *)p {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, p.frame.size.width - 32, 18)];
    l.text = text;
    l.font = [UIFont systemFontOfSize:12];
    l.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    l.textAlignment = NSTextAlignmentRight;
    [p addSubview:l];
}

- (UILabel *)addValue:(NSString *)text to:(UIView)p y:(CGFloat)y color:(UIColor *)c {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, y, p.frame.size.width - 32, 22)];
    l.text = text;
    l.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    l.textColor = c;
    l.textAlignment = NSTextAlignmentRight;
    [p addSubview:l];
    return l;
}

- (UIButton *)btn:(NSString *)t x:(CGFloat)x y:(CGFloat)y color:(UIColor *)c {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(x, y, 55, 26);
    [b setTitle:t forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:11];
    [b setTitleColor:c forState:UIControlStateNormal];
    return b;
}

// MARK: - Data
- (void)refresh {
    NSString *log = [self readLog];

    // Status
    BOOL blocked = [log containsString:@"BLOCKED"] || [log containsString:@"BAN"];
    BOOL success = [log containsString:@"200"] || [log containsString:@"SPOOF"];
    if (blocked) {
        _statusLabel.text = @"محظور - خادمي";
        _statusLabel.textColor = [UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:1.0];
    } else if (success) {
        _statusLabel.text = @"يعمل - تم التجاوز";
        _statusLabel.textColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.3 alpha:1.0];
    } else {
        _statusLabel.text = @"في الانتظار...";
        _statusLabel.textColor = [UIColor grayColor];
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
    _statsLabel.text = [NSString stringWithFormat:
        @"الطلبات: %d | الحظر: %d | التعديل: %d | JB: %d | الاسطر: %lu",
        req, blk, spf, jb, (unsigned long)lines.count];

    // Logs
    NSArray *last = lines.count > 15 ? [lines subarrayWithRange:NSMakeRange(lines.count - 15, 15)] : lines;
    _logView.text = [last componentsJoinedByString:@"\n"];
    if (_logView.text.length > 0) {
        [_logView scrollRangeToVisible:NSMakeRange(_logView.text.length - 1, 1)];
    }
}

- (NSString *)readLog {
    if (![[NSFileManager defaultManager] fileExistsAtPath:LOG_FILE]) return @"";
    NSError *e = nil;
    NSString *s = [NSString stringWithContentsOfFile:LOG_FILE encoding:NSUTF8StringEncoding error:&e];
    return e ? @"" : s;
}

- (void)doCopy {
    NSString *s = [self readLog];
    if (s.length > 0) {
        UIPasteboard.generalPasteboard.string = s;
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"تم" message:@"تم النسخ" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"حسنا" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }
}

- (void)doClear {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"تأكيد" message:@"مسح السجل؟" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"الغاء" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"مسح" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *act) {
        [[NSFileManager defaultManager] removeItemAtPath:LOG_FILE error:nil];
        [self refresh];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
