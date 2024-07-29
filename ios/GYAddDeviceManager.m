//
//  GYAddDeviceManager.m
//  ReedBattery
//
//  Created by 潘振权 on 2022/8/29.
//

#import "GYAddDeviceManager.h"
#import "GranwinAPKit.h"
#import "GWGCDTimer.h"
#import "NSArray+Tools.h"

#include <CommonCrypto/CommonCryptor.h>
#import<CommonCrypto/CommonDigest.h>
#import "GYDESHelper.h"

static NSString *bleServiceUUID = @"ff01";
static NSString *bleReadUUID = @"ff02";
static NSString *bleWriteUUID = @"ff03";

@interface GYAddDeviceManager()<CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, assign) GYBleOperation bleOperation;
@property (nonatomic, strong) CBPeripheral *curPeripheral;
@property (nonatomic, strong) CBPeripheralCategory *currentCategory;    ///< 当前配网

@property (nonatomic, copy) GWCallBack *setDeviceNetworkCallBack;
@property (nonatomic, copy) void(^blockOnNetworkCallBack)(GWDevice *device, NSError *err);    ///<
@property (nonatomic, strong) GWGCDTimer *timeoutTimer;

@property (nonatomic,copy) callBackParameter successBlock;
@property (nonatomic,copy) onFailedBlock failBlock;
@property (nonatomic,strong) NSMutableArray *dataSource;

@property (nonatomic, copy) NSString *configUrl;
@property (nonatomic,strong) NSString *ssid;
@property (nonatomic,strong) NSString *passprot;
@property (nonatomic, assign) NSInteger configuraWiFiRetryTime;
@property (nonatomic,assign) GYConnectWay connectWay;


@property (nonatomic, assign) int randomCount;   ///<   随机数
@property (nonatomic, strong) NSMutableData *sendData;    ///< 发送的数据
@property (nonatomic, assign) int recvCount;    ///< 接受包数量
@property (nonatomic, assign) Byte data1;    ///< 数据
@property (nonatomic, assign) Byte data2;    ///< 数据
@property (nonatomic,assign) int recvNumber; // 分包次数
@property (nonatomic,strong) NSString *bleNameStart; // 蓝牙名称开头匹配
//@property (nonatomic,strong) NSString *bleName; // 蓝牙名称

@property (nonatomic,copy) callBackParameter statusBlock; // 状态返回，1：连接成功；2：发送数据成功

@end

@implementation GYAddDeviceManager

+ (instancetype)shareManager {
    static GYAddDeviceManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[GYAddDeviceManager alloc] init];
        [manager initialize];
    });
    return manager;
}

- (void)initialize{
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    _needCBC = YES;
}

- (void)test {
    Byte first[] = {0xEE, 0x01, 0xF4, 0xDF, 0x4E, 0xCE, 0xB5, 0xC6, 0x03, 0xCC, 0xAE, 0x21, 0xA1, 0x5F, 0x33, 0xED, 0xAA, 0x05, 0x44, 0x80};
    Byte second[] = {0xEE, 0x02, 0x1A, 0x3E, 0xB8, 0x27, 0x1B, 0xA8, 0x47, 0xA3, 0x28, 0x38, 0x7E, 0xA4, 0xB6, 0x41, 0x3D, 0x27, 0x1E, 0x09};
    Byte thr[] = {0xEE, 0x03, 0xE3, 0xF3, 0x6A, 0x38, 0x6D, 0x2F, 0x6E, 0x1C, 0xAA, 0xA5, 0x3D, 0x74, 0x0F, 0x1B, 0x86, 0x0A};
    
    [self dealWithReceiveData:[NSData dataWithBytes:first length:20] peripheral:nil];
    [self dealWithReceiveData:[NSData dataWithBytes:second length:20] peripheral:nil];
    [self dealWithReceiveData:[NSData dataWithBytes:thr length:18] peripheral:nil];

}

- (GYBleAuthority)getupBleAuthority{
    NSInteger state = self.centralManager.state;
    if(state == CBManagerStatePoweredOn){
        return GYStatePoweredOn;
    }else if (state == CBManagerStatePoweredOff){
        return GYStatePoweredOff;
    }else if (state == CBManagerStateUnauthorized){
        return GYStateUnauthorized;
    }else{
        return GYStateUnsupported;
    }
    return  GYStatePoweredOn;
}

- (void)startBleConnect:(NSString *)bleStart success:(callBackParameter)successBlock failure:(onFailedBlock)failBlock{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self.dataSource removeAllObjects];
        self.successBlock = successBlock;
        self.failBlock = failBlock;
        self.bleNameStart = @"granwin-dev";
        [self startConnect];
    });
}

- (void)startConnect{
    switch (self.centralManager.state){
        case CBManagerStateUnknown: {
            _bleOperation = GYBleOperationScan;
        } break;
        case CBManagerStateResetting:{
            NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeBlePwoerOff userInfo:@{NSLocalizedDescriptionKey : @"设备目前不支持"}];
            if (_failBlock) {
                _failBlock(err);
            }
        }
            break;
        case CBManagerStateUnsupported:{
            NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeBlePwoerOff userInfo:@{NSLocalizedDescriptionKey : @"设备目前不支持"}];
            if (_failBlock) {
                _failBlock(err);
            }
        }
            break;
        case CBManagerStateUnauthorized:{
            NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeBlePwoerOff userInfo:@{NSLocalizedDescriptionKey : @"蓝牙未授权"}];
            if (_failBlock) {
                _failBlock(err);
            }
        }
        case CBManagerStatePoweredOff: {
            NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeBlePwoerOff userInfo:@{NSLocalizedDescriptionKey : @"蓝牙设备未开启"}];
            if (_failBlock) {
                _failBlock(err);
            }
        } break;
        case CBManagerStatePoweredOn: {
            _bleOperation = GYBleOperationScan;
            [self startScanBleDevice];
        }
            break;
    }
}

- (void)stopScanBle{
    if (self.timeoutTimer) {
        [self.timeoutTimer invalidate];
        _timeoutTimer = nil;
    }
    _bleOperation = GYBleOperationNone;
    if (self.centralManager.isScanning) {
        [self.centralManager stopScan];
    }
    if (self.curPeripheral) {
        [self.centralManager cancelPeripheralConnection:self.curPeripheral];
        _curPeripheral = nil;
    }
    
    _blockOnNetworkCallBack = nil;
    _successBlock = nil;
    _failBlock = nil;
}

- (void)clearDataSource {
    [self.dataSource removeAllObjects];
}

- (void)startScanBleDevice {
  [self.dataSource removeAllObjects];
    if (self.timeoutTimer) {
        [self.timeoutTimer invalidate];
    }
    __weak typeof(self) weakSelf = self;
    _timeoutTimer = [GWGCDTimer scheduledTimerWithTimeInterval:90 repeats:NO queue:dispatch_get_global_queue(0, 0) block:^{
        weakSelf.bleOperation = GYBleOperationNone;
        [weakSelf.centralManager stopScan];
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"扫描蓝牙设备超时"}];
        if (self->_failBlock) {
            self->_failBlock(err);
        }
    }];
    NSDictionary *option = @{CBCentralManagerScanOptionAllowDuplicatesKey: @YES, CBCentralManagerOptionShowPowerAlertKey:[NSNumber numberWithBool:YES]};

    [self.centralManager scanForPeripheralsWithServices:nil options:option];
}

- (void)reScanBleDevice {
    if (self.centralManager.isScanning) {
        [self.centralManager stopScan];
    }

    NSDictionary *option = @{CBCentralManagerScanOptionAllowDuplicatesKey: @YES, CBCentralManagerOptionShowPowerAlertKey:[NSNumber numberWithBool:YES]};
    [self.centralManager scanForPeripheralsWithServices:nil options:option];
}

//- (void)connectBleDevice:(CBPeripheral *)peripheral completion:(GWCallBack<GWDevice *> *)callBack{
//    _setDeviceNetworkCallBack = callBack;
//    self.curPeripheral = peripheral;
//    [self.centralManager stopScan];
//    _bleOperation = GYBleOperationConnecting;
//    self.connectWay = GYBleDirectlyConnected;
//    [self.timeoutTimer invalidate];
//    
//    __weak typeof(self) weakSelf = self;
//    _timeoutTimer = [GWGCDTimer scheduledTimerWithTimeInterval:90 repeats:NO queue:dispatch_get_global_queue(0, 0) block:^{
//        weakSelf.bleOperation = GYBleOperationNone;
//        [weakSelf.centralManager cancelPeripheralConnection:peripheral];
//        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备超时"}];
//        
//        if (weakSelf.setDeviceNetworkCallBack) {
//            weakSelf.setDeviceNetworkCallBack.onFailed(err);
//        }
//        if (weakSelf.blockOnNetworkCallBack) {
//            weakSelf.blockOnNetworkCallBack(nil, err);
//        }
//
//    }];
//    [self.centralManager connectPeripheral:peripheral options:nil];
//}

- (void)bleSetDeviceNetwork:(NSString *)wifiSSID
               wifiPassword:(NSString *)wifiPassword
                 peripheral:(CBPeripheralCategory *)peripheral
                  configURL:(NSString *)url
                  didFinish:(void(^)(GWDevice *device, NSError *error))callBack
                     status:(callBackParameter)statusBlock{
    self.configUrl = url;
    self.ssid = wifiSSID;
    self.passprot = wifiPassword;
    _blockOnNetworkCallBack = callBack;
    _currentCategory = peripheral;
    _curPeripheral = peripheral.peripheral;
    self.connectWay =GYBleNetConnect;
    _bleOperation = GYBleOperationConnecting;
    _statusBlock = statusBlock;
    [self.timeoutTimer invalidate];
    
    [self.timeoutTimer invalidate];
    __weak typeof(self) weakSelf = self;
    _timeoutTimer = [GWGCDTimer scheduledTimerWithTimeInterval:60 repeats:NO queue:dispatch_get_global_queue(0, 0) block:^{
        weakSelf.bleOperation = GYBleOperationNone;
        if(weakSelf.curPeripheral){
            [weakSelf.centralManager cancelPeripheralConnection:weakSelf.curPeripheral];
        }
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备超时"}];
        if (weakSelf.setDeviceNetworkCallBack) {
            weakSelf.setDeviceNetworkCallBack.onFailed(err);
        }
        if (weakSelf.blockOnNetworkCallBack) {
            weakSelf.blockOnNetworkCallBack(nil, err);
        }
    }];
    [self.centralManager connectPeripheral:_curPeripheral options:nil];
    
}

//- (void)bleSetDeviceNetwork:(NSString *)wifiSSID
//               wifiPassword:(NSString *)wifiPassword
//             peripheralName:(NSString *)peripheralName
//                  configURL:(NSString *)url
//                  didFinish:(GWCallBack <GWDevice *> *)callBack
//                     status:(callBackParameter)statusBlock{
//    self.configUrl = url;
//    self.ssid = wifiSSID;
//    self.passprot = wifiPassword;
//    _setDeviceNetworkCallBack = callBack;
////    _bleName = peripheralName;
//    self.connectWay =GYBleNetConnect;
//    _bleOperation = GYBleOperationConnecting;
//    _statusBlock = statusBlock;
//    [self.timeoutTimer invalidate];
//    __weak typeof(self) weakSelf = self;
//    _timeoutTimer = [GWGCDTimer scheduledTimerWithTimeInterval:90 repeats:NO queue:dispatch_get_global_queue(0, 0) block:^{
//        weakSelf.bleOperation = GYBleOperationNone;
//        if(weakSelf.curPeripheral){
//            [weakSelf.centralManager cancelPeripheralConnection:weakSelf.curPeripheral];
//        }
//        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备超时"}];
//        if (weakSelf.setDeviceNetworkCallBack) {
//            weakSelf.setDeviceNetworkCallBack.onFailed(err);
//        }
//        if (weakSelf.blockOnNetworkCallBack) {
//            weakSelf.blockOnNetworkCallBack(nil, err);
//        }
//
//    }];
//    [self startConnect];
//}

- (void)sendDataWith:(NSData *)data {
    NSLog(@"发送数据:%@", data);
    [self.curPeripheral writeValue:data forCharacteristic:[self getWriteChar] type:CBCharacteristicWriteWithResponse];
}

// 发现蓝牙设备
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"发现蓝牙设备：%@", peripheral.name);
    CBPeripheralCategory *peripheralCategory = [[CBPeripheralCategory alloc]initWithName:peripheral.name rssi:RSSI];
    peripheralCategory.discoverTime = [[NSDate new] timeIntervalSince1970];
    NSData *manufacturerData = [advertisementData objectForKey:@"kCBAdvDataManufacturerData"];
    
    BOOL remove = NO;
    /// mac后面的一个byte的bit1，如果不是1，不能被搜索到
//    if (manufacturerData.length > 10) {
//        NSData *showData = [manufacturerData subdataWithRange:NSMakeRange(manufacturerData.length - 2, 1)];
//        Byte isShow;
//        [showData getBytes:&isShow range:NSMakeRange(0, 1)];
//        int bit = (int) ((isShow >> 1) & 0x01);
//        if (bit == 0x00) {
//            remove = YES;
//        }
//        
//        NSData *pid = [manufacturerData subdataWithRange:NSMakeRange(3, 2)];
//        Byte b1, b2;
//        [pid getBytes:&b1 range:NSMakeRange(0, 1)];
//        [pid getBytes:&b2 range:NSMakeRange(1, 1)];
//        
//        if ((b1 != 0x19 || b2 != 0xd8) && !remove) {
//            return;
//        }
//    } else {
//        return;
//    }
    
    NSString *name = [peripheral.name lowercaseString];
    peripheralCategory.peripheral = peripheral;
    peripheralCategory.advertisementData = advertisementData;
    if (peripheral.name.length > 0) {
        if (_blockOnShowManufacturerData) {
            _blockOnShowManufacturerData([NSString stringWithFormat:@"%@", manufacturerData]);
        }
        static int macId = 1;
        macId ++;
        if (macId > 100000) {
            macId = 1;
        }
        peripheralCategory.peripheralId = [NSString stringWithFormat:@"%d", macId];
      NSLog(@"name:%@, advertisementData:%@", peripheral.name, advertisementData);
        if(self.bleNameStart.length > 0 && 
           [name hasPrefix:self.bleNameStart.lowercaseString]){
            
          if (![peripheralCategory getMacAddress].length) {
            return;
          }
          
            NSInteger index = -1;
            for (int i = 0; i<self.dataSource.count; i++) {
                CBPeripheralCategory *single = self.dataSource[i];
                if ([[peripheralCategory getMacAddress] isEqualToString:[single getMacAddress]]) {
                    single.peripheral = peripheral;
                    single.advertisementData = advertisementData;
                    single.peripheralId = [NSString stringWithFormat:@"%d", macId];
                    single.discoverTime = [[NSDate new] timeIntervalSince1970];
                    index = i;
                    break;
                }
            }
          
          [self.dataSource addObject:peripheralCategory];
            if (_successBlock) {
              _successBlock(@{@"name": peripheral.name ?: @"", @"mac": [peripheralCategory getMacAddress]});
            }
        }
    }
}

- (void)testShow {
    
    Byte bytes[] = {0x01, 0xF0, 0x02, 0x19, 0xD8, 0x00, 0x01, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x28, 0x9C, 0x6E, 0x7D, 0x26, 0x1A, 0x01, 0xD9};
    NSData *manufacturerData = [NSData dataWithBytes:bytes length:21];
    NSData *showData = [manufacturerData subdataWithRange:NSMakeRange(manufacturerData.length - 2, 1)];
    Byte isShow;
    [showData getBytes:&isShow range:NSMakeRange(0, 1)];
    int bit = (int) ((isShow >> 1) & 0x01);
    if (_blockOnShowManufacturerData) {
        _blockOnShowManufacturerData([NSString stringWithFormat:@"%@", manufacturerData]);
    }
    if (bit == 0) {
        return;
    }
}

// 蓝牙设备连接成功
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
  NSLog(@"连接失败：%@", error);
}

// 蓝牙设备连接失败
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"设备断开连接code = %ld,message = %@",error.code,error.localizedDescription);
    __weak __typeof(self) weakSelf = self;
    if (self.bleOperation == GYBleOperationConnecting ||
        self.bleOperation == GYBleOperationConnected) {
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备失败"}];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (weakSelf.setDeviceNetworkCallBack) {
                weakSelf.setDeviceNetworkCallBack.onFailed(err);
            }
            if (weakSelf.blockOnNetworkCallBack) {
                weakSelf.blockOnNetworkCallBack(nil, err);
            }
            [weakSelf stopScanBle];
        });
        
    }
}

- (void)centralManagerDidUpdateState:(nonnull CBCentralManager *)central { 
    
}


// 获取蓝牙服务
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    __weak __typeof(self) weakSelf = self;
    if (error) {
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备获取服务失败"}];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (weakSelf.setDeviceNetworkCallBack) {
                weakSelf.setDeviceNetworkCallBack.onFailed(err);
            }
            if (weakSelf.blockOnNetworkCallBack) {
                weakSelf.blockOnNetworkCallBack(nil, err);
            }
            [weakSelf stopScanBle];
        });
        NSLog(@"获取服务失败");
    } else {
        CBService *service = [peripheral.services objectOfObjectsPassingTest:^BOOL(CBService * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.UUID.UUIDString.lowercaseString containsString:bleServiceUUID];
        }];
        if (service) {
            NSLog(@"获取服务成功，获取特征值");
            [peripheral discoverCharacteristics:nil forService:service];
        } else {
            NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备获取服务失败"}];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (weakSelf.setDeviceNetworkCallBack) {
                    weakSelf.setDeviceNetworkCallBack.onFailed(err);
                }
                if (weakSelf.blockOnNetworkCallBack) {
                    weakSelf.blockOnNetworkCallBack(nil, err);
                }
                [weakSelf stopScanBle];
            });
            NSLog(@"获取服务失败");
        }
    }
}

// 获取蓝牙特征值
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备获取特征值失败"}];
        if (self.setDeviceNetworkCallBack) {
            self.setDeviceNetworkCallBack.onFailed(err);
        }
        if (self.blockOnNetworkCallBack) {
            self.blockOnNetworkCallBack(nil, err);
        }
        [self stopScanBle];
        NSLog(@"获取特征值失败");
    } else {
        CBCharacteristic *writeChar = [service.characteristics objectOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.UUID.UUIDString.lowercaseString containsString:bleWriteUUID];
        }];
        CBCharacteristic *readChar = [service.characteristics objectOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.UUID.UUIDString.lowercaseString containsString:bleReadUUID];
        }];
        
        if (!writeChar || !readChar) {
            NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备获取特征值失败"}];
            if (self.setDeviceNetworkCallBack) {
                self.setDeviceNetworkCallBack.onFailed(err);
            }
            if (self.blockOnNetworkCallBack) {
                self.blockOnNetworkCallBack(nil, err);
            }

            [self stopScanBle];
            NSLog(@"获取特征值失败");
        } else {
            NSLog(@"获取特征值成功");
            [peripheral setNotifyValue:YES forCharacteristic:readChar];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (characteristic.isNotifying) {
        NSLog(@"%@:打开通知成功", characteristic.UUID.UUIDString);
        if (_statusBlock) {
            _statusBlock(@(1));
        }
        if (self.timeoutTimer) {
            [self.timeoutTimer invalidate];
        }
        if (self.connectWay == GYBleDirectlyConnected) {
        }else{
            [self sendConfigureWifiData];
            _configuraWiFiRetryTime = 60;
            __weak typeof(self) weakSelf = self;
            _timeoutTimer = [GWGCDTimer scheduledTimerWithTimeInterval:1 repeats:YES queue:dispatch_get_global_queue(0, 0) block:^{
                weakSelf.configuraWiFiRetryTime --;
                if (weakSelf.configuraWiFiRetryTime <= 0) {
                    [weakSelf.timeoutTimer invalidate];
                    NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeConfigureWiFiFailed userInfo:@{NSLocalizedDescriptionKey : @"蓝牙发送数据配置WiFi无响应，失败"}];
                    if (weakSelf.setDeviceNetworkCallBack) {
                        weakSelf.setDeviceNetworkCallBack.onFailed(err);
                    }
                    if (weakSelf.blockOnNetworkCallBack) {
                        weakSelf.blockOnNetworkCallBack(nil, err);
                    }

                    [weakSelf stopScanBle];
                }
            }];
        }
    } else {
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备打开通知失败"}];
        if (self.setDeviceNetworkCallBack) {
            self.setDeviceNetworkCallBack.onFailed(err);
        }
        if (self.blockOnNetworkCallBack) {
            self.blockOnNetworkCallBack(nil, err);
        }

        [self stopScanBle];
        NSLog(@"打开通知失败");
    }
}

// 写入回调
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error{
    if (error) {
        NSLog(@"error Discovered characteristics for %@ with error: %@", characteristic.UUID, [error localizedDescription]);
    }
    NSLog(@"特征值变化：%@", characteristic.value);
}

// 指定特征值变化
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error {
    if (error) {
        NSLog(@"error Discovered characteristics for %@ with error: %@", characteristic.UUID, [error localizedDescription]);
    }
    NSLog(@"指定特征值变化：%@", characteristic.value);
    NSData *data = characteristic.value;
    
    [self dealWithReceiveData:data peripheral:peripheral];
}

- (void)dealWithReceiveData:(NSData *)data peripheral:(CBPeripheral *)peripheral  {
    if (data) {
        static NSMutableData *recvData;
        if (!recvData) {
            recvData = [NSMutableData data];
        }
        
        Byte count = 0x00;
        Byte dataId = 0x00;
        if (data.length > 2) {
            [data getBytes:&count range:NSMakeRange(1, 1)];
            char numbytes[] = {0x00,count};
            unsigned char by1 = (numbytes[0] &0xff);//高8位
            unsigned char by3 = numbytes[1] &0xff; // 低八位
            int serial = (by3 | by1 << 8);
            self.recvNumber = serial;
            
            if (serial == 1) {
                [data getBytes:&dataId range:NSMakeRange(2, 1)];
                
                char length[] = {0x00,dataId};
                unsigned char len1 = (length[0] &0xff);//高8位
                unsigned char len2 = length[1] &0xff; // 低八位
                int leng = (len2 | len1 << 8);
                self.recvCount = leng;
                
                [recvData appendData:[data subdataWithRange:NSMakeRange(2, data.length - 2)]];
            }else{
                [recvData appendData:[data subdataWithRange:NSMakeRange(2, data.length - 2)]];
            }
        }
        
        NSInteger number = data.length;
        if (number < 20) {
            
            NSDictionary *recvDic = [self decodeReceiveData:recvData];
            if(!self.needCBC){
                NSError *err;
                recvDic = [NSJSONSerialization JSONObjectWithData:recvData options:NSJSONReadingFragmentsAllowed error:&err];
            }
            if ([recvDic[@"CID"] integerValue] == 30006) {
                _bleOperation = GYBleOperationNone;
                _curPeripheral = nil;
                _configuraWiFiRetryTime = -1;
                [self.timeoutTimer invalidate];
                [self.centralManager cancelPeripheralConnection:peripheral];
                GWDevice *device = [[GWDevice alloc] initWithDictionary:recvDic];
                if (_statusBlock) {
                    _statusBlock(@(2));
                }
                if (self.setDeviceNetworkCallBack) {
                    self.setDeviceNetworkCallBack.onSuccess(device);
                }
                if (self.blockOnNetworkCallBack) {
                    self.blockOnNetworkCallBack(device, nil);
                }
            }
            recvData = nil;
        }
    }
}

#pragma mark - privary

- (void)sendWifiData{
    CBCharacteristic *writeChar = [self getWriteChar];
    if (!writeChar) {
        return;
    }
    NSDictionary *sendDataDic = @{
        @"CID" : @(30005),
        @"URL" : self.configUrl,
        @"PL" : @{
            @"SSID": self.ssid,
            @"Password":self.passprot
        },
    };
    [self resetNewRandomCount];
  NSLog(@"发送配网原始数据：%@", sendDataDic);
    //    随机数异或mac倒数第二位得到偏移量
    Byte data1 = self.data1;
    NSData *macData =  [self getMacAddress];
    Byte macByte;
    [macData getBytes:&macByte range:NSMakeRange(macData.length - 2, 1)];
    Byte idByte = (Byte) (data1 ^ macByte);
    NSString *excursion = [self toHexString:&idByte size:1];
    NSInteger random = [GYDESHelper convertHexToDecimal:excursion];
    
    NSMutableData *sendData = [NSJSONSerialization dataWithJSONObject:sendDataDic options:0 error:nil].mutableCopy;
    self.sendData = sendData;
        NSString *policyStr = [[NSString alloc] initWithData:sendData encoding:NSUTF8StringEncoding];
        policyStr = [policyStr stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
        
        NSData *lastData = [policyStr dataUsingEncoding:NSUTF8StringEncoding];
        if(self.needCBC){
          Byte byte[] = {0xE2, 0x67, 0x57, 0x84, 0x3F, 0x42, 0x3B, 0x58, 0xB0, 0xF1, 0xBC, 0xC2, 0x7B, 0xE4, 0xD1, 0x2A, 0x13, 0x64, 0xC3, 0xDB, 0xBD, 0xB0, 0xC6, 0x18, 0x8A, 0xED, 0x73, 0xBB, 0x3D, 0x98, 0x43, 0x92, 0xB0, 0xB3, 0x8C, 0x30, 0xB6, 0x9C, 0x11, 0xA1, 0xB7, 0x45, 0x89, 0xCF, 0x11, 0x17, 0x2F, 0xD3, 0x46, 0xB1, 0xB6, 0x8D, 0xE2, 0x04, 0x5D, 0x6A, 0x69, 0x18, 0xE2, 0x02, 0x32, 0x59, 0xB0, 0xA1, 0x33, 0xB2, 0xB6, 0x91, 0xC9, 0xAA, 0xB4, 0x9E, 0x9E, 0x71, 0xAF, 0x3A, 0x5E, 0xD0, 0xEF, 0xFE, 0x58, 0x93, 0x38, 0x1B, 0xA1, 0xFE, 0x11, 0x30, 0x6C, 0x6D, 0xE6, 0x07, 0x86, 0x93, 0x6D, 0x82, 0x0C, 0x36, 0x24, 0x00, 0x3D, 0x00, 0x29, 0xDB, 0x81, 0xD2, 0x77, 0xEF, 0x2A, 0xC9, 0x23, 0xF4, 0x50, 0x85, 0x55, 0x07, 0x92, 0x37, 0x18, 0x7C, 0xC7, 0xA5, 0x5F, 0x0B, 0xE7, 0xA1, 0x5F, 0x95, 0xC0, 0x8D, 0x23, 0x03, 0x81, 0x7E, 0x2D, 0x52, 0x32, 0xFE, 0x72, 0xB7, 0xDE, 0x01, 0xA3, 0x49, 0x79, 0x4B, 0x04, 0xB5, 0xB3, 0xC4, 0xC3, 0xC8, 0xB0, 0x71, 0x90, 0x2C, 0x6E, 0xB5, 0x0F, 0x4C, 0x13, 0x18, 0xE7, 0xBE, 0x68, 0xA1, 0x83, 0xAF, 0x2F, 0xC2, 0xBA, 0x40, 0x9C, 0x58, 0x25, 0x1A, 0x50, 0x35, 0x5A, 0xA5, 0x4E, 0xE4, 0x77, 0xF0, 0xFD, 0x90, 0xC0, 0x43, 0x6D, 0x0E, 0x26, 0x91, 0x8B, 0xBB, 0x65, 0xFA, 0xB3, 0xBF, 0x44, 0xD9, 0x2E, 0xA5, 0x78, 0xC6, 0x34, 0xAF, 0x6A, 0x5F, 0x03, 0x63, 0x4E, 0x10, 0xE2, 0xF8, 0xD9, 0x95, 0xE6, 0x83, 0x01, 0xCB, 0x39, 0x0B, 0x31, 0xD8, 0x5C, 0xF2, 0x83, 0xBD, 0x35, 0x4C, 0x5D, 0x98, 0x21, 0x12, 0x8A, 0x9C, 0xF6, 0x01, 0xE3, 0x51, 0xA7, 0x14, 0x13, 0xD1, 0xFD, 0xF3, 0x41, 0x68, 0x50, 0x02, 0x03, 0x94, 0x81, 0xA7, 0x72, 0xBB};
        NSData *privaryData = [[NSData alloc] initWithBytes:byte length:256];
        
        NSMutableData *encryptData = [NSMutableData data];
        //     拼接随机数
        [encryptData appendBytes:&data1 length:1];
        
        // 计算随机数到最后一位数的长度
        NSInteger remain = privaryData.length - random;
        NSInteger sendDataLength = lastData.length;
        //  判断加密数据长度与剩余长度的大小
        if(sendDataLength < remain){
            for (NSInteger i = 0; i<lastData.length; i++) {
                NSInteger j = random+i;
                Byte by1;
                [lastData getBytes:&by1 range:NSMakeRange(i, 1)];
                
                Byte b = (Byte) ((byte[j]) ^ by1);
                [encryptData appendBytes:&b length:1];
            }
        }else{
            //         加密数据长度大于剩余长度
            NSInteger remainSendLenth = sendDataLength - remain;
            NSInteger remainder = remainSendLenth % privaryData.length; // 取余
            NSInteger divisor = remainSendLenth / privaryData.length; // 除数
            
            for (NSInteger i = 0; i<remain; i++) {
                NSInteger j = random+i;
                Byte by1;
                [lastData getBytes:&by1 range:NSMakeRange(i, 1)];
                Byte b = (Byte) ((byte[j]) ^ by1);
                [encryptData appendBytes:&b length:1];
            }
            NSInteger beginning = remain; // 初始值
            for (int i = 0; i<divisor; i++) {
                for (int j = 0; i<privaryData.length; j++) {
                    NSInteger z = beginning + i*privaryData.length+j;
                    Byte by1;
                    [lastData getBytes:&by1 range:NSMakeRange(z, 1)];
                    Byte b = (Byte) ((byte[j]) ^ by1);
                    [encryptData appendBytes:&b length:1];
                }
            }
            NSInteger begin = remain + divisor*privaryData.length;
            NSInteger surplus = sendDataLength - begin;
            for (int i = 0; i<surplus; i++) {
                NSInteger j = begin + i;
                Byte by1;
                [lastData getBytes:&by1 range:NSMakeRange(j, 1)];
                Byte b = (Byte) ((byte[i]) ^ by1);
                [encryptData appendBytes:&b length:1];
            }
        }
            NSString *tips = [NSString stringWithFormat:@"mac:%@\n, random:%ld\n原始数据:%@,加密数据：%@",[self getMacAddress], (long)random, sendDataDic, encryptData];
            if (_blockOnSendTips) {
                _blockOnSendTips(tips);
            }
        self.sendData = encryptData;
        [self sendData:self.sendData];
        }else{
            [self sendData:lastData.mutableCopy];
        }
}

- (void)sendConfigureWifiData{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self sendWifiData];
    });
}

- (NSInteger)resetNewRandomCount {
    NSInteger random = arc4random()%50;
    NSString *dataId = [self ToHex:random];
    NSData *da = [self convertHexStrToData:dataId];
    self.data1 = 0x00;
    if (da.length == 1) {
        Byte by;
        [da getBytes:&by length:1];
        self.data1 = by;
    } else if (da.length == 2) {
        Byte by1, by2;
        [da getBytes:&by1 range:NSMakeRange(0, 1)];
        [da getBytes:&by2 range:NSMakeRange(1, 1)];
        self.data1 = by1;
    }
    return random;
}

- (CBCharacteristic *)getWriteChar {
    CBService *service = [self.curPeripheral.services objectOfObjectsPassingTest:^BOOL(CBService * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [obj.UUID.UUIDString.lowercaseString containsString:bleServiceUUID];
    }];
    if (service) {
        CBCharacteristic *writeChar = [service.characteristics objectOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.UUID.UUIDString.lowercaseString containsString:bleWriteUUID];
        }];
        return writeChar;
    }
    return nil;
}

- (NSData *)getMacAddress {    
    CBPeripheralCategory *category = nil;
    for (CBPeripheralCategory *peripheral in self.dataSource) {
        if([self.currentCategory.peripheralId isEqual:peripheral.peripheralId]) {
            category = peripheral;
            break;
        }
    }
    if(category != nil){
        NSDictionary *advDataManuData = category.advertisementData;
        NSData *date = [advDataManuData objectForKey:@"kCBAdvDataManufacturerData"];
        if(date.length > 20){
            return [date subdataWithRange:NSMakeRange(date.length - 8, 6)];
        }
        return nil;
    }
    return nil;
}

- (NSString *)ToHex:(NSInteger)tmpid {
    NSString *nLetterValue;
    NSString *str =@"";
    int ttmpig;
    for (int i =0; i<9; i++) {
        ttmpig=tmpid%16;
        tmpid=tmpid/16;
        switch (ttmpig)
        {
            case 10:
                nLetterValue =@"A";break;
            case 11:
                nLetterValue =@"B";break;
            case 12:
                nLetterValue =@"C";break;
            case 13:
                nLetterValue =@"D";break;
            case 14:
                nLetterValue =@"E";break;
            case 15:
                nLetterValue =@"F";break;
            default:nLetterValue=[[NSString alloc]initWithFormat:@"%lli",ttmpig];
                
        }
        str = [nLetterValue stringByAppendingString:str];
        if (tmpid == 0) {
            break;
        }
        
    }
    return str;
}

- (NSString *)toHexString:(Byte*)byte size:(NSInteger)size {
    NSMutableArray* tempArray = [NSMutableArray arrayWithCapacity:size];
    
    for(int i =0;i<size;i++){
        NSString* newHexStr = [NSString stringWithFormat:@"%x",byte[i]&0xff];
        if(newHexStr.length < 2){
            newHexStr = [@"0" stringByAppendingString:newHexStr];
        }
        [tempArray addObject:newHexStr];
    }
    return [tempArray componentsJoinedByString:@""];
}

//将16进制的字符串转换成NSData
- (NSMutableData *)convertHexStrToData:(NSString *)str {
    if (!str || [str length] == 0) {
        return nil;
    }
    
    NSMutableData *hexData = [[NSMutableData alloc] initWithCapacity:8];
    NSRange range;
    if ([str length] %2 == 0) {
        range = NSMakeRange(0,2);
    } else {
        range = NSMakeRange(0,1);
    }
    for (NSInteger i = range.location; i < [str length]; i += 2) {
        unsigned int anInt;
        NSString *hexCharStr = [str substringWithRange:range];
        NSScanner *scanner = [[NSScanner alloc] initWithString:hexCharStr];
        
        [scanner scanHexInt:&anInt];
        NSData *entity = [[NSData alloc] initWithBytes:&anInt length:1];
        [hexData appendData:entity];
        
        range.location += range.length;
        range.length = 2;
    }
    
    return hexData;
}

- (void)sendData:(NSMutableData *)sendData {
    NSInteger count = sendData.length / 18;
    if (sendData.length % 18 >= 0) {
        count ++;
    }
    
    int delay = 1;
    for (int i = 0; i < count; i ++) {
        NSMutableData *data = [NSMutableData data];
        
        Byte data1 = self.data1;
        
        [data appendBytes:&data1 length:1];
        NSString *dataId = [self ToHex:i + 1];
        NSData *da = [self convertHexStrToData:dataId];
        Byte b3;
        [da getBytes:&b3 length:1];
        [data appendBytes:&b3 length:1];
        //
        if (sendData.length > 18) {
            ////            data = [NSMutableData dataWithData:[sendData subdataWithRange:NSMakeRange(0, 17)]];
            for (int j = 0; j < 18; j ++) {
                Byte bytes;
                [sendData getBytes:&bytes range:NSMakeRange(j, 1)];
                [data appendBytes:&bytes length:1];
            }
            [sendData replaceBytesInRange:NSMakeRange(0, 18) withBytes:nil length:0];
        } else {
            for (int j = 0; j < sendData.length; j ++) {
                Byte bytes;
                [sendData getBytes:&bytes range:NSMakeRange(j, 1)];
                [data appendBytes:&bytes length:1];
            }
            sendData = nil;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self sendDataWith:data];
        });
        delay ++;
    }
}

- (NSDictionary *)decodeReceiveData:(NSData *)receiveData{
  Byte byte[] = {0xE2, 0x67, 0x57, 0x84, 0x3F, 0x42, 0x3B, 0x58, 0xB0, 0xF1, 0xBC, 0xC2, 0x7B, 0xE4, 0xD1, 0x2A, 0x13, 0x64, 0xC3, 0xDB, 0xBD, 0xB0, 0xC6, 0x18, 0x8A, 0xED, 0x73, 0xBB, 0x3D, 0x98, 0x43, 0x92, 0xB0, 0xB3, 0x8C, 0x30, 0xB6, 0x9C, 0x11, 0xA1, 0xB7, 0x45, 0x89, 0xCF, 0x11, 0x17, 0x2F, 0xD3, 0x46, 0xB1, 0xB6, 0x8D, 0xE2, 0x04, 0x5D, 0x6A, 0x69, 0x18, 0xE2, 0x02, 0x32, 0x59, 0xB0, 0xA1, 0x33, 0xB2, 0xB6, 0x91, 0xC9, 0xAA, 0xB4, 0x9E, 0x9E, 0x71, 0xAF, 0x3A, 0x5E, 0xD0, 0xEF, 0xFE, 0x58, 0x93, 0x38, 0x1B, 0xA1, 0xFE, 0x11, 0x30, 0x6C, 0x6D, 0xE6, 0x07, 0x86, 0x93, 0x6D, 0x82, 0x0C, 0x36, 0x24, 0x00, 0x3D, 0x00, 0x29, 0xDB, 0x81, 0xD2, 0x77, 0xEF, 0x2A, 0xC9, 0x23, 0xF4, 0x50, 0x85, 0x55, 0x07, 0x92, 0x37, 0x18, 0x7C, 0xC7, 0xA5, 0x5F, 0x0B, 0xE7, 0xA1, 0x5F, 0x95, 0xC0, 0x8D, 0x23, 0x03, 0x81, 0x7E, 0x2D, 0x52, 0x32, 0xFE, 0x72, 0xB7, 0xDE, 0x01, 0xA3, 0x49, 0x79, 0x4B, 0x04, 0xB5, 0xB3, 0xC4, 0xC3, 0xC8, 0xB0, 0x71, 0x90, 0x2C, 0x6E, 0xB5, 0x0F, 0x4C, 0x13, 0x18, 0xE7, 0xBE, 0x68, 0xA1, 0x83, 0xAF, 0x2F, 0xC2, 0xBA, 0x40, 0x9C, 0x58, 0x25, 0x1A, 0x50, 0x35, 0x5A, 0xA5, 0x4E, 0xE4, 0x77, 0xF0, 0xFD, 0x90, 0xC0, 0x43, 0x6D, 0x0E, 0x26, 0x91, 0x8B, 0xBB, 0x65, 0xFA, 0xB3, 0xBF, 0x44, 0xD9, 0x2E, 0xA5, 0x78, 0xC6, 0x34, 0xAF, 0x6A, 0x5F, 0x03, 0x63, 0x4E, 0x10, 0xE2, 0xF8, 0xD9, 0x95, 0xE6, 0x83, 0x01, 0xCB, 0x39, 0x0B, 0x31, 0xD8, 0x5C, 0xF2, 0x83, 0xBD, 0x35, 0x4C, 0x5D, 0x98, 0x21, 0x12, 0x8A, 0x9C, 0xF6, 0x01, 0xE3, 0x51, 0xA7, 0x14, 0x13, 0xD1, 0xFD, 0xF3, 0x41, 0x68, 0x50, 0x02, 0x03, 0x94, 0x81, 0xA7, 0x72, 0xBB};
    NSData *privaryData = [[NSData alloc] initWithBytes:byte length:256];
    
    //   取随机数
    Byte by;
    [receiveData getBytes:&by range:NSMakeRange(0, 1)];
    //   计算偏移量
    NSData *macData =  [self getMacAddress];
    Byte macByte;
    [macData getBytes:&macByte range:NSMakeRange(macData.length - 2, 1)];
    Byte idByte = (Byte) (by ^ macByte);
    
    NSString *excursion = [self toHexString:&idByte size:1];
    NSInteger random = [GYDESHelper convertHexToDecimal:excursion];
    
    //    待解密数据
    NSRange range = NSMakeRange(1, receiveData.length - 1);
    NSData *decodeData = [receiveData subdataWithRange:range];
    
    NSMutableData *encryptData = [NSMutableData data];
    // 计算随机数到最后一位数的长度
    NSInteger remain = privaryData.length - random;
    NSInteger sendDataLength = decodeData.length;
    //  判断加密数据长度与剩余长度的大小
    if(sendDataLength < remain){
        for (NSInteger i = 0; i<decodeData.length; i++) {
            NSInteger j = random+i;
            Byte by1;
            [decodeData getBytes:&by1 range:NSMakeRange(i, 1)];
            
            Byte b = (Byte) ((byte[j]) ^ by1);
            [encryptData appendBytes:&b length:1];
        }
    }else{
        //         加密数据长度大于剩余长度
        NSInteger remainSendLenth = sendDataLength - remain;
        NSInteger remainder = remainSendLenth % privaryData.length; // 取余
        NSInteger divisor = remainSendLenth / privaryData.length; // 除数
        
        for (NSInteger i = 0; i<remain; i++) {
            NSInteger j = random+i;
            Byte by1;
            [decodeData getBytes:&by1 range:NSMakeRange(i, 1)];
            Byte b = (Byte) ((byte[j]) ^ by1);
            [encryptData appendBytes:&b length:1];
        }
        NSInteger beginning = remain; // 初始值
        for (int i = 0; i<divisor; i++) {
            for (int j = 0; j<privaryData.length; j++) {
                NSInteger z = beginning + i*privaryData.length+j;
                Byte by1;
                [decodeData getBytes:&by1 range:NSMakeRange(z, 1)];
                Byte b = (Byte) ((byte[j]) ^ by1);
                [encryptData appendBytes:&b length:1];
            }
        }
        NSInteger begin = remain + divisor*privaryData.length;
        NSInteger surplus = sendDataLength - begin;
        for (int i = 0; i<surplus; i++) {
            NSInteger j = begin + i;
            Byte by1;
            [decodeData getBytes:&by1 range:NSMakeRange(j, 1)];
            Byte b = (Byte) ((byte[i]) ^ by1);
            [encryptData appendBytes:&b length:1];
        }
    }
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:encryptData options:NSJSONReadingFragmentsAllowed error:&err];
    NSLog(@"蓝牙接收数据:%@------%@", receiveData,encryptData);
    NSLog(@"数据解析:%@", dic);
    
    return dic;
}

- (CBPeripheralCategory *)categoryWithMac:(NSString *)mac {
  return [self.dataSource objectOfObjectsPassingTest:^BOOL(CBPeripheralCategory * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
    return [mac isEqualToString:[obj getMacAddress]];
  }];
}

- (NSMutableArray *)dataSource{
    if (!_dataSource) {
        _dataSource = [NSMutableArray array];
    }
    return _dataSource;
}
@end

