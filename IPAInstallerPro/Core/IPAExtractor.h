#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface IPAExtractedInfo : NSObject
@property (nonatomic, strong) NSString *bundleID;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, strong) NSString *version;
@property (nonatomic, strong) NSString *buildVersion;
@property (nonatomic, strong) NSString *minOSVersion;
@property (nonatomic, strong) NSString *bundleExecutable;
@property (nonatomic, strong) NSString *teamIdentifier;
@property (nonatomic, strong) UIImage *icon;
@property (nonatomic, strong) NSNumber *fileSize;
@property (nonatomic, strong) NSString *formattedSize;
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSArray<NSString *> *supportedDevices;
@property (nonatomic, strong) NSArray<NSString *> *architectures;
@property (nonatomic, strong) NSString *appDirectoryPath;
@property (nonatomic, strong) NSDictionary *rawInfoPlist;
@property (nonatomic, strong) NSDate *modifiedDate;
@end

@interface IPAExtractor (Performance)
- (IPAExtractedInfo *)extractMetadataFromIPA:(NSString *)ipaPath;
- (UIImage *)extractIconFromIPA:(NSString *)ipaPath;
@end

@interface IPAExtractor : NSObject
+ (instancetype)sharedExtractor;
- (IPAExtractedInfo *)extractInfoFromIPA:(NSString *)ipaPath;
- (UIImage *)extractIconFromAppDirectory:(NSString *)appDir infoPlist:(NSDictionary *)plist;
- (NSString *)formatFileSize:(long long)bytes;
@end
