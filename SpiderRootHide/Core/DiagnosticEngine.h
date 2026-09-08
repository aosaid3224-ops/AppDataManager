//
//  DiagnosticEngine.h
//  IPAInstallerPro
//
//  Evidence-based diagnostic system for IPA installation failures
//

#import <Foundation/Foundation.h>

@interface DiagnosticReport : NSObject
@property (nonatomic, strong) NSString *bundleID;
@property (nonatomic, strong) NSArray *postInstallIssues;
@property (nonatomic, strong) NSDictionary *filesystemAudit;
@property (nonatomic, strong) NSString *rootCause;
@property (nonatomic, assign) BOOL canLaunch;
@end

@interface DiagnosticEngine : NSObject
+ (instancetype)sharedEngine;
- (DiagnosticReport *)diagnoseInstalledApp:(NSString *)appPath bundleID:(NSString *)bundleID;
- (void)logReport:(DiagnosticReport *)report;
@end
