//
//  CommandResult.h
//  IPAInstallerPro — Commit 1: Process Execution Abstraction
//
//  Unified result model for every external command execution.
//  No UI logic. No state machine. Pure data.
//

#import <Foundation/Foundation.h>

@interface CommandResult : NSObject

@property (nonatomic, assign, readonly) BOOL success;           // exit code == 0 AND no spawn error
@property (nonatomic, assign, readonly) int exitCode;           // WEXITSTATUS(status) if WIFEXITED
@property (nonatomic, assign, readonly) int signalNumber;       // WTERMSIG(status) if WIFSIGNALED
@property (nonatomic, assign, readonly) int spawnError;         // errno if posix_spawn failed (0 = OK)
@property (nonatomic, copy, readonly) NSString *stdoutText;
@property (nonatomic, copy, readonly) NSString *stderrText;
@property (nonatomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, assign, readonly) BOOL timedOut;
@property (nonatomic, copy, readonly) NSString *commandPath;
@property (nonatomic, copy, readonly) NSArray<NSString *> *arguments;

- (instancetype)initWithCommandPath:(NSString *)path
                          arguments:(NSArray<NSString *> *)arguments
                           exitCode:(int)exitCode
                       signalNumber:(int)signalNumber
                         spawnError:(int)spawnError
                         stdoutText:(NSString *)stdoutText
                         stderrText:(NSString *)stderrText
                           duration:(NSTimeInterval)duration
                           timedOut:(BOOL)timedOut;

/// Diagnostic snapshot for logging. Never contains sensitive data.
- (NSDictionary *)diagnosticDictionary;

/// Human-readable classification for error reporting.
- (NSString *)failureCategory;

@end
