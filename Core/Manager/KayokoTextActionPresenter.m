#import "KayokoTextActionPresenter.h"
#import "KayokoSystemTranslationPresenter.h"

@interface DDParsecCollectionViewController : UIViewController
- (instancetype)initWithString:(NSString *)string range:(NSRange)range dictionaryOnly:(BOOL)dictionaryOnly;
- (void)setSheetMode:(BOOL)sheetMode;
@end

@interface KayokoTextActionPresenter () <UIAdaptivePresentationControllerDelegate>
@property(nonatomic, strong) KayokoSystemTranslationPresenter *systemTranslationPresenter;
@property(nonatomic, strong, nullable) DDParsecCollectionViewController *dictionaryViewController;
@property(nonatomic, assign, getter=isDictionaryPresentationActive) BOOL dictionaryPresentationActive;
@property(nonatomic, assign) BOOL hasPresentedDictionaryInCurrentSession;
@property(nonatomic, assign) BOOL suppressExternalHideAfterDictionaryDismissal;
@property(nonatomic, strong, nullable) dispatch_block_t dictionaryDismissalSuppressionExpirationBlock;
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

- (BOOL)presentLookupForText:(NSString *)text fromController:(UIViewController *)controller {
    NSString *term = [text
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([term length] == 0) {
        return NO;
    }

    if ([controller presentedViewController] || [controller isBeingPresented] || [controller isBeingDismissed] ||
        ![[controller viewIfLoaded] window]) {
        return NO;
    }

    DDParsecCollectionViewController *dictionaryViewController =
        [[DDParsecCollectionViewController alloc] initWithString:term
                                                            range:NSMakeRange(0, [term length])
                                                    dictionaryOnly:YES];
    if (!dictionaryViewController) {
        return NO;
    }
    [self setDictionaryViewController:dictionaryViewController];
    [self setDictionaryPresentationActive:YES];
    [self setHasPresentedDictionaryInCurrentSession:YES];
    [self cancelDictionaryDismissalSuppressionExpiration];
    [self setSuppressExternalHideAfterDictionaryDismissal:NO];
    [dictionaryViewController setSheetMode:YES];
    [dictionaryViewController setModalPresentationStyle:UIModalPresentationPageSheet];
    [[dictionaryViewController presentationController] setDelegate:self];
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = [dictionaryViewController sheetPresentationController];
        if (sheet) {
            [sheet setDetents:@[
                [UISheetPresentationControllerDetent mediumDetent],
                [UISheetPresentationControllerDetent largeDetent]
            ]];
            [sheet setPrefersGrabberVisible:YES];
        }
    }

    [controller presentViewController:dictionaryViewController animated:YES completion:nil];
    return YES;
}

- (void)dismissActionsAnimated:(BOOL)animated {
    BOOL hadDictionarySession = [self hasPresentedDictionaryInCurrentSession];
    UIViewController *dictionaryViewController = [self dictionaryViewController];
    if ([dictionaryViewController presentingViewController]) {
        [dictionaryViewController dismissViewControllerAnimated:animated completion:nil];
    }
    [self setDictionaryViewController:nil];
    [self setDictionaryPresentationActive:NO];
    [self setHasPresentedDictionaryInCurrentSession:NO];
    if (hadDictionarySession) {
        [self beginDictionaryDismissalSuppressionExpiration];
    } else {
        [self cancelDictionaryDismissalSuppressionExpiration];
        [self setSuppressExternalHideAfterDictionaryDismissal:NO];
    }
    [[self systemTranslationPresenter] dismissTranslationAnimated:animated];
}

- (BOOL)shouldSuppressExternalHideRequest {
    if ([self hasPresentedDictionaryInCurrentSession] || [self isDictionaryPresentationActive]) {
        return YES;
    }

    if ([self suppressExternalHideAfterDictionaryDismissal]) {
        [self setSuppressExternalHideAfterDictionaryDismissal:NO];
        [self cancelDictionaryDismissalSuppressionExpiration];
        return YES;
    }

    return NO;
}

- (void)beginDictionaryDismissalSuppressionExpiration {
    [self cancelDictionaryDismissalSuppressionExpiration];
    [self setSuppressExternalHideAfterDictionaryDismissal:YES];

    __weak typeof(self) weakSelf = self;
    dispatch_block_t expirationBlock = dispatch_block_create(0, ^{
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (!strongSelf) {
          return;
      }
      [strongSelf setSuppressExternalHideAfterDictionaryDismissal:NO];
      [strongSelf setDictionaryDismissalSuppressionExpirationBlock:nil];
    });
    [self setDictionaryDismissalSuppressionExpirationBlock:expirationBlock];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(),
                   expirationBlock);
}

- (void)cancelDictionaryDismissalSuppressionExpiration {
    dispatch_block_t expirationBlock = [self dictionaryDismissalSuppressionExpirationBlock];
    if (expirationBlock) {
        dispatch_block_cancel(expirationBlock);
        [self setDictionaryDismissalSuppressionExpirationBlock:nil];
    }
}

- (void)dictionaryPresentationDidDismiss {
    if (![self isDictionaryPresentationActive] && ![self dictionaryViewController]) {
        return;
    }

    [self setDictionaryViewController:nil];
    [self setDictionaryPresentationActive:NO];
}

#pragma mark - UIAdaptivePresentationControllerDelegate

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    (void)presentationController;
    [self dictionaryPresentationDidDismiss];
}

@end
