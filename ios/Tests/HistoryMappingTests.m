#import <Foundation/Foundation.h>
#import "WBPolicy.h"

static NSCalendar *calendar(void) {
    NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    cal.timeZone = [NSTimeZone timeZoneWithName:@"Europe/Rome"];
    return cal;
}

int main(void) { @autoreleasepool {
    NSCalendar *cal = calendar();
    NSDictionary *error = nil;
    NSArray *records = [WBPolicy scheduledValues:@[@0, @60, @0, @72]
        metric:@"heartRate" modelDate:@"2026-10-16" expectedDate:@"2026-10-16"
        intervalSeconds:60 calendar:cal error:&error];
    NSCAssert(error == nil && records.count == 2, @"Detailed samples retain only real values");
    NSCAssert([records[0][@"sampleIndex"] integerValue] == 1, @"Missing slots must not shift timestamps");
    // 2026-10-16 00:01 Europe/Rome = 2026-10-15 22:01 UTC.
    NSCAssert([records[0][@"timestamp"] longLongValue] == 1792101660000LL, @"Use model interval, not the configured interval");
    NSCAssert([records[0][@"intervalMinutes"] doubleValue] == 1, @"Convert seconds to minutes");
    NSCAssert([records[0][@"utcOffsetMinutes"] integerValue] == 120, @"Offset belongs to the sample date");
    NSCAssert([records[0][@"timestampSource"] isEqual:@"reconstructed"], @"Distinguish reconstructed instants");

    error = nil;
    NSCAssert([WBPolicy scheduledValues:@[@57] metric:@"heartRate" modelDate:@"2026-10-15"
        expectedDate:@"2026-10-16" intervalSeconds:300 calendar:cal error:&error] == nil,
        @"Yesterday must not be reported as today's successful batch");
    NSCAssert([error[@"returnedDate"] isEqual:@"2026-10-15"], @"Keep the actual SDK date in the error");
    error = nil;
    NSCAssert([WBPolicy scheduledValues:@[@57] metric:@"heartRate" modelDate:@"2026-10-16"
        expectedDate:@"2026-10-16" intervalSeconds:0 calendar:cal error:&error] == nil,
        @"No guessed interval");
    error = nil;
    NSCAssert([WBPolicy scheduledValues:@[@57] metric:@"heartRate" modelDate:@"2026-02-30"
        expectedDate:@"2026-02-30" intervalSeconds:60 calendar:cal error:&error] == nil,
        @"No normalization of invalid dates");

    // Preserve SDK payloads, including suspect future values: never silently trim at 'now'.
    NSMutableArray *fullDay = [NSMutableArray arrayWithCapacity:288];
    for (NSUInteger i = 0; i < 288; i++) [fullDay addObject:@57];
    error = nil;
    records = [WBPolicy scheduledValues:fullDay metric:@"heartRate" modelDate:@"2026-10-16"
        expectedDate:@"2026-10-16" intervalSeconds:300 calendar:cal error:&error];
    NSCAssert(records.count == 288 && [records.lastObject[@"sampleIndex"] integerValue] == 287,
        @"Do not mask suspect source data with an arbitrary current-time filter");
    // A mixed oxygen response must never leak manual or unidentified readings.
    NSCAssert([WBPolicy scheduledOxygenValueForSource:1 maximum:99 minimum:95 value:97] == nil,
        @"Exclude manual oxygen records even when their values are valid");
    NSCAssert([WBPolicy scheduledOxygenValueForSource:2 maximum:99 minimum:95 value:97] == nil,
        @"Only explicitly scheduled records belong to automatic history");
    NSCAssert([[WBPolicy scheduledOxygenValueForSource:0 maximum:99 minimum:95 value:0] doubleValue] == 97,
        @"Keep the existing average for automatic oxygen ranges");
    NSCAssert([[WBPolicy scheduledOxygenValueForSource:0 maximum:0 minimum:0 value:96] doubleValue] == 96,
        @"Keep automatic single-value oxygen samples");
    NSCAssert([WBPolicy scheduledOxygenValueForSource:0 maximum:0 minimum:0 value:0] == nil,
        @"Zero is not a measurement");
    NSLog(@"History mapping tests passed");
} return 0; }
