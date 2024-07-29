//
//  GYDESHelper.h
//  GranwinsweepingRobot
//
//  Created by 潘振权 on 2022/7/12.
// 解密算法

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GYDESHelper : NSObject
// 数据解析
+ (NSDictionary *)desDecryption:(NSData *)data;

// 接受到设备返回信息进行解密，密钥：gwin0801 IV:gwin0801
+ (NSString *)decryptUseDES:(NSString *)cipherText key:(NSString*)key;

// 数据加密
+ (NSString *)encryptUseDES:(NSString *)clearText key:(NSString *)key;
// CRC-16
+ (unsigned short)crcData:(NSData *)data;

// 转16进制字符串
+ (NSString *)ToHex:(NSInteger)tmpid;

//将16进制的字符串转换成NSData
+ (NSMutableData *)convertHexStrToData:(NSString *)str;

//  十进制转二进制
+ (NSString *)toBinarySystemWithDecimalSystem:(NSString *)decimal;
+ (NSString *)toBinarySystemWithDecimalSystemByInt:(int)num;

//  二进制转十进制
+ (NSString *)toDecimalSystemWithBinarySystem:(NSString *)binary;
// 16进制字符串转10进制
+ (unsigned long long)convertHexToDecimal:(NSString *)hexStr;

// 16进制转ascii值
//+ (NSString *)stringFromHexString:(NSString *)hexString;
// 字节数转16进制字符串
+ (NSString *)toHexString:(Byte*)byte size:(NSInteger)size;
// NSData 转成十六进制格式NSString
+ (NSString *)convertDataToHexStr:(NSData *)data;
// 十六进制字符转十进制字符
+ (NSString *)hexToDecimal:(NSString *)string;
@end

NS_ASSUME_NONNULL_END
