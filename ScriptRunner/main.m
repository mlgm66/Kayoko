#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <sys/resource.h>

static const NSUInteger outputLimit = 1024 * 1024;

static NSDictionary *failure(NSString *status) {
    return @{@"status":status};
}

static NSDictionary *exceptionReply(JSValue *describe, JSValue *exception) {
    JSValue *message = [describe callWithArguments:@[exception]];
    if (!message.isString) return failure(@"Script did not finish");
    if ([message[@"length"] toDouble] > outputLimit) return failure(@"Result is too large");
    NSString *text = message.toString;
    return text.length ? @{@"error":text} : failure(@"Script error");
}

static NSDictionary *execute(NSDictionary *request) {
    JSContext *cx = [JSContext new];
    JSValue *describe = [cx evaluateScript:
        @"(str => e => { try { const n = e && e.line; return (typeof n === 'number' ? 'Line ' + n + ': ' : '') + str(e); }"
         " catch (_) { return 'JavaScript error'; } })(String)"];
    [cx evaluateScript:request[@"code"]];
    if (cx.exception) return exceptionReply(describe, cx.exception);
    JSValue *main = [cx evaluateScript:@"typeof main === 'function' ? main : null"];
    if (cx.exception) return exceptionReply(describe, cx.exception);
    if (main.isNull) return failure(@"Missing main(text)");
    JSValue *value = [main callWithArguments:@[request[@"input"]]];
    if (cx.exception) return exceptionReply(describe, cx.exception);

    BOOL list = value.isArray;
    double count = list ? [value[@"length"] toDouble] : 1;
    if (cx.exception) return exceptionReply(describe, cx.exception);
    if (!(count >= 0 && count <= 256)) return failure(@"Too many results");
    NSMutableArray *results = [NSMutableArray array];
    NSUInteger remaining = outputLimit - (sizeof("{\"results\":[]}") - 1);
    for (NSUInteger i = 0; i < (NSUInteger)count; i++) {
        @autoreleasepool {
            JSValue *item = list ? [value valueAtIndex:i] : value;
            if (cx.exception) return exceptionReply(describe, cx.exception);
            if (!item.isString) return failure(@"Expected text or a list of texts");
            double length = [item[@"length"] toDouble];
            if (!length) continue;
            if (length > remaining) return failure(@"Result is too large");
            NSString *text = item.toString;
            NSData *encoded = [NSJSONSerialization dataWithJSONObject:text options:NSJSONWritingFragmentsAllowed error:nil];
            if (!encoded) return failure(@"Invalid result text");
            NSUInteger size = encoded.length + (results.count ? 1 : 0);
            if (size > remaining) return failure(@"Result is too large");
            remaining -= size;
            [results addObject:text];
        }
    }
    return @{@"results":results};
}

int main(void) {
    @autoreleasepool {
        struct rlimit cpu = {3, 4};
        setrlimit(RLIMIT_CPU, &cpu);
        NSData *input = [[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile];
        NSDictionary *request = [NSJSONSerialization JSONObjectWithData:input options:0 error:nil];
        if (![request isKindOfClass:NSDictionary.class] || ![request[@"code"] isKindOfClass:NSString.class] ||
            ![request[@"input"] isKindOfClass:NSString.class]) return 1;
        NSData *data = [NSJSONSerialization dataWithJSONObject:execute(request) options:0 error:nil];
        if (!data || data.length > outputLimit)
            data = [NSJSONSerialization dataWithJSONObject:failure(data ? @"Result is too large" : @"Invalid result text") options:0 error:nil];
        [[NSFileHandle fileHandleWithStandardOutput] writeData:data];
        return 0;
    }
}
