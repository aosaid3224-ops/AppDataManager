#import "MainViewController.h"
#import "IPAFileBrowserViewController.h"
#import "IPAInstallViewController.h"
#import "Core/IPAExtractor.h"
#import "Core/Logger.h"
#import "GlassIPACell.h"

@interface MainViewController () <UIDocumentPickerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *ipaFiles;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIView *toastView;
@property (nonatomic, strong) UILabel *toastLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *ipaMetadataCache;
@property (nonatomic, strong) dispatch_queue_t ipaCacheQueue;
@property (nonatomic, assign) NSUInteger ipaLoadGeneration;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"ملفات IPA";
    self.view.backgroundColor = [UIColor colorWithRed:0.012 green:0.014 blue:0.018 alpha:1.0];
    self.ipaFiles = [NSMutableArray array];
    self.isLoading = NO;
    self.ipaMetadataCache = [NSMutableDictionary dictionary];
    self.ipaCacheQueue = dispatch_queue_create("com.aosaid.ipainstallerpro.ipa-metadata-cache", DISPATCH_QUEUE_SERIAL);

    [self setupNavigationBar];
    [self setupTableView];
    [self setupEmptyState];
    [self setupAddButton];
    [self setupToast];
    [self setupLoadingIndicator];
    [self loadIPAFiles];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Don't reload here to avoid lag — use pull-to-refresh instead
}

- (void)setupNavigationBar {
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset = UIEdgeInsetsMake(6, 0, 54, 0);
    self.tableView.verticalScrollIndicatorInsets = UIEdgeInsetsMake(8, 0, 20, 0);
    self.tableView.rowHeight = 94;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:self.tableView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    [self.refreshControl addTarget:self action:@selector(refreshPulled:) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;
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
    addBtn.tintColor = [UIColor colorWithRed:0.96 green:0.08 blue:0.10 alpha:1.0];
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

    // Phase 1: enumerate files and show the list immediately. IPA parsing is
    // deliberately deferred so a large archive cannot block first paint.
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
                    [pending addObject:@{ @"path": path, @"key": cacheKey ?: @"", @"placeholder": placeholder }];
                }
            }
        }

        // Phase 1 UI commit: discovery is complete; do not wait for unzip/icon work.
        dispatch_async(dispatch_get_main_queue(), ^{
            if (loadGeneration != self.ipaLoadGeneration) return;
            [self.ipaFiles removeAllObjects];
            [self.ipaFiles addObjectsFromArray:foundFiles];
            [self.tableView reloadData];
            self.emptyLabel.hidden = (self.ipaFiles.count > 0);
            self.emptyLabel.frame = CGRectMake(20, self.view.bounds.size.height / 2 - 40, self.view.bounds.size.width - 40, 80);
            [self.refreshControl endRefreshing];
            [self.loadingIndicator stopAnimating];
            self.loadingIndicator.hidden = YES;
            self.isLoading = NO;
        });

        // Phase 2: enrich only uncached/changed files. Each result is committed
        // only if the file still has the same size, mtime and inode.
        if (pending.count == 0) return;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            for (NSDictionary *job in pending) {
                NSString *path = job[@"path"];
                NSString *originalKey = job[@"key"];
                IPAExtractedInfo *parsed = [[IPAExtractor sharedExtractor] extractInfoFromIPA:path];
                if (!parsed) continue;

                NSDictionary *currentAttrs = [fm attributesOfItemAtPath:path error:nil];
                NSString *currentKey = [self ipaCacheKeyForPath:path attributes:currentAttrs];
                if (![currentKey isEqualToString:originalKey]) continue;

                dispatch_sync(self.ipaCacheQueue, ^{
                    self.ipaMetadataCache[path] = @{ @"key": originalKey, @"info": parsed };
                });

                dispatch_async(dispatch_get_main_queue(), ^{
                    if (loadGeneration != self.ipaLoadGeneration) return;
                    NSUInteger index = [self.ipaFiles indexOfObjectPassingTest:^BOOL(IPAExtractedInfo *obj, NSUInteger idx, BOOL *stop) {
                        return [obj.filePath isEqualToString:path];
                    }];
                    if (index != NSNotFound) {
                        self.ipaFiles[index] = parsed;
                        [self.tableView reloadData];
                    }
                });
            }
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
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        completionHandler(YES);
    }];
    deleteAction.backgroundColor = [UIColor colorWithRed:0.8 green:0.25 blue:0.2 alpha:1.0];

    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}

@end
