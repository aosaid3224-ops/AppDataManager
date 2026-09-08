//
//  ExecutableCapability.h
//  IPAInstallerPro — Commit 2: ldid Executable Validator
//
//  Rich diagnostic result for executable validation.
//  Never contains sensitive data.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ExecutableCapabilityStatus) {
    ExecutableCapabilityStatusNotFound,        // access(F_OK) failed everywhere
    ExecutableCapabilityStatusNotExecutable,   // access(X_OK) failed
    ExecutableCapabilityStatusPermissionDenied,// posix_spawn: EACCES/EPERM
    ExecutableCapabilityStatusProcessFailed,   // posix_spawn: other errno
    ExecutableCapabilityStatusInvalidOutput,   // Ran but output did not validate
    ExecutableCapabilityStatusTimeout,         // Did not respond in time
    ExecutableCapabilityStatusUnknownError,    // Unexpected failure
    ExecutableCapabilityStatusReady            // Found, accessible, executable, invocable, output valid
};

@interface ExecutableCapability : NSObject

@property (nonatomic, copy, readonly) NSString *executableName;
@property (nonatomic, copy, readonly) NSString *resolvedPath;      // The path that was tested
@property (nonatomic, copy, readonly) NSArray<NSString *> *searchedPaths; // All paths checked
@property (nonatomic, assign, readonly) ExecutableCapabilityStatus status;
@property (nonatomic, assign, readonly) BOOL exists;               // access(F_OK)
@property (nonatomic, assign, readonly) BOOL isAccessible;         // Could stat the file
@property (nonatomic, assign, readonly) BOOL isExecutable;         // access(X_OK)
@property (nonatomic, assign, readonly) BOOL isInvocable;          // posix_spawn succeeded
@property (nonatomic, assign, readonly) BOOL outputValid;          // Output matched expectation
@property (nonatomic, assign, readonly) int spawnError;            // errno from posix_spawn (0 if OK)
@property (nonatomic, assign, readonly) int exitCode;              // WEXITSTATUS
@property (nonatomic, assign, readonly) int signalNumber;          // WTERMSIG
@property (nonatomic, copy, readonly) NSString *testOutput;        // stdout + stderr (trimmed)
@property (nonatomic, copy, readonly) NSString *lastErrorMessage;  // Human-readable error
@property (nonatomic, assign, readonly) NSTimeInterval duration;   // Test duration
@property (nonatomic, strong, readonly) NSDate *testTimestamp;     // When tested

- (instancetype)initWithExecutableName:(NSString *)name
                          searchedPaths:(NSArray<NSString *> *)searchedPaths;

/// Update after access() checks.
- (void)markFoundAtPath:(NSString *)path exists:(BOOL)exists executable:(BOOL)executable;

/// Update after invocation test.
- (void)markInvocationResultWithSpawnError:(int)spawnError
                                  exitCode:(int)exitCode
                              signalNumber:(int)signalNumber
                                    output:(NSString *)output
                                  duration:(NSTimeInterval)duration;

/// Mark as ready (all checks passed).
- (void)markReadyWithPath:(NSString *)path output:(NSString *)output duration:(NSTimeInterval)duration;

/// Mark with specific status and error.
- (void)markStatus:(ExecutableCapabilityStatus)status errorMessage:(NSString *)error;

/// Localized Arabic description for UI display.
- (NSString *)localizedStatusDescription;

/// Lightweight diagnostic dictionary (no output text).
- (NSDictionary *)diagnosticSnapshot;

/// Full diagnostic dictionary (includes output, for logs).
- (NSDictionary *)fullDiagnosticDictionary;

@end
