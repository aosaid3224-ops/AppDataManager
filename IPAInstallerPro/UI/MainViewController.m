#import "MainViewController.h"
#import "IPAFileBrowserViewController.h"
#import "IPAInstallViewController.h"
#import "Core/IPAExtractor.h"
#import "Core/Logger.h"
#import "GlassIPACell.h"

@interface MainViewController () <UIDocumentPickerDelegate>
@property (nonatomic, strong) UIView *toastView;
@property (nonatomic, strong) UILabel *toastLabel;
@property (nonatomic, strong) UIView *dashboardHeader;
@property (nonatomic, assign) BOOL hasShownAutoAbout;
@property (nonatomic, strong) UILabel *trustedCountLabel;
@property (nonatomic, strong) UILabel *installedCountLabel;
@property (nonatomic, strong) UISearchBar *searchBar;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"";
    self.navigationItem.title = @"";
    self.view.backgroundColor = [UIColor colorWithRed:0.025 green:0.026 blue:0.030 alpha:1.0];
    self.ipaFiles = [NSMutableArray array];
    self.isLoading = NO;
    self.ipaMetadataCache = [NSMutableDictionary dictionary];
    self.ipaIconCache = [[NSCache alloc] init];
    self.ipaIconCache.countLimit = 100;
    self.ipaCacheQueue = dispatch_queue_create("com.aosaid.ipainstallerpro.ipa-metadata-cache", DISPATCH_QUEUE_SERIAL);

    [self setupNavigationBar];
    [self setupTableView];
    [self setupDashboardHeader];
    [self setupEmptyState];
    [self setupAddButton];
    [self setupToast];
    [self setupLoadingIndicator];
    [self loadIPAFiles];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    // Don't reload here to avoid lag — use pull-to-refresh instead
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.hasShownAutoAbout) return;
    self.hasShownAutoAbout = YES;

    // Wait until the first frame is visible so the alert never blocks app launch.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentAutomaticAboutIfNeeded];
    });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBarHidden = NO;
}

- (void)presentAutomaticAboutIfNeeded {
    NSString *message = @"هذه الأداة متاحة حاليًا كنسخة تجريبية وليست الإصدار النهائي.\n\nقد تواجه بعض الأخطاء أو المشاكل أثناء الاستخدام، ونهدف من خلال هذه المرحلة إلى اختبار الأداة وتحسين استقرارها وتطوير ميزاتها.\n\nإذا واجهت أي خلل، أو لديك ملاحظة أو اقتراح لتحسين الأداة، نرجو منك مشاركة تجربتك معنا. ملاحظاتك تساعدنا على اكتشاف المشاكل ومعالجتها قبل إطلاق الإصدار النهائي.\n\nللتواصل والإبلاغ عن المشاكل:\nX: @Zainqkvd";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"حول الأداة" message:message preferredStyle:UIAlertControllerStyleAlert];
    alert.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)setupNavigationBar {
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.navigationController.navigationBarHidden = YES;
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 4, 0);
    self.tableView.verticalScrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 20, 0);
    self.tableView.rowHeight = 72;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:self.tableView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    [self.refreshControl addTarget:self action:@selector(refreshPulled:) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;
}

- (void)setupDashboardHeader {
    CGFloat width = self.view.bounds.size.width;
    self.dashboardHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 220.0)];
    self.dashboardHeader.backgroundColor = UIColor.clearColor; self.dashboardHeader.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(8, 27, width - 16, 40)];
    NSMutableAttributedString *styledTitle = [[NSMutableAttributedString alloc] initWithString:@"ملفات IPA" attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:27 weight:UIFontWeightBold], NSForegroundColorAttributeName:UIColor.whiteColor}];
    [styledTitle addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:1.0 green:0.22 blue:0.18 alpha:1.0] range:NSMakeRange(6, 3)]; title.attributedText = styledTitle; title.textAlignment = NSTextAlignmentCenter; title.autoresizingMask = UIViewAutoresizingFlexibleWidth; [self.dashboardHeader addSubview:title];
    UIButton *add = [UIButton buttonWithType:UIButtonTypeSystem]; add.frame = CGRectMake(width - 64, 34, 44, 44); add.layer.cornerRadius = 15; add.layer.borderWidth = 0.7; add.layer.borderColor = [UIColor colorWithWhite:1 alpha:.16].CGColor; add.backgroundColor = [UIColor colorWithWhite:1 alpha:.025]; [add setImage:[UIImage systemImageNamed:@"plus"] forState:UIControlStateNormal]; add.tintColor = [UIColor colorWithRed:1 green:.20 blue:.16 alpha:1]; [add addTarget:self action:@selector(addIPATapped:) forControlEvents:UIControlEventTouchUpInside]; [self.dashboardHeader addSubview:add];
    UIButton *viewMode = [UIButton buttonWithType:UIButtonTypeSystem]; viewMode.frame = CGRectMake(24, 34, 48, 48); viewMode.layer.cornerRadius = 17; viewMode.layer.borderWidth = 1; viewMode.layer.borderColor = [UIColor colorWithWhite:1 alpha:.14].CGColor; [viewMode setImage:[UIImage systemImageNamed:@"list.bullet"] forState:UIControlStateNormal]; viewMode.tintColor = [UIColor colorWithRed:1 green:.20 blue:.16 alpha:1]; [self.dashboardHeader addSubview:viewMode];
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(8, 91, MAX(width - 16, 1), 42)]; self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth; self.searchBar.placeholder = @"البحث في الملفات..."; self.searchBar.searchBarStyle = UISearchBarStyleMinimal; self.searchBar.tintColor = [UIColor colorWithRed:1 green:.22 blue:.18 alpha:1]; self.searchBar.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft; [self.dashboardHeader addSubview:self.searchBar];
    UIView *stats = [[UIView alloc] initWithFrame:CGRectMake(8, 139, MAX(width - 16, 1), 74)]; stats.autoresizingMask = UIViewAutoresizingFlexibleWidth; stats.backgroundColor = [UIColor colorWithRed:.065 green:.066 blue:.075 alpha:1]; stats.layer.cornerRadius = 17; stats.layer.borderWidth = 1; stats.layer.borderColor = [UIColor colorWithRed:.42 green:.08 blue:.09 alpha:.65].CGColor; [self.dashboardHeader addSubview:stats];
    NSArray *icons = @[@"cube", @"chart.pie", @"shield", @"arrow.down.circle"]; NSArray *labels = @[@"التطبيقات", @"إجمالي الحجم", @"موثوقة", @"تم التثبيت"]; NSMutableArray *values = [NSMutableArray array];
    for (NSInteger i = 0; i < 4; i++) { CGFloat x = stats.bounds.size.width / 4.0 * i; if (i) { UIView *d = [[UIView alloc] initWithFrame:CGRectMake(x, 14, 1, 46)]; d.backgroundColor = [UIColor colorWithWhite:1 alpha:.08]; [stats addSubview:d]; } UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(x + (stats.bounds.size.width / 4.0 - 22) / 2.0, 7, 22, 22)]; iv.image = [UIImage systemImageNamed:icons[i]]; iv.tintColor = [UIColor colorWithRed:1 green:.22 blue:.18 alpha:1]; iv.contentMode = UIViewContentModeScaleAspectFit; [stats addSubview:iv]; UILabel *v = [[UILabel alloc] initWithFrame:CGRectMake(x + 3, 30, stats.bounds.size.width / 4.0 - 6, 22)]; v.textAlignment = NSTextAlignmentCenter; v.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold]; v.textColor = UIColor.whiteColor; [stats addSubview:v]; [values addObject:v]; UILabel *c = [[UILabel alloc] initWithFrame:CGRectMake(x + 1, 54, stats.bounds.size.width / 4.0 - 2, 16)]; c.text = labels[i]; c.textAlignment = NSTextAlignmentCenter; c.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium]; c.textColor = [UIColor colorWithWhite:.68 alpha:1]; [stats addSubview:c]; }
    self.appsCountLabel = values[0]; self.totalSizeLabel = values[1]; self.trustedCountLabel = values[2]; self.installedCountLabel = values[3];
    self.totalSizeLabel.adjustsFontSizeToFitWidth = YES; self.totalSizeLabel.minimumScaleFactor = 0.45; self.totalSizeLabel.numberOfLines = 1;
    self.tableView.tableHeaderView = self.dashboardHeader;
}

- (void)updateDashboardStatistics {
    NSUInteger trusted = 0; unsigned long long total = 0; for (IPAExtractedInfo *info in self.ipaFiles) { total += info.fileSize.unsignedLongLongValue; if (info.teamIdentifier.length > 0 && ![info.teamIdentifier isEqualToString:@"غير معروف"]) trusted++; }
    NSUInteger installed = 0; NSFileManager *fm = [NSFileManager defaultManager]; for (NSString *root in @[@"/Applications", @"/var/jb/Applications"]) { for (NSString *item in [fm contentsOfDirectoryAtPath:root error:nil]) if ([item.pathExtension.lowercaseString isEqualToString:@"app"]) installed++; }
    self.appsCountLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.ipaFiles.count]; self.totalSizeLabel.text = [[IPAExtractor sharedExtractor] formatFileSize:(long long)total]; self.trustedCountLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)trusted]; self.installedCountLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)installed];
}

- (void)setupEmptyState {
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"لا توجد ملفات IPA\nاضغط + لإضافة ملف";
    self.emptyLabel.textColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    self.emptyLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
}

- (void)setupAddButton {
    UIBarButtonItem *addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                              target:self
                                                                              action:@selector(addIPATapped:)];
    addBtn.tintColor = [UIColor colorWithRed:0.82 green:0.12 blue:0.15 alpha:0.96];
    self.navigationItem.rightBarButtonItem = addBtn;
}

- (void)setupToast {
    self.toastView = [[UIView alloc] initWithFrame:CGRectMake(20, -60, self.view.bounds.size.width - 40, 50)];
    self.toastView.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.18 alpha:0.95];
    self.toastView.layer.cornerRadius = 12;
    self.toastView.layer.masksToBounds = YES;
    self.toastView.alpha = 0;
    [self.view addSubview:self.toastView];

    self.toastLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, self.toastView.bounds.size.width - 32, 50)];
    self.toastLabel.textColor = [UIColor whiteColor];
    self.toastLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.toastLabel.textAlignment = NSTextAlignmentCenter;
    [self.toastView addSubview:self.toastLabel];
}

- (void)setupLoadingIndicator {
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.color = [UIColor colorWithWhite:0.5 alpha:1.0];
    self.loadingIndicator.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2 - 40);
    self.loadingIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.loadingIndicator.hidden = YES;
    [self.view addSubview:self.loadingIndicator];
}

- (void)showToast:(NSString *)message isError:(BOOL)isError {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.toastLabel.text = message;
        self.toastView.backgroundColor = isError
            ? [UIColor colorWithRed:0.8 green:0.25 blue:0.2 alpha:0.95]
            : [UIColor colorWithRed:0.15 green:0.15 blue:0.18 alpha:0.95];

        [UIView animateWithDuration:0.3 animations:^{
            self.toastView.alpha = 1;
            self.toastView.frame = CGRectMake(20, 60, self.view.bounds.size.width - 40, 50);
        } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.3 animations:^{
                    self.toastView.alpha = 0;
                    self.toastView.frame = CGRectMake(20, -60, self.view.bounds.size.width - 40, 50);
                }];
            });
        }];
    });
}

- (NSString *)ipaCacheKeyForPath:(NSString *)path attributes:(NSDictionary *)attrs {
    if (path.length == 0 || !attrs) return nil;
    unsigned long long size = [attrs[NSFileSize] unsignedLongLongValue];
    NSTimeInterval modified = [attrs[NSFileModificationDate] timeIntervalSince1970];
    unsigned long long fileNumber = [attrs[NSFileSystemFileNumber] unsignedLongLongValue];
    return [NSString stringWithFormat:@"%@|%llu|%.6f|%llu", path, size, modified, fileNumber];
}


- (NSString *)iconCacheKeyForPath:(NSString *)path key:(NSString *)cacheKey {
    return [NSString stringWithFormat:@"%@|%@", path, cacheKey];
}

- (IPAExtractedInfo *)placeholderInfoForIPAPath:(NSString *)path size:(NSNumber *)size {
    IPAExtractedInfo *info = [[IPAExtractedInfo alloc] init];
    info.filePath = path;
    info.fileSize = size ?: @0;
    info.formattedSize = [[IPAExtractor sharedExtractor] formatFileSize:info.fileSize.longLongValue];
    info.name = [[path.lastPathComponent stringByDeletingPathExtension] copy];
    info.displayName = info.name;
    info.version = @"جارٍ قراءة البيانات...";
    info.bundleID = @"جارٍ قراءة البيانات...";
    info.buildVersion = @"";
    info.minOSVersion = @"غير محدد";
    info.teamIdentifier = @"غير معروف";
    info.supportedDevices = @[];
    info.architectures = @[];
    return info;
}


- (void)loadIPAFiles {
    if (self.isLoading) return;
    self.isLoading = YES;
    self.ipaLoadGeneration += 1;
    NSUInteger loadGeneration = self.ipaLoadGeneration;

    dispatch_async(dispatch_get_main_queue(), ^{
        self.loadingIndicator.hidden = NO;
        [self.loadingIndicator startAnimating];
        self.emptyLabel.hidden = YES;
    });

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray<IPAExtractedInfo *> *foundFiles = [NSMutableArray array];
        NSMutableArray<NSDictionary *> *pending = [NSMutableArray array];
        NSArray *directories = @[
            @"/var/mobile/Documents/IPAInstaller",
            @"/var/mobile/Documents",
            @"/var/mobile/Downloads",
            @"/var/mobile/Media/Downloads"
        ];

        NSFileManager *fm = [NSFileManager defaultManager];
        NSMutableSet<NSString *> *seenIPAPaths = [NSMutableSet set];
        for (NSString *dir in directories) {
            if (![fm fileExistsAtPath:dir]) {
                if ([dir isEqualToString:@"/var/mobile/Documents/IPAInstaller"]) {
                    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
                }
                continue;
            }

            NSArray *contents = [fm contentsOfDirectoryAtPath:dir error:nil];
            for (NSString *file in contents) {
                if (![file.pathExtension.lowercaseString isEqualToString:@"ipa"]) continue;
                NSString *path = [dir stringByAppendingPathComponent:file];
                if ([seenIPAPaths containsObject:path]) continue;
                [seenIPAPaths addObject:path];

                NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
                NSString *cacheKey = [self ipaCacheKeyForPath:path attributes:attrs];
                __block NSDictionary *cachedRecord = nil;
                dispatch_sync(self.ipaCacheQueue, ^{
                    cachedRecord = self.ipaMetadataCache[path];
                });

                IPAExtractedInfo *cachedInfo = cachedRecord[@"info"];
                if ([cachedRecord[@"key"] isEqualToString:cacheKey] && cachedInfo) {
                    [foundFiles addObject:cachedInfo];
                } else {
                    IPAExtractedInfo *placeholder = [self placeholderInfoForIPAPath:path size:attrs[NSFileSize]];
                    [foundFiles addObject:placeholder];
                    [pending addObject:@{@"path": path, @"key": cacheKey ?: @"", @"index": @(foundFiles.count - 1)}];
                }
            }
        }

        // Phase 1 UI commit: show placeholders immediately
        dispatch_async(dispatch_get_main_queue(), ^{
            if (loadGeneration != self.ipaLoadGeneration) return;
            [self.ipaFiles removeAllObjects];
            [self.ipaFiles addObjectsFromArray:foundFiles];
            [self.tableView reloadData];
            [self updateDashboardStatistics];
            self.emptyLabel.hidden = (self.ipaFiles.count > 0);
            self.emptyLabel.frame = CGRectMake(20, self.view.bounds.size.height / 2 - 40, self.view.bounds.size.width - 40, 80);
            [self.refreshControl endRefreshing];
            [self.loadingIndicator stopAnimating];
            self.loadingIndicator.hidden = YES;
            self.isLoading = NO;
        });

        if (pending.count == 0) return;

        // Phase 2: metadata enrichment (limited concurrency, no icons)
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            dispatch_semaphore_t metaSem = dispatch_semaphore_create(4);
            dispatch_group_t metaGroup = dispatch_group_create();
            NSMutableArray<NSIndexPath *> *batchPaths = [NSMutableArray array];
            NSLock *batchLock = [[NSLock alloc] init];

            for (NSDictionary *job in pending) {
                dispatch_semaphore_wait(metaSem, DISPATCH_TIME_FOREVER);
                dispatch_group_enter(metaGroup);

                dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                    @autoreleasepool {
                        NSString *path = job[@"path"];
                        NSString *originalKey = job[@"key"];
                        IPAExtractedInfo *parsed = [[IPAExtractor sharedExtractor] extractMetadataFromIPA:path];

                        if (parsed) {
                            NSDictionary *currentAttrs = [fm attributesOfItemAtPath:path error:nil];
                            NSString *currentKey = [self ipaCacheKeyForPath:path attributes:currentAttrs];
                            if ([currentKey isEqualToString:originalKey]) {
                                dispatch_sync(self.ipaCacheQueue, ^{
                                    self.ipaMetadataCache[path] = @{@"key": originalKey, @"info": parsed};
                                });
                            }

                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (loadGeneration == self.ipaLoadGeneration) {
                                    NSUInteger index = [job[@"index"] unsignedIntegerValue];
                                    if (index < self.ipaFiles.count) {
                                        IPAExtractedInfo *existing = self.ipaFiles[index];
                                        if ([existing.filePath isEqualToString:path]) {
                                            self.ipaFiles[index] = parsed;
                                            [batchLock lock];
                                            [batchPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                                            if (batchPaths.count >= 5) {
                                                NSArray *toReload = [batchPaths copy];
                                                [batchPaths removeAllObjects];
                                                [batchLock unlock];
                                                [self.tableView reloadRowsAtIndexPaths:toReload withRowAnimation:UITableViewRowAnimationNone];
                                            } else {
                                                [batchLock unlock];
                                            }
                                        }
                                    }
                                }
                                dispatch_semaphore_signal(metaSem);
                                dispatch_group_leave(metaGroup);
                            });
                        } else {
                            dispatch_semaphore_signal(metaSem);
                            dispatch_group_leave(metaGroup);
                        }
                    }
                });
            }

            dispatch_group_wait(metaGroup, DISPATCH_TIME_FOREVER);

            dispatch_async(dispatch_get_main_queue(), ^{
                if (loadGeneration == self.ipaLoadGeneration && batchPaths.count > 0) {
                    [batchLock lock];
                    NSArray *toReload = [batchPaths copy];
                    [batchPaths removeAllObjects];
                    [batchLock unlock];
                    [self.tableView reloadRowsAtIndexPaths:toReload withRowAnimation:UITableViewRowAnimationNone];
                }
                [self updateDashboardStatistics];
            });

            // Phase 3: icon enrichment (background, limited concurrency)
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                dispatch_semaphore_t iconSem = dispatch_semaphore_create(2);
                dispatch_group_t iconGroup = dispatch_group_create();

                for (NSDictionary *job in pending) {
                    dispatch_semaphore_wait(iconSem, DISPATCH_TIME_FOREVER);
                    dispatch_group_enter(iconGroup);

                    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                        @autoreleasepool {
                            NSString *path = job[@"path"];
                            NSString *originalKey = job[@"key"];

                            NSString *iconCacheKey = [self iconCacheKeyForPath:path key:originalKey];
                            UIImage *icon = [self.ipaIconCache objectForKey:iconCacheKey];

                            if (!icon) {
                                icon = [[IPAExtractor sharedExtractor] extractIconFromIPA:path];
                                if (icon) {
                                    [self.ipaIconCache setObject:icon forKey:iconCacheKey];
                                }
                            }

                            if (icon) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    if (loadGeneration == self.ipaLoadGeneration) {
                                        NSUInteger index = [job[@"index"] unsignedIntegerValue];
                                        if (index < self.ipaFiles.count) {
                                            IPAExtractedInfo *info = self.ipaFiles[index];
                                            if ([info.filePath isEqualToString:path] && !info.icon) {
                                                info.icon = icon;
                                                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
                                                GlassIPACell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                                                if ([cell isKindOfClass:[GlassIPACell class]]) {
                                                    [cell setIconImage:icon animated:YES];
                                                }
                                            }
                                        }
                                    }
                                    dispatch_semaphore_signal(iconSem);
                                    dispatch_group_leave(iconGroup);
                                });
                            } else {
                                dispatch_semaphore_signal(iconSem);
                                dispatch_group_leave(iconGroup);
                            }
                        }
                    });
                }

                dispatch_group_wait(iconGroup, DISPATCH_TIME_FOREVER);
            });
        });
    });
}

- (void)refreshPulled:(UIRefreshControl *)sender {
    [self loadIPAFiles];
}

- (void)addIPATapped:(id)sender {
    NSArray *docTypes = @[
        @"com.apple.itunes.ipa",
        @"public.data",
        @"public.item",
        @"public.archive",
        @"public.zip-archive"
    ];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:docTypes inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray *)urls {
    if (urls.count == 0) return;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *destDir = @"/var/mobile/Documents/IPAInstaller";

    if (![fm fileExistsAtPath:destDir]) {
        NSError *dirError = nil;
        [fm createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:&dirError];
        if (dirError) {
            [self showToast:@"فشل إنشاء مجلد التخزين" isError:YES];
            return;
        }
    }

    __block NSInteger successCount = 0;
    __block NSInteger failCount = 0;

    // Process imports on background thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSURL *url in urls) {
            [url startAccessingSecurityScopedResource];

            NSString *fileName = url.lastPathComponent;
            if (!fileName || fileName.length == 0) {
                fileName = @"imported.ipa";
            }
            if (![fileName.pathExtension.lowercaseString isEqualToString:@"ipa"]) {
                fileName = [fileName stringByAppendingPathExtension:@"ipa"];
            }

            NSString *destPath = [destDir stringByAppendingPathComponent:fileName];
            if ([fm fileExistsAtPath:destPath]) {
                [fm removeItemAtPath:destPath error:nil];
                dispatch_sync(self.ipaCacheQueue, ^{
                    [self.ipaMetadataCache removeObjectForKey:destPath];
                });
            }

            NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
            [coordinator coordinateReadingItemAtURL:url options:NSFileCoordinatorReadingForUploading error:nil byAccessor:^(NSURL *newURL) {
                NSError *copyError = nil;
                BOOL copied = [fm copyItemAtPath:newURL.path toPath:destPath error:&copyError];
                if (copied) {
                    successCount++;
                    [[Logger sharedLogger] info:[NSString stringWithFormat:@"Imported %@ to %@", fileName, destPath]];
                } else {
                    failCount++;
                    [[Logger sharedLogger] error:[NSString stringWithFormat:@"Failed to import %@: %@", fileName, copyError.localizedDescription]];
                }
            }];

            [url stopAccessingSecurityScopedResource];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadIPAFiles];

            if (successCount > 0 && failCount == 0) {
                [self showToast:[NSString stringWithFormat:@"تمت إضافة %ld ملف IPA", (long)successCount] isError:NO];
            } else if (successCount > 0 && failCount > 0) {
                [self showToast:[NSString stringWithFormat:@"%ld نجح، %ld فشل", (long)successCount, (long)failCount] isError:YES];
            } else {
                [self showToast:@"فشل إضافة الملفات" isError:YES];
            }
        });
    });
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.ipaFiles.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"GlassIPACell";
    GlassIPACell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[GlassIPACell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
    }
    [cell configureWithIPAInfo:self.ipaFiles[indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell isKindOfClass:[GlassIPACell class]]) {
        [(GlassIPACell *)cell playEntranceAnimationWithDelay:MIN(indexPath.row * 0.045, 0.24)];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    IPAExtractedInfo *info = self.ipaFiles[indexPath.row];
    IPAInstallViewController *installVC = [[IPAInstallViewController alloc] initWithIPAInfo:info];
    [self.navigationController pushViewController:installVC animated:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:@"حذف"
                                                                             handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        IPAExtractedInfo *info = self.ipaFiles[indexPath.row];
        [[NSFileManager defaultManager] removeItemAtPath:info.filePath error:nil];
        dispatch_sync(self.ipaCacheQueue, ^{
            [self.ipaMetadataCache removeObjectForKey:info.filePath];
        });
        [self.ipaFiles removeObjectAtIndex:indexPath.row];
        [self updateDashboardStatistics];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        completionHandler(YES);
    }];
    deleteAction.backgroundColor = [UIColor colorWithRed:0.8 green:0.25 blue:0.2 alpha:1.0];

    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}


@end
