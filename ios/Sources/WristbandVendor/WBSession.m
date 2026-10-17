#import "WBSessionInternal.h"
NSDictionary *WBError(NSString *code, NSString *message) { return @{@"code":code,@"message":message}; }
NSArray *WBMetrics(void) { return @[@"heartRate",@"bloodOxygen",@"hrv",@"stress",@"steps",@"sleep"]; }
double WBNow(void) { return NSDate.date.timeIntervalSince1970*1000; }
@implementation WBSession
- (instancetype)init { if((self=[super init])) { _gate=[WBPolicy new]; _devices=[NSMutableDictionary new]; _connection=@"disconnected"; _features=@{}; _settingsMetadata=[NSMutableDictionary new]; } return self; }
- (void)emit:(NSString *)name data:(NSDictionary *)data { if(self.event) self.event(name,data); }
- (NSString *)bluetooth {
    if(CBManager.authorization==CBManagerAuthorizationDenied || CBManager.authorization==CBManagerAuthorizationRestricted) return @"unauthorized";
    if(!self.central) return @"unknown";
    switch(self.central.state) { case CBManagerStatePoweredOn:return @"on"; case CBManagerStatePoweredOff:return @"off"; case CBManagerStateUnsupported:return @"unsupported"; default:return @"unknown"; }
}
- (NSDictionary *)state {
    NSMutableDictionary *s=[@{@"bluetooth":[self bluetooth],@"connection":self.connection,@"scanning":@(self.scanId!=nil)} mutableCopy];
    if(self.peripheral) s[@"deviceId"]=self.peripheral.identifier.UUIDString;
    if(self.gate.token) s[@"operationId"]=self.gate.token;
    return s;
}
- (NSDictionary *)permissionState { return @{@"bluetooth": CBManager.authorization==CBManagerAuthorizationAllowedAlways?@"granted":CBManager.authorization==CBManagerAuthorizationNotDetermined?@"prompt":@"denied"}; }
- (BOOL)requireReady:(WBCompletion)done { if(!self.kind) {done(nil,WBError(@"NOT_INITIALIZED",@"Call initialize first"));return NO;} if(![self.connection isEqual:@"ready"]) {done(nil,WBError(@"NOT_CONNECTED",@"Device is not ready"));return NO;} return YES; }
- (BOOL)begin:(WBCompletion)done { if(![self.gate begin]) {done(nil,WBError(@"BUSY",@"Another operation is active"));return NO;} self.pending=done; self.writeAcknowledged=NO; return YES; }
- (WBReply)once:(WBReply)done {
    NSString *token=self.gate.token,*command=NSUUID.UUID.UUIDString; self.commandId=command;
    if(self.watchdog) dispatch_block_cancel(self.watchdog);
    __weak WBSession *weak=self;
    self.watchdog=dispatch_block_create(0, ^{ WBSession *s=weak; if([s.gate isCurrent:token] && [s.commandId isEqual:command]) { NSDictionary *failure=s.writeAcknowledged?@{@"code":@"WRITE_VERIFICATION_FAILED",@"message":@"Write acknowledged; read-back timed out",@"writeAcknowledged":@YES}:WBError(@"TIMEOUT",@"SDK response timed out");[s complete:nil error:failure]; [s close:@"timeout"]; } });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,30*NSEC_PER_SEC),dispatch_get_main_queue(),self.watchdog);
    return ^(NSDictionary *data, NSDictionary *error) { dispatch_async(dispatch_get_main_queue(), ^{ WBSession *s=weak; if(![s.gate isCurrent:token] || ![s.commandId isEqual:command]) return; s.commandId=nil; if(s.watchdog)dispatch_block_cancel(s.watchdog);s.watchdog=nil;done(data,error); }); };
}
- (void)complete:(NSDictionary *)data error:(NSDictionary *)error { if(error && self.historyFailure){data=self.historyFailure(error);error=nil;}self.historyFailure=nil; self.historyNext=nil; WBCompletion done=self.pending; self.pending=nil; [self.gate invalidate];self.commandId=nil;if(self.watchdog)dispatch_block_cancel(self.watchdog);self.watchdog=nil;if(done) done(data,error); }
- (void)close:(NSString *)reason {
    if(self.pending) [self complete:nil error:WBError(@"DISCONNECTED",reason)];
    if(self.peripheral && self.peripheral.state!=CBPeripheralStateDisconnected) self.retiringPeripheral=self.peripheral;
    if(self.peripheral) { [[QCSDKManager shareInstance] removePeripheral:self.peripheral]; [self.central cancelPeripheralConnection:self.peripheral]; }
    self.peripheral=nil;self.connection=@"disconnected";self.features=@{};self.info=nil;[self.settingsMetadata removeAllObjects];
    [self emit:@"connectionStateChanged" data:[self state]];
}
- (void)stopScanning:(NSString *)reason { if(!self.scanId)return;[self.central stopScan];self.scanId=nil;if(self.scanTimer)dispatch_block_cancel(self.scanTimer);self.scanTimer=nil;[self emit:@"scanStopped" data:@{@"reason":reason}]; }
- (void)invoke:(NSString *)method options:(NSDictionary *)o completion:(WBCompletion)done {
    if([method isEqual:@"checkPermissions"]) {done([self permissionState],nil);return;}
    if([method isEqual:@"requestPermissions"]) { if(!self.central) self.central=[[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:@{CBCentralManagerOptionShowPowerAlertKey:@NO}]; if(CBManager.authorization!=CBManagerAuthorizationNotDetermined)done([self permissionState],nil);else if(self.permissionRequest) done(nil,WBError(@"BUSY",@"Permission request already active"));else self.permissionRequest=done; return; }
    if([method isEqual:@"initialize"]) {
        NSString *kind=o[@"deviceKind"];if(![@[@"band",@"watch",@"ring"] containsObject:kind]){done(nil,WBError(@"INVALID_ARGUMENT",@"deviceKind must be band, watch or ring"));return;}
        if(self.gate.token || ![self.connection isEqual:@"disconnected"]) {done(nil,WBError(@"BUSY",@"Disconnect before initializing again"));return;}
        self.kind=kind;[QCSDKManager shareInstance].debug=[o[@"debug"] boolValue];
        if(!self.central)self.central=[[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:@{CBCentralManagerOptionShowPowerAlertKey:@NO}];done([self state],nil);return;
    }
    if(!self.kind){done(nil,WBError(@"NOT_INITIALIZED",@"Call initialize first"));return;}
    if([method isEqual:@"getState"]) {done([self state],nil);return;}
    if([method isEqual:@"getCapabilities"]) {done([self capabilities],nil);return;}
    if([method isEqual:@"stopScan"]) {[self stopScanning:@"requested"];done(@{},nil);return;}
    if([method isEqual:@"disconnect"] || [method isEqual:@"forgetDevice"]) { [self stopScanning:@"requested"];[self close:@"requested"];if([method isEqual:@"forgetDevice"]) { [NSUserDefaults.standardUserDefaults removeObjectForKey:@"WBLastDevice"];[NSUserDefaults.standardUserDefaults removeObjectForKey:@"WBLastKind"]; } done(@{},nil);return; }
    double timeout=o[@"timeoutMs"]?[o[@"timeoutMs"] doubleValue]:([method isEqual:@"startScan"]?15000:60000);
    if(o[@"timeoutMs"] && (![o[@"timeoutMs"] isKindOfClass:NSNumber.class] || !isfinite(timeout) || timeout<1000 || timeout>120000 || floor(timeout)!=timeout)) {done(nil,WBError(@"INVALID_ARGUMENT",@"timeoutMs must be an integer from 1000 to 120000"));return;}
    if([method isEqual:@"startScan"] || [method isEqual:@"connect"] || [method isEqual:@"reconnect"]) {
        if(![[self bluetooth] isEqual:@"on"]) {done(nil,WBError([[self bluetooth] isEqual:@"unauthorized"]?@"PERMISSION_DENIED":@"BLUETOOTH_OFF",@"Bluetooth unavailable"));return;}
        if(self.retiringPeripheral || self.gate.token || ![self.connection isEqual:@"disconnected"]) {done(nil,WBError(@"BUSY",@"Wait for disconnection before scanning or connecting"));return;}
        if([method isEqual:@"startScan"]) {
            [self stopScanning:@"requested"];[self.devices removeAllObjects];self.scanId=NSUUID.UUID.UUIDString;
            [self.central scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@NO}];
            __weak WBSession *weak=self;self.scanTimer=dispatch_block_create(0,^{[weak stopScanning:@"timeout"];});dispatch_after(dispatch_time(DISPATCH_TIME_NOW,timeout*NSEC_PER_MSEC),dispatch_get_main_queue(),self.scanTimer);done(@{},nil);return;
        }
        NSString *device=o[@"deviceId"];if([method isEqual:@"reconnect"]) { device=[NSUserDefaults.standardUserDefaults stringForKey:@"WBLastDevice"]; NSString *savedKind=[NSUserDefaults.standardUserDefaults stringForKey:@"WBLastKind"]; if(savedKind && ![savedKind isEqual:self.kind]) {done(nil,WBError(@"INVALID_ARGUMENT",@"Initialize with the saved deviceKind"));return;} }
        NSUUID *uuid=[device isKindOfClass:NSString.class]?[[NSUUID alloc] initWithUUIDString:device]:nil;
        if(!uuid){done(nil,WBError(@"DEVICE_NOT_FOUND",@"No valid device ID"));return;}
        CBPeripheral *p=self.devices[device] ?: [self.central retrievePeripheralsWithIdentifiers:@[uuid]].firstObject;
        if(!p){done(nil,WBError(@"DEVICE_NOT_FOUND",@"Scan for this device first"));return;}
        [self stopScanning:@"connecting"];[self begin:done];self.peripheral=p;self.connection=@"connecting";[self emit:@"connectionStateChanged" data:[self state]];
        NSString *token=self.gate.token;__weak WBSession *weak=self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,timeout*NSEC_PER_MSEC),dispatch_get_main_queue(),^{ WBSession *s=weak;if([s.gate isCurrent:token] && ![s.connection isEqual:@"ready"]) {[s complete:nil error:WBError(@"TIMEOUT",@"Connection initialization timed out")];[s close:@"timeout"];} });
        if(p.state==CBPeripheralStateConnected)[self centralManager:self.central didConnectPeripheral:p];else [self.central connectPeripheral:p options:@{CBConnectPeripheralOptionEnableTransportBridgingKey:@NO,CBConnectPeripheralOptionRequiresANCS:@(![self.kind isEqual:@"ring"])}];return;
    }
    if(![self requireReady:done])return;
    if([method isEqual:@"getDeviceInfo"]) {if(![self begin:done])return;WBReply reply=[self once:^(NSDictionary *d,NSDictionary *e){if(d)self.info=d;[self complete:d error:e];}];[QCSDKCmdCreator getDeviceSoftAndHardVersionSuccess:^(NSString *software,NSString *hardware){NSMutableDictionary *info=[self.info mutableCopy];info[@"firmware"]=software;info[@"hardware"]=hardware;reply(info,nil);} fail:^{reply(nil,WBError(@"SDK_ERROR",@"Device version read failed"));}];return;}
    if(![self begin:done])return;
    if([method isEqual:@"getBattery"]) { WBReply reply=[self once:^(NSDictionary *d,NSDictionary *e){[self complete:d error:e];}];[QCSDKCmdCreator readBatterySuccess:^(int n,BOOL charging){reply(@{@"level":@(n),@"charging":@(charging)},nil);} failed:^{reply(nil,WBError(@"SDK_ERROR",@"Battery read failed"));}];return; }
    NSString *m=o[@"metric"];
    if([method isEqual:@"syncHistory"] || [method isEqual:@"getHistory"]) {
        NSArray *metrics=[method isEqual:@"syncHistory"]?o[@"metrics"]:(m?@[m]:@[]);NSNumber *s=o[@"startDay"],*d=o[@"days"];
        if(![metrics isKindOfClass:NSArray.class] || !metrics.count || [NSSet setWithArray:metrics].count!=metrics.count || ![s isKindOfClass:NSNumber.class] || ![d isKindOfClass:NSNumber.class] || floor(s.doubleValue)!=s.doubleValue || floor(d.doubleValue)!=d.doubleValue || ![WBPolicy validWindow:s.integerValue days:d.integerValue]){[self complete:nil error:WBError(@"INVALID_ARGUMENT",@"Invalid metrics or seven-day window")];return;}
        for(id metric in metrics)if(![WBMetrics() containsObject:metric]){[self complete:nil error:WBError(@"INVALID_ARGUMENT",@"Unknown metric")];return;}
        [self history:metrics start:s.integerValue days:d.integerValue];return;
    }
    if(![WBMetrics() containsObject:m]){[self complete:nil error:WBError(@"INVALID_ARGUMENT",@"Unknown metric")];return;}
    if([method isEqual:@"getMeasurementSettings"] || [method isEqual:@"setMeasurementSettings"]) { if([method isEqual:@"setMeasurementSettings"] && !o[@"patch"]){[self complete:nil error:WBError(@"INVALID_ARGUMENT",@"Patch is required")];return;} [self settings:m patch:[method isEqual:@"setMeasurementSettings"]?o[@"patch"]:nil done:^(NSDictionary *d,NSDictionary *e){[self complete:d error:e];}];return; }
    [self complete:nil error:WBError(@"UNSUPPORTED",@"Unknown operation")];
}
- (void)centralManagerDidUpdateState:(CBCentralManager *)central { [self emit:@"bluetoothStateChanged" data:@{@"bluetooth":[self bluetooth]}];if(self.permissionRequest && CBManager.authorization!=CBManagerAuthorizationNotDetermined){WBCompletion done=self.permissionRequest;self.permissionRequest=nil;done([self permissionState],nil);}if(central.state!=CBManagerStatePoweredOn){[self stopScanning:@"bluetoothOff"];[self close:@"bluetoothOff"];} }
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)p advertisementData:(NSDictionary *)ad RSSI:(NSNumber *)RSSI {if(!self.scanId)return;self.devices[p.identifier.UUIDString]=p;[self emit:@"scanResult" data:@{@"deviceId":p.identifier.UUIDString,@"name":p.name?:@"",@"rssi":RSSI}];}
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)p {
    if(p!=self.peripheral || ![self.connection isEqual:@"connecting"])return;
    self.connection=@"initializing";[self emit:@"connectionStateChanged" data:[self state]];
    WBReply registered=[self once:^(NSDictionary *d,NSDictionary *e){ if(e){[self complete:nil error:e];[self close:@"initializationFailed"];return;} WBReply time=[self once:^(NSDictionary *features,NSDictionary *error){ if(error){[self complete:nil error:error];[self close:@"initializationFailed"];return;}self.features=features;self.connection=@"ready";self.info=@{@"deviceId":p.identifier.UUIDString,@"name":p.name?:@"",@"deviceKind":self.kind};[NSUserDefaults.standardUserDefaults setObject:p.identifier.UUIDString forKey:@"WBLastDevice"];[NSUserDefaults.standardUserDefaults setObject:self.kind forKey:@"WBLastKind"];[self complete:self.info error:nil];[self emit:@"connectionStateChanged" data:[self state]];}];[QCSDKCmdCreator setTime:NSDate.date success:^(NSDictionary *f){time(f,nil);} failed:^{time(nil,WBError(@"SDK_ERROR",@"Time synchronization failed"));}]; }];
    [[QCSDKManager shareInstance] addPeripheral:p finished:^(BOOL success){ registered(@{},success?nil:WBError(@"SDK_ERROR",@"SDK registration failed")); }];
}
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)p error:(NSError *)error {if(p==self.retiringPeripheral){self.retiringPeripheral=nil;return;}if(p!=self.peripheral)return;[self complete:nil error:WBError(@"SDK_ERROR",error.localizedDescription?:@"Connection failed")];[self close:@"connectionFailed"];}
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)p error:(NSError *)error {if(p==self.retiringPeripheral){self.retiringPeripheral=nil;return;}if(p==self.peripheral)[self close:@"linkLost"];}
- (void)background {[self stopScanning:@"requested"];}
- (void)dispose { self.event=nil;[self stopScanning:@"requested"];[self close:@"disposed"];self.central.delegate=nil;if(self.permissionRequest){self.permissionRequest(nil,WBError(@"CANCELLED",@"Plugin disposed"));self.permissionRequest=nil;} }
@end
