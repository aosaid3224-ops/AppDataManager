//
//  ExecutableCapability.m
//  IPAInstallerPro — Commit 2: ldid Executable Validator
//

#import "ExecutableCapability.h"

@implementation ExecutableCapability

- (instancetype)initWithExecutableName:(NSString *)name
                          searchedPaths:(NSArray<NSString *> *)searchedPaths {
    self = [super init];
    if (self) {
        _executableName = [name copy];
        _searchedPaths = [searchedPaths copy] ?: @[];
        _status = ExecutableCapabilityStatusUnknownError;
        _testTimestamp = [NSDate date];
    }
    return self;
}

- (void)markFoundAtPath:(NSString *)path exists:(BOOL)exists executable:(BOOL)executable {
    _resolvedPath = [path copy];
    _exists = exists;
    _isAccessible = YES;
    _isExecutable = executable;
    if (!exists) {
        _status = ExecutableCapabilityStatusNotFound;
        _lastErrorMessage = [NSString stringWithFormat:@"لم يُعثر على %@ في المسارات المُفحصة", _executableName];
    } else if (!executable) {
        _status = ExecutableCapabilityStatusNotExecutable;
        _lastErrorMessage = [NSString stringWithFormat:@"%@ موجود لكنه غير قابل للتنفيذ", path];
    }
}

- (void)markInvocationResultWithSpawnError:(int)spawnError
                                  exitCode:(int)exitCode
                              signalNumber:(int)signalNumber
                                    output:(NSString *)output
                                  duration:(NSTimeInterval)duration {
    _spawnError = spawnError;
    _exitCode = exitCode;
    _signalNumber = signalNumber;
    _testOutput = [output copy] ?: @"";
    _duration = duration;

    if (spawnError != 0) {
        if (spawnError == EACCES || spawnError == EPERM) {
            _status = ExecutableCapabilityStatusPermissionDenied;
            _lastErrorMessage = @"تم رفض الصلاحية عند محاولة تشغيل الأداة";
        } else if (spawnError == ENOENT) {
            _status = ExecutableCapabilityStatusNotFound;
            _lastErrorMessage = @"الأداة غير موجودة في المسار المُحدد";
        } else {
            _status = ExecutableCapabilityStatusProcessFailed;
            _lastErrorMessage = [NSString stringWithFormat:@"فشل تشغيل الأداة (رمز الخطأ: %d)", spawnError];
        }
        return;
    }

    if (signalNumber != 0) {
        _status = ExecutableCapabilityStatusProcessFailed;
        _lastErrorMessage = [NSString stringWithFormat:@"الأداة تلقت إشارة إنهاء (%d)", signalNumber];
        return;
    }

    // spawn succeeded — output validation happens separately via markReady or markStatus
}

- (void)markReadyWithPath:(NSString *)path output:(NSString *)output duration:(NSTimeInterval)duration {
    _resolvedPath = [path copy];
    _exists = YES;
    _isAccessible = YES;
    _isExecutable = YES;
    _isInvocable = YES;
    _outputValid = YES;
    _testOutput = [output copy] ?: @"";
    _duration = duration;
    _status = ExecutableCapabilityStatusReady;
    _lastErrorMessage = nil;
    _spawnError = 0;
    _exitCode = 0;
    _signalNumber = 0;
}

- (void)markStatus:(ExecutableCapabilityStatus)status errorMessage:(NSString *)error {
    _status = status;
    _lastErrorMessage = [error copy];
}

- (NSString *)localizedStatusDescription {
    switch (_status) {
        case ExecutableCapabilityStatusReady:
            return @"الأداة جاهزة";
        case ExecutableCapabilityStatusNotFound:
            return @"الأداة غير موجودة";
        case ExecutableCapabilityStatusNotExecutable:
            return @"الأداة غير قابلة للتنفيذ";
        case ExecutableCapabilityStatusPermissionDenied:
            return @"تم رفض الصلاحية";
        case ExecutableCapabilityStatusProcessFailed:
            return @"فشل تشغيل الأداة";
        case ExecutableCapabilityStatusInvalidOutput:
            return @"خرج الأداة غير صالح";
        case ExecutableCapabilityStatusTimeout:
            return @"انتهت مهلة الاختبار";
        case ExecutableCapabilityStatusUnknownError:
            return @"خطأ غير معروف";
        default:
            return @"حالة غير معروفة";
    }
}

- (NSDictionary *)diagnosticSnapshot {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"executable"] = _executableName ?: @"";
    d[@"resolvedPath"] = _resolvedPath ?: @"";
    d[@"status"] = @(_status);
    d[@"statusName"] = [self statusName];
    d[@"exists"] = @(_exists);
    d[@"isExecutable"] = @(_isExecutable);
    d[@"isInvocable"] = @(_isInvocable);
    d[@"outputValid"] = @(_outputValid);
    d[@"spawnError"] = @(_spawnError);
    d[@"exitCode"] = @(_exitCode);
    d[@"signal"] = @(_signalNumber);
    d[@"durationMs"] = @(round(_duration * 1000.0));
    d[@"timestamp"] = _testTimestamp ?: [NSDate date];
    d[@"searchedPathsCount"] = @(_searchedPaths.count);
    // Do NOT include searchedPaths array (could be long)
    // Do NOT include testOutput (could be large)
    return d;
}

- (NSDictionary *)fullDiagnosticDictionary {
    NSMutableDictionary *d = [[self diagnosticSnapshot] mutableCopy];
    d[@"searchedPaths"] = _searchedPaths ?: @[];
    d[@"testOutput"] = _testOutput ?: @"";
    d[@"errorMessage"] = _lastErrorMessage ?: @"";
    return d;
}

- (NSString *)statusName {
    switch (_status) {
        case ExecutableCapabilityStatusReady: return @"READY";
        case ExecutableCapabilityStatusNotFound: return @"NOT_FOUND";
        case ExecutableCapabilityStatusNotExecutable: return @"NOT_EXECUTABLE";
        case ExecutableCapabilityStatusPermissionDenied: return @"PERMISSION_DENIED";
        case ExecutableCapabilityStatusProcessFailed: return @"PROCESS_FAILED";
        case ExecutableCapabilityStatusInvalidOutput: return @"INVALID_OUTPUT";
        case ExecutableCapabilityStatusTimeout: return @"TIMEOUT";
        case ExecutableCapabilityStatusUnknownError: return @"UNKNOWN_ERROR";
        default: return @"UNKNOWN";
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<ExecutableCapability: %@ | status=%@ | path=%@ | exists=%@ | exec=%@ | invoke=%@ | output=%@ | duration=%.3fs>",
            _executableName, [self statusName], _resolvedPath.lastPathComponent,
            _exists ? @"YES" : @"NO", _isExecutable ? @"YES" : @"NO",
            _isInvocable ? @"YES" : @"NO", _outputValid ? @"YES" : @"NO", _duration];
}

@end
