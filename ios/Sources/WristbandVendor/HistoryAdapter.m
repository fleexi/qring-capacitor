#import "WBSessionInternal.h"

static NSDictionary *WBHistoryError(NSError *error) {
    NSMutableDictionary *result = [WBError(@"SDK_ERROR", error.localizedDescription ?: @"History read failed") mutableCopy];
    if (error) result[@"vendorCode"] = [NSString stringWithFormat:@"%@:%ld", error.domain, (long)error.code];
    return result;
}

// Sleep belongs to the requested sleep day but can start on the previous calendar day.
static void WBApplySleepTimes(NSMutableDictionary *record, QCSleepModel *model) {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDate *start = [WBPolicy localDateTime:[model realBeginTime] calendar:calendar]
        ?: [WBPolicy localDateTime:model.happenDate calendar:calendar];
    NSDate *end = [WBPolicy localDateTime:[model realEndTime] calendar:calendar]
        ?: [WBPolicy localDateTime:model.endTime calendar:calendar];
    if (!start || !end || [end compare:start] != NSOrderedDescending) return;
    record[@"start"] = @(llround(start.timeIntervalSince1970 * 1000));
    record[@"end"] = @(llround(end.timeIntervalSince1970 * 1000));
    record[@"timestamp"] = record[@"start"];
    record[@"utcOffsetMinutes"] = @([calendar.timeZone secondsFromGMTForDate:start] / 60);
    record[@"timestampSource"] = @"reconstructed";
    // Only expand phase durations when they cover the SDK interval exactly.
    double total = 0;
    for (NSDictionary *phase in record[@"phases"]) total += [phase[@"durationSeconds"] doubleValue];
    if (fabs(total - [end timeIntervalSinceDate:start]) > 0.5) return;
    NSMutableArray *timed = [NSMutableArray new];
    double cursor = start.timeIntervalSince1970;
    for (NSDictionary *phase in record[@"phases"]) {
        NSMutableDictionary *item = [phase mutableCopy];
        item[@"start"] = @(llround(cursor * 1000));
        cursor += [phase[@"durationSeconds"] doubleValue];
        item[@"end"] = @(llround(cursor * 1000));
        [timed addObject:item];
    }
    record[@"phases"] = timed;
}

static NSDictionary *WBSleepSegment(QCSleepModel *model, NSString *date, BOOL nap) {
    NSMutableArray *phases = [NSMutableArray new];
    NSArray *types = [model.dataTypes componentsSeparatedByString:@","], *minutes = [model.dataMinutes componentsSeparatedByString:@","];
    if (model.dataTypes.length && types.count == minutes.count) {
        for (NSUInteger i = 0; i < types.count; i++) if ([minutes[i] integerValue] > 0) [phases addObject:@{@"stage":@"unknown", @"durationSeconds":@([minutes[i] integerValue] * 60)}];
    } else {
        NSString *stage = @{@(SLEEPTYPESOBER):@"awake", @(SLEEPTYPELIGHT):@"light", @(SLEEPTYPEDEEP):@"deep", @(SLEEPTYPEREM):@"rem"}[@(model.type)] ?: @"unknown";
        if (model.total > 0) [phases addObject:@{@"stage":stage, @"durationSeconds":@(model.total * 60)}];
    }
    NSMutableDictionary *record = [@{@"metric":@"sleep", @"date":date, @"source":@"scheduled", @"nap":@(nap), @"durationSeconds":@(MAX(0, model.total) * 60), @"phases":phases} mutableCopy];
    WBApplySleepTimes(record, model);
    return record;
}

// Match Android: one night record and one nap record per requested sleep day.
static NSDictionary *WBSleepGroup(NSArray<QCSleepModel *> *models, NSString *date, BOOL nap) {
    if (!models.count) return nil;
    NSMutableArray *phases = [NSMutableArray new];
    long long duration = 0;
    NSNumber *start = nil, *end = nil;
    BOOL allTimed = YES;
    for (QCSleepModel *model in models) {
        NSDictionary *segment = WBSleepSegment(model, date, nap);
        if (![segment[@"phases"] count]) continue;
        [phases addObjectsFromArray:segment[@"phases"]];
        for (NSDictionary *phase in segment[@"phases"]) duration += [phase[@"durationSeconds"] longLongValue];
        NSNumber *segmentStart = segment[@"start"], *segmentEnd = segment[@"end"];
        if (!segmentStart || !segmentEnd) { allTimed = NO; continue; }
        if (!start || [segmentStart compare:start] == NSOrderedAscending) start = segmentStart;
        if (!end || [segmentEnd compare:end] == NSOrderedDescending) end = segmentEnd;
    }
    if (!phases.count) return nil;
    BOOL phasesTimed = YES;
    for (NSDictionary *phase in phases) if (!phase[@"start"]) { phasesTimed = NO; break; }
    if (phasesTimed) [phases sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[@"start"] compare:right[@"start"]];
    }];
    NSMutableDictionary *record = [@{@"metric":@"sleep", @"date":date, @"source":@"scheduled",
        @"nap":@(nap), @"durationSeconds":@(duration), @"phases":phases} mutableCopy];
    if (allTimed && start && end) {
        record[@"start"] = start;
        record[@"end"] = end;
        record[@"timestamp"] = start;
        NSDate *begin = [NSDate dateWithTimeIntervalSince1970:start.doubleValue / 1000.0];
        record[@"utcOffsetMinutes"] = @([NSTimeZone.localTimeZone secondsFromGMTForDate:begin] / 60);
        record[@"timestampSource"] = @"reconstructed";
    }
    return record;
}

@implementation WBSession (History)
- (BOOL)appendScheduledValues:(NSArray *)values metric:(NSString *)metric modelDate:(NSString *)modelDate expectedDate:(NSString *)expectedDate seconds:(double)seconds to:(NSMutableArray *)records reply:(WBReply)reply {
    NSDictionary *error = nil;
    NSArray *mapped = [WBPolicy scheduledValues:values metric:metric modelDate:modelDate expectedDate:expectedDate intervalSeconds:seconds calendar:NSCalendar.currentCalendar error:&error];
    if (!mapped) { reply(nil, error); return NO; }
    [records addObjectsFromArray:mapped];
    return YES;
}

- (void)readDay:(NSString *)metric day:(NSInteger)day date:(NSString *)date done:(WBReply)done {
    if (day < 0 || day > 6) { done(nil, WBError(@"INVALID_ARGUMENT", @"Frozen date outside device retention")); return; }
    NSString *support = [self metricCapability:metric][@"history"][@"support"];
    if (![support isEqual:@"supported"]) {
        done(nil, WBError([support isEqual:@"unknown"] ? @"CAPABILITY_UNKNOWN" : @"UNSUPPORTED", @"History support unavailable"));
        return;
    }
    WBReply reply = [self once:done];
    NSMutableArray *records = [NSMutableArray new];
    void (^success)(void) = ^{ reply(@{@"records":records}, nil); };
    void (^failure)(void) = ^{ reply(nil, WBHistoryError(nil)); };

    if ([metric isEqual:@"heartRate"]) {
        // Same detailed-data API as OnWell, using the interval returned by each model.
        [QCSDKCmdCreator getOneMinuHeartRateDataWithIntervalByDayIndex:day finished:^(NSArray *models, NSError *error) {
            if (error) { reply(nil, WBHistoryError(error)); return; }
            for (QCSchedualHeartRateModel *model in models) {
                if (![model isKindOfClass:QCSchedualHeartRateModel.class]) { failure(); return; }
                if (![self appendScheduledValues:model.heartRates metric:metric modelDate:model.date expectedDate:date seconds:model.secondInterval to:records reply:reply]) return;
            }
            success();
        }];
    } else if ([metric isEqual:@"bloodOxygen"]) {
        // Legacy detailed API already returned readings on the integrated band.
        [QCSDKCmdCreator getBloodOxygenDataByDayIndex:day finished:^(NSArray *models, NSError *error) {
            if (error) { reply(nil, WBHistoryError(error)); return; }
            NSUInteger index = 0;
            for (QCBloodOxygenModel *model in models) {
                NSUInteger sampleIndex = index++;
                if (![model isKindOfClass:QCBloodOxygenModel.class]) { failure(); return; }
                NSNumber *value = [WBPolicy scheduledOxygenValueForSource:model.sourceType maximum:model.maxSoa2 minimum:model.minSoa2 value:model.soa2];
                if (!value) continue;
                NSDictionary *mappingError = nil;
                NSDictionary *fields = [WBPolicy timestampFieldsForDate:model.date expectedDate:date calendar:NSCalendar.currentCalendar error:&mappingError];
                if (!fields) {
                    // A response may include samples outside the requested day; retain valid ones.
                    if ([QCSDKManager shareInstance].debug) NSLog(@"[Wristband] SpO2 sample excluded: requestedDate=%@ returnedDate=%@", date, mappingError[@"returnedDate"]);
                    continue;
                }
                NSMutableDictionary *record = [@{@"metric":metric, @"date":date, @"source":@"scheduled", @"value":value, @"unit":@"%", @"sampleIndex":@(sampleIndex)} mutableCopy];
                [record addEntriesFromDictionary:fields];
                [records addObject:record];
            }
            success();
        }];
    } else if ([metric isEqual:@"hrv"]) {
        // Match the HRV path verified on the OnWell band, including its model interval.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [QCSDKCmdCreator getSchedualHRVDataWithDates:@[@(day)] finished:^(NSArray *models, NSError *error) {
            if (error) { reply(nil, WBHistoryError(error)); return; }
            for (QCHRVModel *model in models) {
                if (![model isKindOfClass:QCHRVModel.class]) { failure(); return; }
                if (![self appendScheduledValues:model.hrv metric:metric modelDate:model.date expectedDate:date seconds:model.secondInterval to:records reply:reply]) return;
            }
            success();
        }];
#pragma clang diagnostic pop
    } else if ([metric isEqual:@"stress"]) {
        // OnWell uses this path successfully with a band despite the vendor header's ring-only note.
        [QCSDKCmdCreator getSchedualStressDataWithDates:@[@(day)] finished:^(NSArray *models, NSError *error) {
            if (error) { reply(nil, WBHistoryError(error)); return; }
            for (QCStressModel *model in models) {
                if (![model isKindOfClass:QCStressModel.class]) { failure(); return; }
                if (![self appendScheduledValues:model.stresses metric:metric modelDate:model.date expectedDate:date seconds:model.secondInterval to:records reply:reply]) return;
            }
            success();
        }];
    } else if ([metric isEqual:@"steps"]) {
        [QCSDKCmdCreator getSportDetailDataByDay:day sportDatas:^(NSArray<QCSportModel *> *models) {
            for (QCSportModel *model in models) {
                if (model.totalStepCount <= 0 && model.distance <= 0) continue;
                NSMutableDictionary *record = [@{@"metric":metric, @"date":date, @"source":@"scheduled", @"steps":@(model.totalStepCount), @"distanceMeters":@(model.distance), @"intervalMinutes":@15} mutableCopy];
                NSCalendar *calendar = NSCalendar.currentCalendar;
                NSDate *sample = [WBPolicy localDateTime:model.happenDate calendar:calendar];
                NSDictionary *fields = [WBPolicy timestampFieldsForDate:sample expectedDate:date calendar:calendar error:NULL];
                if (fields) {
                    [record addEntriesFromDictionary:fields];
                    record[@"timestampSource"] = @"reconstructed";
                    NSDateComponents *time = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:sample];
                    if (time.minute % 15 == 0 && time.second == 0) record[@"sampleIndex"] = @((time.hour * 60 + time.minute) / 15);
                }
                [records addObject:record];
            }
            success();
        } fail:failure];
    } else {
        [QCSDKCmdCreator getFulldaySleepDetailDataByDay:day sleepDatas:^(NSArray<QCSleepModel *> *night, NSArray<QCSleepModel *> *naps) {
            NSDictionary *nightRecord = WBSleepGroup(night, date, NO);
            NSDictionary *napRecord = WBSleepGroup(naps, date, YES);
            if (nightRecord) [records addObject:nightRecord];
            if (napRecord) [records addObject:napRecord];
            success();
        } fail:failure];
    }
}
- (void)history:(NSArray<NSString *> *)metrics start:(NSInteger)start days:(NSInteger)days {
    NSCalendar *calendar=[NSCalendar.currentCalendar copy];NSDate *anchor=NSDate.date;NSDateFormatter *format=[NSDateFormatter new];format.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"];format.calendar=calendar;format.timeZone=calendar.timeZone;format.dateFormat=@"yyyy-MM-dd";
    NSMutableArray *jobs=[NSMutableArray new];for(NSString *m in metrics)for(NSInteger i=start;i<start+days;i++)[jobs addObject:@{@"metric":m,@"day":@(i),@"date":[format stringFromDate:[calendar dateByAddingUnit:NSCalendarUnitDay value:-i toDate:anchor options:0]]}];
    NSMutableArray *batches=[NSMutableArray new];NSString *token=self.gate.token,*device=self.peripheral.identifier.UUIDString;self.historyFailure=^NSDictionary *(NSDictionary *e){return [WBPolicy failedHistory:jobs batches:batches operation:token device:device error:e];};__weak WBSession *weak=self;
    self.historyNext=^(NSUInteger index){WBSession *s=weak;if(![s.gate isCurrent:token]){s.historyNext=nil;return;}if(index==jobs.count){NSUInteger errors=0;for(NSDictionary *b in batches)if([b[@"status"] isEqual:@"error"])errors++;[s complete:@{@"operationId":token,@"deviceId":device,@"status":errors==0?@"success":errors==batches.count?@"failed":@"partial",@"batches":batches} error:nil];s.historyNext=nil;return;}
        NSDictionary *job=jobs[index];
        NSDate *target=[format dateFromString:job[@"date"]];
        NSInteger adjusted=[WBPolicy dayIndex:target today:NSDate.date calendar:calendar];
        [s readDay:job[@"metric"] day:adjusted date:job[@"date"] done:^(NSDictionary *result,NSDictionary *error){NSMutableDictionary *b=[@{@"operationId":token,@"deviceId":device,@"batchIndex":@(index),@"metric":job[@"metric"],@"date":job[@"date"],@"status":error?@"error":@"success",@"records":result[@"records"]?:@[]} mutableCopy];if(error)b[@"error"]=error;[batches addObject:b];[s emit:@"historyBatch" data:b];[s emit:@"syncProgress" data:@{@"operationId":token,@"deviceId":device,@"completed":@(index+1),@"total":@(jobs.count)}];if(s.historyNext)s.historyNext(index+1);}];
    };self.historyNext(0);
}
@end
