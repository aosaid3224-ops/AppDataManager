#import "PVSettingsViewController.h"
#import "PVChangePasswordsViewController.h"

@interface PVSettingsViewController ()
@property (nonatomic, strong) NSArray<NSDictionary *> *settingsSections;
@end

@implementation PVSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"الإعدادات";
    self.settingsSections = @[
        @{
            @"title": @"الأمان",
            @"items": @[
                @{ @"title": @"تغيير كلمات المرور", @"subtitle": @"تحديث كلمة المرور الأولى أو الثانية" }
            ]
        }
    ];
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.rowHeight = 58.0;
    self.tableView.cellLayoutMarginsFollowReadableWidth = YES;
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
    static NSString *identifier = @"PVSettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];

    NSDictionary *item = self.settingsSections[indexPath.section][@"items"][indexPath.row];
    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = item[@"subtitle"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 && indexPath.row == 0) {
        PVChangePasswordsViewController *controller = [[PVChangePasswordsViewController alloc] init];
        [self.navigationController pushViewController:controller animated:YES];
    }
}

@end
