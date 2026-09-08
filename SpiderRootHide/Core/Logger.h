#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, LogLevel) {
    LogLevelDebug = 0,
    LogLevelInfo = 1,
    LogLevelWarning = 2,
    LogLevelError = 3
};

@interface Logger : NSObject
+ (instancetype)sharedLogger;
- (void)log:(LogLevel)level message:(NSString *)message;
- (void)debug:(NSString *)msg;
- (void)info:(NSString *)msg;
- (void)warning:(NSString *)msg;
- (void)error:(NSString *)msg;
- (NSArray<NSString *> *)allLogs;
- (void)clearLogs;
@end
