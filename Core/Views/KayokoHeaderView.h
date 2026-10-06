//
//  KayokoHeaderView.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoGrabberView;

NS_ASSUME_NONNULL_BEGIN

static CGFloat const kKayokoHeaderContentSpacing = 4;

@interface KayokoHeaderView : UIView

@property(nonatomic, strong, readonly) KayokoGrabberView *grabber;
@property(nonatomic, strong, readonly) UILabel *titleLabel;
@property(nonatomic, strong, readonly) UIControl *titleTapControl;
@property(nonatomic, strong, readonly) UIButton *leadingButton;
@property(nonatomic, strong, readonly) UIButton *editButton;
@property(nonatomic, strong, readonly) UIButton *trailingButton;
@property(nonatomic, strong, readonly) UIButton *alternateTrailingButton;
@property(nonatomic, strong, readonly) UIButton *openLinkButton;
@property(nonatomic, strong, readonly) UIButton *selectionActionButton;
@property(nonatomic, strong, readonly) UIButton *translationButton;
@property(nonatomic, strong, readonly) UIButton *bookButton;
@property(nonatomic, strong, readonly) UIButton *shareButton;
@property(nonatomic, strong, readonly) UISegmentedControl *historySegmentedControl;
@property(nonatomic, assign, getter=isHistorySwitcherVisible) BOOL historySwitcherVisible;

+ (CGFloat)preferredHeight;
- (instancetype)initWithTitle:(NSString *)title NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (void)setTitleText:(NSString *)title;
- (void)setHistorySwitcherVisible:(BOOL)historySwitcherVisible animated:(BOOL)animated;
- (void)setSelectedHistorySegmentIndex:(NSInteger)index;
- (void)updateStyleForButton:(UIButton *)button
               withImageName:(NSString *)imageName
                   imageSize:(NSUInteger)imageSize
                   tintColor:(UIColor *)color;

@end

NS_ASSUME_NONNULL_END
