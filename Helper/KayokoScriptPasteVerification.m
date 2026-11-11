#import "KayokoScriptPasteVerification.h"
#import "../Shared/Scripts/KayokoScriptPaste.h"

BOOL KayokoCanVerifyScriptPaste(UIResponder *target) {
    if ([target isKindOfClass:UITextField.class]) return ![(UITextField *)target isSecureTextEntry];
    if ([target isKindOfClass:UITextView.class]) return ![(UITextView *)target isSecureTextEntry];
    return NO;
}

static NSString *KayokoVisibleInputText(UIResponder *target) {
    if (!KayokoCanVerifyScriptPaste(target)) return nil;
    return [(id)target text] ?: @"";
}

void KayokoDispatchScriptPaste(UIResponder *target, uint64_t fingerprint, void (^completion)(BOOL)) {
    if (!KayokoCanVerifyScriptPaste(target) || ![target canPerformAction:@selector(paste:) withSender:nil]) { completion(NO); return; }
    NSString *before = [KayokoVisibleInputText(target) copy];
    id<UITextInput> field = (id<UITextInput>)target;
    UITextRange *selection = before ? field.selectedTextRange : nil;
    NSInteger start = selection ? [field offsetFromPosition:field.beginningOfDocument toPosition:selection.start] : -1;
    NSInteger end = selection ? [field offsetFromPosition:field.beginningOfDocument toPosition:selection.end] : -1;
    if (start < 0 || end < start || (NSUInteger)end > before.length ||
        ![UIApplication.sharedApplication sendAction:@selector(paste:) to:target from:nil forEvent:nil]) { completion(NO); return; }
    BOOL (^inserted)(void) = ^BOOL{
        NSString *after = KayokoVisibleInputText(target);
        NSUInteger suffix = before.length - (NSUInteger)end;
        if (!after || after.length <= (NSUInteger)start + suffix || [after isEqualToString:before]) return NO;
        if ((start && ![after hasPrefix:[before substringToIndex:start]]) ||
            (suffix && ![after hasSuffix:[before substringFromIndex:end]])) return NO;
        NSRange range = NSMakeRange(start, after.length - (NSUInteger)start - suffix);
        if (range.length > 1024 * 1024 + 2) return NO;
        BOOL leftSpace = start && [after characterAtIndex:range.location] == ' ';
        BOOL rightSpace = suffix && [after characterAtIndex:NSMaxRange(range) - 1] == ' ';
        for (NSUInteger left = 0; left <= leftSpace; left++)
            for (NSUInteger right = 0; right <= rightSpace; right++) {
                if (range.length <= left + right) continue;
                NSRange candidate = NSMakeRange(range.location + left, range.length - left - right);
                if (KayokoScriptTextFingerprint([after substringWithRange:candidate]) == fingerprint) return YES;
            }
        return NO;
    };
    if (inserted()) { completion(YES); return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 650 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        completion(inserted());
    });
}
