#import "WBSession.h"
#import "WBPolicy.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <QCBandSDK/QCBandSDK.h>
#import <UIKit/UIKit.h>
typedef void (^WBReply)(NSDictionary *, NSDictionary *);
@interface WBSession () <CBCentralManagerDelegate>
@property(nonatomic,strong) CBCentralManager *central;
@property(nonatomic,strong) CBPeripheral *peripheral;
@property(nonatomic,strong) NSMutableDictionary<NSString *,CBPeripheral *> *devices;
@property(nonatomic,strong) WBPolicy *gate;
@property(nonatomic,copy) NSString *kind;
@property(nonatomic,strong) CBPeripheral *retiringPeripheral;
@property(nonatomic,copy) NSDictionary *(^historyFailure)(NSDictionary *);
@property(nonatomic,copy) void (^historyNext)(NSUInteger);
@property(nonatomic,copy) NSString *connection;
@property(nonatomic,copy) NSString *commandId;
@property(nonatomic,assign) BOOL writeAcknowledged;
@property(nonatomic,copy) WBCompletion permissionRequest;
@property(nonatomic,copy) NSString *scanId;
@property(nonatomic,copy) WBCompletion pending;
@property(nonatomic,strong) NSDictionary *features;
@property(nonatomic,strong) NSDictionary *info;
@property(nonatomic,strong) NSMutableDictionary *settingsMetadata;
@property(nonatomic,copy) dispatch_block_t scanTimer;
@property(nonatomic,copy) dispatch_block_t watchdog;
- (NSDictionary *)state;

- (BOOL)requireReady:(WBCompletion)done;
- (BOOL)begin:(WBCompletion)done;
- (WBReply)once:(WBReply)done;
- (void)complete:(NSDictionary *)data error:(NSDictionary *)error;
- (void)emit:(NSString *)name data:(NSDictionary *)data;
- (void)close:(NSString *)reason;
- (void)stopScanning:(NSString *)reason;
@end
@interface WBSession (Adapters)
- (NSDictionary *)capabilities;
- (NSDictionary *)metricCapability:(NSString *)metric;
- (void)settings:(NSString *)metric patch:(NSDictionary *)patch done:(WBReply)done;
- (void)readSettings:(NSString *)metric done:(WBReply)done;
- (void)history:(NSArray<NSString *> *)metrics start:(NSInteger)start days:(NSInteger)days;
- (void)readDay:(NSString *)metric day:(NSInteger)day date:(NSString *)date done:(WBReply)done;
@end
FOUNDATION_EXPORT NSDictionary *WBError(NSString *code, NSString *message);
FOUNDATION_EXPORT NSArray<NSString *> *WBMetrics(void);
FOUNDATION_EXPORT double WBNow(void);
