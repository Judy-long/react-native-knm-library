//
//  MNNetworkStatusHelper.m
//  MINISO
//
//  Created by 朱迪龙 on 2021/12/28.
//

#import "MNNetworkStatusHelper.h"
#import "Reachability.h"

@interface MNNetworkStatusHelper ()

@property (nonatomic, strong) Reachability *reachability;    ///<


@end

@implementation MNNetworkStatusHelper

+ (MNNetworkStatusHelper *)share {
    static MNNetworkStatusHelper *helper = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        helper = [[MNNetworkStatusHelper alloc] init];
    });
    return helper;
}

- (void)start {
    self.reachability = [Reachability reachabilityForInternetConnection];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    [self.reachability startNotifier];
    [self configStatus:self.reachability];;
}

- (void)configStatus:(Reachability *)reach {
    if ([reach isKindOfClass:[Reachability class]]) {
        NetworkStatus netStatus = [reach currentReachabilityStatus];
        self.isFromDisable = NO;
        switch (netStatus) {
            case NotReachable:
                self.status = MNNetworkStatusDisable;
                break;
            case ReachableViaWiFi:
                if (self.status == MNNetworkStatusDisable) {
                    self.isFromDisable = YES;
                }
                self.status = MNNetworkStatusWifi;
                break;
            case ReachableViaWWAN:
                if (self.status == MNNetworkStatusDisable) {
                    self.isFromDisable = YES;
                }
                self.status = MNNetworkStatusNet;
                break;
                
            default:
                break;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kOnNetworkChange" object:nil];
    }
}

- (void)reachabilityChanged:(NSNotification *)notification {
    Reachability *currentReach = [notification object];
    
    [self configStatus:currentReach];
}

- (BOOL)isNetworkAble {
    return self.status != MNNetworkStatusDisable;
}

@end
