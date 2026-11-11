//
//  KayokoActivitySharePresenter.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoActivitySharePresenter : NSObject

- (BOOL)presentActivityItems:(NSArray *)items
              fromController:(UIViewController *)controller
                  anchorView:(nullable UIView *)anchorView;
- (BOOL)isPresentingActivity;
- (void)dismissActivityAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
