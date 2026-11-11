#import "KayokoScriptPasteTarget.h"
#import "KayokoKeyboardHostResolver.h"
#import "KayokoScriptPaste.h"

@implementation KayokoScriptPasteTarget {
    NSString *_sceneIdentifier;
    pid_t _pid;
    uint64_t _focus;
}

+ (instancetype)currentTarget {
    KayokoKeyboardHostContext *host = [KayokoKeyboardHostResolver.sharedResolver currentKeyboardHostContext];
    if (!host.identifier.length || host.isKayokoOwned || host.isCached) return nil;
    pid_t pid = host.processIdentifier;
    uint64_t focus = KayokoScriptFocus(pid);
    if (!focus) return nil;
    KayokoScriptPasteTarget *target = [self new];
    target->_sceneIdentifier = [host.identifier copy];
    target->_pid = pid;
    target->_focus = focus;
    return target;
}

- (BOOL)isCurrent {
    KayokoKeyboardHostContext *host = [KayokoKeyboardHostResolver.sharedResolver currentKeyboardHostContext];
    return !host.isKayokoOwned && !host.isCached && host.processIdentifier == _pid &&
           [_sceneIdentifier isEqualToString:host.identifier] && KayokoScriptFocus(_pid) == _focus;
}

- (void)pasteText:(NSString *)text atChangeCount:(NSUInteger)changeCount completion:(void (^)(BOOL))completion {
    if (![self isCurrent]) { completion(NO); return; }
    NSString *name = KayokoScriptRequestName(_pid, _focus);
    uint64_t ticket = ((uint64_t)(arc4random_uniform(INT32_MAX) + 1) << 32) | (uint32_t)changeCount;
    NSString *reply = KayokoScriptReceiptName(name, ticket);
    int request;
    if (notify_register_check(name.UTF8String, &request) != NOTIFY_STATUS_OK) { completion(NO); return; }
    __block int response = NOTIFY_TOKEN_INVALID;
    __block BOOL finished = NO;
    void (^finish)(BOOL) = ^(BOOL pasted) {
        if (finished) return;
        finished = YES;
        uint64_t pending = 0;
        if (notify_get_state(request, &pending) == NOTIFY_STATUS_OK && pending == ticket) notify_set_state(request, 0);
        notify_cancel(request);
        if (response != NOTIFY_TOKEN_INVALID) notify_cancel(response);
        completion(pasted);
    };
    int status = notify_register_dispatch(reply.UTF8String, &response, dispatch_get_main_queue(), ^(int token) {
        uint64_t ack = 0;
        if (notify_get_state(token, &ack) == NOTIFY_STATUS_OK && (ack == ticket || ack == ~ticket)) finish(ack == ticket);
    });
    if (status != NOTIFY_STATUS_OK || notify_set_state(response, KayokoScriptTextFingerprint(text)) != NOTIFY_STATUS_OK ||
        notify_set_state(request, ticket) != NOTIFY_STATUS_OK ||
        notify_post(name.UTF8String) != NOTIFY_STATUS_OK) { finish(NO); return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ finish(NO); });
}
@end
