//
//  KayokoInputSwitcherHooks.mm
//  Kayoko
//

#define CHUseSubstrate

#import "KayokoHelperHookInstaller.h"
#import "KayokoHelperLocalization.h"
#import "KayokoHelperRuntime.h"
#import "../Shared/KayokoHookValidation.h"

#import <CaptainHook/CaptainHook.h>
#import <UIKit/UIKit.h>

static NSString *const kKayokoInputSwitcherItemIdentifier = @"com.mlgm.kayoko.globe";
static Ivar kayokoInputSwitcherItemsIvar;
static char kayokoInputSwitcherDictationKey;

CHDeclareClass(UIInputSwitcherView);

@interface UIInputSwitcherView : UIView
- (void)hide;
@end

@interface UIInputSwitcherItem : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *localizedTitle;
@property(nonatomic, copy) NSString *localizedSubtitle;
@property(nonatomic, strong) UIFont *titleFont;
@property(nonatomic, strong) UIFont *subtitleFont;
@property(assign, nonatomic) BOOL usesDeviceLanguage;
@property(nonatomic, strong) UISwitch *switchControl;
@property(nonatomic, copy) id switchIsOnBlock;
@property(nonatomic, copy) id switchToggleBlock;
- (instancetype)initWithIdentifier:(NSString *)identifier;
@end

CHOptimizedMethod0(self, void, UIInputSwitcherView, _reloadInputSwitcherItems) {
    CHSuper0(UIInputSwitcherView, _reloadInputSwitcherItems);
    if ([objc_getAssociatedObject(self, &kayokoInputSwitcherDictationKey) boolValue]) {
        return;
    }
    NSArray *items = object_getIvar(self, kayokoInputSwitcherItemsIvar);
    if (![items isKindOfClass:[NSArray class]]) {
        return;
    }
    for (UIInputSwitcherItem *existingItem in items) {
        if ([existingItem isKindOfClass:NSClassFromString(@"UIInputSwitcherItem")] &&
            [existingItem.identifier isEqualToString:kKayokoInputSwitcherItemIdentifier]) {
            return;
        }
    }
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:items];
    UIInputSwitcherItem *item =
        [[NSClassFromString(@"UIInputSwitcherItem") alloc] initWithIdentifier:kKayokoInputSwitcherItemIdentifier];
    [item setLocalizedTitle:KayokoHelperLocalizedString(@"Kayoko")];
    if (item) {
        [newItems insertObject:item atIndex:newItems.count ? newItems.count - 1 : 0];
        object_setIvarWithStrongDefault(self, kayokoInputSwitcherItemsIvar, newItems);
    }
}

CHOptimizedMethod5(self, id, UIInputSwitcherView, buttonPressed, id, button, withEvent, id, event, location, CGPoint,
                   location, isForDictation, BOOL, isForDictation, tapAction, id, tapAction) {
    objc_setAssociatedObject(self, &kayokoInputSwitcherDictationKey, @(isForDictation),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return CHSuper5(UIInputSwitcherView, buttonPressed, button, withEvent, event, location, location,
                    isForDictation, isForDictation, tapAction, tapAction);
}

CHOptimizedMethod6(self, id, UIInputSwitcherView, buttonPressed, id, button, withEvent, id, event, location, CGPoint,
                   location, isLocationInsideViewHitArea, BOOL, isLocationInsideViewHitArea, isForDictation, BOOL,
                   isForDictation, tapAction, id, tapAction) {
    objc_setAssociatedObject(self, &kayokoInputSwitcherDictationKey, @(isForDictation),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return CHSuper6(UIInputSwitcherView, buttonPressed, button, withEvent, event, location, location,
                    isLocationInsideViewHitArea, isLocationInsideViewHitArea, isForDictation, isForDictation,
                    tapAction, tapAction);
}

CHOptimizedMethod1(self, void, UIInputSwitcherView, didSelectItemAtIndex, unsigned long long, index) {
    NSArray *items = object_getIvar(self, kayokoInputSwitcherItemsIvar);
    if ([items isKindOfClass:[NSArray class]]) {
        if (index >= items.count) {
            return;
        }
        UIInputSwitcherItem *item = items[index];
        if ([item isKindOfClass:NSClassFromString(@"UIInputSwitcherItem")] &&
            [item.identifier isEqualToString:kKayokoInputSwitcherItemIdentifier]) {
            [self hide];
            [[KayokoHelperRuntime sharedRuntime] activateKayokoAfterCapturingCurrentFocus];
            return;
        }
    }
    CHSuper1(UIInputSwitcherView, didSelectItemAtIndex, index);
}

@implementation KayokoHelperHookInstaller (InputSwitcher)

+ (void)installInputSwitcherHooks {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
      Class viewClass = NSClassFromString(@"UIInputSwitcherView");
      Class itemClass = NSClassFromString(@"UIInputSwitcherItem");
      Ivar itemsIvar = class_getInstanceVariable(viewClass, "m_inputSwitcherItems");
      if (!itemsIvar || ivar_getTypeEncoding(itemsIvar)[0] != '@' ||
          !KayokoHookMethodMatches(viewClass, @selector(buttonPressed:withEvent:location:isForDictation:tapAction:),
                                  "@@:@@{CGPoint=dd}B@?") ||
          !KayokoHookMethodMatches(viewClass, @selector(hide), "v@:") ||
          !KayokoHookMethodMatches(viewClass, @selector(_reloadInputSwitcherItems), "v@:") ||
          !KayokoHookMethodMatches(viewClass, @selector(didSelectItemAtIndex:), "v@:Q") ||
          !KayokoHookMethodMatches(itemClass, @selector(initWithIdentifier:), "@@:@") ||
          !KayokoHookMethodMatches(itemClass, @selector(identifier), "@@:") ||
          !KayokoHookMethodMatches(itemClass, @selector(setLocalizedTitle:), "v@:@")) {
          return;
      }
      kayokoInputSwitcherItemsIvar = itemsIvar;
      CHLoadClass_(&UIInputSwitcherView$, viewClass);

      CHHook5(UIInputSwitcherView, buttonPressed, withEvent, location, isForDictation, tapAction);
      if (KayokoHookMethodMatches(viewClass,
                                 @selector(buttonPressed:withEvent:location:isLocationInsideViewHitArea:isForDictation:tapAction:),
                                 "@@:@@{CGPoint=dd}BB@?")) {
          CHHook6(UIInputSwitcherView, buttonPressed, withEvent, location, isLocationInsideViewHitArea,
                  isForDictation, tapAction);
      }
      CHHook0(UIInputSwitcherView, _reloadInputSwitcherItems);
      CHHook1(UIInputSwitcherView, didSelectItemAtIndex);
    });
}

@end
