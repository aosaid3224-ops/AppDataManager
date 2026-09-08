#import "Logger.h"

@interface Logger ()
@property (nonatomic, strong) NSMutableArray<NSString *> *logs;
@property (nonatomic, strong) NSDateFormatter *formatter;
@property (nonatomic, strong) dispatch_queue_t logQueue;
@end

@implementation Logger

+ (instancetype)sharedLogger {
    static Logger *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _logs = [NSMutableArray array];
        _formatter = [[NSDateFormatter alloc] init];
        [_formatter setDateFormat:@"HH:mm:ss.SSS"];
        _logQueue = dispatch_queue_create("com.aosaid.ipainstallerpro.logger", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)log:(LogLevel)level message:(NSString *)message {
    if (!message) return;
    dispatch_async(self.logQueue, ^{
        NSString *levelStr = @"DEBUG";
        switch (level) {
            case LogLevelInfo: levelStr = @"INFO"; break;
            case LogLevelWarning: levelStr = @"WARN"; break;
            case LogLevelError: levelStr = @"ERROR"; break;
            default: break;
        }
        NSString *timestamp = [self.formatter stringFromDate:[NSDate date]];
        NSString *logLine = [NSString stringWithFormat:@"[%@] %@: %@", timestamp, levelStr, message];
        [self.logs addObject:logLine];
        NSLog(@"[IPAInstallerPro] %@", logLine);
    });
}

- (void)debug:(NSString *)msg { [self log:LogLevelDebug message:msg]; }
- (void)info:(NSString *)msg { [self log:LogLevelInfo message:msg]; }
- (void)warning:(NSString *)msg { [self log:LogLevelWarning message:msg]; }
- (void)error:(NSString *)msg { [self log:LogLevelError message:msg]; }

- (NSArray<NSString *> *)allLogs {
    __block NSArray<NSString *> *result;
    dispatch_sync(self.logQueue, ^{ result = [self.logs copy]; });
    return result;
}

- (void)clearLogs {
    dispatch_async(self.logQueue, ^{ [self.logs removeAllObjects]; });
}

@end
