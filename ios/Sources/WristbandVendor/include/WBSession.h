#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef void (^WBCompletion)(NSDictionary * _Nullable result, NSDictionary * _Nullable error);
typedef void (^WBEvent)(NSString *name, NSDictionary *data);
@interface WBSession : NSObject
@property(nonatomic,copy) WBEvent event;
- (void)invoke:(NSString *)method options:(NSDictionary *)options completion:(WBCompletion)completion;
- (void)background;
- (void)dispose;
@end
NS_ASSUME_NONNULL_END
