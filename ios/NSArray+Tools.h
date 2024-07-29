//
//  NSArray+Tools.h
//  Airwick
//
//  Created by chao on 2019/7/19.
//  Copyright © 2019 xlink. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSArray<__covariant ObjectType> (Tools)

- (nullable ObjectType)objectOfObjectsPassingTest:(BOOL (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate;

- (NSArray <ObjectType> *)objectsOfObjectsPassingTest:(BOOL (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate;

@end

NS_ASSUME_NONNULL_END
