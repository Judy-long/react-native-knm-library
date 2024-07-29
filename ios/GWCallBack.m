//
//  GWCallBack.m
//  GranwinAPKit
//
//  Created by (╹◡╹) on 2019/5/14.
//  Copyright © 2019 granwin. All rights reserved.
//

#import "GWCallBack.h"

@implementation GWCallBack

- (instancetype)init {
    if (self = [super init]) {
        _onFailed = ^(NSError * _Nonnull err) {
            NSLog(@"错误回调未实现");
        };
        _onSuccess = ^(id result) {
            NSLog(@"成功回调为实现");
        };
    }
    return self;
}

+ (GWCallBack *)onSuccessful:(onSuccessBlock)onSuccess onFailed:(onFailedBlock)onFailed {
    GWCallBack *callback = [[GWCallBack alloc] init];
    
    if (onSuccess) callback.onSuccess = onSuccess;
    if (onFailed) callback.onFailed = onFailed;
    
    return callback;
}

@end
