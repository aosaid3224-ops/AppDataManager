//
// ForensicDifferentialAnalyzer.h
// IPA Installer Pro — Diagnostic/Forensic Mode
//
// Read-only comparison of two IPA packages. It never installs, signs, registers,
// or changes either input.
//

#import <Foundation/Foundation.h>
@class IPAStructuralResult;

@interface ForensicDifferentialAnalyzer : NSObject
+ (instancetype)sharedAnalyzer;

/// Analyzes both packages and returns a normalized, path-independent diff.
/// The result contains raw structural facts from both sides and categorized
/// differences. No installation policy is inferred.
- (NSDictionary *)compareWorkingIPA:(NSString *)workingIPA
                          crashIPA:(NSString *)crashIPA;

- (NSString *)reportForComparison:(NSDictionary *)comparison;
@end
