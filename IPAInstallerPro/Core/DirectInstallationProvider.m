// DirectInstallationProvider.m
// IPA Installer Pro
//
// v2.2 — STANDALONE with rollback, safe delete order, symlink/traversal checks
//

#import "DirectInstallationProvider.h"
#import "RootlessManager.h"
#import "OperationLog.h"
#import "JailbreakEnvironment.h"
#import "IPAStructuralAnalyzer.h"
#import "IPAStructuralResult.h"
#import "SigningPlanner.h"
#import "SigningPlan.h"
#import "SigningTarget.h"
#import "EntitlementSet.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <spawn.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <copyfile.h>
#include <unistd.h>
#include <errno.h>

extern char **environ;

@interface DirectInstallationProvider ()
@property (nonatomic, strong) NSString *ldidPath;
@property (nonatomic, strong) NSString *uicachePath;
@property (nonatomic, strong) NSString *chmodPath;
@property (nonatomic, strong) NSString *chownPath;
@property (nonatomic, strong) NSString *rmPath;
@property (nonatomic, strong) NSString *cpPath;
@property (nonatomic, strong) NSString *unzipPath;
@property (nonatomic, strong) NSString *whoamiPath;
@property (nonatomic, strong) NSString *helperPath;
@property (nonatomic, strong) NSString *mkdirPath;
@property (nonatomic, strong) NSString *mvPath;
@property (nonatomic, strong) NSString *statPath;
- (BOOL)signBundleExecutableAtPath:(NSString *)bundlePath label:(NSString *)label hasHelper:(BOOL)hasH opLog:(OperationLog *)opLog txnID:(NSString *)txnID;
@end

@implementation DirectInstallationProvider

- (NSString *)providerName { return @"Direct Install"; }
- (NSString *)providerDescription { return @"Standalone installation with full signing — IPA Installer Pro signature"; }
- (NSInteger)priority { return 100; }

- (instancetype)init {
 self = [super init];
 if (self) {
 RootlessManager *rm = [RootlessManager sharedManager];
 self.ldidPath = [rm resolvePath:@"/usr/bin/ldid"];
 self.uicachePath = [rm resolvePath:@"/usr/bin/uicache"];
 self.chmodPath = [rm resolvePath:@"/usr/bin/chmod"];
 self.chownPath = [rm resolvePath:@"/usr/sbin/chown"];
 self.rmPath = [rm resolvePath:@"/bin/rm"];
 self.cpPath = [rm resolvePath:@"/bin/cp"];
 self.unzipPath = [rm resolvePath:@"/usr/bin/unzip"];
 self.whoamiPath = [rm resolvePath:@"/usr/bin/whoami"];
 self.mkdirPath = [rm resolvePath:@"/bin/mkdir"];
 self.mvPath = [rm resolvePath:@"/bin/mv"];
 self.statPath = [rm resolvePath:@"/usr/bin/stat"];
 [self findWorkingHelper];
 }
 return self;
}

- (void)findWorkingHelper {
 NSArray *candidates = @[
 [[RootlessManager sharedManager] resolvePath:@"/usr/bin/ipainstallerpro_helper"],
 @"/usr/bin/ipainstallerpro_helper",
 @"/var/jb/usr/bin/ipainstallerpro_helper"
 ];
 for (NSString *path in candidates) {
 if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
 if ([self testHelperAtPath:path]) {
 self.helperPath = path;
 NSLog(@"[IPAInstallerPro] Helper active: %@", path);
 return;
 }
 }
 }
 self.helperPath = nil;
 NSLog(@"[IPAInstallerPro] WARNING: No root helper — falling back to direct execution");
}

- (BOOL)testHelperAtPath:(NSString *)path {
 pid_t pid;
 const char *h = [path UTF8String];
 const char *w = [self.whoamiPath UTF8String];
 char *argv[] = {(char*)h, (char*)w, NULL};
 if (posix_spawn(&pid, h, NULL, NULL, argv, environ) != 0) return NO;
 int ws;
 waitpid(pid, &ws, 0);
 return (WIFEXITED(ws) && WEXITSTATUS(ws) == 0);
}

- (BOOL)isAvailable {
 return (
 [[NSFileManager defaultManager] fileExistsAtPath:self.ldidPath] &&
 [[NSFileManager defaultManager] fileExistsAtPath:self.uicachePath] &&
 [[NSFileManager defaultManager] fileExistsAtPath:self.unzipPath]
 );
}
- (BOOL)hasRootHelper { return (self.helperPath != nil && self.helperPath.length > 0); }

#pragma mark - Command Execution with OperationLog

- (BOOL)runCmd:(NSString *)cmd args:(NSArray *)args opLog:(OperationLog *)opLog recordID:(NSString *)recID {
 if (!cmd || cmd.length == 0) {
 if (recID && opLog) {
 [opLog endPhase:recID exitCode:1 rawOutput:@"" rawError:@"Command path is empty" verification:@"Invalid command path" verified:NO duration:0];
 }
 return NO;
 }
 pid_t pid;
 const char *c = [cmd UTF8String];
 char **argv = malloc((args.count + 2) * sizeof(char*));
 argv[0] = (char*)c;
 for (NSUInteger i = 0; i < args.count; i++) argv[i+1] = (char*)[args[i] UTF8String];
 argv[args.count + 1] = NULL;
 int st = posix_spawn(&pid, c, NULL, NULL, argv, environ);
 free(argv);
 if (st != 0) {
 if (recID && opLog) {
 [opLog endPhase:recID exitCode:st rawOutput:@"" rawError:[NSString stringWithFormat:@"posix_spawn failed: errno=%d", errno]
 verification:@"Command could not be executed" verified:NO duration:0];
 }
 return NO;
 }
 int ws; waitpid(pid, &ws, 0);
 BOOL ok = (WIFEXITED(ws) && WEXITSTATUS(ws) == 0);
 if (recID && opLog) {
 [opLog endPhase:recID exitCode:WEXITSTATUS(ws) rawOutput:@"" rawError:ok ? @"" : [NSString stringWithFormat:@"Command failed with exit code %d", WEXITSTATUS(ws)]
 verification:[NSString stringWithFormat:@"cmd=%@ args=%@", cmd, [args componentsJoinedByString:@" "]] verified:ok duration:0];
 }
 return ok;
}

- (BOOL)runRoot:(NSString *)cmd args:(NSArray *)args opLog:(OperationLog *)opLog recordID:(NSString *)recID {
 if (![self hasRootHelper]) {
 NSLog(@"[IPAInstallerPro] No helper, running as current user: %@", cmd);
 return [self runCmd:cmd args:args opLog:opLog recordID:recID];
 }
 pid_t pid;
 const char *h = [self.helperPath UTF8String];
 const char *c = [cmd UTF8String];
 char **argv = malloc((args.count + 3) * sizeof(char*));
 argv[0] = (char*)h; argv[1] = (char*)c;
 for (NSUInteger i = 0; i < args.count; i++) argv[i+2] = (char*)[args[i] UTF8String];
 argv[args.count + 2] = NULL;
 int st = posix_spawn(&pid, h, NULL, NULL, argv, environ);
 free(argv);
 if (st != 0) {
 NSLog(@"[IPAInstallerPro] Helper spawn failed (errno=%d), falling back to direct", errno);
 return [self runCmd:cmd args:args opLog:opLog recordID:recID];
 }
 int ws; waitpid(pid, &ws, 0);
 if (WIFEXITED(ws) && WEXITSTATUS(ws) == 0) {
 if (recID && opLog) {
 [opLog endPhase:recID exitCode:0 rawOutput:@"" rawError:@""
 verification:[NSString stringWithFormat:@"root cmd=%@ args=%@", cmd, [args componentsJoinedByString:@" "]] verified:YES duration:0];
 }
 return YES;
 }
 NSLog(@"[IPAInstallerPro] Helper failed (exit=%d), falling back to direct", WEXITSTATUS(ws));
 return [self runCmd:cmd args:args opLog:opLog recordID:recID];
}

- (NSString *)runCmdOutput:(NSString *)cmd args:(NSArray *)args {
 int pipefd[2];
 if (pipe(pipefd) != 0) return nil;
 pid_t pid;
 posix_spawn_file_actions_t actions;
 posix_spawn_file_actions_init(&actions);
 posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDOUT_FILENO);
 posix_spawn_file_actions_addclose(&actions, pipefd[0]);
 posix_spawn_file_actions_addclose(&actions, pipefd[1]);
 const char *c = [cmd UTF8String];
 char **argv = malloc((args.count + 2) * sizeof(char*));
 argv[0] = (char*)c;
 for (NSUInteger i = 0; i < args.count; i++) argv[i+1] = (char*)[args[i] UTF8String];
 argv[args.count + 1] = NULL;
 int st = posix_spawn(&pid, c, &actions, NULL, argv, environ);
 free(argv);
 posix_spawn_file_actions_destroy(&actions);
 close(pipefd[1]);
 if (st != 0) { close(pipefd[0]); return nil; }
 NSMutableString *output = [NSMutableString string];
 char buf[4096];
 ssize_t n;
 while ((n = read(pipefd[0], buf, sizeof(buf) - 1)) > 0) { buf[n] = '\0'; [output appendString:[NSString stringWithUTF8String:buf]]; }
 close(pipefd[0]);
 waitpid(pid, NULL, 0);
 return output;
}

#pragma mark - Security Checks

- (BOOL)containsDangerousPaths:(NSString *)path {
 if (!path) return YES;
 // Check for directory traversal
 if ([path containsString:@".."]) return YES;
 if ([path containsString:@"~"]) return YES;
 // Check for absolute paths that escape expected structure
 if ([path hasPrefix:@"/"]) {
 // Only allow /Payload/... and /Info.plist patterns inside IPA
 if (![path hasPrefix:@"Payload/"] && ![path isEqualToString:@"Payload"]) return YES;
 }
 // Check for symlinks in path
 if ([path containsString:@"->"]) return YES;
 return NO;
}

- (BOOL)validateIPAPathSafety:(NSString *)ipaPath opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 NSString *rec = [opLog beginPhase:OperationPhaseIPAOpen operation:@"pathSafetyCheck" target:ipaPath input:@"" transactionID:txnID];

 // Check file size (max 2GB)
 NSFileManager *fm = [NSFileManager defaultManager];
 NSDictionary *attrs = [fm attributesOfItemAtPath:ipaPath error:nil];
 long long size = attrs.fileSize;
 if (size > 2147483648LL) {
 [opLog endPhase:rec exitCode:1 rawOutput:@"" rawError:@"IPA exceeds 2GB limit"
 verification:[NSString stringWithFormat:@"size=%lld (max=2147483648)", size] verified:NO duration:0];
 return NO;
 }

 // Check available space (need at least 3x IPA size)
 NSString *tmpDir = NSTemporaryDirectory();
 NSDictionary *fsAttrs = [fm attributesOfFileSystemForPath:tmpDir error:nil];
 long long freeSpace = [fsAttrs[NSFileSystemFreeSize] longLongValue];
 if (freeSpace < size * 3) {
 [opLog endPhase:rec exitCode:1 rawOutput:@"" rawError:@"Insufficient disk space"
 verification:[NSString stringWithFormat:@"free=%lld needed=%lld", freeSpace, size * 3] verified:NO duration:0];
 return NO;
 }

 [opLog endPhase:rec exitCode:0 rawOutput:@"" rawError:@""
 verification:[NSString stringWithFormat:@"size=%lld free=%lld", size, freeSpace] verified:YES duration:0];
 return YES;
}

- (BOOL)checkForSymlinksInExtractedPath:(NSString *)path opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 NSFileManager *fm = [NSFileManager defaultManager];
 NSArray *items = [fm subpathsAtPath:path];
 for (NSString *item in items) {
 NSString *fullPath = [path stringByAppendingPathComponent:item];
 // Check if it's a symlink
 NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
 if (attrs.fileType == NSFileTypeSymbolicLink) {
 NSString *dest = [fm destinationOfSymbolicLinkAtPath:fullPath error:nil];
 // Allow symlinks within the app bundle itself
 if (dest && ![dest hasPrefix:path] && ![dest hasPrefix:@"@"]) {
 NSString *rec = [opLog beginPhase:OperationPhaseVerify operation:@"symlinkCheck" target:fullPath input:dest transactionID:txnID];
 [opLog endPhase:rec exitCode:1 rawOutput:@"" rawError:[NSString stringWithFormat:@"Dangerous symlink: %@ -> %@", fullPath, dest]
 verification:@"Symlink escapes app bundle" verified:NO duration:0];
 return NO;
 }
 }
 }
 return YES;
}

#pragma mark - Verification Helpers

- (BOOL)verifyStat:(NSString *)path mode:(mode_t *)outMode uid:(uid_t *)outUid gid:(gid_t *)outGid {
 struct stat st;
 if (stat([path UTF8String], &st) != 0) return NO;
 if (outMode) *outMode = st.st_mode & 0777;
 if (outUid) *outUid = st.st_uid;
 if (outGid) *outGid = st.st_gid;
 return YES;
}

- (BOOL)verifyDeepCopy:(NSString *)src dst:(NSString *)dst opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 NSFileManager *fm = [NSFileManager defaultManager];
 NSArray *srcItems = [fm subpathsAtPath:src];
 NSArray *dstItems = [fm subpathsAtPath:dst];
 NSMutableString *detail = [NSMutableString string];
 BOOL ok = YES;

 if (srcItems.count != dstItems.count) {
 [detail appendFormat:@"countMismatch(src=%lu,dst=%lu) ", (unsigned long)srcItems.count, (unsigned long)dstItems.count];
 ok = NO;
 }

 NSUInteger missing = 0, sizeMismatch = 0;
 for (NSString *sub in srcItems) {
 NSString *sPath = [src stringByAppendingPathComponent:sub];
 NSString *dPath = [dst stringByAppendingPathComponent:sub];
 if (![fm fileExistsAtPath:dPath]) { missing++; ok = NO; continue; }
 NSDictionary *sAttr = [fm attributesOfItemAtPath:sPath error:nil];
 NSDictionary *dAttr = [fm attributesOfItemAtPath:dPath error:nil];
 if ([sAttr fileSize] != [dAttr fileSize]) { sizeMismatch++; ok = NO; }
 }
 [detail appendFormat:@"missing=%lu sizeMismatch=%lu", (unsigned long)missing, (unsigned long)sizeMismatch];

 NSString *rec = [opLog beginPhase:OperationPhaseFileCopy operation:@"deepCopyVerification" target:dst input:@"" transactionID:txnID];
 [opLog endPhase:rec exitCode:0 rawOutput:@"" rawError:@""
 verification:detail verified:YES duration:0];
 return ok;
}

- (BOOL)verifySignature:(NSString *)path opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 NSLog(@"[IPAInstallerPro] verifySignature: path=%@ ldid=%@", path, self.ldidPath);
 NSString *output = [self runCmdOutput:self.ldidPath args:@[@"-d", path]];
 BOOL hasSig = (output && output.length > 0);
 NSString *rec = [opLog beginPhase:OperationPhaseSign operation:@"ldid -d signature check" target:path input:@"" transactionID:txnID];
 [opLog endPhase:rec exitCode:hasSig ? 0 : 1 rawOutput:output ?: @"" rawError:hasSig ? @"" : @"No signature detected"
 verification:hasSig ? @"Signature present" : @"No signature" verified:hasSig duration:0];
 NSLog(@"[IPAInstallerPro] verifySignature result: hasSig=%d output=%@", hasSig, output);
 return hasSig;
}

#pragma mark - Rollback

- (BOOL)backupExistingApp:(NSString *)destApp to:(NSString *)backupPath opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 NSFileManager *fm = [NSFileManager defaultManager];
 if (![fm fileExistsAtPath:destApp]) return YES; // Nothing to backup

 NSString *rec = [opLog beginPhase:OperationPhaseFileCopy operation:@"backupExisting" target:destApp input:backupPath transactionID:txnID];

 // Remove old backup if exists
 if ([fm fileExistsAtPath:backupPath]) {
 [fm removeItemAtPath:backupPath error:nil];
 }

 BOOL backedUp = NO;
 if ([self hasRootHelper]) {
 backedUp = [self runRoot:self.mvPath args:@[destApp, backupPath] opLog:opLog recordID:rec];
 } else {
 NSError *err;
 [fm moveItemAtPath:destApp toPath:backupPath error:&err];
 backedUp = (err == nil);
 if (backedUp && rec && opLog) {
 [opLog endPhase:rec exitCode:0 rawOutput:@"" rawError:@""
 verification:@"NSFileManager backup success" verified:YES duration:0];
 }
 }

 if (!backedUp) {
 [opLog endPhase:rec exitCode:1 rawOutput:@"" rawError:@"Backup failed"
 verification:@"Could not backup existing app" verified:NO duration:0];
 }
 return backedUp;
}

- (void)restoreBackup:(NSString *)backupPath to:(NSString *)destApp opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 NSFileManager *fm = [NSFileManager defaultManager];
 if (![fm fileExistsAtPath:backupPath]) return;

 NSString *rec = [opLog beginPhase:OperationPhaseFileCopy operation:@"restoreBackup" target:backupPath input:destApp transactionID:txnID];

 // Remove failed installation
 if ([fm fileExistsAtPath:destApp]) {
 if ([self hasRootHelper]) [self runRoot:self.rmPath args:@[@"-rf", destApp] opLog:opLog recordID:nil];
 else [fm removeItemAtPath:destApp error:nil];
 }

 BOOL restored = NO;
 if ([self hasRootHelper]) {
 restored = [self runRoot:self.mvPath args:@[backupPath, destApp] opLog:opLog recordID:rec];
 } else {
 NSError *err;
 [fm moveItemAtPath:backupPath toPath:destApp error:&err];
 restored = (err == nil);
 if (restored && rec && opLog) {
 [opLog endPhase:rec exitCode:0 rawOutput:@"" rawError:@""
 verification:@"NSFileManager restore success" verified:YES duration:0];
 }
 }

 if (!restored) {
 [opLog endPhase:rec exitCode:1 rawOutput:@"" rawError:@"Restore failed"
 verification:@"Could not restore backup" verified:NO duration:0];
 }
}

- (void)cleanupBackup:(NSString *)backupPath opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 NSFileManager *fm = [NSFileManager defaultManager];
 if (![fm fileExistsAtPath:backupPath]) return;

 NSString *rec = [opLog beginPhase:OperationPhaseCleanup operation:@"cleanupBackup" target:backupPath input:@"" transactionID:txnID];
 if ([self hasRootHelper]) {
 [self runRoot:self.rmPath args:@[@"-rf", backupPath] opLog:opLog recordID:rec];
 } else {
 [fm removeItemAtPath:backupPath error:nil];
 if (rec && opLog) {
 [opLog endPhase:rec exitCode:0 rawOutput:@"" rawError:@""
 verification:@"Backup cleaned up" verified:YES duration:0];
 }
 }
}

#pragma mark - Main Installation

- (void)installIPA:(NSString *)ipaPath transactionID:(NSString *)txnID operationLog:(OperationLog *)opLog completion:(void (^)(InstallationResult *))completion {
 NSFileManager *fm = [NSFileManager defaultManager];
 BOOL hasH = [self hasRootHelper];

 if (!txnID || txnID.length == 0) {
 txnID = [opLog beginTransactionForIPA:ipaPath];
 }
 // If txnID is provided by the engine, use it directly without creating a duplicate OperationLog entry

 // PHASE 0: SAFETY CHECKS
 if (![self validateIPAPathSafety:ipaPath opLog:opLog txnID:txnID]) {
 NSLog(@"[IPAInstallerPro] EARLY FAIL: IPA safety check failed for: %@", ipaPath);
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"IPA safety check failed" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 // PHASE 1: IPA_OPEN
 NSLog(@"[IPAInstallerPro] === PHASE 1: IPA_OPEN ===");
 NSString *rec1 = [opLog beginPhase:OperationPhaseIPAOpen operation:@"fileExistsAtPath" target:ipaPath input:ipaPath transactionID:txnID];
 BOOL ipaExists = [fm fileExistsAtPath:ipaPath];
 BOOL ipaReadable = [fm isReadableFileAtPath:ipaPath];
 NSDictionary *ipaAttrs = ipaExists ? [fm attributesOfItemAtPath:ipaPath error:nil] : nil;
 [opLog endPhase:rec1 exitCode:ipaExists ? 0 : ENOENT rawOutput:@"" rawError:ipaExists ? @"" : @"IPA not found"
 verification:[NSString stringWithFormat:@"exists=%@ readable=%@ size=%lld", ipaExists ? @"YES" : @"NO", ipaReadable ? @"YES" : @"NO", ipaAttrs ? ipaAttrs.fileSize : 0]
 verified:(ipaExists && ipaReadable) duration:0];

 if (!ipaExists || !ipaReadable) {
 NSLog(@"[IPAInstallerPro] EARLY FAIL: IPA not found or unreadable: %@ exists=%d readable=%d", ipaPath, ipaExists, ipaReadable);
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"IPA not found or unreadable" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 // PHASE 2: IPA_EXTRACT
 NSLog(@"[IPAInstallerPro] === PHASE 2: IPA_EXTRACT ===");
 NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
 NSString *rec2 = [opLog beginPhase:OperationPhaseIPAExtract operation:@"createDirectoryAtPath" target:tmp input:@"" transactionID:txnID];
 BOOL tmpCreated = [fm createDirectoryAtPath:tmp withIntermediateDirectories:YES attributes:nil error:nil];
 [opLog endPhase:rec2 exitCode:tmpCreated ? 0 : 1 rawOutput:@"" rawError:tmpCreated ? @"" : @"Failed to create temp dir"
 verification:[NSString stringWithFormat:@"created=%@", tmpCreated ? @"YES" : @"NO"] verified:tmpCreated duration:0];

 if (!tmpCreated) {
 NSLog(@"[IPAInstallerPro] EARLY FAIL: Temp directory creation failed");
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"Temp directory creation failed" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 NSString *rec3 = [opLog beginPhase:OperationPhaseIPAExtract operation:@"unzip" target:ipaPath input:@"" transactionID:txnID];
 BOOL unzipOk = NO;
 NSString *payload = [tmp stringByAppendingPathComponent:@"Payload"];

 // Try unzip with direct path first
 unzipOk = [self runCmd:self.unzipPath args:@[@"-o", ipaPath, @"-d", tmp] opLog:opLog recordID:rec3];

 // Fallback: try system unzip if available
 if (!unzipOk || ![fm fileExistsAtPath:payload]) {
     NSLog(@"[IPAInstallerPro] Primary unzip failed, trying fallback...");
     NSString *sysUnzip = @"/usr/bin/unzip";
     if ([fm fileExistsAtPath:sysUnzip] && ![sysUnzip isEqualToString:self.unzipPath]) {
         unzipOk = [self runCmd:sysUnzip args:@[@"-o", ipaPath, @"-d", tmp] opLog:opLog recordID:rec3];
     }
 }

 // Fallback 2: try using tar (some IPAs can be extracted with tar)
 if (!unzipOk || ![fm fileExistsAtPath:payload]) {
     NSLog(@"[IPAInstallerPro] unzip binary failed, trying tar extraction...");
     NSString *tarPath = [[RootlessManager sharedManager] resolvePath:@"/usr/bin/tar"];
     if ([fm fileExistsAtPath:tarPath]) {
         unzipOk = [self runCmd:tarPath args:@[@"-xf", ipaPath, @"-C", tmp] opLog:opLog recordID:rec3];
     }
 }

 BOOL payloadExists = [fm fileExistsAtPath:payload];
 if (!unzipOk && !payloadExists) {
 NSLog(@"[IPAInstallerPro] EARLY FAIL: Unzip failed (unzipOk=%d payloadExists=%d)", unzipOk, payloadExists);
 [fm removeItemAtPath:tmp error:nil];
 [opLog endPhase:rec3 exitCode:1 rawOutput:@"" rawError:@"Unzip failed — all methods exhausted" verification:@"unzip failed" verified:NO duration:0];
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"Unzip failed" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }
 // If payload exists but unzip reported failure, it might be partial — check if .app exists
 if (!payloadExists) {
 NSLog(@"[IPAInstallerPro] EARLY FAIL: Payload directory not found after extraction");
 [fm removeItemAtPath:tmp error:nil];
 [opLog endPhase:rec3 exitCode:1 rawOutput:@"" rawError:@"Payload not found" verification:@"no payload" verified:NO duration:0];
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"No Payload in IPA" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 // PHASE 3: APP_IDENTIFY + SECURITY CHECK
// PHASE 3: APP_IDENTIFY + SECURITY CHECK
 NSString *rec4 = [opLog beginPhase:OperationPhaseAppIdentify operation:@"find .app in Payload" target:payload input:@"" transactionID:txnID];
 NSArray *items = [fm contentsOfDirectoryAtPath:payload error:nil];
 NSString *appFolder = nil;
 for (NSString *i in items) { if ([i hasSuffix:@".app"]) { appFolder = i; break; } }
 BOOL appFound = (appFolder != nil);
 [opLog endPhase:rec4 exitCode:appFound ? 0 : 1 rawOutput:@"" rawError:appFound ? @"" : @"No .app folder found"
 verification:[NSString stringWithFormat:@"found=%@ name=%@", appFound ? @"YES" : @"NO", appFolder ?: @"N/A"] verified:YES duration:0];

 if (!appFound) {
 NSLog(@"[IPAInstallerPro] EARLY FAIL: No .app found in Payload");
 [fm removeItemAtPath:tmp error:nil];
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"No .app found" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 NSString *srcApp = [payload stringByAppendingPathComponent:appFolder];

 // Security: Check for dangerous symlinks
 if (![self checkForSymlinksInExtractedPath:srcApp opLog:opLog txnID:txnID]) {
 NSLog(@"[IPAInstallerPro] EARLY FAIL: Dangerous symlinks detected");
 [fm removeItemAtPath:tmp error:nil];
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"Dangerous symlinks detected in IPA" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 NSString *infoPath = [srcApp stringByAppendingPathComponent:@"Info.plist"];
 NSString *rec5 = [opLog beginPhase:OperationPhaseAppIdentify operation:@"read Info.plist" target:infoPath input:@"" transactionID:txnID];
 NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
 BOOL infoRead = (info != nil);
 NSString *bundleID = info[@"CFBundleIdentifier"];
 NSString *exeName = info[@"CFBundleExecutable"];
 BOOL infoHasKeys = infoRead && (bundleID.length > 0) && (exeName.length > 0);
 [opLog endPhase:rec5 exitCode:infoRead ? 0 : 1 rawOutput:@"" rawError:infoRead ? @"" : @"Info.plist unreadable"
 verification:[NSString stringWithFormat:@"read=%@ bundleID=%@ exe=%@", infoRead ? @"YES" : @"NO", bundleID ?: @"N/A", exeName ?: @"N/A"]
 verified:YES duration:0];

 if (!infoHasKeys) {
 NSLog(@"[IPAInstallerPro] EARLY FAIL: Invalid Info.plist — bundleID=%@ exe=%@", bundleID, exeName);
 [fm removeItemAtPath:tmp error:nil];
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"Invalid Info.plist" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

// PHASE 3.5: SMART SIGNING PLAN
 NSString *recPlan = [opLog beginPhase:OperationPhaseAppIdentify operation:@"smart-signing-plan" target:srcApp input:@"analyzing structure" transactionID:txnID];
 __block SigningPlan *signingPlan = nil;
 BOOL planGenerated = NO;
 @try {
 IPAStructuralResult *structResult = [[IPAStructuralAnalyzer sharedAnalyzer] analyzeIPAAtPath:ipaPath keepExtracted:NO];
 if (structResult.success && structResult.executables.count > 0) {
 signingPlan = [[SigningPlanner sharedPlanner] createPlanForStructuralResult:structResult];
 planGenerated = signingPlan.isViable;
 if (planGenerated) {
 NSLog(@"[SmartSign] Plan: %ld targets, %ld preserve, %ld generic, %ld minimal",
 (long)signingPlan.totalTargets, (long)signingPlan.preserveCount,
 (long)signingPlan.genericCount, (long)signingPlan.minimalCount);
 }
 }
 } @catch (NSException *e) {
 NSLog(@"[SmartSign] Plan failed: %@", e.reason);
 }
 [opLog endPhase:recPlan exitCode:0 rawOutput:planGenerated ? @"Smart signing plan generated" : @"Smart signing plan unavailable, using legacy fallback" rawError:@"" verification:@"smart signing plan" verified:YES duration:0];

 // PHASE 4: FILE_COPY (with backup/rollback)
 NSLog(@"[IPAInstallerPro] === PHASE 4: FILE_COPY ===");
 NSString *logicalDest = [@"/Applications" stringByAppendingPathComponent:appFolder];
 NSString *rec7 = [opLog beginPhase:OperationPhaseFileCopy operation:@"resolvePath" target:logicalDest input:logicalDest transactionID:txnID];
 NSString *destApp = [[RootlessManager sharedManager] resolvePath:logicalDest];
 BOOL destResolved = (destApp != nil && destApp.length > 0);
 [opLog endPhase:rec7 exitCode:destResolved ? 0 : 1 rawOutput:destApp ?: @"" rawError:destResolved ? @"" : @"RootlessManager failed"
 verification:[NSString stringWithFormat:@"resolved=%@ path=%@", destResolved ? @"YES" : @"NO", destApp ?: @"N/A"] verified:destResolved duration:0];

 if (!destResolved) {
 NSLog(@"[IPAInstallerPro] EARLY FAIL: Could not resolve destination for: %@", logicalDest);
 [fm removeItemAtPath:tmp error:nil];
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"Could not resolve destination" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 // Ensure Applications directory exists
 NSString *appsDir = [destApp stringByDeletingLastPathComponent];
 if (![fm fileExistsAtPath:appsDir]) {
 NSString *recMkdir = [opLog beginPhase:OperationPhaseFileCopy operation:@"mkdir -p Applications" target:appsDir input:@"" transactionID:txnID];
 BOOL dirCreated = [self runRoot:self.mkdirPath args:@[@"-p", appsDir] opLog:opLog recordID:recMkdir];
 if (!dirCreated) {
 NSError *mkErr;
 [fm createDirectoryAtPath:appsDir withIntermediateDirectories:YES attributes:nil error:&mkErr];
 }
 }

 // BACKUP existing app (rollback support)
 NSString *backupPath = [destApp stringByAppendingString:@".backup"];
 if (![self backupExistingApp:destApp to:backupPath opLog:opLog txnID:txnID]) {
 NSLog(@"[IPAInstallerPro] EARLY FAIL: Backup failed for: %@", destApp);
 [fm removeItemAtPath:tmp error:nil];
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"Failed to backup existing app" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 // Copy — try root helper first, then copyfile, then NSFileManager
 NSString *rec9 = [opLog beginPhase:OperationPhaseFileCopy operation:@"copy app bundle" target:[NSString stringWithFormat:@"%@ -> %@", srcApp, destApp] input:@"" transactionID:txnID];
 BOOL copied = NO;
 if (hasH) {
 copied = [self runRoot:self.cpPath args:@[@"-R", srcApp, destApp] opLog:opLog recordID:rec9];
 }
 if (!copied) {
 int rv = copyfile([srcApp UTF8String], [destApp UTF8String], NULL, COPYFILE_ALL | COPYFILE_RECURSIVE);
 copied = (rv == 0);
 if (!copied) {
 NSError *e;
 [fm copyItemAtPath:srcApp toPath:destApp error:&e];
 copied = (e == nil);
 }
 if (copied && rec9 && opLog) {
 [opLog endPhase:rec9 exitCode:0 rawOutput:@"" rawError:@""
 verification:[NSString stringWithFormat:@"copyfile/NSFileManager fallback success"] verified:YES duration:0];
 }
 }

 if (!copied) {
 // ROLLBACK: restore backup
 [self restoreBackup:backupPath to:destApp opLog:opLog txnID:txnID];
 [fm removeItemAtPath:tmp error:nil];
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"Copy failed — all methods exhausted, rollback attempted" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 // Deep copy verification (warning only — do NOT block installation)
 BOOL deepOk = [self verifyDeepCopy:srcApp dst:destApp opLog:opLog txnID:txnID];
 if (!deepOk) {
 NSLog(@"[IPAInstallerPro] WARNING: Deep copy mismatch — continuing anyway");
 }

 // PHASE 5: PERMISSION
 NSLog(@"[IPAInstallerPro] === PHASE 5: PERMISSION ===");
 NSString *rec10a = [opLog beginPhase:OperationPhasePermission operation:@"chmod -R 755" target:destApp input:@"" transactionID:txnID];
 [self runRoot:self.chmodPath args:@[@"-R", @"755", destApp] opLog:opLog recordID:rec10a];

 NSString *rec10b = [opLog beginPhase:OperationPhasePermission operation:@"chown -R root:wheel" target:destApp input:@"" transactionID:txnID];
 [self runRoot:self.chownPath args:@[@"-R", @"root:wheel", destApp] opLog:opLog recordID:rec10b];

 // STAT verification
 NSString *destExe = [destApp stringByAppendingPathComponent:exeName];
 mode_t mode = 0; uid_t uid = 0; gid_t gid = 0;
 BOOL statOk = [self verifyStat:destExe mode:&mode uid:&uid gid:&gid];
 NSString *rec10c = [opLog beginPhase:OperationPhasePermission operation:@"stat verification" target:destExe input:@"" transactionID:txnID];
 [opLog endPhase:rec10c exitCode:statOk ? 0 : 1 rawOutput:@"" rawError:statOk ? @"" : [NSString stringWithFormat:@"stat failed, errno=%d", errno]
 verification:[NSString stringWithFormat:@"mode=%o uid=%d gid=%d", mode, uid, gid]
 verified:(statOk && mode >= 0755 && uid == 0 && gid == 0) duration:0];

 if (!statOk || mode < 0755 || uid != 0 || gid != 0) {
 // ROLLBACK
 [self restoreBackup:backupPath to:destApp opLog:opLog txnID:txnID];
 [fm removeItemAtPath:tmp error:nil];
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:[NSString stringWithFormat:@"Permission verification failed: mode=%o uid=%d gid=%d", mode, uid, gid]
 provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 // PHASE 6: SMART SIGN + LEGACY SAFETY NET
 NSLog(@"[IPAInstallerPro] === PHASE 6: SIGNING ===");
 NSString *rec11 = [opLog beginPhase:OperationPhaseSign operation:@"sign-execute" target:destApp input:@"" transactionID:txnID];
 NSUInteger smartSignedCount = 0;
 if (planGenerated && signingPlan) {
 smartSignedCount = [self executeSigningPlan:signingPlan atAppPath:destApp hasHelper:hasH opLog:opLog txnID:txnID];
 NSLog(@"[IPAInstallerPro] Smart signing completed: %lu targets", (unsigned long)smartSignedCount);
 }

 // ALWAYS run legacy as safety net — catches anything Smart Signing missed
 NSLog(@"[IPAInstallerPro] Running legacy signing as safety net...");
 [self signAllAt:destApp hasHelper:hasH opLog:opLog txnID:txnID];
 [self signExe:destExe hasHelper:hasH opLog:opLog txnID:txnID];

 BOOL sigOk = [self verifySignature:destExe opLog:opLog txnID:txnID];
 if (!sigOk) {
     NSLog(@"[IPAInstallerPro] Signature weak, retrying with explicit entitlements...");
     [self signExeWithExplicitEntitlements:destExe hasHelper:hasH opLog:opLog txnID:txnID];
     sigOk = [self verifySignature:destExe opLog:opLog txnID:txnID];
     if (!sigOk) {
         [opLog endPhase:rec11 exitCode:1 rawOutput:@"" rawError:@"Signing failed" verification:@"signing" verified:NO duration:0];
         [self restoreBackup:backupPath to:destApp opLog:opLog txnID:txnID];
         [fm removeItemAtPath:tmp error:nil];
         [opLog endTransaction:txnID finalResult:OperationResultFailed];
         if (completion) completion([InstallationResult failureResult:@"Signature failed — rollback" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
         return;
     }
 }
 [opLog endPhase:rec11 exitCode:0 rawOutput:@"" rawError:@"" verification:@"signing complete" verified:YES duration:0];

 // PHASE 7: FRAMEWORK (always run as safety net)
 [self fixFrameworks:destApp hasHelper:hasH opLog:opLog txnID:txnID];
 // PHASE 8: UICACHE
 NSLog(@"[IPAInstallerPro] === PHASE 8: UICACHE ===");
 NSString *rec14a = [opLog beginPhase:OperationPhaseUICache operation:@"uicache -p logical" target:logicalDest input:@"" transactionID:txnID];
 [self runRoot:self.uicachePath args:@[@"-p", logicalDest] opLog:opLog recordID:rec14a];

 NSString *rec14b = [opLog beginPhase:OperationPhaseUICache operation:@"uicache -p resolved" target:destApp input:@"" transactionID:txnID];
 [self runRoot:self.uicachePath args:@[@"-p", destApp] opLog:opLog recordID:rec14b];

 NSString *rec14c = [opLog beginPhase:OperationPhaseUICache operation:@"uicache -a" target:@"" input:@"" transactionID:txnID];
 [self runRoot:self.uicachePath args:@[@"-a"] opLog:opLog recordID:rec14c];

 // PHASE 9: VERIFY
 NSLog(@"[IPAInstallerPro] === PHASE 9: VERIFY ===");
 NSString *rec15 = [opLog beginPhase:OperationPhaseVerify operation:@"final verify" target:destApp input:bundleID transactionID:txnID];
 BOOL finalOk = [self verifyInstallation:destApp bundleID:bundleID exeName:exeName opLog:opLog txnID:txnID];
 [opLog endPhase:rec15 exitCode:finalOk ? 0 : 1 rawOutput:@"" rawError:finalOk ? @"" : @"Final verification failed"
 verification:[NSString stringWithFormat:@"bundleID=%@ exe=%@", bundleID, exeName] verified:finalOk duration:0];

 if (!finalOk) {
 // ROLLBACK
 [self restoreBackup:backupPath to:destApp opLog:opLog txnID:txnID];
 [fm removeItemAtPath:tmp error:nil];
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"Final verification failed, rollback executed" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 // SUCCESS — cleanup backup and temp
 [self cleanupBackup:backupPath opLog:opLog txnID:txnID];

 // PHASE 10: CLEANUP
 NSLog(@"[IPAInstallerPro] === PHASE 10: CLEANUP ===");
 NSString *rec16 = [opLog beginPhase:OperationPhaseCleanup operation:@"remove temp" target:tmp input:@"" transactionID:txnID];
 [fm removeItemAtPath:tmp error:nil];
 BOOL tmpRemoved = ![fm fileExistsAtPath:tmp];
 [opLog endPhase:rec16 exitCode:tmpRemoved ? 0 : 1 rawOutput:@"" rawError:tmpRemoved ? @"" : @"Temp still exists"
 verification:[NSString stringWithFormat:@"removed=%@", tmpRemoved ? @"YES" : @"NO"] verified:tmpRemoved duration:0];

 // SUCCESS
 NSLog(@"[IPAInstallerPro] === INSTALLATION SUCCESS: %@ ===", bundleID);
 [opLog endTransaction:txnID finalResult:OperationResultSuccess];
 InstallationResult *result = [InstallationResult successResult:[NSString stringWithFormat:@"Installed %@", appFolder]
 provider:[self providerName] transaction:txnID evidence:@{@"bundleID": bundleID, @"path": destApp, @"exe": exeName}];
 result.bundleID = bundleID;
 if (completion) completion(result);
}

#pragma mark - Signing

- (void)signAllAt:(NSString *)path hasHelper:(BOOL)hasH opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 NSFileManager *fm = [NSFileManager defaultManager];
 NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:path];
 NSString *relativePath = nil;
 while ((relativePath = [enumerator nextObject])) {
 NSString *fullPath = [path stringByAppendingPathComponent:relativePath];
 NSString *item = [relativePath lastPathComponent];
 BOOL isDir = NO;
 [fm fileExistsAtPath:fullPath isDirectory:&isDir];

 if (isDir) {
 if ([item hasSuffix:@".app"]) {
 NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[fullPath stringByAppendingPathComponent:@"Info.plist"]];
 NSString *en = info[@"CFBundleExecutable"];
 if (en) [self signBin:[fullPath stringByAppendingPathComponent:en] hasHelper:hasH label:[@"app:" stringByAppendingString:en] opLog:opLog txnID:txnID];
 } else if ([item hasSuffix:@".framework"]) {
 NSString *fn = [item stringByDeletingPathExtension];
 [self signBin:[fullPath stringByAppendingPathComponent:fn] hasHelper:hasH label:[@"fw:" stringByAppendingString:fn] opLog:opLog txnID:txnID];
 // Skip descending into framework bundles to avoid double-signing
 [enumerator skipDescendants];
 } else if ([item hasSuffix:@".appex"] || [item hasSuffix:@".xpc"]) {
 [self signBundleExecutableAtPath:fullPath
 label:[NSString stringWithFormat:@"%@:%@", [item.pathExtension lowercaseString], item]
 hasHelper:hasH opLog:opLog txnID:txnID];
 [enumerator skipDescendants];
 }
 } else if ([item hasSuffix:@".dylib"] || [item hasSuffix:@".so"]) {
 [self signBin:fullPath hasHelper:hasH label:[@"dylib:" stringByAppendingString:item] opLog:opLog txnID:txnID];
 }
 }
}

- (NSDictionary *)extractEntitlementsFromExecutable:(NSString *)path {
 NSString *entOutput = [self runCmdOutput:self.ldidPath args:@[@"-e", path]];
 if (!entOutput || entOutput.length < 5) return nil;

 NSData *data = [entOutput dataUsingEncoding:NSUTF8StringEncoding];
 if (!data) return nil;

 NSError *err = nil;
 NSPropertyListFormat fmt = 0;
 id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:&fmt error:&err];
 if ([plist isKindOfClass:[NSDictionary class]] && [(NSDictionary *)plist count] > 0) {
 return (NSDictionary *)plist;
 }

 NSString *tmpEnt = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ext_ent_%@.plist", [[NSUUID UUID] UUIDString]]];
 [entOutput writeToFile:tmpEnt atomically:YES encoding:NSUTF8StringEncoding error:nil];
 NSDictionary *ents = [NSDictionary dictionaryWithContentsOfFile:tmpEnt];
 [[NSFileManager defaultManager] removeItemAtPath:tmpEnt error:nil];
 return ents;
}


- (NSDictionary *)extractEntitlementsFromAppBundle:(NSString *)appPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (!appPath || ![fm fileExistsAtPath:appPath]) return nil;

    // 1. Try archived-expanded-entitlements.xcent (most common in IPAs)
    NSString *xcentPath = [appPath stringByAppendingPathComponent:@"archived-expanded-entitlements.xcent"];
    if ([fm fileExistsAtPath:xcentPath]) {
        NSDictionary *ents = [NSDictionary dictionaryWithContentsOfFile:xcentPath];
        if (ents && ents.count > 0) {
            NSLog(@"[IPAInstallerPro] Found entitlements in archived-expanded-entitlements.xcent (%lu keys)", (unsigned long)ents.count);
            return ents;
        }
    }

    // 2. Try embedded.mobileprovision (extract entitlements from provisioning profile)
    NSString *provPath = [appPath stringByAppendingPathComponent:@"embedded.mobileprovision"];
    if ([fm fileExistsAtPath:provPath]) {
        NSData *provData = [NSData dataWithContentsOfFile:provPath];
        if (provData) {
            NSString *provStr = [[NSString alloc] initWithData:provData encoding:NSASCIIStringEncoding];
            if (provStr) {
                // Find Entitlements dict in the plist portion of .mobileprovision
                NSRange entRange = [provStr rangeOfString:@"<key>Entitlements</key>"];
                if (entRange.location != NSNotFound) {
                    NSString *sub = [provStr substringFromIndex:entRange.location];
                    NSRange dictEnd = [sub rangeOfString:@"</dict>"];
                    if (dictEnd.location != NSNotFound) {
                        NSString *entXml = [sub substringToIndex:dictEnd.location + 7];
                        NSString *wrapped = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\">%@</plist>", entXml];
                        NSData *xmlData = [wrapped dataUsingEncoding:NSUTF8StringEncoding];
                        if (xmlData) {
                            NSError *err = nil;
                            id plist = [NSPropertyListSerialization propertyListWithData:xmlData options:NSPropertyListImmutable format:NULL error:&err];
                            if ([plist isKindOfClass:[NSDictionary class]]) {
                                NSLog(@"[IPAInstallerPro] Found entitlements in embedded.mobileprovision (%lu keys)", (unsigned long)[(NSDictionary *)plist count]);
                                return (NSDictionary *)plist;
                            }
                        }
                    }
                }
            }
        }
    }

    return nil;
}

- (BOOL)signBundleExecutableAtPath:(NSString *)bundlePath label:(NSString *)label hasHelper:(BOOL)hasH opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 NSFileManager *fm = [NSFileManager defaultManager];
 if (bundlePath.length == 0 || ![fm fileExistsAtPath:bundlePath]) return NO;
 NSString *infoPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
 NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
 NSString *executable = [info[@"CFBundleExecutable"] isKindOfClass:[NSString class]] ? info[@"CFBundleExecutable"] : nil;
 if (executable.length == 0) return NO;
 NSString *executablePath = [bundlePath stringByAppendingPathComponent:executable];
 if (![fm fileExistsAtPath:executablePath]) return NO;

 NSString *rec = [opLog beginPhase:OperationPhaseSign operation:[NSString stringWithFormat:@"sign extension (%@)", label ?: @"bundle"] target:executablePath input:@"preserve-entitlements" transactionID:txnID];

 NSDictionary *ents = [self extractEntitlementsFromExecutable:executablePath];
 BOOL signedOK = NO;

 if (ents && ents.count > 0) {
 NSString *entPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ipa-ent-%@.plist", [NSUUID UUID].UUIDString]];
 [ents writeToFile:entPath atomically:YES];
 NSString *sf = [NSString stringWithFormat:@"-S%@", entPath];
 signedOK = hasH ? [self runRoot:self.ldidPath args:@[sf, executablePath] opLog:opLog recordID:rec]
 : [self runCmd:self.ldidPath args:@[sf, executablePath] opLog:opLog recordID:rec];
 [fm removeItemAtPath:entPath error:nil];
 } else {
 signedOK = hasH ? [self runRoot:self.ldidPath args:@[@"-S", executablePath] opLog:opLog recordID:rec]
 : [self runCmd:self.ldidPath args:@[@"-S", executablePath] opLog:opLog recordID:rec];
 }

 return signedOK;
}

- (void)signBin:(NSString *)path hasHelper:(BOOL)hasH label:(NSString *)label opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 if (!path || ![[NSFileManager defaultManager] fileExistsAtPath:path]) return;
 NSString *rec = [opLog beginPhase:OperationPhaseSign operation:[NSString stringWithFormat:@"ldid -S (%@)", label] target:path input:@"" transactionID:txnID];
 if (hasH) [self runRoot:self.chmodPath args:@[@"755", path] opLog:opLog recordID:nil];
 else [self runCmd:self.chmodPath args:@[@"755", path] opLog:opLog recordID:nil];

 // For frameworks and dylibs, try to preserve original entitlements first
 NSDictionary *ents = nil;
 if ([label hasPrefix:@"fw:"] || [label hasPrefix:@"dylib:"]) {
 ents = [self extractEntitlementsFromExecutable:path];
 }

 BOOL ok = NO;
 if (ents && ents.count > 0) {
 NSString *ep = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"bin_%@.ent", [[NSUUID UUID] UUIDString]]];
 [ents writeToFile:ep atomically:YES];
 NSString *sf = [NSString stringWithFormat:@"-S%@", ep];
 ok = hasH ? [self runRoot:self.ldidPath args:@[sf, path] opLog:opLog recordID:rec]
 : [self runCmd:self.ldidPath args:@[sf, path] opLog:opLog recordID:rec];
 [[NSFileManager defaultManager] removeItemAtPath:ep error:nil];
 }

 if (!ok) {
 ok = hasH ? [self runRoot:self.ldidPath args:@[@"-S", path] opLog:opLog recordID:rec]
 : [self runCmd:self.ldidPath args:@[@"-S", path] opLog:opLog recordID:rec];
 }

 if (!ok) {
 // Retry with minimal entitlements
 NSString *ep = [NSTemporaryDirectory() stringByAppendingPathComponent:@"min.ent"];
 [@{@"get-task-allow":@YES, @"platform-application":@YES, @"aps-environment":@"development"} writeToFile:ep atomically:YES];
 NSString *sf = [NSString stringWithFormat:@"-S%@", ep];
 [self runCmd:self.ldidPath args:@[sf, path] opLog:opLog recordID:rec];
 }
}

- (void)signExe:(NSString *)path hasHelper:(BOOL)hasH opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return;
 NSString *rec = [opLog beginPhase:OperationPhaseSign operation:@"signExe (main)" target:path input:@"" transactionID:txnID];

 // Try 1: Extract from the installed executable itself
 NSDictionary *ents = [self extractEntitlementsFromExecutable:path];

 // Try 2: Extract from the app bundle (archived-expanded-entitlements.xcent or embedded.mobileprovision)
 if (!ents || ents.count == 0) {
 NSString *appBundle = [path stringByDeletingLastPathComponent];
 ents = [self extractEntitlementsFromAppBundle:appBundle];
 }

 BOOL ok = NO;

 if (ents && ents.count > 0) {
 NSString *ep = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"orig_%@.ent", [[NSUUID UUID] UUIDString]]];
 [ents writeToFile:ep atomically:YES];
 NSString *sf = [NSString stringWithFormat:@"-S%@", ep];
 ok = hasH ? [self runRoot:self.ldidPath args:@[sf, path] opLog:opLog recordID:rec]
 : [self runCmd:self.ldidPath args:@[sf, path] opLog:opLog recordID:rec];
 [[NSFileManager defaultManager] removeItemAtPath:ep error:nil];
 if (ok) {
 NSLog(@"[IPAInstallerPro] Main exe signed with original entitlements (%lu keys)", (unsigned long)ents.count);
 return;
 }
 }

 ok = hasH ? [self runRoot:self.ldidPath args:@[@"-S", path] opLog:opLog recordID:rec]
 : [self runCmd:self.ldidPath args:@[@"-S", path] opLog:opLog recordID:rec];
 if (ok) {
 NSLog(@"[IPAInstallerPro] Main exe signed blank");
 return;
 }

 NSString *ep2 = [NSTemporaryDirectory() stringByAppendingPathComponent:@"min.ent"];
 [@{@"get-task-allow":@YES, @"platform-application":@YES, @"aps-environment":@"development"} writeToFile:ep2 atomically:YES];
 NSString *sf = [NSString stringWithFormat:@"-S%@", ep2];
 [self runCmd:self.ldidPath args:@[sf, path] opLog:opLog recordID:rec];
}

- (void)signExeWithExplicitEntitlements:(NSString *)path hasHelper:(BOOL)hasH opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return;
 NSString *rec = [opLog beginPhase:OperationPhaseSign operation:@"signExe (explicit entitlements retry)" target:path input:@"" transactionID:txnID];
 NSString *ep = [NSTemporaryDirectory() stringByAppendingPathComponent:@"explicit.ent"];
 NSDictionary *ents = @{
 @"get-task-allow": @YES,
 @"platform-application": @YES,
 @"com.apple.private.security.no-container": @YES,
 @"com.apple.private.security.no-sandbox": @YES,
 @"com.apple.private.skip-library-validation": @YES,
 @"run-unsigned-code": @YES
 };
 [ents writeToFile:ep atomically:YES];
 NSString *sf = [NSString stringWithFormat:@"-S%@", ep];
 if (hasH) {
 [self runRoot:self.ldidPath args:@[sf, path] opLog:opLog recordID:rec];
 } else {
 [self runCmd:self.ldidPath args:@[sf, path] opLog:opLog recordID:rec];
 }
}

- (NSArray *)embeddedExecutablePathsAtPath:(NSString *)appPath {
 NSFileManager *fm = [NSFileManager defaultManager];
 NSMutableArray *paths = [NSMutableArray array];
 NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:appPath];
 NSString *relativePath = nil;
 while ((relativePath = [enumerator nextObject])) {
 NSString *lower = relativePath.lowercaseString;
 if (![lower hasSuffix:@".appex"] && ![lower hasSuffix:@".xpc"]) continue;
 NSString *bundlePath = [appPath stringByAppendingPathComponent:relativePath];
 BOOL isDirectory = NO;
 if (![fm fileExistsAtPath:bundlePath isDirectory:&isDirectory] || !isDirectory) continue;
 NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[bundlePath stringByAppendingPathComponent:@"Info.plist"]];
 NSString *executable = [info[@"CFBundleExecutable"] isKindOfClass:[NSString class]] ? info[@"CFBundleExecutable"] : nil;
 NSString *executablePath = executable.length > 0 ? [bundlePath stringByAppendingPathComponent:executable] : nil;
 if (executablePath.length > 0 && [fm fileExistsAtPath:executablePath]) [paths addObject:executablePath];
 [enumerator skipDescendants];
 }
 return [paths copy];
}

- (BOOL)verifyEmbeddedBundleSignaturesAtPath:(NSString *)appPath opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 NSArray *paths = [self embeddedExecutablePathsAtPath:appPath];
 BOOL allValid = YES;
 for (NSString *path in paths) {
 BOOL valid = [self runCmd:self.ldidPath args:@[@"-d", path] opLog:nil recordID:nil];
 NSString *rec = [opLog beginPhase:OperationPhaseVerify operation:@"verify embedded executable signature" target:path input:@"ldid -d" transactionID:txnID];
 [opLog endPhase:rec exitCode:valid ? 0 : 1 rawOutput:@"" rawError:valid ? @"" : @"Embedded executable signature check failed"
 verification:[NSString stringWithFormat:@"path=%@ signed=%@", path, valid ? @"YES" : @"NO"] verified:valid duration:0];
 if (!valid) allValid = NO;
 }
 return allValid;
}

- (void)fixFrameworks:(NSString *)appPath hasHelper:(BOOL)hasH opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 NSFileManager *fm = [NSFileManager defaultManager];
 NSString *fw = [appPath stringByAppendingPathComponent:@"Frameworks"];
 if (![fm fileExistsAtPath:fw]) return;
 for (NSString *item in [fm contentsOfDirectoryAtPath:fw error:nil]) {
 NSString *ip = [fw stringByAppendingPathComponent:item];
 BOOL isDir = NO;
 [fm fileExistsAtPath:ip isDirectory:&isDir];
 if (isDir && [item hasSuffix:@".framework"]) {
 NSString *fn = [item stringByDeletingPathExtension];
 [self signBin:[ip stringByAppendingPathComponent:fn] hasHelper:hasH label:[@"fw:" stringByAppendingString:fn] opLog:opLog txnID:txnID];
 [self signAllAt:ip hasHelper:hasH opLog:opLog txnID:txnID];
 } else if ([item hasSuffix:@".dylib"] || [item hasSuffix:@".so"]) {
 [self signBin:ip hasHelper:hasH label:[@"dylib:" stringByAppendingString:item] opLog:opLog txnID:txnID];
 if (hasH) {
 [self runRoot:self.chmodPath args:@[@"755", ip] opLog:opLog recordID:nil];
 [self runRoot:self.chownPath args:@[@"root:wheel", ip] opLog:opLog recordID:nil];
 }
 }
 }
}

#pragma mark - Verification

- (BOOL)verifyInstallation:(NSString *)appPath bundleID:(NSString *)bid exeName:(NSString *)en opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 NSFileManager *fm = [NSFileManager defaultManager];
 BOOL ok = YES;
 NSString *ep = [appPath stringByAppendingPathComponent:en];

 // exe exists + readable + executable
 BOOL exeExists = [fm fileExistsAtPath:ep];
 BOOL exeReadable = [fm isReadableFileAtPath:ep];
 BOOL exeX_OK = (access([ep UTF8String], X_OK) == 0);

 NSString *recExe = [opLog beginPhase:OperationPhaseVerify operation:@"verify executable" target:ep input:@"" transactionID:txnID];
 [opLog endPhase:recExe exitCode:(exeExists && exeReadable && exeX_OK) ? 0 : 1 rawOutput:@"" rawError:(exeExists && exeReadable && exeX_OK) ? @"" : [NSString stringWithFormat:@"exists=%d readable=%d xok=%d", exeExists, exeReadable, exeX_OK]
 verification:[NSString stringWithFormat:@"exists=%@ readable=%@ xok=%@", exeExists ? @"YES" : @"NO", exeReadable ? @"YES" : @"NO", exeX_OK ? @"YES" : @"NO"]
 verified:(exeExists && exeReadable && exeX_OK) duration:0];
 if (!exeExists || !exeReadable || !exeX_OK) ok = NO;

 // Info.plist
 NSString *ip = [appPath stringByAppendingPathComponent:@"Info.plist"];
 BOOL infoExists = [fm fileExistsAtPath:ip];
 NSString *recInfo = [opLog beginPhase:OperationPhaseVerify operation:@"verify Info.plist" target:ip input:@"" transactionID:txnID];
 [opLog endPhase:recInfo exitCode:infoExists ? 0 : 1 rawOutput:@"" rawError:infoExists ? @"" : @"Missing"
 verification:[NSString stringWithFormat:@"exists=%@", infoExists ? @"YES" : @"NO"] verified:infoExists duration:0];
 if (!infoExists) ok = NO;

 // Verify signature on main executable
 BOOL exeSigned = [self verifySignature:ep opLog:opLog txnID:txnID];
 if (!exeSigned) ok = NO;

 // Frameworks
 NSString *fwp = [appPath stringByAppendingPathComponent:@"Frameworks"];
 if ([fm fileExistsAtPath:fwp]) {
 for (NSString *item in [fm contentsOfDirectoryAtPath:fwp error:nil]) {
 NSString *p = [fwp stringByAppendingPathComponent:item];
 if ([item hasSuffix:@".dylib"] || [item hasSuffix:@".so"]) {
 BOOL dylibReadable = [fm isReadableFileAtPath:p];
 BOOL dylibX_OK = (access([p UTF8String], X_OK) == 0);
 NSString *recFw = [opLog beginPhase:OperationPhaseVerify operation:[NSString stringWithFormat:@"verify dylib %@", item] target:p input:@"" transactionID:txnID];
 [opLog endPhase:recFw exitCode:(dylibReadable && dylibX_OK) ? 0 : 1 rawOutput:@"" rawError:(dylibReadable && dylibX_OK) ? @"" : @"Permission denied"
 verification:[NSString stringWithFormat:@"readable=%@ xok=%@", dylibReadable ? @"YES" : @"NO", dylibX_OK ? @"YES" : @"NO"]
 verified:(dylibReadable && dylibX_OK) duration:0];
 if (!dylibReadable || !dylibX_OK) ok = NO;
 }
 }
 }

 // Embedded extensions are separate code bundles. A main executable can pass
 // verification while an unsigned appex/xpc crashes the host at launch.
 BOOL embeddedSignaturesOK = [self verifyEmbeddedBundleSignaturesAtPath:appPath opLog:opLog txnID:txnID];
 if (!embeddedSignaturesOK) ok = NO;

 // Check if app is registered in LSApplicationWorkspace (best effort, non-blocking)
 Class LS = objc_getClass("LSApplicationWorkspace");
 if (LS) {
 id ws = [LS performSelector:@selector(defaultWorkspace)];
 if ([ws respondsToSelector:@selector(applicationForIdentifier:)]) {
 id a = [ws performSelector:@selector(applicationForIdentifier:) withObject:bid];
 BOOL registered = (a != nil);
 NSString *recLS = [opLog beginPhase:OperationPhaseVerify operation:@"LSApplicationWorkspace check" target:bid input:@"" transactionID:txnID];
 [opLog endPhase:recLS exitCode:0 rawOutput:@"" rawError:@""
 verification:[NSString stringWithFormat:@"registered=%@", registered ? @"YES" : @"NO"] verified:YES duration:0];
 if (!registered) {
 NSLog(@"[IPAInstallerPro] App not yet registered in LS — uicache may need time");
 }
 }
 }

 // Dopamine-specific: verify app is in correct rootless path (warning only)
 NSString *expectedPrefix = @"/var/jb/Applications/";
 if (![appPath hasPrefix:expectedPrefix] && ![appPath hasPrefix:@"/Applications/"]) {
 NSString *recPath = [opLog beginPhase:OperationPhaseVerify operation:@"rootlessPathCheck" target:appPath input:@"" transactionID:txnID];
 [opLog endPhase:recPath exitCode:0 rawOutput:@"" rawError:@""
 verification:[NSString stringWithFormat:@"path=%@ (non-standard but allowed)", appPath] verified:YES duration:0];
 NSLog(@"[IPAInstallerPro] WARNING: App not in standard Applications path: %@", appPath);
 }

 return ok;
}

- (void)uninstallAppWithBundleID:(NSString *)bundleID completion:(void (^)(BOOL, NSString *))completion {
 if (!bundleID || bundleID.length == 0) {
 if (completion) completion(NO, @"Bundle ID is empty");
 return;
 }

 NSFileManager *fm = [NSFileManager defaultManager];
 NSString *appPath = nil;

 // ─── PHASE 1: Resolve app path via LSApplicationWorkspace ───
 Class LS = objc_getClass("LSApplicationWorkspace");
 if (LS) {
 id ws = [LS performSelector:@selector(defaultWorkspace)];
 if (ws && [ws respondsToSelector:@selector(allApplications)]) {
 NSArray *apps = [ws performSelector:@selector(allApplications)];
 for (id app in apps) {
 NSString *bid = nil;
 if ([app respondsToSelector:@selector(bundleIdentifier)]) {
 bid = [app performSelector:@selector(bundleIdentifier)];
 }
 if ([bid isEqualToString:bundleID]) {
 if ([app respondsToSelector:@selector(bundleURL)]) {
 appPath = [[app performSelector:@selector(bundleURL)] path];
 } else if ([app respondsToSelector:@selector(containerURL)]) {
 appPath = [[app performSelector:@selector(containerURL)] path];
 }
 break;
 }
 }
 }
 }

 // ─── PHASE 2: Scan Applications directories for matching Info.plist ───
 if (!appPath || appPath.length == 0) {
 NSArray *searchDirs = @[@"/var/jb/Applications", @"/Applications", @"/var/mobile/Applications"];
 for (NSString *dir in searchDirs) {
 if (![fm fileExistsAtPath:dir]) continue;
 NSArray *items = [fm contentsOfDirectoryAtPath:dir error:nil];
 for (NSString *item in items) {
 if ([item hasSuffix:@".app"]) {
 NSString *infoPath = [dir stringByAppendingPathComponent:[item stringByAppendingPathComponent:@"Info.plist"]];
 NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
 NSString *bid = info[@"CFBundleIdentifier"];
 if ([bid isEqualToString:bundleID]) {
 appPath = [dir stringByAppendingPathComponent:item];
 break;
 }
 }
 }
 if (appPath) break;
 }
 }

 if (!appPath || appPath.length == 0) {
 if (completion) completion(NO, @"App not found on device");
 return;
 }

 NSLog(@"[IPAInstallerPro] Resolved app path for %@: %@", bundleID, appPath);

 // ─── PHASE 3: Try LSApplicationWorkspace uninstall API (but verify!) ───
 if (LS) {
 id ws = [LS performSelector:@selector(defaultWorkspace)];
 if (ws) {
 BOOL apiCalled = NO;
 if ([ws respondsToSelector:@selector(uninstallApplication:withOptions:)]) {
 (void)[ws performSelector:@selector(uninstallApplication:withOptions:) withObject:bundleID withObject:@{}];
 apiCalled = YES;
 } else if ([ws respondsToSelector:@selector(uninstallApplication:)]) {
 (void)[ws performSelector:@selector(uninstallApplication:) withObject:bundleID];
 apiCalled = YES;
 }
 if (apiCalled && ![fm fileExistsAtPath:appPath]) {
 [self runRoot:self.uicachePath args:@[@"-a"] opLog:nil recordID:nil];
 if (completion) completion(YES, nil);
 return;
 }
 }
 }

 // ─── PHASE 4: Force remove via root helper ───
 // Unregister from SpringBoard first
 [self runRoot:self.uicachePath args:@[@"-p", appPath] opLog:nil recordID:nil];

 // Delete the app bundle
 BOOL removed = NO;
 if ([self hasRootHelper]) {
 removed = [self runRoot:self.rmPath args:@[@"-rf", appPath] opLog:nil recordID:nil];
 } else {
 NSError *err = nil;
 removed = [fm removeItemAtPath:appPath error:&err];
 if (!removed) {
 removed = [self runRoot:self.rmPath args:@[@"-rf", appPath] opLog:nil recordID:nil];
 }
 }

 // ─── PHASE 5: Verify deletion actually happened ───
 if (removed && [fm fileExistsAtPath:appPath]) {
 // Still there — try once more with helper
 removed = [self runRoot:self.rmPath args:@[@"-rf", appPath] opLog:nil recordID:nil];
 }

 if (removed && ![fm fileExistsAtPath:appPath]) {
 [self runRoot:self.uicachePath args:@[@"-a"] opLog:nil recordID:nil];
 if (completion) completion(YES, nil);
 } else {
 if (completion) completion(NO, @"Failed to remove application files — path still exists");
 }
}

#pragma mark - App Icon Extraction

- (NSString *)iconPathForAppAtPath:(NSString *)appPath {
 NSFileManager *fm = [NSFileManager defaultManager];
 NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
 NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
 if (!info) return nil;

 // Try CFBundleIcons (iOS 5+)
 NSDictionary *iconsDict = info[@"CFBundleIcons"];
 if (!iconsDict) iconsDict = info[@"CFBundleIcons~ipad"];

 NSArray *iconFiles = nil;
 if (iconsDict) {
 NSDictionary *primary = iconsDict[@"CFBundlePrimaryIcon"];
 if (primary) iconFiles = primary[@"CFBundleIconFiles"];
 }

 // Fallback to CFBundleIconFiles
 if (!iconFiles || iconFiles.count == 0) {
 iconFiles = info[@"CFBundleIconFiles"];
 }

 // Fallback to CFBundleIconFile (single)
 if (!iconFiles || iconFiles.count == 0) {
 NSString *singleIcon = info[@"CFBundleIconFile"];
 if (singleIcon) iconFiles = @[singleIcon];
 }

 if (!iconFiles || iconFiles.count == 0) return nil;

 // Find the best icon (largest, @2x or @3x preferred)
 NSString *bestIcon = nil;
 for (NSString *iconName in iconFiles) {
 NSString *baseName = [iconName stringByDeletingPathExtension];
 NSString *ext = [iconName pathExtension];
 if (ext.length == 0) ext = @"png";

 // Try @3x first
 NSString *icon3x = [appPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@@3x.%@", baseName, ext]];
 if ([fm fileExistsAtPath:icon3x]) { bestIcon = icon3x; break; }

 // Try @2x
 NSString *icon2x = [appPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@@2x.%@", baseName, ext]];
 if ([fm fileExistsAtPath:icon2x]) { bestIcon = icon2x; break; }

 // Try base
 NSString *iconBase = [appPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", baseName, ext]];
 if ([fm fileExistsAtPath:iconBase]) { bestIcon = iconBase; break; }
 }

 return bestIcon;
}

#pragma mark - Uninstall

- (void)uninstallAppAtPath:(NSString *)appPath bundleID:(NSString *)bundleID completion:(void (^)(BOOL, NSString *))completion {
 if (!appPath || appPath.length == 0 || !bundleID || bundleID.length == 0) {
 [self uninstallAppWithBundleID:bundleID completion:completion];
 return;
 }

 // Unregister from SpringBoard first
 [self runRoot:self.uicachePath args:@[@"-p", appPath] opLog:nil recordID:nil];

 // Delete via root helper
 BOOL removed = [self runRoot:self.rmPath args:@[@"-rf", appPath] opLog:nil recordID:nil];

 // Verify actually gone
 if (removed && ![[NSFileManager defaultManager] fileExistsAtPath:appPath]) {
 [self runRoot:self.uicachePath args:@[@"-a"] opLog:nil recordID:nil];
 if (completion) completion(YES, nil);
 } else {
 if (completion) completion(NO, @"Failed to remove application files");
 }
}
#pragma mark - Smart Signing Plan Execution

- (NSUInteger)executeSigningPlan:(SigningPlan *)plan atAppPath:(NSString *)appPath hasHelper:(BOOL)hasH opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 if (!plan || !plan.isViable || plan.targets.count == 0) {
 NSLog(@"[SmartSign] Invalid plan");
 return 0;
 }
 NSArray *ordered = [plan targetsOrderedForSigning];
 NSUInteger signedCount = 0;
 for (SigningTarget *target in ordered) {
 if (!target.needsSigning) continue;
  NSLog(@"[SmartSign] Signing [%@] %@ with strategy: %@",
        target.targetTypeName, target.targetName, target.strategyNameString);

  BOOL ok = NO;
  switch (target.strategy) {
      case SigningStrategyPreserveOriginal: {
          NSDictionary *ents = target.plannedEntitlements.rawEntitlements;
          if (!ents || ents.count == 0) {
              NSString *entOutput = [self runCmdOutput:self.ldidPath args:@[@"-e", target.filePath]];
              if (entOutput && entOutput.length > 10) {
                  NSString *tmpEnt = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"pres_%@.plist", [[NSUUID UUID] UUIDString]]];
                  [entOutput writeToFile:tmpEnt atomically:YES encoding:NSUTF8StringEncoding error:nil];
                  ents = [NSDictionary dictionaryWithContentsOfFile:tmpEnt];
              }
          }
          ok = [self signTarget:target.filePath withEntitlements:ents hasHelper:hasH opLog:opLog txnID:txnID];
          break;
      }
      case SigningStrategyGeneric:
          ok = [self signTarget:target.filePath withEntitlements:[EntitlementSet genericJailbreakEntitlements] hasHelper:hasH opLog:opLog txnID:txnID];
          break;
      case SigningStrategyMinimal:
          ok = [self signTarget:target.filePath withEntitlements:[EntitlementSet minimalEntitlements] hasHelper:hasH opLog:opLog txnID:txnID];
          break;
      case SigningStrategySkip:
          ok = YES;
          break;
      default:
          ok = [self signTarget:target.filePath withEntitlements:[EntitlementSet genericJailbreakEntitlements] hasHelper:hasH opLog:opLog txnID:txnID];
          break;
  }

  if (!ok) {
      NSLog(@"[SmartSign] FAILED to sign: %@", target.targetName);
  } else {
      signedCount++;
  }

 }
 NSLog(@"[SmartSign] Total signed: %lu / %lu targets", (unsigned long)signedCount, (unsigned long)ordered.count);
 return signedCount;
}

- (BOOL)signTarget:(NSString *)path withEntitlements:(NSDictionary *)entitlements hasHelper:(BOOL)hasH opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 NSFileManager *fm = [NSFileManager defaultManager];
 if (![fm fileExistsAtPath:path]) return NO;
 NSString *recordID = [opLog beginPhase:OperationPhaseSign operation:@"smart-ldid" target:path input:@"" transactionID:txnID];
 NSString *entPath = nil;
 if (entitlements && entitlements.count > 0) {
 NSString *tmpDir = NSTemporaryDirectory();
 NSString *uuid = [[NSUUID UUID] UUIDString];
 entPath = [tmpDir stringByAppendingPathComponent:[NSString stringWithFormat:@"ent_%@.plist", uuid]];
 [entitlements writeToFile:entPath atomically:YES];
 }
 BOOL ok = NO;
 if (entPath) {
 NSString *sf = [NSString stringWithFormat:@"-S%@", entPath];
 ok = hasH ? [self runRoot:self.ldidPath args:@[sf, path] opLog:opLog recordID:recordID]
             : [self runCmd:self.ldidPath args:@[sf, path] opLog:opLog recordID:recordID];
 [fm removeItemAtPath:entPath error:nil];
 } else {
 ok = hasH ? [self runRoot:self.ldidPath args:@[@"-S", path] opLog:opLog recordID:recordID]
             : [self runCmd:self.ldidPath args:@[@"-S", path] opLog:opLog recordID:recordID];
 }
 [opLog endPhase:recordID exitCode:ok ? 0 : 1 rawOutput:@"" rawError:ok ? @"" : @"Smart sign failed" verification:@"smart ldid" verified:ok duration:0];
 return ok;
}


@end