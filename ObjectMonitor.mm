//
//  ObjectMonitor.m
//  taggedpoint
//
//  Created by long on 16/10/24.
//  Copyright © 2016年 didi. All rights reserved.
//

#import "ObjectMonitor.h"
#import <pthread.h>
#import <objc/runtime.h>
#include <set>

static pthread_rwlock_t _buildinClassesLock = PTHREAD_RWLOCK_INITIALIZER;

#define BuildinClassRdLock()      pthread_rwlock_rdlock(&_buildinClassesLock)
#define BuildinClassWrLock()      pthread_rwlock_wrlock(&_buildinClassesLock)
#define BuildinClassUnlock()      pthread_rwlock_unlock(&_buildinClassesLock)


HookBlock deallocBlock;
HookBlock retainBlock;
HookBlock releaseBlock;

static std::set<void *> __all_monitored_objects;

static IMP originDeallocIMP;
static IMP originRetainIMP;
static IMP originRelaseIMP;

@implementation ObjectMonitor

+ (void)startMonitor
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // 注意在替换的实现中，不能调用任何retain， release ， dealloc方法，包括隐含的
        
        SEL deallocSEL = NSSelectorFromString(@"dealloc");
        originDeallocIMP = [self hookSelector:deallocSEL block:^(__unsafe_unretained id aSelf, SEL cmd) {
            if ([ObjectMonitor isShouldMonitorWith:aSelf]) {
                [ObjectMonitor logDealloc:aSelf];
            }
            
            void(*origin)(__unsafe_unretained id, SEL) = (void(*)(__unsafe_unretained id, SEL))originDeallocIMP;
            origin(aSelf, cmd);
            
            //如果已经释放了，就要移除监控
            [ObjectMonitor monitorRemove:aSelf];
        }];
        
        
        SEL retainSEL = NSSelectorFromString(@"retain");
        originRetainIMP = [self hookSelector:retainSEL block:^(__unsafe_unretained id aSelf, SEL cmd) {
            if ([ObjectMonitor isShouldMonitorWith:aSelf]) {
                [ObjectMonitor logRetain:aSelf];
            }
            
            void(*origin)(__unsafe_unretained id, SEL) = (void(*)(__unsafe_unretained id, SEL))originRetainIMP;
            origin(aSelf, cmd);
        }];
        
        SEL releaseSEL = NSSelectorFromString(@"release");
        originRelaseIMP = [self hookSelector:releaseSEL block:^(__unsafe_unretained id aSelf, SEL cmd) {
            if ([ObjectMonitor isShouldMonitorWith:aSelf]) {
                [ObjectMonitor logRelease:aSelf];
            }
            
            void(*origin)(__unsafe_unretained id, SEL) = (void(*)(__unsafe_unretained id, SEL))originRelaseIMP;
            origin(aSelf, cmd);
        }];
    });
}

+ (IMP)hookSelector:(SEL)selector block:(HookBlock)block
{
    Method method = class_getInstanceMethod([NSObject class], selector);
    if (!method) {
        NSLog(@"Not found method for :%@ in Class: NSObject", NSStringFromSelector(selector));
        return nil;
    }
    
    IMP imp = method_getImplementation(method);
    if (!imp) {
        NSLog(@"Not found imp for :%@ in class: NSObject", NSStringFromSelector(selector));
        return nil;
    }
    
    imp = class_replaceMethod([NSObject class], selector, imp_implementationWithBlock(block), method_getTypeEncoding(method));
    return imp;
}

+ (void)monitor:(__unsafe_unretained id)obj
{
    BuildinClassWrLock();
//    [__all_monitored_objects addObject:[NSNumber numberWithLong:(long)obj]];
    __all_monitored_objects.insert((__bridge void *)obj);
    BuildinClassUnlock();
}

+ (void)monitorRemove:(__unsafe_unretained id)obj
{
    __all_monitored_objects.erase((__bridge void *)obj);
}

+ (BOOL)isShouldMonitorWith:(__unsafe_unretained id)obj
{
    BuildinClassRdLock();
    for (std::set<void *>::iterator it=__all_monitored_objects.begin(); it!=__all_monitored_objects.end(); it++) {
        if (*it == (__bridge void *)obj) {
            return YES;
        }
    }
    BuildinClassUnlock();
    return NO;
}


// TODO: 生成固定格式的log
+ (void)logDealloc:(__unsafe_unretained id)obj
{
    NSLog(@"--dealloc--: %p", obj);
}

+ (void)logRetain:(__unsafe_unretained id)obj
{
    NSLog(@"--retain--: %p", obj);
}

+ (void)logRelease:(__unsafe_unretained id)obj
{
    NSLog(@"--release--: %p", obj);
}

+ (NSString *)dumpLogWith:(__unsafe_unretained id)obj
{
    //TODO:
    return nil;
}

@end
