//
//  MNTestModel.m
//  MINISO
//
//  Created by 朱迪龙 on 2021/11/8.
//

#import "MNTestModel.h"
#import <CoreBluetooth/CoreBluetooth.h>
#include <CommonCrypto/CommonCryptor.h>
#import<CommonCrypto/CommonDigest.h>

#define kASDESKEY @"gwin0801"

@interface MNTestModel ()

@property (nonatomic, assign) int randomCount;   ///<   随机数
@property (nonatomic, strong) NSMutableData *sendData;    ///< 发送的数据
@property (nonatomic, assign) int recvCount;    ///< 接受包数量
@property (nonatomic, assign) Byte data1;    ///< 数据
@property (nonatomic, assign) Byte data2;    ///< 数据

@end

@implementation MNTestModel

- (instancetype)init {
    if (self = [super init]) {
        [self sendConfigureWifiData];
    }
    return self;
}

- (void)test:(NSData *)data {
    NSLog(@"receive:%@", data);
    
    if (data.length) {
        Byte status = 0x00;
        Byte start1 = 0x00, start2 = 0x00;
        if (data.length > 7) {
            [data getBytes:&status range:NSMakeRange(6, 1)];
            [data getBytes:&start1 range:NSMakeRange(0, 1)];
            [data getBytes:&start2 range:NSMakeRange(1, 1)];
        }
        
        if (start1 == 0x55 && start2 == 0xaa) {
            if (data.length == 9 && status == 0x01) {
                [self sendData:self.sendData];
            } else if (data.length == 9 && status == 0x02) {
                
            } else if (data.length == 13) {  /// 准备发送mac
                Byte count;
                [data getBytes:&count range:NSMakeRange(8, 1)];
                
                char bytes[]= {0x00, count};
                unsigned char by1 = (bytes[0] &0xff);//高8位
                unsigned char by2 = (bytes[1] &0xff);//低8位
                
                int temp = (by2 | (by1<<8));
                self.recvCount = temp;
                
                Byte dataId1, dataId2;
                [data getBytes:&dataId1 range:NSMakeRange(4, 1)];
                [data getBytes:&dataId2 range:NSMakeRange(5, 1)];
                
                Byte sendBytes[9] = {0x55, 0xAA, 0x01, 0x0E, dataId1, dataId2, 0x01};
                NSData *subData = [NSData dataWithBytes:sendBytes length:7];
                Byte sum = [self CalCheckSum:subData];
                sendBytes[7] = (Byte)(sum & 0x00ff);
                sendBytes[8] = 0xFE;
                
                NSData *firstData = [NSData dataWithBytes:&sendBytes length:9];
                NSLog(@"send:%@", firstData);
                
                // 设备开始发送数据
                Byte bytesss1[20] = {0x89, 0x92, 0x01, 0x7b, 0x22, 0x43, 0x49, 0x44, 0x22, 0x3a, 0x33, 0x30, 0x30, 0x30, 0x36, 0x2c, 0x22, 0x52, 0x43, 0x22};
                Byte bytesss2[20] = {0x89, 0x92, 0x02, 0x3a, 0x30, 0x2c, 0x22, 0x4d, 0x41, 0x43, 0x22, 0x3a, 0x22, 0x42, 0x38, 0x46, 0x30, 0x30, 0x39, 0x45};
                Byte bytesss3[10] = {0x89, 0x92, 0x03, 0x32, 0x39, 0x35, 0x44, 0x34, 0x22, 0x7d};
                
                [self test:[NSData dataWithBytes:bytesss1 length:20]];
                [self test:[NSData dataWithBytes:bytesss2 length:20]];
                [self test:[NSData dataWithBytes:bytesss3 length:10]];
                //                [self.curPeripheral writeValue:firstData forCharacteristic:[self getWriteChar] type:CBCharacteristicWriteWithoutResponse];
            }
        } else {
            static NSMutableData *recvData;
            if (!recvData) {
                recvData = [NSMutableData data];
            }
            
            if (data.length > 3) {
                [recvData appendData:[data subdataWithRange:NSMakeRange(3, data.length - 3)]];
            }
            
            static int count = 1;
            if (count == self.recvCount) {
                //                55 AA 01 0E 6F 10 02 8F FE
                Byte sendBytes[9] = {0x55, 0xAA, 0x01, 0x0E, self.data1, self.data2, 0x02};
                NSData *subData = [NSData dataWithBytes:sendBytes length:7];
                Byte sum = [self CalCheckSum:subData];
                sendBytes[7] = (Byte)(sum & 0x00ff);
                sendBytes[8] = 0xFE;
                
                NSData *firstData = [NSData dataWithBytes:&sendBytes length:9];
                NSLog(@"send:%@", firstData);
                //                [self.curPeripheral writeValue:firstData forCharacteristic:[self getWriteChar] type:CBCharacteristicWriteWithoutResponse];
                
                //                NSData *data = [recvData subdataWithRange:NSMakeRange(2, recvData.length - 3)];
                
                NSDictionary *recvDic = [NSJSONSerialization JSONObjectWithData:recvData options:0 error:nil];
                NSLog(@"data:%@", recvDic);
                if ([recvDic[@"CID"] integerValue] == 30006) {
                    //                    _bleOperation = GWBleOperationNone;
                    //                    _curPeripheral = nil;
                    //                    _configuraWiFiRetryTime = -1;
                    //                    [self.timeoutTimer invalidate];
                    //                    [self.centralManager cancelPeripheralConnection:peripheral];
                    //                    GWDevice *device = [[GWDevice alloc] initWithDictionary:recvDic];
                    //                    self.setDeviceNetworkCallBack.onSuccess(device);
                }
                recvData = nil;
                count = 1;
            } else {
                count ++;
            }
        }
    }
}

- (CBCharacteristic *)getWriteChar {
    //    CBService *service = [self.curPeripheral.services objectOfObjectsPassingTest:^BOOL(CBService * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
    //        return [obj.UUID.UUIDString.lowercaseString isEqualToString:bleServiceUUID];
    //    }];
    //    if (service) {
    //        CBCharacteristic *writeChar = [service.characteristics objectOfObjectsPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
    //            return [obj.UUID.UUIDString.lowercaseString isEqualToString:bleWriteUUID];
    //        }];
    //        return writeChar;
    //    }
    return nil;
}

- (void)sendConfigureWifiData {
    CBCharacteristic *writeChar = [self getWriteChar];
    //    if (writeChar) {
    NSDictionary *sendDataDic = @{
        @"CID" : @(30005),
        @"URL" : @"https://oghafnxkic.execute-api.us-west-2.amazonaws.com/Prod/device/certificate/get",
        @"PL" : @{
            @"SSID": @"AppDev",
            @"Password": @"1234567890"
        },
    };
    
    [self resetRandomCount];
    
    Byte bytes[13] = {0x55, 0xAA, 0x01, 0x0E};
    
    NSMutableData *sendData = [NSJSONSerialization dataWithJSONObject:sendDataDic options:0 error:nil].mutableCopy;
    
    NSString *policyStr = [[NSString alloc] initWithData:sendData encoding:NSUTF8StringEncoding];
    policyStr = [policyStr stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
    
    
    NSData *lastData = [policyStr dataUsingEncoding:NSUTF8StringEncoding];
    sendData = [NSMutableData dataWithData:lastData];
    NSInteger co = sendData.length % 8;
    for (int i = 0; i < (8 - co); i ++) {
        Byte byte = 0x00;
        [sendData appendBytes:&byte length:1];
    }
    self.sendData = sendData;
    
    policyStr = [[NSString alloc] initWithData:self.sendData encoding:NSUTF8StringEncoding];
    
    policyStr = [self encryptUseDES:policyStr key:kASDESKEY];
    
    sendData = [NSMutableData dataWithData:[policyStr dataUsingEncoding:NSUTF8StringEncoding]];
    self.sendData = sendData;
    
    NSInteger length = self.sendData.length;
    NSString *str = [self ToHex:length];
    NSData *data = [self convertHexStrToData:str];
    
    if (data.length == 1) {
        bytes[4] = 0x00;
        Byte by;
        [data getBytes:&by length:1];
        bytes[5] = by;
    } else if (data.length == 2) {
        Byte by1, by2;
        [data getBytes:&by1 range:NSMakeRange(0, 1)];
        [data getBytes:&by2 range:NSMakeRange(1, 1)];
        bytes[4] = by1;
        bytes[5] = by2;
    }
    
    Byte by1 = self.data1;
    Byte by2 = self.data2;
    bytes[6] = by1;
    bytes[7] = by2;
    
    NSInteger count = sendData.length / 17;
    if (sendData.length % 17 > 0) {
        count ++;
    }
    NSData *countData = [self convertHexStrToData: [self ToHex:count]];
    Byte countBtye;
    [countData getBytes:&countBtye range:NSMakeRange(0, 1)];
    bytes[8] = countBtye;
    
    uint16_t le2 = [self crcData:sendData];
    NSString *sss = [self ToHex:le2];
    NSData *crc = [self convertHexStrToData:sss];
    
    if (crc.length == 1) {
        bytes[9] = 0x00;
        Byte by;
        [crc getBytes:&by length:1];
        bytes[10] = by;
    } else if (crc.length == 2) {
        Byte by1, by2;
        [crc getBytes:&by1 range:NSMakeRange(0, 1)];
        [crc getBytes:&by2 range:NSMakeRange(1, 1)];
        bytes[9] = by1;
        bytes[10] = by2;
    }
    
    NSData *subData = [NSData dataWithBytes:bytes length:11];
    
    Byte sum = [self CalCheckSum:subData];
    
    bytes[11] = (Byte)(sum & 0x00ff);
    bytes[12] = 0xFE;
    
    NSData *firstData = [NSData dataWithBytes:&bytes length:13];
    NSLog(@"send:%@", firstData);
    //        [self.curPeripheral writeValue:firstData forCharacteristic:writeChar type:CBCharacteristicWriteWithoutResponse];
    //    }
    
    /// 设备回复
    Byte byte[] = {0x55, 0xAA, 0x00, 0x0E, 0x00, 0x01, 0x01, 0x0F, 0xFE};
    [self test:[NSData dataWithBytes:byte length:9]];
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
        NSString *dataId = [self ToHex:i + 1];
        NSData *da = [self convertHexStrToData:dataId];
        Byte b3;
        [da getBytes:&b3 length:1];
        [data appendBytes:&b3 length:1];
        //
        if (sendData.length > 17) {
            ////            data = [NSMutableData dataWithData:[sendData subdataWithRange:NSMakeRange(0, 17)]];
            for (int j = 0; j < 17; j ++) {
                Byte bytes;
                [sendData getBytes:&bytes range:NSMakeRange(j, 1)];
                [data appendBytes:&bytes length:1];
            }
            [sendData replaceBytesInRange:NSMakeRange(0, 17) withBytes:nil length:0];
        } else {
            for (int j = 0; j < sendData.length; j ++) {
                Byte bytes;
                [sendData getBytes:&bytes range:NSMakeRange(j, 1)];
                [data appendBytes:&bytes length:1];
            }
            ////            data = sendData;
            sendData = nil;
        }
        //        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //            [self.curPeripheral writeValue:data forCharacteristic:[self getWriteChar] type:CBCharacteristicWriteWithoutResponse];
        NSLog(@"send:%@", data);
        //        });
        delay ++;
    }
    
    /// 设备回复
    Byte bytes[9] = {0x55, 0xAA, 0x00, 0x0E, 0x00, 0x01, 0x02, 0x10, 0xFE};
    [self test:[NSData dataWithBytes:bytes length:9]];
    
    Byte bytes1[13] = {0x55, 0xAA, 0x00, 0x0E, 0x00, 0x60, 0x6F, 0x10, 0x03, 0xF4, 0x96, 0x7C, 0xFE};
    [self test:[NSData dataWithBytes:bytes1 length:13]];
}

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


/// 需要初始化iv的DES加密。（CBC模式）
- (NSString *)encodeDesCBCWithString:(NSString*)stringCBC {
    NSData*data;
    const Byte iv[] = {0,1,2,3,4,5,6,7};
    //    NSString*ciphertext =nil;
    NSData *textData = [stringCBC dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger dataLength = [textData length];
    unsigned char buffer[1024];
    
    memset(buffer,0,sizeof(char));
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt,
                                          kCCAlgorithmDES,
                                          kCCOptionPKCS7Padding ,
                                          [kASDESKEY UTF8String],
                                          kCCKeySizeDES,
                                          iv,
                                          [textData bytes],
                                          dataLength,
                                          buffer,1024,
                                          &numBytesEncrypted);
    
    if (cryptStatus == kCCSuccess) {
        data = [NSData dataWithBytes:buffer length:(NSUInteger)numBytesEncrypted];
    }
    
    NSString *result = [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    
    return result;
    
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

@end
