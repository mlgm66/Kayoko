//
//  KayokoDictationHooks.m
//  Kayoko
//

#define CHUseSubstrate

#import "KayokoHelperHookInstaller.h"
#import "KayokoHelperRuntime.h"
#import "../Shared/KayokoHookValidation.h"

#import <CaptainHook/CaptainHook.h>
#import <UIKit/UIKit.h>

CHDeclareClass(UISystemKeyboardDockController);
CHDeclareClass(UIKeyboardImpl);
CHDeclareClass(UIDictationController);

@interface UISystemKeyboardDockController : NSObject
@end

@interface UIKeyboardImpl : UIView
@end

@interface UIDictationController : NSObject
@end

CHOptimizedMethod3(self, void, UISystemKeyboardDockController, dictationItemButtonWasPressed, id, button, withEvent,
                   UIEvent *, event, isRunningButton, BOOL, isRunningButton) {
    [[KayokoHelperRuntime sharedRuntime] activateKayokoAfterCapturingCurrentFocus];
}

CHOptimizedMethod0(self, BOOL, UIKeyboardImpl, shouldShowDictationKey) { return YES; }

CHOptimizedMethod3(self, void, UIDictationController, switchToDictationInputModeWithTouch, id, touch,
                   withKeyboardInputMode, id, inputMode, options, id, options) {
    [[KayokoHelperRuntime sharedRuntime] activateKayokoAfterCapturingCurrentFocus];
}

@implementation KayokoHelperHookInstaller (Dictation)

+ (void)installDictationHooks {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
      Class dockControllerClass = NSClassFromString(@"UISystemKeyboardDockController");
      Class keyboardImplClass = NSClassFromString(@"UIKeyboardImpl");
      Class dictationControllerClass = NSClassFromString(@"UIDictationController");
      if (!KayokoHookMethodMatches(dockControllerClass,
                                  @selector(dictationItemButtonWasPressed:withEvent:isRunningButton:), "v@:@@B") ||
          !KayokoHookMethodMatches(keyboardImplClass, @selector(shouldShowDictationKey), "B@:") ||
          !KayokoHookMethodMatches(dictationControllerClass,
                                  @selector(switchToDictationInputModeWithTouch:withKeyboardInputMode:options:),
                                  "v@:@@@")) {
          NSLog(@"Kayoko: 听写键接口不匹配，未安装激活钩子");
          return;
      }
      CHLoadClass_(&UISystemKeyboardDockController$, dockControllerClass);
      CHLoadClass_(&UIKeyboardImpl$, keyboardImplClass);
      CHLoadClass_(&UIDictationController$, dictationControllerClass);
      CHHook3(UISystemKeyboardDockController, dictationItemButtonWasPressed, withEvent, isRunningButton);
      CHHook0(UIKeyboardImpl, shouldShowDictationKey);
      CHHook3(UIDictationController, switchToDictationInputModeWithTouch, withKeyboardInputMode, options);
    });
}

@end
