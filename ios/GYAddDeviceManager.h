//
//  GYAddDeviceManager.h
//  ReedBattery
//
//  Created by 潘振权 on 2022/8/29.
//

#import <Foundation/Foundation.h>
#import "GWCallBack.h"
#import "GWDevice.h"
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN
@class CBPeripheralCategory;


typedef NS_ENUM(NSUInteger, GYConnectWay) {
    GYBleDirectlyConnected, // 蓝牙直连
    GYBleNetConnect, // 蓝牙配网
    GYWifiNetConnect, // wifi配网
    GYWifiFirstConnect // wifi第一次配网
   
};

typedef NS_ENUM(NSUInteger, GYBleOperation) {
    GYBleOperationNone,
    GYBleOperationScan,
    GYBleOperationConnecting,
    GYBleOperationConnected
};

typedef  NS_ENUM(NSUInteger,GYBleAuthority){
    GYStatePoweredOn, // 已开启已授权
    GYStatePoweredOff, // 未开启
    GYStateUnauthorized, // 未授权
    GYStateUnsupported, // 不支持
    
}; // 蓝牙权限

@interface GYAddDeviceManager : NSObject

@property (nonatomic,strong) NSString *wifiName;
@property (nonatomic,strong) NSString *wifiPassport;
@property (nonatomic,strong) CBPeripheralCategory *peripheralCategory;
@property (nonatomic,strong) NSDictionary *info;
@property (nonatomic, assign) BOOL needCBC;    ///< 需要加密

@property (nonatomic, copy) void(^blockOnShowManufacturerData)(NSString *data);    ///< 扫描到设备

@property (nonatomic, copy) void(^blockOnSendTips)(NSString *str);    ///< 发送提示

+ (instancetype)shareManager;
/**
 * 搜索蓝牙设备
 * @bleStart:蓝牙名称开头（为空默认搜索全部）
 * @successBlock  搜索返回的蓝牙设备信息
 * @failBlock 搜索失败返回的蓝牙信息
 */
- (void)startBleConnect:(NSString *)bleStart success:(callBackParameter)successBlock failure:(onFailedBlock)failBlock;

/// 重新扫描
- (void)reScanBleDevice;

/**
 * 连接蓝牙设备
 *
 * @peripheral  选择的蓝牙信息类型
 *
 */
//- (void)connectBleDevice:(CBPeripheral *)peripheral completion:(GWCallBack<GWDevice *> *)callBack;

/// 蓝牙配网
/// @param wifiSSID WiFi名称
/// @param wifiPassword WiFi密码
/// @param peripheral 连接的设备蓝牙
/// @param url 设备注册URL
/// @param callBack 完成回调
/// @param statusBlock 状态回调：1：连接成功；2：发送数据成功
- (void)bleSetDeviceNetwork:(NSString *)wifiSSID
               wifiPassword:(NSString *)wifiPassword
               peripheral:(CBPeripheralCategory *)peripheral
                  configURL:(NSString *)url
                  didFinish:(void(^)(GWDevice  * _Nullable device, NSError  * _Nullable error))callBack
                  status:(callBackParameter)statusBlock;

/// 蓝牙配网
/// @param wifiSSID WiFi名称
/// @param wifiPassword WiFi密码
/// @param peripheralName  蓝牙名称
/// @param url 设备注册URL
/// @param callBack 完成回调
/// @param statusBlock 状态回调：1：连接成功；2：发送数据成功
//- (void)bleSetDeviceNetwork:(NSString *)wifiSSID
//               wifiPassword:(NSString *)wifiPassword
//               peripheralName:(NSString *)peripheralName
//                  configURL:(NSString *)url
//                  didFinish:(GWCallBack <GWDevice *> *)callBack
//                  status:(callBackParameter)statusBlock;

- (CBPeripheralCategory *)categoryWithMac:(NSString *)mac;

/// 停止扫描，关闭蓝牙扫描功能，清除回调
- (void)stopScanBle;

- (void)clearDataSource;

// 获取蓝牙权限
- (GYBleAuthority)getupBleAuthority;

- (void)test;

- (void)testShow;

@end

NS_ASSUME_NONNULL_END
