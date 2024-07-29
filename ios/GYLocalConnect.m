//
//  GYLocalConnect.m
//  ReedBattery
//
//  Created by 潘振权 on 2022/9/13.
//

#import "GYLocalConnect.h"
#import "GranwinAPKit.h"
#import "NSArray+Tools.h"
#import "GWGCDTimer.h"
#import "GYDESHelper.h"
#import "GYAddDeviceManager.h"

static NSString *bleServiceUUID = @"ee01";
static NSString *bleReadUUID = @"ee02";
static NSString *bleWriteUUID = @"ee03";

static NSString *bleQueryServiceUUID = @"cc01";
static NSString *bleQueryReadUUID = @"cc02";
static NSString *bleQueryWriteUUID = @"cc03";

@interface GYLocalConnect()<CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic,strong) NSMutableArray *dataSource;
@property (nonatomic, strong) GWGCDTimer *timeoutTimer;
@property (nonatomic, assign) GYBleOperation bleOperation;

@property (nonatomic,copy) callBackParameter statusBlock; // 状态返回，1：连接成功；2：发送数据成功

@property (nonatomic, assign) int randomCount;   ///<   随机数
@property (nonatomic, assign) Byte data1;    ///< 数据
@property (nonatomic, assign) Byte data2;    ///< 数据

@property (nonatomic,strong) NSString *bleName;
@property (nonatomic,assign) BOOL firstConnect;
@property (nonatomic,assign) bool secSendData;

@end

@implementation GYLocalConnect

+ (instancetype)createLocalConnect{
    GYLocalConnect *vc = [[GYLocalConnect alloc]init];
    [vc setup];
    return vc;
}

- (void)setup{
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

- (void)searchBleDevice:(callBackParameter)successBlock failure:(onFailedBlock)failBlock{    _successBlock = successBlock;
    _failBlock = failBlock;
    [self startConnect];
}

- (void)connectBle:(CBPeripheral *)peripheral success:(callBackParameter)successBlock PCRequestFailure:(onFailedBlock)failBlock status:(callBackParameter)statusBlock{
    _successBlock = successBlock;
    _failBlock = failBlock;
    _statusBlock = statusBlock;
    self.curPeripheral = peripheral;
    [self.centralManager stopScan];
    
    _bleOperation = GYBleOperationConnecting;
    [self.timeoutTimer invalidate];
    
    __weak typeof(self) weakSelf = self;
    _timeoutTimer = [GWGCDTimer scheduledTimerWithTimeInterval:60 repeats:NO queue:dispatch_get_global_queue(0, 0) block:^{
        weakSelf.bleOperation = GYBleOperationNone;
        [weakSelf.centralManager cancelPeripheralConnection:peripheral];
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备超时"}];
        weakSelf.failBlock(err);
    }];
    [self.centralManager connectPeripheral:peripheral options:nil];
}

- (void)connectBleWithName:(NSString *)name success:(callBackParameter)successBlock PCRequestFailure:(onFailedBlock)failBlock status:(callBackParameter)statusBlock{
    _successBlock = successBlock;
    _failBlock = failBlock;
    _statusBlock = statusBlock;
    _bleName = name;
    
    [self.timeoutTimer invalidate];
    __weak typeof(self) weakSelf = self;
    _timeoutTimer = [GWGCDTimer scheduledTimerWithTimeInterval:18 repeats:NO queue:dispatch_get_global_queue(0, 0) block:^{
        weakSelf.bleOperation = GYBleOperationNone;
        if(weakSelf.curPeripheral){
            [weakSelf.centralManager cancelPeripheralConnection:weakSelf.curPeripheral];
        }
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备超时"}];
        if(weakSelf.failBlock){
            weakSelf.failBlock(err);
        }
    }];
    
    [self startConnect];
}

- (void)startConnect{
    [self.dataSource removeAllObjects];
    switch (self.centralManager.state) {
        case CBManagerStateUnknown: {
            _bleOperation = GYBleOperationScan;
        } break;
        case CBManagerStateResetting:
        case CBManagerStateUnsupported:
        case CBManagerStateUnauthorized:
        case CBManagerStatePoweredOff: {
            NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeBlePwoerOff userInfo:@{NSLocalizedDescriptionKey : @"未开启蓝牙"}];
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

- (void)startScanBleDevice {
    NSDictionary *option = @{CBCentralManagerScanOptionAllowDuplicatesKey : [NSNumber numberWithBool:NO],CBCentralManagerOptionShowPowerAlertKey:[NSNumber numberWithBool:YES]};
    [self.centralManager scanForPeripheralsWithServices:nil options:option];
}

- (void)sendData:(id)param{
    NSInteger time = [[NSDate date]timeIntervalSince1970];
    NSDictionary *parameter = @{@"time":@(time),@"data":param};
    
    [self resetNewRandomCount];

//    随机数异或mac倒数第二位得到偏移量
    Byte data1 = self.data1;
    NSData *macData =  [self getMacAddress];
    Byte macByte;
    [macData getBytes:&macByte range:NSMakeRange(macData.length - 2, 1)];
    Byte idByte = (Byte) (data1 ^ macByte);
    NSString *excursion = [self toHexString:&idByte size:1];
    NSInteger random = [GYDESHelper convertHexToDecimal:excursion];

    NSMutableData *sendData = [NSJSONSerialization dataWithJSONObject:parameter options:0 error:nil].mutableCopy;

    NSString *policyStr = [[NSString alloc] initWithData:sendData encoding:NSUTF8StringEncoding];
    policyStr = [policyStr stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
            
    NSData *lastData = [policyStr dataUsingEncoding:NSUTF8StringEncoding];

Byte byte[] = {0xE2, 0x67, 0x57, 0x84, 0x3F, 0x42, 0x3B, 0x58, 0xB0, 0xF1, 0xBC, 0xC2, 0x7B, 0xE4, 0xD1, 0x2A, 0x13, 0x64, 0xC3, 0xDB, 0xBD, 0xB0, 0xC6, 0x18, 0x8A, 0xED, 0x73, 0xBB, 0x3D, 0x98, 0x43, 0x92, 0xB0, 0xB3, 0x8C, 0x30, 0xB6, 0x9C, 0x11, 0xA1, 0xB7, 0x45, 0x89, 0xCF, 0x11, 0x17, 0x2F, 0xD3, 0x46, 0xB1, 0xB6, 0x8D, 0xE2, 0x04, 0x5D, 0x6A, 0x69, 0x18, 0xE2, 0x02, 0x32, 0x59, 0xB0, 0xA1, 0x33, 0xB2, 0xB6, 0x91, 0xC9, 0xAA, 0xB4, 0x9E, 0x9E, 0x71, 0xAF, 0x3A, 0x5E, 0xD0, 0xEF, 0xFE, 0x58, 0x93, 0x38, 0x1B, 0xA1, 0xFE, 0x11, 0x30, 0x6C, 0x6D, 0xE6, 0x07, 0x86, 0x93, 0x6D, 0x82, 0x0C, 0x36, 0x24, 0x00, 0x3D, 0x00,0x29, 0xDB, 0x81, 0xD2, 0x77, 0xEF, 0x2A, 0xC9, 0x23, 0xF4, 0x50, 0x85, 0x55, 0x07, 0x92, 0x37, 0x18, 0x7C, 0xC7, 0xA5, 0x5F, 0x0B, 0xE7, 0xA1, 0x5F, 0x95, 0xC0, 0x8D, 0x23, 0x03, 0x81, 0x7E, 0x2D, 0x52, 0x32, 0xFE, 0x72, 0xB7, 0xDE, 0x01, 0xA3, 0x49, 0x79, 0x4B, 0x04, 0xB5, 0xB3, 0xC4, 0xC3, 0xC8, 0xB0, 0x71, 0x90, 0x2C, 0x6E, 0xB5, 0x0F, 0x4C, 0x13, 0x18, 0xE7, 0xBE, 0x68, 0xA1, 0x83, 0xAF, 0x2F, 0xC2, 0xBA, 0x40, 0x9C, 0x58, 0x25, 0x1A, 0x50, 0x35, 0x5A, 0xA5, 0x4E, 0xE4, 0x77, 0xF0, 0xFD, 0x90, 0xC0, 0x43, 0x6D, 0x0E, 0x26, 0x91, 0x8B, 0xBB, 0x65, 0xFA, 0xB3, 0xBF, 0x44, 0xD9, 0x2E, 0xA5, 0x78, 0xC6, 0x34, 0xAF, 0x6A, 0x5F, 0x03, 0x63, 0x4E, 0x10, 0xE2, 0xF8, 0xD9, 0x95, 0xE6, 0x83, 0x01, 0xCB, 0x39, 0x0B, 0x31, 0xD8, 0x5C, 0xF2, 0x83, 0xBD, 0x35, 0x4C, 0x5D, 0x98, 0x21, 0x12, 0x8A, 0x9C, 0xF6, 0x01, 0xE3, 0x51, 0xA7, 0x14, 0x13, 0xD1, 0xFD, 0xF3, 0x41, 0x68, 0x50, 0x02, 0x03, 0x94, 0x81, 0xA7, 0x72, 0xBB};
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
                for (int j = 0; j<privaryData.length; j++) {
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
    NSLog(@"发送数据明文：%@",parameter);
    NSLog(@"发送数据总数：%@",encryptData);
    
    if(self.secSendData == NO){
        [self sendQueryOrder:encryptData];
        self.secSendData = YES;
    }else{
        [self subcontractSendData:encryptData];
    }
}

- (void)subcontractSendData:(NSMutableData *)sendData {
    NSInteger count = sendData.length / 18;
    if (sendData.length % 18 >= 0) {
        count ++;
    }
    
    int delay = 1;
    for (int i = 0; i < count; i ++) {
        NSMutableData *data = [NSMutableData data];
        
        Byte data1 = self.data1;
        
        [data appendBytes:&data1 length:1];
        NSString *dataId = [GYDESHelper ToHex:i + 1];
        NSData *da = [GYDESHelper convertHexStrToData:dataId];
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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"发送数据:%@", data);
            [self.curPeripheral writeValue:data forCharacteristic:[self getWriteChar] type:CBCharacteristicWriteWithResponse];
        });
        delay ++;
    }
}

- (void)sendQueryOrder:(NSMutableData *)sendData {
    NSInteger count = sendData.length / 18;
    if (sendData.length % 18 >= 0) {
        count ++;
    }
    
    int delay = 1;
    for (int i = 0; i < count; i ++) {
        NSMutableData *data = [NSMutableData data];
        
        Byte data1 = self.data1;
        
        [data appendBytes:&data1 length:1];
        NSString *dataId = [GYDESHelper ToHex:i + 1];
        NSData *da = [GYDESHelper convertHexStrToData:dataId];
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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"发送数据:%@", data);
            if([self getWriteChar1] != nil){
                [self.curPeripheral writeValue:data forCharacteristic:[self getWriteChar1] type:CBCharacteristicWriteWithResponse];
            }
        });
        delay ++;
    }
}

// 获取特征服务
- (CBCharacteristic *)getWriteChar {
    CBService *service = [self.curPeripheral.services objectOfObjectsPassingTest:^BOOL(CBService * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [obj.UUID.UUIDString.lowercaseString isEqualToString:bleServiceUUID];
    }];
    if (service) {
        CBCharacteristic *writeChar = [service.characteristics objectOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.UUID.UUIDString.lowercaseString isEqualToString:bleWriteUUID];
        }];
        return writeChar;
    }
    return nil;
}

- (CBCharacteristic *)getWriteChar1 {
    CBService *service = [self.curPeripheral.services objectOfObjectsPassingTest:^BOOL(CBService * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [obj.UUID.UUIDString.lowercaseString isEqualToString:bleQueryServiceUUID];
    }];
    if (service) {
        CBCharacteristic *writeChar = [service.characteristics objectOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.UUID.UUIDString.lowercaseString isEqualToString:bleQueryWriteUUID];
        }];
        return writeChar;
    }
    return nil;
}

- (void)resetRandomCount {
    static int count = 1;
    self.randomCount = count;
    count ++;
    [self configDataId];
}

- (void)configDataId {
    NSString *dataId = [GYDESHelper ToHex:self.randomCount];
    NSData *da = [GYDESHelper convertHexStrToData:dataId];
    self.data1 = 0x00;
    self.data2 = 0x00;
    if (da.length == 1) {
        Byte by;
        [da getBytes:&by length:1];
        self.data2 = by;
    } else if (da.length == 2) {
        Byte by1, by2;
        [da getBytes:&by1 range:NSMakeRange(0, 1)];
        [da getBytes:&by2 range:NSMakeRange(1, 1)];
        self.data1 = by1;
        self.data2 = by2;
    }
}
#pragma mark - ble delegate
// 发现蓝牙设备
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"蓝牙名称--%@", peripheral.name);
    if (self.bleName.length > 0) {
        if ([peripheral.name containsString:self.bleName]) {
            self.curPeripheral = peripheral;
            CBPeripheralCategory *peripheralCategory =  [[CBPeripheralCategory alloc]init];
            peripheralCategory.bleName = self.curPeripheral.name;
            peripheralCategory.advertisementData = advertisementData;
            [GYAddDeviceManager shareManager].peripheralCategory = peripheralCategory;
            
            [central stopScan];
            _bleOperation = GYBleOperationConnecting;
            _curPeripheral = peripheral;
            [self.centralManager connectPeripheral:peripheral options:nil];
        }
    }else{
    CBPeripheralCategory *peripheralCategory = [[CBPeripheralCategory alloc]initWithName:peripheral rssi:RSSI];
    peripheralCategory.advertisementData = advertisementData;

    NSString *name = [peripheral.name lowercaseString];
    if (peripheral.name.length > 0 && ([name containsString:@"granwin"] || [name containsString:@"hs"])) {
        NSInteger index = -1;
        for (int i = 0; i<self.dataSource.count; i++) {
            CBPeripheralCategory *single = self.dataSource[i];
            if ([peripheral.name isEqualToString:single.bleName]) {
                index = i;
                break;
            }
        }
        if (index >= 0) {
            [self.dataSource replaceObjectAtIndex:index withObject:peripheralCategory];
        }else{
            [self.dataSource addObject:peripheralCategory];
        }
        NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"RSSI" ascending:YES]];
        [self.dataSource sortUsingDescriptors:sortDescriptors];
        if (_successBlock) {
            _successBlock(self.dataSource);
        }
    }
    }
}

// 蓝牙设备连接成功
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    peripheral.delegate = self;
    [peripheral discoverServices:@[[CBUUID UUIDWithString:bleServiceUUID],[CBUUID UUIDWithString:bleQueryServiceUUID]]];
}

// 蓝牙设备连接失败
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"设备断开连接%@",error.localizedDescription);
    if (self.bleOperation == GYBleOperationConnecting ||
        self.bleOperation == GYBleOperationConnected) {
        NSLog(@"设备断开连接%@",error.localizedDescription);
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备失败"}];
        if (_failBlock) {
            _failBlock(err);
        }
    }
}

- (void)centralManagerDidUpdateState:(nonnull CBCentralManager *)central {
    switch (central.state) {
        case CBManagerStateUnknown: {
            
        } break;
        case CBManagerStateResetting:
        case CBManagerStateUnsupported:
        case CBManagerStateUnauthorized:
        case CBManagerStatePoweredOff: {
            if (self.bleOperation != GYBleOperationNone) {
                NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeBlePwoerOff userInfo:@{NSLocalizedDescriptionKey : @"未开启蓝牙"}];
                _bleOperation = GYBleOperationNone;
                if (_failBlock) {
                    _failBlock(err);
                }
            }
            
        } break;
        case CBManagerStatePoweredOn: {
            if (self.bleOperation == GYBleOperationScan) {
                [self startScanBleDevice];
            }
        }
            break;
        default:
            break;
    }
}


// 获取蓝牙服务
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备获取服务失败"}];
        [self stopSetDeviceNetwork];
        if (_failBlock) {
            _failBlock(err);
        }
        NSLog(@"获取服务失败");
    } else {
        CBService *service = [peripheral.services objectOfObjectsPassingTest:^BOOL(CBService * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.UUID.UUIDString.lowercaseString isEqualToString:bleServiceUUID];
        }];
        CBService *service1 = [peripheral.services objectOfObjectsPassingTest:^BOOL(CBService * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.UUID.UUIDString.lowercaseString isEqualToString:bleQueryServiceUUID];
        }];
        if (service) {
            NSLog(@"获取服务成功，获取特征值");
            [peripheral discoverCharacteristics:@[
                [CBUUID UUIDWithString:bleReadUUID],
                [CBUUID UUIDWithString:bleWriteUUID]
            ] forService:service];
        } else {
            NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备获取服务失败"}];
            [self stopSetDeviceNetwork];
            if (_failBlock) {
                _failBlock(err);
            }
            NSLog(@"获取服务失败");
        }
        if(service1){
            NSLog(@"获取查询服务成功，获取特征值");
            [peripheral discoverCharacteristics:@[
                [CBUUID UUIDWithString:bleQueryReadUUID],
                [CBUUID UUIDWithString:bleQueryWriteUUID]
            ] forService:service1];
        }
    }
}

// 获取蓝牙特征值
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备获取特征值失败"}];
        [self stopSetDeviceNetwork];
        if (_failBlock) {
            _failBlock(err);
        }
        NSLog(@"获取特征值失败");
    } else {
        CBCharacteristic *writeChar = [service.characteristics objectOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.UUID.UUIDString.lowercaseString isEqualToString:bleWriteUUID];
        }];
        CBCharacteristic *readChar = [service.characteristics objectOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.UUID.UUIDString.lowercaseString isEqualToString:bleReadUUID];
        }];
        CBCharacteristic *writeChar1 = [service.characteristics objectOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.UUID.UUIDString.lowercaseString isEqualToString:bleQueryWriteUUID];
        }];
        CBCharacteristic *readChar1 = [service.characteristics objectOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.UUID.UUIDString.lowercaseString isEqualToString:bleQueryReadUUID];
        }];
        if ((!writeChar || !readChar) || (writeChar1 || !readChar1)) {
            NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备获取特征值失败"}];
            [self stopSetDeviceNetwork];
            if (_failBlock) {
                _failBlock(err);
            }
            NSLog(@"获取特征值失败");
        } else {
            NSLog(@"获取特征值成功");
            [peripheral setNotifyValue:YES forCharacteristic:readChar];
        }
        if(writeChar1 && readChar1){
            [peripheral setNotifyValue:YES forCharacteristic:readChar1];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (characteristic.isNotifying) {
        self.hasConnect = YES;
        self.firstConnect = NO;
        self.secSendData = NO;
        NSLog(@"%@:打开通知成功", characteristic.UUID.UUIDString);
        if (_statusBlock) {
            _statusBlock(@(1));
        }
//        if(_successBlock){
//            _successBlock(@"");
//        }
            [_timeoutTimer invalidate];
             _timeoutTimer = nil;
        
        if (self.centralManager.isScanning) {
            [self.centralManager stopScan];
        }
    } else {
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备打开通知失败"}];
       [self stopSetDeviceNetwork];
        if (_failBlock) {
            _failBlock(err);
        }
        NSLog(@"打开通知失败");
    }
}

// 指定特征值变化
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error {
    if (error) {
        NSLog(@"error Discovered characteristics for %@ with error: %@", characteristic.UUID, [error localizedDescription]);
    }
    NSLog(@"指定特征值变化：%@", characteristic.value);
    NSData *data = characteristic.value;
    if (data) {
        static NSMutableData *recvData;
        if (!recvData) {
            recvData = [NSMutableData data];
        }
        static NSInteger recvId;
        Byte pack = 0x00;
        Byte count = 0x00;
        Byte dataId = 0x00;
        
        if (data.length > 2) {
            [data getBytes:&count range:NSMakeRange(1, 1)];
            [data getBytes:&pack range:NSMakeRange(0, 1)];
            
            char numbytes[] = {0x00,count};
            unsigned char by1 = (numbytes[0] &0xff);//高8位
            unsigned char by3 = numbytes[1] &0xff; // 低八位
            int serial = (by3 | by1 << 8);

            char ids[] = {0x00,pack};
            unsigned char aby1 = (ids[0] &0xff);//高8位
            unsigned char aby3 = ids[1] &0xff; // 低八位
            
            if (serial == 1) {
                recvId =  (aby3 | aby1 << 8);
                [data getBytes:&dataId range:NSMakeRange(2, 1)];
                
                char length[] = {0x00,dataId};
                unsigned char len1 = (length[0] &0xff);//高8位
                unsigned char len2 = length[1] &0xff; // 低八位
                int leng = (len2 | len1 << 8);
                
                [recvData appendData:[data subdataWithRange:NSMakeRange(2, data.length - 2)]];
            }else{
//                NSInteger secId = (aby3 | aby1 << 8);
//                if(secId == recvId){
                [recvData appendData:[data subdataWithRange:NSMakeRange(2, data.length - 2)]];
//                }
            }
        }
        NSInteger number = data.length;
        if (number < 20) {
            NSDictionary *recvDic = [self decodeReceiveData:recvData];
            NSDictionary *data = [recvDic objectForKey:@"data"];
            NSMutableDictionary *tempDic =  [NSMutableDictionary dictionaryWithDictionary:self.receiveData];
            [tempDic addEntriesFromDictionary:data];
            NSLog(@"接收数据：%@",recvDic);
//            NSLog(@"蓝牙接收数据：%@",tempDic);
            if(self.firstConnect == NO){
                //  发送查询指令
//
            [self sendData:@[@(1),@(2),@(3),@(4),@(5),@(6),@(7),@(8),@(9),@(10),@(11),@(12),@(13),@(14),@(15),@(16),@(17),@(18),@(19),@(20),@(21),@(22),@(23),@(24),@(25),@(26),@(27),@(28),@(29),@(30),@(31),@(33)]];
                self.firstConnect = YES;
            }
            self.receiveData = tempDic.copy;
            if(_successBlock){
                _successBlock(self.receiveData);
            }
            recvData = nil;
        }
    }else{
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备获取服务失败"}];
    }
}

// 写入回调
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error{
    if (error) {
       NSLog(@"error Discovered characteristics for %@ with error: %@", characteristic.UUID, [error localizedDescription]);
    }
    NSLog(@"特征值变化：%@", characteristic.value);
 }

- (NSDictionary *)decodeReceiveData:(NSData *)receiveData{
    if(receiveData.length > 500){
        NSLog(@"-------");
    }
    Byte byte[] = {0xE2, 0x67, 0x57, 0x84, 0x3F, 0x42, 0x3B, 0x58, 0xB0, 0xF1, 0xBC, 0xC2, 0x7B, 0xE4, 0xD1, 0x2A, 0x13, 0x64, 0xC3, 0xDB, 0xBD, 0xB0, 0xC6, 0x18, 0x8A, 0xED, 0x73, 0xBB, 0x3D, 0x98, 0x43, 0x92, 0xB0, 0xB3, 0x8C, 0x30, 0xB6, 0x9C, 0x11, 0xA1, 0xB7, 0x45, 0x89, 0xCF, 0x11, 0x17, 0x2F, 0xD3, 0x46, 0xB1, 0xB6, 0x8D, 0xE2, 0x04, 0x5D, 0x6A, 0x69, 0x18, 0xE2, 0x02, 0x32, 0x59, 0xB0, 0xA1, 0x33, 0xB2, 0xB6, 0x91, 0xC9, 0xAA, 0xB4, 0x9E, 0x9E, 0x71, 0xAF, 0x3A, 0x5E, 0xD0, 0xEF, 0xFE, 0x58, 0x93, 0x38, 0x1B, 0xA1, 0xFE, 0x11, 0x30, 0x6C, 0x6D, 0xE6, 0x07, 0x86, 0x93, 0x6D, 0x82, 0x0C, 0x36, 0x24, 0x00, 0x3D, 0x00,0x29, 0xDB, 0x81, 0xD2, 0x77, 0xEF, 0x2A, 0xC9, 0x23, 0xF4, 0x50, 0x85, 0x55, 0x07, 0x92, 0x37, 0x18, 0x7C, 0xC7, 0xA5, 0x5F, 0x0B, 0xE7, 0xA1, 0x5F, 0x95, 0xC0, 0x8D, 0x23, 0x03, 0x81, 0x7E, 0x2D, 0x52, 0x32, 0xFE, 0x72, 0xB7, 0xDE, 0x01, 0xA3, 0x49, 0x79, 0x4B, 0x04, 0xB5, 0xB3, 0xC4, 0xC3, 0xC8, 0xB0, 0x71, 0x90, 0x2C, 0x6E, 0xB5, 0x0F, 0x4C, 0x13, 0x18, 0xE7, 0xBE, 0x68, 0xA1, 0x83, 0xAF, 0x2F, 0xC2, 0xBA, 0x40, 0x9C, 0x58, 0x25, 0x1A, 0x50, 0x35, 0x5A, 0xA5, 0x4E, 0xE4, 0x77, 0xF0, 0xFD, 0x90, 0xC0, 0x43, 0x6D, 0x0E, 0x26, 0x91, 0x8B, 0xBB, 0x65, 0xFA, 0xB3, 0xBF, 0x44, 0xD9, 0x2E, 0xA5, 0x78, 0xC6, 0x34, 0xAF, 0x6A, 0x5F, 0x03, 0x63, 0x4E, 0x10, 0xE2, 0xF8, 0xD9, 0x95, 0xE6, 0x83, 0x01, 0xCB, 0x39, 0x0B, 0x31, 0xD8, 0x5C, 0xF2, 0x83, 0xBD, 0x35, 0x4C, 0x5D, 0x98, 0x21, 0x12, 0x8A, 0x9C, 0xF6, 0x01, 0xE3, 0x51, 0xA7, 0x14, 0x13, 0xD1, 0xFD, 0xF3, 0x41, 0x68, 0x50, 0x02, 0x03, 0x94, 0x81, 0xA7, 0x72, 0xBB};
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
                if(i == remain-1){
                    NSLog(@"----");
                }
                [encryptData appendBytes:&b length:1];
            }
            NSInteger beginning = remain; // 初始值
            for (int i = 0; i<divisor; i++) {
                for (int j = 0; j<privaryData.length; j++) {
                    NSInteger z = beginning + i*privaryData.length+j;
                    Byte by1;
                    if(j == privaryData.length-1){
                        NSLog(@"-----");
                    }
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
    NSString * str  = [NSString stringWithUTF8String:[encryptData bytes]];
//    [[NSString alloc] initWithData:encryptData encoding:NSUTF8StringEncoding];
    [NSString stringWithUTF8String:[encryptData bytes]];
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:encryptData
                                                        options:NSJSONReadingFragmentsAllowed
                                                          error:&err];
    NSLog(@"udp接收数据:%@------%@", receiveData,encryptData);
    return dic;
}


- (NSInteger)resetNewRandomCount {
    NSInteger random = arc4random()%255;
    NSString *dataId = [GYDESHelper ToHex:random];
    NSData *da = [GYDESHelper convertHexStrToData:dataId];
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

 - (NSMutableArray *)dataSource{
        if (!_dataSource) {
            _dataSource = [NSMutableArray array];
        }
        return _dataSource;
 }

- (NSDictionary *)receiveData{
    if(!_receiveData){
        _receiveData = [NSDictionary dictionary];
    }
    return _receiveData;
}

- (NSData *)getMacAddress{
    CBPeripheralCategory *category = nil;
    for (CBPeripheralCategory *peripheral in self.dataSource) {
        if([self.curPeripheral.name isEqual:peripheral.bleName]){
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

- (void)stopSetDeviceNetwork {
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
    _failBlock = nil;
    _successBlock = nil;
    _statusBlock = nil;
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
}

@end
