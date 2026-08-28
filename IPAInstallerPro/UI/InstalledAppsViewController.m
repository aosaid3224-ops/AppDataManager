//
//  InstalledAppsViewController.m
//  IPAInstallerPro
//

#import "InstalledAppsViewController.h"
#import "ApplicationManager.h"
#import "AppDetailsViewController.h"

@interface InstalledAppsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISegmentedControl *segmentControl;
@property (nonatomic, strong) NSArray<AppInfo *> *apps;
@property (nonatomic, strong) NSArray<AppInfo *> *filteredApps;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIButton *retryButton;
@end

@implementation InstalledAppsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:1.0];
    self.title = @"\u0627\u0644\u062a\u0637\u0628\u064a\u0642\u0627\u062a";

    [self setupSegmentControl];
    [self setupTableView];
    [self setupActivityIndicator];
    [self setupErrorUI];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(duplicateDidComplete:) name:@"IPAInstallerProDuplicateDidComplete" object:nil];
    [self loadApps];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"IPAInstallerProDuplicateDidComplete" object:nil];
}

- (void)duplicateDidComplete:(NSNotification *)note {
    if (![note.userInfo[@"success"] boolValue]) return;
    [self loadApps];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadApps];
}

- (void)setupSegmentControl {
    _segmentControl = [[UISegmentedControl alloc] initWithItems:@[@"\u0627\u0644\u0643\u0644", @"\u0645\u0633\u062a\u062e\u062f\u0645", @"\u0646\u0638\u0627\u0645"]];
    _segmentControl.translatesAutoresizingMaskIntoConstraints = NO;
    _segmentControl.selectedSegmentIndex = 0;
    _segmentControl.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    _segmentControl.selectedSegmentTintColor = [UIColor colorWithWhite:0.25 alpha:1.0];
    [_segmentControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateNormal];
    [_segmentControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_segmentControl];

    [NSLayoutConstraint activateConstraints:@[
        [_segmentControl.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [_segmentControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [_segmentControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [_segmentControl.heightAnchor constraintEqualToConstant:36]
    ]];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 72;
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"AppCell"];
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:_segmentControl.bottomAnchor constant:12],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupActivityIndicator {
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    _activityIndicator.color = [UIColor colorWithWhite:0.5 alpha:1.0];
    _activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:_activityIndicator];

    [NSLayoutConstraint activateConstraints:@[
        [_activityIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_activityIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)setupErrorUI {
    _errorLabel = [[UILabel alloc] init];
    _errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _errorLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    _errorLabel.textColor = [UIColor colorWithRed:0.8 green:0.3 blue:0.3 alpha:1.0];
    _errorLabel.textAlignment = NSTextAlignmentCenter;
    _errorLabel.numberOfLines = 0;
    _errorLabel.hidden = YES;
    [self.view addSubview:_errorLabel];

    _retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _retryButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_retryButton setTitle:@"\u0625\u0639\u0627\u062f\u0629 \u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629" forState:UIControlStateNormal];
    _retryButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [_retryButton setTitleColor:[UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    [_retryButton addTarget:self action:@selector(loadApps) forControlEvents:UIControlEventTouchUpInside];
    _retryButton.hidden = YES;
    [self.view addSubview:_retryButton];

    [NSLayoutConstraint activateConstraints:@[
        [_errorLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_errorLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-30],
        [_errorLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [_errorLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],

        [_retryButton.topAnchor constraintEqualToAnchor:_errorLabel.bottomAnchor constant:16],
        [_retryButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
    ]];
}

- (void)loadApps {
    [self.activityIndicator startAnimating];
    self.tableView.hidden = YES;
    self.errorLabel.hidden = YES;
    self.retryButton.hidden = YES;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray<AppInfo *> *apps = nil;
        NSString *errorMsg = nil;

        @try {
            apps = [[ApplicationManager sharedManager] allInstalledApplications];
        } @catch (NSException *e) {
            errorMsg = [NSString stringWithFormat:@"\u062e\u0637\u0623: %@", e.reason ?: @"\u063a\u064a\u0631 \u0645\u0639\u0631\u0648\u0641"];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicator stopAnimating];

            if (errorMsg) {
                self.errorLabel.text = errorMsg;
                self.errorLabel.hidden = NO;
                self.retryButton.hidden = NO;
                self.tableView.hidden = YES;
                return;
            }

            if (!apps || apps.count == 0) {
                self.errorLabel.text = @"\u0644\u0627 \u062a\u0648\u062c\u062f \u062a\u0637\u0628\u064a\u0642\u0627\u062a \u0645\u062b\u0628\u062a\u0629";
                self.errorLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
                self.errorLabel.hidden = NO;
                self.retryButton.hidden = NO;
                self.tableView.hidden = YES;
                return;
            }

            self.apps = apps;
            [self filterApps];
            self.tableView.hidden = NO;
            [self.tableView reloadData];
        });
    });
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    [self filterApps];
    [self.tableView reloadData];
}

- (void)filterApps {
    if (self.segmentControl.selectedSegmentIndex == 0) {
        self.filteredApps = self.apps;
    } else if (self.segmentControl.selectedSegmentIndex == 1) {
        self.filteredApps = [self.apps filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isSystemApp == NO"]];
    } else {
        self.filteredApps = [self.apps filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isSystemApp == YES"]];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredApps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AppCell" forIndexPath:indexPath];
    AppInfo *app = self.filteredApps[indexPath.row];

    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    cell.textLabel.text = app.name;
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];

    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ \u2022 %@", app.bundleID, app.version];
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];

    if (app.icon) {
        cell.imageView.image = app.icon;
    } else {
        cell.imageView.image = [self placeholderIcon];
    }
    cell.imageView.layer.cornerRadius = 10;
    cell.imageView.clipsToBounds = YES;

    return cell;
}

- (UIImage *)placeholderIcon {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(44, 44), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.15 alpha:1.0].CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, 44, 44));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    AppInfo *app = self.filteredApps[indexPath.row];
    AppDetailsViewController *detail = [[AppDetailsViewController alloc] initWithAppInfo:app];
    [self.navigationController pushViewController:detail animated:YES];
}

@end
