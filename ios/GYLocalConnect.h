//
//  GYLocalConnect.h
//  ReedBattery
//
//  Created by 潘振权 on 2022/9/13.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "GWDevice.h"
#import "GWCallBack.h"

NS_ASSUME_NONNULL_BEGIN

@interface GYLocalConnect : NSObject

@property (nonatomic,assign) BOOL hasConnect;
@property (nonatomic, strong) CBPeripheral *curPeripheral;
@property (nonatomic,strong) NSDictionary *receiveData;
@property (nonatomic,strong) CBPeripheralCategory *peripheralCategory;
@property (nonatomic,copy) callBackParameter successBlock;
@property (nonatomic,copy) onFailedBlock failBlock;
@property (nonatomic,assign) long timesheet;

+ (instancetype)createLocalConnect;

- (void)searchBleDevice:(callBackParameter)successBlock failure:(onFailedBlock)failBlock;

// 连接蓝牙设备
- (void)connectBle:(CBPeripheral *)peripheral success:(callBackParameter)successBlock PCRequestFailure:(onFailedBlock)failBlock status:(callBackParameter)statusBlock;

- (void)connectBleWithName:(NSString *)name success:(callBackParameter)successBlock PCRequestFailure:(onFailedBlock)failBlock status:(callBackParameter)statusBlock;

// 发送指令
- (void)sendData:(id)param;

- (NSDictionary *)decodeReceiveData:(NSData *)receiveData;

- (void)stopScanBle;

- (void)stopSetDeviceNetwork;

@end

NS_ASSUME_NONNULL_END
