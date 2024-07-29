//
//  NSArray+Tools.m
//  Airwick
//
//  Created by chao on 2019/7/19.
//  Copyright © 2019 xlink. All rights reserved.
//

#import "NSArray+Tools.h"

@implementation NSArray (Tools)

- (id)objectOfObjectsPassingTest:(BOOL (NS_NOESCAPE ^)(id _Nonnull, NSUInteger, BOOL * _Nonnull))predicate {
    NSUInteger index = NSNotFound;
    if (self.count) {
        index = [self indexOfObjectPassingTest:predicate];
    }
    return index == NSNotFound ? nil : self[index];
}

- (NSArray *)objectsOfObjectsPassingTest:(BOOL (NS_NOESCAPE ^)(id _Nonnull, NSUInteger, BOOL * _Nonnull))predicate {
    NSMutableArray *arr = [NSMutableArray array];
    if (self.count) {
        NSIndexSet *indexSet = [self indexesOfObjectsPassingTest:predicate];
        [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
            [arr addObject:self[idx]];
        }];
    }
    return [NSArray arrayWithArray:arr];
}

@end
