#import "IPAZipReader.h"
#import <zlib.h>
#include <stdint.h>
#include <string.h>

static uint16_t IPAReadLE16(const uint8_t *p) {
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static uint32_t IPAReadLE32(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static BOOL IPAIsInfoPlistEntry(NSString *entry) {
    if (entry.length == 0) return NO;
    NSString *lower = entry.lowercaseString;
    if (![lower hasPrefix:@"payload/"] || ![lower hasSuffix:@"/info.plist"]) return NO;
    NSArray<NSString *> *parts = [entry pathComponents];
    return parts.count == 3 && [parts[1].lowercaseString hasSuffix:@".app"];
}

static NSData *IPAInflateRaw(NSData *compressed, NSUInteger expectedLength) {
    if (compressed.length == 0 || expectedLength == 0 || expectedLength > (128ULL * 1024ULL * 1024ULL)) return nil;

    NSMutableData *output = [NSMutableData dataWithLength:expectedLength];
    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    stream.next_in = (Bytef *)compressed.bytes;
    stream.avail_in = (uInt)MIN(compressed.length, UINT_MAX);
    stream.next_out = (Bytef *)output.mutableBytes;
    stream.avail_out = (uInt)MIN(output.length, UINT_MAX);

    if (inflateInit2(&stream, -MAX_WBITS) != Z_OK) return nil;
    int result = inflate(&stream, Z_FINISH);
    BOOL complete = (result == Z_STREAM_END && stream.total_out == expectedLength);
    inflateEnd(&stream);
    return complete ? output : nil;
}

@implementation IPAZipReader

+ (NSData *)extractInfoPlistDataFromIPA:(NSString *)ipaPath {
    if (ipaPath.length == 0) return nil;
    NSData *archive = [NSData dataWithContentsOfFile:ipaPath options:NSDataReadingMappedIfSafe error:nil];
    if (archive.length < 22) return nil;

    const uint8_t *bytes = archive.bytes;
    NSUInteger length = archive.length;
    NSUInteger searchStart = length > (0xFFFF + 22) ? length - (0xFFFF + 22) : 0;
    NSUInteger eocd = NSNotFound;
    for (NSUInteger cursor = length - 22;; cursor--) {
        if (IPAReadLE32(bytes + cursor) == 0x06054b50) {
            eocd = cursor;
            break;
        }
        if (cursor == searchStart) break;
    }
    if (eocd == NSNotFound || eocd + 22 > length) return nil;

    uint16_t entryCount = IPAReadLE16(bytes + eocd + 10);
    uint32_t centralSize = IPAReadLE32(bytes + eocd + 12);
    uint32_t centralOffset = IPAReadLE32(bytes + eocd + 16);
    if (entryCount == 0 || centralOffset > length || centralSize > length - centralOffset) return nil;

    NSUInteger cursor = centralOffset;
    NSString *bestEntry = nil;
    uint32_t bestLocalOffset = 0;
    uint16_t bestMethod = 0;
    uint32_t bestCompressedSize = 0;
    uint32_t bestUncompressedSize = 0;

    for (uint16_t index = 0; index < entryCount && cursor + 46 <= length; index++) {
        if (IPAReadLE32(bytes + cursor) != 0x02014b50) break;
        uint16_t method = IPAReadLE16(bytes + cursor + 10);
        uint32_t compressedSize = IPAReadLE32(bytes + cursor + 20);
        uint32_t uncompressedSize = IPAReadLE32(bytes + cursor + 24);
        uint16_t nameLength = IPAReadLE16(bytes + cursor + 28);
        uint16_t extraLength = IPAReadLE16(bytes + cursor + 30);
        uint16_t commentLength = IPAReadLE16(bytes + cursor + 32);
        uint32_t localOffset = IPAReadLE32(bytes + cursor + 42);
        NSUInteger recordLength = 46ULL + nameLength + extraLength + commentLength;
        if (recordLength > length - cursor) break;

        NSString *entry = [[NSString alloc] initWithBytes:bytes + cursor + 46 length:nameLength encoding:NSUTF8StringEncoding];
        if (IPAIsInfoPlistEntry(entry) && (!bestEntry || entry.length < bestEntry.length)) {
            bestEntry = entry;
            bestLocalOffset = localOffset;
            bestMethod = method;
            bestCompressedSize = compressedSize;
            bestUncompressedSize = uncompressedSize;
        }
        cursor += recordLength;
    }

    if (!bestEntry || bestLocalOffset > length || bestLocalOffset + 30 > length) return nil;
    if (IPAReadLE32(bytes + bestLocalOffset) != 0x04034b50) return nil;
    uint16_t localNameLength = IPAReadLE16(bytes + bestLocalOffset + 26);
    uint16_t localExtraLength = IPAReadLE16(bytes + bestLocalOffset + 28);
    NSUInteger dataOffset = (NSUInteger)bestLocalOffset + 30ULL + localNameLength + localExtraLength;
    if (dataOffset > length || bestCompressedSize > length - dataOffset) return nil;

    NSData *compressed = [archive subdataWithRange:NSMakeRange(dataOffset, bestCompressedSize)];
    NSData *plistData = nil;
    if (bestMethod == 0) {
        plistData = compressed;
    } else if (bestMethod == 8) {
        plistData = IPAInflateRaw(compressed, bestUncompressedSize);
    }
    if (plistData.length == 0) return nil;

    id plist = [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListImmutable format:nil error:nil];
    return [plist isKindOfClass:[NSDictionary class]] ? plistData : nil;
}

@end
