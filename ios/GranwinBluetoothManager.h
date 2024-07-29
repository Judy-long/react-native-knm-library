//
//  GranwinBluetoothManager.h
//  WanHe
//
//  Created by 朱迪龙 on 2022/7/19.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, RPBleOperation) {
   RPBleOperationNone,
   RPBleOperationScan,
   RPBleOperationConnecting,
   RPBleOperationConnected
};

typedef NS_ENUM(UInt8, RPErrorCode) {
   RPErrorCodeNoStart,
   RPErrorCodeTimeout,
   RPErrorCodeBlePwoerOff,
   RPErrorCodeNoSupportAutoConnectWiFi,
   RPErrorCodeConfigureWiFiFailed
};

typedef void(^CallBack)(id data, NSError *err);

NS_ASSUME_NONNULL_BEGIN

@interface GranwinBluetoothManager : NSObject

+ (GranwinBluetoothManager *)shared;

- (void)start;

/// 搜索
- (void)startScanBleDeviceWithName:(NSString *)name callBack:(CallBack)callBack;

/// 连接
- (void)connectDeviceWithMac:(NSString *)mac name:(NSString *)name completion:(CallBack)completion;

- (void)connectDeviceWithName:(NSString *)name completion:(CallBack)completion;

- (void)sendDataWithString:(NSString *)value;

/// 向cc03发送数据
- (void)sendCCDataWithString:(NSString *)value;

- (void)disconnect;

- (void)stopScan;

//- (void)test;
//
//- (void)testSend;

@end

NS_ASSUME_NONNULL_END
