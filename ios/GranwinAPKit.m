//
//  GranwinAPKit.m
//  GranwinAPKit
//
//  Created by (╹◡╹) on 2019/5/7.
//  Copyright © 2019 granwin. All rights reserved.
//

#import "GranwinAPKit.h"
#import <UIKit/UIKit.h>
#import "GWGCDTimer.h"
#import "NSArray+Tools.h"

#import <arpa/inet.h>
#import <NetworkExtension/NEHotspotConfigurationManager.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import "GCDAsyncUdpSocket.h"
#import <CoreBluetooth/CoreBluetooth.h>
#include <CommonCrypto/CommonCryptor.h>
#import<CommonCrypto/CommonDigest.h>

#import "UIAlertController+showOnWindow.h"

//
//static NSString *bleServiceUUID = @"0000ff01-0000-1000-8000-00805f9b34fb";
//static NSString *bleReadUUID = @"0000ff02-0000-1000-8000-00805f9b34fb";
//static NSString *bleWriteUUID = @"0000ff03-0000-1000-8000-00805f9b34fb";

static NSString *bleServiceUUID = @"ff01";
static NSString *bleReadUUID = @"ff02";
static NSString *bleWriteUUID = @"ff03";

//static NSString *bleServiceUUID = @"ee01";
//static NSString *bleReadUUID = @"ee02";
//static NSString *bleWriteUUID = @"ee03";

@interface GranwinAPKit ()<NSNetServiceBrowserDelegate, NSNetServiceDelegate, GCDAsyncUdpSocketDelegate, CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, copy) NSString *appId;
@property (nonatomic, copy) NSString *appSecret;

@property (nonatomic, strong) NSNetServiceBrowser *browser;
@property (nonatomic, strong) NSNetService *curService;
@property (nonatomic, strong) NSURLSessionDataTask *task;

@property (nonatomic, copy) NSString *ssid;
@property (nonatomic, copy) NSString *pwd;
@property (nonatomic, copy) GWCallBack *setDeviceNetworkCallBack;

@property (nonatomic, strong) GWGCDTimer *timeoutTimer;

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, assign) GWBleOperation bleOperation;
@property (nonatomic, strong) CBPeripheral *curPeripheral;

@property (nonatomic, assign) NSInteger configuraWiFiRetryTime;
@property (nonatomic, strong) GCDAsyncUdpSocket *udpSocket;

@property (nonatomic, copy) NSString *bleName;
@property (nonatomic, copy) NSString *configUrl;
@property (nonatomic, copy) NSString *deviceToken;

@property (nonatomic, assign) int randomCount;   ///<   随机数
@property (nonatomic, strong) NSMutableData *sendData;    ///< 发送的数据
@property (nonatomic, assign) int recvCount;    ///< 接受包数量
@property (nonatomic, assign) Byte data1;    ///< 数据
@property (nonatomic, assign) Byte data2;    ///< 数据
@property (nonatomic, assign) BOOL needCBC;    ///< 需要加密
@property (nonatomic, assign) BOOL sending;    ///< 正在发送
@property (nonatomic, strong) NSMutableArray *dataArray;    ///< 发送
@property (nonatomic, strong) NSMutableData *receiveData;    ///< receiveData

@end

@implementation GranwinAPKit

+ (GranwinAPKit *)shared {
  static GranwinAPKit *granwinAPKit = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    granwinAPKit = [[GranwinAPKit alloc] init];
    granwinAPKit.needCBC = YES;
  });
  return granwinAPKit;
}

- (void)showTips:(NSString *)tips completion:(void(^)(void))completion {
      NSString *str = [NSString stringWithFormat:@"%@", tips];
      UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:str preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (completion) {
          completion();
        }
      }];
      [alert addAction:action];
      [alert showOnWindow];
}

- (void)start {
  _appId = @"Default";
  _appSecret = @"Default";
  _deviceToken = @"";
  _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

#pragma mark - 蓝牙部分
- (void)bleSetDeviceNetwork:(NSString *)wifiSSID
               wifiPassword:(NSString *)wifiPassword
                    bleName:(NSString *)bleName
                  configURL:(NSString *)url
                  didFinish:(GWCallBack<GWDevice *> *)callBack {
  NSLog(@"bleSetDeviceNetwork:%@,%@,%@,%@", wifiSSID, wifiPassword, bleName, url);
  if (!self.appId.length || !self.appSecret.length) {
    NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeNoStart userInfo:@{NSLocalizedDescriptionKey : @"SDK未启动"}];
    callBack.onFailed(err);
  } else {
    _ssid = wifiSSID;
    _pwd = wifiPassword ?: @"";
    _bleName = bleName.copy;
    _configUrl = url.copy;
    _setDeviceNetworkCallBack = callBack;
    
    switch (self.centralManager.state) {
      case CBManagerStateUnknown: {
        _bleOperation = GWBleOperationScan;
        
        _ssid = wifiSSID;
        _pwd = wifiPassword ?: @"";
        _setDeviceNetworkCallBack = callBack;
      } break;
      case CBManagerStateResetting:
      case CBManagerStateUnsupported:
      case CBManagerStateUnauthorized:
      case CBManagerStatePoweredOff: {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
          NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeBlePwoerOff userInfo:@{NSLocalizedDescriptionKey : @"未开启蓝牙"}];
          callBack.onFailed(err);
        }];
      } break;
      case CBManagerStatePoweredOn: {
        _bleOperation = GWBleOperationScan;
        
        [self startScanBleDevice];
      }
        break;
    }
  }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
  switch (central.state) {
    case CBManagerStateUnknown: {
      
    } break;
    case CBManagerStateResetting:
    case CBManagerStateUnsupported:
    case CBManagerStateUnauthorized:
    case CBManagerStatePoweredOff: {
      if (self.bleOperation != GWBleOperationNone) {
        __weak typeof(self) weakSelf = self;
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
          NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeBlePwoerOff userInfo:@{NSLocalizedDescriptionKey : @"未开启蓝牙"}];
          weakSelf.bleOperation = GWBleOperationNone;
          weakSelf.setDeviceNetworkCallBack.onFailed(err);
        }];
      }
    } break;
    case CBManagerStatePoweredOn: {
      if (self.bleOperation == GWBleOperationScan) {
        [self startScanBleDevice];
      }
    }
      break;
    default:
      break;
  }
}

- (void)startScanBleDevice {
  if (self.timeoutTimer) {
    [self.timeoutTimer invalidate];
  }
  __weak typeof(self) weakSelf = self;
  _timeoutTimer = [GWGCDTimer scheduledTimerWithTimeInterval:20 repeats:NO queue:dispatch_get_global_queue(0, 0) block:^{
    weakSelf.bleOperation = GWBleOperationNone;
    [weakSelf.centralManager stopScan];
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
      NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"扫描蓝牙设备超时"}];
      weakSelf.setDeviceNetworkCallBack.onFailed(err);
    }];
  }];
  
  [self.centralManager scanForPeripheralsWithServices:nil options:nil];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
  NSLog(@"%@", peripheral.name);
  if ([peripheral.name containsString:self.bleName]) {
    [central stopScan];
    _bleOperation = GWBleOperationConnecting;
    _curPeripheral = peripheral;
    [self.timeoutTimer invalidate];
    
    __weak typeof(self) weakSelf = self;
    _timeoutTimer = [GWGCDTimer scheduledTimerWithTimeInterval:50 repeats:NO queue:dispatch_get_global_queue(0, 0) block:^{
      weakSelf.bleOperation = GWBleOperationNone;
      if (weakSelf.curPeripheral) {
        [weakSelf.centralManager cancelPeripheralConnection:weakSelf.curPeripheral];
      }
      [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备超时"}];
        weakSelf.setDeviceNetworkCallBack.onFailed(err);
      }];
    }];
    [central connectPeripheral:peripheral options:nil];
  }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
  peripheral.delegate = self;
  [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
  NSLog(@"设备断开连接");
//  [self showTips:[NSString stringWithFormat:@"%@", error] completion:^{
    if (self.bleOperation == GWBleOperationConnecting ||
        self.bleOperation == GWBleOperationConnected) {
      NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备失败"}];
      [self setDeviceNetworkFailed:err];
    }
//  }];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
  if (error) {
    NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备获取服务失败"}];
    [self setDeviceNetworkFailed:err];
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
      [self setDeviceNetworkFailed:err];
      NSLog(@"获取服务失败");
    }
  }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
  if (error) {
    NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备获取特征值失败"}];
    [self setDeviceNetworkFailed:err];
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
      [self setDeviceNetworkFailed:err];
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
    [self sendConfigureWifiData];
    if (self.timeoutTimer) {
      [self.timeoutTimer invalidate];
    }
    //        [peripheral readValueForCharacteristic:characteristic];
    //
    _configuraWiFiRetryTime = 20;
    __weak typeof(self) weakSelf = self;
    _timeoutTimer = [GWGCDTimer scheduledTimerWithTimeInterval:1 repeats:YES queue:dispatch_get_global_queue(0, 0) block:^{
      //            if (weakSelf.configuraWiFiRetryTime == 0) {
      //                [weakSelf.timeoutTimer invalidate];
      //                NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeConfigureWiFiFailed userInfo:@{NSLocalizedDescriptionKey : @"重试了5次，蓝牙发送数据配置WiFi无响应，失败"}];
      //                [weakSelf setDeviceNetworkFailed:err];
      //            } else if (weakSelf.configuraWiFiRetryTime > 0) {
      //                weakSelf.configuraWiFiRetryTime--;
      //                [weakSelf sendConfigureWifiData];
      //            }
      weakSelf.configuraWiFiRetryTime --;
      if (weakSelf.configuraWiFiRetryTime <= 0) {
        [weakSelf.timeoutTimer invalidate];
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeConfigureWiFiFailed userInfo:@{NSLocalizedDescriptionKey : @"蓝牙发送数据配置WiFi无响应，失败"}];
        [weakSelf setDeviceNetworkFailed:err];
      }
    }];
    
  } else {
    NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeTimeout userInfo:@{NSLocalizedDescriptionKey : @"连接蓝牙设备打开通知失败"}];
    [self setDeviceNetworkFailed:err];
    NSLog(@"打开通知失败");
  }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error {
  NSLog(@"特征值变化：%@", characteristic.value);
  NSData *value = characteristic.value;
  
  [self dealWithReceiveData:value];
  
  //
  //    static int step = 0;
  //    NSData *data = characteristic.value;
  //    if (data) {
  //        Byte status = 0x00;
  //        Byte start1 = 0x00, start2 = 0x00;
  //        if (data.length > 7) {
  //            [data getBytes:&status range:NSMakeRange(6, 1)];
  //            [data getBytes:&start1 range:NSMakeRange(0, 1)];
  //            [data getBytes:&start2 range:NSMakeRange(1, 1)];
  //        }
  //        if (start1 == 0x55 && start2 == 0xaa) {
  //                if (data.length == 9 && status == 0x01) {
  //                    step ++;
  //                    [self sendData:self.sendData];
  //                } else if (data.length == 9 && status == 0x02) {
  //                    step ++;
  //                } else if (data.length == 13 && step == 2) {  /// 准备发送mac
  //                    step ++;
  //                    Byte count;
  //                    [data getBytes:&count range:NSMakeRange(8, 1)];
  //
  //                    char bytes[]= {0x00, count};
  //                    unsigned char by1 = (bytes[0] &0xff);//高8位
  //                    unsigned char by2 = (bytes[1] &0xff);//低8位
  //
  //                    int temp = (by2 | (by1<<8));
  //                    self.recvCount = temp;
  //
  //                    Byte dataId1, dataId2;
  //                    [data getBytes:&dataId1 range:NSMakeRange(6, 1)];
  //                    [data getBytes:&dataId2 range:NSMakeRange(7, 1)];
  //
  //                    Byte sendBytes[9] = {0x55, 0xAA, 0x01, 0x0E, dataId1, dataId2, 0x01};
  //                    NSData *subData = [NSData dataWithBytes:sendBytes length:7];
  //                    Byte sum = [self CalCheckSum:subData];
  //                    sendBytes[7] = (Byte)(sum & 0x00ff);
  //                    sendBytes[8] = 0xFE;
  //
  //                    NSData *firstData = [NSData dataWithBytes:&sendBytes length:9];
  //                    [self sendDataWith:firstData];
  //    //                [self.curPeripheral writeValue:firstData forCharacteristic:[self getWriteChar] type:CBCharacteristicWriteWithResponse];
  //                }
  //        } else if (step == 3) {
  //            static NSMutableData *recvData;
  //            if (!recvData) {
  //                recvData = [NSMutableData data];
  //            }
  //
  //            Byte start1 = 0x00, start2 = 0x00;
  //            if (data.length > 3) {
  //                if (data.length > 7) {
  //                    [data getBytes:&start1 range:NSMakeRange(0, 1)];
  //                    [data getBytes:&start2 range:NSMakeRange(1, 1)];
  //                }
  //                [recvData appendData:[data subdataWithRange:NSMakeRange(3, data.length - 3)]];
  //            } else {
  //                return;
  //            }
  //
  //            static int count = 1;
  //            if (count == self.recvCount) {
  //                step = 0;
  ////                55 AA 01 0E 6F 10 02 8F FE
  //                Byte sendBytes[9] = {0x55, 0xAA, 0x01, 0x0E, start1, start2, 0x02};
  //                NSData *subData = [NSData dataWithBytes:sendBytes length:7];
  //                Byte sum = [self CalCheckSum:subData];
  //                sendBytes[7] = (Byte)(sum & 0x00ff);
  //                sendBytes[8] = 0xFE;
  //
  //                NSData *firstData = [NSData dataWithBytes:&sendBytes length:9];
  //                [self.curPeripheral writeValue:firstData forCharacteristic:[self getWriteChar] type:CBCharacteristicWriteWithResponse];
  //
  //                NSString *str1 =[[ NSString alloc] initWithData:recvData encoding:NSUTF8StringEncoding];
  //                NSString *str = [self decryptUseDES:str1 key:@"gwin0801"];
  //                str = [str stringByReplacingOccurrencesOfString:@"\0" withString:@""];
  //
  //                NSDictionary *recvDic = [NSJSONSerialization JSONObjectWithData:[str dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
  //                if ([recvDic[@"CID"] integerValue] == 30006) {
  //                    _bleOperation = GWBleOperationNone;
  //                    _curPeripheral = nil;
  //                    _configuraWiFiRetryTime = -1;
  //                    [self.timeoutTimer invalidate];
  //
  //                  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
  //                    [self.centralManager cancelPeripheralConnection:peripheral];
  //                  });
  //
  //                  __weak typeof(self) weakSelf = self;
  //                  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
  //                    GWDevice *device = [[GWDevice alloc] initWithDictionary:recvDic];
  //                    weakSelf.setDeviceNetworkCallBack.onSuccess(device);
  //                  }];
  //                }
  //                recvData = nil;
  //                count = 1;
  //            } else {
  //                count ++;
  //            }
  //        }
  //    }
}

- (void)dealWithReceiveData:(NSData *)value {
  if (!self.receiveData.length) {  /// 第一包
    if (value.length > 7) {
      Byte byte;
      [value getBytes:&byte range:NSMakeRange(2, 1)];
      if (byte != 0x01) {
        return;
      }
      [self.receiveData appendData:[value subdataWithRange:NSMakeRange(7, value.length - 7)]];
    }
  } else if (value.length > 3) {
    [self.receiveData appendData:[value subdataWithRange:NSMakeRange(3, value.length - 3)]];
  }
  
  if (value.length < 20) {
    NSString *str1 = [self hexStringFromString:self.receiveData];
    NSString *str = [self decryptUseDES:str1 key:@"gwin0801"];
    str = [str stringByReplacingOccurrencesOfString:@"\0" withString:@""];
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    
    if (!data) {
//      [self showTips:[NSString stringWithFormat:@"接收到数据:%@ 解密字符串:%@", value, str] completion:^{
//
//      }];
      self.receiveData = nil;
      return;
    }
    NSDictionary *recvDic = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
//    [self showTips:[NSString stringWithFormat:@"收到数据：%@\n解密：%@\n转字典：%@", value, str, recvDic] completion:^{
//
//    }];

    if ([recvDic[@"CID"] integerValue] == 30006) {
      _receiveData = nil;
      _bleOperation = GWBleOperationNone;
      _configuraWiFiRetryTime = -1;
      [self.timeoutTimer invalidate];
      
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.curPeripheral) {
          [self.centralManager cancelPeripheralConnection:self.curPeripheral];
          self.curPeripheral = nil;
        }
      });
      
      __weak typeof(self) weakSelf = self;
      [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        GWDevice *device = [[GWDevice alloc] initWithDictionary:recvDic];
        weakSelf.setDeviceNetworkCallBack.onSuccess(device);
      }];
    }
    
  }
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

- (void)sendConfigureWifiData {
  CBCharacteristic *writeChar = [self getWriteChar];
  if (writeChar) {
    NSDictionary *sendDataDic = @{
      @"CID" : @(30005),
      @"URL" : self.configUrl,
      @"PL" : @{
        @"SSID": self.ssid,
        @"Password": self.pwd
      },
    };
    
    //        NSDictionary *sendDataDic = @{
    //            @"CID" : @(30005),
    //            @"URL" : self.configUrl,
    //            @"PL" : @{
    //                @"Password": @"1234567890",
    //                @"SSID": @"AppDev"
    //            }
    //        };
    
    
    NSLog(@"发送数据:%@", sendDataDic);
    
    NSMutableData *sendData = [NSJSONSerialization dataWithJSONObject:sendDataDic options:0 error:nil].mutableCopy;
    self.sendData = sendData;
    
    NSString *policyStr = [[NSString alloc] initWithData:sendData encoding:NSUTF8StringEncoding];
    policyStr = [policyStr stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
//    [self showTips:[NSString stringWithFormat:@"原始数据：%@", sendDataDic] completion:^{
//    }];
    [self sendDataWithString:policyStr];
    
    //
    //        [self resetRandomCount];
    //
    //        Byte bytes[13] = {0x55, 0xAA, 0x01, 0x0E};
    //
    //        NSMutableData *sendData = [NSJSONSerialization dataWithJSONObject:sendDataDic options:0 error:nil].mutableCopy;
    //        self.sendData = sendData;
    //
    //        NSString *policyStr = [[NSString alloc] initWithData:sendData encoding:NSUTF8StringEncoding];
    //        policyStr = [policyStr stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
    //
    //        NSData *lastData = [policyStr dataUsingEncoding:NSUTF8StringEncoding];
    //        sendData = [NSMutableData dataWithData:lastData];
    //
    //        uint16_t le2 = [self crcData:sendData];
    //        NSString *sss = [self ToHex:le2];
    //        NSData *crc = [self convertHexStrToData:sss];
    //
    //        if (self.needCBC) {  /// 如果是cbc，需要补0
    //            NSInteger co = sendData.length % 8;
    //            if (co != 0) {
    //                for (int i = 0; i < (8 - co); i ++) {
    //                    Byte byte = 0x00;
    //                    [sendData appendBytes:&byte length:1];
    //                }
    //            }
    //        }
    //
    //        policyStr = [[NSString alloc] initWithData:sendData encoding:NSUTF8StringEncoding];
    //        policyStr = [self encryptUseDES:policyStr key:@"gwin0801"];
    //        sendData = [NSMutableData dataWithData:[policyStr dataUsingEncoding:NSUTF8StringEncoding]];
    //        self.sendData = sendData;
    //        NSInteger length = self.sendData.length;
    //
    //        NSString *str = [self ToHex:length];
    //        NSData *data = [self convertHexStrToData:str];
    //
    //        if (data.length == 1) {
    //            bytes[4] = 0x00;
    //            Byte by;
    //            [data getBytes:&by length:1];
    //            bytes[5] = by;
    //        } else if (data.length == 2) {
    //            Byte by1, by2;
    //            [data getBytes:&by1 range:NSMakeRange(0, 1)];
    //            [data getBytes:&by2 range:NSMakeRange(1, 1)];
    //            bytes[4] = by1;
    //            bytes[5] = by2;
    //        }
    //
    //        Byte by1 = self.data1;
    //        Byte by2 = self.data2;
    //        bytes[6] = by1;
    //        bytes[7] = by2;
    //
    //        NSInteger count = sendData.length / 17;
    //        if (sendData.length % 17 > 0) {
    //            count ++;
    //        }
    //        NSData *countData = [self convertHexStrToData: [self ToHex:count]];
    //        Byte countBtye;
    //        [countData getBytes:&countBtye range:NSMakeRange(0, 1)];
    //        bytes[8] = countBtye;
    //
    ////        uint16_t le2 = [self crcData:sendData];
    ////        NSString *sss = [self ToHex:le2];
    ////        NSData *crc = [self convertHexStrToData:sss];
    //
    //        if (crc.length == 1) {
    //            bytes[9] = 0x00;
    //            Byte by;
    //            [crc getBytes:&by length:1];
    //            bytes[10] = by;
    //        } else if (crc.length == 2) {
    //            Byte by1, by2;
    //            [crc getBytes:&by1 range:NSMakeRange(0, 1)];
    //            [crc getBytes:&by2 range:NSMakeRange(1, 1)];
    //            bytes[9] = by1;
    //            bytes[10] = by2;
    //        }
    //
    //        NSData *subData = [NSData dataWithBytes:bytes length:11];
    //
    //        Byte sum = [self CalCheckSum:subData];
    //
    //        bytes[11] = (Byte)(sum & 0x00ff);
    //        bytes[12] = 0xFE;
    //
    //        NSData *firstData = [NSData dataWithBytes:&bytes length:13];
    //        [self sendDataWith:firstData];
    ////        [self.curPeripheral writeValue:firstData forCharacteristic:writeChar type:CBCharacteristicWriteWithResponse];
  }
}


- (void)sendDataWithString:(NSString *)value {
  CBCharacteristic *writeChar = [self getWriteChar];
  if (writeChar) {
    if (self.dataArray.count || self.sending) {  /// 如果有数据在发送
      [self.dataArray addObject:value];
      return;
    }
    
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
    
    NSString *tips = [NSString stringWithFormat:@"%@", policyStr];
    
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
    
//    [self showTips:[NSString stringWithFormat:@"原始：%@\n加密：%@\n转data：%@", tips, policyStr, self.sendData] completion:^{
//
//    }];
    
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
      [firstData appendData:[self.sendData subdataWithRange:NSMakeRange(0, 13)]];
      [self sendDataWith:firstData];
      
      NSData *otherData = [self.sendData subdataWithRange:NSMakeRange(13, self.sendData.length - 13)];
      
      [self sendData:[NSMutableData dataWithData:otherData]];
    } else {
      [firstData appendData:self.sendData];
      [self sendDataWith:firstData];
      [self sendNext];
    }
  }
}

- (void)sendNext {
  if (self.dataArray.count) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      NSString *str = self.dataArray.firstObject;
      [self.dataArray removeObjectAtIndex:0];
      self.sending = NO;
      [self sendDataWithString:str];
    });
  } else {
    self.sending = NO;
  }
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
      [self sendNext];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [self sendDataWith:data];
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
    plainText = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
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

- (NSString *) toHexString:(Byte*)byte size:(NSInteger)size {
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

//
//- (void)sendData:(NSMutableData *)sendData {
//    NSInteger count = sendData.length / 17;
//    if (sendData.length % 17 > 0) {
//        count ++;
//    }
//
//    int delay = 1;
//    for (int i = 0; i < count; i ++) {
//        NSMutableData *data = [NSMutableData data];
//
//        Byte data1 = self.data1;
//        Byte data2 = self.data2;
//
//        [data appendBytes:&data1 length:1];
//        [data appendBytes:&data2 length:1];
//        NSString *dataId = [self ToHex:i + 1];
//        NSData *da = [self convertHexStrToData:dataId];
//        Byte b3;
//        [da getBytes:&b3 length:1];
//        [data appendBytes:&b3 length:1];
////
//        if (sendData.length > 17) {
//////            data = [NSMutableData dataWithData:[sendData subdataWithRange:NSMakeRange(0, 17)]];
//            for (int j = 0; j < 17; j ++) {
//                Byte bytes;
//                [sendData getBytes:&bytes range:NSMakeRange(j, 1)];
//                [data appendBytes:&bytes length:1];
//            }
//            [sendData replaceBytesInRange:NSMakeRange(0, 17) withBytes:nil length:0];
//        } else {
//            for (int j = 0; j < sendData.length; j ++) {
//                Byte bytes;
//                [sendData getBytes:&bytes range:NSMakeRange(j, 1)];
//                [data appendBytes:&bytes length:1];
//            }
//////            data = sendData;
//            sendData = nil;
//        }
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            [self sendDataWith:data];
////            [self.curPeripheral writeValue:data forCharacteristic:[self getWriteChar] type:CBCharacteristicWriteWithResponse];
//        });
//        delay ++;
//    }
//}

- (void)resetRandomCount {
  static int count = 1;
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
  if (data) {
    [self.curPeripheral writeValue:data forCharacteristic:[self getWriteChar] type:CBCharacteristicWriteWithResponse];
  }
}

#pragma mark - 连接热点部分
- (void)connectDeviceHot:(NSString *)deviceHot hotPassword:(NSString *)pwd didFinish:(GWCallBack *)callBack {
  if (!self.appId.length || !self.appSecret.length) {
    NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeNoStart userInfo:@{NSLocalizedDescriptionKey : @"SDK未启动"}];
    callBack.onFailed(err);
  } else {
    /// 启动网络监听
    
    
    __weak typeof(self) weakSelf = self;
    if (@available(iOS 11.0, *)) {
      NEHotspotConfiguration *hotspotConfig;
      
      if (pwd.length) {
        //加入有密码的wifi
        hotspotConfig = [[NEHotspotConfiguration alloc] initWithSSID:deviceHot passphrase:pwd isWEP:NO];
      } else{
        //加入没有密码的wifi
        hotspotConfig = [[NEHotspotConfiguration alloc]initWithSSID:deviceHot];
      }
      
      // 开始连接 (调用此方法后系统会自动弹窗确认)
      [[NEHotspotConfigurationManager sharedManager] applyConfiguration:hotspotConfig completionHandler:^(NSError * _Nullable error) {
        NSLog(@"%@",error);
        if (error) {
          if (error.code == 13) { //已连接
            callBack.onSuccess(nil);
          } else {
            callBack.onFailed(error);
          }
        } else {
          if ([deviceHot isEqualToString:[weakSelf getWiFiSSID]]) {
            callBack.onSuccess(nil);
          } else {
            callBack.onFailed(nil);
          }
        }
      }];
    } else {
      // Fallback on earlier versions
      NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeNoSupportAutoConnectWiFi userInfo:@{NSLocalizedDescriptionKey : @"iOS 11以下不支持自动切换WiFi"}];
      callBack.onFailed(err);
    }
  }
}

- (NSString *)getWiFiSSID {
  NSArray *ifs = (__bridge_transfer id)CNCopySupportedInterfaces();
  NSLog(@"interfaces:%@",ifs);
  NSDictionary *info = nil;
  for (NSString *ifname in ifs) {
    info = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifname);
    NSLog(@"%@ => %@",ifname,info);
  }
  return info[@"SSID"];
}

#pragma mark - 配置设备上网部分
- (void)setDeviceNetwork:(NSString *)wifiSSID
            wifiPassword:(NSString *)wifiPassword
               configURL:(NSString *)url
              timeoutSec:(NSTimeInterval)sec
               didFinish:(GWCallBack<GWDevice *> *)callBack {
  if (!self.appId.length || !self.appSecret.length) {
    NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeNoStart userInfo:@{NSLocalizedDescriptionKey : @"SDK未启动"}];
    callBack.onFailed(err);
  } else {
    _ssid = wifiSSID;
    _pwd = wifiPassword;
    _configUrl = url;
    //        if (deviceToken) _deviceToken = deviceToken;
    _setDeviceNetworkCallBack = callBack;
    _configuraWiFiRetryTime = 10;
    
    if (self.timeoutTimer) {
      [self.timeoutTimer invalidate];
    }
    
    [self configureWiFiWithDeviceIP:@"10.10.100.254" withServerPort:9091];
    
    __weak typeof(self) weakSelf = self;
    _timeoutTimer = [GWGCDTimer scheduledTimerWithTimeInterval:10 repeats:YES queue:dispatch_get_global_queue(0, 0) block:^{
      if (weakSelf.configuraWiFiRetryTime == 0) {
        [weakSelf.timeoutTimer invalidate];
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeConfigureWiFiFailed userInfo:@{NSLocalizedDescriptionKey : @"重试了10次，UDP发送数据配置WiFi无响应，失败"}];
        [weakSelf setDeviceNetworkFailed:err];
      } else if (weakSelf.configuraWiFiRetryTime > 0) {
        weakSelf.configuraWiFiRetryTime--;
        [weakSelf configureWiFiWithDeviceIP:@"10.10.100.254" withServerPort:9091];
      }
    }];
  }
}

- (void)stopSetDeviceNetwork {
  if (self.timeoutTimer) {
    [self.timeoutTimer invalidate];
    _timeoutTimer = nil;
  }
  [self.browser stop];
  
  _bleOperation = GWBleOperationNone;
  if (self.centralManager.isScanning) {
    [self.centralManager stopScan];
  }
  if (self.curPeripheral) {
    [self.centralManager cancelPeripheralConnection:self.curPeripheral];
    _curPeripheral = nil;
  }
  
  _setDeviceNetworkCallBack = nil;
}

- (void)setDeviceNetworkFailed:(NSError *)err {
  __weak typeof(self) weakSelf = self;
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    weakSelf.setDeviceNetworkCallBack.onFailed(err);
    [weakSelf stopSetDeviceNetwork];
  }];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing {
  NSLog(@"did find service:%@", service);
  
  if (self.timeoutTimer) {
    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;
    
    _curService = service;
    service.delegate = self;
    [service resolveWithTimeout:3];
  }
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender {
  NSLog(@"did Resolve Address:%@", sender);
  NSDictionary *dic = [self parsingIP:sender];
  
  if (dic) {
    [self.browser stop];
    _configuraWiFiRetryTime = 5;
    
    __weak typeof(self) weakSelf = self;
    _timeoutTimer = [GWGCDTimer scheduledTimerWithTimeInterval:1 repeats:YES queue:dispatch_get_global_queue(0, 0) block:^{
      if (weakSelf.configuraWiFiRetryTime == 0) {
        [weakSelf.timeoutTimer invalidate];
        NSError *err = [NSError errorWithDomain:@"com.granwin.GranwinAPKit" code:GWErrorCodeConfigureWiFiFailed userInfo:@{NSLocalizedDescriptionKey : @"重试了5次，UDP发送数据配置WiFi无响应，失败"}];
        [weakSelf setDeviceNetworkFailed:err];
      } else if (weakSelf.configuraWiFiRetryTime > 0) {
        weakSelf.configuraWiFiRetryTime--;
        //                [weakSelf configureWiFiWithDeviceIP:@"10.10.100.254" withServerPort:9091];
      }
    }];
  }
}

- (NSDictionary *)parsingIP:(NSNetService *)sender{
  UInt16 sPort = 0;
  NSString *ipv4;
  
  for (NSData *address in [sender addresses]) {
    typedef union {
      struct sockaddr sa;
      struct sockaddr_in ipv4;
    } ip_socket_address;
    
    struct sockaddr *socketAddr = (struct sockaddr*)[address bytes];
    if(socketAddr->sa_family == AF_INET) {
      sPort = ntohs(((struct sockaddr_in *)socketAddr)->sin_port);
      struct sockaddr_in* pV4Addr = (struct sockaddr_in*)socketAddr;
      int ipAddr = pV4Addr->sin_addr.s_addr;
      char str[INET_ADDRSTRLEN];
      ipv4 = [NSString stringWithUTF8String:inet_ntop( AF_INET, &ipAddr, str, INET_ADDRSTRLEN )];
    }
  }
  
  NSDictionary *data = nil;
  if (ipv4) {
    data = @{
      @"ip": ipv4,
      @"port": [NSNumber numberWithInt:sPort]
    };
  }
  
  return data;
}

- (void)configureWiFiWithDeviceIP:(NSString *)ip withServerPort:(UInt16)port {
  
  //    NSDictionary *contentDic = @{@"CID" : @(30005),
  //                                 @"URL" : @"http://iot.granwin.com:8089/gateway/deerma_device/aliyun/iot/device/register",
  //                                 @"PL" : @{
  //                                         @"SSID" : self.ssid,
  //                                         @"Password" : self.pwd
  //                                 }};
  
  
  NSDictionary *sendDataDic = @{
    @"CID" : @(30005),
    @"URL" : self.configUrl,
    @"PL" : @{
      @"SSID": self.ssid,
      @"Password": self.pwd
    },
  };
  
  [self showTips:[NSString stringWithFormat:@"%@", sendDataDic] completion:^{
    
  }];
  
  NSMutableData *sendData = [NSJSONSerialization dataWithJSONObject:sendDataDic options:0 error:nil].mutableCopy;
  self.sendData = sendData;
  
  NSString *policyStr = [[NSString alloc] initWithData:sendData encoding:NSUTF8StringEncoding];
  policyStr = [policyStr stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
  
  NSData *lastData = [policyStr dataUsingEncoding:NSUTF8StringEncoding];
  sendData = [NSMutableData dataWithData:lastData];
  
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
  sendData = [NSMutableData dataWithData:[policyStr dataUsingEncoding:NSUTF8StringEncoding]];
  
  NSLog(@"udp发送数据:%@", sendData);
  [self.udpSocket sendData:sendData toHost:ip port:port withTimeout:-1 tag:0];
  [self.udpSocket receiveOnce:nil];
}

- (void)onNotify:(nonnull NSString *)connectId topic:(nonnull NSString *)topic data:(id _Nullable)data {
  if ([self.delegate respondsToSelector:@selector(onNotify:topic:data:)]) {
    [self.delegate onNotify:connectId topic:topic data:data];
  }
}

- (BOOL)shouldHandle:(nonnull NSString *)connectId topic:(nonnull NSString *)topic {
  return NO;
}

#pragma mark - GCDAsyncSocket Delegate
- (GCDAsyncUdpSocket *)udpSocket {
  if (!_udpSocket) {
    _udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(0, 0)];
  }
  return _udpSocket;
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag {
  NSLog(@"udp发送数据成功");
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
  NSString *str = [self toHexString:(Byte *)data.bytes size:data.length];
  NSString *da = [self decryptUseDES:str key:@"gwin0801"];
  if (!da) {
    str = [[ NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    da = [self decryptUseDES:str key:@"gwin0801"];
  }
  da = [da stringByReplacingOccurrencesOfString:@"\0" withString:@""];
  NSDictionary *dic = [self dictionaryWithJsonString:da];
  //    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  //  UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
  //  pasteboard.string = str;
  //
    NSString *message = [NSString stringWithFormat:@"原始数据：%@\n解析数据：%@", data, dic];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *confirm = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
    }];
    [alert addAction:confirm];
    [alert showOnWindow];
  
  NSLog(@"接收到udp回包：%@", dic);
  
  if ([dic[@"CID"] unsignedIntegerValue] == 30006) {  //成功
    [self.udpSocket close];
    _udpSocket = nil;
    _configuraWiFiRetryTime = -1;
    [self.timeoutTimer invalidate];
    GWDevice *device = [[GWDevice alloc] initWithDictionary:dic];
    self.setDeviceNetworkCallBack.onSuccess(device);
  }
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

- (NSMutableArray *)dataArray {
  if (!_dataArray) {
    _dataArray = NSMutableArray.new;
  }
  return _dataArray;
}

- (NSMutableData *)receiveData {
  if (!_receiveData) {
    _receiveData = NSMutableData.new;
  }
  return _receiveData;
}

@end
