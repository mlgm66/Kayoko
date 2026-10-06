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

CHDeclareClass(UIInputSwitcherView);

@interface UIInputSwitcherView : UIView
- (BOOL)isForDictation;
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
    if ([self isForDictation]) {
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
        object_setIvar(self, kayokoInputSwitcherItemsIvar, newItems);
    }
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
          !KayokoHookMethodMatches(viewClass, @selector(isForDictation), "B@:") ||
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

      CHHook0(UIInputSwitcherView, _reloadInputSwitcherItems);
      CHHook1(UIInputSwitcherView, didSelectItemAtIndex);
    });
}

@end
