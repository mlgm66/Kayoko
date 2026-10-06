//
//  KayokoPreviewViewController.m
//  Kayoko
//

#import "KayokoPreviewViewController.h"

#import "KayokoHeaderButtonStyle.h"
#import "KayokoHeaderView.h"
#import "KayokoActivitySharePresenter.h"
#import "KayokoHistoryItemActionHandler.h"
#import "KayokoImageEditPresenter.h"
#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"
#import "KayokoPreviewView.h"
#import "KayokoTextActionPresenter.h"

static NSString *kayokoPreviewTextByTrimmingBoundaryNewlines(NSString *text) {
    return [(text ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

static NSString *KayokoPreviewLocalizedString(NSString *key) {
    return [[KayokoPasteboardManager localizationBundle] localizedStringForKey:key value:key table:@"Tweak"];
}

NS_ASSUME_NONNULL_BEGIN

@interface KayokoPreviewViewController ()
#pragma mark - Views

@property(nonatomic, strong, readwrite) KayokoPreviewView *previewView;

#pragma mark - State

@property(nonatomic, copy, nullable, readwrite) NSString *sourceHistoryKey;
@property(nonatomic, strong, nullable, readwrite) KayokoPasteboardItem *previewItem;
@property(nonatomic, assign) NSUInteger previewGeneration;
@property(nonatomic, strong) KayokoHistoryItemActionHandler *actionHandler;
@property(nonatomic, strong) KayokoActivitySharePresenter *activitySharePresenter;
@property(nonatomic, strong) KayokoTextActionPresenter *textActionPresenter;
@property(nonatomic, strong) KayokoImageEditPresenter *imageEditPresenter;
@property(nonatomic, assign) BOOL imageRestoreAvailable;
@property(nonatomic, assign) BOOL imageRestoreInProgress;
@property(nonatomic, strong, nullable) UIAlertController *imageRestoreAlert;

- (NSString *)actionImageNameForItem:(KayokoPasteboardItem *)item;
- (NSString *)actionAccessibilityLabelKeyForItem:(KayokoPasteboardItem *)item;
- (nullable id)activityItemForPreviewItem:(KayokoPasteboardItem *)item;
- (void)updateShareButtonState;
- (void)configureEditButton;
- (void)setEditButtonHidden:(BOOL)hidden;
- (void)handleEditButtonPressed;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoPreviewViewController

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _previewView = [[KayokoPreviewView alloc] initWithName:@""];
        _actionHandler = [[KayokoHistoryItemActionHandler alloc] init];
        _activitySharePresenter = [[KayokoActivitySharePresenter alloc] init];
        _textActionPresenter = [[KayokoTextActionPresenter alloc] init];
        _imageEditPresenter = [[KayokoImageEditPresenter alloc] init];
        [[[_previewView headerView] translationButton] addTarget:self
            action:@selector(handleTranslationButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [[[_previewView headerView] bookButton] addTarget:self
            action:@selector(handleBookButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [[[_previewView headerView] shareButton]
                   addTarget:self
                      action:@selector(handleShareButtonPressed)
            forControlEvents:UIControlEventTouchUpInside];
        [[[_previewView headerView] editButton]
                   addTarget:self
                      action:@selector(handleEditButtonPressed)
            forControlEvents:UIControlEventTouchUpInside];
        [[[_previewView headerView] alternateTrailingButton] addTarget:self
            action:@selector(handleRestoreImageButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self setView:_previewView];
    }
    return self;
}

#pragma mark - Presentation

- (void)showPreviewWithItem:(KayokoPasteboardItem *)item sourceHistoryKey:(NSString *)sourceHistoryKey {
    self.previewGeneration++;
    [self setPreviewItem:item];
    [self setSourceHistoryKey:sourceHistoryKey];
    [[self previewView] setUserInteractionEnabled:YES];

    if (![[item imageName] isEqualToString:@""]) {
        NSData *imageData = [[NSFileManager defaultManager]
            contentsAtPath:[NSString stringWithFormat:@"%@/%@", [KayokoPasteboardManager historyImagesPath],
                                                      [item imageName]]];
        [[self previewView] reset];
        [[self previewView] showImage:[UIImage imageWithData:imageData]];
    } else {
        NSString *previewText = kayokoPreviewTextByTrimmingBoundaryNewlines([item content]);
        [[self previewView] showText:previewText];
    }
    KayokoHeaderView *headerView = [[self previewView] headerView];
    [headerView setHidden:NO];
    [headerView setHistorySwitcherVisible:NO animated:NO];
    [headerView setTitleText:@""];
    [headerView updateStyleForButton:[headerView leadingButton]
                       withImageName:@"arrowshape.turn.up.backward"
                           imageSize:kKayokoFavoritesButtonImageSize
                           tintColor:[UIColor labelColor]];
    [headerView updateStyleForButton:[headerView trailingButton]
                       withImageName:[self actionImageNameForItem:item]
                           imageSize:kKayokoBackButtonImageSize
                           tintColor:[UIColor labelColor]];
    [headerView updateStyleForButton:[headerView shareButton]
                       withImageName:@"square.and.arrow.up"
                           imageSize:kKayokoBackButtonImageSize
                           tintColor:[UIColor labelColor]];
    [[headerView shareButton] setHidden:NO];
    [[headerView leadingButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Back"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
    NSString *actionAccessibilityLabelKey = [self actionAccessibilityLabelKeyForItem:item];
    [[headerView trailingButton] setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle]
                                                           localizedStringForKey:actionAccessibilityLabelKey
                                                                           value:nil
                                                                           table:@"Tweak"]];
    [[headerView trailingButton] setEnabled:YES];
    [[headerView trailingButton] setAlpha:1.0];
    [[headerView shareButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Share"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
    [self configureEditButton];
    [self refreshImageRestoreAvailability];
    [self updateShareButtonState];
    [self updateTextActionButtons];
}

#pragma mark - Actions

- (NSString *)actionImageNameForItem:(KayokoPasteboardItem *)item {
    if ([[item imageName] length] > 0) {
        return @"square.and.arrow.down";
    }
    return @"doc.on.doc.fill";
}

- (NSString *)actionAccessibilityLabelKeyForItem:(KayokoPasteboardItem *)item {
    if ([[item imageName] length] > 0) {
        return @"Save to Photos";
    }
    return @"Copy";
}

- (id)activityItemForPreviewItem:(KayokoPasteboardItem *)item {
    if ([[item imageName] length] > 0) {
        return [[self previewView] imageView].image;
    }

    if ([item hasLink]) {
        NSURL *URL = [NSURL URLWithString:[item content] ?: @""];
        if (URL) {
            return URL;
        }
    }

    NSString *text = kayokoPreviewTextByTrimmingBoundaryNewlines([item content]);
    return [text length] > 0 ? text : nil;
}

- (void)updateShareButtonState {
    UIButton *shareButton = [[[self previewView] headerView] shareButton];
    BOOL enabled = [self activityItemForPreviewItem:[self previewItem]] != nil;
    [shareButton setEnabled:enabled];
    [shareButton setAlpha:enabled ? 1.0 : 0.35];
}

- (void)updateTextActionButtons {
    KayokoHeaderView *headerView = [[self previewView] headerView];
    BOOL isText = [[self previewItem] imageName].length == 0;
    BOOL hasText = isText && [[self textForActions] length] > 0;
    BOOL canOpenLink = isText && [[self previewItem] hasLink];
    NSBundle *bundle = [KayokoPasteboardManager localizationBundle];
    [headerView updateStyleForButton:[headerView openLinkButton] withImageName:@"arrow.up"
                          imageSize:kKayokoBackButtonImageSize tintColor:[UIColor labelColor]];
    [[headerView openLinkButton] setHidden:!canOpenLink];
    [[headerView openLinkButton] setEnabled:canOpenLink];
    [[headerView openLinkButton] setAlpha:1.0];
    [[headerView openLinkButton] setAccessibilityLabel:[bundle localizedStringForKey:@"Open" value:nil table:@"Tweak"]];
    [headerView updateStyleForButton:[headerView translationButton] withImageName:@"character.bubble"
                          imageSize:kKayokoBackButtonImageSize tintColor:[UIColor labelColor]];
    [[headerView translationButton] setHidden:!isText || ![[self textActionPresenter] isTranslationAvailable]];
    [[headerView translationButton] setEnabled:hasText];
    [[headerView translationButton] setAlpha:hasText ? 1.0 : 0.35];
    [[headerView translationButton] setAccessibilityLabel:[bundle localizedStringForKey:@"Translate" value:nil table:@"Tweak"]];
    [headerView updateStyleForButton:[headerView bookButton] withImageName:@"book.closed"
                          imageSize:kKayokoBackButtonImageSize tintColor:[UIColor labelColor]];
    [[headerView bookButton] setHidden:!isText];
    [[headerView bookButton] setEnabled:hasText];
    [[headerView bookButton] setAlpha:hasText ? 1.0 : 0.35];
    [[headerView bookButton] setAccessibilityLabel:[bundle localizedStringForKey:@"Look Up" value:nil table:@"Tweak"]];
}

- (NSString *)textForActions {
    return kayokoPreviewTextByTrimmingBoundaryNewlines([[self previewItem] content]);
}

- (void)handleTranslationButtonPressed {
    if ([[self textActionPresenter] presentTranslationForText:[self textForActions] fromController:self
                                                 anchorView:[[[self previewView] headerView] translationButton]] &&
        [self hapticFeedbackHandler]) {
        [self hapticFeedbackHandler](UIImpactFeedbackStyleLight);
    }
}

- (void)handleBookButtonPressed {
    if ([[self textActionPresenter] presentLookupForText:[self textForActions] fromController:self] &&
        [self hapticFeedbackHandler]) {
        [self hapticFeedbackHandler](UIImpactFeedbackStyleLight);
    }
}

- (void)configureEditButton {
    if (![self canEditPreviewItem]) {
        [self setEditButtonHidden:YES];
        return;
    }

    KayokoHeaderView *headerView = [[self previewView] headerView];
    [headerView updateStyleForButton:[headerView editButton]
                       withImageName:@"square.and.pencil"
                           imageSize:kKayokoBackButtonImageSize
                           tintColor:[UIColor labelColor]];
    [[headerView editButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Edit"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
    [self setEditButtonHidden:NO];
    [self setEditButtonEnabled:YES];
}

- (void)setEditButtonHidden:(BOOL)hidden {
    UIButton *editButton = [[[self previewView] headerView] editButton];
    [editButton setHidden:hidden];
    if (hidden) {
        [editButton setEnabled:NO];
        [editButton setAlpha:0];
    }
}

- (void)setEditButtonEnabled:(BOOL)enabled {
    UIButton *editButton = [[[self previewView] headerView] editButton];
    [editButton setEnabled:enabled];
    [editButton setAlpha:(enabled && ![editButton isHidden]) ? 1.0 : 0.35];
}

- (BOOL)canEditPreviewItem {
    KayokoPasteboardItem *item = [self previewItem];
    return item && [[self sourceHistoryKey] length] > 0 &&
           ([[item imageName] length] == 0 || [[[self previewView] imageView] image] != nil);
}

- (void)handleEditButtonPressed {
    if (![self canEditPreviewItem] || self.imageRestoreInProgress) {
        return;
    }

    UIButton *editButton = [[[self previewView] headerView] editButton];
    if ([editButton isHidden] || ![editButton isEnabled]) {
        return;
    }

    [self setEditButtonEnabled:NO];
    [[self delegate] previewViewControllerDidRequestEdit:self];
}

- (void)beginImageEditing {
    KayokoPasteboardItem *item = [self previewItem];
    NSString *historyKey = [self sourceHistoryKey];
    if ([[item imageName] length] == 0 || [historyKey length] == 0 || [[self previewView] isHidden]) {
        [self setEditButtonEnabled:YES];
        return;
    }

    NSUInteger generation = self.previewGeneration;
    __weak typeof(self) weakSelf = self;
    BOOL presented = [[self imageEditPresenter]
        presentImageForItem:item
        sourceHistoryKey:historyKey
        fromController:[self parentViewController] ?: self
        completion:^(KayokoPasteboardItem *updatedItem) {
          __strong typeof(weakSelf) strongSelf = weakSelf;
          if (!strongSelf || strongSelf.previewGeneration != generation || [strongSelf previewItem] != item ||
              [[strongSelf previewView] isHidden]) {
              return;
          }
          if (updatedItem) {
              [strongSelf showPreviewWithItem:updatedItem sourceHistoryKey:historyKey];
          } else {
              [strongSelf setEditButtonEnabled:YES];
          }
          [[strongSelf delegate] previewViewControllerDidFinishImageEditing:strongSelf];
        }];
    if (!presented) {
        [self setEditButtonEnabled:YES];
    } else if ([self hapticFeedbackHandler]) {
        [self hapticFeedbackHandler](UIImpactFeedbackStyleLight);
    }
}

- (void)dismissImageEditing {
    self.previewGeneration++;
    [[self imageEditPresenter] dismissEditingAnimated:NO];
    UIAlertController *alert = self.imageRestoreAlert;
    self.imageRestoreAlert = nil;
    self.imageRestoreInProgress = NO;
    self.imageRestoreAvailable = NO;
    [[[[self previewView] headerView] alternateTrailingButton] setHidden:YES];
    if (!alert.isBeingPresented && alert.presentingViewController) {
        [alert dismissViewControllerAnimated:NO completion:nil];
    }
}

- (void)refreshImageRestoreAvailability {
    self.imageRestoreAvailable = NO;
    UIButton *button = [[[self previewView] headerView] alternateTrailingButton];
    [button setHidden:YES];
    [button setEnabled:NO];
    KayokoPasteboardItem *item = [self previewItem];
    NSString *historyKey = [self sourceHistoryKey];
    if (!item.imageName.length || !historyKey.length) return;

    NSUInteger generation = self.previewGeneration;
    __weak typeof(self) weakSelf = self;
    [[KayokoPasteboardManager sharedInstance] canRestoreImageForPasteboardItem:item inHistoryWithKey:historyKey
        completion:^(BOOL canRestore, NSError *error) {
            KayokoPreviewViewController *strongSelf = weakSelf;
            if (!strongSelf || strongSelf.previewGeneration != generation || strongSelf.previewItem != item) return;
            strongSelf.imageRestoreAvailable = canRestore && !error;
            KayokoHeaderView *header = strongSelf.previewView.headerView;
            [header updateStyleForButton:header.alternateTrailingButton withImageName:@"arrow.uturn.backward"
                              imageSize:kKayokoBackButtonImageSize tintColor:UIColor.labelColor];
            [header.alternateTrailingButton setAccessibilityLabel:KayokoPreviewLocalizedString(@"Restore Original")];
            [header.alternateTrailingButton setHidden:!strongSelf.imageRestoreAvailable];
            [header.alternateTrailingButton setEnabled:strongSelf.imageRestoreAvailable && !strongSelf.imageRestoreInProgress];
            [header.alternateTrailingButton setAlpha:1.0];
        }];
}

- (void)closeImageRestoreAlert:(UIAlertController *)alert completion:(dispatch_block_t)completion {
    if (!alert.presentingViewController) {
        completion();
    } else if (alert.isBeingDismissed && alert.transitionCoordinator) {
        [alert.transitionCoordinator animateAlongsideTransition:nil
            completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) { completion(); }];
    } else {
        [alert dismissViewControllerAnimated:YES completion:completion];
    }
}

- (void)finishImageRestoreForGeneration:(NSUInteger)generation {
    if (self.previewGeneration != generation) return;
    self.imageRestoreAlert = nil;
    self.imageRestoreInProgress = NO;
    self.previewView.userInteractionEnabled = YES;
    [self setEditButtonEnabled:YES];
    [self refreshImageRestoreAvailability];
    [[self delegate] previewViewControllerDidFinishImageEditing:self];
}

- (void)handleRestoreImageButtonPressed {
    UIViewController *presenter = self.parentViewController ?: self;
    if (!self.imageRestoreAvailable || self.imageRestoreInProgress || self.previewView.hidden ||
        [self.imageEditPresenter shouldSuppressExternalHideRequest] || !presenter.viewIfLoaded.window ||
        presenter.presentedViewController || presenter.isBeingPresented || presenter.isBeingDismissed) return;

    KayokoPasteboardItem *item = self.previewItem;
    NSString *historyKey = self.sourceHistoryKey;
    NSUInteger generation = self.previewGeneration;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:KayokoPreviewLocalizedString(@"Restore to Original?")
        message:KayokoPreviewLocalizedString(@"This removes all edits from this image.") preferredStyle:UIAlertControllerStyleAlert];
    self.imageRestoreAlert = alert;
    self.imageRestoreInProgress = YES;
    __weak typeof(self) weakSelf = self;
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:KayokoPreviewLocalizedString(@"Cancel") style:UIAlertActionStyleCancel
        handler:^(__unused UIAlertAction *action) {
            [weakSelf closeImageRestoreAlert:weakAlert completion:^{ [weakSelf finishImageRestoreForGeneration:generation]; }];
        }]];
    [alert addAction:[UIAlertAction actionWithTitle:KayokoPreviewLocalizedString(@"Restore Original") style:UIAlertActionStyleDestructive
        handler:^(__unused UIAlertAction *action) {
            [weakSelf closeImageRestoreAlert:weakAlert completion:^{
                KayokoPreviewViewController *strongSelf = weakSelf;
                if (!strongSelf || strongSelf.previewGeneration != generation) return;
                strongSelf.imageRestoreAlert = nil;
                strongSelf.previewView.userInteractionEnabled = NO;
                [[KayokoPasteboardManager sharedInstance] restoreOriginalImageForPasteboardItem:item inHistoryWithKey:historyKey
                    completion:^(KayokoPasteboardItem *updatedItem, NSError *error) {
                        KayokoPreviewViewController *current = weakSelf;
                        if (!current || current.previewGeneration != generation) return;
                        if (!updatedItem || error) {
                            [current presentImageRestoreFailureForGeneration:generation];
                            return;
                        }
                        current.imageRestoreInProgress = NO;
                        [current showPreviewWithItem:updatedItem sourceHistoryKey:historyKey];
                        [[current delegate] previewViewControllerDidFinishImageEditing:current];
                    }];
            }];
        }]];
    [presenter presentViewController:alert animated:YES completion:^{
        if (weakSelf.imageRestoreAlert != alert) [alert dismissViewControllerAnimated:NO completion:nil];
    }];
    if (self.hapticFeedbackHandler) self.hapticFeedbackHandler(UIImpactFeedbackStyleLight);
}

- (void)presentImageRestoreFailureForGeneration:(NSUInteger)generation {
    UIViewController *presenter = self.parentViewController ?: self;
    if (!presenter.viewIfLoaded.window || presenter.presentedViewController || presenter.isBeingDismissed) {
        [self finishImageRestoreForGeneration:generation];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:KayokoPreviewLocalizedString(@"Unable to Restore Image")
        message:KayokoPreviewLocalizedString(@"The current image has not been changed. Please try again.")
        preferredStyle:UIAlertControllerStyleAlert];
    self.imageRestoreAlert = alert;
    __weak typeof(self) weakSelf = self;
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:KayokoPreviewLocalizedString(@"OK") style:UIAlertActionStyleCancel
        handler:^(__unused UIAlertAction *action) {
            [weakSelf closeImageRestoreAlert:weakAlert completion:^{ [weakSelf finishImageRestoreForGeneration:generation]; }];
        }]];
    [presenter presentViewController:alert animated:YES completion:^{
        if (weakSelf.imageRestoreAlert != alert) [alert dismissViewControllerAnimated:NO completion:nil];
    }];
}

- (void)handleShareButtonPressed {
    id activityItem = [self activityItemForPreviewItem:[self previewItem]];
    if (!activityItem || [[self previewView] isHidden]) {
        return;
    }

    KayokoHeaderView *headerView = [[self previewView] headerView];
    if ([[self activitySharePresenter] presentActivityItems:@[ activityItem ]
                                             fromController:self
                                                 anchorView:[headerView shareButton]]) {
        if ([self hapticFeedbackHandler]) {
            [self hapticFeedbackHandler](UIImpactFeedbackStyleLight);
        }
    }
}

- (void)handleActionButtonWithCompletion:(void (^)(BOOL success))completion {
    KayokoPasteboardItem *item = [self previewItem];
    if (!item || [[self previewView] isHidden]) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    if ([[item imageName] length] > 0) {
        UIButton *actionButton = [[[self previewView] headerView] trailingButton];
        if (![actionButton isEnabled]) {
            if (completion) {
                completion(NO);
            }
            return;
        }

        [actionButton setEnabled:NO];
        NSUInteger generation = self.previewGeneration;
        __weak typeof(self) weakSelf = self;
        [[self actionHandler] saveImageForItem:item completion:^(BOOL success) {
          __strong typeof(weakSelf) strongSelf = weakSelf;
          BOOL isCurrentPreview = strongSelf && strongSelf.previewGeneration == generation &&
                                  [strongSelf previewItem] == item && ![[strongSelf previewView] isHidden];
          if (isCurrentPreview) {
              [[[[strongSelf previewView] headerView] trailingButton] setEnabled:YES];
          }
          if (completion) {
              completion(success && isCurrentPreview);
          }
        }];
        return;
    }
    [[self actionHandler] copyItem:item completion:completion];
}

#pragma mark - Dismissal

- (void)hidePreview {
    self.previewGeneration++;
    [self dismissImageEditing];
    [self dismissTextActions];
    [[self activitySharePresenter] dismissActivityAnimated:NO];
    [[[[self previewView] headerView] shareButton] setHidden:YES];
    [self setEditButtonHidden:YES];
    [[self previewView] setUserInteractionEnabled:YES];
    [self setPreviewItem:nil];

    [[self previewView] reset];
    [self setSourceHistoryKey:nil];
}

- (void)resetPreviewState {
    self.previewGeneration++;
    [self dismissImageEditing];
    [self dismissTextActions];
    [[self activitySharePresenter] dismissActivityAnimated:NO];
    [[self previewView] reset];
    [[self previewView] setHidden:YES];
    [[self previewView] setUserInteractionEnabled:YES];
    [[[[self previewView] headerView] shareButton] setHidden:YES];
    [self setEditButtonHidden:YES];
    [self setPreviewItem:nil];
    [self setSourceHistoryKey:nil];
}

- (void)scrollToTopAnimated:(BOOL)animated {
    [[self previewView] scrollToTopAnimated:animated];
}

- (void)dismissTextActions {
    [[self textActionPresenter] dismissActionsAnimated:NO];
    KayokoHeaderView *headerView = [[self previewView] headerView];
    [[headerView openLinkButton] setHidden:YES];
    [[headerView translationButton] setHidden:YES];
    [[headerView bookButton] setHidden:YES];
}

- (BOOL)shouldSuppressExternalHideRequest {
    return self.imageRestoreInProgress || [[self imageEditPresenter] shouldSuppressExternalHideRequest] ||
           [[self textActionPresenter] shouldSuppressExternalHideRequest];
}

@end
