#import <UIKit/UIKit.h>

@class KayokoPasteboardItem;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoImageEditPresenter : NSObject

- (BOOL)presentImageForItem:(KayokoPasteboardItem *)item
          sourceHistoryKey:(NSString *)historyKey
            fromController:(UIViewController *)controller
                completion:(void (^)(KayokoPasteboardItem *_Nullable updatedItem))completion;
- (void)dismissEditingAnimated:(BOOL)animated;
- (BOOL)shouldSuppressExternalHideRequest;

@end

NS_ASSUME_NONNULL_END
