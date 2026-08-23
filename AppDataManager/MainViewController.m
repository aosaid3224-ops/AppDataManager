#import "MainViewController.h"
#import "AppDataManager.h"
#import "AppDetailViewController.h"

#pragma mark - Monochrome design system

static UIColor *ADMCanvas(void) { return [UIColor colorWithRed:0.028 green:0.029 blue:0.035 alpha:1.0]; }
static UIColor *ADMPanel(void) { return [UIColor colorWithRed:0.090 green:0.093 blue:0.108 alpha:1.0]; }
static UIColor *ADMPanelRaised(void) { return [UIColor colorWithRed:0.135 green:0.140 blue:0.158 alpha:1.0]; }
static UIColor *ADMLine(void) { return [UIColor colorWithWhite:0.34 alpha:0.82]; }
static UIColor *ADMInk(void) { return [UIColor colorWithWhite:0.98 alpha:1.0]; }
static UIColor *ADMMuted(void) { return [UIColor colorWithWhite:0.66 alpha:1.0]; }
static UIColor *ADMAccent(void) { return [UIColor colorWithRed:0.43 green:0.56 blue:0.92 alpha:1.0]; }
static UIColor *ADMAccentSoft(void) { return [UIColor colorWithRed:0.13 green:0.17 blue:0.30 alpha:1.0]; }

#pragma mark - Application row

@interface AppListCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIImageView *appIcon;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *bundleLabel;
@property (nonatomic, strong) UILabel *sizeLabel;
@end

@implementation AppListCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _cardView = [[UIView alloc] init];
        _cardView.backgroundColor = ADMPanel();
        _cardView.layer.cornerRadius = 16;
        _cardView.layer.borderWidth = 0.5;
        _cardView.layer.borderColor = ADMLine().CGColor;
        _cardView.layer.masksToBounds = YES;
        _cardView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_cardView];

        _appIcon = [[UIImageView alloc] init];
        _appIcon.layer.cornerRadius = 12;
        _appIcon.layer.masksToBounds = YES;
        _appIcon.contentMode = UIViewContentModeScaleAspectFit;
        _appIcon.backgroundColor = ADMPanelRaised();
        _appIcon.translatesAutoresizingMaskIntoConstraints = NO;
        [_cardView addSubview:_appIcon];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        _nameLabel.textColor = ADMInk();
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_cardView addSubview:_nameLabel];

        _bundleLabel = [[UILabel alloc] init];
        _bundleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightRegular];
        _bundleLabel.textColor = ADMMuted();
        _bundleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        _bundleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_cardView addSubview:_bundleLabel];

        _sizeLabel = [[UILabel alloc] init];
        _sizeLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
        _sizeLabel.textColor = ADMAccent();
        _sizeLabel.textAlignment = NSTextAlignmentRight;
        _sizeLabel.adjustsFontSizeToFitWidth = YES;
        _sizeLabel.minimumScaleFactor = 0.65;
        _sizeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_cardView addSubview:_sizeLabel];

        UIImageView *arrow = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.left"]];
        arrow.tintColor = [UIColor colorWithWhite:0.38 alpha:1.0];
        arrow.translatesAutoresizingMaskIntoConstraints = NO;
        [_cardView addSubview:arrow];

        [NSLayoutConstraint activateConstraints:@[
            [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5],
            [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],
            [_cardView.heightAnchor constraintEqualToConstant:76],

            [_appIcon.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:15],
            [_appIcon.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
            [_appIcon.widthAnchor constraintEqualToConstant:46],
            [_appIcon.heightAnchor constraintEqualToConstant:46],

            [_nameLabel.leadingAnchor constraintEqualToAnchor:_appIcon.trailingAnchor constant:13],
            [_nameLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:14],
            [_nameLabel.trailingAnchor constraintEqualToAnchor:_sizeLabel.leadingAnchor constant:-10],
            [_bundleLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_bundleLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:4],
            [_bundleLabel.trailingAnchor constraintEqualToAnchor:_nameLabel.trailingAnchor],

            [_sizeLabel.trailingAnchor constraintEqualToAnchor:arrow.leadingAnchor constant:-8],
            [_sizeLabel.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
            [_sizeLabel.widthAnchor constraintEqualToConstant:76],
            [arrow.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14],
            [arrow.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
            [arrow.widthAnchor constraintEqualToConstant:12],
            [arrow.heightAnchor constraintEqualToConstant:16]
        ]];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.nameLabel.text = nil;
    self.bundleLabel.text = nil;
    self.sizeLabel.text = nil;
    self.appIcon.image = nil;
    self.appIcon.tintColor = nil;
    self.alpha = 1.0;
    self.transform = CGAffineTransformIdentity;
}

@end

#pragma mark - Scope header

@interface AppScopeHeaderView : UITableViewHeaderFooterView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *countLabel;
@end

@implementation AppScopeHeaderView

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundView = [[UIView alloc] init];
        self.backgroundView.backgroundColor = ADMCanvas();
        self.contentView.backgroundColor = ADMCanvas();

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
        _titleLabel.textColor = ADMInk();
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightMedium];
        _subtitleLabel.textColor = ADMAccent();
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_subtitleLabel];

        _countLabel = [[UILabel alloc] init];
        _countLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];
        _countLabel.textColor = ADMAccent();
        _countLabel.textAlignment = NSTextAlignmentCenter;
        _countLabel.backgroundColor = ADMAccentSoft();
        _countLabel.layer.cornerRadius = 11;
        _countLabel.layer.masksToBounds = YES;
        _countLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_countLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18],
            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
            [_countLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18],
            [_countLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_countLabel.widthAnchor constraintEqualToConstant:42],
            [_countLabel.heightAnchor constraintEqualToConstant:23]
        ]];
    }
    return self;
}

@end

#pragma mark - Compact statistics

@interface StatsHeaderView : UIView
@property (nonatomic, strong) UILabel *appsValueLabel;
@property (nonatomic, strong) UILabel *sizeValueLabel;
@end

@implementation StatsHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = ADMPanel();
        self.layer.cornerRadius = 16;
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = [ADMAccent() colorWithAlphaComponent:0.34].CGColor;
        self.layer.masksToBounds = YES;

        CAGradientLayer *wash = [CAGradientLayer layer];
        wash.frame = self.bounds;
        wash.colors = @[(id)[ADMAccentSoft() colorWithAlphaComponent:0.88].CGColor, (id)ADMPanel().CGColor];
        wash.startPoint = CGPointMake(1.0, 0.0);
        wash.endPoint = CGPointMake(0.0, 1.0);
        [self.layer insertSublayer:wash atIndex:0];

        UILabel *title = [[UILabel alloc] init];
        title.text = @"ملخص البيانات";
        title.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        title.textColor = UIColor.whiteColor;
        title.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:title];

        UILabel *status = [[UILabel alloc] init];
        status.text = @"● LIVE";
        status.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold];
        status.textColor = ADMAccent();
        status.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:status];

        UIView *rule = [[UIView alloc] init];
        rule.backgroundColor = [ADMAccent() colorWithAlphaComponent:0.72];
        rule.layer.cornerRadius = 1;
        rule.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:rule];

        UIView *split = [[UIView alloc] init];
        split.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.16];
        split.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:split];

        _appsValueLabel = [[UILabel alloc] init];
        _appsValueLabel.text = @"—";
        _appsValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:26 weight:UIFontWeightBold];
        _appsValueLabel.textColor = ADMAccent();
        _appsValueLabel.textAlignment = NSTextAlignmentRight;
        _appsValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_appsValueLabel];

        _sizeValueLabel = [[UILabel alloc] init];
        _sizeValueLabel.text = @"0 B";
        _sizeValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:18 weight:UIFontWeightSemibold];
        _sizeValueLabel.textColor = UIColor.whiteColor;
        _sizeValueLabel.textAlignment = NSTextAlignmentLeft;
        _sizeValueLabel.adjustsFontSizeToFitWidth = YES;
        _sizeValueLabel.minimumScaleFactor = 0.65;
        _sizeValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_sizeValueLabel];

        UILabel *appsCaption = [[UILabel alloc] init];
        appsCaption.text = @"التطبيقات المثبتة";
        appsCaption.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        appsCaption.textColor = [UIColor colorWithWhite:1.0 alpha:0.74];
        appsCaption.textAlignment = NSTextAlignmentRight;
        appsCaption.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:appsCaption];

        UILabel *sizeCaption = [[UILabel alloc] init];
        sizeCaption.text = @"حجم البيانات";
        sizeCaption.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        sizeCaption.textColor = [UIColor colorWithWhite:1.0 alpha:0.74];
        sizeCaption.textAlignment = NSTextAlignmentLeft;
        sizeCaption.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:sizeCaption];

        [NSLayoutConstraint activateConstraints:@[
            [title.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-18],
            [title.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
            [status.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:18],
            [status.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
            [rule.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-18],
            [rule.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
            [rule.widthAnchor constraintEqualToConstant:36],
            [rule.heightAnchor constraintEqualToConstant:2],
            [split.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [split.topAnchor constraintEqualToAnchor:rule.bottomAnchor constant:9],
            [split.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-13],
            [split.widthAnchor constraintEqualToConstant:0.5],
            [_appsValueLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-18],
            [_appsValueLabel.topAnchor constraintEqualToAnchor:rule.bottomAnchor constant:7],
            [_appsValueLabel.leadingAnchor constraintEqualToAnchor:split.trailingAnchor constant:16],
            [appsCaption.trailingAnchor constraintEqualToAnchor:_appsValueLabel.trailingAnchor],
            [appsCaption.topAnchor constraintEqualToAnchor:_appsValueLabel.bottomAnchor constant:0],
            [_sizeValueLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:18],
            [_sizeValueLabel.topAnchor constraintEqualToAnchor:rule.bottomAnchor constant:10],
            [_sizeValueLabel.trailingAnchor constraintEqualToAnchor:split.leadingAnchor constant:-16],
            [sizeCaption.leadingAnchor constraintEqualToAnchor:_sizeValueLabel.leadingAnchor],
            [sizeCaption.topAnchor constraintEqualToAnchor:_sizeValueLabel.bottomAnchor constant:0]
        ]];
    }
    return self;
}

@end

#pragma mark - Empty/loading state

@interface ADMStateView : UIView
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *retryButton;
@end

@implementation ADMStateView

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.backgroundColor = ADMPanel();
        self.layer.cornerRadius = 18;
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = ADMLine().CGColor;
        self.translatesAutoresizingMaskIntoConstraints = NO;

        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        _spinner.color = ADMAccent();
        _spinner.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_spinner];

        _iconView = [[UIImageView alloc] init];
        _iconView.tintColor = ADMAccent();
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_iconView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        _titleLabel.textColor = ADMInk();
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_titleLabel];

        _messageLabel = [[UILabel alloc] init];
        _messageLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _messageLabel.textColor = ADMMuted();
        _messageLabel.textAlignment = NSTextAlignmentCenter;
        _messageLabel.numberOfLines = 0;
        _messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_messageLabel];

        _retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_retryButton setTitle:@"إعادة المحاولة" forState:UIControlStateNormal];
        [_retryButton setTitleColor:ADMInk() forState:UIControlStateNormal];
        _retryButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        _retryButton.backgroundColor = ADMPanelRaised();
        _retryButton.layer.cornerRadius = 11;
        _retryButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_retryButton];

        [NSLayoutConstraint activateConstraints:@[
            [_spinner.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_spinner.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_iconView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_iconView.topAnchor constraintEqualToAnchor:self.topAnchor constant:25],
            [_iconView.widthAnchor constraintEqualToConstant:30],
            [_iconView.heightAnchor constraintEqualToConstant:30],
            [_titleLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:10],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:18],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-18],
            [_messageLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6],
            [_messageLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:24],
            [_messageLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-24],
            [_retryButton.topAnchor constraintEqualToAnchor:_messageLabel.bottomAnchor constant:14],
            [_retryButton.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_retryButton.widthAnchor constraintEqualToConstant:122],
            [_retryButton.heightAnchor constraintEqualToConstant:34]
        ]];
    }
    return self;
}

@end

#pragma mark - Controller

@interface MainViewController () <UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) UISegmentedControl *scopeControl;
@property (nonatomic, strong) NSArray *allApps;
@property (nonatomic, strong) NSArray *userApps;
@property (nonatomic, strong) NSArray *systemApps;
@property (nonatomic, strong) NSArray *visibleApps;
@property (nonatomic, strong) AppDataManager *manager;
@property (nonatomic, strong) UIView *topContainer;
@property (nonatomic, strong) StatsHeaderView *statsView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) ADMStateView *stateView;
@property (nonatomic, assign) BOOL isCalculatingSizes;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"التطبيقات";
    self.view.backgroundColor = ADMCanvas();
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.manager = [AppDataManager sharedManager];
    self.allApps = @[];
    self.userApps = @[];
    self.systemApps = @[];
    self.visibleApps = @[];
    [self setupNavigationBar];
    [self setupSearchController];
    [self setupTableView];
    [self setupStateView];
    [self loadApps];
}

- (void)setupNavigationBar {
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    self.navigationController.navigationBar.tintColor = ADMInk();
    self.navigationController.navigationBar.barTintColor = ADMCanvas();
    self.navigationController.navigationBar.backgroundColor = ADMCanvas();
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: ADMInk()};
    self.navigationController.navigationBar.largeTitleTextAttributes = @{NSForegroundColorAttributeName: ADMInk(), NSFontAttributeName: [UIFont systemFontOfSize:34 weight:UIFontWeightBold]};
}

- (void)setupSearchController {
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"ابحث بالاسم أو معرف الحزمة";
    self.searchController.searchBar.tintColor = ADMAccent();
    self.searchController.searchBar.searchTextField.textColor = ADMInk();
    self.searchController.searchBar.searchTextField.backgroundColor = ADMPanelRaised();
    self.searchController.searchBar.searchTextField.layer.cornerRadius = 11;
    self.searchController.searchBar.searchTextField.layer.masksToBounds = YES;
    self.searchController.searchBar.searchTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.searchController.searchBar.placeholder attributes:@{NSForegroundColorAttributeName: ADMMuted()}];
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
}

- (void)setupTableView {
    self.topContainer = [[UIView alloc] init];
    self.topContainer.backgroundColor = ADMCanvas();
    self.topContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.topContainer];

    self.statsView = [[StatsHeaderView alloc] initWithFrame:CGRectZero];
    self.statsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.topContainer addSubview:self.statsView];

    self.scopeControl = [[UISegmentedControl alloc] initWithItems:@[@"تطبيقات المستخدم", @"تطبيقات النظام"]];
    self.scopeControl.selectedSegmentIndex = 0;
    self.scopeControl.backgroundColor = ADMPanel();
    self.scopeControl.selectedSegmentTintColor = ADMAccentSoft();
    self.scopeControl.layer.cornerRadius = 11;
    self.scopeControl.layer.borderWidth = 0.5;
    self.scopeControl.layer.borderColor = [ADMAccent() colorWithAlphaComponent:0.38].CGColor;
    self.scopeControl.clipsToBounds = YES;
    [self.scopeControl setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor, NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightMedium]} forState:UIControlStateNormal];
    [self.scopeControl setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor, NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold]} forState:UIControlStateSelected];
    [self.scopeControl addTarget:self action:@selector(scopeChanged:) forControlEvents:UIControlEventValueChanged];
    self.scopeControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.topContainer addSubview:self.scopeControl];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = ADMCanvas();
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 30, 0);
    self.tableView.alwaysBounceVertical = YES;
    self.tableView.directionalLockEnabled = NO;
    self.tableView.delaysContentTouches = NO;
    self.tableView.canCancelContentTouches = YES;
    self.tableView.decelerationRate = UIScrollViewDecelerationRateNormal;
    self.tableView.bounces = YES;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.scrollsToTop = YES;
    self.tableView.showsVerticalScrollIndicator = YES;
    self.tableView.rowHeight = 86;
    self.tableView.estimatedRowHeight = 86;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    [self.tableView registerClass:[AppScopeHeaderView class] forHeaderFooterViewReuseIdentifier:@"AppScopeHeader"];
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = ADMAccent();
    [self.refreshControl addTarget:self action:@selector(loadApps) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;

    [NSLayoutConstraint activateConstraints:@[
        [self.topContainer.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.topContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.topContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.topContainer.heightAnchor constraintEqualToConstant:154],
        [self.statsView.topAnchor constraintEqualToAnchor:self.topContainer.topAnchor constant:8],
        [self.statsView.leadingAnchor constraintEqualToAnchor:self.topContainer.leadingAnchor constant:16],
        [self.statsView.trailingAnchor constraintEqualToAnchor:self.topContainer.trailingAnchor constant:-16],
        [self.statsView.heightAnchor constraintEqualToConstant:94],
        [self.scopeControl.topAnchor constraintEqualToAnchor:self.statsView.bottomAnchor constant:10],
        [self.scopeControl.leadingAnchor constraintEqualToAnchor:self.topContainer.leadingAnchor constant:16],
        [self.scopeControl.trailingAnchor constraintEqualToAnchor:self.topContainer.trailingAnchor constant:-16],
        [self.scopeControl.heightAnchor constraintEqualToConstant:40],
        [self.tableView.topAnchor constraintEqualToAnchor:self.topContainer.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupStateView {
    self.stateView = [[ADMStateView alloc] init];
    self.stateView.hidden = YES;
    [self.stateView.retryButton addTarget:self action:@selector(loadApps) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.stateView];
    [NSLayoutConstraint activateConstraints:@[
        [self.stateView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:28],
        [self.stateView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-28],
        [self.stateView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:28],
        [self.stateView.heightAnchor constraintEqualToConstant:205]
    ]];
}

#pragma mark - Loading and filtering

- (void)loadApps {
    [self.stateView.spinner startAnimating];
    self.stateView.hidden = NO;
    self.stateView.iconView.hidden = YES;
    self.stateView.titleLabel.text = @"جاري قراءة التطبيقات";
    self.stateView.messageLabel.text = @"يتم تحديث القائمة من النظام…";
    self.stateView.retryButton.hidden = YES;
    self.tableView.alpha = self.allApps.count > 0 ? 1.0 : 0.38;
    [self.manager clearCache];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *apps = [self.manager allInstalledApplications];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allApps = apps ?: @[];
            [self rebuildSectionsForSearchText:self.searchController.searchBar.text];
            [self.refreshControl endRefreshing];
            [self.stateView.spinner stopAnimating];
            [self updateStateAfterLoad];
            self.statsView.appsValueLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.allApps.count];
            self.statsView.sizeValueLabel.text = @"0 B";
            self.statsView.sizeValueLabel.alpha = 1.0;
            [self.tableView reloadData];
            [self calculateSizesInBackground];
        });
    });
}

- (void)updateStateAfterLoad {
    if (self.allApps.count > 0) {
        self.stateView.hidden = YES;
        self.tableView.alpha = 1.0;
        return;
    }
    self.stateView.hidden = NO;
    self.stateView.iconView.hidden = NO;
    self.stateView.iconView.image = [UIImage systemImageNamed:@"square.grid.2x2"];
    self.stateView.titleLabel.text = @"لا توجد بيانات لعرضها";
    self.stateView.messageLabel.text = @"لم تُرجع خدمة النظام قائمة التطبيقات. يمكنك إعادة المحاولة بأمان.";
    self.stateView.retryButton.hidden = NO;
    self.tableView.alpha = 1.0;
}

- (BOOL)isSystemApplicationRecord:(NSDictionary *)app {
    NSString *bundleID = [app[@"bundleID"] isKindOfClass:[NSString class]] ? app[@"bundleID"] : @"";
    NSString *type = [[app[@"type"] description] lowercaseString];
    if ([bundleID hasPrefix:@"com.apple."]) return YES;
    if ([type containsString:@"system"] || [type containsString:@"internal"]) return YES;
    if ([type containsString:@"user"]) return NO;
    return [self.manager isSystemApp:bundleID];
}

- (void)rebuildSectionsForSearchText:(NSString *)searchText {
    NSMutableArray *users = [NSMutableArray array];
    NSMutableArray *systems = [NSMutableArray array];
    NSPredicate *matches = searchText.length > 0 ? [NSPredicate predicateWithFormat:@"name CONTAINS[c] %@ OR bundleID CONTAINS[c] %@", searchText, searchText] : nil;
    for (NSDictionary *app in self.allApps) {
        if (matches && ![matches evaluateWithObject:app]) continue;
        if ([self isSystemApplicationRecord:app]) [systems addObject:app];
        else [users addObject:app];
    }
    self.userApps = users;
    self.systemApps = systems;
    [self updateVisibleApps];
}

- (void)updateVisibleApps {
    self.visibleApps = self.scopeControl.selectedSegmentIndex == 0 ? (self.userApps ?: @[]) : (self.systemApps ?: @[]);
}

- (void)scopeChanged:(UISegmentedControl *)sender {
    [self updateVisibleApps];
    [UIView transitionWithView:self.tableView duration:0.24 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        [self.tableView reloadData];
    } completion:nil];
}

- (NSString *)displaySizeForApp:(NSDictionary *)app {
    NSString *value = [app[@"sizeString"] isKindOfClass:[NSString class]] ? app[@"sizeString"] : @"";
    NSString *normalized = [value lowercaseString];
    if (value.length == 0 || [normalized containsString:@"calculating"] || [value containsString:@"جار"] || [value containsString:@"حساب"]) return @"—";
    return value;
}

- (void)calculateSizesInBackground {
    if (self.isCalculatingSizes || self.allApps.count == 0) return;
    self.isCalculatingSizes = YES;
    NSArray *snapshot = [self.allApps copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *updated = [NSMutableArray arrayWithCapacity:snapshot.count];
        unsigned long long total = 0;
        for (NSDictionary *app in snapshot) {
            NSString *bundleID = app[@"bundleID"];
            unsigned long long size = [self.manager dataSizeForBundleID:bundleID];
            NSMutableDictionary *copy = [app mutableCopy];
            copy[@"size"] = @(size);
            copy[@"sizeString"] = [self.manager formatBytes:size];
            [updated addObject:copy];
            total += size;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allApps = updated;
            [self rebuildSectionsForSearchText:self.searchController.searchBar.text];
            self.statsView.sizeValueLabel.text = [self.manager formatBytes:total];
            self.statsView.sizeValueLabel.alpha = 0.0;
            [UIView animateWithDuration:0.24 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.statsView.sizeValueLabel.alpha = 1.0;
            } completion:nil];
            [self.tableView reloadData];
            self.isCalculatingSizes = NO;
        });
    });
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.visibleApps.count; }

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    AppScopeHeaderView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"AppScopeHeader"];
    BOOL system = self.scopeControl.selectedSegmentIndex == 1;
    header.titleLabel.text = system ? @"تطبيقات النظام" : @"تطبيقات المستخدم";
    header.subtitleLabel.text = system ? @"SYSTEM APPLICATIONS" : @"USER APPLICATIONS";
    header.countLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.visibleApps.count];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section { return 60; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"AppCell";
    AppListCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) cell = [[AppListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
    NSDictionary *app = self.visibleApps[indexPath.row];
    cell.nameLabel.text = app[@"name"];
    cell.bundleLabel.text = app[@"bundleID"];
    cell.sizeLabel.text = [self displaySizeForApp:app];
    UIImage *icon = [self.manager iconForBundleID:app[@"bundleID"]];
    if (icon) { cell.appIcon.image = icon; cell.appIcon.tintColor = nil; }
    else { cell.appIcon.image = [UIImage systemImageNamed:@"app.fill"]; cell.appIcon.tintColor = ADMAccent(); }
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Subtle entrance only: it does not modify scroll physics or follow every scroll frame.
    cell.alpha = 0.96;
    cell.transform = CGAffineTransformMakeTranslation(0.0, 4.0);
    [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut animations:^{
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *app = self.visibleApps[indexPath.row];
    AppDetailViewController *detailVC = [[AppDetailViewController alloc] initWithAppInfo:app];
    [self.navigationController pushViewController:detailVC animated:YES];
}

#pragma mark - Search

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self rebuildSectionsForSearchText:searchController.searchBar.text];
    [self.tableView reloadData];
}

@end
