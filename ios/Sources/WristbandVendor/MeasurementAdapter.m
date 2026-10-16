#import "WBSessionInternal.h"
@implementation WBSession (Measurement)
- (QCMeasuringType)measurementType:(NSString *)metric {return [@{@"heartRate":@(QCMeasuringTypeHeartRate),@"bloodOxygen":@(QCMeasuringTypeBloodOxygen),@"temperature":@(QCMeasuringTypeBodyTemperature),@"hrv":@(QCMeasuringTypeHRV),@"stress":@(QCMeasuringTypeStress)}[metric] integerValue];}
- (void)measurementValue:(id)v token:(NSString *)token {
    if(![self.gate isCurrent:token] || !self.sessionId || self.measurementStopping || ![v isKindOfClass:NSNumber.class] || !isfinite([v doubleValue]) || [v doubleValue]<=0)return;
    [self emit:@"measurementUpdated" data:@{@"sessionId":self.sessionId,@"deviceId":self.peripheral.identifier.UUIDString,@"metric":self.measurementMetric,@"value":v,@"unit":WBUnit(self.measurementMetric),@"timestamp":@(WBNow())}];
}
- (void)refreshHeart:(NSString *)token {
    if(![self.gate isCurrent:token] || self.measurementStopping)return;
    WBReply refreshed=[self once:^(NSDictionary *d,NSDictionary *e){if(e){[self finishMeasurement:@"failed" reason:@"refreshFailed" error:e];return;}__weak WBSession *weak=self;self.keepalive=[NSTimer scheduledTimerWithTimeInterval:2 repeats:NO block:^(NSTimer *timer){[weak refreshHeart:token];}];}];
    [QCSDKCmdCreator continueRealTimeHeartRateSuccess:^{refreshed(@{},nil);} fail:^{refreshed(nil,WBError(@"SDK_ERROR",@"Heart-rate refresh failed"));}];
}
- (void)measure:(NSString *)metric mode:(NSString *)mode timeout:(double)timeout {
    NSString *support=[self metricCapability:metric][[mode isEqual:@"single"]?@"singleMeasurement":@"continuousMeasurement"][@"support"];
    if(![support isEqual:@"supported"]){[self complete:nil error:WBError([support isEqual:@"unknown"]?@"CAPABILITY_UNKNOWN":@"UNSUPPORTED",@"Measurement mode unavailable")];return;}
    NSString *token=self.gate.token;self.sessionId=token;self.measurementMetric=metric;self.measurementMode=mode;self.measurementStopping=NO;
    if([mode isEqual:@"single"]) {
        WBCompletion start=self.pending;self.pending=nil;
        [[QCSDKManager shareInstance] startToMeasuringWithOperateType:[self measurementType:metric] timeout:(NSInteger)ceil(timeout/1000) measuringHandle:^(id value){dispatch_async(dispatch_get_main_queue(),^{[self measurementValue:value token:token];});} completedHandle:^(BOOL ok,id value,NSError *error){dispatch_async(dispatch_get_main_queue(),^{if(![self.gate isCurrent:token] || self.measurementStopping)return;[self measurementValue:value token:token];[self finishMeasurement:ok?@"completed":@"failed" reason:nil error:ok?nil:WBError(@"SDK_ERROR",error.localizedDescription?:@"Measurement failed")];});}];
        start(@{@"sessionId":token},nil);
    } else {
        WBReply ack=[self once:^(NSDictionary *d,NSDictionary *e){WBCompletion started=self.pending;self.pending=nil;if(e){if(started)started(nil,e);[self finishMeasurement:@"failed" reason:nil error:e];return;}[QCSDKManager shareInstance].realTimeHeartRate=^(NSInteger n){dispatch_async(dispatch_get_main_queue(),^{[self measurementValue:@(n) token:token];});};if(started)started(@{@"sessionId":token},nil);[self refreshHeart:token];}];
        [QCSDKCmdCreator beginRealTimeHeartRateSuccess:^{ack(@{},nil);} fail:^{ack(nil,WBError(@"SDK_ERROR",@"Real-time heart rate start failed"));}];
    }
    // The SDK timeout is acquisition duration, not its enclosing command deadline.
    // Leave bounded time for start ACK and terminal callback; stop has its own watchdog.
    double deadline=timeout+([mode isEqual:@"single"]?5000:0);
    __weak WBSession *weak=self;if(timeout>0)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,deadline*NSEC_PER_MSEC),dispatch_get_main_queue(),^{WBSession *s=weak;if([s.gate isCurrent:token])[s finishMeasurement:@"failed" reason:@"timeout" error:WBError(@"TIMEOUT",@"Measurement session expired")];});
}
- (void)finishMeasurement:(NSString *)status reason:(NSString *)reason error:(NSDictionary *)error {
    if(!self.sessionId || self.measurementStopping)return;self.measurementStopping=YES;[self.keepalive invalidate];self.keepalive=nil;[QCSDKManager shareInstance].realTimeHeartRate=nil;
    WBReply stopped=[self once:^(NSDictionary *d,NSDictionary *e){[self finalizeMeasurement:e?@"failed":status reason:reason error:e?:error];if(e)[self close:@"stopFailed"];}];
    if([self.measurementMode isEqual:@"continuous"])[QCSDKCmdCreator endRealTimeHeartRateSuccess:^{stopped(@{},nil);} fail:^{stopped(nil,WBError(@"SDK_ERROR",@"Stop failed"));}];
    else [[QCSDKManager shareInstance] stopToMeasuringWithOperateType:[self measurementType:self.measurementMetric] completedHandle:^(BOOL ok,NSError *e){stopped(@{},ok?nil:WBError(@"SDK_ERROR",e.localizedDescription?:@"Stop failed"));}];
}
- (void)finalizeMeasurement:(NSString *)status reason:(NSString *)reason error:(NSDictionary *)error {
    if(!self.sessionId)return;NSString *sid=self.sessionId,*metric=self.measurementMetric;self.sessionId=nil;self.measurementStopping=NO;[self.keepalive invalidate];self.keepalive=nil;[QCSDKManager shareInstance].realTimeHeartRate=nil;
    WBCompletion stop=self.stopRequest;self.stopRequest=nil;
    if(self.pending)[self complete:nil error:error?:WBError(@"CANCELLED",reason?:@"Measurement cancelled")];else [self complete:@{} error:nil];
    NSMutableDictionary *event=[@{@"sessionId":sid,@"deviceId":self.peripheral.identifier.UUIDString?:@"",@"metric":metric,@"status":status} mutableCopy];if(reason)event[@"reason"]=reason;if(error)event[@"error"]=error;[self emit:@"measurementFinished" data:event];
    if(stop)stop(error?nil:@{@"stopped":@YES},error);
}
@end
