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
+ (NSArray *)indexedValues:(NSArray *)values metric:(NSString *)metric date:(NSString *)date interval:(double)interval {
    NSMutableArray *records=[NSMutableArray new];NSUInteger i=0;
    NSString *unit=[metric isEqual:@"heartRate"]?@"bpm":[metric isEqual:@"bloodOxygen"]?@"%":[metric isEqual:@"temperature"]?@"celsius":@"vendor";
    for(id v in values){if([v isKindOfClass:NSNumber.class] && isfinite([v doubleValue]) && [v doubleValue]>0){NSMutableDictionary *r=[@{@"metric":metric,@"date":date,@"source":@"scheduled",@"value":v,@"unit":unit,@"sampleIndex":@(i)} mutableCopy];if(interval>0)r[@"intervalMinutes"]=@(interval);[records addObject:r];}i++;}return records;
}
+ (NSDictionary *)failedHistory:(NSArray *)jobs batches:(NSArray *)batches operation:(NSString *)operation device:(NSString *)device error:(NSDictionary *)error {
    NSMutableArray *all=[batches mutableCopy];for(NSUInteger i=all.count;i<jobs.count;i++)[all addObject:@{@"operationId":operation,@"deviceId":device,@"batchIndex":@(i),@"metric":jobs[i][@"metric"],@"date":jobs[i][@"date"],@"status":@"error",@"records":@[],@"error":error}];NSUInteger successes=0;for(NSDictionary *b in all)if([b[@"status"] isEqual:@"success"])successes++;return @{@"operationId":operation,@"deviceId":device,@"status":successes?@"partial":@"failed",@"batches":all};
}
+ (BOOL)verificationMatches:(NSDictionary *)patch actual:(NSDictionary *)actual { for(NSString *k in patch)if(![patch[k] isEqual:actual[k]])return NO;return YES; }
+ (NSInteger)dayIndex:(NSDate *)date today:(NSDate *)today calendar:(NSCalendar *)calendar {NSInteger index=[calendar components:NSCalendarUnitDay fromDate:[calendar startOfDayForDate:date] toDate:[calendar startOfDayForDate:today] options:0].day;return index>=0 && index<=6?index:NSNotFound;}
@end
