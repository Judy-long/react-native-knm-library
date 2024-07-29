//
//  GranwinAPKit.h
//  GranwinAPKit
//
//  Created by (╹◡╹) on 2019/5/7.
//  Copyright © 2019 granwin. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GWDevice.h"
#import "GWCallBack.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^LinkkitBooleanResultBlock)(BOOL succeeded, NSError * _Nullable error);

typedef NS_ENUM(UInt8, GWErrorCode) {
    GWErrorCodeNoStart,
    GWErrorCodeTimeout,
    GWErrorCodeBlePwoerOff,
    GWErrorCodeNoSupportAutoConnectWiFi,
    GWErrorCodeConfigureWiFiFailed
};

typedef NS_ENUM(NSInteger, GWIoTMQTTStatus) {
    GWIoTMQTTStatusUnknown,
    GWIoTMQTTStatusConnecting,
    GWIoTMQTTStatusConnected,
    GWIoTMQTTStatusDisconnected,
    GWIoTMQTTStatusConnectionRefused,
    GWIoTMQTTStatusConnectionError,
    GWIoTMQTTStatusProtocolError
};

typedef NS_ENUM(NSUInteger, GWIotMessageType) {
    GWIotMessageTypeConnectState,   ///< 连接状态改变
    GWIotMessageTypeReceiveData,    ///< 收到设备信息
};

typedef NS_ENUM(NSUInteger, GWBleOperation) {
    GWBleOperationNone,
    GWBleOperationScan,
    GWBleOperationConnecting,
    GWBleOperationConnected
};

@protocol GranwinAPKitDelegate <NSObject>

//收到数据回调
- (void)onNotify:(nonnull NSString *)connectId topic:(nonnull NSString *)topic data:(id _Nullable)data;

@end

@interface GranwinAPKit : NSObject

@property (nonatomic, weak) id <GranwinAPKitDelegate> delegate;

+ (GranwinAPKit *)shared;

//启动SDK
- (void)start;

#pragma mark - 开始配网
//蓝牙配网
- (void)bleSetDeviceNetwork:(NSString *)wifiSSID
               wifiPassword:(NSString *)wifiPassword
                    bleName:(NSString *)bleName
                  configURL:(NSString *)url
                  didFinish:(GWCallBack <GWDevice *> *)callBack;

//连接到WiFi热点
- (void)connectDeviceHot:(NSString *)deviceHot hotPassword:(NSString *)pwd didFinish:(GWCallBack *)callBack;

//配置设备WiFi
- (void)setDeviceNetwork:(NSString *)wifiSSID
            wifiPassword:(NSString *)wifiPassword
               configURL:(NSString *)url
              timeoutSec:(NSTimeInterval)sec didFinish:(GWCallBack <GWDevice *> *)callBack;

//停止配置WiFi
- (void)stopSetDeviceNetwork;

- (void)dealWithReceiveData:(NSData *)value;

@end

NS_ASSUME_NONNULL_END
