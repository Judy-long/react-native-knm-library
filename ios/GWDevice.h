//
//  GWDevice.h
//  GranwinAPKit
//
//  Created by (╹◡╹) on 2019/5/15.
//  Copyright © 2019 granwin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>


NS_ASSUME_NONNULL_BEGIN

@interface GWDevice : NSObject

@property (nonatomic, copy) NSString *pk;

@property (nonatomic, copy) NSString *mid;

@property (nonatomic, copy) NSString *mac;

@property (nonatomic, copy) NSString *fver;

@property (nonatomic, copy) NSString *productKey;

- (instancetype)initWithDictionary:(NSDictionary *)dic;

- (NSDictionary *)getDictionaryFormat;

@end

@interface  CBPeripheralCategory:NSObject

@property (nonatomic, copy) NSString *peripheralId;    ///< id

@property (nonatomic,strong) CBPeripheral *peripheral;

@property (nonatomic,strong) NSString *bleName;

@property (nonatomic,strong) NSNumber *RSSI;

@property (nonatomic,strong) NSDictionary *advertisementData;

@property (nonatomic, assign) NSTimeInterval discoverTime;    ///< 发现时间

- (instancetype)initWithName:(NSString *)name rssi:(NSNumber *)rssi;

- (NSString *)getPid;

- (NSString *)getMacAddress;

@end


NS_ASSUME_NONNULL_END
