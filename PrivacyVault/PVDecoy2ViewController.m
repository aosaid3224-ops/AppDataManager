#import "PVDecoy2ViewController.h"
#import "PVPassword2ViewController.h"
#import "PVVaultViewController.h"

@interface PVDecoy2ViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UILabel *detailsLabel;
@property (nonatomic, assign) NSUInteger tapCount;
@property (nonatomic, assign) BOOL openingAuthentication;
@end

@implementation PVDecoy2ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"النشاط";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.navigationItem.hidesBackButton = YES;

    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.backgroundColor = [UIColor clearColor];
    tableView.scrollEnabled = NO;
    [self.view addSubview:tableView];

    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 110.0)];
    UILabel *summary = [[UILabel alloc] initWithFrame:CGRectZero];
    summary.text = @"ملخص النشاط\nلا توجد إجراءات معلقة";
    summary.numberOfLines = 0;
    summary.textAlignment = NSTextAlignmentRight;
    summary.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle3];
    summary.textColor = [UIColor labelColor];
    summary.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:summary];
    [NSLayoutConstraint activateConstraints:@[
        [summary.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20.0],
        [summary.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20.0],
        [summary.topAnchor constraintEqualToAnchor:header.topAnchor constant:16.0],
        [summary.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-12.0]
    ]];

    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 92.0)];
    self.detailsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.detailsLabel.text = @"التفاصيل";
    self.detailsLabel.textAlignment = NSTextAlignmentRight;
    self.detailsLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.detailsLabel.textColor = [UIColor secondaryLabelColor];
    self.detailsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailsLabel.userInteractionEnabled = YES;
    [footer addSubview:self.detailsLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.detailsLabel.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:20.0],
        [self.detailsLabel.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor constant:-20.0],
        [self.detailsLabel.topAnchor constraintEqualToAnchor:footer.topAnchor constant:16.0],
        [self.detailsLabel.bottomAnchor constraintEqualToAnchor:footer.bottomAnchor constant:-16.0]
    ]];

    UITapGestureRecognizer *sevenTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSevenTaps:)];
    sevenTap.numberOfTapsRequired = 7;
    sevenTap.numberOfTouchesRequired = 1;
    [self.detailsLabel addGestureRecognizer:sevenTap];

    tableView.tableHeaderView = header;
    tableView.tableFooterView = footer;
    tableView.delegate = self;
    tableView.dataSource = self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.tapCount = 0;
    self.openingAuthentication = NO;
}

- (void)handleSevenTaps:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded || self.openingAuthentication) return;
    self.openingAuthentication = YES;
    PVPassword2ViewController *password2 = [[PVPassword2ViewController alloc] init];
    __weak UINavigationController *weakNavigationController = self.navigationController;
    password2.authenticationSuccess = ^{
        UINavigationController *navigationController = weakNavigationController;
        if (!navigationController) return;
        PVVaultViewController *vault = [[PVVaultViewController alloc] init];
        [navigationController pushViewController:vault animated:YES];
    };
    password2.authenticationFailure = ^{
        UINavigationController *navigationController = weakNavigationController;
        if (!navigationController) return;
        [navigationController popViewControllerAnimated:YES];
    };
    [self.navigationController pushViewController:password2 animated:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 2; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"PVActivityCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.textAlignment = NSTextAlignmentRight;
    cell.detailTextLabel.textAlignment = NSTextAlignmentLeft;
    if (indexPath.row == 0) {
        cell.textLabel.text = @"حالة الاتصال";
        cell.detailTextLabel.text = @"متصل";
        cell.imageView.image = [UIImage systemImageNamed:@"wifi"];
    } else {
        cell.textLabel.text = @"آخر مزامنة";
        cell.detailTextLabel.text = @"اليوم";
        cell.imageView.image = [UIImage systemImageNamed:@"arrow.clockwise"];
    }
    cell.imageView.tintColor = [UIColor secondaryLabelColor];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

@end
