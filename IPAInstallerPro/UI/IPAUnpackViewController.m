#import "IPAUnpackViewController.h"
#import "Core/IPAArchiveExtractor.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "IPAArchiveBrowserViewController.h"

@interface IPAUnpackViewController () <UIDocumentPickerDelegate, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *items;
@property (nonatomic, strong) IPAArchiveExtractionTask *activeTask;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, assign) BOOL sortByDate;
@property (nonatomic, assign) BOOL restoringItems;
@end

static NSString * const kIPAExtractorPersistedItemsKey = @"IPAExtractor.PersistedItems.v1";

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
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.navigationController.navigationBar.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.items = [NSMutableArray array];
    [self restorePersistedItems];
    [self setupNavigation];
    [self setupTableView];
    [self setupEmptyState];
}

- (NSURL *)urlForItem:(NSDictionary *)item {
    id value = item[@"url"];
    return [value isKindOfClass:NSURL.class] ? value : nil;
}

- (NSString *)sourcePathForItem:(NSDictionary *)item {
    return item[@"originalPath"] ?: [self urlForItem:item].path;
}

- (void)persistItems {
    NSMutableArray *records = [NSMutableArray arrayWithCapacity:self.items.count];
    for (NSDictionary *item in self.items) {
        NSMutableDictionary *record = [NSMutableDictionary dictionary];
        NSString *originalPath = [self sourcePathForItem:item];
        if (originalPath.length > 0) record[@"originalPath"] = originalPath;
        NSData *bookmark = item[@"bookmarkData"];
        if (bookmark.length > 0) record[@"bookmarkData"] = bookmark;
        for (NSString *key in @[@"displayName", @"name", @"status", @"outputPath", @"state", @"addedAt", @"updatedAt"]) {
            id value = item[key];
            if (value) record[key] = value;
        }
        record[@"unavailable"] = @([item[@"unavailable"] boolValue]);
        [records addObject:record];
    }
    [[NSUserDefaults standardUserDefaults] setObject:records forKey:kIPAExtractorPersistedItemsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSURL *)resolvePersistedURLForRecord:(NSDictionary *)record {
    NSData *bookmark = record[@"bookmarkData"];
    BOOL stale = NO;
    NSError *bookmarkError = nil;
    NSURL *url = bookmark.length > 0 ? [NSURL URLByResolvingBookmarkData:bookmark options:0 relativeToURL:nil bookmarkDataIsStale:&stale error:&bookmarkError] : nil;
    NSString *path = record[@"originalPath"];
    if (!url && path.length > 0) url = [NSURL fileURLWithPath:path];
    if (url && ![[NSFileManager defaultManager] fileExistsAtPath:url.path]) return nil;
    if (url && ![url.path.pathExtension.lowercaseString isEqualToString:@"ipa"]) return nil;
    return url;
}

- (void)restorePersistedItems {
    self.restoringItems = YES;
    NSArray<NSDictionary *> *records = [[NSUserDefaults standardUserDefaults] arrayForKey:kIPAExtractorPersistedItemsKey];
    for (NSDictionary *record in records) {
        if (![record isKindOfClass:NSDictionary.class]) continue;
        NSURL *url = [self resolvePersistedURLForRecord:record];
        NSString *originalPath = record[@"originalPath"] ?: url.path;
        if (originalPath.length == 0) continue;
        NSMutableDictionary *item = [@{
            @"url": url ?: [NSNull null],
            @"originalPath": originalPath,
            @"name": record[@"name"] ?: [originalPath lastPathComponent],
            @"displayName": record[@"displayName"] ?: [[originalPath lastPathComponent] stringByDeletingPathExtension],
            @"status": record[@"status"] ?: (url ? @"جاهز" : @"غير متاح"),
            @"state": record[@"state"] ?: (url ? @"ready" : @"unavailable"),
            @"progress": @0.0,
            @"extracting": @NO,
            @"unavailable": @(!url),
            @"outputPath": record[@"outputPath"] ?: @"",
            @"addedAt": record[@"addedAt"] ?: [NSDate date],
            @"updatedAt": record[@"updatedAt"] ?: [NSDate date]
        } mutableCopy];
        if (record[@"bookmarkData"]) item[@"bookmarkData"] = record[@"bookmarkData"];
        if (url) item[@"securityScopeActive"] = @([url startAccessingSecurityScopedResource]);
        [self.items addObject:item];
    }
    self.restoringItems = NO;
}

- (void)setupNavigation {
    UIBarButtonItem *add = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addIPATapped:)];
    UIBarButtonItem *sort = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.up.arrow.down"] style:UIBarButtonItemStylePlain target:self action:@selector(toggleSort:)];
    self.navigationItem.rightBarButtonItems = @[add, sort];
    for (UIBarButtonItem *item in self.navigationItem.rightBarButtonItems) item.tintColor = UIColor.whiteColor;
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"بحث في حزم IPA...";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 84;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"IPAUnpackCell"];
    [self.view addSubview:self.tableView];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self persistItems];
}

- (NSString *)rtlText:(NSString *)text {
    return [NSString stringWithFormat:@"\u2067%@\u2069", text ?: @""];
}

- (NSString *)ltrText:(NSString *)text {
    return [NSString stringWithFormat:@"\u2066%@\u2069", text ?: @""];
}

- (void)setupEmptyState {
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, self.view.bounds.size.height / 2 - 65, self.view.bounds.size.width - 48, 130)];
    self.emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.emptyLabel.text = @"لا توجد حزم IPA مضافة\nاضغط + لاختيار ملف خارجي";
    self.emptyLabel.textColor = [UIColor colorWithWhite:0.42 alpha:1.0];
    self.emptyLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.hidden = self.items.count > 0;
    [self.view addSubview:self.emptyLabel];
}

- (void)addIPATapped:(id)sender {
    UTType *appleIPAType = [UTType typeWithIdentifier:@"com.apple.itunes.ipa"];
    UTType *localIPAType = [UTType typeWithIdentifier:@"com.aosaid.ipainstallerpro.ipa"];
    UTType *extensionIPAType = [UTType typeWithFilenameExtension:@"ipa"];
    NSMutableArray<UTType *> *ipaTypes = [NSMutableArray array];
    for (UTType *type in @[appleIPAType ?: [NSNull null], localIPAType ?: [NSNull null], extensionIPAType ?: [NSNull null]]) {
        if (![type isKindOfClass:UTType.class] || [ipaTypes containsObject:type]) continue;
        [ipaTypes addObject:type];
    }
    if (ipaTypes.count == 0) {
        [self showMessage:@"تعذر تسجيل نوع IPA على هذا النظام."];
        return;
    }
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:ipaTypes asCopy:NO];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSUInteger added = 0;
    for (NSURL *url in urls) {
        if (!url.isFileURL || ![url.pathExtension.lowercaseString isEqualToString:@"ipa"]) continue;
        BOOL duplicate = NO;
        for (NSDictionary *existing in self.items) {
            if ([existing[@"url"] isEqual:url]) { duplicate = YES; break; }
        }
        if (duplicate) continue;
        BOOL accessed = [url startAccessingSecurityScopedResource];
        NSData *bookmark = [url bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
        NSMutableDictionary *item = [@{
            @"url": url,
            @"name": url.lastPathComponent ?: @"IPA",
            @"displayName": [url.lastPathComponent stringByDeletingPathExtension] ?: @"IPA",
            @"status": @"جاهز",
            @"progress": @0.0,
            @"extracting": @NO,
            @"securityScopeActive": @(accessed),
            @"bookmarkData": bookmark ?: [NSData data],
            @"originalPath": url.path ?: @"",
            @"state": @"ready",
            @"unavailable": @NO,
            @"addedAt": [NSDate date],
            @"updatedAt": [NSDate date],
        } mutableCopy];
        [self.items addObject:item];
        added++;
    }
    if (added > 0) [self persistItems];
    self.emptyLabel.hidden = self.items.count > 0;
    [self.tableView reloadData];
    if (added == 0 && urls.count > 0) [self showMessage:@"لم يتم قبول أي ملف؛ يجب أن يكون الامتداد .ipa."];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
}

- (NSArray<NSDictionary *> *)displayRows {
    NSString *query = self.searchController.searchBar.text.lowercaseString ?: @"";
    NSArray *visibleItems = [self.items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, NSDictionary *bindings) {
        if (query.length == 0) return YES;
        NSString *name = [item[@"displayName"] ?: item[@"name"] ?: @"" lowercaseString];
        return [name containsString:query];
    }]];
    visibleItems = [visibleItems sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        if (self.sortByDate) {
            NSDate *aDate = [[[NSFileManager defaultManager] attributesOfItemAtPath:[self sourcePathForItem:a] error:nil] objectForKey:NSFileModificationDate];
            NSDate *bDate = [[[NSFileManager defaultManager] attributesOfItemAtPath:[self sourcePathForItem:b] error:nil] objectForKey:NSFileModificationDate];
            return [bDate compare:aDate];
        }
        return [[a[@"displayName"] ?: a[@"name"] ?: @"" description] localizedCaseInsensitiveCompare:[b[@"displayName"] ?: b[@"name"] ?: @"" description]];
    }];
    NSMutableArray *rows = [NSMutableArray array];
    for (NSMutableDictionary *item in visibleItems) {
        [rows addObject:@{ @"kind": @"source", @"item": item }];
        NSString *output = item[@"outputPath"];
        if (output.length > 0) {
            [rows addObject:@{ @"kind": @"output", @"item": item }];
        }
    }
    return rows;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self.tableView reloadData];
}

- (void)toggleSort:(id)sender {
    self.sortByDate = !self.sortByDate;
    [self.tableView reloadData];
}

- (NSDictionary *)rowDescriptorAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *rows = [self displayRows];
    return indexPath.row < rows.count ? rows[indexPath.row] : nil;
}

- (void)confirmExtractionForItem:(NSMutableDictionary *)item indexPath:(NSIndexPath *)indexPath {
    if ([item[@"extracting"] boolValue] || self.activeTask) return;
    NSURL *url = item[@"url"];
    NSString *name = item[@"displayName"] ?: item[@"name"] ?: @"IPA";
    BOOL hasPreviousOutput = [item[@"outputPath"] length] > 0;
    NSString *message = hasPreviousOutput
        ? [NSString stringWithFormat:@"سيتم إنشاء ناتج جديد بجانب الملف الأصلي، مع إبقاء الناتج السابق دون تغيير.\n\n%@", name]
        : [NSString stringWithFormat:@"سيتم إنشاء مجلد جديد بجانب الملف الأصلي دون تعديل أو حذف ملف IPA.\n\n%@", name];
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:hasPreviousOutput ? @"إعادة استخراج IPA" : @"فك حزمة IPA" message:message preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"نعم، استخراج" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *outputPath = [[IPAArchiveExtractor sharedExtractor] uniqueOutputDirectoryForIPAPath:url.path];
        item[@"extracting"] = @YES;
        item[@"state"] = @"extracting";
        item[@"status"] = @"جارٍ التحقق والاستخراج...";
        item[@"progress"] = @0.0;
        [self reloadItem:item];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"إلغاء" style:UIBarButtonItemStylePlain target:self action:@selector(cancelActiveExtraction:)];
        __weak typeof(self) weakSelf = self;
        self.activeTask = [[IPAArchiveExtractor sharedExtractor] extractIPAAtPath:url.path outputPath:outputPath progress:^(double progress, NSString *status) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            item[@"progress"] = @(progress);
            item[@"status"] = status ?: @"جارٍ العمل...";
            [strongSelf reloadItem:item];
        } completion:^(IPAArchiveExtractionResult *result) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            item[@"extracting"] = @NO;
            strongSelf.activeTask = nil;
            strongSelf.navigationItem.leftBarButtonItem = nil;
            item[@"progress"] = result.success ? @1.0 : @0.0;
            item[@"state"] = result.success ? @"success" : (result.cancelled ? @"cancelled" : @"failed");
            item[@"status"] = result.success ? @"نجح الاستخراج" : (result.cancelled ? @"أُلغي" : (result.errorMessage.length ? result.errorMessage : @"فشل فك الحزمة"));
            if (result.success) item[@"outputPath"] = result.outputPath ?: @"";
            [strongSelf reloadItem:item];
            if (result.success) {
                UIAlertController *done = [UIAlertController alertControllerWithTitle:@"تم فك الحزمة" message:[NSString stringWithFormat:@"تم استخراج كامل المحتوى إلى:\n%@\n\nعدد العناصر: %lu", [strongSelf ltrText:result.outputPath], (unsigned long)result.extractedEntryCount] preferredStyle:UIAlertControllerStyleAlert];
                [done addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleCancel handler:nil]];
                [done addAction:[UIAlertAction actionWithTitle:@"فتح المجلد" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [strongSelf openOutputPath:result.outputPath]; }]];
                [strongSelf presentViewController:done animated:YES completion:nil];
            } else if (result.cancelled) {
                UIAlertController *cancelled = [UIAlertController alertControllerWithTitle:@"تم إلغاء الاستخراج" message:@"تم تنظيف الحالة المؤقتة ولم يتم اعتماد مجلد ناقص كناتج." preferredStyle:UIAlertControllerStyleAlert];
                [cancelled addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleDefault handler:nil]];
                [strongSelf presentViewController:cancelled animated:YES completion:nil];
            } else {
                UIAlertController *failed = [UIAlertController alertControllerWithTitle:@"فشل فك الحزمة" message:result.errorMessage ?: @"تعذر استخراج الملف" preferredStyle:UIAlertControllerStyleAlert];
                [failed addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleDefault handler:nil]];
                [strongSelf presentViewController:failed animated:YES completion:nil];
            }
        }];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)cancelActiveExtraction:(id)sender {
    if (!self.activeTask) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إلغاء الاستخراج" message:@"هل تريد إلغاء العملية؟ سيتم تنظيف الملفات المؤقتة ولن يتغير ملف IPA الأصلي." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"متابعة" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء العملية" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) { [self.activeTask cancel]; }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)reloadItem:(NSMutableDictionary *)item {
    item[@"updatedAt"] = [NSDate date];
    [self persistItems];
    self.emptyLabel.hidden = self.items.count > 0;
    [self.tableView reloadData];
}

- (void)openOutputPath:(NSString *)path {
    if (path.length == 0) return;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [self showMessage:@"الناتج غير متاح؛ قد يكون المجلد قد نُقل أو حُذف خارج Spider."];
        return;
    }
    IPAArchiveBrowserViewController *browser = [[IPAArchiveBrowserViewController alloc] initWithRootPath:path];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:browser];
    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navigation animated:YES completion:nil];
}

- (void)sharePath:(NSString *)path {
    if (path.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [self showMessage:@"الملف أو المجلد غير متاح للمشاركة."];
        return;
    }
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    activity.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)savePathToFiles:(NSString *)path {
    if (path.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [self showMessage:@"الناتج غير متاح للحفظ في الملفات."];
        return;
    }
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[[NSURL fileURLWithPath:path]] asCopy:YES];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)showInfoForPath:(NSString *)path title:(NSString *)title {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    BOOL isDirectory = [attrs[NSFileType] isEqualToString:NSFileTypeDirectory];
    NSString *message = [NSString stringWithFormat:@"المسار:\n%@\n\nالنوع: %@\nالحجم: %@\nالتاريخ: %@", [self ltrText:path], isDirectory ? @"مجلد" : @"ملف", [self formattedSize:[attrs[NSFileSize] unsignedLongLongValue]], [self formattedDate:attrs[NSFileModificationDate]]];
    [self showAlertWithTitle:title ?: @"معلومات الملف" message:message];
}

- (void)renameDisplayNameForItem:(NSMutableDictionary *)item {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إعادة تسمية العرض" message:@"سيتم تغيير الاسم الظاهر داخل Spider فقط، ولن يتغير اسم الملف الحقيقي." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.text = item[@"displayName"] ?: item[@"name"]; field.clearButtonMode = UITextFieldViewModeWhileEditing; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"حفظ" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { NSString *value = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; if (value.length > 0) { item[@"displayName"] = value; [self reloadItem:item]; } }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)renameOutputForItem:(NSMutableDictionary *)item {
    NSString *oldPath = item[@"outputPath"];
    if (oldPath.length == 0) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إعادة تسمية الناتج" message:@"سيتم تغيير اسم مجلد الاستخراج الحقيقي فقط، ولن يتغير ملف IPA الأصلي." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = oldPath.lastPathComponent;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"حفظ" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length == 0 || [name containsString:@"/"] || [name containsString:@"\\"] || [name isEqualToString:@"."] || [name isEqualToString:@".."] || [name containsString:@":"]) {
            [self showMessage:@"اسم المجلد غير صالح."];
            return;
        }
        NSString *newPath = [[oldPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:name];
        if ([[NSFileManager defaultManager] fileExistsAtPath:newPath]) {
            [self showMessage:@"يوجد مجلد بهذا الاسم؛ اختر اسمًا آخر."];
            return;
        }
        NSError *error = nil;
        if (![[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:&error]) {
            [self showMessage:error.localizedDescription ?: @"تعذر إعادة تسمية الناتج."];
            return;
        }
        item[@"outputPath"] = newPath;
        item[@"state"] = @"success";
        [self reloadItem:item];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)removeSourceFromList:(NSMutableDictionary *)item {
    if ([item[@"securityScopeActive"] boolValue]) [item[@"url"] stopAccessingSecurityScopedResource];
    [self.items removeObjectIdenticalTo:item];
    [self persistItems];
    self.emptyLabel.hidden = self.items.count > 0;
    [self.tableView reloadData];
}

- (void)deleteOutputForItem:(NSMutableDictionary *)item {
    NSString *path = item[@"outputPath"];
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"حذف الناتج" message:@"سيُحذف مجلد الاستخراج فقط، ولن يُحذف ملف IPA الأصلي ولن يُزال المصدر من القائمة." preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"حذف الناتج" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) { NSError *error = nil; if ([[NSFileManager defaultManager] fileExistsAtPath:path] && ![[NSFileManager defaultManager] removeItemAtPath:path error:&error]) { [self showMessage:error.localizedDescription ?: @"تعذر حذف الناتج"]; return; }         [item removeObjectForKey:@"outputPath"]; item[@"state"] = @"ready"; item[@"status"] = @"جاهز لإعادة الاستخراج"; [self reloadItem:item]; }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (NSString *)formattedSize:(unsigned long long)bytes {
    if (bytes < 1024) return [NSString stringWithFormat:@"%llu B", bytes];
    if (bytes < 1024 * 1024) return [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
    if (bytes < 1024ULL * 1024ULL * 1024ULL) return [NSString stringWithFormat:@"%.1f MB", bytes / (1024.0 * 1024.0)];
    return [NSString stringWithFormat:@"%.2f GB", bytes / (1024.0 * 1024.0 * 1024.0)];
}

- (NSString *)formattedDate:(NSDate *)date {
    if (!date) return @"غير معروف";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"ar"];
    return [formatter stringFromDate:date];
}

- (void)showMessage:(NSString *)message { [self showAlertWithTitle:@"فك حزمة IPA" message:message]; }

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    alert.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [alert addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentActionsForDescriptor:(NSDictionary *)descriptor fromButton:(UIButton *)button {
    if (!descriptor) return;
    BOOL isOutput = [descriptor[@"kind"] isEqualToString:@"output"];
    NSMutableDictionary *item = descriptor[@"item"];
    NSString *title = isOutput ? @"إجراءات المجلد المستخرج" : @"إجراءات ملف IPA";
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    sheet.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    __weak typeof(self) weakSelf = self;
    void (^add)(NSString *, UIAlertActionStyle, dispatch_block_t) = ^(NSString *name, UIAlertActionStyle style, dispatch_block_t block) {
        [sheet addAction:[UIAlertAction actionWithTitle:name style:style handler:^(UIAlertAction *action) {
            __strong typeof(weakSelf) self = weakSelf;
            if (self && block) block();
        }]];
    };
    if (isOutput) {
        add(@"فتح", UIAlertActionStyleDefault, ^{ [weakSelf openOutputPath:item[@"outputPath"]]; });
        add(@"حفظ في الملفات", UIAlertActionStyleDefault, ^{ [weakSelf savePathToFiles:item[@"outputPath"]]; });
        add(@"مشاركة", UIAlertActionStyleDefault, ^{ [weakSelf sharePath:item[@"outputPath"]]; });
        add(@"إعادة تسمية", UIAlertActionStyleDefault, ^{ [weakSelf renameOutputForItem:item]; });
        add(@"نسخ المسار", UIAlertActionStyleDefault, ^{ [UIPasteboard generalPasteboard].string = item[@"outputPath"]; [weakSelf showMessage:@"تم نسخ المسار."]; });
        add(@"معلومات الملف", UIAlertActionStyleDefault, ^{ [weakSelf showInfoForPath:item[@"outputPath"] title:@"معلومات الناتج"]; });
        add(@"حذف الناتج", UIAlertActionStyleDestructive, ^{ [weakSelf deleteOutputForItem:item]; });
    } else {
        BOOL available = ![item[@"unavailable"] boolValue] && [self urlForItem:item] != nil;
        NSString *extractTitle = [item[@"outputPath"] length] > 0 ? @"إعادة استخراج" : @"استخراج";
        UIAlertAction *extract = [UIAlertAction actionWithTitle:extractTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [weakSelf confirmExtractionForItem:item indexPath:nil]; }];
        extract.enabled = available && !self.activeTask;
        [sheet addAction:extract];
        add(@"مشاركة", UIAlertActionStyleDefault, ^{ [weakSelf sharePath:[weakSelf sourcePathForItem:item]]; });
        add(@"فتح في الملفات", UIAlertActionStyleDefault, ^{ [weakSelf sharePath:[weakSelf sourcePathForItem:item]]; });
        add(@"إعادة تسمية العرض", UIAlertActionStyleDefault, ^{ [weakSelf renameDisplayNameForItem:item]; });
        add(@"معلومات الملف", UIAlertActionStyleDefault, ^{ [weakSelf showInfoForPath:[weakSelf sourcePathForItem:item] title:@"معلومات IPA"]; });
        add(@"إزالة من القائمة", UIAlertActionStyleDestructive, ^{ [weakSelf removeSourceFromList:item]; });
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = button ?: self.view;
        sheet.popoverPresentationController.sourceRect = button ? button.bounds : self.view.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)moreTapped:(UIButton *)button {
    NSDictionary *descriptor = [self rowDescriptorAtIndexPath:[NSIndexPath indexPathForRow:button.tag inSection:0]];
    [self presentActionsForDescriptor:descriptor fromButton:button];
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
    NSDictionary *descriptor = [self rowDescriptorAtIndexPath:indexPath];
    if (!descriptor) return nil;
    NSString *kind = descriptor[@"kind"];
    NSMutableDictionary *item = descriptor[@"item"];
    BOOL isOutput = [kind isEqualToString:@"output"];
    __weak typeof(self) weakSelf = self;
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return nil;
        NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];
        if (isOutput) {
            [actions addObject:[UIAction actionWithTitle:@"فتح" image:[UIImage systemImageNamed:@"folder"] identifier:nil handler:^(__kindof UIAction *action) { [self openOutputPath:item[@"outputPath"]]; }]];
            [actions addObject:[UIAction actionWithTitle:@"حفظ في الملفات" image:[UIImage systemImageNamed:@"square.and.arrow.down"] identifier:nil handler:^(__kindof UIAction *action) { [self savePathToFiles:item[@"outputPath"]]; }]];
            [actions addObject:[UIAction actionWithTitle:@"مشاركة" image:[UIImage systemImageNamed:@"square.and.arrow.up"] identifier:nil handler:^(__kindof UIAction *action) { [self sharePath:item[@"outputPath"]]; }]];
            [actions addObject:[UIAction actionWithTitle:@"إعادة تسمية" image:[UIImage systemImageNamed:@"pencil"] identifier:nil handler:^(__kindof UIAction *action) { [self renameOutputForItem:item]; }]];
            [actions addObject:[UIAction actionWithTitle:@"نسخ المسار" image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:nil handler:^(__kindof UIAction *action) { [UIPasteboard generalPasteboard].string = item[@"outputPath"]; [self showMessage:@"تم نسخ المسار."]; }]];
            [actions addObject:[UIAction actionWithTitle:@"معلومات الملف" image:[UIImage systemImageNamed:@"info.circle"] identifier:nil handler:^(__kindof UIAction *action) { [self showInfoForPath:item[@"outputPath"] title:@"معلومات الناتج"]; }]];
            [actions addObject:[UIAction actionWithTitle:@"حذف الناتج" image:[UIImage systemImageNamed:@"trash"] identifier:nil handler:^(__kindof UIAction *action) { [self deleteOutputForItem:item]; }]];
        } else {
            NSString *extractTitle = [item[@"outputPath"] length] > 0 ? @"إعادة استخراج" : @"استخراج";
            [actions addObject:[UIAction actionWithTitle:extractTitle image:[UIImage systemImageNamed:@"archivebox"] identifier:nil handler:^(__kindof UIAction *action) { [self confirmExtractionForItem:item indexPath:indexPath]; }]];
            [actions addObject:[UIAction actionWithTitle:@"مشاركة" image:[UIImage systemImageNamed:@"square.and.arrow.up"] identifier:nil handler:^(__kindof UIAction *action) { [self sharePath:[self sourcePathForItem:item]]; }]];
            [actions addObject:[UIAction actionWithTitle:@"فتح في الملفات" image:[UIImage systemImageNamed:@"folder"] identifier:nil handler:^(__kindof UIAction *action) { [self sharePath:[self sourcePathForItem:item]]; }]];
            [actions addObject:[UIAction actionWithTitle:@"إعادة تسمية العرض" image:[UIImage systemImageNamed:@"pencil"] identifier:nil handler:^(__kindof UIAction *action) { [self renameDisplayNameForItem:item]; }]];
            [actions addObject:[UIAction actionWithTitle:@"معلومات الملف" image:[UIImage systemImageNamed:@"info.circle"] identifier:nil handler:^(__kindof UIAction *action) { [self showInfoForPath:[self sourcePathForItem:item] title:@"معلومات IPA"]; }]];
            [actions addObject:[UIAction actionWithTitle:@"إزالة من القائمة" image:[UIImage systemImageNamed:@"minus.circle"] identifier:nil handler:^(__kindof UIAction *action) { [self removeSourceFromList:item]; }]];
        }
        return [UIMenu menuWithTitle:@"إجراءات" children:actions];
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self displayRows].count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"IPAUnpackCell" forIndexPath:indexPath];
    NSDictionary *descriptor = [self rowDescriptorAtIndexPath:indexPath];
    NSString *kind = descriptor[@"kind"];
    NSMutableDictionary *item = descriptor[@"item"];
    BOOL output = [kind isEqualToString:@"output"];
    cell.indentationLevel = output ? 1 : 0;
    NSString *sourceTitle = item[@"displayName"] ?: item[@"name"] ?: @"IPA";
    cell.textLabel.text = output ? [NSString stringWithFormat:@"↳ %@ — Extracted", sourceTitle] : [NSString stringWithFormat:@"%@.ipa", sourceTitle];
    cell.textLabel.textColor = UIColor.whiteColor;
    cell.textLabel.textAlignment = NSTextAlignmentRight;
    cell.textLabel.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:output ? UIFontWeightMedium : UIFontWeightSemibold];
    if (output) {
        BOOL outputAvailable = [[NSFileManager defaultManager] fileExistsAtPath:item[@"outputPath"]];
        NSDictionary *attrs = outputAvailable ? [[NSFileManager defaultManager] attributesOfItemAtPath:item[@"outputPath"] error:nil] : @{};
        cell.detailTextLabel.text = outputAvailable ? [NSString stringWithFormat:@"مستخرج • %@ • %@", [self formattedSize:[attrs[NSFileSize] unsignedLongLongValue]], [self formattedDate:attrs[NSFileModificationDate]]] : @"الناتج غير متاح";
        cell.detailTextLabel.textColor = outputAvailable ? [UIColor colorWithRed:0.35 green:0.9 blue:0.55 alpha:1.0] : [UIColor colorWithRed:0.95 green:0.65 blue:0.25 alpha:1.0];
        cell.detailTextLabel.textAlignment = NSTextAlignmentRight;
        cell.detailTextLabel.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        cell.imageView.image = [[UIImage systemImageNamed:@"folder.fill"] imageWithTintColor:[UIColor colorWithRed:0.4 green:0.55 blue:0.95 alpha:1.0]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        BOOL extracting = [item[@"extracting"] boolValue];
        BOOL unavailable = [item[@"unavailable"] boolValue];
        double progress = [item[@"progress"] doubleValue];
        NSString *status = item[@"status"] ?: @"جاهز";
        cell.detailTextLabel.text = extracting ? [NSString stringWithFormat:@"%@ %.0f%%", status, progress * 100.0] : (unavailable ? @"غير متاح — الملف الأصلي غير موجود" : [NSString stringWithFormat:@"%@ • %@", status, item[@"name"] ?: @""]);
        cell.detailTextLabel.textColor = extracting ? [UIColor colorWithRed:0.35 green:0.75 blue:1.0 alpha:1.0] : (unavailable ? [UIColor colorWithRed:0.95 green:0.65 blue:0.25 alpha:1.0] : [UIColor colorWithWhite:0.55 alpha:1.0]);
        cell.detailTextLabel.textAlignment = NSTextAlignmentRight;
        cell.detailTextLabel.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        cell.imageView.image = [[UIImage systemImageNamed:@"doc.zipper"] imageWithTintColor:[UIColor colorWithRed:0.35 green:0.75 blue:0.55 alpha:1.0]];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = extracting ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
    }
    cell.detailTextLabel.numberOfLines = 2;
    UIButton *more = [UIButton buttonWithType:UIButtonTypeSystem];
    more.tag = indexPath.row;
    more.frame = CGRectMake(0, 0, 44, 44);
    [more setTitle:@"•••" forState:UIControlStateNormal];
    more.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    more.tintColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    more.accessibilityLabel = @"إجراءات العنصر";
    more.accessibilityHint = @"فتح قائمة الإجراءات";
    [more addTarget:self action:@selector(moreTapped:) forControlEvents:UIControlEventTouchUpInside];
    cell.accessoryView = more;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *descriptor = [self rowDescriptorAtIndexPath:indexPath];
    if (!descriptor) return;
    NSMutableDictionary *item = descriptor[@"item"];
    if ([descriptor[@"kind"] isEqualToString:@"output"]) {
        [self openOutputPath:item[@"outputPath"]];
    } else if (![item[@"extracting"] boolValue] && !self.activeTask) {
        [self confirmExtractionForItem:item indexPath:indexPath];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath { return YES; }

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *descriptor = [self rowDescriptorAtIndexPath:indexPath];
    if (!descriptor) return nil;
    NSMutableDictionary *item = descriptor[@"item"];
    BOOL output = [descriptor[@"kind"] isEqualToString:@"output"];
    NSString *title = output ? @"حذف الناتج" : @"إزالة من القائمة";
    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:title handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        if (output) [self deleteOutputForItem:item]; else [self removeSourceFromList:item];
        completionHandler(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[action]];
}

@end
