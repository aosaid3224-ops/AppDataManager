#import "PVSettingsViewController.h"
#import "PVChangePasswordsViewController.h"

@interface PVSettingsViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) NSArray<NSDictionary *> *settingsSections;
@property (nonatomic, assign) BOOL openingPasswordSettings;
@end

@implementation PVSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"الإعدادات";
    self.settingsSections = @[
        @{
            @"title": @"عام",
            @"items": @[
                @{ @"title": @"حالة التطبيق", @"subtitle": @"يعمل بشكل طبيعي", @"kind": @"status" },
                @{ @"title": @"الإصدار", @"subtitle": [self applicationVersionText], @"kind": @"version" }
            ]
        },
        @{
            @"title": @"الدعم",
            @"items": @[
                @{ @"title": @"المساعدة", @"subtitle": @"معلومات وإرشادات الاستخدام", @"kind": @"help" }
            ]
        }
    ];
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.rowHeight = 58.0;
    self.tableView.cellLayoutMarginsFollowReadableWidth = YES;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
}

- (NSString *)applicationVersionText {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return version.length > 0 ? version : @"محدّث";
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.settingsSections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.settingsSections[section][@"items"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.settingsSections[section][@"title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.settingsSections[indexPath.section][@"items"][indexPath.row];
    NSString *kind = item[@"kind"];
    NSString *identifier = [NSString stringWithFormat:@"PVSettingsCell-%@", kind];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];

    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = item[@"subtitle"];
    cell.textLabel.textAlignment = NSTextAlignmentRight;
    cell.detailTextLabel.textAlignment = NSTextAlignmentRight;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.imageView.image = nil;
    cell.textLabel.textColor = [UIColor labelColor];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];

    if ([kind isEqualToString:@"status"]) {
        cell.imageView.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
        cell.imageView.tintColor = [UIColor systemGreenColor];
    } else if ([kind isEqualToString:@"version"]) {
        cell.imageView.image = [UIImage systemImageNamed:@"info.circle"];
        cell.imageView.tintColor = [UIColor secondaryLabelColor];
        cell.userInteractionEnabled = YES;
        for (UIGestureRecognizer *existingGesture in [cell.gestureRecognizers copy]) {
            [cell removeGestureRecognizer:existingGesture];
        }
        UITapGestureRecognizer *hiddenSettingsGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleHiddenSettingsGesture:)];
        hiddenSettingsGesture.numberOfTapsRequired = 5;
        hiddenSettingsGesture.numberOfTouchesRequired = 1;
        hiddenSettingsGesture.cancelsTouchesInView = NO;
        [cell addGestureRecognizer:hiddenSettingsGesture];
    } else {
        cell.imageView.image = [UIImage systemImageNamed:@"questionmark.circle"];
        cell.imageView.tintColor = [UIColor secondaryLabelColor];
    }
    return cell;
}

- (void)handleHiddenSettingsGesture:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded || self.openingPasswordSettings) return;
    self.openingPasswordSettings = YES;
    PVChangePasswordsViewController *controller = [[PVChangePasswordsViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.openingPasswordSettings = NO;
}

@end
