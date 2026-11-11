#import <UIKit/UIKit.h>

BOOL KayokoCanVerifyScriptPaste(UIResponder *target);
void KayokoDispatchScriptPaste(UIResponder *target, uint64_t fingerprint, void (^completion)(BOOL inserted));
