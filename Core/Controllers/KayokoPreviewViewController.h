//
//  KayokoPreviewViewController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoPreviewView;
@class KayokoPreviewViewController;
@class KayokoPasteboardItem;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoPreviewViewControllerDelegate <NSObject>
- (void)previewViewControllerDidRequestEdit:(KayokoPreviewViewController *)controller;
- (void)previewViewControllerDidFinishImageEditing:(KayokoPreviewViewController *)controller;
@end

@interface KayokoPreviewViewController : UIViewController

@property(nonatomic, weak, nullable) id<KayokoPreviewViewControllerDelegate> delegate;
@property(nonatomic, strong, readonly) KayokoPreviewView *previewView;
@property(nonatomic, copy, nullable, readonly) NSString *sourceHistoryKey;
@property(nonatomic, strong, nullable, readonly) KayokoPasteboardItem *previewItem;
@property(nonatomic, copy, nullable) void (^hapticFeedbackHandler)(UIImpactFeedbackStyle style);

- (void)showPreviewWithItem:(KayokoPasteboardItem *)item sourceHistoryKey:(NSString *)sourceHistoryKey;
- (void)handleActionButtonWithCompletion:(nullable void (^)(BOOL success))completion;
- (void)setEditButtonEnabled:(BOOL)enabled;
- (void)beginImageEditing;
- (void)dismissImageEditing;
- (void)hidePreview;
- (void)resetPreviewState;
- (BOOL)shouldSuppressExternalHideRequest;
- (void)scrollToTopAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
