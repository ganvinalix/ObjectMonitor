//
//  ObjectMonitor.h
//  taggedpoint
//
//  Created by long on 16/10/24.
//  Copyright © 2016年 didi. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^HookBlock)(__unsafe_unretained id aSelf, SEL cmd);

extern HookBlock deallocBlock;
extern HookBlock retainBlock;
extern HookBlock releaseBlock;

@interface ObjectMonitor : NSObject

+ (void)startMonitor;
+ (void)monitor:(__unsafe_unretained id)obj;
+ (NSString *)dumpLogWith:(__unsafe_unretained id)obj;

@end
