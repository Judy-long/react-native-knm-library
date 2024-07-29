//
//  GYDESHelper.m
//  GranwinsweepingRobot
//
//  Created by 潘振权 on 2022/7/12.
//

#import "GYDESHelper.h"
#import <CommonCrypto/CommonCrypto.h>

@implementation GYDESHelper
// 数据解析
+ (NSDictionary *)desDecryption:(NSData *)data{
    NSString *aString =  [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    NSString *decryString = [self decryptUseDES:aString key:@"gwin0801"];
//    加密的字符串需要去掉中间的操作符才能解析成功
    NSString *dealString = [decryString stringByTrimmingCharactersInSet:[NSCharacterSet controlCharacterSet]];
    NSData *jsonData = [dealString dataUsingEncoding:NSUTF8StringEncoding];
     NSError *err;
     NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                         options:NSJSONReadingFragmentsAllowed
                                                           error:&err];
    return  dic;
}
// 接受到设备返回信息进行解密，密钥：gwin0801 IV:gwin0801
+ (NSString *)decryptUseDES:(NSString *)cipherText key:(NSString*)key{
    NSData *cipherData = [self convertHexStrToData:cipherText];
    NSString *keyString = key;
    unsigned char buffer[1024*100];
    memset(buffer, 0, sizeof(char));
    size_t numBytesDecrypted = 0;
      Byte *iv = (Byte *)[[keyString dataUsingEncoding:NSUTF8StringEncoding] bytes];
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt,
                                          kCCAlgorithmDES,
                                          kCCOptionPKCS7Padding,
                                          [keyString UTF8String],
                                          kCCKeySizeDES,
                                          iv,
                                          [cipherData bytes],
                                          [cipherData length],
                                          buffer,
                                          1024*100,
                                          &numBytesDecrypted);
    NSString* plainText = nil;
    if (cryptStatus == kCCSuccess) {
        NSData* data = [NSData dataWithBytes:buffer length:(NSUInteger)numBytesDecrypted];
        plainText = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"des解密后的字符串:%@",plainText);
    }
    return plainText;
}

// 数据加密
+ (NSString *)encryptUseDES:(NSString *)clearText key:(NSString *)key {
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
    }else{
        //NSLog(@"DES加密失败");
    }
    return plainText;
}

+ (NSData *)convertHexStrToData:(NSString *)str {
    if (!str || [str length] == 0) {
        return nil;
    }
    
    NSMutableData *hexData = [[NSMutableData alloc] initWithCapacity:8];
    NSRange range;
    if ([str length] % 2 == 0) {
        range = NSMakeRange(0, 2);
    } else {
        range = NSMakeRange(0, 1);
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
    
    NSLog(@"hexdata: %@", hexData);
    return hexData;
}

+ (unsigned short)crcData:(NSData *)data {
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

+ (NSString *)ToHex:(NSInteger)tmpid {
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

+ (NSString *)toBinarySystemWithDecimalSystem:(NSString *)decimal{
    int num = [decimal intValue];
    return  [self toBinarySystemWithDecimalSystemByInt:num];
}

+ (NSString *)toBinarySystemWithDecimalSystemByInt:(int)num{
    int remainder = 0;      //余数
    int divisor = 0;        //除数
    NSString * prepare = @"";
    while (true){
        remainder = num%2;
        divisor = num/2;
        num = divisor;
        prepare = [prepare stringByAppendingFormat:@"%d",remainder];
        if (divisor == 0){
            break;
        }
    }
    NSString * result = @"";
    for (NSInteger i = prepare.length-1; i >= 0; i --){
        result = [result stringByAppendingFormat:@"%@",
                  [prepare substringWithRange:NSMakeRange(i , 1)]];
 
    }
    return result;
}


//  二进制转十进制
+ (NSString *)toDecimalSystemWithBinarySystem:(NSString *)binary{
    int ll = 0 ;
    int  temp = 0 ;
    for (int i = 0; i < binary.length; i ++){
        temp = [[binary substringWithRange:NSMakeRange(i, 1)] intValue];
        temp = temp * powf(2, binary.length - i - 1);
        ll += temp;
    }
    
    NSString * result = [NSString stringWithFormat:@"%d",ll];
    return result;
}

+ (unsigned long long)convertHexToDecimal:(NSString *)hexStr{
    unsigned long long decimal = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexStr];
    [scanner scanHexLongLong:&decimal];
    return decimal;
}

+ (NSString *)toHexString:(Byte*)byte size:(NSInteger)size {
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

+ (NSString *)convertDataToHexStr:(NSData *)data{
    if (!data || [data length] == 0) {
        return @"";
    }
    NSMutableString *string = [[NSMutableString alloc] initWithCapacity:[data length]];
    
    [data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        unsigned char *dataBytes = (unsigned char*)bytes;
        for (NSInteger i = 0; i < byteRange.length; i++) {
            NSString *hexStr = [NSString stringWithFormat:@"%x", (dataBytes[i]) & 0xff];
            if ([hexStr length] == 2) {
                [string appendString:hexStr];
            } else {
                [string appendFormat:@"0%@", hexStr];
            }
        }
    }];
    
    return string;
}

+ (NSString *)hexToDecimal:(NSString *)string {
    return [NSString stringWithFormat:@"%lu",strtoul([string UTF8String],0,16)];
}

@end
