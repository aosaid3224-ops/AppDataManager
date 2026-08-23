#import "BackupManagerViewController.h"
#import "AppDataManager.h"

static UIColor *ADMCanvas(void) { return [UIColor colorWithRed:0.025 green:0.027 blue:0.035 alpha:1.0]; }
static UIColor *ADMPanel(void) { return [UIColor colorWithRed:0.090 green:0.093 blue:0.108 alpha:1.0]; }
static UIColor *ADMPanelRaised(void) { return [UIColor colorWithRed:0.135 green:0.140 blue:0.158 alpha:1.0]; }
static UIColor *ADMInk(void) { return [UIColor colorWithRed:0.93 green:0.95 blue:0.98 alpha:1.0]; }
static UIColor *ADMMuted(void) { return [UIColor colorWithWhite:0.66 alpha:1.0]; }
static UIColor *ADMAccent(void) { return [UIColor colorWithRed:0.43 green:0.56 blue:0.92 alpha:1.0]; }
static UIColor *ADMAccentSoft(void) { return [UIColor colorWithRed:0.13 green:0.17 blue:0.30 alpha:1.0]; }

#pragma mark - Storage map

@interface PieChartView : UIView
@property (nonatomic, strong) NSArray *segments;
@property (nonatomic, strong) UILabel *centerLabel;
@end

@implementation PieChartView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        _centerLabel = [[UILabel alloc] init];
        _centerLabel.textAlignment = NSTextAlignmentCenter;
        _centerLabel.numberOfLines = 2;
        _centerLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_centerLabel];
        [NSLayoutConstraint activateConstraints:@[
            [_centerLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_centerLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_centerLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_centerLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
        ]];
    }
    return self;
}

- (void)setSegments:(NSArray *)segments { _segments = segments; [self setNeedsDisplay]; }

- (void)drawRect:(CGRect)rect {
    CGFloat total = 0;
    for (NSDictionary *segment in self.segments) total += [segment[@"value"] doubleValue];
    if (total <= 0) return;

    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    CGFloat lineWidth = 15.0;
    CGFloat radius = MIN(rect.size.width, rect.size.height) / 2.0 - lineWidth;
    UIBezierPath *track = [UIBezierPath bezierPathWithArcCenter:center radius:radius startAngle:-M_PI_2 endAngle:3 * M_PI_2 clockwise:YES];
    track.lineWidth = lineWidth;
    track.lineCapStyle = kCGLineCapRound;
    [[UIColor colorWithWhite:0.16 alpha:1.0] setStroke];
    [track stroke];

    CGFloat start = -M_PI_2;
    for (NSDictionary *segment in self.segments) {
        CGFloat value = [segment[@"value"] doubleValue];
        if (value <= 0) continue;
        CGFloat end = start + ((value / total) * 2 * M_PI);
        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center radius:radius startAngle:start endAngle:end clockwise:YES];
        path.lineWidth = lineWidth;
        path.lineCapStyle = kCGLineCapRound;
        [segment[@"color"] setStroke];
        [path stroke];
        start = end;
    }
}

@end

#pragma mark - Backup row

@interface BackupCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIImageView *appIcon;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *sizeLabel;
@property (nonatomic, strong) UIButton *restoreButton;
@property (nonatomic, strong) UIButton *deleteButton;
@end

@implementation BackupCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _cardView = [[UIView alloc] init];
        _cardView.backgroundColor = ADMPanel();
        _cardView.layer.cornerRadius = 15;
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
        _nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _nameLabel.textColor = ADMInk();
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_cardView addSubview:_nameLabel];

        _dateLabel = [[UILabel alloc] init];
        _dateLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightRegular];
        _dateLabel.textColor = ADMMuted();
        _dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_cardView addSubview:_dateLabel];

        _sizeLabel = [[UILabel alloc] init];
        _sizeLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
        _sizeLabel.textColor = ADMAccent();
        _sizeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_cardView addSubview:_sizeLabel];

        _deleteButton = [self makeButtonWithIcon:@"trash.fill" color:ADMAccent() background:ADMAccentSoft()];
        [_cardView addSubview:_deleteButton];
        _restoreButton = [self makeButtonWithIcon:@"arrow.counterclockwise" color:ADMAccent() background:ADMAccentSoft()];
        [_cardView addSubview:_restoreButton];

        [NSLayoutConstraint activateConstraints:@[
            [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5],
            [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],
            [_cardView.heightAnchor constraintEqualToConstant:82],
            [_appIcon.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:15],
            [_appIcon.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
            [_appIcon.widthAnchor constraintEqualToConstant:46],
            [_appIcon.heightAnchor constraintEqualToConstant:46],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_appIcon.trailingAnchor constant:12],
            [_nameLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:13],
            [_nameLabel.trailingAnchor constraintEqualToAnchor:_restoreButton.leadingAnchor constant:-10],
            [_dateLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_dateLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:4],
            [_dateLabel.trailingAnchor constraintEqualToAnchor:_nameLabel.trailingAnchor],
            [_sizeLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_sizeLabel.topAnchor constraintEqualToAnchor:_dateLabel.bottomAnchor constant:4],
            [_deleteButton.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-13],
            [_deleteButton.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
            [_deleteButton.widthAnchor constraintEqualToConstant:38],
            [_deleteButton.heightAnchor constraintEqualToConstant:38],
            [_restoreButton.trailingAnchor constraintEqualToAnchor:_deleteButton.leadingAnchor constant:-8],
            [_restoreButton.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
            [_restoreButton.widthAnchor constraintEqualToConstant:38],
            [_restoreButton.heightAnchor constraintEqualToConstant:38]
        ]];
    }
    return self;
}

- (UIButton *)makeButtonWithIcon:(NSString *)icon color:(UIColor *)color background:(UIColor *)background {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage systemImageNamed:icon] forState:UIControlStateNormal];
    button.tintColor = color;
    button.backgroundColor = background;
    button.layer.cornerRadius = 11;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.nameLabel.text = nil;
    self.dateLabel.text = nil;
    self.sizeLabel.text = nil;
    self.appIcon.image = nil;
    self.alpha = 1.0;
    self.transform = CGAffineTransformIdentity;
}

@end

#pragma mark - Controller

@interface BackupManagerViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *backups;
@property (nonatomic, strong) AppDataManager *manager;
@property (nonatomic, strong) PieChartView *pieChart;
@property (nonatomic, strong) UIView *statsContainer;
@end

@implementation BackupManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"النسخ الاحتياطية";
    self.view.backgroundColor = ADMCanvas();
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.manager = [AppDataManager sharedManager];
    [self setupNavigationBar];
    [self setupStatsView];
    [self setupTableView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadBackups];
}

- (void)setupNavigationBar {
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    self.navigationController.navigationBar.tintColor = ADMInk();
    self.navigationController.navigationBar.barTintColor = ADMCanvas();
    self.navigationController.navigationBar.backgroundColor = ADMCanvas();
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: ADMInk()};
    self.navigationController.navigationBar.largeTitleTextAttributes = @{NSForegroundColorAttributeName: ADMInk(), NSFontAttributeName: [UIFont systemFontOfSize:34 weight:UIFontWeightBold]};
    UIBarButtonItem *add = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"plus"] style:UIBarButtonItemStylePlain target:self action:@selector(addBackupTapped)];
    add.tintColor = ADMAccent();
    self.navigationItem.rightBarButtonItem = add;
}

- (void)setupStatsView {
    self.statsContainer = [[UIView alloc] init];
    self.statsContainer.backgroundColor = ADMPanel();
    self.statsContainer.layer.cornerRadius = 20;
    self.statsContainer.layer.masksToBounds = YES;
    self.statsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statsContainer];

    UILabel *eyebrow = [[UILabel alloc] init];
    eyebrow.text = @"STORAGE MAP  /  BACKUP ARCHIVE";
    eyebrow.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightSemibold];
    eyebrow.textColor = ADMAccent();
    eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.statsContainer addSubview:eyebrow];

    self.pieChart = [[PieChartView alloc] init];
    self.pieChart.translatesAutoresizingMaskIntoConstraints = NO;
    [self.statsContainer addSubview:self.pieChart];

    NSArray *items = @[
        @{ @"color": ADMAccent(), @"title": @"النسخ الاحتياطية" },
        @{ @"color": [UIColor colorWithWhite:0.50 alpha:1.0], @"title": @"بيانات التطبيقات" },
        @{ @"color": [UIColor colorWithWhite:0.30 alpha:1.0], @"title": @"المساحة الحرة" }
    ];
    UIView *lastDot = nil;
    for (NSDictionary *item in items) {
        UIView *dot = [[UIView alloc] init];
        dot.backgroundColor = item[@"color"];
        dot.layer.cornerRadius = 3;
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        [self.statsContainer addSubview:dot];
        UILabel *label = [[UILabel alloc] init];
        label.text = item[@"title"];
        label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        label.textColor = ADMMuted();
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [self.statsContainer addSubview:label];
        UILabel *value = [[UILabel alloc] init];
        value.tag = [item[@"title"] hash];
        value.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
        value.textColor = ADMInk();
        value.textAlignment = NSTextAlignmentRight;
        value.translatesAutoresizingMaskIntoConstraints = NO;
        [self.statsContainer addSubview:value];
        [NSLayoutConstraint activateConstraints:@[
            [dot.leadingAnchor constraintEqualToAnchor:self.pieChart.trailingAnchor constant:14],
            [dot.widthAnchor constraintEqualToConstant:7],
            [dot.heightAnchor constraintEqualToConstant:7],
            [label.leadingAnchor constraintEqualToAnchor:dot.trailingAnchor constant:8],
            [label.centerYAnchor constraintEqualToAnchor:dot.centerYAnchor],
            [value.trailingAnchor constraintEqualToAnchor:self.statsContainer.trailingAnchor constant:-16],
            [value.leadingAnchor constraintGreaterThanOrEqualToAnchor:label.trailingAnchor constant:5],
            [value.centerYAnchor constraintEqualToAnchor:dot.centerYAnchor]
        ]];
        if (lastDot) [dot.topAnchor constraintEqualToAnchor:lastDot.bottomAnchor constant:13].active = YES;
        else [dot.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:20].active = YES;
        lastDot = dot;
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.statsContainer.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [self.statsContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.statsContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.statsContainer.heightAnchor constraintEqualToConstant:190],
        [eyebrow.leadingAnchor constraintEqualToAnchor:self.statsContainer.leadingAnchor constant:18],
        [eyebrow.topAnchor constraintEqualToAnchor:self.statsContainer.topAnchor constant:17],
        [self.pieChart.leadingAnchor constraintEqualToAnchor:self.statsContainer.leadingAnchor constant:18],
        [self.pieChart.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:14],
        [self.pieChart.widthAnchor constraintEqualToConstant:132],
        [self.pieChart.heightAnchor constraintEqualToConstant:132]
    ]];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = ADMCanvas();
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 30, 0);
    self.tableView.rowHeight = 92;
    self.tableView.estimatedRowHeight = 92;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.statsContainer.bottomAnchor constant:14],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

#pragma mark - Data (preserved)

- (void)loadBackups {
    NSMutableArray *allBackups = [NSMutableArray array];
    NSArray *apps = [self.manager allInstalledApplications];
    for (NSDictionary *app in apps) {
        NSArray *appBackups = [self.manager availableBackupsForBundleID:app[@"bundleID"]];
        for (NSDictionary *backup in appBackups) {
            NSMutableDictionary *fullBackup = [backup mutableCopy];
            fullBackup[@"appName"] = app[@"name"];
            fullBackup[@"bundleID"] = app[@"bundleID"];
            [allBackups addObject:fullBackup];
        }
    }
    self.backups = [allBackups sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"date"] compare:a[@"date"]];
    }];
    [self updateChart];
    [self.tableView reloadData];
}

- (void)updateChart {
    unsigned long long backupsSize = [self.manager totalBackupsSize];
    unsigned long long appsSize = [self.manager totalAppsDataSize];
    unsigned long long freeSpace = [self.manager totalFreeSpace];
    unsigned long long total = backupsSize + appsSize + freeSpace;
    if (total == 0) total = 1;
    self.pieChart.segments = @[
        @{ @"value": @(backupsSize), @"color": ADMAccent() },
        @{ @"value": @(appsSize), @"color": [UIColor colorWithWhite:0.50 alpha:1.0] },
        @{ @"value": @(freeSpace), @"color": [UIColor colorWithWhite:0.30 alpha:1.0] }
    ];
    self.pieChart.centerLabel.attributedText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\nالمستخدم", [self.manager formatBytes:backupsSize + appsSize]] attributes:@{NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightSemibold], NSForegroundColorAttributeName: ADMMuted()}];
    NSDictionary *values = @{
        @"النسخ الاحتياطية": [self.manager formatBytes:backupsSize],
        @"بيانات التطبيقات": [self.manager formatBytes:appsSize],
        @"المساحة الحرة": [self.manager formatBytes:freeSpace]
    };
    for (UIView *view in self.statsContainer.subviews) {
        if (![view isKindOfClass:[UILabel class]] || view.tag == 0) continue;
        UILabel *label = (UILabel *)view;
        for (NSString *key in values) if (label.tag == [key hash]) label.text = values[key];
    }
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.backups.count; }

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *header = [[UIView alloc] init];
    header.backgroundColor = ADMCanvas();
    UILabel *title = [[UILabel alloc] init];
    title.text = @"الأرشيف المتاح";
    title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    title.textColor = ADMInk();
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:title];
    UILabel *count = [[UILabel alloc] init];
    count.text = [NSString stringWithFormat:@"%lu نسخة", (unsigned long)self.backups.count];
    count.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
    count.textColor = ADMMuted();
    count.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:count];
    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:18],
        [title.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [count.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-18],
        [count.centerYAnchor constraintEqualToAnchor:header.centerYAnchor]
    ]];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section { return 50; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"BackupCell";
    BackupCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) cell = [[BackupCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
    NSDictionary *backup = self.backups[indexPath.row];
    cell.nameLabel.text = backup[@"appName"];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MMM d, yyyy 'at' h:mm a"];
    cell.dateLabel.text = [formatter stringFromDate:backup[@"date"]];
    cell.sizeLabel.text = backup[@"sizeString"];
    UIImage *icon = [self.manager iconForBundleID:backup[@"bundleID"]];
    if (icon) { cell.appIcon.image = icon; cell.appIcon.tintColor = nil; }
    else { cell.appIcon.image = [UIImage systemImageNamed:@"app.fill"];         cell.appIcon.tintColor = ADMAccent(); }
    cell.restoreButton.tag = indexPath.row;
    [cell.restoreButton addTarget:self action:@selector(restoreTapped:) forControlEvents:UIControlEventTouchUpInside];
    cell.deleteButton.tag = indexPath.row;
    [cell.deleteButton addTarget:self action:@selector(deleteTapped:) forControlEvents:UIControlEventTouchUpInside];
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.alpha = 0.0;
    cell.transform = CGAffineTransformMakeTranslation(0, 7);
    [UIView animateWithDuration:0.24 delay:MIN(indexPath.row * 0.03, 0.15) options:UIViewAnimationOptionCurveEaseOut animations:^{ cell.alpha = 1.0; cell.transform = CGAffineTransformIdentity; } completion:nil];
}

#pragma mark - Actions (preserved)

- (void)restoreTapped:(UIButton *)sender {
    NSDictionary *backup = self.backups[sender.tag];
    NSString *bundleID = backup[@"bundleID"];
    NSString *path = backup[@"path"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تأكيد الاستعادة" message:[NSString stringWithFormat:@"سيتم استبدال بيانات %@ بالنسخة المحددة. هل تريد المتابعة؟", backup[@"appName"]] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"استعادة" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showSpinner];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            BOOL success = [self.manager restoreAppData:bundleID fromBackup:path];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideSpinner];
                [self showToast:success ? @"تمت الاستعادة" : @"فشلت الاستعادة"];
            });
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)deleteTapped:(UIButton *)sender {
    NSDictionary *backup = self.backups[sender.tag];
    NSString *path = backup[@"path"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تأكيد الحذف" message:@"سيتم حذف هذه النسخة نهائياً." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"حذف" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self showSpinner];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            BOOL success = [self.manager deleteBackup:path];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideSpinner];
                if (success) [self loadBackups];
                [self showToast:success ? @"تم حذف النسخة" : @"فشل حذف النسخة"];
            });
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)addBackupTapped { [self showToast:@"انتقل إلى تبويب التطبيقات لإنشاء نسخة جديدة"]; }

- (void)showSpinner {
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.tag = 999;
    spinner.color = ADMAccent();
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:spinner];
    [NSLayoutConstraint activateConstraints:@[[spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor], [spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]]];
    [spinner startAnimating];
}

- (void)hideSpinner {
    UIActivityIndicatorView *spinner = [self.view viewWithTag:999];
    [spinner stopAnimating];
    [spinner removeFromSuperview];
}

- (void)showToast:(NSString *)message {
    UILabel *toast = [[UILabel alloc] init];
    toast.text = message;
    toast.textColor = ADMInk();
    toast.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.97];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    toast.layer.cornerRadius = 14;
    toast.layer.masksToBounds = YES;
    toast.numberOfLines = 0;
    CGSize size = [message boundingRectWithSize:CGSizeMake(self.view.bounds.size.width - 64, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: toast.font} context:nil].size;
    toast.frame = CGRectMake(0, 0, size.width + 34, size.height + 24);
    toast.center = CGPointMake(self.view.center.x, self.view.bounds.size.height - 118);
    toast.alpha = 0.0;
    [self.view addSubview:toast];
    [UIView animateWithDuration:0.2 animations:^{ toast.alpha = 1.0; } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.25 delay:2.2 options:UIViewAnimationOptionCurveEaseOut animations:^{ toast.alpha = 0.0; } completion:^(BOOL done) { [toast removeFromSuperview]; }];
    }];
}

@end
