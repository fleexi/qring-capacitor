#import <Foundation/Foundation.h>
#import "WBPolicy.h"
int main(void) { @autoreleasepool {
    WBPolicy *gate=[WBPolicy new];
    NSString *a=[gate begin]; NSCAssert(a!=nil,@"first begins");
    NSCAssert([gate begin]==nil,@"busy");
    [gate invalidate]; NSString *b=[gate begin];
    NSCAssert(![gate finish:a],@"stale completion rejected");
    NSCAssert([gate isCurrent:b],@"new session intact");
    NSCAssert([gate finish:b] && ![gate finish:b],@"only completes once");
    NSCAssert([WBPolicy validatePatch:@{@"enabled":@NO}]==nil,@"false valid");
    NSCAssert([WBPolicy validatePatch:@{}]!=nil,@"empty invalid");
    NSCAssert([WBPolicy validatePatch:@{@"intervalMinutes":@2.5}]!=nil,@"fraction invalid");
    NSCAssert([WBPolicy validatePatch:@{@"enabled":@1}]!=nil,@"number is not boolean");
    NSCAssert([WBPolicy validWindow:0 days:7] && ![WBPolicy validWindow:1 days:7],@"window");
    NSArray *records=[WBPolicy indexedValues:@[@0,@60,@0,@72] metric:@"heartRate" date:@"2026-10-16" interval:5];
    NSCAssert(records.count==2 && [records[0][@"sampleIndex"] integerValue]==1 && records[0][@"timestamp"]==nil,@"keep missing slots without inventing time");
    NSArray *jobs=@[@{@"metric":@"heartRate",@"date":@"2026-10-16"},@{@"metric":@"hrv",@"date":@"2026-10-16"}];
    NSDictionary *summary=[WBPolicy failedHistory:jobs batches:@[@{@"status":@"success",@"records":@[@1]}] operation:@"op" device:@"dev" error:@{@"code":@"TIMEOUT"}];
    NSCAssert([summary[@"status"] isEqual:@"partial"] && [summary[@"batches"] count]==2 && [summary[@"batches"][0][@"records"] count]==1,@"retain successful batches on timeout");
    NSCAssert([WBPolicy verificationMatches:@{@"enabled":@NO} actual:@{@"enabled":@NO}],@"false read-back matches");
    NSCAssert(![WBPolicy verificationMatches:@{@"enabled":@NO} actual:@{@"enabled":@YES}],@"ACK is not proof of applied patch");
    NSCalendar *cal=[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];cal.timeZone=[NSTimeZone timeZoneWithName:@"Europe/Rome"];
    NSDateComponents *startParts=[NSDateComponents new];startParts.year=2026;startParts.month=10;startParts.day=24;
    NSDateComponents *endParts=[NSDateComponents new];endParts.year=2026;endParts.month=10;endParts.day=26;
    NSCAssert([WBPolicy dayIndex:[cal dateFromComponents:startParts] today:[cal dateFromComponents:endParts] calendar:cal]==2,@"calendar days survive DST");
    NSLog(@"Policy tests passed");
} return 0; }
