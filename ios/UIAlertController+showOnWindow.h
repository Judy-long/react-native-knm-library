//
//  UIAlertController+showOnWindow.h
//  UIAlertControllerShowOnWindow
//
//  Created by (╹◡╹) on 2018/2/23.
//  Copyright © 2018年 granwin. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIAlertController (showOnWindow)

+ (UIAlertController *)showAlertTips:(NSString *)tips;

- (void)showOnWindow;

- (UIAlertAction *)addActionWithTitle:(NSString *)title;
- (UIAlertAction *)addActionWithTitle:(NSString *)title style:(UIAlertActionStyle)style;
- (UIAlertAction *)addActionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *action))handler;;

@end
