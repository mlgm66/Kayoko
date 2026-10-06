//
//  KayokoWordSelectionViewController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoWordSelectionView;
@class KayokoWordSelectionViewController;
@class KayokoPasteboardItem;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoWordSelectionViewControllerDelegate <NSObject>

- (void)wordSelectionViewController:(KayokoWordSelectionViewController *)controller
    didRequestHideContainerAfterDirectPaste:(BOOL)directPaste;
- (void)wordSelectionViewController:(KayokoWordSelectionViewController *)controller
     triggerHapticFeedbackWithStyle:(UIImpactFeedbackStyle)style;
- (void)wordSelectionViewControllerDidRequestEdit:(KayokoWordSelectionViewController *)controller;

@end

@interface KayokoWordSelectionViewController : UIViewController

@property(nonatomic, weak, nullable) id<KayokoWordSelectionViewControllerDelegate> delegate;
@property(nonatomic, strong, readonly) KayokoWordSelectionView *wordSelectionView;
@property(nonatomic, copy, nullable, readonly) NSString *sourceHistoryKey;
@property(nonatomic, strong, nullable, readonly) KayokoPasteboardItem *sourceItem;
@property(nonatomic, copy, readonly) NSString *selectedText;
@property(nonatomic, assign, readonly) NSRange selectedTextRangeInOriginalText;
@property(nonatomic, assign, readonly, getter=isShowingWordSelection) BOOL showingWordSelection;
@property(nonatomic, assign, readonly) BOOL hasSelectedText;
@property(nonatomic, copy, nullable) void (^selectionChangedHandler)(void);

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (BOOL)canShowText:(NSString *)text;
- (void)showWordSelectionWithItem:(KayokoPasteboardItem *)item
                 sourceHistoryKey:(NSString *)sourceHistoryKey
               automaticallyPaste:(BOOL)automaticallyPaste;
- (void)hideWordSelection;
- (void)handleActionButtonWithAutomaticallyPaste:(BOOL)automaticallyPaste;
- (void)setEditButtonEnabled:(BOOL)enabled;
- (void)resetWordSelectionState;
- (BOOL)shouldSuppressExternalHideRequest;
- (void)updateActionButtonState;
- (void)scrollToTopAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
