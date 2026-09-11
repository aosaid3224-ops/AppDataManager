//
// LiveOperationStream.m
// IPA Installer Pro — UI/Event Pipeline only
//

#import "LiveOperationStream.h"

@interface LiveOperationStream ()
@property (nonatomic, copy) NSString *transactionID;
@property (nonatomic, copy) LiveOperationEventHandler handler;
@property (nonatomic, copy) NSString *subscriptionID;
@property (nonatomic, assign, readwrite, getter=isClosed) BOOL closed;
@property (nonatomic, assign) NSUInteger nextSequence;
@property (nonatomic, assign) BOOL finalDelivered;
@end

@implementation LiveOperationEvent
@end

@implementation LiveOperationStream

- (void)startForTransactionID:(NSString *)transactionID handler:(LiveOperationEventHandler)handler {
    [self close];
    self.transactionID = [transactionID copy];
    self.handler = [handler copy];
    self.nextSequence = 0;
    self.finalDelivered = NO;
    self.closed = NO;
    __weak typeof(self) weakSelf = self;
    self.subscriptionID = [[OperationLog sharedLog] subscribeLiveToTransactionID:self.transactionID handler:^(OperationRecord *record, BOOL isUpdate) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf receiveRecord:record isUpdate:isUpdate];
    }];
}

- (void)close {
    if (self.subscriptionID.length) {
        [[OperationLog sharedLog] unsubscribeLiveSubscription:self.subscriptionID];
    }
    self.subscriptionID = nil;
    self.closed = YES;
    self.handler = nil;
    self.transactionID = nil;
}

- (void)dealloc {
    if (self.subscriptionID.length) [[OperationLog sharedLog] unsubscribeLiveSubscription:self.subscriptionID];
}

- (BOOL)accepts:(OperationRecord *)record {
    return !self.closed && self.transactionID.length > 0 && [record isKindOfClass:[OperationRecord class]] && [record.transactionID isEqualToString:self.transactionID];
}

- (BOOL)isFinalRecord:(OperationRecord *)record {
    return record.phase == OperationPhaseComplete;
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

- (NSString *)diagnosticMessageForRecord:(OperationRecord *)record {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *operation = record.operation ?: @"";
    if (operation.length) [parts addObject:operation];

    // OperationLog already owns these diagnostic values. Keep this observer-only:
    // do not run another probe or reinterpret any result here.
    if (record.rawOutput.length) [parts addObject:[NSString stringWithFormat:@"output: %@", record.rawOutput]];
    if (record.rawError.length) [parts addObject:[NSString stringWithFormat:@"error: %@", record.rawError]];
    if (record.verification.length) [parts addObject:[NSString stringWithFormat:@"verification: %@", record.verification]];
    if (record.context.count) {
        NSError *serializationError = nil;
        NSData *json = [NSJSONSerialization dataWithJSONObject:record.context options:0 error:&serializationError];
        NSString *context = json.length ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : nil;
        if (!context.length) context = record.context.description;
        if (context.length) [parts addObject:[NSString stringWithFormat:@"context: %@", context]];
    }
    return [parts componentsJoinedByString:@" | "] ?: @"UNKNOWN";
}

- (void)receiveRecord:(OperationRecord *)record isUpdate:(BOOL)isUpdate {
    if (![self accepts:record] || self.finalDelivered) return;
    LiveOperationEvent *event = [[LiveOperationEvent alloc] init];
    event.recordID = record.recordID ?: @"";
    event.transactionID = record.transactionID ?: @"";
    event.sequence = ++self.nextSequence;
    event.operationTimestamp = record.timestamp ?: [NSDate date];
    event.timestamp = [NSDate date];
    event.dispatchedAt = [NSDate date];
    event.stage = [self stageName:record];
    event.status = [self statusName:record update:isUpdate];
    event.message = [self diagnosticMessageForRecord:record];
    event.target = record.target ?: @"";
    event.exitStatus = record.exitCode;
    event.finalEvent = [self isFinalRecord:record];
    event.update = isUpdate;

    LiveOperationEventHandler handler = self.handler;
    if (handler) handler(event);
    if (event.finalEvent) {
        self.finalDelivered = YES;
        // The final event is delivered before the subscription is closed.
        // Any later callback is rejected at the stream boundary.
        [self close];
    }
}

@end
