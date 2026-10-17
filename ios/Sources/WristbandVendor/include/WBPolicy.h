#import <Foundation/Foundation.h>
@interface WBPolicy : NSObject
@property(nonatomic,copy,readonly) NSString *token;
- (NSString *)begin;
- (BOOL)isCurrent:(NSString *)token;
- (BOOL)finish:(NSString *)token;
- (void)invalidate;
+ (NSString *)validatePatch:(NSDictionary *)patch;
+ (BOOL)validWindow:(NSInteger)start days:(NSInteger)days;
+ (NSArray *)indexedValues:(NSArray *)values metric:(NSString *)metric date:(NSString *)date interval:(double)interval;
+ (NSDictionary *)failedHistory:(NSArray *)jobs batches:(NSArray *)batches operation:(NSString *)operation device:(NSString *)device error:(NSDictionary *)error;
+ (BOOL)verificationMatches:(NSDictionary *)patch actual:(NSDictionary *)actual;
+ (NSInteger)dayIndex:(NSDate *)date today:(NSDate *)today calendar:(NSCalendar *)calendar;
+ (NSArray *)scheduledValues:(NSArray *)values metric:(NSString *)metric modelDate:(NSString *)modelDate expectedDate:(NSString *)expectedDate intervalSeconds:(double)intervalSeconds calendar:(NSCalendar *)calendar error:(NSDictionary **)error;
+ (NSDictionary *)timestampFieldsForDate:(NSDate *)date expectedDate:(NSString *)expectedDate calendar:(NSCalendar *)calendar error:(NSDictionary **)error;
+ (NSDate *)localDateTime:(NSString *)value calendar:(NSCalendar *)calendar;
+ (NSNumber *)scheduledOxygenValueForSource:(NSInteger)source maximum:(double)maximum minimum:(double)minimum value:(double)value;
@end
