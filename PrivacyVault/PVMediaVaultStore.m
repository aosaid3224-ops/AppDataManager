#import "PVMediaVaultStore.h"

static NSString * const PVMediaVaultErrorDomain = @"com.aosaid.privacyvault.media-vault";
static NSString * const PVMediaVaultMetadataFilename = @"com.aosaid.privacyvault.media.plist";
static NSString * const PVMediaVaultDirectoryName = @"PrivacyVaultMedia";

@implementation PVMediaVaultItem

+ (instancetype)itemFromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;
    NSString *identifier = dictionary[@"identifier"];
    NSString *filename = dictionary[@"filename"];
    NSString *type = dictionary[@"type"];
    NSString *path = dictionary[@"path"];
    NSNumber *size = dictionary[@"byteSize"];
    if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0 ||
        ![filename isKindOfClass:[NSString class]] || filename.length == 0 ||
        ![type isKindOfClass:[NSString class]] || ![path isKindOfClass:[NSString class]] ||
        ![size isKindOfClass:[NSNumber class]]) return nil;
    PVMediaVaultItem *item = [[self alloc] init];
    item.identifier = identifier;
    item.filename = filename;
    item.type = type;
    item.path = path;
    item.byteSize = size.unsignedIntegerValue;
    return item;
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"identifier": self.identifier ?: @"",
        @"filename": self.filename ?: @"",
        @"type": self.type ?: @"",
        @"path": self.path ?: @"",
        @"byteSize": @(self.byteSize)
    };
}

@end

@interface PVMediaVaultStore ()
- (NSString *)libraryDirectory;
- (NSString *)vaultDirectory;
- (NSString *)metadataPath;
- (NSMutableArray<PVMediaVaultItem *> *)mutableItems;
- (BOOL)writeItems:(NSArray<PVMediaVaultItem *> *)items error:(NSError **)error;
- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description;
@end

@implementation PVMediaVaultStore

+ (instancetype)sharedStore {
    static PVMediaVaultStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ store = [[self alloc] init]; });
    return store;
}

- (NSArray<PVMediaVaultItem *> *)items {
    NSArray *rawItems = [NSArray arrayWithContentsOfFile:[self metadataPath]];
    if (![rawItems isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *dictionary in rawItems) {
        PVMediaVaultItem *item = [PVMediaVaultItem itemFromDictionary:dictionary];
        if (item) [items addObject:item];
    }
    return [items copy];
}

- (BOOL)importFileAtURL:(NSURL *)sourceURL identifier:(NSString *)identifier type:(NSString *)type originalFilename:(NSString *)originalFilename error:(NSError **)error {
    if (!sourceURL.isFileURL || identifier.length == 0 || type.length == 0) {
        if (error) *error = [self errorWithCode:1 description:@"بيانات العنصر غير صالحة"];
        return NO;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *fileError = nil;
    if (![fileManager createDirectoryAtPath:[self vaultDirectory] withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0700} error:&fileError]) {
        if (error) *error = fileError ?: [self errorWithCode:2 description:@"تعذر إنشاء مساحة PrivacyVault"];
        return NO;
    }

    NSString *extension = originalFilename.pathExtension.lowercaseString;
    NSString *storedFilename = [NSString stringWithFormat:@"%@%@", [[NSUUID UUID] UUIDString], extension.length ? [@"." stringByAppendingString:extension] : @""];
    NSString *destinationPath = [[self vaultDirectory] stringByAppendingPathComponent:storedFilename];
    NSString *temporaryPath = [destinationPath stringByAppendingString:@".partial"];
    [fileManager removeItemAtPath:temporaryPath error:nil];
    if (![fileManager copyItemAtURL:sourceURL toURL:[NSURL fileURLWithPath:temporaryPath] error:&fileError]) {
        if (error) *error = fileError ?: [self errorWithCode:3 description:@"تعذر نسخ العنصر إلى PrivacyVault"];
        return NO;
    }
    NSDictionary *attributes = [fileManager attributesOfItemAtPath:temporaryPath error:&fileError];
    unsigned long long byteSize = [attributes fileSize];
    if (byteSize == 0 || ![fileManager moveItemAtPath:temporaryPath toPath:destinationPath error:&fileError]) {
        [fileManager removeItemAtPath:temporaryPath error:nil];
        if (error) *error = fileError ?: [self errorWithCode:4 description:@"تم نسخ ملف فارغ أو غير صالح"];
        return NO;
    }

    PVMediaVaultItem *item = [[PVMediaVaultItem alloc] init];
    item.identifier = identifier;
    item.filename = originalFilename.lastPathComponent.length ? originalFilename.lastPathComponent : storedFilename;
    item.type = type;
    item.path = storedFilename;
    item.byteSize = (NSUInteger)byteSize;
    if (![self verifyItem:item error:&fileError]) {
        [fileManager removeItemAtPath:destinationPath error:nil];
        if (error) *error = fileError ?: [self errorWithCode:5 description:@"تعذر التحقق من العنصر المنسوخ"];
        return NO;
    }

    NSMutableArray *items = [self mutableItems];
    [items addObject:item];
    if (![self writeItems:items error:&fileError]) {
        [fileManager removeItemAtPath:destinationPath error:nil];
        if (error) *error = fileError ?: [self errorWithCode:6 description:@"تعذر حفظ سجل العنصر"];
        return NO;
    }
    return YES;
}

- (BOOL)verifyItem:(PVMediaVaultItem *)item error:(NSError **)error {
    if (!item || item.path.length == 0 || item.byteSize == 0) {
        if (error) *error = [self errorWithCode:7 description:@"بيانات العنصر المخفي غير مكتملة"];
        return NO;
    }
    NSString *path = [[self vaultDirectory] stringByAppendingPathComponent:item.path.lastPathComponent];
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    unsigned long long actualSize = [attributes fileSize];
    if (!attributes || actualSize == 0 || actualSize != item.byteSize) {
        if (error) *error = [self errorWithCode:8 description:@"العنصر المخفي غير موجود أو غير مكتمل"];
        return NO;
    }
    return YES;
}

- (NSURL *)urlForItem:(PVMediaVaultItem *)item {
    if (!item) return nil;
    return [NSURL fileURLWithPath:[[self vaultDirectory] stringByAppendingPathComponent:item.path.lastPathComponent]];
}

- (BOOL)removeItem:(PVMediaVaultItem *)item error:(NSError **)error {
    if (![self verifyItem:item error:error]) return NO;
    NSError *metadataError = nil;
    NSMutableArray *oldItems = [self mutableItems];
    NSMutableArray *newItems = [oldItems mutableCopy];
    NSIndexSet *indexes = [newItems indexesOfObjectsPassingTest:^BOOL(PVMediaVaultItem *candidate, NSUInteger idx, BOOL *stop) {
        return [candidate.identifier isEqualToString:item.identifier];
    }];
    if (indexes.count == 0) {
        if (error) *error = [self errorWithCode:10 description:@"العنصر غير موجود في سجل PrivacyVault"];
        return NO;
    }
    [newItems removeObjectsAtIndexes:indexes];

    // Commit metadata first. If it fails, the vault file is deliberately left untouched.
    if (![self writeItems:newItems error:&metadataError]) {
        if (error) *error = metadataError ?: [self errorWithCode:11 description:@"تعذر تحديث سجل PrivacyVault"];
        return NO;
    }

    NSError *fileError = nil;
    if (![[NSFileManager defaultManager] removeItemAtURL:[self urlForItem:item] error:&fileError]) {
        // Restore the metadata record so a failed deletion never loses the vault reference.
        [self writeItems:oldItems error:nil];
        if (error) *error = fileError ?: [self errorWithCode:12 description:@"تعذر إزالة نسخة PrivacyVault"];
        return NO;
    }
    return YES;
}

- (NSString *)libraryDirectory {
    NSString *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    return library.length ? library : @"/var/mobile/Library";
}

- (NSString *)vaultDirectory {
    return [[self libraryDirectory] stringByAppendingPathComponent:PVMediaVaultDirectoryName];
}

- (NSString *)metadataPath {
    NSString *preferences = [[self libraryDirectory] stringByAppendingPathComponent:@"Preferences"];
    return [preferences stringByAppendingPathComponent:PVMediaVaultMetadataFilename];
}

- (NSMutableArray<PVMediaVaultItem *> *)mutableItems {
    return [[self items] mutableCopy] ?: [NSMutableArray array];
}

- (BOOL)writeItems:(NSArray<PVMediaVaultItem *> *)items error:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *preferences = [[self libraryDirectory] stringByAppendingPathComponent:@"Preferences"];
    NSError *directoryError = nil;
    if (![fileManager createDirectoryAtPath:preferences withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0700} error:&directoryError]) {
        if (error) *error = directoryError ?: [self errorWithCode:11 description:@"تعذر إنشاء سجل PrivacyVault"];
        return NO;
    }
    NSMutableArray *rawItems = [NSMutableArray arrayWithCapacity:items.count];
    for (PVMediaVaultItem *item in items) [rawItems addObject:item.dictionaryRepresentation];
    if (![rawItems writeToFile:[self metadataPath] atomically:YES]) {
        if (error) *error = [self errorWithCode:12 description:@"تعذر حفظ سجل PrivacyVault"];
        return NO;
    }
    [fileManager setAttributes:@{NSFilePosixPermissions: @0600, NSFileProtectionKey: NSFileProtectionComplete} ofItemAtPath:[self metadataPath] error:nil];
    [fileManager setAttributes:@{NSFilePosixPermissions: @0700} ofItemAtPath:[self vaultDirectory] error:nil];
    return YES;
}

- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description {
    return [NSError errorWithDomain:PVMediaVaultErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: description}];
}

@end
