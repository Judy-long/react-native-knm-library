//
//  GWDevice.m
//  GranwinAPKit
//
//  Created by (╹◡╹) on 2019/5/15.
//  Copyright © 2019 granwin. All rights reserved.
//

#import "GWDevice.h"
#import "GYDESHelper.h"

@implementation GWDevice

- (instancetype)initWithDictionary:(NSDictionary *)dic {
    if (self = [super init]) {
        _pk = dic[@"PK"];
        _mid = dic[@"MID"];
        _mac = dic[@"MAC"];
        _fver = dic[@"FVER"];
        _productKey = dic[@"product_key"];
        
        if (!self.mid.length) {
            _mid = self.mac;
        }
    }
    return self;
}

- (NSDictionary *)getDictionaryFormat {
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"PK"] = self.pk;
    dic[@"MID"] = self.mid;
    dic[@"MAC"] = self.mac;
    dic[@"FVER"] = self.fver;
    dic[@"product_key"] = self.productKey;
    return [NSDictionary dictionaryWithDictionary:dic];
}

@end


@implementation  CBPeripheralCategory

- (instancetype)initWithName:(NSString *)name rssi:(NSNumber *)rssi{
    self = [super init];
    if (self) {
        self.discoverTime = [[NSDate new] timeIntervalSince1970];
        self.bleName = name;
//        self.peripheral = peripheral;
        self.RSSI = rssi;
    }
    return self;
}

- (NSString *)getPid{
    
    NSDictionary *advDataManuData = self.advertisementData;
    NSData *date = [advDataManuData objectForKey:@"kCBAdvDataManufacturerData"];
    if(date.length > 10){
        
        NSData *pid = [date subdataWithRange:NSMakeRange(3, 2)];
        NSString *sting = [GYDESHelper convertDataToHexStr:pid];
        return [GYDESHelper hexToDecimal:sting];
    }
    return @"";
}



- (NSString *)getMacAddress{
    NSDictionary *advDataManuData = self.advertisementData;
    NSData *date = [advDataManuData objectForKey:@"kCBAdvDataManufacturerData"];
    if(date.length > 20){
       NSData *macData = [date subdataWithRange:NSMakeRange(date.length - 8, 6)];
        NSString *sting = [GYDESHelper convertDataToHexStr:macData];
        return sting;
    }
    return @"";
}
@end
