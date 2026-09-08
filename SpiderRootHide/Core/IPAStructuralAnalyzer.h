//
// IPAStructuralAnalyzer.h
// IPAInstallerPro — Phase 1: Universal IPA Structural Reader
//
// Read-only structural analyzer for any IPA.
// Extracts to temporary directory, analyzes, cleans up.
// Does NOT modify IPA. Does NOT install. Does NOT sign.
//

#import <Foundation/Foundation.h>
@class IPAStructuralResult;

@interface IPAStructuralAnalyzer : NSObject

+ (instancetype)sharedAnalyzer;

/// Analyze IPA at given path. Returns structured result.
/// This is a synchronous blocking call.
- (IPAStructuralResult *)analyzeIPAAtPath:(NSString *)ipaPath;

/// Analyze IPA with option to keep extracted files for inspection.
- (IPAStructuralResult *)analyzeIPAAtPath:(NSString *)ipaPath keepExtracted:(BOOL)keep;

/// Analyze an already extracted Payload tree without extracting the IPA again.
/// The caller owns the extraction directory and must keep it alive until analysis returns.
- (IPAStructuralResult *)analyzeExtractedPayloadAtPath:(NSString *)payloadPath sourceIPAPath:(NSString *)ipaPath;

@end
