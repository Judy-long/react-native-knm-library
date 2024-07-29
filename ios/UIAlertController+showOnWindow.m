//
//  UIAlertController+showOnWindow.m
//  UIAlertControllerShowOnWindow
//
//  Created by (╹◡╹) on 2018/2/23.
//  Copyright © 2018年 granwin. All rights reserved.
//

#import "UIAlertController+showOnWindow.h"

@implementation UIAlertController (showOnWindow)

+ (UIAlertController *)showAlertTips:(NSString *)tips {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:tips preferredStyle:UIAlertControllerStyleAlert];
    [alert addActionWithTitle:@"确定"];
    [alert showOnWindow];
    
    return alert;
}

- (void)showOnWindow {
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [window setRootViewController:[[UIViewController alloc] init]];
    window.windowLevel = UIWindowLevelAlert;
    [window makeKeyAndVisible];
    
    [[self getCurrentVC] presentViewController:self animated:YES completion:nil];
  }];
}

/// 获取当前展示的控制器
- (UIViewController *)getCurrentVC {
    UIViewController *result = nil;

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
    // 获取当前展示的控制器
    result = window.rootViewController;
    while (result) {
        if(result.presentedViewController){
            result = result.presentedViewController;
        }
        // 如果为UITabBarController：取选中控制器
        if ([result isKindOfClass:[UITabBarController class]]) {
            result = [(UITabBarController *)result selectedViewController]; //tabBar的选中控制器一般为导航控制器
        }
        // 如果为UINavigationController：取可视控制器
        if ([result isKindOfClass:[UINavigationController class]]) {
            result = [(UINavigationController *)result visibleViewController];
        }else {
            break;
        }
    }
    return result;
}

- (UIAlertAction *)addActionWithTitle:(NSString *)title {
    return [self addActionWithTitle:title style:UIAlertActionStyleDefault];
}

- (UIAlertAction *)addActionWithTitle:(NSString *)title style:(UIAlertActionStyle)style {
    return [self addActionWithTitle:title style:style handler:nil];
}

- (UIAlertAction *)addActionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *))handler {
    UIAlertAction *action = [UIAlertAction actionWithTitle:title style:style handler:handler];
    [self addAction:action];
    return action;
}

@end
