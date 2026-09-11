#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Minimal, read-only IPA ZIP reader used as a RootHide-safe fallback.
/// It extracts only Payload/*.app/Info.plist and never writes outside memory.
@interface IPAZipReader : NSObject
+ (nullable NSData *)extractInfoPlistDataFromIPA:(NSString *)ipaPath;
@end

NS_ASSUME_NONNULL_END
