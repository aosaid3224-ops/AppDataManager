#import "MachORPathRepair.h"
#import <mach-o/loader.h>
#import <mach-o/fat.h>

#define PV_LC_REQ_DYLD 0x80000000U
#define PV_LC_RPATH 0x1cU
#define PV_LC_LOAD_DYLIB 0x0cU
#define PV_LC_ID_DYLIB 0x0dU
#define PV_LC_LOAD_WEAK_DYLIB 0x18U
#define PV_LC_REEXPORT_DYLIB 0x1fU
#define PV_LC_LAZY_LOAD_DYLIB 0x20U
#define PV_LC_LOAD_UPWARD_DYLIB 0x23U

static uint32_t pvRead32(const uint8_t *bytes, BOOL swap) {
    uint32_t value = 0;
    memcpy(&value, bytes, sizeof(value));
    return swap ? CFSwapInt32(value) : value;
}

@interface MachORPathRepair ()
- (BOOL)repairMutableData:(NSMutableData *)data
             binaryPath:(NSString *)binaryPath
                appPath:(NSString *)appPath
               changed:(BOOL *)changed
          detectedUnsafe:(BOOL *)detectedUnsafe
                  error:(NSString **)error;
@end

@implementation MachORPathRepair

+ (instancetype)sharedRepair {
    static MachORPathRepair *repair = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        repair = [[self alloc] init];
    });
    return repair;
}

- (BOOL)isClearlyNonPortableRPath:(NSString *)path {
    if (path.length == 0) return NO;
    NSArray<NSString *> *hostPrefixes = @[
        @"/nix/store/",
        @"/Users/",
        @"/home/",
        @"/Volumes/",
        @"/private/var/folders/"
    ];
    for (NSString *prefix in hostPrefixes) {
        if ([path hasPrefix:prefix]) return YES;
    }
    return NO;
}

- (NSString *)portableRPathForBinary:(NSString *)binaryPath appPath:(NSString *)appPath {
    NSString *lower = binaryPath.lowercaseString;
    if ([lower containsString:@".appex/"] || [lower containsString:@".xpc/"]) {
        return @"@executable_path/../../Frameworks";
    }
    if ([lower containsString:@".framework/"]) {
        return @"@loader_path/..";
    }
    if ([binaryPath isEqualToString:[appPath stringByAppendingPathComponent:[appPath.lastPathComponent stringByDeletingPathExtension]]]) {
        return @"@executable_path/Frameworks";
    }
    return @"@loader_path/..";
}

- (BOOL)patchRPathCommandAt:(uint8_t *)command
                  commandSize:(uint32_t)commandSize
                      swapped:(BOOL)swap
                   binaryPath:(NSString *)binaryPath
                      appPath:(NSString *)appPath
                      changed:(BOOL *)changed
                 detectedUnsafe:(BOOL *)detectedUnsafe
                         error:(NSString **)error {
    if (commandSize < 12) return YES;
    uint32_t pathOffset = pvRead32(command + 8, swap);
    if (pathOffset >= commandSize) return YES;

    uint32_t maxLength = commandSize - pathOffset;
    const char *pathBytes = (const char *)(command + pathOffset);
    NSUInteger length = 0;
    while (length < maxLength && pathBytes[length] != '\0') length++;
    if (length == maxLength) return YES;

    NSString *original = [[NSString alloc] initWithBytes:pathBytes length:length encoding:NSUTF8StringEncoding];
    if (![self isClearlyNonPortableRPath:original]) return YES;
    if (detectedUnsafe) *detectedUnsafe = YES;

    NSString *replacement = [self portableRPathForBinary:binaryPath appPath:appPath];
    NSData *replacementData = [replacement dataUsingEncoding:NSUTF8StringEncoding];
    if (replacementData.length + 1 > maxLength) {
        if (error) {
            *error = [NSString stringWithFormat:@"Unsafe LC_RPATH is too short to replace: %@ -> %@", original, replacement];
        }
        return NO;
    }

    memset(command + pathOffset, 0, maxLength);
    memcpy(command + pathOffset, replacementData.bytes, replacementData.length);
    if (changed) *changed = YES;
    NSLog(@"[MachORPathRepair] %@: %@ -> %@", binaryPath, original, replacement);
    return YES;
}

- (BOOL)repairThinSliceInData:(NSMutableData *)data
                         offset:(NSUInteger)offset
                          length:(NSUInteger)length
                     binaryPath:(NSString *)binaryPath
                        appPath:(NSString *)appPath
                        changed:(BOOL *)changed
                   detectedUnsafe:(BOOL *)detectedUnsafe
                           error:(NSString **)error {
    if (offset + 4 > data.length || offset + length > data.length || length < sizeof(struct mach_header)) return YES;
    uint8_t *base = data.mutableBytes;
    uint32_t rawMagic = 0;
    memcpy(&rawMagic, base + offset, sizeof(rawMagic));

    BOOL is64 = (rawMagic == MH_MAGIC_64 || rawMagic == MH_CIGAM_64);
    BOOL is32 = (rawMagic == MH_MAGIC || rawMagic == MH_CIGAM);
    if (!is64 && !is32) return YES;
    BOOL swap = (rawMagic == MH_CIGAM || rawMagic == MH_CIGAM_64);
    NSUInteger headerSize = is64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header);
    if (length < headerSize) return YES;

    uint8_t *header = base + offset;
    uint32_t commandCount = pvRead32(header + 16, swap);
    uint32_t commandsSize = pvRead32(header + 20, swap);
    if (headerSize + commandsSize > length) {
        if (error) *error = [NSString stringWithFormat:@"Invalid Mach-O load-command range: %@", binaryPath];
        return NO;
    }

    NSUInteger commandOffset = offset + headerSize;
    NSUInteger commandEnd = commandOffset + commandsSize;
    for (uint32_t index = 0; index < commandCount; index++) {
        if (commandOffset + 8 > commandEnd) {
            if (error) *error = [NSString stringWithFormat:@"Truncated Mach-O load command: %@", binaryPath];
            return NO;
        }
        uint8_t *command = base + commandOffset;
        uint32_t commandType = pvRead32(command, swap);
        uint32_t commandSize = pvRead32(command + 4, swap);
        if (commandSize < 8 || commandOffset + commandSize > commandEnd) {
            if (error) *error = [NSString stringWithFormat:@"Invalid Mach-O command size: %@", binaryPath];
            return NO;
        }
        uint32_t baseCommand = commandType & ~PV_LC_REQ_DYLD;
        if (baseCommand == PV_LC_RPATH) {
            if (![self patchRPathCommandAt:command commandSize:commandSize swapped:swap binaryPath:binaryPath appPath:appPath changed:changed detectedUnsafe:detectedUnsafe error:error]) return NO;
        }
        commandOffset += commandSize;
    }
    return YES;
}

- (BOOL)repairMutableData:(NSMutableData *)data
               binaryPath:(NSString *)binaryPath
                  appPath:(NSString *)appPath
                 changed:(BOOL *)changed
            detectedUnsafe:(BOOL *)detectedUnsafe
                    error:(NSString **)error {
    if (data.length < 4) return YES;
    uint8_t *bytes = data.mutableBytes;
    uint32_t rawMagic = 0;
    memcpy(&rawMagic, bytes, sizeof(rawMagic));

    if (rawMagic == FAT_MAGIC || rawMagic == FAT_CIGAM || rawMagic == FAT_MAGIC_64 || rawMagic == FAT_CIGAM_64) {
        BOOL fat64 = (rawMagic == FAT_MAGIC_64 || rawMagic == FAT_CIGAM_64);
        BOOL swap = (rawMagic == FAT_CIGAM || rawMagic == FAT_CIGAM_64);
        if (data.length < 8) return YES;
        uint32_t count = pvRead32(bytes + 4, swap);
        NSUInteger entrySize = fat64 ? sizeof(struct fat_arch_64) : sizeof(struct fat_arch);
        NSUInteger tableEnd = 8 + ((NSUInteger)count * entrySize);
        if (tableEnd > data.length) {
            if (error) *error = [NSString stringWithFormat:@"Invalid FAT Mach-O table: %@", binaryPath];
            return NO;
        }
        for (uint32_t i = 0; i < count; i++) {
            uint8_t *entry = bytes + 8 + ((NSUInteger)i * entrySize);
            uint64_t sliceOffset = 0;
            uint64_t sliceSize = 0;
            if (fat64) {
                uint64_t rawOffset = 0, rawSize = 0;
                memcpy(&rawOffset, entry + 8, sizeof(rawOffset));
                memcpy(&rawSize, entry + 16, sizeof(rawSize));
                if (swap) {
                    rawOffset = CFSwapInt64(rawOffset);
                    rawSize = CFSwapInt64(rawSize);
                }
                sliceOffset = rawOffset;
                sliceSize = rawSize;
            } else {
                sliceOffset = pvRead32(entry + 8, swap);
                sliceSize = pvRead32(entry + 12, swap);
            }
            if (sliceOffset > data.length || sliceSize > data.length - sliceOffset) {
                if (error) *error = [NSString stringWithFormat:@"Invalid FAT Mach-O slice: %@", binaryPath];
                return NO;
            }
            if (![self repairThinSliceInData:data offset:(NSUInteger)sliceOffset length:(NSUInteger)sliceSize binaryPath:binaryPath appPath:appPath changed:changed detectedUnsafe:detectedUnsafe error:error]) return NO;
        }
        return YES;
    }

    return [self repairThinSliceInData:data offset:0 length:data.length binaryPath:binaryPath appPath:appPath changed:changed detectedUnsafe:detectedUnsafe error:error];
}

- (BOOL)repairAppAtPath:(NSString *)appPath
          changedPaths:(NSArray<NSString *> **)changedPaths
                 error:(NSString **)error {
    if (changedPaths) *changedPaths = @[];
    if (error) *error = nil;
    if (appPath.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:appPath]) {
        if (error) *error = @"App bundle does not exist";
        return NO;
    }

    NSMutableArray<NSString *> *changed = [NSMutableArray array];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:appPath];
    NSString *relativePath = nil;
    while ((relativePath = [enumerator nextObject])) {
        NSString *fullPath = [appPath stringByAppendingPathComponent:relativePath];
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:nil];
        if ([attributes[NSFileType] isEqualToString:NSFileTypeSymbolicLink] || [attributes[NSFileType] isEqualToString:NSFileTypeDirectory]) continue;

        NSData *original = [NSData dataWithContentsOfFile:fullPath options:NSDataReadingMappedIfSafe error:nil];
        if (original.length < 4) continue;
        uint32_t rawMagic = 0;
        [original getBytes:&rawMagic length:sizeof(rawMagic)];
        BOOL isMachO = (rawMagic == MH_MAGIC || rawMagic == MH_CIGAM || rawMagic == MH_MAGIC_64 || rawMagic == MH_CIGAM_64 || rawMagic == FAT_MAGIC || rawMagic == FAT_CIGAM || rawMagic == FAT_MAGIC_64 || rawMagic == FAT_CIGAM_64);
        if (!isMachO) continue;

        NSMutableData *mutableData = [original mutableCopy];
        BOOL fileChanged = NO;
        BOOL detectedUnsafe = NO;
        NSString *repairError = nil;
        if (![self repairMutableData:mutableData binaryPath:fullPath appPath:appPath changed:&fileChanged detectedUnsafe:&detectedUnsafe error:&repairError]) {
            if (error) *error = repairError ?: [NSString stringWithFormat:@"Unable to repair %@", fullPath];
            return NO;
        }
        if (detectedUnsafe && !fileChanged) {
            if (error) *error = [NSString stringWithFormat:@"Unsafe LC_RPATH detected but not repaired: %@", fullPath];
            return NO;
        }
        if (fileChanged) {
            if (![mutableData writeToFile:fullPath options:NSDataWritingAtomic error:nil]) {
                if (error) *error = [NSString stringWithFormat:@"Unable to write repaired Mach-O: %@", fullPath];
                return NO;
            }
            [changed addObject:fullPath];
        }
    }

    if (changedPaths) *changedPaths = [changed copy];
    return YES;
}

@end
