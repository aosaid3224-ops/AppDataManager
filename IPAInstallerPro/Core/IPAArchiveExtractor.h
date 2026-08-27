#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class IPAArchiveExtractionResult;
typedef void (^IPAArchiveExtractionProgress)(double progress, NSString *status);
typedef void (^IPAArchiveExtractionCompletion)(IPAArchiveExtractionResult *result);

@interface IPAArchiveExtractionResult : NSObject
@property (nonatomic, assign, getter=isSuccess) BOOL success;
@property (nonatomic, copy) NSString *sourcePath;
@property (nonatomic, copy, nullable) NSString *outputPath;
@property (nonatomic, copy) NSString *statusMessage;
@property (nonatomic, copy) NSString *errorMessage;
@property (nonatomic, assign) NSUInteger extractedEntryCount;
@property (nonatomic, assign) unsigned long long extractedByteCount;
@end

@interface IPAArchiveExtractor : NSObject
+ (instancetype)sharedExtractor;
- (NSString *)defaultOutputDirectoryForIPAPath:(NSString *)ipaPath;
- (NSString *)uniqueOutputDirectoryForIPAPath:(NSString *)ipaPath;
- (void)extractIPAAtPath:(NSString *)ipaPath
              outputPath:(NSString *)outputPath
                progress:(nullable IPAArchiveExtractionProgress)progress
              completion:(IPAArchiveExtractionCompletion)completion;
@end

NS_ASSUME_NONNULL_END
