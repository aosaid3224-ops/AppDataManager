#import "IPAUnpackViewController.h"
#import "Core/IPAArchiveExtractor.h"
#import "IPAArchiveBrowserViewController.h"

@interface IPAUnpackViewController () <UIDocumentPickerDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *items;
@end

@implementation IPAUnpackViewController

- (void)dealloc {
    for (NSDictionary *item in self.items) {
        if ([item[@"securityScopeActive"] boolValue]) {
            [item[@"url"] stopAccessingSecurityScopedResource];
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"فك حزمة IPA";
    self.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:1.0];
    self.items = [NSMutableArray array];
    [self setupNavigation];
    [self setupTableView];
    [self setupEmptyState];
}

- (void)setupNavigation {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addIPATapped:)];
    self.navigationItem.rightBarButtonItem.tintColor = UIColor.whiteColor;
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 84;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"IPAUnpackCell"];
    [self.view addSubview:self.tableView];
}

- (void)setupEmptyState {
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, self.view.bounds.size.height / 2 - 65, self.view.bounds.size.width - 48, 130)];
    self.emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.emptyLabel.text = @"لا توجد حزم IPA مضافة\nاضغط + لاختيار ملف خارجي";
    self.emptyLabel.textColor = [UIColor colorWithWhite:0.42 alpha:1.0];
    self.emptyLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 0;
    [self.view addSubview:self.emptyLabel];
}

- (void)addIPATapped:(id)sender {
    NSArray *types = @[@"com.apple.itunes.ipa", @"public.zip-archive"];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:types inMode:UIDocumentPickerModeOpen];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    for (NSURL *url in urls) {
        if (![url.pathExtension.lowercaseString isEqualToString:@"ipa"]) continue;
        BOOL accessed = [url startAccessingSecurityScopedResource];
        NSMutableDictionary *item = [@{
            @"url": url,
            @"name": url.lastPathComponent ?: @"IPA",
            @"status": @"جاهز للاستخراج",
            @"progress": @0.0,
            @"extracting": @NO,
        } mutableCopy];
        item[@"securityScopeActive"] = @(accessed);
        [self.items addObject:item];
    }
    self.emptyLabel.hidden = self.items.count > 0;
    [self.tableView reloadData];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
}

- (void)confirmExtractionForItem:(NSMutableDictionary *)item indexPath:(NSIndexPath *)indexPath {
    if ([item[@"extracting"] boolValue]) return;
    NSURL *url = item[@"url"];
    NSString *name = item[@"name"] ?: @"IPA";
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"فك حزمة IPA"
        message:[NSString stringWithFormat:@"هل تريد استخراج محتويات ملف IPA؟\n\n%@\n\nسيتم إنشاء مجلد جديد بجانب الملف الأصلي دون تعديل أو حذف ملف IPA.", name]
        preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"نعم، استخراج" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *outputPath = [[IPAArchiveExtractor sharedExtractor] uniqueOutputDirectoryForIPAPath:url.path];
        item[@"extracting"] = @YES;
        item[@"status"] = @"جارٍ التحقق والاستخراج...";
        item[@"progress"] = @0.0;
            [self reloadItem:item];

        __weak typeof(self) weakSelf = self;
        [[IPAArchiveExtractor sharedExtractor] extractIPAAtPath:url.path outputPath:outputPath progress:^(double progress, NSString *status) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            item[@"progress"] = @(progress);
            item[@"status"] = status ?: @"جارٍ العمل...";
            [strongSelf reloadItem:item];
        } completion:^(IPAArchiveExtractionResult *result) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            item[@"extracting"] = @NO;
            item[@"progress"] = result.success ? @1.0 : @0.0;
            item[@"status"] = result.success ? @"تم الاستخراج بالكامل" : (result.errorMessage.length ? result.errorMessage : @"فشل فك الحزمة");
            if (result.success) item[@"outputPath"] = result.outputPath ?: @"";
            [strongSelf.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            if (result.success) {
                UIAlertController *done = [UIAlertController alertControllerWithTitle:@"تم فك الحزمة"
                    message:[NSString stringWithFormat:@"تم استخراج كامل المحتوى إلى:\n%@\n\nعدد العناصر: %lu", result.outputPath, (unsigned long)result.extractedEntryCount]
                    preferredStyle:UIAlertControllerStyleAlert];
                [done addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleCancel handler:nil]];
                [done addAction:[UIAlertAction actionWithTitle:@"فتح المجلد" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    [strongSelf openOutputPath:result.outputPath];
                }]];
                [strongSelf presentViewController:done animated:YES completion:nil];
            } else {
                UIAlertController *failed = [UIAlertController alertControllerWithTitle:@"فشل فك الحزمة" message:result.errorMessage ?: @"تعذر استخراج الملف" preferredStyle:UIAlertControllerStyleAlert];
                [failed addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleDefault handler:nil]];
                [strongSelf presentViewController:failed animated:YES completion:nil];
            }
        }];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)reloadItem:(NSMutableDictionary *)item {
    NSUInteger index = [self.items indexOfObjectIdenticalTo:item];
    if (index == NSNotFound || index >= self.items.count) return;
    NSIndexPath *path = [NSIndexPath indexPathForRow:index inSection:0];
    [self.tableView reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)openOutputPath:(NSString *)path {
    if (path.length == 0) return;
    IPAArchiveBrowserViewController *browser = [[IPAArchiveBrowserViewController alloc] initWithRootPath:path];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:browser];
    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navigation animated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.items.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"IPAUnpackCell" forIndexPath:indexPath];
    NSDictionary *item = self.items[indexPath.row];
    BOOL extracting = [item[@"extracting"] boolValue];
    BOOL success = item[@"outputPath"] != nil;
    cell.textLabel.text = item[@"name"];
    cell.textLabel.textColor = UIColor.whiteColor;
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    double progress = [item[@"progress"] doubleValue];
    cell.detailTextLabel.text = extracting ? [NSString stringWithFormat:@"%@ %.0f%%", item[@"status"] ?: @"جارٍ العمل...", progress * 100.0] : item[@"status"];
    cell.detailTextLabel.textColor = success ? [UIColor colorWithRed:0.35 green:0.9 blue:0.55 alpha:1.0] : (extracting ? [UIColor colorWithRed:0.35 green:0.75 blue:1.0 alpha:1.0] : [UIColor colorWithWhite:0.55 alpha:1.0]);
    cell.detailTextLabel.numberOfLines = 2;
    cell.imageView.image = [[UIImage systemImageNamed:success ? @"folder.fill" : @"doc.zipper"] imageWithTintColor:success ? [UIColor colorWithRed:0.4 green:0.55 blue:0.95 alpha:1.0] : [UIColor colorWithRed:0.35 green:0.75 blue:0.55 alpha:1.0]];
    cell.accessoryType = success ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = extracting ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSMutableDictionary *item = self.items[indexPath.row];
    if ([item[@"extracting"] boolValue]) return;
    if (item[@"outputPath"] && [item[@"outputPath"] length] > 0) {
        [self openOutputPath:item[@"outputPath"]];
    } else {
        [self confirmExtractionForItem:item indexPath:indexPath];
    }
}

@end
