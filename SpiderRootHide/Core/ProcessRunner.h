//
//  ProcessRunner.h
//  IPAInstallerPro — Commit 1: Process Execution Abstraction
//
//  Unified, observable, and auditable process execution.
//  Rules:
//    - Always passes environ (never NULL).
//    - Always captures exit code, signal, errno, stdout, stderr, duration.
//    - Always enforces timeout (caller may pass 0 for no timeout).
//    - Never swallows errors.
//    - Never touches UI.
//

#import <Foundation/Foundation.h>
@class CommandResult;

@interface ProcessRunner : NSObject

+ (instancetype)sharedRunner;

/// Synchronous execution. Blocks calling thread. Use from background queues only.
/// @param path      Absolute path to executable.
/// @param arguments Array of argument strings (NOT including argv[0]).
/// @param timeout   Maximum seconds to wait (0 = no timeout).
/// @return CommandResult with full execution evidence.
- (CommandResult *)runCommand:(NSString *)path
                    arguments:(NSArray<NSString *> *)arguments
                      timeout:(NSTimeInterval)timeout;

/// Asynchronous execution. Returns immediately; result delivered on background queue.
- (void)runCommand:(NSString *)path
         arguments:(NSArray<NSString *> *)arguments
           timeout:(NSTimeInterval)timeout
        completion:(void (^)(CommandResult *result))completion;

@end
