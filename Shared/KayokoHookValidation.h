#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <string.h>

static inline BOOL KayokoHookMethodMatches(Class cls, SEL selector, const char *encoding) {
    if (!cls || !selector || !encoding) {
        return NO;
    }
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        return NO;
    }
    NSMethodSignature *actual = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    NSMethodSignature *expected = [NSMethodSignature signatureWithObjCTypes:encoding];
    if (!actual || !expected || actual.numberOfArguments != expected.numberOfArguments ||
        strcmp(actual.methodReturnType, expected.methodReturnType) != 0) {
        return NO;
    }
    for (NSUInteger index = 0; index < actual.numberOfArguments; index++) {
        if (strcmp([actual getArgumentTypeAtIndex:index], [expected getArgumentTypeAtIndex:index]) != 0) {
            return NO;
        }
    }
    return YES;
}
