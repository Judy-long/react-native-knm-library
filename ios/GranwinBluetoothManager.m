//
//  GranwinAPKit.m
//  GranwinAPKit
//
//  Created by (╹◡╹) on 2019/5/7.
//  Copyright © 2019 granwin. All rights reserved.
//

#import "GranwinBluetoothManager.h"
#import <UIKit/UIKit.h>
#import "GWGCDTimer.h"
#import "NSArray+Tools.h"
#import "GranwinAPKit.h"
//#import "MNTipsManager.h"

#import <arpa/inet.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <CoreBluetooth/CoreBluetooth.h>
#include <CommonCrypto/CommonCryptor.h>
#import<CommonCrypto/CommonDigest.h>
#import "UIAlertController+showOnWindow.h"

//static NSString *bleServiceUUID = @"0000ff01-0000-1000-8000-00805f9b34fb";
//static NSString *bleReadUUID = @"0000ff02-0000-1000-8000-00805f9b34fb";
//static NSString *bleWriteUUID = @"0000ff03-0000-1000-8000-00805f9b34fb";

static NSString *bleServiceUUID = @"EE01";
static NSString *bleReadUUID = @"EE02";
static NSString *bleWriteUUID = @"EE03";

static NSString *bleServiceUUID1 = @"CC01";
static NSString *bleReadUUID1 = @"CC02";
static NSString *bleWriteUUID1 = @"CC03";

//static NSString *bleServiceUUID = @"0000FFF0-0000-1000-8000-00805F9B34FB";
//static NSString *bleReadUUID = @"0000FFF1-0000-1000-8000-00805F9B34FB";
//static NSString *bleWriteUUID = @"0000FFF2-0000-1000-8000-00805F9B34FB";


@interface GranwinBluetoothManager ()<CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) GWGCDTimer *timeoutTimer;

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, assign) RPBleOperation bleOperation;
@property (nonatomic, strong) CBPeripheral *curPeripheral;
@property (nonatomic, strong) CBService *ccService;    ///< cc服务

//@property (nonatomic, copy) NSString *bleName;
@property (nonatomic, copy) NSString *configUrl;
@property (nonatomic, copy) NSString *deviceToken;

@property (nonatomic, assign) int randomCount;   ///<   随机数
@property (nonatomic, strong) NSMutableData *sendData;    ///< 发送的数据
@property (nonatomic, assign) int recvCount;    ///< 接受包数量
@property (nonatomic, assign) Byte data1;    ///< 数据
@property (nonatomic, assign) Byte data2;    ///< 数据
@property (nonatomic, assign) BOOL needCBC;    ///< 需要加密
@property (nonatomic, copy) NSString *mac;    ///< mac
@property (nonatomic, assign) BOOL autoConnect;    ///< 自动连接

@property (nonatomic, strong) NSMutableArray *deviceArray;    ///< 设备
@property (nonatomic, copy) CallBack scanCallBack;    ///< scanCallBack
@property (nonatomic, copy) CallBack blockOnConnect;    ///< 连接
@property (nonatomic, strong) NSMutableData *receiveData;    ///< 接收的数据
@property (nonatomic, assign) BOOL isBluetoothOn;    ///< 蓝牙打开
@property (nonatomic, strong) NSMutableArray *recordArray;    ///< 设备
@property (nonatomic, copy) NSString *name;    ///< 名字（连接）
@property (nonatomic, strong) NSMutableArray <NSDictionary *>*dataArray;    ///< 数据
@property (nonatomic, assign) BOOL sending;    ///< 发送中
@property (nonatomic, assign) BOOL isEE;    ///< 发送EE

@end

@implementation GranwinBluetoothManager

//- (NSString *)name {
//  return @"fnirsi.etool.40mpro";
//}

+ (GranwinBluetoothManager *)shared {
  static GranwinBluetoothManager *manager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    manager = [[GranwinBluetoothManager alloc] init];
    manager.needCBC = YES;
  });
  return manager;
}

- (void)start {
  _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

- (void)stopScan {
  [self.centralManager stopScan];
}

- (void)disconnect {
  if (self.curPeripheral) {
    [self.centralManager cancelPeripheralConnection:self.curPeripheral];
    self.curPeripheral = nil;
  }
  [self.recordArray removeAllObjects];
}

#pragma mark - 蓝牙部分
- (void)connectDeviceWithMac:(NSString *)mac name:(NSString *)name completion:(CallBack)completion {
  [self stopScan];
  [self disconnect];
  
  _scanCallBack = nil;
  self.autoConnect = YES;
  _mac = mac;
  _name = name;
  
//  [self showTips:@"调用连接"];
  
  if (self.isBluetoothOn) {
    _mac = mac;
    _blockOnConnect = completion;
    
    __block NSDictionary *dict = nil;
    [self.recordArray enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      NSString *mac = obj[@"mac"];
      if ([mac.uppercaseString isEqualToString:self.mac.uppercaseString]) {
        dict = obj;
        *stop = YES;
      }
    }];
    
//    if (dict) {
//      self.curPeripheral = dict[@"peripheral"];
//      NSString *tips = [NSString stringWithFormat:@"开始连接%@ %@", mac, self.curPeripheral];
//      [self showTips:tips];
//
//      [self.centralManager stopScan];
//      _bleOperation = RPBleOperationConnecting;
//      [self.timeoutTimer invalidate];
//      __weak typeof(self) weakSelf = self;
//      _timeoutTimer = [GWGCDTimer scheduledTimerWithTimeInterval:30 repeats:NO queue:dispatch_get_global_queue(0, 0) block:^{
//        weakSelf.bleOperation = RPBleOperationNone;
//        [weakSelf.centralManager cancelPeripheralConnection:weakSelf.curPeripheral];
//        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:RPErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备超时"}];
//        [self setDeviceNetworkFailed:err];
//      }];
//      [self.centralManager connectPeripheral:self.curPeripheral options:nil];
//    } else {
      [self startScanBleDeviceWithName:self.name autoConnect:YES callBack:self.scanCallBack];
//    }
  } else {
    
  }
}

- (void)connectDeviceWithName:(NSString *)name completion:(CallBack)completion {
  [self stopScan];
  [self disconnect];
  
  _scanCallBack = nil;
  self.autoConnect = YES;
  _name = name;
  
  if (self.isBluetoothOn) {
    _blockOnConnect = completion;
    
    __block NSDictionary *dict = nil;
    [self.recordArray enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      if ([obj[@"name"] isEqualToString:self.name]) {
        dict = obj;
        *stop = YES;
      }
    }];
    
//    if (dict) {
//      self.curPeripheral = dict[@"peripheral"];
//
//      [self.centralManager stopScan];
//      _bleOperation = RPBleOperationConnecting;
//      [self.timeoutTimer invalidate];
//      __weak typeof(self) weakSelf = self;
//      _timeoutTimer = [GWGCDTimer scheduledTimerWithTimeInterval:30 repeats:NO queue:dispatch_get_global_queue(0, 0) block:^{
//        weakSelf.bleOperation = RPBleOperationNone;
//        [weakSelf.centralManager cancelPeripheralConnection:weakSelf.curPeripheral];
//        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:RPErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备超时"}];
//        [self setDeviceNetworkFailed:err];
//      }];
//      [self.centralManager connectPeripheral:self.curPeripheral options:nil];
//    } else {
      [self startScanBleDeviceWithName:self.name autoConnect:YES callBack:self.scanCallBack];
//    }
  } else {
    
  }
}

- (void)disconnectDeviceWithMac:(NSString *)mac {
  if (self.curPeripheral) {
    [self.centralManager cancelPeripheralConnection:self.curPeripheral];
    self.curPeripheral = nil;
  }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
  self.isBluetoothOn = NO;
  switch (central.state) {
    case CBManagerStateUnknown: {
      
    } break;
    case CBManagerStateResetting:
    case CBManagerStateUnsupported:
    case CBManagerStateUnauthorized:
    case CBManagerStatePoweredOff: {
      [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kNotificationOnConnectChange" object:nil userInfo:@{@"status": @(0)}];
      }];
      if (self.bleOperation != RPBleOperationNone) {
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:RPErrorCodeBlePwoerOff userInfo:@{NSLocalizedDescriptionKey : @"未开启蓝牙"}];
        _bleOperation = RPBleOperationNone;
        [self setDeviceNetworkFailed:err];
      }
    } break;
    case CBManagerStatePoweredOn: {
      self.isBluetoothOn = YES;
    }
      break;
    default:
      break;
  }
}

- (void)startScanBleDeviceWithName:(NSString *)name callBack:(CallBack)callBack {
  [self startScanBleDeviceWithName:name autoConnect:NO callBack:callBack];
}

- (void)startScanBleDeviceWithName:(NSString *)name autoConnect:(BOOL)autoConnect callBack:(CallBack)callBack {
  _autoConnect = autoConnect;
  _scanCallBack = callBack;
  _name = name.copy;
  _bleOperation = RPBleOperationScan;

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
  });
}


- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
  NSLog(@"name:%@", peripheral.name);
  if ([peripheral.name containsString:self.name]) {
    NSString *mac = @"";
    NSData *data = advertisementData[@"kCBAdvDataManufacturerData"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kOnScanBluetooth" object:nil userInfo:@{@"data": data ?: NSData.new}];
    
    
//    NSString *str = [NSString stringWithFormat:@"%@", data];
//    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:str preferredStyle:UIAlertControllerStyleAlert];
//    UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
//
//    }];
//    [alert addAction:action];
//    [alert showOnWindow];
    
//    NSString *mac = @"";
//    NSData *data = advertisementData[@"kCBAdvDataManufacturerData"];
//    if (data.length == 8) {
//        Byte byte1, byte2;
//        [data getBytes:&byte1 range:NSMakeRange(0, 1)];
//        [data getBytes:&byte2 range:NSMakeRange(1, 1)];
//        if (byte1 == 0x7d && byte2 == 0x02) {
//            mac = [self hexStringFromString:data];
//            mac = [mac substringFromIndex:4];
//        }
//    }

#if DEBUG
    if (data.length == 0) {
      Byte byte[] = {0xff, 0x01, 0x03, 0x12, 0xad, 0x76, 0x87, 0x98, 0xac, 0xab, 0xae, 0x23, 0x23, 0x45, 0x56, 0xff, 0x88, 0x99, 0x10, 0x11};
      data = [NSData dataWithBytes:byte length:20];
    }
#endif
    
    if (data.length >= 20) {
      data = [data subdataWithRange:NSMakeRange(13, 6)];
      mac = [self hexStringFromString:data];
      NSMutableString *muStr = NSMutableString.new;
      for (int i = 0; i < 6; i ++) {
          [muStr appendString:[mac substringWithRange:NSMakeRange(i * 2, 2)]];
          if (i != 5) {
              [muStr appendString:@":"];
          }
      }
      mac = muStr.copy;
    }

    if (mac) {
      NSString *tips =[NSString stringWithFormat:@"发现设备：%@", mac];
//      [self showTips:tips];
      
      __block NSInteger index = NSNotFound;
      [self.recordArray enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj[@"mac"] isEqualToString:self.mac]) {
          index = idx;
          *stop = YES;
        }
      }];
      if (index != NSNotFound) {
        [self.recordArray removeObjectAtIndex:index];
      }
      
      NSDictionary *params = @{@"name": peripheral.name, @"mac": mac, @"peripheral": peripheral};
      [self.recordArray addObject:params];
    }
    
//    if (mac.length) {
      if (_scanCallBack) {
        _scanCallBack(@{@"mac": mac ? mac : @"", @"name": peripheral.name}, nil);
      }
      
      if (self.autoConnect &&
          [self.mac isEqualToString:mac]) {
        _curPeripheral = peripheral;
        
        NSString *tips = [NSString stringWithFormat:@"开始连接%@ %@", mac, self.curPeripheral];
//        [self showTips:tips];
        
        [self.centralManager stopScan];
        _bleOperation = RPBleOperationConnecting;
        [self.timeoutTimer invalidate];
        __weak typeof(self) weakSelf = self;
        _timeoutTimer = [GWGCDTimer scheduledTimerWithTimeInterval:30 repeats:NO queue:dispatch_get_global_queue(0, 0) block:^{
          weakSelf.bleOperation = RPBleOperationNone;
          if (weakSelf.curPeripheral) {
            [weakSelf.centralManager cancelPeripheralConnection:weakSelf.curPeripheral];
          }
          NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:RPErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备超时"}];
          [self setDeviceNetworkFailed:err];
        }];
        [self.centralManager connectPeripheral:peripheral options:nil];
//        [self connectDeviceWithMac:mac name:self.name completion:self.blockOnConnect];
      }
//    }
//    [self.centralManager connectPeripheral:peripheral options:nil];
  }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
  NSString *tips = [NSString stringWithFormat:@"peripheral连接成功"];

//  [self showTips:tips];

  peripheral.delegate = self;
  [peripheral discoverServices:nil];
  _bleOperation = RPBleOperationConnected;
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
  NSLog(@"设备断开连接");
  NSString *tips = [NSString stringWithFormat:@"设备断开连接%@", error];

//  [self showTips:tips];

  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kNotificationOnConnectChange" object:nil userInfo:@{@"status": @(0)}];
  }];
  
  if (self.bleOperation == RPBleOperationConnecting ||
      self.bleOperation == RPBleOperationConnected) {
    NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:RPErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备失败"}];
    [self setDeviceNetworkFailed:err];
  }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
  if (error) {
    NSString *tips = [NSString stringWithFormat:@"发现服务失败%@", error];

//    [self showTips:tips];
    NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备获取服务失败"}];
    [self setDeviceNetworkFailed:err];
    NSLog(@"获取服务失败");
  } else {
//    for (CBService *service in peripheral.services) {
//      [peripheral discoverCharacteristics:nil forService:service];
//    }
//    return;
    CBService *service = [peripheral.services objectOfObjectsPassingTest:^BOOL(CBService * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      return [obj.UUID.UUIDString.uppercaseString containsString:bleServiceUUID];
    }];
    
    CBService *service1 = [peripheral.services objectOfObjectsPassingTest:^BOOL(CBService * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      return [obj.UUID.UUIDString.uppercaseString containsString:bleServiceUUID1];
    }];
    
    if (service) {
//      [self showTips:@"发现服务成功"];
      NSLog(@"获取服务成功，获取特征值");
      [peripheral discoverCharacteristics:nil forService:service];
    } else {
      NSString *tips = [NSString stringWithFormat:@"发现服务失败%@", peripheral.services];
//      [self showTips:tips];
      NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备获取服务失败"}];
      [self setDeviceNetworkFailed:err];
      NSLog(@"获取服务失败");
    }
    
    if (service1) {
      NSString *tips = [NSString stringWithFormat:@"发现CC服务:%@", service1];
//      [self showTips:tips];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [peripheral discoverCharacteristics:nil forService:service1];
      });
    }
  }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
//  [self showTips:@"发现特征值"];
  if (error) {
    NSString *tips = [NSString stringWithFormat:@"发现特征值失败%@", error];

    [self showTips:tips];

    NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备获取特征值失败"}];
    [self setDeviceNetworkFailed:err];
    NSLog(@"获取特征值失败");
  } else {
    NSString *tips = [NSString stringWithFormat:@"发现特征值：%@", service.characteristics];
//    [self showTips:tips];
    NSLog(@"获取特征值112:%@", service.characteristics);
      CBCharacteristic *writeChar = [service.characteristics objectOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [obj.UUID.UUIDString.uppercaseString containsString:bleWriteUUID];
      }];
      CBCharacteristic *readChar = [service.characteristics objectOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [obj.UUID.UUIDString.uppercaseString containsString:bleReadUUID];
      }];
      
      if (!writeChar || !readChar) {
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备获取特征值失败"}];
        [self setDeviceNetworkFailed:err];
        NSLog(@"获取特征值失败");
        NSString *tips = [NSString stringWithFormat:@"发现特征值失败%@", service.characteristics];

//        [self showTips:tips];

      } else {
        NSLog(@"获取特征值成功");
        [peripheral setNotifyValue:YES forCharacteristic:readChar];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
          [[NSNotificationCenter defaultCenter] postNotificationName:@"kNotificationOnConnectChange" object:nil userInfo:@{@"status": @(1)}];
        }];
  //      [self showTips:@"连接成功"];
        if (_blockOnConnect) {
          _blockOnConnect(self.mac ?: self.name, nil);
        }
    }
    
    CBCharacteristic *writeChar1 = [service.characteristics objectOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      return [obj.UUID.UUIDString.uppercaseString containsString:bleWriteUUID1];
    }];
    CBCharacteristic *readChar1 = [service.characteristics objectOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      return [obj.UUID.UUIDString.uppercaseString containsString:bleReadUUID1];
    }];
    
    if (writeChar1 && readChar1) {
      NSString *tips = [NSString stringWithFormat:@"发现cc特征值:%@", service.characteristics];
      [self showTips:tips];
      [peripheral setNotifyValue:YES forCharacteristic:readChar1];
    } else {
//      NSString *tips = [NSString stringWithFormat:@"发现特征值失败：%@", service];
//      [self showTips:tips];
    }
  }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
  if (characteristic.isNotifying) {
    NSLog(@"%@:打开通知成功", characteristic.UUID.UUIDString);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kOnNotifyStatusChange" object:nil userInfo:@{@"status": @(YES)}];
    if (self.timeoutTimer) {
      [self.timeoutTimer invalidate];
    }
  } else {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kOnNotifyStatusChange" object:nil userInfo:@{@"status": @(NO)}];
    NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:RPErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备打开通知失败"}];
    [self setDeviceNetworkFailed:err];
    NSLog(@"打开通知失败");
  }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error {
  [self dealWithReceiveData:characteristic.value];
}
//
//- (void)test {
//  Byte byte1[] = {0xAF,0x0A,0x01,0x74,0x5A,0x01,0xD2,0x65,0xCB,0x7D,0x40,0x70,0x43,0x77,0x17,0x31,0xC0,0x81,0xDF,0x1C};
//  Byte byte2[] = {0xAF,0x0A,0x02,0x46,0xFD,0x1E,0xFF,0xE3,0x53,0x20,0x60,0xF4,0x7B,0x32,0xBC,0x18,0x00,0xB5,0x84,0x8F};
//  Byte byte3[] = {0xAF,0x0A,0x03,0x21,0x02,0x9A,0x63,0xB1,0x8C,0x40,0xCF,0x5B,0x7D,0x8D,0x91,0x22,0x5B,0x8C,0x32,0xDD};
//  Byte byte4[] = {0xAF,0x0A,0x04,0x19,0x66,0x1F,0x0D,0x74,0x13,0xE7,0xDB,0x7E,0xA4,0xE0,0x7B,0x89,0xDB,0x9F,0x1F,0x7F};
//  Byte byte5[] = {0xAF,0x0A,0x05,0x25,0x22,0x58,0xC1,0x50,0x14,0x3D,0x33,0x68,0xEB,0xBB,0x67,0x43,0xA2,0x27,0xAE,0xE1};
//  Byte byte6[] = {0xAF,0x0A,0x06,0x04,0x87,0xFD,0x7F,0xF7,0xA1,0xB9,0x71,0x30,0xF4,0x75,0x8C,0xFA,0xCD,0x47,0x5D,0x7F};
//  Byte byte7[] = {0xAF,0x0A,0x07,0x0A,0x05,0x66,0xC8,0x60,0xC9,0x12,0x52,0xAD,0xA2,0x57,0x3C,0x06,0x7E,0x50,0x5F,0x53};
//  Byte byte8[] = {0xAF,0x0A,0x08,0x18,0x36,0xFF,0x8D,0x1C,0x65,0x6E,0xAE,0x1E,0xF2,0x9A,0x96,0x35,0xC0,0x61,0x85,0xDC};
//  Byte byte9[] = {0xAF,0x0A,0x09,0xF2,0x80,0x73,0xD7,0x0B,0xD2,0xCC,0x01,0x3D,0x71,0x32,0xE3,0x3A,0x2E,0xB9,0xE9,0x85};
//  Byte byte10[] = {0xAF,0x0A,0x0A,0xB1,0xD1,0x76,0x66,0xF2,0x05,0xB9,0x7D,0xB8,0x04,0xA1,0x5D,0xDD,0xFC,0x23,0x53,0x5A};
//  Byte byte11[] = {0xAF,0x0A,0x0B,0x3F,0xB6,0x1B,0x9D,0x83,0x79,0x07,0x62,0x7C,0xCE,0x0F,0xA9,0x46,0x75,0xEA,0x7C,0x91};
//  Byte byte12[] = {0xAF,0x0A,0x0C,0x6F,0x53,0x48,0x9E,0xD7,0xC4,0x21,0x7D,0x54,0xB2,0xB0,0x9B,0x90,0xEE,0x36,0x25,0xE7};
//  Byte byte13[] = {0xAF,0x0A,0x0D,0x5F,0xCB,0x24,0x0E,0x6F,0xF9,0xF2,0xE7,0x47,0x25,0x85,0x83,0x9A,0xB1,0x23,0x19,0x14};
//  Byte byte14[] = {0xAF,0x0A,0x0E,0x4E,0xB1,0x75,0x94,0xA6,0x02,0x4D,0x08,0xBD,0xDE,0xC1,0x9A,0x56,0x06,0x80,0xFF,0x32};
//  Byte byte15[] = {0xAF,0x0A,0x0F,0x6A,0x34,0xFF,0xC5,0xFF,0xC6,0x81,0x36,0x72,0x4F,0xF5,0xA5,0xE9,0xD0,0x69,0x20,0x3C};
//  Byte byte16[] = {0xAF,0x0A,0x10,0x34,0x6E,0x38,0xD1,0x20,0xD9,0xA1,0x30,0x47,0x49,0x4A,0x4E,0x5F,0x2D,0x61,0x0D,0xF8};
//  Byte byte17[] = {0xAF,0x0A,0x11,0xA2,0xAA,0xF4,0x0F,0x45,0x88,0x86,0x81,0xAE,0x5C,0xAA,0xE8,0x48,0x88,0x41,0x39,0xD5};
//  Byte byte18[] = {0xAF,0x0A,0x12,0xCE,0xF3,0x64,0x67,0x49,0x17,0xFF,0x11,0xA2,0x3B,0x5F,0x47,0x37,0xB3,0xAD,0x86,0x53};
//  Byte byte19[] = {0xAF,0x0A,0x13,0x7B,0x88,0x3E,0x32,0xE3,0x67,0x76,0x7C,0xF3,0xFD,0xE7,0x51,0x5D,0x51,0x2E,0x4D,0x08};
//  Byte byte20[] = {0xAF,0x0A,0x14,0x4C,0xD0,0x2F,0x59,0x25,0x58,0x41,0x9A,0xB2,0xF6,0x73,0x7F,0x2C,0x7A,0x2F,0xF9,0x4F};
//  Byte byte21[] = {0xAF,0x0A,0x15,0x74,0x21,0x03,0x0D,0xF7,0xE1,0x8C,0xEB,0x53,0xB7,0x9F,0xDC,0xD5,0x89,0x07,0xE6,0xC4};
//  Byte byte22[] = {0xAF,0x0A,0x16,0xF3,0xEE,0x4B,0x25,0xC7,0x65,0x24,0x95,0x34,0xCF,0x69,0xBF,0x2F,0x03,0xEE,0x8F,0x3A};
//  Byte byte23[] = {0xAF,0x0A,0x17,0xE9,0x8F,0x33,0x7B,0xF6,0x72,0xF5,0x57,0x27,0x19,0x3D,0x4C,0xEE,0x74,0x59,0xAD,0x2A};
//  Byte byte24[] = {0xAF,0x0A,0x18,0x77,0xB8,0x17,0x80,0xAB,0x25,0x2F,0xB9,0xD4,0xB4,0xF5,0x8D,0x91,0xB7,0xAC,0xD4,0xF4};
//  Byte byte25[] = {0xAF,0x0A,0x19,0x90,0x12,0x82,0xCB,0x16,0x2F,0x12,0xC4,0xBE,0xF7,0xB2,0xFE,0xAE,0x54,0x63,0x44,0xF2};
//  Byte byte26[] = {0xAF,0x0A,0x1A,0xF8,0x21,0x29,0x7A,0xFF,0xA4,0xA7,0x0A,0x5E,0x7B,0xDF,0xA6,0x59,0x3D,0x16,0x39,0xB3};
//  Byte byte27[] = {0xAF,0x0A,0x1B,0xEC,0x28,0x8B,0xA2,0x74,0x4D,0x60,0xA8,0x8D,0x10,0x7F,0x3D,0x3F,0x55,0x05,0xF7,0x7B};
//  Byte byte28[] = {0xAF,0x0A,0x1C,0x00,0x61,0xE1,0x38,0x0F,0xFA,0xEF,0x1C,0x9B,0x4C,0x8A,0x4D,0x20,0xCC,0x93,0x9C,0x57};
//  Byte byte29[] = {0xAF,0x0A,0x1D};
//
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte1 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte2 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte3 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte4 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte5 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte6 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte7 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte8 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte9 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte10 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte11 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte12 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte13 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte14 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte15 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte16 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte17 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte18 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte19 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte20 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte21 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte22 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte23 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte24 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte25 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte26 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte27 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte28 length:20]];
//  [self dealWithReceiveData:[NSData dataWithBytes:&byte29 length:3]];
//
//
//
//}

//- (void)testSend {
//  [self sendDataWithString:@"000100041de2"];
//}

- (void)dealWithReceiveData:(NSData *)value {
//  NSString *str = [self hexStringFromString:value];
//  if (str) {
//    [[NSNotificationCenter defaultCenter] postNotificationName:@"kOnReceiveBluetoothData" object:nil userInfo:@{@"data": str ? str : @""}];
//  }

  if (!self.receiveData.length) {  /// 第一包
    if (value.length > 7) {
      [self.receiveData appendData:[value subdataWithRange:NSMakeRange(7, value.length - 7)]];
    }
  } else if (value.length > 3) {
    [self.receiveData appendData:[value subdataWithRange:NSMakeRange(3, value.length - 3)]];
  }

  if (value.length < 20) {
    NSString *str1 = [self hexStringFromString:self.receiveData];
    NSString *str = [self decryptUseDES:str1 key:@"gwin0801"];
    str = [str stringByReplacingOccurrencesOfString:@"\0" withString:@""];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"kOnReceiveBluetoothData" object:nil userInfo:@{@"data": str ? str : @""}];
    self.receiveData = nil;
  }
}

//- (CBCharacteristic *)getCCWriteChar {
//  CBService *service = [self.curPeripheral.services objectOfObjectsPassingTest:^BOOL(CBService * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//    return [obj.UUID.UUIDString.uppercaseString containsString:bleServiceUUID1];
//  }];
//  if (service) {
//    CBCharacteristic *writeChar = [service.characteristics objectOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//      return [obj.UUID.UUIDString.uppercaseString containsString:bleWriteUUID1];
//    }];
//    return writeChar;
//  }
////  return CBCharacteristic.new;
//  return nil;
//}


- (CBCharacteristic *)getWriteChar {
  CBService *service = [self.curPeripheral.services objectOfObjectsPassingTest:^BOOL(CBService * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
    return [obj.UUID.UUIDString.uppercaseString containsString:self.isEE ? bleServiceUUID : bleServiceUUID1];
  }];
  if (service) {
    CBCharacteristic *writeChar = [service.characteristics objectOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      return [obj.UUID.UUIDString.uppercaseString containsString:self.isEE ? bleWriteUUID : bleWriteUUID1];
    }];
    return writeChar;
  }
//  return CBCharacteristic.new;
  return nil;
}

- (void)sendNext {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if (self.dataArray.count) {
      NSDictionary *dict = self.dataArray.firstObject;
      [self.dataArray removeObjectAtIndex:0];
      self.sending = NO;
      self.isEE = [dict[@"isEE"] boolValue];
      [self sendDataWithDataString:dict[@"data"]];
    } else {
      self.sending = NO;
    }
  });
}

- (void)sendCCDataWithString:(NSString *)value {
//  CBCharacteristic *writeChar = [self getCCWriteChar];
//  if (writeChar) {
//    NSData *data = [self convertHexStrToData:value];
//    [self.curPeripheral writeValue:data forCharacteristic:writeChar type:CBCharacteristicWriteWithResponse];
//  }
  if (self.dataArray.count || self.sending) {
    [self.dataArray addObject:@{@"isEE": @(NO), @"data": value ?: @""}];
  } else {
    self.isEE = NO;
    [self sendDataWithDataString:value];
  }
}

- (void)sendDataWithString:(NSString *)value {
  if (self.dataArray.count || self.sending) {  /// 如果有数据在发送
    [self.dataArray addObject:@{@"isEE": @(YES), @"data": value ?: @""}];
  } else {
    self.isEE = YES;
    [self sendDataWithDataString:value];
  }
}

- (void)sendDataWithDataString:(NSString *)value {
  //  NSString *tips = [NSString stringWithFormat:@"RN需要发送的数据:%@", value];
  //  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:tips preferredStyle:UIAlertControllerStyleAlert];
  //  UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
  //
  //  }];
  //  [alert addAction:action];
  //  [alert showOnWindow];

    
    CBCharacteristic *writeChar = [self getWriteChar];
    if (writeChar) {
      
      self.sending = YES;
      [self resetRandomCount];
      
      Byte bytes[13] = {0x55, 0xAA, 0x01, 0x0E};
      
      NSString *policyStr = [value stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
      
      NSData *lastData = [policyStr dataUsingEncoding:NSUTF8StringEncoding];
      NSMutableData *sendData = [NSMutableData dataWithData:lastData];
      
      uint16_t le2 = [self crcData:sendData];
      NSString *sss = [self ToHex:le2];
      NSData *crc = [self convertHexStrToData:sss];
      
      if (self.needCBC) {  /// 如果是cbc，需要补0
        NSInteger co = sendData.length % 8;
        if (co != 0) {
          for (int i = 0; i < (8 - co); i ++) {
            Byte byte = 0x00;
            [sendData appendBytes:&byte length:1];
          }
        }
      }
      
      policyStr = [[NSString alloc] initWithData:sendData encoding:NSUTF8StringEncoding];
      policyStr = [self encryptUseDES:policyStr key:@"gwin0801"];
  //    sendData = [NSMutableData dataWithData:[policyStr dataUsingEncoding:NSUTF8StringEncoding]];
      self.sendData = [self convertHexStrToData:policyStr];
          
      NSInteger length = self.sendData.length;
      
      NSString *str = [self ToHex:length];
      NSData *data = [self convertHexStrToData:str];
      
      // id
      Byte by1 = self.data1;
      Byte by2 = self.data2;
      bytes[0] = by1;
      bytes[1] = by2;
      
      bytes[2] = 0x01;  /// 序列
      
      // crc
      if (crc.length == 1) {
        bytes[3] = 0x00;
        Byte by;
        [crc getBytes:&by length:1];
        bytes[4] = by;
      } else if (crc.length == 2) {
        Byte by1, by2;
        [crc getBytes:&by1 range:NSMakeRange(0, 1)];
        [crc getBytes:&by2 range:NSMakeRange(1, 1)];
        bytes[3] = by1;
        bytes[4] = by2;
      }

      Byte b1, b2;
      NSData *len = [self convertHexStrToData:[self ToHex:value.length]];
      if (len.length > 1) {
          [len getBytes:&b1 range:NSMakeRange(0, 1)];
          [len getBytes:&b2 range:NSMakeRange(1, 1)];
        bytes[5] = b1;
        bytes[6] = b2;
      } else {
          [len getBytes:&b2 range:NSMakeRange(0, 1)];
        bytes[5] = 0x00;
        bytes[6] = b2;
      }

  //    // 长度
  //    if (data.length == 1) {
  //      bytes[5] = 0x00;
  //      Byte by;
  //      [data getBytes:&by length:1];
  //      bytes[6] = by;
  //    } else if (data.length == 2) {
  //      Byte by1, by2;
  //      [data getBytes:&by1 range:NSMakeRange(0, 1)];
  //      [data getBytes:&by2 range:NSMakeRange(1, 1)];
  //      bytes[5] = by1;
  //      bytes[6] = by2;
  //    }
          
      NSMutableData *firstData = [NSMutableData dataWithData:[NSData dataWithBytes:&bytes length:7]];
      
      if (self.sendData.length == 13) {  /// 只有一个包，发送空包
        [firstData appendData:self.sendData];
        [self sendDataWith:firstData];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          Byte bytes[3];
          bytes[0] = self.data1;
          bytes[1] = self.data2;
          bytes[2] = 0x02;
          NSData *finish = [NSData dataWithBytes:&bytes length:3];
          [self sendDataWith:finish];
          [self sendNext];
        });
      } else if (self.sendData.length > 13) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          [firstData appendData:[self.sendData subdataWithRange:NSMakeRange(0, 13)]];
          [self sendDataWith:firstData];
          
          NSData *otherData = [self.sendData subdataWithRange:NSMakeRange(13, self.sendData.length - 13)];
          
          [self sendData:[NSMutableData dataWithData:otherData]];
        });
      } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          [firstData appendData:self.sendData];
          [self sendDataWith:firstData];
          [self sendNext];
        });
      }
    }
}

- (void)setDeviceNetworkFailed:(NSError *)error {
//  if (_blockOnConnect) {
//    _blockOnConnect(nil, error);
//  }
}

- (void)sendData:(NSMutableData *)sendData {
  NSInteger count = sendData.length / 17;
  if (sendData.length % 17 > 0) {
    count ++;
  }
  
  int delay = 1;
  for (int i = 0; i < count; i ++) {
    NSMutableData *data = [NSMutableData data];
    
    Byte data1 = self.data1;
    Byte data2 = self.data2;
    
    [data appendBytes:&data1 length:1];
    [data appendBytes:&data2 length:1];
    NSString *dataId = [self ToHex:i + 2];
    NSData *da = [self convertHexStrToData:dataId];
    Byte b3;
    [da getBytes:&b3 length:1];
    [data appendBytes:&b3 length:1];
    
    BOOL needSendFinish = NO;
    if (sendData.length > 17) {
        [data appendData: [NSMutableData dataWithData:[sendData subdataWithRange:NSMakeRange(0, 17)]]];
      [sendData replaceBytesInRange:NSMakeRange(0, 17) withBytes:nil length:0];
    } else if (sendData.length == 17) {
      [data appendData:sendData];
      [sendData replaceBytesInRange:NSMakeRange(0, 17) withBytes:nil length:0];
      needSendFinish = YES;
    } else {
      [data appendData:sendData];
      sendData = nil;
//      [self sendNext];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [self sendDataWith:data];
      
      if (sendData.length < 17) {
        [self sendNext];
      }
      if (needSendFinish) {  /// 结束
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          Byte bytes[3];
          bytes[0] = self.data1;
          bytes[1] = self.data2;
          NSString *dataId = [self ToHex:i + 3];
          NSData *da = [self convertHexStrToData:dataId];
          Byte b3;
          [da getBytes:&b3 length:1];
          bytes[2] = b3;
          NSData *finish = [NSData dataWithBytes:&bytes length:3];
          [self sendDataWith:finish];
          
          [self sendNext];
        });
      }
    });
    
    delay ++;
  }
}

- (void)resetRandomCount {
  static int count = 1;
  if (count > 65535) {
    count = 1;
  }
  self.randomCount = count;
  count ++;
  [self configDataId];
}

- (void)configDataId {
  NSString *dataId = [self ToHex:self.randomCount];
  NSData *da = [self convertHexStrToData:dataId];
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

- (NSString *) encryptUseDES:(NSString *)clearText key:(NSString *)key {
  NSInteger bufferSize = 1024;
  NSData *data = [clearText dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
  unsigned char buffer[bufferSize];  //注意空间大小
  memset(buffer, 0, sizeof(char));
  size_t numBytesEncrypted = 0;
  
  CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt,
                                        kCCAlgorithmDES,
                                        kCCOptionPKCS7Padding,
                                        //                                          kCCOptionPKCS7Padding | kCCOptionECBMode,
                                        [key UTF8String],
                                        kCCKeySizeDES,
                                        [key UTF8String],
                                        //                                          nil,
                                        [data bytes],
                                        [data length],
                                        buffer,
                                        bufferSize,  //注意空间大小
                                        &numBytesEncrypted);
  
  NSString* plainText = nil;
  if (cryptStatus == kCCSuccess) {
    NSData *dataTemp = [NSData dataWithBytes:buffer length:(NSUInteger)data.length];
    
    //转化为byte
    Byte *byte = (Byte *)[dataTemp bytes];
    
    NSUInteger len = [dataTemp length];
    
    plainText = [self toHexString:byte size:len];
    
    //plainText = [dataTemp base64EncodedString];
  }else{
    //NSLog(@"DES加密失败");
  }
  return plainText;
}

- (NSString *)decryptUseDES:(NSString *)cipherText key:(NSString *)key {
  NSData *cipherData = [self convertHexStrToData:cipherText];
  unsigned char buffer[1024];
  memset(buffer, 0, sizeof(char));
  size_t numBytesDecrypted = 0;
  CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmDES, kCCOptionPKCS7Padding, [key UTF8String], kCCKeySizeDES, [key UTF8String], [cipherData bytes], [cipherData length], buffer, 1024, &numBytesDecrypted);
  NSString *plainText = nil;
  if (cryptStatus == kCCSuccess) {
    NSData *data = [NSData dataWithBytes:buffer length:(NSUInteger)numBytesDecrypted];
//    plainText = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//    if (!plainText) {
      plainText = [self hexStringFromString:data];
//    }
  }
  return plainText;
}



- (NSString *)hexStringFromString:(NSData *)data{
  Byte *bytes = (Byte *)[data bytes];
  //下面是Byte转换为16进制。
  NSString *hexStr=@"";
  for(int i=0;i<[data length];i++){
    NSString *newHexStr = [NSString stringWithFormat:@"%x",bytes[i]&0xff];///16进制数
    if([newHexStr length]==1)
      hexStr = [NSString stringWithFormat:@"%@0%@",hexStr,newHexStr];
    else
      hexStr = [NSString stringWithFormat:@"%@%@",hexStr,newHexStr];
  }
  return hexStr;
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

- (unsigned short)crcData:(NSData *)data {
  int start = 0; //选择数据要计算CRC的起始位
  int end = (uint16_t)[data length]; //选择数据要CRC计算的范围段
  
  unsigned short  crc = 0xffff; // initial value
  unsigned short  polynomial = 0x1021; // poly value
  Byte codeKeyByteAry[data.length];
  for (int i = 0 ; i < data.length; i++) {
    NSData *idata = [data subdataWithRange:NSMakeRange(i, 1)];
    codeKeyByteAry[i] =((Byte*)[idata bytes])[0];
  }
  for (int index = start; index < end; index++){
    Byte b = codeKeyByteAry[index];
    for (int i = 0; i < 8; i++) {
      Boolean bit = ((b >> (7 - i) & 1) == 1);
      Boolean c15 = ((crc >> 15 & 1) == 1);
      crc <<= 1;
      if (c15 ^ bit)
        crc ^= polynomial;
    }
  }
  crc &= 0xffff;
  return crc;
}

- (Byte)CalCheckSum:(NSData *)data {
  Byte chksum = 0;
  Byte *byte = (Byte *)[data bytes];
  for (int i = 0; i < data.length; i ++) {
    chksum += byte[i];
  }
  return chksum;
}

- (void)sendDataWith:(NSData *)data {
  NSLog(@"发送数据:%@", data);

  
  if ([self getWriteChar]) {
//    NSString *str = [NSString stringWithFormat:@"发送数据%@", data];
//    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:str preferredStyle:UIAlertControllerStyleAlert];
//    UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
//
//    }];
//    [alert addAction:action];
//    [alert showOnWindow];

    [self.curPeripheral writeValue:data forCharacteristic:[self getWriteChar] type:CBCharacteristicWriteWithResponse];
  }
}

- (void)startActionWithType:(int)type data:(int)data {
    if (data > 65535) {
        data = 65535;
    }
    Byte b1, b2;
    NSData *value = [self convertHexStrToData:[self ToHex:data]];
    if (value.length > 1) {
        [value getBytes:&b1 range:NSMakeRange(0, 1)];
        [value getBytes:&b2 range:NSMakeRange(1, 1)];
    } else {
        b1 = 0x00;
        [value getBytes:&b2 range:NSMakeRange(0, 1)];
    }
    
    Byte bytes[4] = {0x03};
    switch (type) {
        case 0:
            bytes[1] = 0x01;
            bytes[2] = 0x00;
            bytes[3] = 0x00;
            break;
        case 1:
            bytes[1] = 0x02;
            bytes[2] = b1;
            bytes[3] = b2;
            break;
        case 2:
            bytes[1] = 0x03;
            bytes[2] = b1;
            bytes[3] = b2;
            break;
    }
    NSData *sendData = [NSData dataWithBytes:bytes length:4];
    [self sendDataWith:sendData];
    
//    NSString *sendStr = [self hexStringFromString:sendData];
//    sendStr = [self encryptUseDES:sendStr key:@"gwin0801"];
//    sendData = [self convertHexStrToData:sendStr];
//    NSLog(@"%@", sendData);
}

//字典转json格式字符串：
- (NSString*)dictionaryToJson:(NSDictionary *)dic {
  NSError *parseError = nil;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
  
  return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

//json格式字符串转字典：
- (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString {
  if (jsonString == nil) {
    return nil;
  }
  
  NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
  NSError *err;
  NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                      options:NSJSONReadingMutableContainers
                                                        error:&err];
  if (err) {
    NSLog(@"json解析失败：%@",err);
    return nil;
  }
  
  return dic;
}

- (void)showTips:(NSString *)tips {
  [[NSNotificationCenter defaultCenter] postNotificationName:@"kOnLinkState" object:nil userInfo:@{@"data": tips ? : @""}];
  NSLog(@"%@", tips);
      NSString *str = [NSString stringWithFormat:@"%@", tips];
      UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:str preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {

      }];
      [alert addAction:action];
      [alert showOnWindow];
//  [MNTipsManager showTips:tips];
}

- (NSMutableArray *)deviceArray {
  if (!_deviceArray) {
    _deviceArray = NSMutableArray.new;
  }
  return _deviceArray;
}

- (NSMutableData *)receiveData {
  if (!_receiveData) {
    _receiveData = NSMutableData.new;
  }
  return _receiveData;
}

- (NSMutableArray *)recordArray {
  if (!_recordArray) {
    _recordArray = NSMutableArray.new;
  }
  return _recordArray;
}

- (NSMutableArray *)dataArray {
  if (!_dataArray) {
    _dataArray = NSMutableArray.new;
  }
  return _dataArray;
}

@end
