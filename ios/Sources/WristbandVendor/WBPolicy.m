#import "WBPolicy.h"
#import <CoreFoundation/CoreFoundation.h>
@implementation WBPolicy
- (NSString *)begin { if(_token) return nil; _token=NSUUID.UUID.UUIDString; return _token; }
- (BOOL)isCurrent:(NSString *)token { return token && [_token isEqual:token]; }
- (BOOL)finish:(NSString *)token { if(![self isCurrent:token]) return NO; _token=nil; return YES; }
- (void)invalidate { _token=nil; }
+ (NSString *)validatePatch:(NSDictionary *)patch {
    if(![patch isKindOfClass:NSDictionary.class] || !patch.count) return @"Patch must not be empty";
    for(NSString *k in patch) if(![@[@"enabled",@"intervalMinutes"] containsObject:k]) return @"Unknown setting";
    id e=patch[@"enabled"], i=patch[@"intervalMinutes"];
    if(e && (![e isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)e)!=CFBooleanGetTypeID())) return @"enabled must be boolean";
    if(i && (![i isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)i)==CFBooleanGetTypeID() || !isfinite([i doubleValue]) || [i doubleValue]<1 || floor([i doubleValue])!=[i doubleValue])) return @"intervalMinutes must be a positive integer";
    return nil;
}
+ (BOOL)validWindow:(NSInteger)start days:(NSInteger)days { return start>=0 && days>=1 && start<=6 && days<=7-start; }
// Daily arrays are indexed by local wall-clock slots, not elapsed time across DST.
+ (NSDictionary *)indexedTimestamp:(NSUInteger)index date:(NSString *)day interval:(double)interval {
    double seconds = index * interval * 60.0;
    if (!isfinite(seconds) || seconds < 0 || seconds >= 86400) return @{};
    NSInteger offset = (NSInteger)llround(seconds);
    if (offset >= 86400) return @{};
    NSString *local = [NSString stringWithFormat:@"%@ %02ld:%02ld:%02ld", day, (long)(offset / 3600), (long)(offset / 60 % 60), (long)(offset % 60)];
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    calendar.timeZone = NSTimeZone.localTimeZone;
    NSDateFormatter *formatter = [self historyFormatter:calendar pattern:@"yyyy-MM-dd"];
    NSDate *base = [formatter dateFromString:day];
    if (!base) return @{};
    NSDate *sample = [calendar dateBySettingHour:offset / 3600 minute:offset / 60 % 60 second:offset % 60 ofDate:base options:NSCalendarMatchStrictly | NSCalendarMatchFirst];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    if (!sample || ![[formatter stringFromDate:sample] isEqual:local]) return @{};
    return @{@"timestamp":@(llround(sample.timeIntervalSince1970 * 1000)),
             @"utcOffsetMinutes":@([calendar.timeZone secondsFromGMTForDate:sample] / 60),
             @"timestampSource":@"reconstructed"};
}
// Fixed history cadence confirmed for the integrated wristband.
+ (double)historyIntervalForMetric:(NSString *)metric sdkInterval:(double)interval {
    if ([metric isEqual:@"hrv"]) return 30;
    if ([metric isEqual:@"stress"]) return 30;
    return interval;
}
+ (NSArray *)indexedValues:(NSArray *)values metric:(NSString *)metric date:(NSString *)date interval:(double)interval {
    NSMutableArray *records = [NSMutableArray new];
    NSString *unit = [metric isEqual:@"heartRate"] ? @"bpm" : [metric isEqual:@"bloodOxygen"] ? @"%" : @"vendor";
    double samplingInterval = [self historyIntervalForMetric:metric sdkInterval:interval];
    BOOL timed = isfinite(samplingInterval) && samplingInterval > 0;
    [values enumerateObjectsUsingBlock:^(id value, NSUInteger index, BOOL *stop) {
        if (![value isKindOfClass:NSNumber.class] || !isfinite([value doubleValue]) || [value doubleValue] <= 0) return;
        NSMutableDictionary *record = [@{@"metric":metric, @"date":date, @"source":@"scheduled", @"value":value, @"unit":unit, @"sampleIndex":@(index)} mutableCopy];
        if (timed) {
            record[@"intervalMinutes"] = @(samplingInterval);
            [record addEntriesFromDictionary:[self indexedTimestamp:index date:date interval:samplingInterval]];
        }
        [records addObject:record];
    }];
    return records;
}
+ (NSDictionary *)failedHistory:(NSArray *)jobs batches:(NSArray *)batches operation:(NSString *)operation device:(NSString *)device error:(NSDictionary *)error {
    NSMutableArray *all=[batches mutableCopy];for(NSUInteger i=all.count;i<jobs.count;i++)[all addObject:@{@"operationId":operation,@"deviceId":device,@"batchIndex":@(i),@"metric":jobs[i][@"metric"],@"date":jobs[i][@"date"],@"status":@"error",@"records":@[],@"error":error}];NSUInteger successes=0;for(NSDictionary *b in all)if([b[@"status"] isEqual:@"success"])successes++;return @{@"operationId":operation,@"deviceId":device,@"status":successes?@"partial":@"failed",@"batches":all};
}
+ (BOOL)verificationMatches:(NSDictionary *)patch actual:(NSDictionary *)actual { for(NSString *k in patch)if(![patch[k] isEqual:actual[k]])return NO;return YES; }
+ (NSInteger)dayIndex:(NSDate *)date today:(NSDate *)today calendar:(NSCalendar *)calendar {NSInteger index=[calendar components:NSCalendarUnitDay fromDate:[calendar startOfDayForDate:date] toDate:[calendar startOfDayForDate:today] options:0].day;return index>=0 && index<=6?index:NSNotFound;}

+ (NSDateFormatter *)historyFormatter:(NSCalendar *)calendar pattern:(NSString *)pattern {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.calendar = calendar;
    formatter.timeZone = calendar.timeZone;
    formatter.dateFormat = pattern;
    formatter.lenient = NO;
    return formatter;
}
+ (NSDate *)localDateTime:(NSString *)value calendar:(NSCalendar *)calendar {
    if (![value isKindOfClass:NSString.class]) return nil;
    NSDateFormatter *formatter = [self historyFormatter:calendar pattern:@"yyyy-MM-dd HH:mm:ss"];
    NSDate *date = [formatter dateFromString:value];
    return date && [[formatter stringFromDate:date] isEqual:value] ? date : nil;
}
+ (NSDictionary *)timestampFieldsForDate:(NSDate *)date expectedDate:(NSString *)expectedDate calendar:(NSCalendar *)calendar error:(NSDictionary **)error {
    NSDateFormatter *formatter = [self historyFormatter:calendar pattern:@"yyyy-MM-dd"];
    NSString *actual = date ? [formatter stringFromDate:date] : @"";
    if (!date || ![actual isEqual:expectedDate]) {
        if (error) *error = @{@"code":@"SDK_ERROR", @"message":@"SDK sample date does not match the requested day", @"requestedDate":expectedDate ?: @"", @"returnedDate":actual};
        return nil;
    }
    return @{@"timestamp":@(date.timeIntervalSince1970 * 1000),
             @"utcOffsetMinutes":@([calendar.timeZone secondsFromGMTForDate:date] / 60),
             @"timestampSource":@"sdk"};
}
+ (NSArray *)scheduledValues:(NSArray *)values metric:(NSString *)metric modelDate:(NSString *)modelDate expectedDate:(NSString *)expectedDate intervalSeconds:(double)intervalSeconds calendar:(NSCalendar *)calendar error:(NSDictionary **)error {
    if (![modelDate isKindOfClass:NSString.class] || ![modelDate isEqual:expectedDate]) {
        if (error) *error = @{@"code":@"SDK_ERROR", @"message":@"SDK history date does not match the requested day", @"requestedDate":expectedDate ?: @"", @"returnedDate":modelDate ?: @""};
        return nil;
    }
    NSDateFormatter *formatter = [self historyFormatter:calendar pattern:@"yyyy-MM-dd"];
    NSDate *base = [formatter dateFromString:modelDate];
    double samplingInterval = [self historyIntervalForMetric:metric sdkInterval:intervalSeconds / 60.0];
    if (!base || ![[formatter stringFromDate:base] isEqual:modelDate] || !isfinite(samplingInterval) || samplingInterval <= 0) {
        if (error) *error = @{@"code":@"SDK_ERROR", @"message":@"SDK history has an invalid date or sampling interval"};
        return nil;
    }
    NSMutableArray *records = [[self indexedValues:values metric:metric date:modelDate interval:samplingInterval] mutableCopy];
    return records;
}
// QCBloodOxygenModel.sourceType: 0=scheduled, 1=manual. Unknown sources are excluded.
+ (NSNumber *)scheduledOxygenValueForSource:(NSInteger)source maximum:(double)maximum minimum:(double)minimum value:(double)value {
    if (source != 0) return nil;
    double reading = maximum > 0 && minimum > 0 ? (maximum + minimum) / 2.0 : value;
    return isfinite(reading) && reading > 0 ? @(reading) : nil;
}
@end
