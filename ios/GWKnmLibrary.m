
#import "GWKnmLibrary.h"
#import "GranwinAPKit.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import <CoreLocation/CLLocationManager.h>
#import "UIAlertController+showOnWindow.h"
#import "MNNetworkStatusHelper.h"
#import "GranwinBluetoothManager.h"
#import "GYAddDeviceManager.h"
#import <React/RCTConvert.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
#import <AuthenticationServices/AuthenticationServices.h>

@interface GWKnmLibrary () <CLLocationManagerDelegate, ASAuthorizationControllerDelegate,ASAuthorizationControllerPresentationContextProviding>


@property (nonatomic, strong) CLLocationManager *locManager;
@property (nonatomic, copy) RCTPromiseResolveBlock ssidBlock;    ///< ssid
@property (nonatomic, copy) RCTPromiseRejectBlock ssidRejectBlock;    ///< reject
@property (nonatomic, strong) NSTimer *timer;    ///< timer

@property (nonatomic, copy) RCTPromiseResolveBlock networkBlock;    ///< ssid
@property (nonatomic, copy) RCTPromiseRejectBlock networkRejectBlock;    ///< reject
@property (nonatomic, strong) NSTimer *networkTimer;    ///< timer
@property (nonatomic, copy) NSString *networkName;    ///< 网络名字
@property (nonatomic, strong) NSTimer *checkTimer;    ///< 网络检测

@property (nonatomic, copy) RCTPromiseResolveBlock signBlock;    ///< ssid
@property (nonatomic, copy) RCTPromiseRejectBlock signRejectBlock;    ///< reject

@property (nonatomic, copy) RCTPromiseResolveBlock connectBlock;    ///< ssid


@end

@implementation GWKnmLibrary

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

RCT_REMAP_METHOD(connectDeviceHot, deviceHot:(NSString *)deviceHot hotPassword:(NSString *)pwd tips:(NSString *)tips title:(NSString *)title btnTitle:(NSString *)btnTitle didFinish:(RCTPromiseResolveBlock)callBack rejecter:(RCTPromiseRejectBlock)reject) {
  __weak typeof(self) weakSelf = self;
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    weakSelf.networkBlock = callBack;
    weakSelf.networkRejectBlock = reject;
    weakSelf.networkName = deviceHot;
    
    if ([[self getWiFiInfo] hasPrefix:deviceHot]) {
      if (weakSelf.networkBlock) {
        weakSelf.networkBlock(nil);
        weakSelf.networkBlock = nil;
        weakSelf.networkRejectBlock = nil;
      }
    } else {
      [[MNNetworkStatusHelper share] start];
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkChange) name:@"kOnNetworkChange" object:nil];
      weakSelf.checkTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:weakSelf selector:@selector(networkChange) userInfo:nil repeats:YES];
      [[NSRunLoop currentRunLoop] addTimer:weakSelf.checkTimer forMode:NSRunLoopCommonModes];
      
      //      NSString *tips = [NSString stringWithFormat:@"请手动连接到无线网络%@，密码%@", deviceHot, pwd];
      __weak typeof(self) weakSelf = self;
      UIAlertController *alert = [UIAlertController alertControllerWithTitle:tips message:title preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *confirm = [UIAlertAction actionWithTitle:btnTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
          weakSelf.networkTimer = [NSTimer scheduledTimerWithTimeInterval:60 target:weakSelf selector:@selector(connectFailure) userInfo:nil repeats:YES];
          [[NSRunLoop currentRunLoop] addTimer:weakSelf.networkTimer forMode:NSRunLoopCommonModes];
        }];
      }];
      [alert addAction:confirm];
      [alert showOnWindow];
    }
  }];
  
  
  //  [[GranwinAPKit shared] connectDeviceHot:deviceHot hotPassword:pwd didFinish:[GWCallBack <GWDevice *> onSuccessful:^(GWDevice *result) {
  //    if (callBack) {
  //      NSDictionary *dict = @{};
  //      if (result) {
  //        dict = [result getDictionaryFormat];
  //      }
  //      callBack(dict);
  //    }
  //  } onFailed:^(NSError *err) {
  //    if (reject) {
  //      reject(@"", @"", err);
  //    }
  //  }]];
}

- (void)connectFailure {
  if (_networkRejectBlock) {
    [self.networkTimer invalidate];
    self.networkTimer = nil;
    [self.checkTimer invalidate];
    self.checkTimer = nil;
    NSError *err = [NSError errorWithDomain:@"" code:-1001 userInfo:@{@"msg": @"连接热点超时"}];
    _networkRejectBlock(@"", @"", err);
    _networkBlock = nil;
    _networkRejectBlock = nil;
  }
}

- (void)networkChange {
  if ([[self getWiFiInfo] hasPrefix:self.networkName]) {
    [self.networkTimer invalidate];
    self.networkTimer = nil;
    [self.checkTimer invalidate];
    self.checkTimer = nil;
    if (_networkBlock) {
      _networkBlock(nil);
      _networkBlock = nil;
      _networkRejectBlock = nil;
    }
  }
}

RCT_REMAP_METHOD(wifiSetDeviceNetwork,
                 wifiSSID:(NSString *)wifiSSID
                 wifiPassword:(NSString *)wifiPassword
                 configURL:(NSString *)url
                 timeoutSec:(NSTimeInterval)sec
                 didFinish:(RCTPromiseResolveBlock)callBack rejecter:(RCTPromiseRejectBlock)reject) {
  [[GranwinAPKit shared] setDeviceNetwork:wifiSSID wifiPassword:wifiPassword configURL:url timeoutSec:sec * 1000 didFinish:[GWCallBack <GWDevice *> onSuccessful:^(GWDevice *result) {
    if (callBack) {
      NSDictionary *dict = @{};
      if (result) {
        dict = [result getDictionaryFormat];
      }
      callBack(dict);
    }
  } onFailed:^(NSError *err) {
    if (reject) {
      reject(@"", @"", err);
    }
  }]];
}

RCT_EXPORT_METHOD(stopSetDeviceNetwork) {
  [[GranwinAPKit shared] stopSetDeviceNetwork];
}

RCT_EXPORT_METHOD(start) {
  [[GranwinAPKit shared] start];
}

RCT_EXPORT_METHOD(openSystemSetting) {
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    NSURL *url = [NSURL URLWithString:@"App-Prefs:root=WIFI"];
    if (@available(iOS 10.0, *)) {
      [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
      [[UIApplication sharedApplication] openURL:url];
    }
  }];
}



RCT_REMAP_METHOD(showMessage, message:(NSString *)message) {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *confirm = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
    
  }];
  [alert addAction:confirm];
  [alert showOnWindow];
}


RCT_REMAP_METHOD(checkPhotoPermissions,
                 type:(int)type
                 didFinish:(RCTPromiseResolveBlock)callBack rejecter:(RCTPromiseRejectBlock)reject) {
  if (type == 1) {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusAuthorized) {
      if (callBack) {
        callBack(nil);
      }
      return;
    } else if (status == AVAuthorizationStatusNotDetermined){
      [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        if (granted) {
          if (callBack) {
            callBack(nil);
          }
        }
      }];
    } else {  /// 用户拒绝了
      [self authPhoto];
    }
  } else {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusAuthorized) {
      if (callBack) {
        callBack(nil);
      }
    } else if (status == PHAuthorizationStatusNotDetermined) {
      [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
          if (callBack) {
            callBack(nil);
          }
        }
      }];
    } else {
      [self authPhoto];
    }
  }
}

- (void)authPhoto {
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    NSURL * url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if([[UIApplication sharedApplication] canOpenURL:url]) {
      NSURL*url =[NSURL URLWithString:UIApplicationOpenSettingsURLString];
      [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
  }];
}

- (void)checkCameraPermissions:(void(^)(BOOL granted))callback {
  AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
  if (status == AVAuthorizationStatusAuthorized) {
    callback(YES);
    return;
  }
  else if (status == AVAuthorizationStatusNotDetermined){
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
      callback(granted);
      return;
    }];
  }
  else {
    callback(NO);
  }
}

- (void)checkPhotosPermissions:(void(^)(BOOL granted))callback {
  PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
  if (status == PHAuthorizationStatusAuthorized) {
    callback(YES);
    return;
  } else if (status == PHAuthorizationStatusNotDetermined) {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
      if (status == PHAuthorizationStatusAuthorized) {
        callback(YES);
        return;
      }
      else {
        callback(NO);
        return;
      }
    }];
  }
  else {
    callback(NO);
  }
}

- (void)getcurrentLocation {
  if (@available(iOS 13.0, *)) {
    //用户明确拒绝，可以弹窗提示用户到设置中手动打开权限
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
      //使用下面接口可以打开当前应用的设置页面
      [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:^(BOOL success) {
        
      }];
    }
  }
  
  __weak typeof(self) weakSelf = self;
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    weakSelf.networkTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:weakSelf selector:@selector(timeRun) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:weakSelf.networkTimer forMode:NSRunLoopCommonModes];
  }];
  
  self.locManager = [[CLLocationManager alloc] init];
  self.locManager.delegate = self;
  if(![CLLocationManager locationServicesEnabled] ||
     [CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined){
    //弹框提示用户是否开启位置权限
    [self.locManager requestWhenInUseAuthorization];
  }
}

- (void)timeRun {
  NSString *ssid = [self getWiFiInfo];
  if (ssid.length) {
    [self.networkTimer invalidate];
    self.networkTimer = nil;
    if (_ssidBlock) {
      _ssidBlock(ssid);
      _ssidBlock = nil;
      _ssidRejectBlock = nil;
    }
  }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
  if (status == kCLAuthorizationStatusAuthorizedWhenInUse ||
      status == kCLAuthorizationStatusAuthorizedAlways) {
    //再重新获取ssid
    [self configWifi];
  }
}

- (void)configWifi {
  NSString *ssid = [self getWiFiInfo];
  if (ssid.length) {
    [self.networkTimer invalidate];
    self.networkTimer = nil;
    if (_ssidBlock) {
      _ssidBlock(ssid);
      _ssidBlock = nil;
      _ssidRejectBlock = nil;
    }
  } else {
    [self.networkTimer invalidate];
    self.networkTimer = nil;
    if (_ssidRejectBlock) {
      NSError *err = [NSError errorWithDomain:@"" code:-1000 userInfo:@{@"message": @"获取ssid失败"}];
      _ssidRejectBlock(@"", @"", err);
      _ssidRejectBlock = nil;
      _ssidBlock = nil;
    }
  }
}

- (NSString *)getWiFiInfo {
  NSArray *ifs = (__bridge_transfer id)CNCopySupportedInterfaces();
  NSLog(@"interfaces:%@",ifs);
  NSDictionary *info = nil;
  for (NSString *ifname in ifs) {
    info = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifname);
    NSLog(@"%@ => %@",ifname,info);
  }
  return info[@"SSID"];
}

RCT_REMAP_METHOD(getWifiSSid, ssidSuccess:(RCTPromiseResolveBlock)completion rejecter:(RCTPromiseRejectBlock)reject) {
  NSString *ssid = [self getWiFiInfo];
  if (ssid.length) {
    if (completion) {
      completion(ssid);
    }
  } else {
    _ssidBlock = completion;
    _ssidRejectBlock = reject;
    [self getcurrentLocation];
  }
};

#pragma mark - 控制
RCT_REMAP_METHOD(scanDevices, bleName:(NSString *)bleName scanSuccess:(RCTPromiseResolveBlock)completion rejecter:(RCTPromiseRejectBlock)reject) {
  [[GYAddDeviceManager shareManager] startBleConnect:bleName success:^(NSDictionary *response) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self sendEventWithName:@"RNBLEModule_onScan" body:response];
    });
  } failure:^(NSError *err) {
    if (reject) {
      reject(@"", @"", err);
    }
  }];
};

RCT_REMAP_METHOD(bleSetDeviceNetwork, wifiSSID:(NSString *)wifiSSID wifiPassword:(NSString *)wifiPassword mac:(NSString *)mac configURL:(NSString *)url didFinish:(RCTPromiseResolveBlock)callBack rejecter:(RCTPromiseRejectBlock)reject) {
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    [[GYAddDeviceManager shareManager] bleSetDeviceNetwork:wifiSSID wifiPassword:wifiPassword peripheral:[[GYAddDeviceManager shareManager] categoryWithMac:mac] configURL:url didFinish:^(GWDevice * _Nullable device, NSError * _Nullable error) {
      if (callBack) {
        NSDictionary *dict = @{};
        if (device) {
          dict = [device getDictionaryFormat];
        }
        callBack(dict);
      }
    } status:^(id response) {
      
    }];
  }];
}

RCT_REMAP_METHOD(connectDevice, mac:(NSString *)mac connectSuccess:(RCTPromiseResolveBlock)completion rejecter:(RCTPromiseRejectBlock)reject) {
  _connectBlock = completion;
  [[NSNotificationCenter defaultCenter] removeObserver:self name:@"kOnReceiveBluetoothData" object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reveiveBluetoothData:) name:@"kOnReceiveBluetoothData" object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:@"kNotificationOnConnectChange" object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bluetoothStatusChange:) name:@"kNotificationOnConnectChange" object:nil];

    [[GranwinBluetoothManager shared] connectDeviceWithMac:mac name:@"administer的MacBook Pro" completion:^(id data, NSError *err) {
    if (err) {
      if (reject) {
        reject(@"", @"", err);
      }
    } else {

    }
  }];
}

RCT_REMAP_METHOD(connectDeviceWithName, name:(NSString *)name connectSuccess:(RCTPromiseResolveBlock)completion rejecter:(RCTPromiseRejectBlock)reject) {
  _connectBlock = completion;
  [[NSNotificationCenter defaultCenter] removeObserver:self name:@"kOnReceiveBluetoothData" object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reveiveBluetoothData:) name:@"kOnReceiveBluetoothData" object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:@"kNotificationOnConnectChange" object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bluetoothStatusChange:) name:@"kNotificationOnConnectChange" object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:@"kOnNotifyStatusChange" object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationStatusChange:) name:@"kOnNotifyStatusChange" object:nil];

  [[GranwinBluetoothManager shared] connectDeviceWithName:name completion:^(id data, NSError *err) {
    if (err) {
      if (reject) {
        reject(@"", @"", err);
      }
    } else {

    }
  }];
}


- (void)reveiveBluetoothData:(NSNotification *)noti {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self sendEventWithName:@"RNBLEModule_Data" body:noti.userInfo[@"data"]];
  });
}

- (void)bluetoothStatusChange:(NSNotification *)noti {
  BOOL status = [noti.userInfo[@"status"] boolValue];
    dispatch_async(dispatch_get_main_queue(), ^{
      [self sendEventWithName:@"RNBLEModule_Connect_Status" body:@(status)];
    });
}

- (void)notificationStatusChange:(NSNotification *)noti {
  BOOL status = [noti.userInfo[@"status"] boolValue];
    dispatch_async(dispatch_get_main_queue(), ^{
      [self sendEventWithName:@"RNBLEModule_Notify_Status" body:@(status)];
    });
}

- (NSArray *)supportedEvents {
  return @[@"RNBLEModule_Data", @"RNBLEModule_onScan", @"RNBLEModule_Connect_Status", @"Granwin_AWS_notification_ios_token", @"RNBLEModule_Notify_Status"];
}

RCT_EXPORT_METHOD(startBluetoothControl) {
  [[GranwinBluetoothManager shared] start];
}


RCT_EXPORT_METHOD(sendData:data) {
  [[GranwinBluetoothManager shared] sendDataWithString:data];
}

RCT_EXPORT_METHOD(sendCCData:data) {
  [[GranwinBluetoothManager shared] sendCCDataWithString:data];
}

RCT_EXPORT_METHOD(stopScanDevice) {
  [[GranwinBluetoothManager shared] stopScan];
  [[GYAddDeviceManager shareManager] stopScanBle];
}

RCT_EXPORT_METHOD(disConnectDevice) {
  [[GranwinBluetoothManager shared] disconnect];
}

RCT_EXPORT_METHOD(getDeviceToken) {
  NSString *deviceToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"kOndeviceToken"];
  if (deviceToken.length) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self sendEventWithName:@"Granwin_AWS_notification_ios_token" body:deviceToken];
    });
  } else {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDeviceToken:) name:@"kOnReceiveDeviceToken" object:nil];
  }
}

- (void)handleDeviceToken:(NSNotification *)noti {
  NSString *deviceToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"kOndeviceToken"];
  dispatch_async(dispatch_get_main_queue(), ^{
    [self sendEventWithName:@"RNBLEModule_DeviceToken" body:deviceToken];
  });
}

#pragma mark - 苹果登录
RCT_REMAP_METHOD(signInWithAppleId, appleCompletion:(RCTPromiseResolveBlock)completion rejecter:(RCTPromiseRejectBlock)reject) {
  _signBlock = completion;
  _signRejectBlock = reject;
  // 手机系统版本 不支持 时 隐藏苹果登录按钮
  if (@available(iOS 13.0, *)) {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSignInWithAppleStateChanged:) name:ASAuthorizationAppleIDProviderCredentialRevokedNotification object:nil];
    [self authorizationAppleID];
  } else {
    if (reject) {
      NSError *error = [NSError errorWithDomain:@"" code:-1002 userInfo:@{@"msg": @"版本不支持"}];
      reject(@"", @"", error);
    }
  }
}

#pragma mark- 授权苹果ID
- (void)authorizationAppleID{
  if (@available(iOS 13.0, *)) {
    // 基于用户的Apple ID授权用户，生成用户授权请求的一种机制
    ASAuthorizationAppleIDProvider * appleIDProvider = [[ASAuthorizationAppleIDProvider alloc] init];
    // 创建新的AppleID 授权请求
    ASAuthorizationAppleIDRequest * authAppleIDRequest = [appleIDProvider createRequest];
    // 在用户授权期间请求的联系信息
    //        authAppleIDRequest.requestedScopes = @[ASAuthorizationScopeFullName, ASAuthorizationScopeEmail];
    //如果 KeyChain 里面也有登录信息的话，可以直接使用里面保存的用户名和密码进行登录。
    //        ASAuthorizationPasswordRequest * passwordRequest = [[[ASAuthorizationPasswordProvider alloc] init] createRequest];
    
    NSMutableArray <ASAuthorizationRequest *> * array = [NSMutableArray arrayWithCapacity:2];
    if (authAppleIDRequest) {
      [array addObject:authAppleIDRequest];
    }
    //        if (passwordRequest) {
    //            [array addObject:passwordRequest];
    //        }
    NSArray <ASAuthorizationRequest *> * requests = [array copy];
    // 由ASAuthorizationAppleIDProvider创建的授权请求 管理授权请求的控制器
    ASAuthorizationController * authorizationController = [[ASAuthorizationController alloc] initWithAuthorizationRequests:requests];
    // 设置授权控制器通知授权请求的成功与失败的代理
    authorizationController.delegate = self;
    // 设置提供 展示上下文的代理，在这个上下文中 系统可以展示授权界面给用户
    authorizationController.presentationContextProvider = self;
    // 在控制器初始化期间启动授权流
    [authorizationController performRequests];
  }
}

#pragma mark- ASAuthorizationControllerDelegate
// 授权成功
- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization API_AVAILABLE(ios(13.0)) {
  
  if ([authorization.credential isKindOfClass:[ASAuthorizationAppleIDCredential class]]) {
    
    ASAuthorizationAppleIDCredential * credential = (ASAuthorizationAppleIDCredential *)authorization.credential;
    
    // 苹果用户唯一标识符，该值在同一个开发者账号下的所有 App 下是一样的，开发者可以用该唯一标识符与自己后台系统的账号体系绑定起来。
    NSString * userID = credential.user;
    //把用户的唯一标识 传给后台 判断该用户是否绑定手机号，如果绑定了直接登录，如果没绑定跳绑定手机号页面
    //        // 苹果用户信息 如果授权过，可能无法再次获取该信息
    NSPersonNameComponents * fullName = credential.fullName;
    NSString * email = credential.email;
    //
    //        // 服务器验证需要使用的参数
    NSString * authorizationCode = [[NSString alloc] initWithData:credential.authorizationCode encoding:NSUTF8StringEncoding];
    NSString * identityToken = [[NSString alloc] initWithData:credential.identityToken encoding:NSUTF8StringEncoding];
    
    NSDictionary *params = @{@"userId": userID ? userID : @"",
                             @"fullName": fullName ? fullName : @"",
                             @"email": email ? email : @"",
                             @"authorizationCode" : authorizationCode ? authorizationCode : @"",
                             @"identityToken": identityToken ? identityToken : @""
    };
    
    if (_signBlock) {
      _signBlock(params);
    }
    
    //
    //        // 用于判断当前登录的苹果账号是否是一个真实用户，取值有：unsupported、unknown、likelyReal
    //        ASUserDetectionStatus realUserStatus = credential.realUserStatus;
    
    //        NSLog(@"userID: %@", userID);
    //        NSLog(@"fullName: %@", fullName);
    //        NSLog(@"email: %@", email);
    //        NSLog(@"authorizationCode: %@", authorizationCode);
    //        NSLog(@"identityToken: %@", identityToken);
    //        NSLog(@"realUserStatus: %@", @(realUserStatus));
  } else if ([authorization.credential isKindOfClass:[ASPasswordCredential class]]) {
    // 这个获取的是iCloud记录的账号密码，需要输入框支持iOS 12 记录账号密码的新特性，如果不支持，可以忽略
    // 用户登录使用现有的密码凭证
    ASPasswordCredential * passwordCredential = (ASPasswordCredential *)authorization.credential;
    // 密码凭证对象的用户标识 用户的唯一标识
    NSString * userID = passwordCredential.user;
    if (_signBlock) {
      _signBlock(@{@"userId": userID ? userID : @""});
    }
    //把用户的唯一标识 传给后台 判断该用户是否绑定手机号，如果绑定了直接登录，如果没绑定跳绑定手机号页面
    
    //        // 密码凭证对象的密码
    //        NSString * password = passwordCredential.password;
    //        NSLog(@"userID: %@", user);
    //        NSLog(@"password: %@", password);
    
  } else {
    if (_signRejectBlock) {
      NSError *error = [NSError errorWithDomain:@"" code:-1003 userInfo:@{@"msg": @"登录失败"}];
      _signRejectBlock(@"", @"", error);
    }
  }
}

// 授权失败
- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error API_AVAILABLE(ios(13.0)) {
  NSString *errorMsg = nil;
  switch (error.code) {
    case ASAuthorizationErrorCanceled:
      errorMsg = @"用户取消了授权请求";
      break;
    case ASAuthorizationErrorFailed:
      errorMsg = @"授权请求失败";
      break;
    case ASAuthorizationErrorInvalidResponse:
      errorMsg = @"授权请求响应无效";
      break;
    case ASAuthorizationErrorNotHandled:
      errorMsg = @"未能处理授权请求";
      break;
    case ASAuthorizationErrorUnknown:
      errorMsg = @"授权请求失败未知原因";
      break;
  }
  if (_signRejectBlock) {
    NSError *error = [NSError errorWithDomain:@"" code:-1004 userInfo:@{@"msg": errorMsg}];
    _signRejectBlock(@"", @"", error);
  }
  
  NSLog(@"%@", errorMsg);
}

#pragma mark- ASAuthorizationControllerPresentationContextProviding
- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(ASAuthorizationController *)controller  API_AVAILABLE(ios(13.0)){
  return [self getWindow];
}

- (UIWindow *)getWindow {
  UIWindow *window = [[UIApplication sharedApplication] keyWindow];
  if (window.windowLevel != UIWindowLevelNormal) {
    NSArray *windows = [[UIApplication sharedApplication] windows];
    for (UIWindow *temp in windows) {
      if (temp.windowLevel == UIWindowLevelNormal) {
        window = temp;
        break;
      }
    }
  }
  return window;
}

#pragma mark- apple授权状态 更改通知
- (void)handleSignInWithAppleStateChanged:(NSNotification *)notification{
  NSLog(@"%@", notification.userInfo);
}

- (void)dealloc {
  if (@available(iOS 13.0, *)) {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ASAuthorizationAppleIDProviderCredentialRevokedNotification object:nil];
  }
}


@end
  
