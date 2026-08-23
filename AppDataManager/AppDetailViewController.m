#import "AppDetailViewController.h"
#import "AppDataManager.h"

// MARK: - Color Palette
#define C_BG [UIColor colorWithRed:0.025 green:0.027 blue:0.035 alpha:1.0]
#define C_CARD [UIColor colorWithRed:0.090 green:0.093 blue:0.108 alpha:1.0]
#define C_CARD_HOVER [UIColor colorWithRed:0.135 green:0.140 blue:0.158 alpha:1.0]
#define C_ACCENT [UIColor colorWithRed:0.43 green:0.56 blue:0.92 alpha:1.0]
#define C_DANGER [UIColor colorWithWhite:0.72 alpha:1.0]
#define C_TEXT_PRI [UIColor whiteColor]
#define C_TEXT_SEC [UIColor colorWithWhite:0.66 alpha:1.0]
#define C_TEXT_TER [UIColor colorWithWhite:0.58 alpha:1.0]

// Category colors
#define C_DOC [UIColor colorWithRed:0.43 green:0.56 blue:0.92 alpha:1.0]
#define C_LIB [UIColor colorWithRed:0.34 green:0.44 blue:0.72 alpha:1.0]
#define C_CACHE [UIColor colorWithRed:0.27 green:0.34 blue:0.55 alpha:1.0]

// MARK: - Smooth Storage Ring
@interface StorageRingView : UIView
@property (nonatomic, assign) CGFloat docRatio;
@property (nonatomic, assign) CGFloat libRatio;
@property (nonatomic, assign) CGFloat cacheRatio;
@property (nonatomic, strong) UILabel *centerLabel;
- (void)animateToRatios:(CGFloat)doc lib:(CGFloat)lib cache:(CGFloat)cache;
@end

@implementation StorageRingView {
    CGFloat _targetDoc, _targetLib, _targetCache;
    CGFloat _currentDoc, _currentLib, _currentCache;
    CADisplayLink *_displayLink;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];

        _centerLabel = [[UILabel alloc] init];
        _centerLabel.textAlignment = NSTextAlignmentCenter;
        _centerLabel.numberOfLines = 2;
        _centerLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_centerLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_centerLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_centerLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_centerLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
            [_centerLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8]
        ]];
    }
    return self;
}

- (void)animateToRatios:(CGFloat)doc lib:(CGFloat)lib cache:(CGFloat)cache {
    _targetDoc = doc; _targetLib = lib; _targetCache = cache;
    _currentDoc = 0; _currentLib = 0; _currentCache = 0;

    if (_displayLink) [_displayLink invalidate];
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateAnimation)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)updateAnimation {
    CGFloat speed = 0.08;
    _currentDoc += (_targetDoc - _currentDoc) * speed;
    _currentLib += (_targetLib - _currentLib) * speed;
    _currentCache += (_targetCache - _currentCache) * speed;

    if (fabs(_targetDoc - _currentDoc) < 0.001 &&
        fabs(_targetLib - _currentLib) < 0.001 &&
        fabs(_targetCache - _currentCache) < 0.001) {
        _currentDoc = _targetDoc;
        _currentLib = _targetLib;
        _currentCache = _targetCache;
        [_displayLink invalidate];
        _displayLink = nil;
    }
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    CGFloat lw = 14.0;
    CGFloat inset = lw / 2.0 + 4;
    CGFloat r = (MIN(rect.size.width, rect.size.height) - lw) / 2.0 - inset;
    CGPoint c = CGPointMake(rect.size.width / 2.0, rect.size.height / 2.0);

    // Background track
    UIBezierPath *bg = [UIBezierPath bezierPathWithArcCenter:c radius:r startAngle:-M_PI_2 endAngle:3*M_PI_2 clockwise:YES];
    [[UIColor colorWithWhite:0.08 alpha:1.0] setStroke];
    bg.lineWidth = lw;
    bg.lineCapStyle = kCGLineCapRound;
    [bg stroke];

    // Segments
    NSArray *colors = @[C_DOC, C_LIB, C_CACHE];
    NSArray *ratios = @[@(_currentDoc), @(_currentLib), @(_currentCache)];
    CGFloat start = -M_PI_2;
    CGFloat total = _currentDoc + _currentLib + _currentCache;

    for (NSUInteger i = 0; i < 3; i++) {
        CGFloat ratio = [ratios[i] floatValue];
        if (ratio <= 0.005) continue;
        CGFloat end = start + (2 * M_PI * ratio);
        UIBezierPath *p = [UIBezierPath bezierPathWithArcCenter:c radius:r startAngle:start endAngle:end clockwise:YES];
        [colors[i] setStroke];
        p.lineWidth = lw;
        p.lineCapStyle = kCGLineCapRound;
        [p stroke];
        start = end;
    }

    // Center text
    CGFloat pct = total > 0 ? (_currentDoc + _currentLib + _currentCache) * 100 : 0;
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] init];
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%.0f%%", pct] attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:22 weight:UIFontWeightBold],
        NSForegroundColorAttributeName: C_TEXT_PRI
    }]];
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nمستخدم" attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:9 weight:UIFontWeightMedium],
        NSForegroundColorAttributeName: C_TEXT_TER
    }]];
    _centerLabel.attributedText = attr;
}

@end

// MARK: - Stat Row with Progress
@interface StatRow : UIView
@property (nonatomic, strong) UIView *dot;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *sizeLabel;
@property (nonatomic, strong) UILabel *pctLabel;
@property (nonatomic, strong) UIProgressView *progressView;
- (instancetype)initWithColor:(UIColor *)color title:(NSString *)title;
- (void)setSize:(NSString *)size pct:(NSString *)pct progress:(CGFloat)progress;
@end

@implementation StatRow

- (instancetype)initWithColor:(UIColor *)color title:(NSString *)title {
    self = [super init];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;

        _dot = [[UIView alloc] init];
        _dot.backgroundColor = color;
        _dot.layer.cornerRadius = 4;
        _dot.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_dot];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.text = title;
        _nameLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        _nameLabel.textColor = C_TEXT_SEC;
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_nameLabel];

        _sizeLabel = [[UILabel alloc] init];
        _sizeLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        _sizeLabel.textColor = C_TEXT_PRI;
        _sizeLabel.textAlignment = NSTextAlignmentRight;
        _sizeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_sizeLabel];

        _pctLabel = [[UILabel alloc] init];
        _pctLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        _pctLabel.textColor = C_TEXT_TER;
        _pctLabel.textAlignment = NSTextAlignmentRight;
        _pctLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_pctLabel];

        _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _progressView.progressTintColor = color;
        _progressView.trackTintColor = [UIColor colorWithWhite:0.08 alpha:1.0];
        _progressView.layer.cornerRadius = 2;
        _progressView.clipsToBounds = YES;
        _progressView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_progressView];

        [NSLayoutConstraint activateConstraints:@[
            [_dot.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_dot.centerYAnchor constraintEqualToAnchor:_nameLabel.centerYAnchor],
            [_dot.widthAnchor constraintEqualToConstant:8],
            [_dot.heightAnchor constraintEqualToConstant:8],

            [_nameLabel.leadingAnchor constraintEqualToAnchor:_dot.trailingAnchor constant:10],
            [_nameLabel.topAnchor constraintEqualToAnchor:self.topAnchor],

            [_pctLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_pctLabel.centerYAnchor constraintEqualToAnchor:_nameLabel.centerYAnchor],
            [_pctLabel.widthAnchor constraintEqualToConstant:40],

            [_sizeLabel.trailingAnchor constraintEqualToAnchor:_pctLabel.leadingAnchor constant:-8],
            [_sizeLabel.centerYAnchor constraintEqualToAnchor:_nameLabel.centerYAnchor],
            [_sizeLabel.widthAnchor constraintEqualToConstant:70],

            [_progressView.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:6],
            [_progressView.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_progressView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_progressView.heightAnchor constraintEqualToConstant:4],
            [_progressView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4]
        ]];
    }
    return self;
}

- (void)setSize:(NSString *)size pct:(NSString *)pct progress:(CGFloat)progress {
    _sizeLabel.text = size;
    _pctLabel.text = pct;
    _progressView.progress = progress;
}

@end

// MARK: - Info Row
@interface InfoRow : UIView
- (instancetype)initWithIcon:(NSString *)icon title:(NSString *)title value:(NSString *)value;
@end

@implementation InfoRow

- (instancetype)initWithIcon:(NSString *)icon title:(NSString *)title value:(NSString *)value {
    self = [super init];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = [UIColor clearColor];

        UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:icon]];
        iv.tintColor = C_TEXT_TER;
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:iv];

        UILabel *tl = [[UILabel alloc] init];
        tl.text = title;
        tl.font = [UIFont systemFontOfSize:12];
        tl.textColor = C_TEXT_SEC;
        tl.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:tl];

        UILabel *vl = [[UILabel alloc] init];
        vl.text = value;
        vl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        vl.textColor = C_TEXT_PRI;
        vl.textAlignment = NSTextAlignmentRight;
        vl.numberOfLines = 1;
        vl.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:vl];

        [NSLayoutConstraint activateConstraints:@[
            [iv.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [iv.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [iv.widthAnchor constraintEqualToConstant:16],
            [iv.heightAnchor constraintEqualToConstant:16],
            [tl.leadingAnchor constraintEqualToAnchor:iv.trailingAnchor constant:10],
            [tl.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [vl.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [vl.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [vl.leadingAnchor constraintGreaterThanOrEqualToAnchor:tl.trailingAnchor constant:12],
            [self.heightAnchor constraintEqualToConstant:30]
        ]];
    }
    return self;
}

@end

// MARK: - AppDetailViewController
@interface AppDetailViewController ()
@property (nonatomic, strong) NSDictionary *appInfo;
@property (nonatomic, strong) AppDataManager *manager;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

// Header
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *metaLabel;

// Data Card
@property (nonatomic, strong) UIView *dataCard;
@property (nonatomic, strong) UILabel *dataTitleLabel;
@property (nonatomic, strong) UILabel *dataSizeLabel;
@property (nonatomic, strong) StorageRingView *ringView;
@property (nonatomic, strong) StatRow *docsRow;
@property (nonatomic, strong) StatRow *libRow;
@property (nonatomic, strong) StatRow *cacheRow;

// Backup Card
@property (nonatomic, strong) UIView *backupCard;
@property (nonatomic, strong) UILabel *backupTitle;
@property (nonatomic, strong) UILabel *backupStatus;
@property (nonatomic, strong) UIButton *backupBtn;
@property (nonatomic, strong) UIButton *restoreBtn;

// Actions Card
@property (nonatomic, strong) UIView *actionCard;
@property (nonatomic, strong) UIButton *wipeBtn;

// Technical Card
@property (nonatomic, strong) UIView *techCard;
@property (nonatomic, strong) UIButton *techToggle;
@property (nonatomic, strong) UIView *techContent;
@property (nonatomic, assign) BOOL techExpanded;
@property (nonatomic, strong) NSLayoutConstraint *techHeightConstraint;
@end

@implementation AppDetailViewController

- (instancetype)initWithAppInfo:(NSDictionary *)appInfo {
    self = [super init];
    if (self) { _appInfo = appInfo; _manager = [AppDataManager sharedManager]; }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"";
    self.view.backgroundColor = C_BG;
    [self setupNav];
    [self setupScroll];
    [self setupHeader];
    [self setupDataCard];
    [self setupBackupCard];
    [self setupActionCard];
    [self setupTechCard];
    [self loadData];
}

- (void)setupNav {
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.navigationController.navigationBar.tintColor = C_TEXT_PRI;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"xmark"]
        style:UIBarButtonItemStylePlain target:self action:@selector(close)];
}

- (void)close { [self.navigationController popViewControllerAnimated:YES]; }

- (void)setupScroll {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor]
    ]];
}

- (UIView *)makeCard {
    UIView *v = [[UIView alloc] init];
    v.backgroundColor = C_CARD;
    v.layer.cornerRadius = 16;
    v.layer.masksToBounds = YES;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    return v;
}

#pragma mark - Header

- (void)setupHeader {
    NSString *bid = self.appInfo[@"bundleID"];

    self.iconView = [[UIImageView alloc] init];
    self.iconView.layer.cornerRadius = 16;
    self.iconView.layer.masksToBounds = YES;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *icon = [self.manager iconForBundleID:bid];
    if (icon) self.iconView.image = icon;
    else {
        self.iconView.image = [UIImage systemImageNamed:@"app.fill"];
        self.iconView.tintColor = C_ACCENT;
        self.iconView.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1.0];
    }
    [self.contentView addSubview:self.iconView];

    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.text = self.appInfo[@"name"];
    self.nameLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    self.nameLabel.textColor = C_TEXT_PRI;
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.nameLabel];

    self.metaLabel = [[UILabel alloc] init];
    NSString *ver = [self.manager versionForBundleID:bid];
    self.metaLabel.text = [NSString stringWithFormat:@"الإصدار %@ · %@", ver, bid];
    self.metaLabel.font = [UIFont systemFontOfSize:12];
    self.metaLabel.textColor = C_TEXT_TER;
    self.metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.metaLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.iconView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:20],
        [self.iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.iconView.widthAnchor constraintEqualToConstant:64],
        [self.iconView.heightAnchor constraintEqualToConstant:64],
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.iconView.topAnchor constant:6],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.iconView.trailingAnchor constant:16],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.metaLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:5],
        [self.metaLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.metaLabel.trailingAnchor constraintEqualToAnchor:self.nameLabel.trailingAnchor]
    ]];
}

#pragma mark - Data Card (REDESIGNED)

- (void)setupDataCard {
    self.dataCard = [self makeCard];
    [self.contentView addSubview:self.dataCard];

    // Title
    self.dataTitleLabel = [[UILabel alloc] init];
    self.dataTitleLabel.text = @"بيانات التطبيق";
    self.dataTitleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    self.dataTitleLabel.textColor = C_TEXT_TER;
    self.dataTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dataCard addSubview:self.dataTitleLabel];

    // Ring
    self.ringView = [[StorageRingView alloc] initWithFrame:CGRectZero];
    self.ringView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dataCard addSubview:self.ringView];

    // Total size
    self.dataSizeLabel = [[UILabel alloc] init];
    self.dataSizeLabel.text = @"—";
    self.dataSizeLabel.textColor = C_TEXT_PRI;
    self.dataSizeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dataCard addSubview:self.dataSizeLabel];

    // Stat rows
    self.docsRow = [[StatRow alloc] initWithColor:C_DOC title:@"المستندات"];
    [self.dataCard addSubview:self.docsRow];

    self.libRow = [[StatRow alloc] initWithColor:C_LIB title:@"المكتبة"];
    [self.dataCard addSubview:self.libRow];

    self.cacheRow = [[StatRow alloc] initWithColor:C_CACHE title:@"التخزين المؤقت"];
    [self.dataCard addSubview:self.cacheRow];

    [NSLayoutConstraint activateConstraints:@[
        [self.dataCard.topAnchor constraintEqualToAnchor:self.metaLabel.bottomAnchor constant:24],
        [self.dataCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.dataCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [self.dataTitleLabel.topAnchor constraintEqualToAnchor:self.dataCard.topAnchor constant:18],
        [self.dataTitleLabel.leadingAnchor constraintEqualToAnchor:self.dataCard.leadingAnchor constant:20],

        [self.ringView.topAnchor constraintEqualToAnchor:self.dataTitleLabel.bottomAnchor constant:16],
        [self.ringView.leadingAnchor constraintEqualToAnchor:self.dataCard.leadingAnchor constant:20],
        [self.ringView.widthAnchor constraintEqualToConstant:110],
        [self.ringView.heightAnchor constraintEqualToConstant:110],

        [self.dataSizeLabel.topAnchor constraintEqualToAnchor:self.ringView.topAnchor constant:20],
        [self.dataSizeLabel.leadingAnchor constraintEqualToAnchor:self.ringView.trailingAnchor constant:16],
        [self.dataSizeLabel.trailingAnchor constraintEqualToAnchor:self.dataCard.trailingAnchor constant:-20],

        [self.docsRow.topAnchor constraintEqualToAnchor:self.ringView.bottomAnchor constant:20],
        [self.docsRow.leadingAnchor constraintEqualToAnchor:self.dataCard.leadingAnchor constant:20],
        [self.docsRow.trailingAnchor constraintEqualToAnchor:self.dataCard.trailingAnchor constant:-20],

        [self.libRow.topAnchor constraintEqualToAnchor:self.docsRow.bottomAnchor constant:10],
        [self.libRow.leadingAnchor constraintEqualToAnchor:self.docsRow.leadingAnchor],
        [self.libRow.trailingAnchor constraintEqualToAnchor:self.docsRow.trailingAnchor],

        [self.cacheRow.topAnchor constraintEqualToAnchor:self.libRow.bottomAnchor constant:10],
        [self.cacheRow.leadingAnchor constraintEqualToAnchor:self.docsRow.leadingAnchor],
        [self.cacheRow.trailingAnchor constraintEqualToAnchor:self.docsRow.trailingAnchor],
        [self.cacheRow.bottomAnchor constraintEqualToAnchor:self.dataCard.bottomAnchor constant:-18]
    ]];
}

#pragma mark - Backup Card

- (void)setupBackupCard {
    self.backupCard = [self makeCard];
    [self.contentView addSubview:self.backupCard];

    self.backupTitle = [[UILabel alloc] init];
    self.backupTitle.text = @"النسخ الاحتياطية";
    self.backupTitle.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    self.backupTitle.textColor = C_TEXT_TER;
    self.backupTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.backupCard addSubview:self.backupTitle];

    self.backupStatus = [[UILabel alloc] init];
    self.backupStatus.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.backupStatus.textColor = C_TEXT_PRI;
    self.backupStatus.translatesAutoresizingMaskIntoConstraints = NO;
    [self.backupCard addSubview:self.backupStatus];

    self.backupBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.backupBtn.translatesAutoresizingMaskIntoConstraints = NO;
    self.backupBtn.backgroundColor = [UIColor colorWithRed:0.769 green:0.655 blue:0.490 alpha:0.12];
    self.backupBtn.layer.cornerRadius = 10;
    self.backupBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [self.backupBtn setTitle:@"نسخ احتياطي" forState:UIControlStateNormal];
    self.restoreBtn.hidden = YES;
    self.restoreBtn.alpha = 0.0;
    [self.backupBtn setTitleColor:C_ACCENT forState:UIControlStateNormal];
    [self.backupBtn addTarget:self action:@selector(backupTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.backupCard addSubview:self.backupBtn];

    self.restoreBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.restoreBtn.translatesAutoresizingMaskIntoConstraints = NO;
    self.restoreBtn.backgroundColor = [UIColor colorWithRed:0.3 green:0.6 blue:0.9 alpha:0.12];
    self.restoreBtn.layer.cornerRadius = 10;
    self.restoreBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [self.restoreBtn setTitle:@"استعادة" forState:UIControlStateNormal];
    [self.restoreBtn setTitleColor:[UIColor colorWithRed:0.3 green:0.6 blue:0.9 alpha:1.0] forState:UIControlStateNormal];
    [self.restoreBtn addTarget:self action:@selector(restoreDetailTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.backupCard addSubview:self.restoreBtn];

    [NSLayoutConstraint activateConstraints:@[
        [self.backupCard.topAnchor constraintEqualToAnchor:self.dataCard.bottomAnchor constant:12],
        [self.backupCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.backupCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [self.backupTitle.topAnchor constraintEqualToAnchor:self.backupCard.topAnchor constant:18],
        [self.backupTitle.leadingAnchor constraintEqualToAnchor:self.backupCard.leadingAnchor constant:20],

        [self.backupStatus.topAnchor constraintEqualToAnchor:self.backupTitle.bottomAnchor constant:6],
        [self.backupStatus.leadingAnchor constraintEqualToAnchor:self.backupTitle.leadingAnchor],

        [self.backupBtn.topAnchor constraintEqualToAnchor:self.backupStatus.bottomAnchor constant:12],
        [self.backupBtn.leadingAnchor constraintEqualToAnchor:self.backupTitle.leadingAnchor],
        [self.backupBtn.widthAnchor constraintEqualToConstant:110],
        [self.backupBtn.heightAnchor constraintEqualToConstant:36],

        [self.restoreBtn.topAnchor constraintEqualToAnchor:self.backupBtn.topAnchor],
        [self.restoreBtn.leadingAnchor constraintEqualToAnchor:self.backupBtn.trailingAnchor constant:10],
        [self.restoreBtn.widthAnchor constraintEqualToConstant:110],
        [self.restoreBtn.heightAnchor constraintEqualToConstant:36],
        [self.restoreBtn.bottomAnchor constraintEqualToAnchor:self.backupCard.bottomAnchor constant:-16]
    ]];
}

#pragma mark - Action Card

- (void)setupActionCard {
    self.actionCard = [self makeCard];
    [self.contentView addSubview:self.actionCard];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"حذف البيانات";
    title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    title.textColor = C_TEXT_PRI;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [self.actionCard addSubview:title];

    UILabel *desc = [[UILabel alloc] init];
    desc.text = @"سيتم حذف جميع بيانات التطبيق بشكل دائم. أنصح بإنشاء نسخ احتياطي أولاً.";
    desc.font = [UIFont systemFontOfSize:12];
    desc.textColor = C_TEXT_SEC;
    desc.numberOfLines = 2;
    desc.translatesAutoresizingMaskIntoConstraints = NO;
    [self.actionCard addSubview:desc];

    self.wipeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.wipeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    self.wipeBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:0.12];
    self.wipeBtn.layer.cornerRadius = 10;
    self.wipeBtn.layer.borderColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:0.30].CGColor;
    self.wipeBtn.layer.borderWidth = 1;
    self.wipeBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [self.wipeBtn setTitle:@"حذف" forState:UIControlStateNormal];
    [self.wipeBtn setTitleColor:C_DANGER forState:UIControlStateNormal];
    [self.wipeBtn addTarget:self action:@selector(wipeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.actionCard addSubview:self.wipeBtn];

    [NSLayoutConstraint activateConstraints:@[
        [self.actionCard.topAnchor constraintEqualToAnchor:self.backupCard.bottomAnchor constant:12],
        [self.actionCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.actionCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [title.topAnchor constraintEqualToAnchor:self.actionCard.topAnchor constant:18],
        [title.leadingAnchor constraintEqualToAnchor:self.actionCard.leadingAnchor constant:20],

        [desc.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:5],
        [desc.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [desc.trailingAnchor constraintEqualToAnchor:self.actionCard.trailingAnchor constant:-20],

        [self.wipeBtn.topAnchor constraintEqualToAnchor:desc.bottomAnchor constant:12],
        [self.wipeBtn.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.wipeBtn.widthAnchor constraintEqualToConstant:110],
        [self.wipeBtn.heightAnchor constraintEqualToConstant:36],
        [self.wipeBtn.bottomAnchor constraintEqualToAnchor:self.actionCard.bottomAnchor constant:-16]
    ]];
}

#pragma mark - Technical Card

- (void)setupTechCard {
    self.techCard = [self makeCard];
    [self.contentView addSubview:self.techCard];

    self.techToggle = [UIButton buttonWithType:UIButtonTypeCustom];
    self.techToggle.translatesAutoresizingMaskIntoConstraints = NO;
    self.techToggle.backgroundColor = [UIColor clearColor];
    [self.techToggle addTarget:self action:@selector(toggleTech) forControlEvents:UIControlEventTouchUpInside];
    [self.techCard addSubview:self.techToggle];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"معلومات التطبيق";
    title.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    title.textColor = C_TEXT_SEC;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [self.techToggle addSubview:title];

    UIImageView *chev = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
    chev.tintColor = C_TEXT_TER;
    chev.translatesAutoresizingMaskIntoConstraints = NO;
    chev.tag = 100;
    [self.techToggle addSubview:chev];

    self.techContent = [[UIView alloc] init];
    self.techContent.translatesAutoresizingMaskIntoConstraints = NO;
    self.techContent.clipsToBounds = YES;
    [self.techCard addSubview:self.techContent];

    NSString *bid = self.appInfo[@"bundleID"];
    NSString *dp = [self.manager dataPathForBundleID:bid];
    NSString *ver = [self.manager versionForBundleID:bid];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.techContent addSubview:stack];

    [stack addArrangedSubview:[[InfoRow alloc] initWithIcon:@"number" title:@"معرف الحزمة" value:bid]];
    [stack addArrangedSubview:[[InfoRow alloc] initWithIcon:@"tag" title:@"الإصدار" value:ver]];
    [stack addArrangedSubview:[[InfoRow alloc] initWithIcon:@"folder" title:@"مسار البيانات" value:dp ?: @"—"]];
    [stack addArrangedSubview:[[InfoRow alloc] initWithIcon:@"doc" title:@"المستندات" value:[NSString stringWithFormat:@"%lu ملف", (unsigned long)[self.manager documentsCountForBundleID:bid]]]];

    self.techExpanded = NO;
    self.techHeightConstraint = [self.techContent.heightAnchor constraintEqualToConstant:0];
    self.techHeightConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [self.techCard.topAnchor constraintEqualToAnchor:self.actionCard.bottomAnchor constant:12],
        [self.techCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.techCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.techCard.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-28],

        [self.techToggle.topAnchor constraintEqualToAnchor:self.techCard.topAnchor],
        [self.techToggle.leadingAnchor constraintEqualToAnchor:self.techCard.leadingAnchor],
        [self.techToggle.trailingAnchor constraintEqualToAnchor:self.techCard.trailingAnchor],
        [self.techToggle.heightAnchor constraintEqualToConstant:48],

        [title.leadingAnchor constraintEqualToAnchor:self.techToggle.leadingAnchor constant:20],
        [title.centerYAnchor constraintEqualToAnchor:self.techToggle.centerYAnchor],

        [chev.trailingAnchor constraintEqualToAnchor:self.techToggle.trailingAnchor constant:-20],
        [chev.centerYAnchor constraintEqualToAnchor:self.techToggle.centerYAnchor],
        [chev.widthAnchor constraintEqualToConstant:14],
        [chev.heightAnchor constraintEqualToConstant:14],

        [self.techContent.topAnchor constraintEqualToAnchor:self.techToggle.bottomAnchor],
        [self.techContent.leadingAnchor constraintEqualToAnchor:self.techCard.leadingAnchor constant:20],
        [self.techContent.trailingAnchor constraintEqualToAnchor:self.techCard.trailingAnchor constant:-20],
        [self.techContent.bottomAnchor constraintEqualToAnchor:self.techCard.bottomAnchor constant:-10],

        [stack.topAnchor constraintEqualToAnchor:self.techContent.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.techContent.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:self.techContent.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:self.techContent.bottomAnchor]
    ]];
}

- (void)toggleTech {
    self.techExpanded = !self.techExpanded;
    UIImageView *chev = [self.techToggle viewWithTag:100];
    [UIView animateWithDuration:0.3 animations:^{ chev.transform = self.techExpanded ? CGAffineTransformMakeRotation(M_PI) : CGAffineTransformIdentity; }];

    self.techHeightConstraint.active = NO;
    self.techHeightConstraint = self.techExpanded ? [self.techContent.heightAnchor constraintGreaterThanOrEqualToConstant:120] : [self.techContent.heightAnchor constraintEqualToConstant:0];
    self.techHeightConstraint.active = YES;

    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:0 animations:^{ [self.view layoutIfNeeded]; } completion:nil];
}

#pragma mark - Data Loading (REAL STATS)

- (void)loadData {
    NSString *bid = self.appInfo[@"bundleID"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // حساب الأحجام الحقيقية
        NSString *dp = [self.manager dataPathForBundleID:bid];
        unsigned long long docs = 0, lib = 0, cache = 0;

        if (dp) {
            docs = [self dirSize:[dp stringByAppendingPathComponent:@"Documents"]];
            lib = [self dirSize:[dp stringByAppendingPathComponent:@"Library"]];
            cache = [self dirSize:[[dp stringByAppendingPathComponent:@"Library"] stringByAppendingPathComponent:@"Caches"]];
        }

        unsigned long long total = docs + lib + cache;
        NSString *totalStr = [self.manager formatBytes:total];

        CGFloat dr = total > 0 ? (CGFloat)docs / (CGFloat)total : 0;
        CGFloat lr = total > 0 ? (CGFloat)lib / (CGFloat)total : 0;
        CGFloat cr = total > 0 ? (CGFloat)cache / (CGFloat)total : 0;

        NSDate *lb = [self.manager lastBackupDateForBundleID:bid];

        dispatch_async(dispatch_get_main_queue(), ^{
            // Total size
            NSMutableAttributedString *sizeAttr = [[NSMutableAttributedString alloc] init];
            NSArray *parts = [totalStr componentsSeparatedByString:@" "];
            NSString *num = parts.count > 0 ? parts[0] : totalStr;
            NSString *unit = parts.count > 1 ? parts[1] : @"";

            [sizeAttr appendAttributedString:[[NSAttributedString alloc] initWithString:num attributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:28 weight:UIFontWeightBold],
                NSForegroundColorAttributeName: C_TEXT_PRI
            }]];
            if (unit.length > 0) {
                [sizeAttr appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@", unit] attributes:@{
                    NSFontAttributeName: [UIFont systemFontOfSize:14 weight:UIFontWeightMedium],
                    NSForegroundColorAttributeName: C_TEXT_SEC
                }]];
            }
            self.dataSizeLabel.attributedText = sizeAttr;

            // Animate ring
            [self.ringView animateToRatios:dr lib:lr cache:cr];

            // Update stat rows
            [self.docsRow setSize:[self.manager formatBytes:docs]
                              pct:[NSString stringWithFormat:@"%.0f%%", dr * 100]
                         progress:dr];
            [self.libRow setSize:[self.manager formatBytes:lib]
                             pct:[NSString stringWithFormat:@"%.0f%%", lr * 100]
                        progress:lr];
            [self.cacheRow setSize:[self.manager formatBytes:cache]
                               pct:[NSString stringWithFormat:@"%.0f%%", cr * 100]
                          progress:cr];

            [self updateBackup:lb];
        });
    });
}

- (void)updateBackup:(NSDate *)lastBackup {
    if (lastBackup) {
        NSDateFormatter *f = [[NSDateFormatter alloc] init];
        f.dateStyle = NSDateFormatterShortStyle;
        f.timeStyle = NSDateFormatterShortStyle;
        self.backupStatus.text = [NSString stringWithFormat:@"آخر نسخ احتياطي: %@", [f stringFromDate:lastBackup]];
        self.backupStatus.textColor = [UIColor colorWithRed:0.35 green:0.75 blue:0.55 alpha:1.0];
        self.restoreBtn.hidden = NO;
        self.restoreBtn.alpha = 1.0;
    } else {
        self.backupStatus.text = @"لا توجد نسخ احتياطية";
        self.backupStatus.textColor = C_TEXT_SEC;
        self.restoreBtn.hidden = YES;
        self.restoreBtn.alpha = 0.0;
    }
}

- (unsigned long long)dirSize:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) return 0;
    unsigned long long t = 0;
    for (NSString *item in [fm subpathsAtPath:path]) {
        @try {
            NSDictionary *a = [fm attributesOfItemAtPath:[path stringByAppendingPathComponent:item] error:nil];
            if (a) t += [a fileSize];
        } @catch (NSException *e) { continue; }
    }
    return t;
}

#pragma mark - Actions

- (void)backupTapped {
    NSString *bid = self.appInfo[@"bundleID"];

    UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"نسخ %@", self.appInfo[@"name"]]
                                                               message:@"سيتم إنشاء نسخ احتياطي كامل من بيانات التطبيق."
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"نسخ احتياطي" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [self showSpinner:@"جاري النسخ..."];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            BOOL ok = [self.manager backupAppData:bid];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideSpinner];
                [self toast:ok ? @"تم إنشاء النسخ الاحتياطي ✅" : @"فشل إنشاء النسخ الاحتياطي ❌"];
                [self loadData];
            });
        });
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)restoreDetailTapped {
    NSString *bid = self.appInfo[@"bundleID"];
    NSArray *backups = [self.manager availableBackupsForBundleID:bid];

    if (backups.count == 0) {
        [self toast:@"لا توجد نسخ احتياطية ❌"];
        return;
    }

    NSString *latestBackupPath = backups[0][@"path"];
    NSString *backupDateStr = [self formatDate:backups[0][@"date"]];

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"استعادة النسخ الاحتياطي"
                                                               message:[NSString stringWithFormat:@"سيتم استبدال بيانات التطبيق الحالية بالنسخ الاحتياطي (%@).", backupDateStr]
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"استعادة" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [self showSpinner:@"جاري الاستعادة..."];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            BOOL ok = [self.manager restoreAppData:bid fromBackup:latestBackupPath];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideSpinner];
                [self toast:ok ? @"تمت الاستعادة ✅" : @"فشلت الاستعادة ❌"];
                if (ok) [self loadData];
            });
        });
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (NSString *)formatDate:(NSDate *)date {
    if (!date) return @"Unknown";
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    [f setDateFormat:@"yyyy-MM-dd HH:mm"];
    return [f stringFromDate:date];
}

- (void)showSpinner:(NSString *)message {
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.tag = 999;
    spinner.center = self.view.center;
    spinner.color = C_ACCENT;
    [self.view addSubview:spinner];
    [spinner startAnimating];

    UILabel *label = [[UILabel alloc] init];
    label.tag = 998;
    label.text = message;
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    label.textColor = C_TEXT_PRI;
    label.textAlignment = NSTextAlignmentCenter;
    label.frame = CGRectMake(0, 0, 200, 30);
    label.center = CGPointMake(self.view.center.x, self.view.center.y + 40);
    [self.view addSubview:label];
}

- (void)hideSpinner {
    UIActivityIndicatorView *spinner = [self.view viewWithTag:999];
    [spinner stopAnimating];
    [spinner removeFromSuperview];
    UILabel *label = [self.view viewWithTag:998];
    [label removeFromSuperview];
}

- (void)wipeTapped {
    NSString *bid = self.appInfo[@"bundleID"];
    NSString *name = self.appInfo[@"name"];

    if ([self.manager isSystemApp:bid]) {
        [self toast:@"لا يمكن حذف بيانات تطبيق النظام ⛔"];
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *dp = [self.manager dataPathForBundleID:bid];
        unsigned long long d = [self dirSize:[dp stringByAppendingPathComponent:@"Documents"]];
        unsigned long long l = [self dirSize:[dp stringByAppendingPathComponent:@"Library"]];
        unsigned long long c = [self dirSize:[[dp stringByAppendingPathComponent:@"Library"] stringByAppendingPathComponent:@"Caches"]];
        unsigned long long t = d + l + c;

        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *msg = [NSString stringWithFormat:@"سيتم حذف بيانات %@ بشكل دائم:\n\nالمستندات: %@\nالمكتبة: %@\nالتخزين المؤقت: %@\n\nالإجمالي: %@",
                name, [self.manager formatBytes:d], [self.manager formatBytes:l],
                [self.manager formatBytes:c], [self.manager formatBytes:t]];

            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"حذف بيانات التطبيق"
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
            [a addAction:[UIAlertAction actionWithTitle:@"حذف" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *_) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    BOOL ok = [self.manager wipeAppData:bid];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self toast:ok ? @"تم الحذف ✅" : @"فشل الحذف ❌"];
                        if (ok) [self loadData];
                    });
                });
            }]];
            [self presentViewController:a animated:YES completion:nil];
        });
    });
}

- (void)toast:(NSString *)msg {
    UILabel *t = [[UILabel alloc] init];
    t.text = msg;
    t.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    t.textColor = C_TEXT_PRI;
    t.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.20 alpha:0.95];
    t.textAlignment = NSTextAlignmentCenter;
    t.layer.cornerRadius = 10;
    t.layer.masksToBounds = YES;
    t.alpha = 0;
    t.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:t];

    [NSLayoutConstraint activateConstraints:@[
        [t.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [t.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-24],
        [t.heightAnchor constraintEqualToConstant:38],
        [t.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:50]
    ]];

    [UIView animateWithDuration:0.3 animations:^{ t.alpha = 1.0; } completion:^(BOOL f) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3 animations:^{ t.alpha = 0; } completion:^(BOOL f2) { [t removeFromSuperview]; }];
        });
    }];
}

@end