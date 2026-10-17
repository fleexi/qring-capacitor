#import "WBSessionInternal.h"
@implementation WBSession (Settings)
- (NSDictionary *)metricCapability:(NSString *)m {
    BOOL ready=[self.connection isEqual:@"ready"];
    NSString *key=@{@"bloodOxygen":QCBandFeatureBloodOxygen,@"hrv":QCBandFeatureHRV,@"stress":QCBandFeatureStress}[m];
    NSString *s=!ready?@"unknown":(!key?@"supported":(!self.features[key]?@"unknown":([self.features[key] boolValue]?@"supported":@"unsupported")));
    if([m isEqual:@"heartRate"] && ready)s=@"supported";
    NSDictionary *op=@{@"support":s,@"reason":@"SDK protocol and device feature flags"};
    BOOL numeric=![@[@"steps",@"sleep"] containsObject:m];
    NSString *setting=!numeric?@"unsupported":s;
    NSDictionary *en=@{@"support":setting,@"readable":@(![setting isEqual:@"unsupported"]),@"writable":@(![setting isEqual:@"unsupported"])};
    NSDictionary *interval=self.settingsMetadata[m]?:@{@"support":@"unknown",@"readable":@NO,@"writable":@NO};
    if(!numeric || [m isEqual:@"hrv"])interval=@{@"support":@"unsupported",@"readable":@NO,@"writable":@NO,@"reason":@"No verified interval read/write mapping in v1"};
    return @{@"history":op,@"settings":@{@"enabled":en,@"intervalMinutes":interval}};
}
- (NSDictionary *)capabilities {NSMutableDictionary *metrics=[NSMutableDictionary new];for(NSString *m in WBMetrics())metrics[m]=[self metricCapability:m];return @{@"metrics":metrics};}
- (void)readSettings:(NSString *)m done:(WBReply)done {
    WBReply reply=[self once:done];void(^fail)(void)=^{reply(nil,WBError(@"SDK_ERROR",@"Setting read failed"));};
    void(^value)(BOOL,NSInteger)=^(BOOL enabled,NSInteger interval){NSMutableDictionary *v=[@{@"enabled":@(enabled)} mutableCopy];if(interval>0)v[@"intervalMinutes"]=@(interval);reply(v,nil);};
    if([m isEqual:@"heartRate"]) [QCSDKCmdCreator getSchedualHeartRateStatusAndIntervalWithSuccess:value fail:fail];
    else if([m isEqual:@"bloodOxygen"]) [QCSDKCmdCreator getSchedualBOInfoWithIntervalSuccess:value fail:fail];
    else if([m isEqual:@"hrv"]) [QCSDKCmdCreator getSchedualHRVWithFinshed:^(BOOL e,NSError *error){if(error)fail();else value(e,0);}];
    else if([m isEqual:@"stress"]) [QCSDKCmdCreator getSchedualStressStatusWithIntervalFinshed:^(BOOL e,NSInteger min,NSInteger current,NSError *error){if(error)fail();else reply(@{@"enabled":@(e),@"intervalMinutes":@(current),@"min":@(min)},nil);}];
    else reply(nil,WBError(@"UNSUPPORTED",@"No settings for this metric"));
}
- (NSDictionary *)publicSettings:(NSString *)m values:(NSDictionary *)v {
    if(v[@"intervalMinutes"] && [v[@"intervalMinutes"] integerValue]>0) self.settingsMetadata[m]=@{@"support":@"supported",@"readable":@YES,@"writable":@YES,@"min":v[@"min"]?:@1,@"max":@255,@"step":@1};
    NSMutableDictionary *r=[@{@"metric":m,@"source":@"device",@"readAt":@(WBNow()),@"capabilities":[self metricCapability:m][@"settings"]} mutableCopy];r[@"enabled"]=v[@"enabled"];if(v[@"intervalMinutes"])r[@"intervalMinutes"]=v[@"intervalMinutes"];return r;
}
- (void)settings:(NSString *)m patch:(NSDictionary *)patch done:(WBReply)done {
    NSString *support=[self metricCapability:m][@"settings"][@"enabled"][@"support"];
    if(![support isEqual:@"supported"]){done(nil,WBError([support isEqual:@"unknown"]?@"CAPABILITY_UNKNOWN":@"UNSUPPORTED",@"Automatic measurement support is not available"));return;}
    if(patch){NSString *e=[WBPolicy validatePatch:patch];if(e){done(nil,WBError(@"INVALID_ARGUMENT",e));return;}}
    [self readSettings:m done:^(NSDictionary *v,NSDictionary *e){
        if(e){done(nil,e);return;}NSDictionary *current=[self publicSettings:m values:v];if(!patch){done(current,nil);return;}
        NSDictionary *ic=current[@"capabilities"][@"intervalMinutes"];NSNumber *interval=patch[@"intervalMinutes"]?:v[@"intervalMinutes"];
        if(patch[@"intervalMinutes"] && (![ic[@"writable"] boolValue] || [interval integerValue]<[ic[@"min"] integerValue] || [interval integerValue]>255)){done(nil,WBError(@"INVALID_ARGUMENT",@"Interval is unsupported or outside verified bounds"));return;}
        BOOL enabled=patch[@"enabled"]?[patch[@"enabled"] boolValue]:[v[@"enabled"] boolValue];
        WBReply ack=[self once:^(NSDictionary *d,NSDictionary *error){if(error){done(nil,error);return;}self.writeAcknowledged=YES;[self readSettings:m done:^(NSDictionary *actual,NSDictionary *readError){if(readError || ![WBPolicy verificationMatches:patch actual:actual]){done(nil,@{@"code":@"WRITE_VERIFICATION_FAILED",@"message":@"Write acknowledged; read-back failed or differs from the patch",@"writeAcknowledged":@YES});return;}done(@{@"verification":@"readBack",@"settings":[self publicSettings:m values:actual]},nil);}];}];
        void(^success)(void)=^{ack(@{},nil);};void(^fail)(void)=^{ack(nil,WBError(@"SDK_ERROR",@"Setting write failed"));};
        if([m isEqual:@"heartRate"]) {if(interval)[QCSDKCmdCreator setSchedualHeartRateStatus:enabled timeInterval:interval.integerValue success:success fail:fail];else [QCSDKCmdCreator setSchedualHeartRateStatus:enabled success:^(BOOL x){success();} fail:fail];}
        else if([m isEqual:@"bloodOxygen"]) {if(interval)[QCSDKCmdCreator setSchedualBOInfoOn:enabled timeInterval:interval.integerValue success:success fail:fail];else [QCSDKCmdCreator setSchedualBOInfoOn:enabled success:^(BOOL x){success();} fail:fail];}
        else if([m isEqual:@"hrv"]) [QCSDKCmdCreator setSchedualHRVStatus:enabled finshed:^(NSError *error){if(error)fail();else success();}];
        else if([m isEqual:@"stress"]) {if(interval)[QCSDKCmdCreator setSchedualStressStatus:enabled interval:interval.integerValue finshed:^(NSError *error){if(error)fail();else success();}];else [QCSDKCmdCreator setSchedualStressStatus:enabled finshed:^(NSError *error){if(error)fail();else success();}];}
    }];
}
@end
