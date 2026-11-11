#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTextActionPresenter : NSObject

@property(nonatomic, assign, readonly, getter=isTranslationAvailable) BOOL translationAvailable;

- (BOOL)presentTranslationForText:(NSString *)text
                  fromController:(UIViewController *)controller
                      anchorView:(UIView *)anchorView;
- (void)dismissActionsAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
