#import "KayokoTextActionPresenter.h"
#import "KayokoSystemTranslationPresenter.h"

@interface KayokoTextActionPresenter ()
@property(nonatomic, strong) KayokoSystemTranslationPresenter *systemTranslationPresenter;
@end

@implementation KayokoTextActionPresenter

- (instancetype)init {
    self = [super init];
    if (self) {
        _systemTranslationPresenter = [[KayokoSystemTranslationPresenter alloc] init];
    }
    return self;
}

- (BOOL)isTranslationAvailable {
    return [[self systemTranslationPresenter] isAvailable];
}

- (BOOL)presentTranslationForText:(NSString *)text
                  fromController:(UIViewController *)controller
                      anchorView:(UIView *)anchorView {
    return [[self systemTranslationPresenter] presentTranslationForText:text
                                                       fromController:controller
                                                           anchorView:anchorView];
}

- (void)dismissActionsAnimated:(BOOL)animated {
    [self.systemTranslationPresenter dismissTranslationAnimated:animated];
}
@end
