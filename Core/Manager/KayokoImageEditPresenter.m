#import "KayokoImageEditPresenter.h"
#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"

#import <QuickLook/QuickLook.h>

@interface KayokoImageEditSession : NSObject
@property(nonatomic, strong) NSURL *directoryURL;
@property(nonatomic, strong) NSURL *inputURL;
@property(nonatomic, strong, nullable) NSURL *pendingEditedURL;
@property(nonatomic, strong, nullable) NSURL *failedCopyURL;
@property(nonatomic, strong) KayokoPasteboardItem *item;
@property(nonatomic, strong, nullable) KayokoPasteboardItem *updatedItem;
@property(nonatomic, copy) NSString *historyKey;
@property(nonatomic, strong) QLPreviewController *controller;
@property(nonatomic, weak) UIViewController *presenter;
@property(nonatomic, strong, nullable) UIAlertController *retryAlert;
@property(nonatomic, copy, nullable) void (^completion)(KayokoPasteboardItem *_Nullable updatedItem);
@property(nonatomic, copy, nullable) dispatch_block_t afterDismiss;
@property(nonatomic, assign) BOOL active;
@property(nonatomic, assign) BOOL saving;
@property(nonatomic, assign) BOOL awaitingRetry;
@property(nonatomic, assign) BOOL nativeDismissed;
@end

@implementation KayokoImageEditSession
@end

static void KayokoRemoveImageEditFiles(KayokoImageEditSession *session) {
    if (!session.saving) {
        [[NSFileManager defaultManager] removeItemAtURL:session.directoryURL error:nil];
    }
}

static NSString *KayokoImageEditLocalizedString(NSString *key) {
    return [[KayokoPasteboardManager localizationBundle] localizedStringForKey:key value:key table:@"Tweak"];
}

@interface KayokoImageEditPresenter () <QLPreviewControllerDataSource, QLPreviewControllerDelegate>
@property(nonatomic, strong, nullable) KayokoImageEditSession *session;
@end

@implementation KayokoImageEditPresenter

- (BOOL)presentImageForItem:(KayokoPasteboardItem *)item
          sourceHistoryKey:(NSString *)historyKey
            fromController:(UIViewController *)controller
                completion:(void (^)(KayokoPasteboardItem *_Nullable updatedItem))completion {
    if (![NSThread isMainThread] || self.session || !item.imageName.length || !completion ||
        !([historyKey isEqualToString:kKayokoHistoryKeyHistory] || [historyKey isEqualToString:kKayokoHistoryKeyFavorites]) ||
        !controller.viewIfLoaded.window || controller.viewIfLoaded.window.hidden || controller.presentedViewController ||
        controller.isBeingPresented || controller.isBeingDismissed) {
        return NO;
    }

    UIImage *image = [[KayokoPasteboardManager sharedInstance] getImageForItem:item];
    NSData *data = image.CGImage ? UIImagePNGRepresentation(image) : nil;
    if (!data.length) {
        return NO;
    }
    NSURL *directory = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
        URLByAppendingPathComponent:[@"KayokoImageEditing" stringByAppendingPathComponent:[NSUUID UUID].UUIDString]
                         isDirectory:YES];
    NSURL *inputURL = [directory URLByAppendingPathComponent:@"input.png"];
    if (![[NSFileManager defaultManager] createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil] ||
        ![data writeToURL:inputURL options:NSDataWritingAtomic error:nil] || ![QLPreviewController canPreviewItem:inputURL]) {
        [[NSFileManager defaultManager] removeItemAtURL:directory error:nil];
        return NO;
    }

    KayokoImageEditSession *session = [[KayokoImageEditSession alloc] init];
    session.directoryURL = directory;
    session.inputURL = inputURL;
    session.item = [KayokoPasteboardItem itemFromDictionary:item.dictionaryRepresentation];
    session.historyKey = [historyKey copy];
    session.presenter = controller;
    session.completion = completion;
    session.active = YES;
    QLPreviewController *preview = [[QLPreviewController alloc] init];
    preview.dataSource = self;
    preview.delegate = self;
    preview.modalPresentationStyle = UIModalPresentationOverFullScreen;
    session.controller = preview;
    self.session = session;
    __weak typeof(self) weakSelf = self;
    [controller presentViewController:preview animated:YES completion:^{
        if (!session.active) {
            [preview dismissViewControllerAnimated:NO completion:^{
                KayokoRemoveImageEditFiles(session);
            }];
        } else if (![preview presentingViewController]) {
            [weakSelf finishSession:session];
        }
    }];
    return YES;
}

- (BOOL)shouldSuppressExternalHideRequest {
    return self.session.active;
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return self.session.controller == controller ? 1 : 0;
}

- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    return self.session.inputURL;
}

- (QLPreviewItemEditingMode)previewController:(QLPreviewController *)controller editingModeForPreviewItem:(id<QLPreviewItem>)previewItem {
    return QLPreviewItemEditingModeCreateCopy;
}

- (void)previewController:(QLPreviewController *)controller didSaveEditedCopyOfPreviewItem:(id<QLPreviewItem>)previewItem atURL:(NSURL *)modifiedContentsURL {
    KayokoImageEditSession *session = self.session;
    if (!session.active || session.controller != controller) {
        return;
    }
    [self captureEditedCopyAtURL:modifiedContentsURL forSession:session];
}

- (void)captureEditedCopyAtURL:(NSURL *)URL forSession:(KayokoImageEditSession *)session {
    NSURL *copyURL = [session.directoryURL URLByAppendingPathComponent:[NSUUID UUID].UUIDString];
    BOOL accessed = [URL startAccessingSecurityScopedResource];
    BOOL copied = [[NSFileManager defaultManager] copyItemAtURL:URL toURL:copyURL error:nil];
    if (accessed) {
        [URL stopAccessingSecurityScopedResource];
    }
    if (!copied) {
        session.failedCopyURL = URL;
        if (!session.saving) {
            [self presentSaveFailureForSession:session];
        }
        return;
    }
    session.failedCopyURL = nil;
    if (session.pendingEditedURL) {
        [[NSFileManager defaultManager] removeItemAtURL:session.pendingEditedURL error:nil];
    }
    session.pendingEditedURL = copyURL;
    if (!session.saving) {
        [self savePendingImageForSession:session];
    }
}

- (void)savePendingImageForSession:(KayokoImageEditSession *)session {
    if (!session.active || self.session != session || session.saving || !session.pendingEditedURL) {
        return;
    }
    NSURL *editedURL = session.pendingEditedURL;
    session.pendingEditedURL = nil;
    session.saving = YES;
    session.awaitingRetry = NO;
    session.controller.view.userInteractionEnabled = NO;
    __weak typeof(self) weakSelf = self;
    [[KayokoPasteboardManager sharedInstance] replaceImageForPasteboardItem:session.item
                                                         inHistoryWithKey:session.historyKey
                                                            editedFileURL:editedURL
                                                               completion:^(KayokoPasteboardItem *updatedItem, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            session.saving = NO;
            KayokoImageEditPresenter *strongSelf = weakSelf;
            if (!session.active || strongSelf.session != session) {
                KayokoRemoveImageEditFiles(session);
                return;
            }
            if (!updatedItem || error) {
                if (!session.pendingEditedURL) {
                    session.pendingEditedURL = editedURL;
                } else {
                    [[NSFileManager defaultManager] removeItemAtURL:editedURL error:nil];
                }
                [strongSelf presentSaveFailureForSession:session];
                return;
            }
            session.item = updatedItem;
            session.updatedItem = updatedItem;
            [[NSFileManager defaultManager] removeItemAtURL:editedURL error:nil];
            if (session.pendingEditedURL) {
                [strongSelf savePendingImageForSession:session];
                return;
            }
            if (session.failedCopyURL) {
                [strongSelf presentSaveFailureForSession:session];
                return;
            }
            [strongSelf closeNativeEditorForSession:session animated:YES completion:^{
                [weakSelf finishSession:session];
            }];
        });
    }];
}

- (void)presentSaveFailureForSession:(KayokoImageEditSession *)session {
    if (!session.active || self.session != session || session.retryAlert) {
        return;
    }
    session.awaitingRetry = YES;
    __weak typeof(self) weakSelf = self;
    [self closeNativeEditorForSession:session animated:YES completion:^{
        KayokoImageEditPresenter *strongSelf = weakSelf;
        if (!session.active || strongSelf.session != session) {
            return;
        }
        UIViewController *presenter = session.presenter;
        if (!presenter.viewIfLoaded.window || presenter.presentedViewController || presenter.isBeingDismissed) {
            [strongSelf finishSession:session];
            return;
        }
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:KayokoImageEditLocalizedString(@"Unable to Save Image")
                             message:KayokoImageEditLocalizedString(@"The edited image could not be saved. You can retry or cancel.")
                      preferredStyle:UIAlertControllerStyleAlert];
        session.retryAlert = alert;
        [alert addAction:[UIAlertAction actionWithTitle:KayokoImageEditLocalizedString(@"Retry")
                                                 style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [weakSelf closeSaveAlertForSession:session completion:^{
                if (!session.active || weakSelf.session != session) {
                    return;
                }
                if (session.failedCopyURL) {
                    [weakSelf captureEditedCopyAtURL:session.failedCopyURL forSession:session];
                } else {
                    [weakSelf savePendingImageForSession:session];
                }
            }];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:KayokoImageEditLocalizedString(@"Cancel")
                                                 style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
            [weakSelf closeSaveAlertForSession:session completion:^{
                [weakSelf finishSession:session];
            }];
        }]];
        [presenter presentViewController:alert animated:YES completion:^{
            if (!session.active) {
                [alert dismissViewControllerAnimated:NO completion:^{
                    KayokoRemoveImageEditFiles(session);
                }];
            }
        }];
    }];
}

- (void)closeSaveAlertForSession:(KayokoImageEditSession *)session completion:(dispatch_block_t)completion {
    UIAlertController *alert = session.retryAlert;
    session.retryAlert = nil;
    if (!alert.presentingViewController) {
        completion();
        return;
    }
    if (alert.isBeingDismissed && alert.transitionCoordinator) {
        [alert.transitionCoordinator animateAlongsideTransition:nil
                                                    completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {
            completion();
        }];
    } else {
        [alert dismissViewControllerAnimated:YES completion:completion];
    }
}

- (void)closeNativeEditorForSession:(KayokoImageEditSession *)session
                          animated:(BOOL)animated
                        completion:(dispatch_block_t)completion {
    if (session.nativeDismissed ||
        (!session.controller.presentingViewController && !session.controller.isBeingPresented)) {
        session.nativeDismissed = YES;
        completion();
        return;
    }
    session.afterDismiss = completion;
    if (session.controller.isBeingDismissed) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [session.controller dismissViewControllerAnimated:animated completion:^{
        [weakSelf nativeEditorDidDismissForSession:session];
    }];
}

- (void)previewControllerDidDismiss:(QLPreviewController *)controller {
    KayokoImageEditSession *session = self.session;
    if (session.controller == controller) {
        [self nativeEditorDidDismissForSession:session];
    }
}

- (void)nativeEditorDidDismissForSession:(KayokoImageEditSession *)session {
    if (session.nativeDismissed) {
        return;
    }
    session.nativeDismissed = YES;
    dispatch_block_t afterDismiss = session.afterDismiss;
    session.afterDismiss = nil;
    if (afterDismiss) {
        afterDismiss();
    } else if (!session.saving && !session.awaitingRetry) {
        [self finishSession:session];
    }
}

- (void)finishSession:(KayokoImageEditSession *)session {
    if (!session.active || self.session != session || session.saving) {
        return;
    }
    session.active = NO;
    self.session = nil;
    session.controller.delegate = nil;
    session.controller.dataSource = nil;
    void (^completion)(KayokoPasteboardItem *) = session.completion;
    session.completion = nil;
    session.afterDismiss = nil;
    session.retryAlert = nil;
    KayokoRemoveImageEditFiles(session);
    if (completion) {
        completion(session.updatedItem);
    }
}

- (void)dismissEditingAnimated:(BOOL)animated {
    KayokoImageEditSession *session = self.session;
    if (!session) {
        return;
    }
    session.active = NO;
    session.completion = nil;
    session.afterDismiss = nil;
    self.session = nil;
    session.controller.delegate = nil;
    session.controller.dataSource = nil;
    UIViewController *presented = session.retryAlert ?: session.controller;
    session.retryAlert = nil;
    if (presented.isBeingPresented) {
        return;
    }
    if (presented.presentingViewController) {
        [presented dismissViewControllerAnimated:animated completion:^{
            KayokoRemoveImageEditFiles(session);
        }];
    } else {
        KayokoRemoveImageEditFiles(session);
    }
}

@end
