//
//  MNNetworkStatusHelper.h
//  MINISO
//
//  Created by 朱迪龙 on 2021/12/28.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, MNNetworkStatus) {
    MNNetworkStatusDisable,     ///< 没网
    MNNetworkStatusWifi,        ///< WiFi
    MNNetworkStatusNet,         ///< 移动网络
};

NS_ASSUME_NONNULL_BEGIN

@interface MNNetworkStatusHelper : NSObject

@property (nonatomic, assign) MNNetworkStatus status;    ///< 状态
@property (nonatomic, assign) BOOL isNetworkAble;    ///< 是否有网
@property (nonatomic, assign) BOOL isFromDisable;    ///< 是否从无网到有网


+ (MNNetworkStatusHelper *)share;

- (void)start;

@end

NS_ASSUME_NONNULL_END
