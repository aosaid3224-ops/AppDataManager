#import "PVMediaLibraryViewController.h"
#import "PVMediaVaultStore.h"
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
#import "PVMediaVaultBrowserViewController.h"

@interface PVMediaLibraryViewController () <UITableViewDataSource, UITableViewDelegate, PHPickerViewControllerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *statisticsLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *pickButton;
@property (nonatomic, strong) UIButton *hiddenImagesButton;
@property (nonatomic, strong) UIButton *hiddenVideosButton;
@property (nonatomic, strong) NSArray<PVMediaVaultItem *> *vaultItems;
@property (nonatomic, strong) NSArray<PHPickerResult *> *selectedPickerResults;
@property (nonatomic, assign) NSUInteger libraryImageCount;
@property (nonatomic, assign) NSUInteger libraryVideoCount;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, assign) BOOL didAutoPresentPicker;
@end

@implementation PVMediaLibraryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"إخفاء الصور والفيديوهات";
    self.vaultItems = @[];
    self.selectedPickerResults = @[];
    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    if (@available(iOS 13.0, *)) self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    else self.view.backgroundColor = [UIColor whiteColor];

    self.statisticsLabel = [[UILabel alloc] init];
    self.statisticsLabel.textAlignment = NSTextAlignmentRight;
    self.statisticsLabel.numberOfLines = 0;
    self.statisticsLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.statisticsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statisticsLabel];

    self.pickButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.pickButton setTitle:@"اختيار من الصور والفيديوهات" forState:UIControlStateNormal];
    self.pickButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.pickButton addTarget:self action:@selector(openPhotoPicker:) forControlEvents:UIControlEventTouchUpInside];
    self.pickButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.pickButton];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.textAlignment = NSTextAlignmentRight;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 76.0;
    self.tableView.hidden = YES;
    [self.view addSubview:self.tableView];

    self.hiddenImagesButton = [self makeHiddenSectionButton:@"الصور المخفية" action:@selector(openHiddenImages:)];
    self.hiddenVideosButton = [self makeHiddenSectionButton:@"الفيديوهات المخفية" action:@selector(openHiddenVideos:)];
    [self.view addSubview:self.hiddenImagesButton];
    [self.view addSubview:self.hiddenVideosButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.statisticsLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [self.statisticsLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.statisticsLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.pickButton.topAnchor constraintEqualToAnchor:self.statisticsLabel.bottomAnchor constant:12],
        [self.pickButton.trailingAnchor constraintEqualToAnchor:self.statisticsLabel.trailingAnchor],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.pickButton.bottomAnchor constant:4],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.statisticsLabel.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.statisticsLabel.trailingAnchor],
        [self.hiddenImagesButton.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:20],
        [self.hiddenImagesButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.hiddenImagesButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.hiddenImagesButton.heightAnchor constraintEqualToConstant:104],
        [self.hiddenVideosButton.topAnchor constraintEqualToAnchor:self.hiddenImagesButton.bottomAnchor constant:14],
        [self.hiddenVideosButton.leadingAnchor constraintEqualToAnchor:self.hiddenImagesButton.leadingAnchor],
        [self.hiddenVideosButton.trailingAnchor constraintEqualToAnchor:self.hiddenImagesButton.trailingAnchor],
        [self.hiddenVideosButton.heightAnchor constraintEqualToAnchor:self.hiddenImagesButton.heightAnchor],
        [self.tableView.topAnchor constraintEqualToAnchor:self.hiddenVideosButton.bottomAnchor constant:8],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self reloadVaultItems];
    [self updateStatistics];
    [self requestPhotoAccessWithCompletion:nil];
    if (self.mediaType.length > 0) {
        self.statisticsLabel.hidden = YES;
        self.pickButton.hidden = YES;
        self.hiddenImagesButton.hidden = YES;
        self.hiddenVideosButton.hidden = YES;
        self.tableView.hidden = YES;
        self.title = [self.mediaType isEqualToString:@"video"] ? @"إضافة فيديوهات" : @"إضافة صور";
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self reloadVaultItems];
    [self requestPhotoAccessWithCompletion:nil];
    if (self.mediaType.length > 0 && !self.didAutoPresentPicker) {
        self.didAutoPresentPicker = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self openPhotoPicker:nil];
        });
    }
}

- (NSArray<PVMediaVaultItem *> *)imageItems {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(PVMediaVaultItem *item, NSDictionary *bindings) {
        return [item.type isEqualToString:@"image"];
    }];
    return [self.vaultItems filteredArrayUsingPredicate:predicate];
}

- (NSArray<PVMediaVaultItem *> *)videoItems {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(PVMediaVaultItem *item, NSDictionary *bindings) {
        return [item.type isEqualToString:@"video"];
    }];
    return [self.vaultItems filteredArrayUsingPredicate:predicate];
}

- (void)requestPhotoAccessWithCompletion:(void (^)(BOOL granted))completion {
    if (@available(iOS 14.0, *)) {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
        if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
            [self reloadLibraryStatistics];
            if (completion) completion(YES);
            return;
        }
        if (status == PHAuthorizationStatusDenied || status == PHAuthorizationStatusRestricted) {
            [self showPhotoPermissionMessage];
            if (completion) completion(NO);
            return;
        }
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite handler:^(PHAuthorizationStatus newStatus) {
            dispatch_async(dispatch_get_main_queue(), ^{
                BOOL granted = newStatus == PHAuthorizationStatusAuthorized || newStatus == PHAuthorizationStatusLimited;
                if (granted) [self reloadLibraryStatistics];
                else [self showPhotoPermissionMessage];
                if (completion) completion(granted);
            });
        }];
    } else {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        if (status == PHAuthorizationStatusAuthorized) {
            [self reloadLibraryStatistics];
            if (completion) completion(YES);
        } else if (status == PHAuthorizationStatusNotDetermined) {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus newStatus) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    BOOL granted = newStatus == PHAuthorizationStatusAuthorized;
                    if (granted) [self reloadLibraryStatistics];
                    else [self showPhotoPermissionMessage];
                    if (completion) completion(granted);
                });
            }];
        } else {
            [self showPhotoPermissionMessage];
            if (completion) completion(NO);
        }
    }
}

- (BOOL)hasPhotoAccess {
    if (@available(iOS 14.0, *)) {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
        return status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited;
    }
    return [PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized;
}

- (void)showPhotoPermissionMessage {
    self.libraryImageCount = 0;
    self.libraryVideoCount = 0;
    self.statisticsLabel.text = [NSString stringWithFormat:@"الصور في المكتبة: غير متاح\nالفيديوهات في المكتبة: غير متاح\nالمحدد للإخفاء: %lu\nالصور المخفية: %lu\nالفيديوهات المخفية: %lu", (unsigned long)self.selectedPickerResults.count, (unsigned long)self.imageItems.count, (unsigned long)self.videoItems.count];
    self.statusLabel.textColor = [UIColor systemRedColor];
    self.statusLabel.text = @"يلزم السماح للتطبيق بالوصول إلى مكتبة الصور لعرض الإحصائيات وإخفاء الأصول المحددة.";
    self.pickButton.enabled = NO;
}

- (void)reloadLibraryStatistics {
    PHFetchOptions *imageOptions = [[PHFetchOptions alloc] init];
    PHFetchOptions *videoOptions = [[PHFetchOptions alloc] init];
    self.libraryImageCount = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:imageOptions].count;
    self.libraryVideoCount = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeVideo options:videoOptions].count;
    [self updateStatistics];
}

- (void)reloadVaultItems {
    self.vaultItems = [PVMediaVaultStore sharedStore].items;
    [self updateHiddenSectionButtons];
    [self updateStatistics];
    [self.tableView reloadData];
}

- (UIButton *)makeHiddenSectionButton:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.textAlignment = NSTextAlignmentRight;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    button.contentEdgeInsets = UIEdgeInsetsMake(12, 18, 12, 18);
    button.layer.cornerRadius = 16.0;
    button.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        button.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        button.tintColor = [UIColor systemBlueColor];
    } else {
        button.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0];
    }
    button.accessibilityTraits = UIAccessibilityTraitButton;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button setTitle:title forState:UIControlStateNormal];
    return button;
}

- (void)updateHiddenSectionButtons {
    NSUInteger imageCount = self.imageItems.count;
    NSUInteger videoCount = self.videoItems.count;
    [self.hiddenImagesButton setTitle:[NSString stringWithFormat:@"الصور المخفية\n%lu عنصر — اضغط للتصفح", (unsigned long)imageCount] forState:UIControlStateNormal];
    [self.hiddenVideosButton setTitle:[NSString stringWithFormat:@"الفيديوهات المخفية\n%lu عنصر — اضغط للتصفح", (unsigned long)videoCount] forState:UIControlStateNormal];
    self.hiddenImagesButton.accessibilityLabel = [NSString stringWithFormat:@"الصور المخفية، %lu عنصر", (unsigned long)imageCount];
    self.hiddenVideosButton.accessibilityLabel = [NSString stringWithFormat:@"الفيديوهات المخفية، %lu عنصر", (unsigned long)videoCount];
}

- (void)openHiddenImages:(UIButton *)sender {
    [self openBrowserForItems:self.imageItems title:@"الصور المخفية"];
}

- (void)openHiddenVideos:(UIButton *)sender {
    [self openBrowserForItems:self.videoItems title:@"الفيديوهات المخفية"];
}

- (void)openBrowserForItems:(NSArray<PVMediaVaultItem *> *)items title:(NSString *)title {
    PVMediaVaultBrowserViewController *browser = [[PVMediaVaultBrowserViewController alloc] init];
    browser.sectionTitle = title;
    browser.items = [items copy];
    __weak typeof(self) weakSelf = self;
    browser.restoreHandler = ^(PVMediaVaultItem *item, void (^completion)(BOOL success, NSString *message)) {
        [weakSelf restoreItem:item completion:completion];
    };
    [self.navigationController pushViewController:browser animated:YES];
}

- (void)updateStatistics {
    [self updateHiddenSectionButtons];
    self.statisticsLabel.text = [NSString stringWithFormat:@"الصور في المكتبة: %lu\nالفيديوهات في المكتبة: %lu\nالمحدد للإخفاء: %lu\nالصور المخفية: %lu\nالفيديوهات المخفية: %lu", (unsigned long)self.libraryImageCount, (unsigned long)self.libraryVideoCount, (unsigned long)self.selectedPickerResults.count, (unsigned long)self.imageItems.count, (unsigned long)self.videoItems.count];
    self.pickButton.enabled = !self.busy && [self hasPhotoAccess];
}

- (void)openPhotoPicker:(UIButton *)sender {
    if (self.busy) return;
    [self requestPhotoAccessWithCompletion:^(BOOL granted) {
        if (!granted) return;
        PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] initWithPhotoLibrary:[PHPhotoLibrary sharedPhotoLibrary]];
        if ([self.mediaType isEqualToString:@"image"]) configuration.filter = [PHPickerFilter imagesFilter];
        else if ([self.mediaType isEqualToString:@"video"]) configuration.filter = [PHPickerFilter videosFilter];
        else configuration.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[[PHPickerFilter imagesFilter], [PHPickerFilter videosFilter]]];
        configuration.selectionLimit = 0;
        configuration.preferredAssetRepresentationMode = PHPickerConfigurationAssetRepresentationModeCurrent;
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    self.selectedPickerResults = results ?: @[];
    [self updateStatistics];
    if (self.selectedPickerResults.count == 0) {
        if (self.mediaType.length > 0) {
            [self.navigationController popViewControllerAnimated:YES];
            return;
        }
        self.statusLabel.textColor = [UIColor systemGrayColor];
        self.statusLabel.text = @"لم يتم اختيار أي عنصر؛ لم تتغير أي بيانات.";
        return;
    }
    UIAlertController *confirmation = [UIAlertController alertControllerWithTitle:@"تأكيد الإخفاء" message:[NSString stringWithFormat:@"تم اختيار %lu عنصر. هل تريد نسخها والتحقق منها ثم إخفاء أصولها من تطبيق الصور؟", (unsigned long)self.selectedPickerResults.count] preferredStyle:UIAlertControllerStyleAlert];
    [confirmation addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        self.selectedPickerResults = @[];
        if (self.mediaType.length > 0) {
            [self.navigationController popViewControllerAnimated:YES];
            return;
        }
        self.statusLabel.textColor = [UIColor systemGrayColor];
        self.statusLabel.text = @"تم إلغاء الاختيار؛ لم تتغير أي بيانات.";
        [self updateStatistics];
    }]];
    [confirmation addAction:[UIAlertAction actionWithTitle:@"السماح بالإخفاء" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self importSelectedPickerResults];
    }]];
    [self presentViewController:confirmation animated:YES completion:nil];
}

- (void)importSelectedPickerResults {
    if (self.busy || self.selectedPickerResults.count == 0) return;
    self.busy = YES;
    [self updateStatistics];
    self.statusLabel.textColor = [UIColor labelColor];
    self.statusLabel.text = @"جارٍ نسخ العناصر والتحقق منها…";
    [self importPickerResults:self.selectedPickerResults atIndex:0 importedItems:[NSMutableArray array] completion:^(BOOL success, NSArray<PVMediaVaultItem *> *importedItems, NSError *error) {
        if (!success) {
            self.busy = NO;
            self.statusLabel.textColor = [UIColor systemRedColor];
            self.statusLabel.text = error.localizedDescription ?: @"فشل الاستيراد؛ لم تتم إزالة أي أصل من الصور.";
            self.selectedPickerResults = @[];
            [self reloadVaultItems];
            return;
        }
        [self verifyItems:importedItems completion:^(BOOL verified, NSError *verificationError) {
            if (!verified) {
                self.busy = NO;
                self.statusLabel.textColor = [UIColor systemRedColor];
                self.statusLabel.text = verificationError.localizedDescription ?: @"فشل التحقق؛ لم تتم إزالة أي أصل من الصور.";
                self.selectedPickerResults = @[];
                [self reloadVaultItems];
                return;
            }
            NSMutableArray<NSString *> *identifiers = [NSMutableArray arrayWithCapacity:importedItems.count];
            for (PVMediaVaultItem *item in importedItems) [identifiers addObject:item.identifier];
            PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsWithLocalIdentifiers:identifiers options:nil];
            if (assets.count != identifiers.count) {
                self.busy = NO;
                self.statusLabel.textColor = [UIColor systemOrangeColor];
                self.statusLabel.text = @"تم حفظ العناصر والتحقق منها، لكن تعذر مطابقة كل أصل؛ لم تتم إزالة أي أصل من الصور.";
                self.selectedPickerResults = @[];
                [self reloadVaultItems];
                return;
            }
            [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
                [PHAssetChangeRequest deleteAssets:assets];
            } completionHandler:^(BOOL deletionSuccess, NSError *deletionError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.busy = NO;
                    self.selectedPickerResults = @[];
                    if (deletionSuccess) {
                        self.statusLabel.textColor = [UIColor systemGreenColor];
                        self.statusLabel.text = @"تمت الإضافة والتحقق وإخفاء الأصول المحددة.";
                    } else {
                        self.statusLabel.textColor = [UIColor systemOrangeColor];
                        self.statusLabel.text = @"تم حفظ العناصر والتحقق منها، لكن تعذر حذف الأصول؛ بقيت النسختان محفوظتين.";
                    }
                    [self reloadLibraryStatistics];
                    [self reloadVaultItems];
                    if (deletionSuccess && self.mediaType.length > 0) [self.navigationController popViewControllerAnimated:YES];
                });
            }];
        }];
    }];
}

- (void)importPickerResults:(NSArray<PHPickerResult *> *)results atIndex:(NSUInteger)index importedItems:(NSMutableArray<PVMediaVaultItem *> *)importedItems completion:(void (^)(BOOL success, NSArray<PVMediaVaultItem *> *importedItems, NSError *error))completion {
    if (index >= results.count) {
        completion(YES, [importedItems copy], nil);
        return;
    }
    PHPickerResult *result = results[index];
    NSString *assetIdentifier = result.assetIdentifier;
    if (assetIdentifier.length == 0) {
        completion(NO, [importedItems copy], [NSError errorWithDomain:@"com.aosaid.privacyvault.media" code:30 userInfo:@{NSLocalizedDescriptionKey: @"تعذر التعرف على أصل العنصر المحدد؛ لم يتم حذف أي أصل"}]);
        return;
    }
    NSItemProvider *provider = result.itemProvider;
    NSString *typeIdentifier = provider.registeredTypeIdentifiers.firstObject;
    if (typeIdentifier.length == 0) {
        completion(NO, [importedItems copy], [NSError errorWithDomain:@"com.aosaid.privacyvault.media" code:31 userInfo:@{NSLocalizedDescriptionKey: @"تعذر قراءة نوع العنصر المحدد"}]);
        return;
    }
    [provider loadFileRepresentationForTypeIdentifier:typeIdentifier completionHandler:^(NSURL *url, NSError *error) {
        if (error || !url.isFileURL) {
            completion(NO, [importedItems copy], [NSError errorWithDomain:error.domain ?: @"com.aosaid.privacyvault.media" code:error.code ?: 32 userInfo:@{NSLocalizedDescriptionKey: @"تعذر تحميل العنصر من منتقي الصور"}]);
            return;
        }
        BOOL video = [typeIdentifier rangeOfString:@"movie" options:NSCaseInsensitiveSearch].location != NSNotFound || [typeIdentifier rangeOfString:@"video" options:NSCaseInsensitiveSearch].location != NSNotFound;
        NSString *type = video ? @"video" : @"image";
        NSError *importError = nil;
        BOOL imported = [[PVMediaVaultStore sharedStore] importFileAtURL:url identifier:assetIdentifier type:type originalFilename:url.lastPathComponent error:&importError];
        if (!imported) {
            completion(NO, [importedItems copy], importError ?: [NSError errorWithDomain:@"com.aosaid.privacyvault.media" code:33 userInfo:@{NSLocalizedDescriptionKey: @"فشل حفظ العنصر داخل PrivacyVault"}]);
            return;
        }
        PVMediaVaultItem *storedItem = nil;
        for (PVMediaVaultItem *candidate in [PVMediaVaultStore sharedStore].items) if ([candidate.identifier isEqualToString:assetIdentifier]) { storedItem = candidate; break; }
        if (!storedItem) {
            completion(NO, [importedItems copy], [NSError errorWithDomain:@"com.aosaid.privacyvault.media" code:34 userInfo:@{NSLocalizedDescriptionKey: @"تعذر قراءة سجل العنصر المحفوظ"}]);
            return;
        }
        [importedItems addObject:storedItem];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self importPickerResults:results atIndex:index + 1 importedItems:importedItems completion:completion];
        });
    }];
}

- (void)verifyItems:(NSArray<PVMediaVaultItem *> *)items completion:(void (^)(BOOL verified, NSError *error))completion {
    for (PVMediaVaultItem *item in items) {
        NSError *error = nil;
        if (![[PVMediaVaultStore sharedStore] verifyItem:item error:&error]) {
            completion(NO, error ?: [NSError errorWithDomain:@"com.aosaid.privacyvault.media" code:35 userInfo:@{NSLocalizedDescriptionKey: @"فشل التحقق من نسخة PrivacyVault؛ لم يتم حذف الأصل"}]);
            return;
        }
    }
    completion(YES, nil);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? self.imageItems.count : self.videoItems.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"الصور المخفية" : @"الفيديوهات المخفية";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"PVHiddenMediaCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    cell.textLabel.textAlignment = NSTextAlignmentRight;
    cell.detailTextLabel.textAlignment = NSTextAlignmentRight;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    NSArray<PVMediaVaultItem *> *items = indexPath.section == 0 ? self.imageItems : self.videoItems;
    PVMediaVaultItem *item = items[indexPath.row];
    cell.textLabel.text = item.filename;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ — %@ بايت", indexPath.section == 0 ? @"صورة" : @"فيديو", [NSNumber numberWithUnsignedInteger:item.byteSize]];
    UIButton *restoreButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [restoreButton setTitle:@"استرداد" forState:UIControlStateNormal];
    restoreButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    restoreButton.tag = (indexPath.section * 100000) + indexPath.row;
    [restoreButton addTarget:self action:@selector(restoreButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [restoreButton sizeToFit];
    cell.accessoryView = restoreButton;
    if (@available(iOS 13.0, *)) cell.imageView.image = [UIImage systemImageNamed:indexPath.section == 0 ? @"photo.fill" : @"video.fill"];
    return cell;
}

- (void)restoreButtonTapped:(UIButton *)sender {
    NSUInteger section = (NSUInteger)sender.tag / 100000;
    NSUInteger row = (NSUInteger)sender.tag % 100000;
    NSArray<PVMediaVaultItem *> *items = section == 0 ? self.imageItems : self.videoItems;
    if (row >= items.count || self.busy) return;
    [self restoreItem:items[row]];
}

- (void)restoreItem:(PVMediaVaultItem *)item {
    [self restoreItem:item completion:nil];
}

- (void)restoreItem:(PVMediaVaultItem *)item completion:(void (^)(BOOL success, NSString *message))completion {
    NSError *verificationError = nil;
    if (![[PVMediaVaultStore sharedStore] verifyItem:item error:&verificationError]) {
        self.statusLabel.textColor = [UIColor systemRedColor];
        self.statusLabel.text = verificationError.localizedDescription ?: @"نسخة PrivacyVault غير مكتملة؛ لم تتم إزالتها.";
        if (completion) completion(NO, self.statusLabel.text);
        return;
    }
    [self requestPhotoAccessWithCompletion:^(BOOL granted) {
        if (!granted) {
            if (completion) completion(NO, @"يلزم السماح بإضافة الوسائط إلى تطبيق الصور قبل الاسترداد.");
            return;
        }
        NSURL *url = [[PVMediaVaultStore sharedStore] urlForItem:item];
        self.busy = YES;
        [self updateStatistics];
        self.statusLabel.textColor = [UIColor labelColor];
        self.statusLabel.text = @"جارٍ استرداد العنصر والتحقق منه…";
        __block NSString *createdIdentifier = nil;
        [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
            PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
            PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
            PHAssetResourceType resourceType = [item.type isEqualToString:@"video"] ? PHAssetResourceTypeVideo : PHAssetResourceTypePhoto;
            [request addResourceWithType:resourceType fileURL:url options:options];
            createdIdentifier = request.placeholderForCreatedAsset.localIdentifier;
        } completionHandler:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!success || createdIdentifier.length == 0) {
                    self.busy = NO;
                    self.statusLabel.textColor = [UIColor systemRedColor];
                    self.statusLabel.text = error.localizedDescription ?: @"فشل الاسترداد؛ بقيت نسخة PrivacyVault دون تغيير.";
                    [self updateStatistics];
                    if (completion) completion(NO, self.statusLabel.text);
                    return;
                }
                PHFetchResult<PHAsset *> *createdAssets = [PHAsset fetchAssetsWithLocalIdentifiers:@[createdIdentifier] options:nil];
                if (createdAssets.count == 0) {
                    self.busy = NO;
                    self.statusLabel.textColor = [UIColor systemRedColor];
                    self.statusLabel.text = @"لم يتم التحقق من العنصر المسترد؛ بقيت نسخة PrivacyVault دون تغيير.";
                    [self updateStatistics];
                    if (completion) completion(NO, self.statusLabel.text);
                    return;
                }
                NSError *removeError = nil;
                if (![[PVMediaVaultStore sharedStore] removeItem:item error:&removeError]) {
                    self.busy = NO;
                    self.statusLabel.textColor = [UIColor systemOrangeColor];
                    self.statusLabel.text = @"تم استرداد العنصر، لكن تعذر إزالة نسخة PrivacyVault؛ بقيت النسخة للحماية.";
                    [self reloadVaultItems];
                    if (completion) completion(NO, self.statusLabel.text);
                    return;
                }
                self.busy = NO;
                self.statusLabel.textColor = [UIColor systemGreenColor];
                self.statusLabel.text = @"تم استرداد العنصر والتحقق منه وإزالة نسخة PrivacyVault.";
                [self reloadLibraryStatistics];
                [self reloadVaultItems];
                if (completion) completion(YES, self.statusLabel.text);
            });
        }];
    }];
}

@end
