//
// IPAStructuralResult.h
// IPAInstallerPro — Phase 1: Universal IPA Structural Reader
//
// Structured result model for IPA structural analysis.
// All data is factual. No decisions. No strategies.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, IPAStructuralParseStatus) {
    IPAStructuralParseNotAttempted = 0,
    IPAStructuralParseSuccess = 1,
    IPAStructuralParsePartial = 2,
    IPAStructuralParseFailed = 3
};

#pragma mark - Bundle

@interface IPAStructuralBundle : NSObject
@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) NSString *bundleType;       // .app, .appex, .xpc, .framework, .bundle
@property (nonatomic, strong) NSString *bundleIdentifier;
@property (nonatomic, strong) NSString *executableName;
@property (nonatomic, strong) NSString *executablePath;
@property (nonatomic, assign) BOOL executableExists;
@property (nonatomic, strong) NSString *parentBundlePath;
@property (nonatomic, assign) NSInteger nestingLevel;
- (NSDictionary *)dictionaryRepresentation;
@end

#pragma mark - Executable Slice

@interface IPAStructuralExecutableSlice : NSObject
@property (nonatomic, assign) uint32_t cputype;
@property (nonatomic, assign) uint32_t cpusubtype;
@property (nonatomic, assign) uint64_t offset;
@property (nonatomic, assign) uint64_t size;
@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSString *architectureName;
- (NSDictionary *)dictionaryRepresentation;
@end

#pragma mark - Dependency

@interface IPAStructuralDependency : NSObject
@property (nonatomic, strong) NSString *rawInstallName;
@property (nonatomic, assign) BOOL isWeak;
@property (nonatomic, strong) NSString *sourceExecutablePath;
- (NSDictionary *)dictionaryRepresentation;
@end

#pragma mark - RPath

@interface IPAStructuralRPath : NSObject
@property (nonatomic, strong) NSString *rawPath;
@property (nonatomic, strong) NSString *sourceExecutablePath;
- (NSDictionary *)dictionaryRepresentation;
@end

#pragma mark - Load Command

@interface IPAStructuralLoadCommand : NSObject
@property (nonatomic, assign) uint32_t cmd;
@property (nonatomic, assign) uint32_t cmdsize;
@property (nonatomic, strong) NSString *cmdDescription;
- (NSDictionary *)dictionaryRepresentation;
@end

#pragma mark - Executable

@interface IPAStructuralExecutable : NSObject
@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) unsigned long long fileSize;
@property (nonatomic, assign) uint32_t machOType;
@property (nonatomic, strong) NSString *machOTypeName;
@property (nonatomic, strong) NSArray<IPAStructuralExecutableSlice *> *slices;
@property (nonatomic, strong) NSArray<IPAStructuralDependency *> *dependencies;
@property (nonatomic, strong) NSArray<IPAStructuralRPath *> *rpaths;
@property (nonatomic, strong) NSArray<IPAStructuralLoadCommand *> *loadCommands;
@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSString *minOSVersion;
@property (nonatomic, strong) NSString *sdkVersion;
@property (nonatomic, assign) uint32_t platform;
@property (nonatomic, strong) NSString *platformName;
@property (nonatomic, assign) BOOL hasCodeSignature;
@property (nonatomic, assign) IPAStructuralParseStatus parseStatus;
@property (nonatomic, strong) NSString *parseError;
- (NSDictionary *)dictionaryRepresentation;
@end

#pragma mark - Result

@interface IPAStructuralResult : NSObject
@property (nonatomic, strong) NSString *ipaPath;
@property (nonatomic, strong) NSString *extractPath;
@property (nonatomic, assign) unsigned long long ipaSize;
@property (nonatomic, strong) NSArray<IPAStructuralBundle *> *bundles;
@property (nonatomic, strong) NSArray<IPAStructuralExecutable *> *executables;
@property (nonatomic, strong) NSMutableArray<NSString *> *errors;
@property (nonatomic, strong) NSMutableArray<NSString *> *warnings;
@property (nonatomic, assign) NSTimeInterval analysisDurationMs;
@property (nonatomic, strong) NSDate *analysisStartTime;
@property (nonatomic, strong) NSDate *analysisEndTime;
@property (nonatomic, assign) BOOL success;

// Summary counters (raw facts)
@property (nonatomic, assign) NSInteger bundleCount;
@property (nonatomic, assign) NSInteger executableCount;
@property (nonatomic, assign) NSInteger frameworkCount;
@property (nonatomic, assign) NSInteger dylibCount;
@property (nonatomic, assign) NSInteger appexCount;
@property (nonatomic, assign) NSInteger xpcCount;
@property (nonatomic, assign) NSInteger dependencyCount;
@property (nonatomic, assign) NSInteger rpathCount;
@property (nonatomic, assign) NSInteger sliceCount;

- (NSDictionary *)dictionaryRepresentation;
- (NSString *)jsonRepresentation;
- (NSString *)summaryReport;
@end
