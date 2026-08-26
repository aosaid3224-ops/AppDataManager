//
//  RuntimeDiagnostics.m
//  IPAInstallerPro
//
//  Post-Install Runtime Observability Layer — Implementation.
//  OBSERVE → MEASURE → RECORD. Never assume. Never fix without data.
//

#import "RuntimeDiagnostics.h"
#import "OperationLog.h"
#import "RootlessManager.h"
#import "MachOAnalyzer.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <sys/types.h>
#import <signal.h>
#import <spawn.h>
#import <UIKit/UIKit.h>
#import <sys/wait.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <errno.h>
#import <unistd.h>

// ─── ProcessInfo Implementation ───
@implementation ProcessInfo
@end

// ─── RuntimeDiagnosticsResult Implementation ───
@implementation RuntimeDiagnosticsResult

- (NSString *)detailedReport {
    NSMutableString *r = [NSMutableString string];
    [r appendFormat:@"\n=== Runtime Diagnostics Report ===\n"];
    [r appendFormat:@"Bundle ID: %@\n", self.bundleID ?: @"N/A"];
    [r appendFormat:@"State: %@\n", self.state ?: @"N/A"];
    [r appendFormat:@"\n--- Timing ---\n"];
    [r appendFormat:@"Launch requested: %@\n", self.launchRequestedAt ?: @"N/A"];
    [r appendFormat:@"Process detected: %@\n", self.processDetectedAt ?: @"N/A"];
    [r appendFormat:@"Process exit: %@\n", self.processExitAt ?: @"N/A"];
    [r appendFormat:@"Launch detection time: %.0f ms\n", self.launchDetectionTimeMs];
    [r appendFormat:@"Process lifetime: %.0f ms\n", self.processLifetimeMs];
    NSString *exitAfter = self.processExitAfterLaunchMs >= 0 ? [NSString stringWithFormat:@"%.0f ms", self.processExitAfterLaunchMs] : @"N/A (process remained alive)";
    [r appendFormat:@"Process exit after launch: %@\n", exitAfter];
    [r appendFormat:@"Monitoring window: %.0f ms\n", self.monitoringWindowMs];
    [r appendFormat:@"Failure stage: %@\n", self.failureStage ?: @"N/A"];
    [r appendFormat:@"Evidence: %@\n", self.evidenceSummary ?: @"N/A"];
    if (self.phaseTimeline.count > 0) {
        [r appendFormat:@"Phase timeline: %@\n", [self.phaseTimeline componentsJoinedByString:@" -> "]];
    }
    [r appendFormat:@"\n--- Process ---\n"];
    [r appendFormat:@"Detected: %@\n", self.processDetected ? @"YES" : @"NO"];
    [r appendFormat:@"PID: %d\n", self.pid];
    [r appendFormat:@"UID: %d\n", self.uid];
    [r appendFormat:@"GID: %d\n", self.gid];
    [r appendFormat:@"Remained alive: %@\n", self.processRemainedAlive ? @"YES" : @"NO"];
    [r appendFormat:@"\n--- Crash ---\n"];
    [r appendFormat:@"Crash detected: %@\n", self.crashDetected ? @"YES" : @"NO"];
    [r appendFormat:@"Termination reason: %@\n", self.terminationReason ?: @"N/A"];
    [r appendFormat:@"Crash report path: %@\n", self.crashReportPath ?: @"unavailable"];
    if (self.crashReportPID > 0) {
        [r appendFormat:@"Crash report PID: %d\n", self.crashReportPID];
        [r appendFormat:@"Crash report PID matched launch: %@\n", self.crashReportPIDMatched ? @"YES" : @"NO"];
    }
    if (self.crashExceptionType.length > 0 || self.crashSignal.length > 0 || self.crashTerminationIndicator.length > 0 || self.crashFaultingThread.length > 0) {
        [r appendFormat:@"Crash exception: %@\n", self.crashExceptionType ?: @"N/A"];
        [r appendFormat:@"Crash signal: %@\n", self.crashSignal ?: @"N/A"];
        [r appendFormat:@"Termination indicator: %@\n", self.crashTerminationIndicator ?: @"N/A"];
        [r appendFormat:@"Faulting thread: %@\n", self.crashFaultingThread ?: @"N/A"];
    }
    if (self.crashAnalysisSummary.length > 0) {
        [r appendFormat:@"Crash analysis: %@\n", self.crashAnalysisSummary];
    }
    if (self.diagnosticOutput && self.diagnosticOutput.length > 0) {
        [r appendFormat:@"\n--- Diagnostic Output ---\n%@\n", self.diagnosticOutput];
    }
    [r appendFormat:@"\n=== End Report ===\n"];
    return r;
}

@end

// ─── RuntimeDiagnostics Implementation ───
@interface RuntimeDiagnostics ()
- (NSString *)processSnapshotForPID:(pid_t)pid;
- (NSString *)launchDependencyReportForBundleID:(NSString *)bundleID;
- (BOOL)monitorProcess:(pid_t)pid duration:(NSTimeInterval)duration trace:(NSMutableString *)trace exitStatus:(int *)exitStatus signalNum:(int *)signalNum;
- (NSString *)waitForFreshCrashReportForBundleID:(NSString *)bundleID processName:(NSString *)processName pid:(pid_t)pid launchedAt:(NSDate *)launchedAt timeout:(NSTimeInterval)timeout;
- (NSString *)crashReportAnalysisForPath:(NSString *)path expectedPID:(pid_t)pid result:(RuntimeDiagnosticsResult *)result;
@end

@implementation RuntimeDiagnostics

+ (instancetype)sharedDiagnostics {
    static RuntimeDiagnostics *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _processDetectionTimeout = 8.0;
        _monitoringWindow = 20.0;
        _pollInterval = 0.5;
    }
    return self;
}

#pragma mark - Main Diagnostic Entry

- (void)diagnoseAppLaunch:(NSString *)bundleID
           transactionID:(NSString *)txnID
            operationLog:(OperationLog *)opLog
              completion:(void (^)(RuntimeDiagnosticsResult *result))completion {

    NSDate *overallStart = [NSDate date];
    RuntimeDiagnosticsResult *result = [[RuntimeDiagnosticsResult alloc] init];
    result.bundleID = bundleID;
    result.state = @"NOT_STARTED";
    result.launchRequestedAt = [NSDate date];
    result.monitoringWindowMs = self.monitoringWindow * 1000.0;
    result.failureStage = @"not_started";
    NSMutableArray<NSString *> *timeline = [NSMutableArray array];
    result.phaseTimeline = timeline;
    [timeline addObject:@"launch_request_started"];

    NSLog(@"[RuntimeDiagnostics] Starting diagnosis for %@", bundleID);
    // Inventory is collected before launch so a fast crash cannot occur while
    // the diagnostic layer is still scanning the bundle.
    NSString *launchMap = [self launchDependencyReportForBundleID:bundleID];

    // PHASE 1: LAUNCH
    NSString *recLaunch = [opLog beginPhase:OperationPhaseLaunch
                                  operation:@"launchApp"
                                     target:bundleID
                                      input:@""
                              transactionID:txnID];

    result.state = @"LAUNCH_REQUESTED";
    BOOL launched = [self launchAppWithBundleID:bundleID];
    NSTimeInterval launchDuration = [[NSDate date] timeIntervalSinceDate:result.launchRequestedAt] * 1000.0;

    [opLog endPhase:recLaunch
           exitCode:launched ? 0 : 1
          rawOutput:@""
           rawError:launched ? @"" : @"LSApplicationWorkspace openApplicationWithBundleID failed"
       verification:launched ? @"Launch request dispatched" : @"Launch request failed"
           verified:launched
           duration:launchDuration / 1000.0];

    if (!launched) {
        [timeline addObject:@"launch_request_failed"];
        result.failureStage = @"launch_request";
        result.evidenceSummary = @"The launch request was rejected before process detection";
        result.success = NO;
        result.state = @"LAUNCH_FAILED";
        result.summary = @"Launch request failed";
        if (completion) completion(result);
        return;
    }

    [timeline addObject:@"launch_request_dispatched"];
    // PHASE 2: PROCESS DETECTION
    NSString *recDetect = [opLog beginPhase:OperationPhaseLaunch
                                  operation:@"processDetection"
                                     target:bundleID
                                      input:[NSString stringWithFormat:@"timeout=%.1fs", self.processDetectionTimeout]
                              transactionID:txnID];

    NSDate *detectStart = [NSDate date];
    ProcessInfo *proc = [self detectProcessForBundleID:bundleID timeout:self.processDetectionTimeout];
    result.launchDetectionTimeMs = [[NSDate date] timeIntervalSinceDate:detectStart] * 1000.0;
    result.processDetectedAt = proc ? [NSDate date] : nil;

    if (proc) {
        [timeline addObject:@"process_detected"];
        result.failureStage = @"process_detection_passed";
        result.processDetected = YES;
        result.pid = proc.pid;
        result.uid = proc.uid;
        result.gid = proc.gid;
        result.appName = proc.name;
        result.executablePath = proc.executablePath;
        result.state = @"PROCESS_DETECTED";

        NSString *procInfo = [NSString stringWithFormat:@"PID=%d name=%@ UID=%d GID=%d path=%@",
                              proc.pid, proc.name, proc.uid, proc.gid, proc.executablePath ?: @"N/A"];

        [opLog endPhase:recDetect
               exitCode:0
              rawOutput:procInfo
               rawError:@""
           verification:[NSString stringWithFormat:@"Process detected in %.0f ms", result.launchDetectionTimeMs]
               verified:YES
               duration:result.launchDetectionTimeMs / 1000.0];

        NSLog(@"[RuntimeDiagnostics] Process detected: %@", procInfo);
    } else {
        [timeline addObject:@"process_not_detected"];
        result.failureStage = @"process_detection";
        result.evidenceSummary = @"No matching process was observed within the detection window";
        result.processDetected = NO;
        result.state = @"PROCESS_NOT_DETECTED";
        result.success = NO;
        result.summary = [NSString stringWithFormat:@"Process not detected within %.1fs", self.processDetectionTimeout];

        [opLog endPhase:recDetect
               exitCode:1
              rawOutput:@""
               rawError:[NSString stringWithFormat:@"No process matching %@ found after %.1fs", bundleID, self.processDetectionTimeout]
           verification:@"Process detection timeout"
               verified:NO
               duration:result.launchDetectionTimeMs / 1000.0];

        if (completion) completion(result);
        return;
    }

    [timeline addObject:@"runtime_monitor_started"];
    // PHASE 3: RUNTIME MONITORING
    NSString *recMonitor = [opLog beginPhase:OperationPhaseRuntimeMonitor
                                   operation:@"runtimeMonitor"
                                      target:bundleID
                                       input:[NSString stringWithFormat:@"PID=%d window=%.1fs poll=%.1fs",
                                              result.pid, self.monitoringWindow, self.pollInterval]
                               transactionID:txnID];

    NSDate *monitorStart = [NSDate date];
    NSMutableString *liveTrace = [NSMutableString stringWithFormat:@"[0ms] monitor_started pid=%d\n", result.pid];
    [liveTrace appendFormat:@"=== Launch Dependency Inventory ===\n%@\n", launchMap ?: @"inventory_unavailable"];
    // The installer is not the parent of the target app, so waitpid may not
    // expose its exit status. Keep that state explicitly unknown instead of
    // misclassifying a disappeared process as a normal exit.
    int exitStatus = -1;
    int signalNum = 0;
    BOOL stillAlive = [self monitorProcess:result.pid duration:self.monitoringWindow trace:liveTrace exitStatus:&exitStatus signalNum:&signalNum];
    NSTimeInterval monitorDuration = [[NSDate date] timeIntervalSinceDate:monitorStart] * 1000.0;

    if (!stillAlive) {
        // Process exited during monitoring
        result.processRemainedAlive = NO;
        result.processExitAt = [NSDate date];
        result.processLifetimeMs = monitorDuration;

        // Determine termination reason from actual data
        NSString *terminationReason = [self determineTerminationReason:result.pid
                                                               bundleID:bundleID
                                                              processName:proc.name
                                                               exitStatus:exitStatus
                                                                signalNum:signalNum];
        result.terminationReason = terminationReason;
        // ─── STATE CLASSIFICATION ───
        // RUNNING: stayed alive for full window
        // EXITED_NORMAL: exited with status 0 (no crash signal)
        // CRASHED: terminated by crash signal (SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGTRAP)
        // KILLED_JETSAM: terminated by SIGKILL (OOM or system kill)
        // UNKNOWN: cannot determine reason
        
        NSString *state;
        NSString *terminationType;
        BOOL crashDetected = NO;
        int exitCodeForLog = 1;
        
        if (signalNum == SIGKILL) {
            state = @"KILLED_JETSAM";
            terminationType = @"Killed by SIGKILL";
            exitCodeForLog = 3;
            NSString *jetsam = [self findJetsamEventForProcessName:proc.name bundleID:bundleID];
            if (jetsam) {
                terminationType = @"Killed by Jetsam (out-of-memory)";
            }
        } else if (signalNum == SIGTERM) {
            state = @"KILLED";
            terminationType = @"Terminated by SIGTERM";
            exitCodeForLog = 3;
        } else if (signalNum != 0) {
            state = @"CRASHED";
            terminationType = [NSString stringWithFormat:@"Crashed by %@ (%d)", [self signalName:signalNum], signalNum];
            crashDetected = YES;
            exitCodeForLog = 2;
        } else if (exitStatus < 0) {
            state = @"EXITED_UNOBSERVED";
            terminationType = @"Process disappeared; exit status/signal unavailable because the app is not a child of the installer";
            exitCodeForLog = 1;
        } else if (exitStatus == 0) {
            state = @"EXITED_NORMAL";
            terminationType = @"Exited normally (status 0)";
            exitCodeForLog = 1;
        } else {
            state = @"EXITED_WITH_ERROR";
            terminationType = [NSString stringWithFormat:@"Exited with error status %d", exitStatus];
            exitCodeForLog = 1;
        }
        
        [timeline addObject:@"process_exited"];
        result.failureStage = @"runtime_monitoring";
        result.evidenceSummary = crashDetected ? @"Termination signal observed from process monitoring" : (exitStatus < 0 ? @"Process disappeared; exit status was not observable" : @"Process exit observed without a crash signal");
        result.processExitAfterLaunchMs = result.processDetectedAt ? ([[NSDate date] timeIntervalSinceDate:result.processDetectedAt] * 1000.0) : monitorDuration;
        result.crashDetected = crashDetected;
        result.state = state;
        result.terminationReason = terminationType;
        result.success = NO;
        result.summary = [NSString stringWithFormat:@"%@ after %.0f ms", terminationType, monitorDuration];
        
        [opLog endPhase:recMonitor
               exitCode:exitCodeForLog
              rawOutput:[NSString stringWithFormat:@"lifetime=%.0fms exitStatus=%d signal=%d state=%@", monitorDuration, exitStatus, signalNum, state]
               rawError:terminationType
           verification:[NSString stringWithFormat:@"Process %@ after %.0f ms", state, monitorDuration]
               verified:NO
               duration:monitorDuration / 1000.0];
        
        NSLog(@"[RuntimeDiagnostics] Process %@ after %.0f ms (exit=%d signal=%d)", state, monitorDuration, exitStatus, signalNum);

        // ─── PHASE 4: COMPREHENSIVE CRASH DIAGNOSTICS ───
        NSString *recCrash = [opLog beginPhase:OperationPhaseCrashDiagnostics
                                      operation:@"crashDiagnostics"
                                         target:bundleID
                                          input:[NSString stringWithFormat:@"PID=%d exitStatus=%d signal=%d", result.pid, exitStatus, signalNum]
                                  transactionID:txnID];

        NSMutableString *diagnosticOutput = [NSMutableString string];
        [diagnosticOutput appendFormat:@"=== Live Process Trace ===\n%@\n\n", liveTrace];

        // 4a. Crash Reporter (.ips files)
        NSString *crashPath = [self waitForFreshCrashReportForBundleID:bundleID processName:proc.name pid:result.pid launchedAt:result.processDetectedAt timeout:3.0];
        [timeline addObject:@"crash_evidence_lookup"];
        if (crashPath) {
            [timeline addObject:@"crash_report_found"];
            result.failureStage = @"crash_report";
            result.evidenceSummary = @"A fresh OS crash report matched the launched process";
            // A fresh crash report is stronger evidence than the unavailable
            // waitpid status for an unrelated application process.
            result.crashDetected = YES;
            result.state = @"CRASHED";
            result.summary = [NSString stringWithFormat:@"Crash report found after process exit: %@", crashPath.lastPathComponent];
            result.crashReportPath = crashPath;
            NSString *crashContent = [NSString stringWithContentsOfFile:crashPath encoding:NSUTF8StringEncoding error:nil];
            if (crashContent) {
                [diagnosticOutput appendFormat:@"=== Crash Report (%@) ===\n%@\n\n", crashPath, crashContent];
                NSString *crashAnalysis = [self crashReportAnalysisForPath:crashPath expectedPID:result.pid result:result];
                if (crashAnalysis.length > 0) {
                    [diagnosticOutput appendFormat:@"=== Crash Analysis (PID-matched) ===\n%@\n\n", crashAnalysis];
                }
            }
        }

        // 4b. Jetsam Events (out-of-memory kills)
        NSString *jetsamInfo = [self findJetsamEventForProcessName:proc.name bundleID:bundleID];
        if (jetsamInfo) {
            [diagnosticOutput appendFormat:@"=== Jetsam Event ===\n%@\n\n", jetsamInfo];
        }

        // 4c. Syslog entries
        NSString *syslogEntries = [self getSyslogForProcess:proc.name pid:result.pid bundleID:bundleID];
        if (syslogEntries) {
            [diagnosticOutput appendFormat:@"=== Syslog Entries ===\n%@\n\n", syslogEntries];
        }

        // 4d. Launchd logs
        NSString *launchdLog = [self getLaunchdLogForBundleID:bundleID];
        if (launchdLog) {
            [diagnosticOutput appendFormat:@"=== Launchd Log ===\n%@\n\n", launchdLog];
        }

        // 4e. Unified logs (log show)
        NSString *unifiedLog = [self getUnifiedLogForBundleID:bundleID processName:proc.name];
        if (unifiedLog) {
            [diagnosticOutput appendFormat:@"=== Unified Log ===\n%@\n\n", unifiedLog];
        }

        // 4f. Process exit status analysis
        NSString *exitAnalysis = [self analyzeExitStatus:exitStatus signalNum:signalNum];
        [diagnosticOutput appendFormat:@"=== Exit Status Analysis ===\n%@\n", exitAnalysis];

        result.diagnosticOutput = diagnosticOutput;

        BOOL hasAnyDiagnostic = (diagnosticOutput.length > 0);
        [opLog endPhase:recCrash
               exitCode:hasAnyDiagnostic ? 0 : 1
              rawOutput:diagnosticOutput
               rawError:hasAnyDiagnostic ? @"" : @"No diagnostic sources produced output"
           verification:[NSString stringWithFormat:@"Checked: CrashReporter, Jetsam, Syslog, Launchd, UnifiedLogs. Found: %@", hasAnyDiagnostic ? @"YES" : @"NO"]
               verified:hasAnyDiagnostic
               duration:0];

        NSLog(@"[RuntimeDiagnostics] Crash diagnostics complete. Sources found: %@", hasAnyDiagnostic ? @"YES" : @"NO");

    } else {
        [timeline addObject:@"monitoring_window_completed"];
        result.failureStage = @"monitoring_window";
        result.evidenceSummary = @"No process termination or crash report was observed during the monitoring window";
        // Process remained alive for full monitoring window
        result.processRemainedAlive = YES;
        result.processLifetimeMs = monitorDuration;
        result.state = @"RUNNING";
        result.success = YES;
        result.terminationReason = @"";
        result.summary = [NSString stringWithFormat:@"Process remained alive for full %.0f ms monitoring window", monitorDuration];

        NSMutableString *aliveEvidence = [NSMutableString stringWithFormat:@"alive_after=%.0fms\nphase=monitoring_window\n=== Live Process Trace ===\n%@", monitorDuration, liveTrace];
        NSString *aliveUnified = [self getUnifiedLogForBundleID:bundleID processName:proc.name];
        if (aliveUnified.length > 0) {
            [aliveEvidence appendFormat:@"\n=== Relevant Unified Log ===\n%@", aliveUnified];
        }
        NSString *aliveJetsam = [self findJetsamEventForProcessName:proc.name bundleID:bundleID];
        if (aliveJetsam.length > 0) {
            [aliveEvidence appendFormat:@"\n=== Relevant Jetsam Evidence ===\n%@", aliveJetsam];
        }
        result.diagnosticOutput = aliveEvidence;

        [opLog endPhase:recMonitor
               exitCode:0
              rawOutput:aliveEvidence
               rawError:@""
           verification:[NSString stringWithFormat:@"Process remained alive for full %.0f ms monitoring window", monitorDuration]
               verified:YES
               duration:monitorDuration / 1000.0];

        NSLog(@"[RuntimeDiagnostics] Process remained alive for %.0f ms", monitorDuration);
    }

    NSTimeInterval overallDuration = [[NSDate date] timeIntervalSinceDate:overallStart] * 1000.0;
    NSLog(@"[RuntimeDiagnostics] Complete for %@ in %.0f ms — State: %@", bundleID, overallDuration, result.state);

    if (completion) completion(result);
}

#pragma mark - Launch

- (BOOL)launchAppWithBundleID:(NSString *)bundleID {
    // LSApplicationWorkspace/UIKit launch requests must run on the main
    // thread, while detection, polling, and log collection must not block it.
    if (![NSThread isMainThread]) {
        __block BOOL opened = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            opened = [self launchAppWithBundleID:bundleID];
        });
        return opened;
    }
    @try {
        Class LSClass = objc_getClass([@"LSApplicationWorkspace" UTF8String]);
        if (!LSClass) {
            NSLog(@"[RuntimeDiagnostics] LSApplicationWorkspace not available");
            return NO;
        }
        id workspace = ((id (*)(Class, SEL))objc_msgSend)(LSClass, NSSelectorFromString(@"defaultWorkspace"));
        if (!workspace) {
            NSLog(@"[RuntimeDiagnostics] defaultWorkspace returned nil");
            return NO;
        }
        SEL openSel = NSSelectorFromString(@"openApplicationWithBundleID:");
        if ([workspace respondsToSelector:openSel]) {
            BOOL opened = ((BOOL (*)(id, SEL, NSString *))objc_msgSend)(workspace, openSel, bundleID);
            NSLog(@"[RuntimeDiagnostics] openApplicationWithBundleID:%@ returned %d", bundleID, opened);
            return opened;
        }
        NSString *urlScheme = [NSString stringWithFormat:@"%@://", bundleID];
        NSURL *url = [NSURL URLWithString:urlScheme];
        if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            NSLog(@"[RuntimeDiagnostics] Launched via URL scheme: %@", urlScheme);
            return YES;
        }
        NSLog(@"[RuntimeDiagnostics] No launch method available for %@", bundleID);
        return NO;
    } @catch (NSException *e) {
        NSLog(@"[RuntimeDiagnostics] Launch exception: %@", e.reason);
        return NO;
    }
}

#pragma mark - Launch Dependency Inventory

- (NSString *)launchDependencyReportForBundleID:(NSString *)bundleID {
    NSString *appPath = [self findAppPathForBundleID:bundleID];
    if (appPath.length == 0) return @"app_path=unavailable";

    NSMutableString *report = [NSMutableString stringWithFormat:@"app_path=%@\n", appPath];
    MachOAnalyzer *analyzer = [MachOAnalyzer sharedAnalyzer];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:appPath];
    NSUInteger count = 0;
    NSUInteger signedCount = 0;
    NSUInteger failedParseCount = 0;
    for (NSString *relativePath in enumerator) {
        if (report.length > 120000) {
            [report appendString:@"inventory_truncated=YES limit=120000\n"];
            break;
        }
        NSString *path = [appPath stringByAppendingPathComponent:relativePath];
        BOOL isDirectory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] || isDirectory) continue;
        MachOAnalysisResult *analysis = [analyzer analyzeFileAtPath:path];
        if (!analysis || analysis.magicName.length == 0 || [analysis.magicName isEqualToString:@"unknown"]) continue;
        count++;
        if (analysis.hasCodeSignature) signedCount++;
        if (analysis.parseStatus == MachOParseFailed) failedParseCount++;

        NSMutableArray *architectures = [NSMutableArray array];
        for (MachOSlice *slice in analysis.slices) {
            if (slice.architectureName.length > 0) [architectures addObject:slice.architectureName];
        }
        NSMutableArray *dependencies = [NSMutableArray array];
        for (MachODependency *dependency in analysis.dependencies) {
            if (dependency.rawInstallName.length > 0) [dependencies addObject:dependency.rawInstallName];
        }
        NSMutableArray *rpaths = [NSMutableArray array];
        for (MachORPath *rpath in analysis.rpaths) {
            if (rpath.rawPath.length > 0) [rpaths addObject:rpath.rawPath];
        }
        [report appendFormat:@"target=%@ magic=%@ type=%@ arch=[%@] codeSignature=%@ offset=%u size=%u parse=%ld deps=[%@] rpaths=[%@] parseError=%@\n",
         relativePath,
         analysis.magicName,
         analysis.machOTypeName ?: @"unknown",
         [architectures componentsJoinedByString:@","] ,
         analysis.hasCodeSignature ? @"YES" : @"NO",
         analysis.codeSignatureOffset,
         analysis.codeSignatureSize,
         (long)analysis.parseStatus,
         [dependencies componentsJoinedByString:@","] ,
         [rpaths componentsJoinedByString:@","] ,
         analysis.parseError ?: @"-"];
    }
    [report appendFormat:@"inventory_count=%lu signed=%lu parseFailed=%lu\n", (unsigned long)count, (unsigned long)signedCount, (unsigned long)failedParseCount];
    return report;
}

#pragma mark - Process Detection

- (ProcessInfo *)detectProcessForBundleID:(NSString *)bundleID timeout:(NSTimeInterval)timeout {
    NSDate *start = [NSDate date];
    NSString *exeName = [self extractExecutableNameFromBundleID:bundleID];
    while ([[NSDate date] timeIntervalSinceDate:start] < timeout) {
        ProcessInfo *proc = [self findProcessMatchingBundleID:bundleID exeName:exeName];
        if (proc) return proc;
        [NSThread sleepForTimeInterval:self.pollInterval];
    }
    return nil;
}

- (NSString *)extractExecutableNameFromBundleID:(NSString *)bundleID {
    NSString *appPath = [self findAppPathForBundleID:bundleID];
    if (appPath) {
        NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
        NSString *exeName = info[@"CFBundleExecutable"];
        if (exeName) return exeName;
    }
    NSArray *parts = [bundleID componentsSeparatedByString:@"."];
    return parts.lastObject ?: bundleID;
}

- (NSString *)findAppPathForBundleID:(NSString *)bundleID {
    NSArray *searchPaths = @[@"/var/jb/Applications", @"/Applications"];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *base in searchPaths) {
        NSArray *items = [fm contentsOfDirectoryAtPath:base error:nil];
        for (NSString *item in items) {
            if ([item hasSuffix:@".app"]) {
                NSString *appPath = [base stringByAppendingPathComponent:item];
                NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
                NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
                if ([info[@"CFBundleIdentifier"] isEqualToString:bundleID]) {
                    return appPath;
                }
            }
        }
    }
    return nil;
}

- (ProcessInfo *)findProcessMatchingBundleID:(NSString *)bundleID exeName:(NSString *)exeName {
    NSString *psOutput = [self runCmdOutput:@"/var/jb/usr/bin/ps" args:@[@"-eo", @"pid,uid,gid,args"]];
    if (!psOutput) psOutput = [self runCmdOutput:@"/bin/ps" args:@[@"-eo", @"pid,uid,gid,args"]];
    if (!psOutput) return nil;

    NSString *expectedExecutable = exeName.lastPathComponent ?: exeName;
    NSString *appPath = [self findAppPathForBundleID:bundleID];
    NSString *expectedAppName = [[appPath.lastPathComponent stringByDeletingPathExtension] copy];
    NSArray *lines = [psOutput componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length == 0) continue;
        NSArray *parts = [trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSMutableArray *cleanParts = [NSMutableArray array];
        for (NSString *p in parts) if (p.length > 0) [cleanParts addObject:p];
        if (cleanParts.count < 4) continue;

        pid_t pid = [cleanParts[0] intValue];
        if (pid <= 0 || ![self isProcessAlive:pid]) continue;
        NSString *uidStr = cleanParts[1];
        NSString *gidStr = cleanParts[2];
        NSString *command = [[cleanParts subarrayWithRange:NSMakeRange(3, cleanParts.count - 3)] componentsJoinedByString:@" "];
        NSString *commandExecutable = command.lastPathComponent;

        // A bundle may contain extensions whose executable names happen to
        // include the app executable name. They are not the app's process.
        BOOL nestedProcess = [command containsString:@"/PlugIns/"] ||
                             [command containsString:@".appex/"] ||
                             [command containsString:@".framework/"] ||
                             [command containsString:@".xpc/"] ||
                             [command containsString:@"/Frameworks/"];
        BOOL executableMatches = [commandExecutable isEqualToString:expectedExecutable];
        BOOL appPathMatches = expectedAppName.length == 0 ||
                              [command containsString:[NSString stringWithFormat:@"/%@.app/", expectedAppName]];
        if (nestedProcess || !executableMatches || !appPathMatches) continue;

        ProcessInfo *info = [[ProcessInfo alloc] init];
        info.pid = pid;
        info.uid = [uidStr intValue];
        info.gid = [gidStr intValue];
        info.name = command;
        info.executablePath = commandExecutable;
        info.startTime = [NSDate date];
        return info;
    }
    return nil;
}

#pragma mark - Process Monitoring with Exit Status

- (BOOL)monitorProcess:(pid_t)pid duration:(NSTimeInterval)duration trace:(NSMutableString *)trace exitStatus:(int *)exitStatus signalNum:(int *)signalNum {
    NSDate *start = [NSDate date];
    NSDate *nextSnapshot = start;
    *exitStatus = -1;
    *signalNum = 0;

    while ([[NSDate date] timeIntervalSinceDate:start] < duration) {
        NSDate *now = [NSDate date];
        if ([now compare:nextSnapshot] != NSOrderedAscending) {
            NSTimeInterval elapsed = [now timeIntervalSinceDate:start] * 1000.0;
            [trace appendFormat:@"[%.0fms] %@\n", elapsed, [self processSnapshotForPID:pid]];
            nextSnapshot = [now dateByAddingTimeInterval:2.0];
        }

        if (![self isProcessAlive:pid]) {
            // The target is not our child in normal iOS execution. waitpid is
            // attempted only for completeness; unavailable status stays -1.
            int status = 0;
            pid_t waited = waitpid(pid, &status, WNOHANG);
            if (waited == pid) {
                if (WIFEXITED(status)) *exitStatus = WEXITSTATUS(status);
                if (WIFSIGNALED(status)) *signalNum = WTERMSIG(status);
            }
            NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:start] * 1000.0;
            [trace appendFormat:@"[%.0fms] process_not_alive exitStatus=%d signal=%d waitpid=%d\n", elapsed, *exitStatus, *signalNum, waited];
            return NO;
        }
        [NSThread sleepForTimeInterval:self.pollInterval];
    }

    BOOL alive = [self isProcessAlive:pid];
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:start] * 1000.0;
    [trace appendFormat:@"[%.0fms] monitor_finished alive=%@\n", elapsed, alive ? @"YES" : @"NO"];
    return alive;
}

- (NSString *)processSnapshotForPID:(pid_t)pid {
    int savedErrno = 0;
    BOOL alive = (kill(pid, 0) == 0);
    if (!alive) savedErrno = errno;
    NSString *ps = [self runCmdOutput:@"/var/jb/usr/bin/ps" args:@[@"-p", [NSString stringWithFormat:@"%d", pid], @"-o", @"pid=,ppid=,uid=,gid=,stat=,etime=,comm="]];
    if (!ps) ps = [self runCmdOutput:@"/bin/ps" args:@[@"-p", [NSString stringWithFormat:@"%d", pid], @"-o", @"pid=,ppid=,uid=,gid=,stat=,etime=,comm="]];
    NSString *compact = [(ps ?: @"ps_unavailable") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [NSString stringWithFormat:@"pid=%d alive=%@ errno=%d snapshot=%@", pid, alive ? @"YES" : @"NO", savedErrno, compact];
}

- (BOOL)isProcessAlive:(pid_t)pid {
    return (kill(pid, 0) == 0);
}

#pragma mark - Termination Reason Determination

- (NSString *)determineTerminationReason:(pid_t)pid bundleID:(NSString *)bundleID processName:(NSString *)processName exitStatus:(int)exitStatus signalNum:(int)signalNum {
    NSMutableString *reason = [NSMutableString string];

    // Check signal first
    if (signalNum != 0) {
        NSString *signalName = [self signalName:signalNum];
        [reason appendFormat:@"Terminated by signal %d (%@). ", signalNum, signalName];

        if (signalNum == SIGKILL) {
            // SIGKILL could be jetsam (OOM) or manual kill
            NSString *jetsam = [self findJetsamEventForProcessName:processName bundleID:bundleID];
            if (jetsam) {
                [reason appendFormat:@"SIGKILL detected — possible Jetsam/OOM kill. %@", jetsam];
            } else {
                [reason appendString:@"SIGKILL detected — could be Jetsam (out-of-memory), manual kill, or system termination."];
            }
        } else if (signalNum == SIGABRT) {
            [reason appendString:@"SIGABRT — assertion failure or abort() called."];
        } else if (signalNum == SIGSEGV) {
            [reason appendString:@"SIGSEGV — segmentation fault (memory access violation)."];
        } else if (signalNum == SIGBUS) {
            [reason appendString:@"SIGBUS — bus error (misaligned memory access)."];
        } else if (signalNum == SIGILL) {
            [reason appendString:@"SIGILL — illegal instruction (corrupted binary or architecture mismatch)."];
        } else if (signalNum == SIGTRAP) {
            [reason appendString:@"SIGTRAP — breakpoint/trap (debugger or runtime check)."];
        }
    } else if (exitStatus < 0) {
        [reason appendString:@"Process disappeared but exit status/signal was not observable because the app is not a child of the installer. "];
    } else if (exitStatus != 0) {
        [reason appendFormat:@"Exited with status %d. ", exitStatus];
        if (exitStatus == 1) {
            [reason appendString:@"General error exit."];
        } else if (exitStatus == 255) {
            [reason appendString:@"Exit code 255 — typically indicates launch failure or dylib loading issue."];
        }
    } else {
        [reason appendString:@"Exited with status 0 (normal exit) — but process terminated unexpectedly during monitoring."];
    }

    // Check for crash report regardless
    NSString *crashPath = [self findCrashReportForBundleID:bundleID processName:processName];
    if (crashPath) {
        [reason appendFormat:@" Crash report found at: %@", crashPath];
    } else {
        [reason appendString:@" No crash report found in standard locations."];
    }

    return reason;
}

- (NSString *)signalName:(int)signalNum {
    switch (signalNum) {
        case SIGHUP: return @"SIGHUP";
        case SIGINT: return @"SIGINT";
        case SIGQUIT: return @"SIGQUIT";
        case SIGILL: return @"SIGILL";
        case SIGTRAP: return @"SIGTRAP";
        case SIGABRT: return @"SIGABRT";
        case SIGBUS: return @"SIGBUS";
        case SIGFPE: return @"SIGFPE";
        case SIGKILL: return @"SIGKILL";
        case SIGSEGV: return @"SIGSEGV";
        case SIGTERM: return @"SIGTERM";
        default: return @"UNKNOWN";
    }
}

#pragma mark - Crash Report Search

- (NSString *)waitForFreshCrashReportForBundleID:(NSString *)bundleID processName:(NSString *)processName pid:(pid_t)pid launchedAt:(NSDate *)launchedAt timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *searchPaths = @[
        @"/var/mobile/Library/Logs/CrashReporter",
        @"/var/mobile/Library/Logs/CrashReporter/DiagnosticLogs"
    ];
    while ([[NSDate date] compare:deadline] == NSOrderedAscending) {
        NSString *bestPath = nil;
        NSDate *bestDate = nil;
        for (NSString *basePath in searchPaths) {
            NSArray *items = [fm contentsOfDirectoryAtPath:basePath error:nil];
            for (NSString *item in items) {
                if (!([item hasSuffix:@".ips"] || [item hasSuffix:@".crash"])) continue;
                NSString *fullPath = [basePath stringByAppendingPathComponent:item];
                NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
                NSDate *modDate = attrs[NSFileModificationDate];
                if (!modDate || (launchedAt && [modDate timeIntervalSinceDate:launchedAt] < -2.0)) continue;
                if ([[NSDate date] timeIntervalSinceDate:modDate] > 120.0) continue;
                NSString *content = [NSString stringWithContentsOfFile:fullPath encoding:NSUTF8StringEncoding error:nil];
                if (content.length == 0) continue;
                if (bundleID.length > 0 && ![content containsString:bundleID]) continue;
                if (processName.length > 0 && ![content containsString:processName]) continue;
                NSRange jsonStart = [content rangeOfString:@"{"];
                if (jsonStart.location == NSNotFound) continue;
                NSData *jsonData = [[content substringFromIndex:jsonStart.location] dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *report = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
                NSNumber *reportPID = report[@"pid"];
                if (pid > 0 && (![reportPID isKindOfClass:[NSNumber class]] || reportPID.intValue != pid)) continue;
                if (!bestDate || [modDate compare:bestDate] == NSOrderedDescending) {
                    bestDate = modDate;
                    bestPath = fullPath;
                }
            }
        }
        if (bestPath) return bestPath;
        [NSThread sleepForTimeInterval:0.25];
    }
    return nil;
}

- (NSString *)findCrashReportForBundleID:(NSString *)bundleID processName:(NSString *)processName {
    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray *searchPaths = @[
        @"/var/mobile/Library/Logs/CrashReporter",
        @"/var/mobile/Library/Logs/CrashReporter/DiagnosticLogs",
        @"/var/mobile/Library/Logs/CrashReporter/Panics",
        @"/var/mobile/Library/Logs/CrashReporter/CoreCapture"
    ];

    NSDate *now = [NSDate date];
    NSString *latestPath = nil;
    NSDate *latestDate = nil;

    for (NSString *basePath in searchPaths) {
        if (![fm fileExistsAtPath:basePath]) continue;

        NSArray *items = [fm contentsOfDirectoryAtPath:basePath error:nil];
        for (NSString *item in items) {
            BOOL matches = NO;
            if (bundleID && [item containsString:bundleID]) matches = YES;
            if (processName && [item containsString:processName]) matches = YES;

            if (matches && ([item hasSuffix:@".ips"] || [item hasSuffix:@".crash"])) {
                NSString *fullPath = [basePath stringByAppendingPathComponent:item];
                NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
                NSDate *modDate = attrs[NSFileModificationDate];

                if (modDate && [now timeIntervalSinceDate:modDate] < 300) {
                    if (!latestDate || [modDate compare:latestDate] == NSOrderedDescending) {
                        latestDate = modDate;
                        latestPath = fullPath;
                    }
                }
            }
        }
    }

    return latestPath;
}

- (NSString *)crashReportAnalysisForPath:(NSString *)path expectedPID:(pid_t)pid result:(RuntimeDiagnosticsResult *)result {
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (content.length == 0) return @"REPORT_PARSE_FAILED: empty crash report";
    NSRange jsonStart = [content rangeOfString:@"{"];
    if (jsonStart.location == NSNotFound) return @"REPORT_PARSE_FAILED: JSON object not found";
    NSData *jsonData = [[content substringFromIndex:jsonStart.location] dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *report = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    if (![report isKindOfClass:[NSDictionary class]]) return @"REPORT_PARSE_FAILED: invalid JSON";

    NSNumber *reportPID = report[@"pid"];
    result.crashReportPID = reportPID.intValue;
    result.crashReportPIDMatched = (pid <= 0 || reportPID.intValue == pid);
    NSDictionary *exception = report[@"exception"];
    NSDictionary *termination = report[@"termination"];
    NSDictionary *asi = report[@"asi"];
    result.crashExceptionType = [exception[@"type"] isKindOfClass:[NSString class]] ? exception[@"type"] : @"N/A";
    result.crashSignal = [exception[@"signal"] isKindOfClass:[NSString class]] ? exception[@"signal"] : @"N/A";
    result.crashTerminationIndicator = [termination[@"indicator"] isKindOfClass:[NSString class]] ? termination[@"indicator"] : @"N/A";

    NSMutableString *summary = [NSMutableString string];
    NSString *byProc = [termination[@"byProc"] isKindOfClass:[NSString class]] ? termination[@"byProc"] : @"N/A";
    [summary appendFormat:@"pid=%d matched=%@ exception=%@ signal=%@ termination=%@ byProc=%@",
     result.crashReportPID,
     result.crashReportPIDMatched ? @"YES" : @"NO",
     result.crashExceptionType,
     result.crashSignal,
     result.crashTerminationIndicator,
     byProc];
    if ([asi isKindOfClass:[NSDictionary class]] && asi.count > 0) {
        NSMutableArray *asiParts = [NSMutableArray array];
        for (NSString *key in asi) {
            id value = asi[key];
            if ([value isKindOfClass:[NSArray class]]) value = [value componentsJoinedByString:@"; "];
            [asiParts addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
        }
        [summary appendFormat:@" asi={%@}", [asiParts componentsJoinedByString:@" | "]];
    }

    NSArray *images = report[@"usedImages"] ?: report[@"binaryImages"];
    NSMutableDictionary<NSNumber *, NSString *> *imageNames = [NSMutableDictionary dictionary];
    NSMutableArray *loadedAppComponents = [NSMutableArray array];
    if ([images isKindOfClass:[NSArray class]]) {
        for (NSUInteger i = 0; i < images.count; i++) {
            NSDictionary *image = images[i];
            if (![image isKindOfClass:[NSDictionary class]]) continue;
            NSString *name = [image[@"name"] isKindOfClass:[NSString class]] ? image[@"name"] : @"unknown";
            imageNames[@(i)] = name;
            NSString *imagePath = [image[@"path"] isKindOfClass:[NSString class]] ? image[@"path"] : @"";
            BOOL appOwned = [imagePath containsString:@".app/"];
            BOOL dynamicComponent = [name.pathExtension.lowercaseString isEqualToString:@"dylib"] || [imagePath containsString:@"/Frameworks/"];
            if (appOwned && dynamicComponent && loadedAppComponents.count < 80) {
                [loadedAppComponents addObject:[NSString stringWithFormat:@"%@ [%@]", name, imagePath]];
            }
        }
    }

    NSArray *backtrace = report[@"lastExceptionBacktrace"];
    NSMutableArray *topFrames = [NSMutableArray array];
    if ([backtrace isKindOfClass:[NSArray class]]) {
        for (NSDictionary *frame in [backtrace subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)16, backtrace.count))]) {
            NSNumber *imageIndex = frame[@"imageIndex"];
            NSString *symbol = [frame[@"symbol"] isKindOfClass:[NSString class]] ? frame[@"symbol"] : @"<no-symbol>";
            NSNumber *offset = frame[@"imageOffset"];
            NSString *imageName = imageNames[imageIndex] ?: @"unknown-image";
            [topFrames addObject:[NSString stringWithFormat:@"%@ +%@ [%@ index=%@]", symbol, offset ?: @0, imageName, imageIndex ?: @"?"]];
        }
    }
    if (topFrames.count > 0) [summary appendFormat:@" topFrames={%@}", [topFrames componentsJoinedByString:@" | "]];

    NSArray *threads = report[@"threads"];
    NSMutableArray *triggeredThreads = [NSMutableArray array];
    if ([threads isKindOfClass:[NSArray class]]) {
        for (NSDictionary *thread in threads) {
            if (![thread[@"triggered"] boolValue]) continue;
            NSString *queue = [thread[@"queue"] isKindOfClass:[NSString class]] ? thread[@"queue"] : @"unknown-queue";
            NSNumber *threadID = thread[@"id"];
            [triggeredThreads addObject:[NSString stringWithFormat:@"id=%@ queue=%@", threadID ?: @"?", queue]];
        }
    }
    result.crashFaultingThread = triggeredThreads.count > 0 ? [triggeredThreads componentsJoinedByString:@"; "] : @"not-marked-in-report";
    if (triggeredThreads.count > 0) [summary appendFormat:@" faultingThread={%@}", result.crashFaultingThread];

    if (loadedAppComponents.count > 0) {
        [summary appendFormat:@" loadedAppComponents=%lu", (unsigned long)loadedAppComponents.count];
        NSMutableString *componentDetail = [NSMutableString stringWithString:@"\n=== Loaded App Components ===\n"];
        for (NSString *component in loadedAppComponents) [componentDetail appendFormat:@"%@\n", component];
        [summary appendString:componentDetail];
    }
    result.crashAnalysisSummary = summary;
    return summary;
}

#pragma mark - Jetsam Event Search

- (NSString *)findJetsamEventForProcessName:(NSString *)processName bundleID:(NSString *)bundleID {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *jetsamPath = @"/var/mobile/Library/Logs/CrashReporter/JetsamEvent";

    if (![fm fileExistsAtPath:jetsamPath]) {
        return nil;
    }

    NSArray *items = [fm contentsOfDirectoryAtPath:jetsamPath error:nil];
    NSDate *now = [NSDate date];
    NSString *latestMatch = nil;
    NSDate *latestDate = nil;

    for (NSString *item in items) {
        if ([item hasSuffix:@".ips"]) {
            NSString *fullPath = [jetsamPath stringByAppendingPathComponent:item];
            NSString *content = [NSString stringWithContentsOfFile:fullPath encoding:NSUTF8StringEncoding error:nil];

            if (content && processName && [content containsString:processName]) {
                NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
                NSDate *modDate = attrs[NSFileModificationDate];
                if (modDate && [now timeIntervalSinceDate:modDate] < 300) {
                    if (!latestDate || [modDate compare:latestDate] == NSOrderedDescending) {
                        latestDate = modDate;
                        latestMatch = fullPath;
                    }
                }
            }
        }
    }

    if (latestMatch) {
        NSString *content = [NSString stringWithContentsOfFile:latestMatch encoding:NSUTF8StringEncoding error:nil];
        if (content) {
            // Extract relevant lines mentioning the process
            NSArray *lines = [content componentsSeparatedByString:@"\n"];
            NSMutableString *relevant = [NSMutableString string];
            for (NSString *line in lines) {
                if (processName && [line containsString:processName]) {
                    [relevant appendFormat:@"%@\n", line];
                }
            }
            if (relevant.length > 0) {
                return [NSString stringWithFormat:@"Jetsam report: %@\nRelevant entries:\n%@", latestMatch, relevant];
            }
        }
    }

    return nil;
}

#pragma mark - Syslog Search

- (NSString *)getSyslogForProcess:(NSString *)processName pid:(pid_t)pid bundleID:(NSString *)bundleID {
    // Try to read syslog
    NSString *syslogPath = @"/var/log/syslog";
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm fileExistsAtPath:syslogPath]) {
        // Try alternative paths
        syslogPath = @"/var/jb/var/log/syslog";
        if (![fm fileExistsAtPath:syslogPath]) {
            return nil;
        }
    }

    // Use tail to get last 50 lines, then grep for process
    NSString *tailOutput = [self runCmdOutput:@"/var/jb/usr/bin/tail" args:@[@"-n", @"50", syslogPath]];
    if (!tailOutput) return nil;

    NSArray *lines = [tailOutput componentsSeparatedByString:@"\n"];
    NSMutableString *relevant = [NSMutableString string];

    for (NSString *line in lines) {
        if ((processName && [line containsString:processName]) ||
            (bundleID && [line containsString:bundleID]) ||
            [line containsString:[NSString stringWithFormat:@"[%d]", pid]]) {
            [relevant appendFormat:@"%@\n", line];
        }
    }

    return relevant.length > 0 ? relevant : nil;
}

#pragma mark - Launchd Log

- (NSString *)getLaunchdLogForBundleID:(NSString *)bundleID {
    NSString *launchdLog = @"/var/log/launchd.log";
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm fileExistsAtPath:launchdLog]) {
        return nil;
    }

    NSString *tailOutput = [self runCmdOutput:@"/var/jb/usr/bin/tail" args:@[@"-n", @"30", launchdLog]];
    if (!tailOutput) return nil;

    NSArray *lines = [tailOutput componentsSeparatedByString:@"\n"];
    NSMutableString *relevant = [NSMutableString string];

    for (NSString *line in lines) {
        if ([line containsString:bundleID]) {
            [relevant appendFormat:@"%@\n", line];
        }
    }

    return relevant.length > 0 ? relevant : nil;
}

#pragma mark - Unified Log (log show)

- (NSString *)getUnifiedLogForBundleID:(NSString *)bundleID processName:(NSString *)processName {
    // Try to use log command (may not work on all jailbreaks)
    NSString *logOutput = [self runCmdOutput:@"/usr/bin/log" args:@[@"show", @"--last", @"2m", @"--predicate", [NSString stringWithFormat:@"subsystem == \"%@\" OR process == \"%@\"", bundleID, processName ?: bundleID]]];

    if (!logOutput || logOutput.length == 0) {
        // Try alternative: log stream with timeout
        logOutput = [self runCmdOutput:@"/usr/bin/log" args:@[@"show", @"--last", @"1m"]];
    }

    if (!logOutput || logOutput.length == 0) {
        return nil;
    }

    // Filter for relevant lines
    NSArray *lines = [logOutput componentsSeparatedByString:@"\n"];
    NSMutableString *relevant = [NSMutableString string];

    for (NSString *line in lines) {
        if ([line containsString:bundleID] || (processName && [line containsString:processName])) {
            [relevant appendFormat:@"%@\n", line];
        }
    }

    return relevant.length > 0 ? relevant : nil;
}

#pragma mark - Exit Status Analysis

- (NSString *)analyzeExitStatus:(int)exitStatus signalNum:(int)signalNum {
    NSMutableString *analysis = [NSMutableString string];

    [analysis appendFormat:@"Exit status: %@\n", exitStatus < 0 ? @"unavailable" : [NSString stringWithFormat:@"%d", exitStatus]];
    [analysis appendFormat:@"Signal: %d (%@)\n", signalNum, [self signalName:signalNum]];

    if (signalNum == SIGKILL) {
        [analysis appendString:@"\nSIGKILL analysis:\n"];
        [analysis appendString:@"- Jetsam (out-of-memory): Check JetsamEvent logs\n"];
        [analysis appendString:@"- Manual kill: User or another process sent SIGKILL\n"];
        [analysis appendString:@"- System termination: launchd or watchdog terminated the process\n"];
    } else if (signalNum == SIGABRT) {
        [analysis appendString:@"\nSIGABRT analysis:\n"];
        [analysis appendString:@"- Assertion failure (NSAssert, assert())\n"];
        [analysis appendString:@"- Uncaught exception\n"];
        [analysis appendString:@"- abort() called intentionally\n"];
    } else if (signalNum == SIGSEGV) {
        [analysis appendString:@"\nSIGSEGV analysis:\n"];
        [analysis appendString:@"- Dereferencing null pointer\n"];
        [analysis appendString:@"- Buffer overflow\n"];
        [analysis appendString:@"- Use-after-free\n"];
        [analysis appendString:@"- Stack overflow\n"];
    } else if (exitStatus == 255) {
        [analysis appendString:@"\nExit 255 analysis:\n"];
        [analysis appendString:@"- Dylib loading failure (injection tool incompatibility)\n"];
        [analysis appendString:@"- Launchd failed to start the process\n"];
        [analysis appendString:@"- Missing or corrupted executable\n"];
    }

    return analysis;
}

#pragma mark - Command Execution

- (NSString *)runCmdOutput:(NSString *)cmd args:(NSArray *)args {
    if (!cmd || cmd.length == 0) return nil;

    int outPipe[2];
    if (pipe(outPipe) != 0) return nil;

    pid_t pid = 0;
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, outPipe[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&actions, outPipe[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&actions, outPipe[0]);
    posix_spawn_file_actions_addclose(&actions, outPipe[1]);

    const char *c = [cmd UTF8String];
    char **argv = malloc((args.count + 2) * sizeof(char*));
    argv[0] = (char *)c;
    for (NSUInteger i = 0; i < args.count; i++) argv[i + 1] = (char *)[args[i] UTF8String];
    argv[args.count + 1] = NULL;

    extern char **environ;
    int st = posix_spawn(&pid, c, &actions, NULL, argv, environ);
    free(argv);
    posix_spawn_file_actions_destroy(&actions);
    close(outPipe[1]);

    if (st != 0) { close(outPipe[0]); return nil; }

    int flags = fcntl(outPipe[0], F_GETFL, 0);
    if (flags >= 0) fcntl(outPipe[0], F_SETFL, flags | O_NONBLOCK);
    NSMutableData *data = [NSMutableData data];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
    BOOL pipeClosed = NO;
    char buf[4096];

    while (!pipeClosed) {
        ssize_t n = read(outPipe[0], buf, sizeof(buf));
        if (n > 0) {
            if (data.length < (1024 * 1024)) {
                NSUInteger remaining = (1024 * 1024) - data.length;
                [data appendBytes:buf length:MIN((NSUInteger)n, remaining)];
            }
            continue;
        }
        if (n == 0) {
            pipeClosed = YES;
            break;
        }
        if (errno != EAGAIN && errno != EINTR) break;
        if ([[NSDate date] compare:deadline] != NSOrderedAscending) {
            kill(pid, SIGTERM);
            usleep(100000);
            kill(pid, SIGKILL);
            break;
        }
        [NSThread sleepForTimeInterval:0.02];
    }

    close(outPipe[0]);
    int ws = 0;
    while (waitpid(pid, &ws, 0) < 0 && errno == EINTR) { }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}

@end
