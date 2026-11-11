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
CHDeclareClass(UIKeyboardDockItemButton);
CHDeclareClass(UIKeyboardDockItem);
CHDeclareClass(UIKeyboardLayoutStar);

@interface UIKeyboardDockItem : NSObject
- (id)initWithImageName:(id)imageName identifier:(id)identifier;
- (void)setImageName:(NSString *)imageName;
@end

@interface UIKeyboardDockItemButton : UIButton
@property(nonatomic, copy) NSString *identifier;
@end

@interface UISystemKeyboardDockController : NSObject
@end

@interface UIKeyboardImpl : UIView
@end

@interface UIDictationController : NSObject
@end

@interface UIKBTree : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *properties;
@end

@interface UIKeyboardLayoutStar : UIView
@end

CHOptimizedMethod2(self, id, UIKeyboardDockItem, initWithImageName, id, arg1, identifier, id, arg2) {
    if ([arg1 isEqualToString:@"mic"]) {
        if (@available(iOS 16, *)) {
            arg1 = @"list.clipboard";
        } else {
            arg1 = @"doc.on.clipboard";
        }
    }
    return CHSuper2(UIKeyboardDockItem, initWithImageName, arg1, identifier, arg2);
}

CHOptimizedMethod1(self, void, UIKeyboardDockItem, setImageName, NSString *, arg1) {
    if ([arg1 isEqualToString:@"mic"]) {
        if (@available(iOS 16, *)) {
            arg1 = @"list.clipboard";
        } else {
            arg1 = @"doc.on.clipboard";
        }
    }
    CHSuper1(UIKeyboardDockItem, setImageName, arg1);
}

CHOptimizedMethod2(self, void, UIKeyboardDockItemButton, setImage, UIImage *, image, forState, UIControlState, state) {
    if (image && [self.identifier isEqualToString:@"dictation"]) {
        UIImage *clipboardImage = [UIImage systemImageNamed:@"list.clipboard" withConfiguration:image.symbolConfiguration];
        if (clipboardImage) {
            image = clipboardImage;
        }
    }
    CHSuper2(UIKeyboardDockItemButton, setImage, image, forState, state);
}

CHOptimizedMethod1(self, void, UIKeyboardDockItemButton, setIdentifier, NSString *, identifier) {
    CHSuper1(UIKeyboardDockItemButton, setIdentifier, identifier);
    if ([identifier isEqualToString:@"dictation"]) {
        [self setImage:[self imageForState:UIControlStateNormal] forState:UIControlStateNormal];
    }
}

CHOptimizedMethod3(self, void, UISystemKeyboardDockController, dictationItemButtonWasPressed, id, button, withEvent,
                   UIEvent *, event, isRunningButton, BOOL, isRunningButton) {
    [[KayokoHelperRuntime sharedRuntime] activateKayokoAfterCapturingCurrentFocus];
}

CHOptimizedMethod2(self, void, UISystemKeyboardDockController, dictationItemButtonWasPressed, id, button, withEvent,
                   UIEvent *, event) {
    [[KayokoHelperRuntime sharedRuntime] activateKayokoAfterCapturingCurrentFocus];
}

CHOptimizedMethod0(self, BOOL, UIKeyboardImpl, shouldShowDictationKey) { return YES; }

CHOptimizedMethod1(self, UIKBTree *, UIKeyboardLayoutStar, keyHitTest, CGPoint, point) {
    UIKBTree *key = CHSuper1(UIKeyboardLayoutStar, keyHitTest, point);
    if ([key.name isEqualToString:@"Dictation-Key"] &&
        [key.properties isKindOfClass:[NSMutableDictionary class]]) {
        key.properties[@"KBinteractionType"] = @0;
        [[KayokoHelperRuntime sharedRuntime] activateKayokoAfterCapturingCurrentFocus];
    }
    return key;
}

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
      CHLoadClass_(&UISystemKeyboardDockController$, dockControllerClass);
      if (KayokoHookMethodMatches(dockControllerClass,
                                 @selector(dictationItemButtonWasPressed:withEvent:isRunningButton:), "v@:@@B")) {
          CHHook3(UISystemKeyboardDockController, dictationItemButtonWasPressed, withEvent, isRunningButton);
      } else if (KayokoHookMethodMatches(dockControllerClass,
                                        @selector(dictationItemButtonWasPressed:withEvent:), "v@:@@")) {
          CHHook2(UISystemKeyboardDockController, dictationItemButtonWasPressed, withEvent);
      }
      if (KayokoHookMethodMatches(keyboardImplClass, @selector(shouldShowDictationKey), "B@:")) {
          CHLoadClass_(&UIKeyboardImpl$, keyboardImplClass);
          CHHook0(UIKeyboardImpl, shouldShowDictationKey);
      }
      if (KayokoHookMethodMatches(dictationControllerClass,
                                 @selector(switchToDictationInputModeWithTouch:withKeyboardInputMode:options:),
                                 "v@:@@@")) {
          CHLoadClass_(&UIDictationController$, dictationControllerClass);
          CHHook3(UIDictationController, switchToDictationInputModeWithTouch, withKeyboardInputMode, options);
      }

      Class layoutClass = NSClassFromString(@"UIKeyboardLayoutStar");
      Class treeClass = NSClassFromString(@"UIKBTree");
      if (KayokoHookMethodMatches(layoutClass, @selector(keyHitTest:), "@@:{CGPoint=dd}") &&
          KayokoHookMethodMatches(treeClass, @selector(name), "@@:") &&
          KayokoHookMethodMatches(treeClass, @selector(properties), "@@:")) {
          CHLoadClass_(&UIKeyboardLayoutStar$, layoutClass);
          CHHook1(UIKeyboardLayoutStar, keyHitTest);
      }

      Class dockButtonClass = NSClassFromString(@"UIKeyboardDockItemButton");
      Class dockItemClass = NSClassFromString(@"UIKeyboardDockItem");
      if (KayokoHookMethodMatches(dockItemClass, @selector(initWithImageName:identifier:), "@@:@@") &&
          KayokoHookMethodMatches(dockItemClass, @selector(setImageName:), "v@:@")) {
          CHLoadClass_(&UIKeyboardDockItem$, dockItemClass);
          CHHook2(UIKeyboardDockItem, initWithImageName, identifier);
          CHHook1(UIKeyboardDockItem, setImageName);
          return;
      }
      if (![dockButtonClass isSubclassOfClass:[UIButton class]] ||
          !KayokoHookMethodMatches(dockButtonClass, @selector(identifier), "@@:") ||
          !KayokoHookMethodMatches(dockButtonClass, @selector(setIdentifier:), "v@:@") ||
          !KayokoHookMethodMatches(dockButtonClass, @selector(setImage:forState:), "v@:@Q")) {
          NSLog(@"Kayoko: 听写键图标接口不匹配，未安装图标钩子");
          return;
      }
      CHLoadClass_(&UIKeyboardDockItemButton$, dockButtonClass);
      CHHook2(UIKeyboardDockItemButton, setImage, forState);
      CHHook1(UIKeyboardDockItemButton, setIdentifier);
    });
}

@end
