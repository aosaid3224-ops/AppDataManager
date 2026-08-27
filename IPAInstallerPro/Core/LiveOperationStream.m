//
// LiveOperationStream.m
// IPA Installer Pro — UI/Event Pipeline only
//

#import "LiveOperationStream.h"

@interface LiveOperationStream ()
@property (nonatomic, copy) NSString *transactionID;
@property (nonatomic, copy) LiveOperationEventHandler handler;
@property (nonatomic, assign, readwrite, getter=isClosed) BOOL closed;
@property (nonatomic, assign) NSUInteger nextSequence;
@property (nonatomic, strong) NSMutableSet<NSString *> *deliveredFinalRecordIDs;
@end

@implementation LiveOperationEvent
@end

@implementation LiveOperationStream

- (void)startForTransactionID:(NSString *)transactionID handler:(LiveOperationEventHandler)handler {
    [self close];
    self.transactionID = [transactionID copy];
    self.handler = [handler copy];
    self.nextSequence = 0;
    self.closed = NO;
    self.deliveredFinalRecordIDs = [NSMutableSet set];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(recordAdded:) name:@"OperationRecordAdded" object:nil];
    [center addObserver:self selector:@selector(recordUpdated:) name:@"OperationRecordUpdated" object:nil];
}

- (void)close {
    if (self.closed && !self.transactionID.length) return;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"OperationRecordAdded" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"OperationRecordUpdated" object:nil];
    self.closed = YES;
    self.handler = nil;
    self.transactionID = nil;
    [self.deliveredFinalRecordIDs removeAllObjects];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)accepts:(OperationRecord *)record {
    return !self.closed && self.transactionID.length > 0 && [record isKindOfClass:[OperationRecord class]] && [record.transactionID isEqualToString:self.transactionID];
}

- (BOOL)isFinalRecord:(OperationRecord *)record {
    if (record.phase == OperationPhaseComplete) return YES;
    if (record.result == OperationResultFailed && (record.phase == OperationPhaseCleanup || record.phase == OperationPhaseCrashDiagnostics)) return YES;
    return NO;
}

- (NSString *)stageName:(OperationRecord *)record {
    NSString *phase = [record phaseName];
    return phase.length ? phase.uppercaseString : @"UNKNOWN";
}

- (NSString *)statusName:(OperationRecord *)record update:(BOOL)update {
    if (record.result == OperationResultPending || record.exitCode == -1) return update ? @"RUNNING" : @"PENDING";
    if (record.result == OperationResultSuccess && record.verified && record.exitCode == 0) return @"SUCCESS";
    if (record.result == OperationResultPartial) return @"PARTIAL";
    if (record.result == OperationResultSkipped) return @"SKIPPED";
    return @"FAILED";
}

- (LiveOperationEvent *)eventFromRecord:(OperationRecord *)record update:(BOOL)update {
    LiveOperationEvent *event = [[LiveOperationEvent alloc] init];
    event.recordID = record.recordID ?: @"";
    event.transactionID = record.transactionID ?: @"";
    event.sequence = ++self.nextSequence;
    event.timestamp = record.timestamp ?: [NSDate date];
    event.stage = [self stageName:record];
    event.status = [self statusName:record update:update];
    event.message = record.operation ?: @"";
    event.target = record.target ?: @"";
    event.exitStatus = record.exitCode;
    event.finalEvent = [self isFinalRecord:record];
    event.update = update;
    return event;
}

- (void)emitRecord:(OperationRecord *)record update:(BOOL)update {
    if (![self accepts:record]) return;
    LiveOperationEvent *event = [self eventFromRecord:record update:update];
    LiveOperationEventHandler handler = self.handler;
    if (handler) handler(event);
    if (event.finalEvent) {
        [self.deliveredFinalRecordIDs addObject:event.recordID];
        // Closing is synchronous and happens only after delivering the final
        // event. Any queued notification arriving afterward is rejected.
        [self close];
    }
}

- (void)recordAdded:(NSNotification *)notification {
    [self emitRecord:notification.object update:NO];
}

- (void)recordUpdated:(NSNotification *)notification {
    OperationRecord *record = notification.object;
    if (![self accepts:record]) return;
    // A final record must be delivered exactly once. It may be emitted first
    // as BEGIN and later as END, but not after the stream has closed.
    if ([self isFinalRecord:record] && [self.deliveredFinalRecordIDs containsObject:record.recordID]) return;
    [self emitRecord:record update:YES];
}

@end
