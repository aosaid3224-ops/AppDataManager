//
//  InstallationProgressViewController.m
//  IPAInstallerPro
//
//  v2.1.22 — Event-Driven Live Installation UI
//  Observes OperationLog notifications for real-time phase updates.
//  No timers. No fake progress. No auto-launch.
//

#import "InstallationProgressViewController.h"
#import "InstallationEngine.h"
#import "JailbreakEnvironment.h"
#import "OperationLog.h"
#import <objc/runtime.h>

#pragma mark - Phase Visual State

typedef NS_ENUM(NSInteger, PhaseVisualState) {
    PhaseVisualStatePending = 0,
    PhaseVisualStateActive  = 1,
    PhaseVisualStateSuccess = 2,
    PhaseVisualStateFailed  = 3
};

#pragma mark - InstallPhaseView

@interface InstallPhaseView : UIView
@property (nonatomic, strong) UILabel *iconLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView  *pulsingDot;
@property (nonatomic, assign) PhaseVisualState phaseState;
- (void)setState:(PhaseVisualState)state animated:(BOOL)animated;
@end

@implementation InstallPhaseView

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;

        _iconLabel = [[UILabel alloc] init];
        _iconLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _iconLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
        _iconLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_iconLabel];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.text = title;
        [self addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _subtitleLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        _subtitleLabel.text = subtitle;
        [self addSubview:_subtitleLabel];

        _pulsingDot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 6, 6)];
        _pulsingDot.translatesAutoresizingMaskIntoConstraints = NO;
        _pulsingDot.layer.cornerRadius = 3;
        _pulsingDot.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
        _pulsingDot.hidden = YES;
        [self addSubview:_pulsingDot];

        [NSLayoutConstraint activateConstraints:@[
            [_iconLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [_iconLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_iconLabel.widthAnchor constraintEqualToConstant:28],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconLabel.trailingAnchor constant:12],
            [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:10],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-16],

            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
            [_subtitleLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-10],
            [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-16],

            [_pulsingDot.leadingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor constant:8],
            [_pulsingDot.centerYAnchor constraintEqualToAnchor:_titleLabel.centerYAnchor],
            [_pulsingDot.widthAnchor constraintEqualToConstant:6],
            [_pulsingDot.heightAnchor constraintEqualToConstant:6],

            [self.heightAnchor constraintGreaterThanOrEqualToConstant:48]
        ]];

        self.phaseState = PhaseVisualStatePending;
        [self updateAppearanceAnimated:NO];
    }
    return self;
}

- (void)setState:(PhaseVisualState)state animated:(BOOL)animated {
    if (_phaseState == state) return;
    _phaseState = state;
    [self updateAppearanceAnimated:animated];
}

- (void)updateAppearanceAnimated:(BOOL)animated {
    void (^updates)(void) = ^{
        switch (self.phaseState) {
            case PhaseVisualStatePending:
                self.iconLabel.text = @"○";
                self.iconLabel.textColor = [UIColor colorWithWhite:0.4 alpha:1.0];
                self.titleLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
                self.subtitleLabel.textColor = [UIColor colorWithWhite:0.35 alpha:1.0];
                self.pulsingDot.hidden = YES;
                break;
            case PhaseVisualStateActive:
                self.iconLabel.text = @"◉";
                self.iconLabel.textColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
                self.titleLabel.textColor = [UIColor whiteColor];
                self.subtitleLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
                self.pulsingDot.hidden = NO;
                break;
            case PhaseVisualStateSuccess:
                self.iconLabel.text = @"✓";
                self.iconLabel.textColor = [UIColor colorWithRed:0.3 green:0.85 blue:0.4 alpha:1.0];
                self.titleLabel.textColor = [UIColor whiteColor];
                self.subtitleLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
                self.pulsingDot.hidden = YES;
                break;
            case PhaseVisualStateFailed:
                self.iconLabel.text = @"✗";
                self.iconLabel.textColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.3 alpha:1.0];
                self.titleLabel.textColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.3 alpha:1.0];
                self.subtitleLabel.textColor = [UIColor colorWithRed:0.7 green:0.3 blue:0.3 alpha:1.0];
                self.pulsingDot.hidden = YES;
                break;
        }
    };

    if (animated) {
        [UIView animateWithDuration:0.35 animations:updates];
    } else {
        updates();
    }

    if (self.phaseState == PhaseVisualStateActive) {
        [self startPulsing];
    } else {
        [self stopPulsing];
    }
}

- (void)startPulsing {
    self.pulsingDot.alpha = 1.0;
    [UIView animateWithDuration:0.8
                          delay:0
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         self.pulsingDot.alpha = 0.2;
                     }
                     completion:nil];
}

- (void)stopPulsing {
    [self.pulsingDot.layer removeAllAnimations];
    self.pulsingDot.alpha = 1.0;
}

@end

#pragma mark - ViewController

@interface InstallationProgressViewController ()
@property (nonatomic, strong) NSString *installedBundleID;
@property (nonatomic, strong) NSString *currentTxnID;
@property (nonatomic, assign) BOOL isDone;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UILabel *headerLabel;
@property (nonatomic, strong) UILabel *appNameLabel;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UIStackView *phasesStack;
@property (nonatomic, strong) NSMutableArray<InstallPhaseView *> *phaseViews;
@property (nonatomic, strong) UIView *reportCard;
@property (nonatomic, strong) NSDate *installStartTime;
@property (nonatomic, assign) NSInteger currentPhaseIndex;
@property (nonatomic, assign) BOOL hasFailed;
@end

@implementation InstallationProgressViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:1.0];
    self.title = @"تثبيت التطبيق";
    [self setupUI];
    [self registerForOperationLogNotifications];
    [self startInstallation];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - OperationLog Notifications (Event-Driven)

- (void)registerForOperationLogNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(operationRecordAdded:)
                                                 name:@"OperationRecordAdded"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(operationRecordUpdated:)
                                                 name:@"OperationRecordUpdated"
                                               object:nil];
}

/*
 * Maps OperationPhase → UI Visual Phase (0-4)
 *
 * 0: التحقق من ملف IPA       → OperationPhaseIPAOpen
 * 1: استخراج التطبيق          → OperationPhaseIPAExtract, OperationPhaseAppIdentify
 * 2: تثبيت الملفات            → OperationPhaseFileCopy, Framework, Dylib, Sign, Permission
 * 3: تسجيل التطبيق            → OperationPhaseUICache
 * 4: التحقق النهائي           → OperationPhaseVerify, OperationPhaseComplete
 */
- (NSInteger)uiPhaseIndexForOperationPhase:(OperationPhase)opPhase {
    switch (opPhase) {
        case OperationPhaseIPAOpen:
            return 0;
        case OperationPhaseIPAExtract:
        case OperationPhaseAppIdentify:
            return 1;
        case OperationPhaseFileCopy:
        case OperationPhaseFramework:
        case OperationPhaseDylib:
        case OperationPhaseSign:
        case OperationPhasePermission:
            return 2;
        case OperationPhaseUICache:
            return 3;
        case OperationPhaseVerify:
        case OperationPhaseComplete:
            return 4;
        default:
            return -1; // Unknown / don't map
    }
}

- (void)operationRecordAdded:(NSNotification *)note {
    if (self.isDone) return;
    OperationRecord *record = note.object;
    if (!record || ![record.transactionID isEqualToString:self.currentTxnID]) return;

    NSInteger uiPhase = [self uiPhaseIndexForOperationPhase:record.phase];
    if (uiPhase < 0) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        // Mark all previous phases as success
        for (NSInteger i = 0; i < uiPhase; i++) {
            if (self.phaseViews[i].phaseState == PhaseVisualStatePending) {
                [self.phaseViews[i] setState:PhaseVisualStateSuccess animated:YES];
            }
        }
        // Activate current phase
        [self.phaseViews[uiPhase] setState:PhaseVisualStateActive animated:YES];
        self.currentPhaseIndex = uiPhase;

        // Update progress
        float progress = (float)(uiPhase + 1) / (float)self.phaseViews.count;
        [self.progressView setProgress:progress animated:YES];
    });
}

- (void)operationRecordUpdated:(NSNotification *)note {
    if (self.isDone) return;
    OperationRecord *record = note.object;
    if (!record || ![record.transactionID isEqualToString:self.currentTxnID]) return;

    NSInteger uiPhase = [self uiPhaseIndexForOperationPhase:record.phase];
    if (uiPhase < 0) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (record.result == OperationResultSuccess) {
            [self.phaseViews[uiPhase] setState:PhaseVisualStateSuccess animated:YES];
        } else if (record.result == OperationResultFailed) {
            [self.phaseViews[uiPhase] setState:PhaseVisualStateFailed animated:YES];
            self.hasFailed = YES;
        }
    });
}

#pragma mark - UI Setup

- (void)setupUI {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_scrollView];

    _containerView = [[UIView alloc] init];
    _containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:_containerView];

    _headerLabel = [[UILabel alloc] init];
    _headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _headerLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    _headerLabel.textColor = [UIColor whiteColor];
    _headerLabel.textAlignment = NSTextAlignmentCenter;
    _headerLabel.text = @"جارٍ التثبيت...";
    [_containerView addSubview:_headerLabel];

    _appNameLabel = [[UILabel alloc] init];
    _appNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _appNameLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    _appNameLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    _appNameLabel.textAlignment = NSTextAlignmentCenter;
    _appNameLabel.text = [self.ipaPath lastPathComponent] ?: @"";
    [_containerView addSubview:_appNameLabel];

    _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _progressView.translatesAutoresizingMaskIntoConstraints = NO;
    _progressView.progressTintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
    _progressView.trackTintColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    _progressView.layer.cornerRadius = 2;
    _progressView.clipsToBounds = YES;
    [_containerView addSubview:_progressView];

    _phasesStack = [[UIStackView alloc] init];
    _phasesStack.translatesAutoresizingMaskIntoConstraints = NO;
    _phasesStack.axis = UILayoutConstraintAxisVertical;
    _phasesStack.spacing = 2;
    [_containerView addSubview:_phasesStack];

    _phaseViews = [NSMutableArray array];
    NSArray *phases = @[
        @[@"التحقق من ملف IPA",       @"جارٍ التحقق من سلامة الملف..."],
        @[@"استخراج التطبيق",        @"جارٍ فك ضغط المحتويات..."],
        @[@"تثبيت الملفات",          @"جارٍ النسخ والتوقيع..."],
        @[@"تسجيل التطبيق",          @"جارٍ التسجيل في النظام..."],
        @[@"التحقق النهائي",         @"جارٍ التأكد من اكتمال التثبيت..."]
    ];
    for (NSArray *p in phases) {
        InstallPhaseView *pv = [[InstallPhaseView alloc] initWithTitle:p[0] subtitle:p[1]];
        [_phasesStack addArrangedSubview:pv];
        [_phaseViews addObject:pv];
    }

    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_containerView.topAnchor constraintEqualToAnchor:_scrollView.topAnchor constant:20],
        [_containerView.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor constant:20],
        [_containerView.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor constant:-20],
        [_containerView.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor constant:-20],
        [_containerView.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor constant:-40],

        [_headerLabel.topAnchor constraintEqualToAnchor:_containerView.topAnchor],
        [_headerLabel.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor],
        [_headerLabel.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor],

        [_appNameLabel.topAnchor constraintEqualToAnchor:_headerLabel.bottomAnchor constant:6],
        [_appNameLabel.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor],
        [_appNameLabel.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor],

        [_progressView.topAnchor constraintEqualToAnchor:_appNameLabel.bottomAnchor constant:20],
        [_progressView.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor],
        [_progressView.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor],
        [_progressView.heightAnchor constraintEqualToConstant:4],

        [_phasesStack.topAnchor constraintEqualToAnchor:_progressView.bottomAnchor constant:24],
        [_phasesStack.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor],
        [_phasesStack.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor],
        [_phasesStack.bottomAnchor constraintLessThanOrEqualToAnchor:_containerView.bottomAnchor]
    ]];
}

#pragma mark - Phase Control

- (void)setPhase:(NSInteger)index state:(PhaseVisualState)state {
    if (index < 0 || index >= (NSInteger)self.phaseViews.count) return;
    [self.phaseViews[index] setState:state animated:YES];
    self.currentPhaseIndex = index;
}

#pragma mark - Installation

- (void)startInstallation {
    if (!self.ipaPath) {
        [self showFinalState:NO message:@"مسار IPA غير صالح"];
        return;
    }

    // ─── Full State Reset for sequential installs ───
    self.isDone = NO;
    self.hasFailed = NO;
    self.installedBundleID = nil;
    self.currentTxnID = nil;
    self.currentPhaseIndex = -1;
    self.installStartTime = [NSDate date];

    if (self.reportCard) {
        [self.reportCard removeFromSuperview];
        self.reportCard = nil;
    }

    self.headerLabel.text = @"جارٍ التثبيت...";
    self.headerLabel.textColor = [UIColor whiteColor];
    self.appNameLabel.text = [self.ipaPath lastPathComponent] ?: @"";
    [self.progressView setProgress:0.0 animated:NO];

    for (InstallPhaseView *pv in self.phaseViews) {
        [pv setState:PhaseVisualStatePending animated:NO];
    }

    InstallationEngine *engine = [InstallationEngine sharedEngine];
    if (engine.activeTransactionID && engine.activeTransactionID.length > 0) {
        [self showFinalState:NO message:@"تثبيت آخر قيد التقدم"];
        return;
    }

    self.currentTxnID = [[NSUUID UUID] UUIDString];
    [engine prepareTransactionWithID:self.currentTxnID];

    __weak typeof(self) weakSelf = self;
    [engine installIPA:self.ipaPath
         progressBlock:^(InstallationStage stage, NSString *statusMessage, float progress) {
        // Engine progress is coarse; OperationLog notifications drive the UI phases.
        // We use this only for final completion/failure signals.
    } completion:^(InstallationResult *result) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.isDone = YES;
        if (result && result.success) {
            strongSelf.installedBundleID = result.bundleID;
            [strongSelf handleCompletionSuccess:result];
        } else {
            [strongSelf handleCompletionFailure:result];
        }
    }];
}

- (void)handleCompletionSuccess:(InstallationResult *)result {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Ensure all phases show success
        for (InstallPhaseView *pv in self.phaseViews) {
            if (pv.phaseState == PhaseVisualStateActive || pv.phaseState == PhaseVisualStatePending) {
                [pv setState:PhaseVisualStateSuccess animated:YES];
            }
        }
        [self.progressView setProgress:1.0 animated:YES];
        self.headerLabel.text = @"اكتمل التثبيت ✓";
        [self showReportCard:result success:YES];
    });
}

- (void)handleCompletionFailure:(InstallationResult *)result {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger failIdx = self.currentPhaseIndex >= 0 ? self.currentPhaseIndex : 0;
        if (failIdx < (NSInteger)self.phaseViews.count) {
            [self.phaseViews[failIdx] setState:PhaseVisualStateFailed animated:YES];
        }
        self.headerLabel.text = @"فشل التثبيت ✗";
        self.headerLabel.textColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.3 alpha:1.0];
        [self showReportCard:result success:NO];
    });
}

#pragma mark - Report Card

- (void)showReportCard:(InstallationResult *)result success:(BOOL)success {
    if (self.reportCard) [self.reportCard removeFromSuperview];

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    card.layer.cornerRadius = 16;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1.0].CGColor;
    [self.containerView addSubview:card];
    self.reportCard = card;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    [card addSubview:stack];

    // Status header
    UILabel *statusLabel = [[UILabel alloc] init];
    statusLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.text = success ? @"✓ تم التثبيت بنجاح" : @"✗ فشل التثبيت";
    statusLabel.textColor = success
        ? [UIColor colorWithRed:0.3 green:0.85 blue:0.4 alpha:1.0]
        : [UIColor colorWithRed:0.9 green:0.3 blue:0.3 alpha:1.0];
    [stack addArrangedSubview:statusLabel];

    // Divider
    UIView *divider = [[UIView alloc] init];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    [divider.heightAnchor constraintEqualToConstant:1].active = YES;
    [stack addArrangedSubview:divider];

    NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:self.installStartTime];
    JailbreakEnvironment *env = [JailbreakEnvironment sharedEnvironment];
    NSString *appName = [[self.ipaPath lastPathComponent] stringByDeletingPathExtension] ?: @"-";

    // ─── App Section ───
    [self addSectionTitle:@"التطبيق" toStack:stack];
    [self addItem:[NSString stringWithFormat:@"الاسم: %@", appName] toStack:stack];
    [self addItem:[NSString stringWithFormat:@"Bundle ID: %@", result.bundleID ?: @"-"] toStack:stack];

    // ─── Installation Section ───
    [self addSectionTitle:@"التثبيت" toStack:stack];
    [self addItem:[NSString stringWithFormat:@"الحالة: %@", success ? @"نجاح" : @"فشل"] toStack:stack];
    [self addItem:[NSString stringWithFormat:@"المعاملة: %@...", self.currentTxnID ? [self.currentTxnID substringToIndex:MIN(8, self.currentTxnID.length)] : @"-"] toStack:stack];
    [self addItem:[NSString stringWithFormat:@"المدة: %.1f ثانية", duration] toStack:stack];

    // ─── Validation Section (on success) ───
    if (success) {
        [self addSectionTitle:@"التحقق" toStack:stack];
        [self addItem:@"IPA: ✓ صالح" toStack:stack];
        [self addItem:@"المحتوى: ✓ مكتمل" toStack:stack];
        [self addItem:@"التوقيع: ✓ موجود" toStack:stack];
        [self addItem:@"التسجيل: ✓ مكتمل" toStack:stack];
    }

    // ─── Environment Section ───
    [self addSectionTitle:@"البيئة" toStack:stack];
    [self addItem:[NSString stringWithFormat:@"الجيلبريك: %@", env.jailbreakType ?: @"غير معروف"] toStack:stack];
    [self addItem:[NSString stringWithFormat:@"Rootless: %@", env.isRootless ? @"نعم" : @"لا"] toStack:stack];
    [self addItem:[NSString stringWithFormat:@"المسار: %@", env.applicationsPath ?: @"-"] toStack:stack];

    // ─── Error (on failure) ───
    if (!success && result.message.length > 0) {
        [self addSectionTitle:@"تفاصيل الخطأ" toStack:stack];
        UILabel *errLabel = [[UILabel alloc] init];
        errLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        errLabel.textColor = [UIColor colorWithRed:0.8 green:0.4 blue:0.4 alpha:1.0];
        errLabel.text = result.message;
        errLabel.numberOfLines = 0;
        [stack addArrangedSubview:errLabel];
    }

    // ─── Buttons ───
    UIView *spacer = [[UIView alloc] init];
    [spacer.heightAnchor constraintEqualToConstant:8].active = YES;
    [stack addArrangedSubview:spacer];

    UIButton *doneBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    doneBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [doneBtn setTitle:@"تم" forState:UIControlStateNormal];
    doneBtn.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    doneBtn.backgroundColor = success
        ? [UIColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:1.0]
        : [UIColor colorWithRed:0.6 green:0.2 blue:0.2 alpha:1.0];
    [doneBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    doneBtn.layer.cornerRadius = 12;
    [doneBtn addTarget:self action:@selector(doneTapped:) forControlEvents:UIControlEventTouchUpInside];
    [doneBtn.heightAnchor constraintEqualToConstant:48].active = YES;
    [stack addArrangedSubview:doneBtn];

    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor constraintEqualToAnchor:self.phasesStack.bottomAnchor constant:24],
        [card.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor],
        [card.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor constant:-20],

        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:20],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-20],
    ]];

    // Animate in
    card.alpha = 0;
    card.transform = CGAffineTransformMakeTranslation(0, 30);
    [UIView animateWithDuration:0.5 delay:0.1 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:0 animations:^{
        card.alpha = 1;
        card.transform = CGAffineTransformIdentity;
    } completion:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CGRect cardFrame = [self.scrollView convertRect:card.frame fromView:self.containerView];
        [self.scrollView scrollRectToVisible:cardFrame animated:YES];
    });
}

- (void)addSectionTitle:(NSString *)title toStack:(UIStackView *)stack {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    label.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    label.text = title;
    [stack addArrangedSubview:label];
}

- (void)addItem:(NSString *)text toStack:(UIStackView *)stack {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    label.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    label.text = text;
    label.numberOfLines = 0;
    [stack addArrangedSubview:label];
}

- (void)showFinalState:(BOOL)success message:(NSString *)message {
    self.headerLabel.text = message;
    self.headerLabel.textColor = success
        ? [UIColor colorWithRed:0.3 green:0.85 blue:0.4 alpha:1.0]
        : [UIColor colorWithRed:0.9 green:0.3 blue:0.3 alpha:1.0];
}

#pragma mark - Actions

- (void)doneTapped:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
