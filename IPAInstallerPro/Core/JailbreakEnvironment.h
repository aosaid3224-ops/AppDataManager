//
//  JailbreakEnvironment.h
//  IPAInstallerPro — Commit 4: Diagnostics Fix
//
//  CHANGES:
//  - Added iosVersion and architecture properties.
//  - Kept all existing properties for backward compatibility.
//

#import <Foundation/Foundation.h>

@interface JailbreakEnvironment : NSObject

+ (instancetype)sharedEnvironment;
- (void)detectEnvironment;

@property (readonly, nonatomic) BOOL isJailbroken;
@property (readonly, nonatomic) BOOL isRootless;
@property (readonly, nonatomic) NSString *jailbreakType;
@property (readonly, nonatomic) NSString *rootPath;

@property (readonly, nonatomic) NSString *applicationsPath;
@property (readonly, nonatomic) NSString *usrBinPath;
@property (readonly, nonatomic) NSString *mobileDocumentsPath;

@property (readonly, nonatomic) NSString *osVersion;      // Alias for iosVersion (backward compat)
@property (readonly, nonatomic) NSString *deviceModel;    // From UIDevice
@property (readonly, nonatomic) NSString *iosVersion;     // From NSProcessInfo
@property (readonly, nonatomic) NSString *architecture;   // From uname/sysctl

@property (readonly, nonatomic) id lsApplicationWorkspace;

@end
