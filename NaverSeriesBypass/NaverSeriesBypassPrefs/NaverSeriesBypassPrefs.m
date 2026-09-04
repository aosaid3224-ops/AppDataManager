#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>

#define LOG_FILE @"/var/mobile/Documents/NaverBypass_Diagnostics.log"

static UIWindow *NBActiveWindow(void) {
    UIApplication *application = [UIApplication sharedApplication];
    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) return window;
        }
    }
    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.windows.firstObject) return windowScene.windows.firstObject;
    }
    return nil;
}

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
    UIWindow *window = NBActiveWindow();
    if (!window) return;

    // Remove existing overlay if any
    UIView *existing = [window viewWithTag:99999];
    if (existing) [existing removeFromSuperview];

    // Create overlay
    CGFloat w = window.bounds.size.width;
    CGFloat h = window.bounds.size.height;

    UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
    overlay.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.06 alpha:1.0];
    overlay.tag = 99999;
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // Close button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(w - 70, 50, 60, 36);
    [closeBtn setTitle:@"اغلاق" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeDashboard) forControlEvents:UIControlEventTouchUpInside];
    [overlay addSubview:closeBtn];

    CGFloat y = 100;
    CGFloat m = 16;

    // === Status ===
    UIView *sCard = [self cardAt:CGRectMake(m, y, w - m*2, 70) parent:overlay];
    [self titleLabel:@"حالة التطبيق" parent:sCard];
    UILabel *status = [self valueLabel:@"في الانتظار..." color:[UIColor grayColor] parent:sCard y:34];
    status.tag = 10001;
    y += 86;

    // === Stats ===
    UIView *stCard = [self cardAt:CGRectMake(m, y, w - m*2, 130) parent:overlay];
    [self titleLabel:@"الاحصائيات" parent:stCard];
    UILabel *stats = [self valueLabel:@"افتح Naver Series واضغط على فصل" color:[UIColor lightGrayColor] parent:stCard y:34];
    stats.numberOfLines = 0;
    stats.tag = 10002;
    y += 146;

    // === Logs ===
    UIView *lCard = [self cardAt:CGRectMake(m, y, w - m*2, h - y - 30) parent:overlay];
    [self titleLabel:@"سجل الاحداث" parent:lCard];

    UITextView *logView = [[UITextView alloc] initWithFrame:CGRectMake(m, 34, lCard.frame.size.width - m*2, lCard.frame.size.height - 80)];
    logView.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.03 alpha:1.0];
    logView.textColor = [UIColor colorWithRed:0.4 green:0.8 blue:0.4 alpha:1.0];
    logView.font = [UIFont fontWithName:@"Courier" size:9];
    logView.editable = NO;
    logView.textAlignment = NSTextAlignmentRight;
    logView.tag = 10003;
    logView.text = @"لا يوجد سجل بعد...";
    [lCard addSubview:logView];

    UIButton *cpy = [UIButton buttonWithType:UIButtonTypeSystem];
    cpy.frame = CGRectMake(lCard.frame.size.width - m - 60, lCard.frame.size.height - 36, 55, 26);
    [cpy setTitle:@"نسخ" forState:UIControlStateNormal];
    cpy.titleLabel.font = [UIFont systemFontOfSize:11];
    [cpy setTitleColor:[UIColor colorWithRed:0.3 green:0.5 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    [cpy addTarget:self action:@selector(copyLogs) forControlEvents:UIControlEventTouchUpInside];
    [lCard addSubview:cpy];

    UIButton *clr = [UIButton buttonWithType:UIButtonTypeSystem];
    clr.frame = CGRectMake(m, lCard.frame.size.height - 36, 55, 26);
    [clr setTitle:@"مسح" forState:UIControlStateNormal];
    clr.titleLabel.font = [UIFont systemFontOfSize:11];
    [clr setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [clr addTarget:self action:@selector(clearLogs) forControlEvents:UIControlEventTouchUpInside];
    [lCard addSubview:clr];

    [window addSubview:overlay];

    // Start refresh
    [self refreshDashboard];
    [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(refreshDashboard) userInfo:nil repeats:YES];
}

- (void)closeDashboard {
    UIWindow *window = NBActiveWindow();
    UIView *overlay = [window viewWithTag:99999];
    if (overlay) {
        [UIView animateWithDuration:0.2 animations:^{
            overlay.alpha = 0;
        } completion:^(BOOL finished) {
            [overlay removeFromSuperview];
        }];
    }
}

- (UIView *)cardAt:(CGRect)frame parent:(UIView *)parent {
    UIView *v = [[UIView alloc] initWithFrame:frame];
    v.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    v.layer.cornerRadius = 10;
    [parent addSubview:v];
    return v;
}

- (void)titleLabel:(NSString *)text parent:(UIView *)p {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, p.frame.size.width - 32, 18)];
    l.text = text;
    l.font = [UIFont systemFontOfSize:12];
    l.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    l.textAlignment = NSTextAlignmentRight;
    [p addSubview:l];
}

- (UILabel *)valueLabel:(NSString *)text color:(UIColor *)c parent:(UIView *)p y:(CGFloat)y {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, y, p.frame.size.width - 32, 22)];
    l.text = text;
    l.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    l.textColor = c;
    l.textAlignment = NSTextAlignmentRight;
    [p addSubview:l];
    return l;
}

- (void)refreshDashboard {
    @try {
        UIWindow *window = NBActiveWindow();
        UIView *overlay = [window viewWithTag:99999];
        if (!overlay) return;

        UILabel *status = (UILabel *)[overlay viewWithTag:10001];
        UILabel *stats = (UILabel *)[overlay viewWithTag:10002];
        UITextView *logView = (UITextView *)[overlay viewWithTag:10003];

        NSString *log = [self readLog];

        // Status
        BOOL blocked = [log containsString:@"BLOCKED"] || [log containsString:@"BAN"];
        BOOL success = [log containsString:@"200"] || [log containsString:@"SPOOF"];
        if (blocked) {
            status.text = @"محظور - خادمي";
            status.textColor = [UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:1.0];
        } else if (success) {
            status.text = @"يعمل - تم التجاوز";
            status.textColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.3 alpha:1.0];
        } else {
            status.text = @"في الانتظار...";
            status.textColor = [UIColor grayColor];
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
        stats.text = [NSString stringWithFormat:
            @"الطلبات: %d | الحظر: %d | التعديل: %d | JB: %d | الاسطر: %lu",
            req, blk, spf, jb, (unsigned long)lines.count];

        // Logs
        NSArray *last = lines.count > 15 ? [lines subarrayWithRange:NSMakeRange(lines.count - 15, 15)] : lines;
        logView.text = [last componentsJoinedByString:@"\n"];
        if (logView.text.length > 0) {
            [logView scrollRangeToVisible:NSMakeRange(logView.text.length - 1, 1)];
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

- (void)copyLogs {
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

- (void)clearLogs {
    @try {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"تأكيد" message:@"مسح السجل؟" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"الغاء" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"مسح" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *act) {
            [[NSFileManager defaultManager] removeItemAtPath:LOG_FILE error:nil];
            [self refreshDashboard];
        }]];
        [self presentViewController:a animated:YES completion:nil];
    }
    @catch (NSException *e) {
        NSLog(@"[NaverBypass] Clear error: %@", e.reason);
    }
}

@end
