#import <Foundation/Foundation.h>
#import <notify.h>
#import <CommonCrypto/CommonDigest.h>
#import <string.h>

static inline NSString *KayokoScriptFocusName(pid_t pid) {
    return [NSString stringWithFormat:@"com.mlgm.kayoko.script.focus.%d", pid];
}

static inline NSString *KayokoScriptRequestName(pid_t pid, uint64_t focus) {
    return [NSString stringWithFormat:@"com.mlgm.kayoko.script.paste.%d.%llu", pid, (unsigned long long)focus];
}

static inline NSString *KayokoScriptReceiptName(NSString *request, uint64_t ticket) {
    return [request stringByAppendingFormat:@".reply.%llu", (unsigned long long)ticket];
}

static inline uint64_t KayokoScriptTextFingerprint(NSString *text) {
    NSData *bytes = [text dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(bytes.bytes, (CC_LONG)bytes.length, digest);
    uint64_t value;
    memcpy(&value, digest, sizeof(value));
    return value;
}

static inline uint64_t KayokoScriptFocus(pid_t pid) {
    int token;
    uint64_t focus = 0;
    if (pid > 0 && notify_register_check(KayokoScriptFocusName(pid).UTF8String, &token) == NOTIFY_STATUS_OK) {
        notify_get_state(token, &focus);
        notify_cancel(token);
    }
    return focus;
}
