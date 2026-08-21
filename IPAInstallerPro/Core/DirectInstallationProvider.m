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
 [opLog endPhase:rec exitCode:ok ? 0 : 1 rawOutput:@"" rawError:ok ? @"" : @"Deep copy verification failed"
 verification:detail verified:ok duration:0];
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

 // Extract REAL Bundle ID from IPA before anything else
 NSString *realBundleID = [self extractBundleIDFromIPA:ipaPath];
 if (!realBundleID || realBundleID.length == 0) {
 if (completion) completion([InstallationResult failureResult:@"Could not extract Bundle ID from IPA"
 provider:[self providerName] transaction:@"" error:nil evidence:nil]);
 return;
 }

 if (!txnID || txnID.length == 0) {
 txnID = [opLog beginTransactionForIPA:ipaPath];
 }
 // If txnID is provided by the engine, use it directly without creating a duplicate OperationLog entry

 // PHASE 0: SAFETY CHECKS
 if (![self validateIPAPathSafety:ipaPath opLog:opLog txnID:txnID]) {
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"IPA safety check failed" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 // PHASE 1: IPA_OPEN
 NSString *rec1 = [opLog beginPhase:OperationPhaseIPAOpen operation:@"fileExistsAtPath" target:ipaPath input:ipaPath transactionID:txnID];
 BOOL ipaExists = [fm fileExistsAtPath:ipaPath];
 BOOL ipaReadable = [fm isReadableFileAtPath:ipaPath];
 NSDictionary *ipaAttrs = ipaExists ? [fm attributesOfItemAtPath:ipaPath error:nil] : nil;
 [opLog endPhase:rec1 exitCode:ipaExists ? 0 : ENOENT rawOutput:@"" rawError:ipaExists ? @"" : @"IPA not found"
 verification:[NSString stringWithFormat:@"exists=%@ readable=%@ size=%lld", ipaExists ? @"YES" : @"NO", ipaReadable ? @"YES" : @"NO", ipaAttrs ? ipaAttrs.fileSize : 0]
 verified:(ipaExists && ipaReadable) duration:0];

 if (!ipaExists || !ipaReadable) {
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"IPA not found or unreadable" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 // PHASE 2: IPA_EXTRACT
 NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
 NSString *rec2 = [opLog beginPhase:OperationPhaseIPAExtract operation:@"createDirectoryAtPath" target:tmp input:@"" transactionID:txnID];
 BOOL tmpCreated = [fm createDirectoryAtPath:tmp withIntermediateDirectories:YES attributes:nil error:nil];
 [opLog endPhase:rec2 exitCode:tmpCreated ? 0 : 1 rawOutput:@"" rawError:tmpCreated ? @"" : @"Failed to create temp dir"
 verification:[NSString stringWithFormat:@"created=%@", tmpCreated ? @"YES" : @"NO"] verified:tmpCreated duration:0];

 if (!tmpCreated) {
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"Temp directory creation failed" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 NSString *rec3 = [opLog beginPhase:OperationPhaseIPAExtract operation:@"unzip" target:ipaPath input:[@[@"-o", ipaPath, @"-d", tmp] componentsJoinedByString:@" "] transactionID:txnID];
 BOOL unzipOk = [self runCmd:self.unzipPath args:@[@"-o", ipaPath, @"-d", tmp] opLog:opLog recordID:rec3];
 NSString *payload = [tmp stringByAppendingPathComponent:@"Payload"];
 BOOL payloadExists = [fm fileExistsAtPath:payload];

 if (!unzipOk || !payloadExists) {
 [fm removeItemAtPath:tmp error:nil];
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"Unzip failed" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 // PHASE 3: APP_IDENTIFY + SECURITY CHECK
 NSString *rec4 = [opLog beginPhase:OperationPhaseAppIdentify operation:@"find .app in Payload" target:payload input:@"" transactionID:txnID];
 NSArray *items = [fm contentsOfDirectoryAtPath:payload error:nil];
 NSString *appFolder = nil;
 for (NSString *i in items) { if ([i hasSuffix:@".app"]) { appFolder = i; break; } }
 BOOL appFound = (appFolder != nil);
 [opLog endPhase:rec4 exitCode:appFound ? 0 : 1 rawOutput:@"" rawError:appFound ? @"" : @"No .app folder found"
 verification:[NSString stringWithFormat:@"found=%@ name=%@", appFound ? @"YES" : @"NO", appFolder ?: @"N/A"] verified:appFound duration:0];

 if (!appFound) {
 [fm removeItemAtPath:tmp error:nil];
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"No .app found" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 NSString *srcApp = [payload stringByAppendingPathComponent:appFolder];

 // Security: Check for dangerous symlinks
 if (![self checkForSymlinksInExtractedPath:srcApp opLog:opLog txnID:txnID]) {
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
 verified:infoHasKeys duration:0];

 if (!infoHasKeys) {
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
 [opLog endPhase:recPlan exitCode:0 rawOutput:planGenerated ? @"Smart signing plan generated" : @"Smart signing plan unavailable, using legacy fallback" rawError:@"" verification:@"smart signing plan" verified:planGenerated duration:0];

 // PHASE 4: FILE_COPY (with backup/rollback)
 NSString *logicalDest = [@"/Applications" stringByAppendingPathComponent:appFolder];
 NSString *rec7 = [opLog beginPhase:OperationPhaseFileCopy operation:@"resolvePath" target:logicalDest input:logicalDest transactionID:txnID];
 NSString *destApp = [[RootlessManager sharedManager] resolvePath:logicalDest];
 BOOL destResolved = (destApp != nil && destApp.length > 0);
 [opLog endPhase:rec7 exitCode:destResolved ? 0 : 1 rawOutput:destApp ?: @"" rawError:destResolved ? @"" : @"RootlessManager failed"
 verification:[NSString stringWithFormat:@"resolved=%@ path=%@", destResolved ? @"YES" : @"NO", destApp ?: @"N/A"] verified:destResolved duration:0];

 if (!destResolved) {
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

 // Deep copy verification
 BOOL deepOk = [self verifyDeepCopy:srcApp dst:destApp opLog:opLog txnID:txnID];
 if (!deepOk) {
 // ROLLBACK
 [self restoreBackup:backupPath to:destApp opLog:opLog txnID:txnID];
 [fm removeItemAtPath:tmp error:nil];
 [opLog endTransaction:txnID finalResult:OperationResultFailed];
 if (completion) completion([InstallationResult failureResult:@"Deep copy verification failed, rollback executed" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
 return;
 }

 // PHASE 5: PERMISSION
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

 // PHASE 6: SMART SIGN
 NSString *rec11 = [opLog beginPhase:OperationPhaseSign operation:@"smart-sign-execute" target:destApp input:@"" transactionID:txnID];
 BOOL signOk = NO;
 BOOL usedSmartSigning = NO;
 if (planGenerated && signingPlan) {
 signOk = [self executeSigningPlan:signingPlan atAppPath:destApp hasHelper:hasH opLog:opLog txnID:txnID];
 usedSmartSigning = signOk;
 }
 if (!usedSmartSigning) {
 // Legacy fallback
 [self signAllAt:destApp hasHelper:hasH opLog:opLog txnID:txnID];
 [self signExe:destExe hasHelper:hasH opLog:opLog txnID:txnID];
 BOOL sigOk = [self verifySignature:destExe opLog:opLog txnID:txnID];
 if (!sigOk) {
     [self signExeWithExplicitEntitlements:destExe hasHelper:hasH opLog:opLog txnID:txnID];
     sigOk = [self verifySignature:destExe opLog:opLog txnID:txnID];
     if (!sigOk) {
         [opLog endPhase:rec11 exitCode:1 rawOutput:@"" rawError:@"Legacy signing failed" verification:@"legacy signing" verified:NO duration:0];
         [self restoreBackup:backupPath to:destApp opLog:opLog txnID:txnID];
         [fm removeItemAtPath:tmp error:nil];
         [opLog endTransaction:txnID finalResult:OperationResultFailed];
         if (completion) completion([InstallationResult failureResult:@"Signature failed — rollback" provider:[self providerName] transaction:txnID error:nil evidence:nil]);
         return;
     }
 }
 signOk = YES;

 } else {
 signOk = [self verifySignature:destExe opLog:opLog txnID:txnID];
 if (!signOk) {
 [self signExeWithExplicitEntitlements:destExe hasHelper:hasH opLog:opLog txnID:txnID];
 signOk = [self verifySignature:destExe opLog:opLog txnID:txnID];
 }
 }
 [opLog endPhase:rec11 exitCode:signOk ? 0 : 1 rawOutput:@"" rawError:signOk ? @"" : @"Signing failed" verification:@"legacy signing" verified:signOk duration:0];
 // PHASE 7: FRAMEWORK (legacy only if no smart signing)
 if (!usedSmartSigning) {
 [self fixFrameworks:destApp hasHelper:hasH opLog:opLog txnID:txnID];
 }

 // PHASE 8: UICACHE
 NSString *rec14a = [opLog beginPhase:OperationPhaseUICache operation:@"uicache -p logical" target:logicalDest input:@"" transactionID:txnID];
 [self runRoot:self.uicachePath args:@[@"-p", logicalDest] opLog:opLog recordID:rec14a];

 NSString *rec14b = [opLog beginPhase:OperationPhaseUICache operation:@"uicache -p resolved" target:destApp input:@"" transactionID:txnID];
 [self runRoot:self.uicachePath args:@[@"-p", destApp] opLog:opLog recordID:rec14b];

 NSString *rec14c = [opLog beginPhase:OperationPhaseUICache operation:@"uicache -a" target:@"" input:@"" transactionID:txnID];
 [self runRoot:self.uicachePath args:@[@"-a"] opLog:opLog recordID:rec14c];

 // PHASE 9: VERIFY (comprehensive)
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
 NSString *rec16 = [opLog beginPhase:OperationPhaseCleanup operation:@"remove temp" target:tmp input:@"" transactionID:txnID];
 [fm removeItemAtPath:tmp error:nil];
 BOOL tmpRemoved = ![fm fileExistsAtPath:tmp];
 [opLog endPhase:rec16 exitCode:tmpRemoved ? 0 : 1 rawOutput:@"" rawError:tmpRemoved ? @"" : @"Temp still exists"
 verification:[NSString stringWithFormat:@"removed=%@", tmpRemoved ? @"YES" : @"NO"] verified:tmpRemoved duration:0];

 // SUCCESS
 [opLog endTransaction:txnID finalResult:OperationResultSuccess];
 InstallationResult *result = [InstallationResult successResult:[NSString stringWithFormat:@"Installed %@", appFolder]
 provider:[self providerName] transaction:txnID evidence:@{@"bundleID": bundleID, @"path": destApp, @"exe": exeName}];
 result.bundleID = bundleID;
 if (completion) completion(result);
}

#pragma mark - Bundle ID Extraction

- (NSString *)extractBundleIDFromIPA:(NSString *)ipaPath {
 NSFileManager *fm = [NSFileManager defaultManager];
 NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
 [fm createDirectoryAtPath:tmp withIntermediateDirectories:YES attributes:nil error:nil];

 // Quick unzip of Info.plist only
 [self runCmd:self.unzipPath args:@[@"-j", @"-o", ipaPath, @"Payload/*/Info.plist", @"-d", tmp] opLog:nil recordID:nil];

 NSString *infoPath = [tmp stringByAppendingPathComponent:@"Info.plist"];
 NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
 NSString *bundleID = info[@"CFBundleIdentifier"];

 [fm removeItemAtPath:tmp error:nil];
 return bundleID;
}

#pragma mark - Signing

- (void)signAllAt:(NSString *)path hasHelper:(BOOL)hasH opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 NSFileManager *fm = [NSFileManager defaultManager];
 for (NSString *item in [fm contentsOfDirectoryAtPath:path error:nil]) {
 NSString *ip = [path stringByAppendingPathComponent:item];
 BOOL isDir = NO;
 [fm fileExistsAtPath:ip isDirectory:&isDir];
 if (isDir) {
 [self signAllAt:ip hasHelper:hasH opLog:opLog txnID:txnID];
 if ([item hasSuffix:@".app"]) {
 NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[ip stringByAppendingPathComponent:@"Info.plist"]];
 NSString *en = info[@"CFBundleExecutable"];
 if (en) [self signBin:[ip stringByAppendingPathComponent:en] hasHelper:hasH label:[@"app:" stringByAppendingString:en] opLog:opLog txnID:txnID];
 } else if ([item hasSuffix:@".framework"]) {
 NSString *fn = [item stringByDeletingPathExtension];
 [self signBin:[ip stringByAppendingPathComponent:fn] hasHelper:hasH label:[@"fw:" stringByAppendingString:fn] opLog:opLog txnID:txnID];
 } else if ([item hasSuffix:@".appex"] || [item hasSuffix:@".xpc"]) {
 // Complex apps commonly contain extension executables. They must
 // be signed with their own original entitlements, not generic app
 // entitlements, otherwise launch can crash after registration.
 [self signBundleExecutableAtPath:ip
 label:[NSString stringWithFormat:@"%@:%@", [item.pathExtension lowercaseString], item]
 hasHelper:hasH opLog:opLog txnID:txnID];
 }
 } else if ([item hasSuffix:@".dylib"] || [item hasSuffix:@".so"]) {
 [self signBin:ip hasHelper:hasH label:[@"dylib:" stringByAppendingString:item] opLog:opLog txnID:txnID];
 }
 }
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
 NSString *entOutput = [self runCmdOutput:self.ldidPath args:@[@"-e", executablePath]];
 NSString *entPath = nil;
 NSArray *signArgs = nil;
 if (entOutput.length > 0) {
 entPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ipa-ent-%@.plist", [NSUUID UUID].UUIDString]];
 [entOutput writeToFile:entPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
 signArgs = @[[NSString stringWithFormat:@"-S%@", entPath], executablePath];
 } else {
 signArgs = @[@"-S", executablePath];
 }

 BOOL signedOK = hasH ? [self runRoot:self.ldidPath args:signArgs opLog:opLog recordID:rec]
 : [self runCmd:self.ldidPath args:signArgs opLog:opLog recordID:rec];
 if (entPath) [fm removeItemAtPath:entPath error:nil];
 return signedOK;
}

- (void)signBin:(NSString *)path hasHelper:(BOOL)hasH label:(NSString *)label opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 if (!path || ![[NSFileManager defaultManager] fileExistsAtPath:path]) return;
 NSString *rec = [opLog beginPhase:OperationPhaseSign operation:[NSString stringWithFormat:@"ldid -S (%@)", label] target:path input:@"" transactionID:txnID];
 if (hasH) [self runRoot:self.chmodPath args:@[@"755", path] opLog:opLog recordID:nil];
 else [self runCmd:self.chmodPath args:@[@"755", path] opLog:opLog recordID:nil];
 BOOL ok = hasH ? [self runRoot:self.ldidPath args:@[@"-S", path] opLog:opLog recordID:rec]
 : [self runCmd:self.ldidPath args:@[@"-S", path] opLog:opLog recordID:rec];
 if (!ok) {
 // Retry with minimal entitlements
 NSString *ep = [NSTemporaryDirectory() stringByAppendingPathComponent:@"min.ent"];
 [@{@"get-task-allow":@YES, @"platform-application":@YES} writeToFile:ep atomically:YES];
 NSString *sf = [NSString stringWithFormat:@"-S%@", ep];
 [self runCmd:self.ldidPath args:@[sf, path] opLog:opLog recordID:rec];
 }
}

- (void)signExe:(NSString *)path hasHelper:(BOOL)hasH opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return;
 NSString *rec = [opLog beginPhase:OperationPhaseSign operation:@"signExe (main)" target:path input:@"" transactionID:txnID];
 NSString *ep = [NSTemporaryDirectory() stringByAppendingPathComponent:@"orig.ent"];
 NSString *entOutput = [self runCmdOutput:self.ldidPath args:@[@"-e", path]];
 if (entOutput && entOutput.length > 10) {
 [entOutput writeToFile:ep atomically:YES encoding:NSUTF8StringEncoding error:nil];
 NSString *sf = [NSString stringWithFormat:@"-S%@", ep];
 BOOL ok = hasH ? [self runRoot:self.ldidPath args:@[sf, path] opLog:opLog recordID:rec]
 : [self runCmd:self.ldidPath args:@[sf, path] opLog:opLog recordID:rec];
 if (ok) return;
 }
 BOOL ok = hasH ? [self runRoot:self.ldidPath args:@[@"-S", path] opLog:opLog recordID:rec]
 : [self runCmd:self.ldidPath args:@[@"-S", path] opLog:opLog recordID:rec];
 if (!ok) {
 NSString *ep2 = [NSTemporaryDirectory() stringByAppendingPathComponent:@"min.ent"];
 [@{@"get-task-allow":@YES, @"platform-application":@YES} writeToFile:ep2 atomically:YES];
 NSString *sf = [NSString stringWithFormat:@"-S%@", ep2];
 [self runCmd:self.ldidPath args:@[sf, path] opLog:opLog recordID:rec];
 }
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

 // Check if app is registered in LSApplicationWorkspace (best effort)
 Class LS = objc_getClass("LSApplicationWorkspace");
 if (LS) {
 id ws = [LS performSelector:@selector(defaultWorkspace)];
 if ([ws respondsToSelector:@selector(applicationForIdentifier:)]) {
 id a = [ws performSelector:@selector(applicationForIdentifier:) withObject:bid];
 BOOL registered = (a != nil);
 NSString *recLS = [opLog beginPhase:OperationPhaseVerify operation:@"LSApplicationWorkspace check" target:bid input:@"" transactionID:txnID];
 [opLog endPhase:recLS exitCode:registered ? 0 : 1 rawOutput:@"" rawError:registered ? @"" : @"Not registered"
 verification:[NSString stringWithFormat:@"registered=%@", registered ? @"YES" : @"NO"] verified:registered duration:0];
 if (!registered) {
 // Not critical — uicache may need time
 NSLog(@"[IPAInstallerPro] App not yet registered in LS, but uicache was run");
 }
 }
 }

 // Dopamine-specific: verify app is in correct rootless path
 NSString *expectedPrefix = @"/var/jb/Applications/";
 if (![appPath hasPrefix:expectedPrefix]) {
 NSString *recPath = [opLog beginPhase:OperationPhaseVerify operation:@"rootlessPathCheck" target:appPath input:@"" transactionID:txnID];
 [opLog endPhase:recPath exitCode:1 rawOutput:@"" rawError:@"App not in rootless Applications path"
 verification:[NSString stringWithFormat:@"path=%@ expectedPrefix=%@", appPath, expectedPrefix] verified:NO duration:0];
 ok = NO;
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

- (BOOL)executeSigningPlan:(SigningPlan *)plan atAppPath:(NSString *)appPath hasHelper:(BOOL)hasH opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 if (!plan || !plan.isViable || plan.targets.count == 0) {
 NSLog(@"[SmartSign] Invalid plan");
 return NO;
 }
 NSArray *ordered = [plan targetsOrderedForSigning];
 BOOL allOk = YES;
 for (SigningTarget *target in ordered) {
 if (!target.needsSigning) continue;

  // Resolve full target path
  NSString *targetPath = target.filePath;
  if (!targetPath || targetPath.length == 0) {
      NSLog(@"[SmartSign] SKIP: empty path for %@", target.targetName);
      continue;
  }
  if (![targetPath hasPrefix:@"/"]) {
      targetPath = [appPath stringByAppendingPathComponent:targetPath];
  }
  if (![[NSFileManager defaultManager] fileExistsAtPath:targetPath]) {
      NSLog(@"[SmartSign] SKIP: not found %@", targetPath);
      continue;
  }

  NSLog(@"[SmartSign] Signing [%@] %@ at %@ strategy: %@",
        target.targetTypeName, target.targetName, targetPath, target.strategyNameString);

  BOOL ok = NO;
  switch (target.strategy) {
      case SigningStrategyPreserveOriginal: {
          NSDictionary *ents = target.plannedEntitlements.rawEntitlements;
          if (!ents || ents.count == 0) {
              NSString *entOutput = [self runCmdOutput:self.ldidPath args:@[@"-e", targetPath]];
              if (entOutput && entOutput.length > 10) {
                  NSString *tmpEnt = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"pres_%@.plist", [[NSUUID UUID] UUIDString]]];
                  [entOutput writeToFile:tmpEnt atomically:YES encoding:NSUTF8StringEncoding error:nil];
                  ents = [NSDictionary dictionaryWithContentsOfFile:tmpEnt];
              }
              if (!ents || ents.count == 0) {
                  NSLog(@"[SmartSign] PreserveOriginal fallback to Generic for: %@", target.targetName);
                  ents = [EntitlementSet genericJailbreakEntitlements];
              }
          }
          ok = [self signTarget:targetPath withEntitlements:ents hasHelper:hasH opLog:opLog txnID:txnID];
          break;
      }
      case SigningStrategyGeneric:
          ok = [self signTarget:targetPath withEntitlements:[EntitlementSet genericJailbreakEntitlements] hasHelper:hasH opLog:opLog txnID:txnID];
          break;
      case SigningStrategyMinimal:
          ok = [self signTarget:targetPath withEntitlements:[EntitlementSet minimalEntitlements] hasHelper:hasH opLog:opLog txnID:txnID];
          break;
      case SigningStrategySkip:
          ok = YES;
          break;
      default:
          ok = [self signTarget:targetPath withEntitlements:[EntitlementSet genericJailbreakEntitlements] hasHelper:hasH opLog:opLog txnID:txnID];
          break;
  }

  if (!ok) {
      NSLog(@"[SmartSign] FAILED to sign: %@", target.targetName);
      allOk = NO;
  }

 }
 return allOk;
}

- (BOOL)signTarget:(NSString *)path withEntitlements:(NSDictionary *)entitlements hasHelper:(BOOL)hasH opLog:(OperationLog *)opLog txnID:(NSString *)txnID {
 NSFileManager *fm = [NSFileManager defaultManager];
 NSLog(@"[SmartSign] signTarget: path=%@ ents=%lu", path, (unsigned long)(entitlements ? entitlements.count : 0));
 if (![fm fileExistsAtPath:path]) {
     NSLog(@"[SmartSign] signTarget: FILE NOT FOUND: %@", path);
     return NO;
 }
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