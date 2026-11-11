//
//  KayokoActivitySharePresenter.m
//  Kayoko
//

#import "KayokoActivitySharePresenter.h"

@interface KayokoActivitySharePresenter ()

@property(nonatomic, strong, nullable) UIActivityViewController *presentedActivityController;


@end

@implementation KayokoActivitySharePresenter

- (BOOL)presentActivityItems:(NSArray *)items
              fromController:(UIViewController *)controller
                  anchorView:(UIView *)anchorView {
    if ([items count] == 0 || !controller || [self isPresentingActivity] || [controller presentedViewController] ||
        [controller isBeingPresented] || [controller isBeingDismissed] || ![[controller viewIfLoaded] window]) {
        return NO;
    }

    UIActivityViewController *activityController =
        [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    if (!activityController) {
        return NO;
    }

    UIPopoverPresentationController *popoverController = [activityController popoverPresentationController];
    if (popoverController) {
        UIView *resolvedAnchorView = anchorView ?: [controller view];
        [popoverController setSourceView:resolvedAnchorView];
        [popoverController setSourceRect:[resolvedAnchorView bounds]];
    }

    __weak typeof(self) weakSelf = self;
    __weak UIActivityViewController *weakActivityController = activityController;
    [activityController setCompletionWithItemsHandler:^(__unused UIActivityType activityType, __unused BOOL completed,
                                                         __unused NSArray *returnedItems, __unused NSError *activityError) {
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if ([strongSelf presentedActivityController] == weakActivityController) {
          [strongSelf setPresentedActivityController:nil];
      }
    }];

    [self setPresentedActivityController:activityController];
    [controller presentViewController:activityController animated:YES completion:nil];
    return YES;
}

- (void)dismissActivityAnimated:(BOOL)animated {
    UIActivityViewController *activityController = [self presentedActivityController];
    if ([activityController presentingViewController]) {
        [activityController dismissViewControllerAnimated:animated completion:nil];
    }
    [self setPresentedActivityController:nil];
}

- (BOOL)isPresentingActivity {
    UIActivityViewController *activityController = [self presentedActivityController];
    if (!activityController) {
        return NO;
    }
    if ([activityController presentingViewController] || [activityController isBeingPresented] ||
        [activityController isBeingDismissed]) {
        return YES;
    }

    [self setPresentedActivityController:nil];
    return NO;
}

@end
