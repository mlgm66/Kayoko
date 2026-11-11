#import <UIKit/UIKit.h>

@class KayokoHeaderView, KayokoMainView, KayokoPasteboardItem;

@interface KayokoScriptPanelController : UIViewController
@property(nonatomic, readonly) KayokoHeaderView *headerView;
@property(nonatomic, readonly) UIView *body;
@property(nonatomic, weak) KayokoMainView *panel;
@property(nonatomic, copy) void (^returnToSource)(BOOL copied);
@property(nonatomic, copy) void (^dismissPanel)(void);
@property(nonatomic, copy) void (^didFinishTransition)(void);
@property(nonatomic) CGFloat keyboardBottomInset;
@property(nonatomic, readonly) BOOL protectsSystemAction;
- (void)beginWithText:(NSString *)text item:(KayokoPasteboardItem *)item historyKey:(NSString *)historyKey;
- (void)invalidatePendingActions;
- (void)reset;
@end
