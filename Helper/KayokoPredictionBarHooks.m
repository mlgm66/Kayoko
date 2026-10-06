//
//  KayokoPredictionBarHooks.m
//  Kayoko
//

#define CHUseSubstrate

#import "KayokoHelperHookInstaller.h"
#import "KayokoHelperLocalization.h"
#import "KayokoHelperRuntime.h"
#import "../Shared/KayokoHookValidation.h"

#import <CaptainHook/CaptainHook.h>
#import <UIKit/UIKit.h>

@interface TIKeyboardCandidate : NSObject
@end

@interface TIAutocorrectionList : NSObject
+ (TIAutocorrectionList *)listWithAutocorrection:(TIKeyboardCandidate *)arg1
                                     predictions:(NSArray<TIKeyboardCandidate *> *)predictions
                                       emojiList:(NSArray<TIKeyboardCandidate *> *)emojiList;
@end

@interface UIKeyboardAutocorrectionController : NSObject
- (void)setAutocorrectionList:(TIAutocorrectionList *)textSuggestionList;
@end

@interface TUIPredictionView : UIView
@end

@interface TIKeyboardCandidateSingle : TIKeyboardCandidate
@property(nonatomic, copy) NSString *candidate;
@end

@interface TIZephyrCandidate : TIKeyboardCandidateSingle
@property(nonatomic, copy) NSString *label;
@property(nonatomic, copy) NSString *fromBundleId;
@end

@interface UIPredictionViewController : UIViewController
@end

@class UIKBInputDelegateManager;

@interface UIKeyboardImpl : UIView
@property(nonatomic, strong, readonly) UIKeyboardAutocorrectionController *autocorrectionController;
@property(nonatomic, strong) UIKBInputDelegateManager *inputDelegateManager;
+ (instancetype)activeInstance;
@end

@interface UIKBInputDelegateManager : NSObject
- (UITextRange *)selectedTextRange;
- (NSString *)textInRange:(UITextRange *)range;
@end

@interface UIKeyboardLayoutStar : UIView
@end

CHDeclareClass(UIKeyboardAutocorrectionController);
CHDeclareClass(UIPredictionViewController);
CHDeclareClass(UIKeyboardLayoutStar);

static BOOL kayokoShouldShowCustomSuggestions = NO;

static TIAutocorrectionList *kayokoCreateAutocorrectionList(void) {
    NSArray<NSString *> *labels = @[ @"History", @"Copy", @"Paste" ];
    NSMutableArray<TIZephyrCandidate *> *candidates = [[NSMutableArray alloc] init];
    for (NSString *label in labels) {
        TIZephyrCandidate *candidate = [[objc_getClass("TIZephyrCandidate") alloc] init];
        if (!candidate) {
            return nil;
        }
        [candidate setLabel:KayokoHelperLocalizedString(label)];
        [candidate setCandidate:[NSString stringWithFormat:@"{kayoko-%@}", label]];
        [candidate setFromBundleId:@"com.mlgm.kayoko"];
        [candidates addObject:candidate];
    }

    return [objc_getClass("TIAutocorrectionList") listWithAutocorrection:nil predictions:candidates emojiList:nil];
}

CHOptimizedMethod1(self, void, UIKeyboardAutocorrectionController, setAutocorrectionList, TIAutocorrectionList *,
                   autoCorrectionList) {
    TIAutocorrectionList *kayokoList = kayokoShouldShowCustomSuggestions ? kayokoCreateAutocorrectionList() : nil;
    CHSuper1(UIKeyboardAutocorrectionController, setAutocorrectionList, kayokoList ?: autoCorrectionList);
}

CHOptimizedMethod2(self, void, UIPredictionViewController, predictionView, TUIPredictionView *, predictionView,
                   didSelectCandidate, TIZephyrCandidate *, candidate) {
    if ([candidate respondsToSelector:@selector(fromBundleId)] &&
        [candidate respondsToSelector:@selector(candidate)] &&
        [[candidate fromBundleId] isEqualToString:@"com.mlgm.kayoko"]) {
        if ([[candidate candidate] isEqualToString:@"{kayoko-History}"]) {
            [[KayokoHelperRuntime sharedRuntime] activateKayoko];
        } else if ([[candidate candidate] isEqualToString:@"{kayoko-Copy}"]) {
            UIKBInputDelegateManager *delegateManager =
                [[objc_getClass("UIKeyboardImpl") activeInstance] inputDelegateManager];
            UITextRange *range = [delegateManager selectedTextRange];
            NSString *text = range ? [delegateManager textInRange:range] : nil;

            if (text.length > 0) {
                [[UIPasteboard generalPasteboard] setString:text];
            }
        } else if ([[candidate candidate] isEqualToString:@"{kayoko-Paste}"]) {
            [[KayokoHelperRuntime sharedRuntime] pasteFromPredictionBar];
        }
    } else {
        CHSuper2(UIPredictionViewController, predictionView, predictionView, didSelectCandidate, candidate);
    }
}

CHOptimizedMethod2(self, BOOL, UIPredictionViewController, isVisibleForInputDelegate, id, delegate, inputViews, id,
                   inputViews) {
    return YES;
}

CHOptimizedMethod1(self, void, UIKeyboardLayoutStar, setKeyplaneName, NSString *, name) {
    CHSuper1(UIKeyboardLayoutStar, setKeyplaneName, name);

    kayokoShouldShowCustomSuggestions = [name isEqualToString:@"first-alternate"] ||
                                        [name isEqualToString:@"second-alternate"];

    [[[objc_getClass("UIKeyboardImpl") activeInstance] autocorrectionController] setAutocorrectionList:nil];
}

@implementation KayokoHelperHookInstaller (PredictionBar)

+ (void)installPredictionBarHooks {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
      Class candidateClass = NSClassFromString(@"TIZephyrCandidate");
      Class listClass = NSClassFromString(@"TIAutocorrectionList");
      Class keyboardImplClass = NSClassFromString(@"UIKeyboardImpl");
      Class delegateManagerClass = NSClassFromString(@"UIKBInputDelegateManager");
      Class autocorrectionClass = NSClassFromString(@"UIKeyboardAutocorrectionController");
      Class predictionClass = NSClassFromString(@"UIPredictionViewController");
      Class layoutClass = NSClassFromString(@"UIKeyboardLayoutStar");
      if (!KayokoHookMethodMatches(candidateClass, @selector(init), "@@:") ||
          !KayokoHookMethodMatches(candidateClass, @selector(setLabel:), "v@:@") ||
          !KayokoHookMethodMatches(candidateClass, @selector(setCandidate:), "v@:@") ||
          !KayokoHookMethodMatches(candidateClass, @selector(setFromBundleId:), "v@:@") ||
          !KayokoHookMethodMatches(candidateClass, @selector(fromBundleId), "@@:") ||
          !KayokoHookMethodMatches(candidateClass, @selector(candidate), "@@:") ||
          !KayokoHookMethodMatches(object_getClass(listClass),
                                  @selector(listWithAutocorrection:predictions:emojiList:), "@@:@@@") ||
          !KayokoHookMethodMatches(object_getClass(keyboardImplClass), @selector(activeInstance), "@@:") ||
          !KayokoHookMethodMatches(keyboardImplClass, @selector(autocorrectionController), "@@:") ||
          !KayokoHookMethodMatches(keyboardImplClass, @selector(inputDelegateManager), "@@:") ||
          !KayokoHookMethodMatches(delegateManagerClass, @selector(selectedTextRange), "@@:") ||
          !KayokoHookMethodMatches(delegateManagerClass, @selector(textInRange:), "@@:@") ||
          !KayokoHookMethodMatches(autocorrectionClass, @selector(setAutocorrectionList:), "v@:@") ||
          !KayokoHookMethodMatches(predictionClass, @selector(predictionView:didSelectCandidate:), "v@:@@") ||
          !KayokoHookMethodMatches(predictionClass, @selector(isVisibleForInputDelegate:inputViews:), "B@:@@") ||
          !KayokoHookMethodMatches(layoutClass, @selector(setKeyplaneName:), "v@:@")) {
          NSLog(@"Kayoko: 候选栏接口不匹配，未安装激活钩子");
          return;
      }
      CHLoadClass_(&UIKeyboardAutocorrectionController$, autocorrectionClass);
      CHHook1(UIKeyboardAutocorrectionController, setAutocorrectionList);
      CHLoadClass_(&UIPredictionViewController$, predictionClass);
      CHHook2(UIPredictionViewController, isVisibleForInputDelegate, inputViews);
      CHLoadClass_(&UIKeyboardLayoutStar$, layoutClass);
      CHHook1(UIKeyboardLayoutStar, setKeyplaneName);
      CHHook2(UIPredictionViewController, predictionView, didSelectCandidate);
    });
}

@end
