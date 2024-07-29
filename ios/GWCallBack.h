//
//  GWCallBack.h
//  GranwinAPKit
//
//  Created by (╹◡╹) on 2019/5/14.
//  Copyright © 2019 granwin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GWCallBack<ObjectType> : NSObject

typedef void(^onSuccessBlock)(ObjectType result);
typedef void(^onFailedBlock)(NSError *err);
typedef void(^callBackParameter)(id response);

@property (nonatomic, copy) onSuccessBlock onSuccess;
@property (nonatomic, copy) onFailedBlock onFailed;

+ (GWCallBack *)onSuccessful:(onSuccessBlock)onSuccess onFailed:(onFailedBlock)onFailed;

@end
