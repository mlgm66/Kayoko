//
//  KayokoWordSelectionViewController.m
//  Kayoko
//

#import "KayokoWordSelectionViewController.h"

#import "KayokoHeaderButtonStyle.h"
#import "KayokoHeaderView.h"
#import "KayokoActivitySharePresenter.h"
#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"
#import "KayokoTextActionPresenter.h"
#import "KayokoWordSelectionView.h"

static NSUInteger const kKayokoWordSelectionMaximumTextLength = 5000;

static NSString *kayokoWordSelectionTextByTrimmingBoundaryNewlines(NSString *text) {
    return [(text ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

NS_ASSUME_NONNULL_BEGIN

@interface KayokoWordSelectionViewController ()
#pragma mark - Views
@property(nonatomic, strong, readwrite) KayokoWordSelectionView *wordSelectionView;

#pragma mark - State

@property(nonatomic, copy, nullable, readwrite) NSString *sourceHistoryKey;
@property(nonatomic, strong, nullable, readwrite) KayokoPasteboardItem *sourceItem;
@property(nonatomic, strong) KayokoTextActionPresenter *textActionPresenter;
@property(nonatomic, strong) KayokoActivitySharePresenter *activitySharePresenter;
@property(nonatomic, assign) BOOL usesSelectionOrderForSelectedText;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoWordSelectionViewController

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _wordSelectionView = [[KayokoWordSelectionView alloc] init];
        [_wordSelectionView setHidden:YES];
        _textActionPresenter = [[KayokoTextActionPresenter alloc] init];
        [[[_wordSelectionView headerView] alternateTrailingButton]
                   addTarget:self
                      action:@selector(handleSelectionOrderButtonPressed)
            forControlEvents:UIControlEventTouchUpInside];
        [[[_wordSelectionView headerView] selectionActionButton]
                   addTarget:self
                      action:@selector(handleSelectionActionButtonPressed)
            forControlEvents:UIControlEventTouchUpInside];
        [[[_wordSelectionView headerView] translationButton]
                   addTarget:self
                      action:@selector(handleTranslationButtonPressed)
            forControlEvents:UIControlEventTouchUpInside];
        [[[_wordSelectionView headerView] bookButton]
                   addTarget:self
                      action:@selector(handleBookButtonPressed)
            forControlEvents:UIControlEventTouchUpInside];
        [[[_wordSelectionView headerView] shareButton]
                   addTarget:self
                      action:@selector(handleShareButtonPressed)
            forControlEvents:UIControlEventTouchUpInside];
        [[[_wordSelectionView headerView] editButton]
                   addTarget:self
                      action:@selector(handleEditButtonPressed)
            forControlEvents:UIControlEventTouchUpInside];
        _activitySharePresenter = [[KayokoActivitySharePresenter alloc] init];
        [self setView:_wordSelectionView];

        __weak typeof(self) weakSelf = self;
        [_wordSelectionView setSelectionChangedHandler:^{
          [weakSelf updateActionButtonState];
          [weakSelf updateSelectionActionButtonStates];
          [weakSelf updateTranslationButtonState];
          [weakSelf updateBookButtonState];
          [weakSelf updateShareButtonState];
          if ([weakSelf selectionChangedHandler]) {
              [weakSelf selectionChangedHandler]();
          }
        }];
    }
    return self;
}

#pragma mark - Public State

- (NSString *)selectedText {
    return [[self wordSelectionView] selectedText];
}

- (NSRange)selectedTextRangeInOriginalText {
    return [[self wordSelectionView] selectedTextRangeInOriginalText];
}

- (BOOL)isShowingWordSelection {
    return ![[self wordSelectionView] isHidden];
}

- (BOOL)hasSelectedText {
    return [[self wordSelectionView] hasSelectedText];
}

- (BOOL)canShowText:(NSString *)text {
    return [text length] <= kKayokoWordSelectionMaximumTextLength;
}

- (void)scrollToTopAnimated:(BOOL)animated {
    [[self wordSelectionView] scrollToTopAnimated:animated];
}

#pragma mark - Presentation

- (void)showWordSelectionWithItem:(KayokoPasteboardItem *)item
                 sourceHistoryKey:(NSString *)sourceHistoryKey
               automaticallyPaste:(BOOL)automaticallyPaste {
    [self setSourceItem:item];
    [self setSourceHistoryKey:sourceHistoryKey];

    NSString *text = kayokoWordSelectionTextByTrimmingBoundaryNewlines([item content]);
    [[self wordSelectionView] setUsesSelectionOrderForSelectedText:[self usesSelectionOrderForSelectedText]];
    [[self wordSelectionView] setText:text];
    [[self wordSelectionView] setHidden:NO];

    KayokoHeaderView *headerView = [[self wordSelectionView] headerView];
    [headerView setHidden:NO];
    [headerView setHistorySwitcherVisible:NO animated:NO];
    [headerView setTitleText:@""];
    [headerView updateStyleForButton:[headerView leadingButton]
                       withImageName:@"arrowshape.turn.up.backward"
                           imageSize:kKayokoFavoritesButtonImageSize
                           tintColor:[UIColor labelColor]];
    [headerView updateStyleForButton:[headerView trailingButton]
                       withImageName:(automaticallyPaste ? @"doc.on.clipboard" : @"doc.on.doc.fill")imageSize
                                    :kKayokoBackButtonImageSize
                           tintColor:[UIColor labelColor]];
    [headerView updateStyleForButton:[headerView openLinkButton]
                       withImageName:@"arrow.up"
                           imageSize:kKayokoBackButtonImageSize
                           tintColor:[UIColor labelColor]];
    [[headerView openLinkButton] setHidden:![item hasLink]];
    [[headerView openLinkButton] setEnabled:[item hasLink]];
    [[headerView openLinkButton] setAlpha:1.0];
    [[headerView alternateTrailingButton] setHidden:NO];
    [[headerView alternateTrailingButton] setEnabled:YES];
    [[headerView alternateTrailingButton] setAlpha:1.0];
    [[headerView alternateTrailingButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Selection Order"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
    [[headerView selectionActionButton] setHidden:NO];
    NSString *translationImageName = [UIImage systemImageNamed:@"character.bubble"] ? @"character.bubble" : @"globe";
    [headerView updateStyleForButton:[headerView translationButton]
                       withImageName:translationImageName
                           imageSize:kKayokoBackButtonImageSize
                           tintColor:[UIColor labelColor]];
    [headerView updateStyleForButton:[headerView bookButton]
                       withImageName:@"book.closed"
                           imageSize:kKayokoBackButtonImageSize
                           tintColor:[UIColor labelColor]];
    [[headerView bookButton] setHidden:NO];
    [headerView updateStyleForButton:[headerView shareButton]
                       withImageName:@"square.and.arrow.up"
                           imageSize:kKayokoBackButtonImageSize
                           tintColor:[UIColor labelColor]];
    [[headerView shareButton] setHidden:NO];
    [[headerView leadingButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Back"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
    [[headerView trailingButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle]
                                  localizedStringForKey:(automaticallyPaste ? @"Paste" : @"Copy")
                                                  value:nil
                                                  table:@"Tweak"]];
    [[headerView openLinkButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Open"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
    [[headerView shareButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Share"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
    [self configureEditButton];
    [self updateSelectionOrderButtonState];
    [self updateActionButtonState];
    [self updateSelectionActionButtonStates];
    [self updateTranslationButtonState];
    [self updateBookButtonState];
    [self updateShareButtonState];
}

#pragma mark - Dismissal

- (void)hideWordSelection {
    [self resetWordSelectionState];
}

#pragma mark - Actions

- (void)handleActionButtonWithAutomaticallyPaste:(BOOL)automaticallyPaste {
    KayokoPasteboardItem *sourceItem = [self sourceItem];
    NSString *text = [self textForActions];
    if (!sourceItem || ![self isShowingWordSelection] || [text length] == 0) {
        return;
    }
    KayokoPasteboardItem *selectedItem = [self hasSelectedText] ?
        [[KayokoPasteboardItem alloc] initWithBundleIdentifier:[sourceItem bundleIdentifier]
                                                    andContent:text
                                                withImageNamed:@""] : sourceItem;
    NSString *historyKey = [self sourceHistoryKey] ?: kKayokoHistoryKeyHistory;
    if (automaticallyPaste) {
        [[KayokoPasteboardManager sharedInstance] writePasteboardItem:selectedItem
                                                    sourceHistoryItem:sourceItem
                                                   fromHistoryWithKey:historyKey
                                                 allowsAutomaticPaste:YES];
    } else {
        KayokoPasteboardManager *pasteboardManager = [KayokoPasteboardManager sharedInstance];
        if ([pasteboardManager copyPasteboardItemToPasteboard:selectedItem]) {
            [pasteboardManager addPasteboardItem:selectedItem toHistoryWithKey:kKayokoHistoryKeyHistory];
        }
    }

    [[self delegate] wordSelectionViewController:self didRequestHideContainerAfterDirectPaste:automaticallyPaste];
    [[self delegate] wordSelectionViewController:self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)handleSelectionOrderButtonPressed {
    [self setUsesSelectionOrderForSelectedText:![self usesSelectionOrderForSelectedText]];
    [[self delegate] wordSelectionViewController:self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleLight];
}

- (void)handleSelectionActionButtonPressed {
    KayokoWordSelectionView *wordSelectionView = [self wordSelectionView];
    BOOL didChange = [wordSelectionView hasAllTokensSelected] ? [wordSelectionView clearSelectedTokens]
                                                               : [wordSelectionView selectAllTokens];
    if (didChange) {
        [[self delegate] wordSelectionViewController:self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleLight];
    }
}

- (void)handleTranslationButtonPressed {
    KayokoHeaderView *headerView = [[self wordSelectionView] headerView];
    if ([[self textActionPresenter] presentTranslationForText:[self textForActions]
                                             fromController:self
                                                 anchorView:[headerView translationButton]]) {
        [[self delegate] wordSelectionViewController:self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleLight];
    }
}

- (void)handleBookButtonPressed {
    if ([[self textActionPresenter] presentLookupForText:[self textForActions] fromController:self]) {
        [[self delegate] wordSelectionViewController:self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleLight];
    }
}

- (void)handleShareButtonPressed {
    NSString *text = [self textForActions];
    if ([text length] == 0) {
        return;
    }

    KayokoHeaderView *headerView = [[self wordSelectionView] headerView];
    if ([[self activitySharePresenter] presentActivityItems:@[ text ] fromController:self anchorView:[headerView shareButton]]) {
        [[self delegate] wordSelectionViewController:self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleLight];
    }
}

#pragma mark - State

- (void)setUsesSelectionOrderForSelectedText:(BOOL)usesSelectionOrderForSelectedText {
    if (_usesSelectionOrderForSelectedText == usesSelectionOrderForSelectedText) {
        return;
    }

    _usesSelectionOrderForSelectedText = usesSelectionOrderForSelectedText;
    [[self wordSelectionView] setUsesSelectionOrderForSelectedText:usesSelectionOrderForSelectedText];
    [self updateSelectionOrderButtonState];
    [self updateTranslationButtonState];
}

- (void)resetWordSelectionState {
    [[self textActionPresenter] dismissActionsAnimated:NO];
    [[self activitySharePresenter] dismissActivityAnimated:NO];
    [[[[self wordSelectionView] headerView] alternateTrailingButton] setHidden:YES];
    [[[[self wordSelectionView] headerView] selectionActionButton] setHidden:YES];
    [[[[self wordSelectionView] headerView] openLinkButton] setHidden:YES];
    [[[[self wordSelectionView] headerView] translationButton] setHidden:YES];
    [[[[self wordSelectionView] headerView] bookButton] setHidden:YES];
    [[[[self wordSelectionView] headerView] shareButton] setHidden:YES];
    [self setEditButtonHidden:YES];
    [[self wordSelectionView] setHidden:YES];
    [[self wordSelectionView] setUserInteractionEnabled:YES];
    [[self wordSelectionView] reset];
    [self setSourceItem:nil];
    [self setSourceHistoryKey:nil];
}

- (BOOL)shouldSuppressExternalHideRequest {
    return [[self textActionPresenter] shouldSuppressExternalHideRequest];
}

#pragma mark - Edit

- (void)configureEditButton {
    KayokoHeaderView *headerView = [[self wordSelectionView] headerView];
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
    UIButton *editButton = [[[self wordSelectionView] headerView] editButton];
    [editButton setHidden:hidden];
    if (hidden) {
        [editButton setEnabled:NO];
        [editButton setAlpha:0];
    }
}

- (void)setEditButtonEnabled:(BOOL)enabled {
    UIButton *editButton = [[[self wordSelectionView] headerView] editButton];
    [editButton setEnabled:enabled];
    [editButton setAlpha:(enabled && ![editButton isHidden]) ? 1.0 : 0.35];
}

- (void)handleEditButtonPressed {
    if (![self isShowingWordSelection] || ![self sourceItem] || [[self sourceHistoryKey] length] == 0) {
        return;
    }

    UIButton *editButton = [[[self wordSelectionView] headerView] editButton];
    if ([editButton isHidden] || ![editButton isEnabled]) {
        return;
    }

    [self setEditButtonEnabled:NO];
    [[self delegate] wordSelectionViewControllerDidRequestEdit:self];
}

- (NSString *)textForActions {
    return [self hasSelectedText] ? [self selectedText] :
        kayokoWordSelectionTextByTrimmingBoundaryNewlines([[self sourceItem] content]);
}

#pragma mark - Header

- (void)updateActionButtonState {
    BOOL enabled = [[self textForActions] length] > 0;
    UIButton *actionButton = [[[self wordSelectionView] headerView] trailingButton];
    [actionButton setEnabled:enabled];
    [actionButton setAlpha:enabled ? 1.0 : 0.35];
}

- (void)updateShareButtonState {
    UIButton *shareButton = [[[self wordSelectionView] headerView] shareButton];
    BOOL enabled = [[self textForActions] length] > 0;
    [shareButton setEnabled:enabled];
    [shareButton setAlpha:enabled ? 1.0 : 0.35];
}

- (void)updateSelectionOrderButtonState {
    UIButton *selectionOrderButton = [[[self wordSelectionView] headerView] alternateTrailingButton];
    BOOL enabled = [self usesSelectionOrderForSelectedText];
    NSString *preferredImageName = enabled ? @"123.rectangle.fill" : @"123.rectangle";
    NSString *imageName = [UIImage systemImageNamed:preferredImageName] ? preferredImageName : @"textformat.123";
    [[[self wordSelectionView] headerView]
        updateStyleForButton:selectionOrderButton
               withImageName:imageName
                   imageSize:kKayokoBackButtonImageSize
                   tintColor:[UIColor labelColor]];
    [selectionOrderButton setSelected:enabled];
    UIAccessibilityTraits traits = [selectionOrderButton accessibilityTraits] | UIAccessibilityTraitButton;
    if (enabled) {
        traits |= UIAccessibilityTraitSelected;
    } else {
        traits &= ~UIAccessibilityTraitSelected;
    }
    [selectionOrderButton setAccessibilityTraits:traits];
}

- (void)updateSelectionActionButtonStates {
    KayokoWordSelectionView *wordSelectionView = [self wordSelectionView];
    UIButton *selectionActionButton = [[wordSelectionView headerView] selectionActionButton];
    BOOL hasAllTokensSelected = [wordSelectionView hasAllTokensSelected];
    BOOL enabled = [wordSelectionView hasTokens];
    NSString *imageName = hasAllTokensSelected ? @"xmark.circle" : @"checkmark.circle";
    NSString *accessibilityKey = hasAllTokensSelected ? @"Clear Selection" : @"Select All";

    [[wordSelectionView headerView] updateStyleForButton:selectionActionButton
                                             withImageName:imageName
                                                 imageSize:kKayokoBackButtonImageSize
                                                 tintColor:[UIColor labelColor]];
    [selectionActionButton setEnabled:enabled];
    [selectionActionButton setAlpha:enabled ? 1.0 : 0.35];
    [selectionActionButton
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:accessibilityKey
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
}

- (void)updateTranslationButtonState {
    UIButton *translationButton = [[[self wordSelectionView] headerView] translationButton];
    BOOL available = [[self textActionPresenter] isTranslationAvailable];
    [translationButton setHidden:!available];
    if (!available) {
        return;
    }

    BOOL enabled = [[self textForActions] length] > 0;
    [translationButton setEnabled:enabled];
    [translationButton setAlpha:enabled ? 1.0 : 0.35];
    [translationButton
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Translate"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
}

- (void)updateBookButtonState {
    UIButton *bookButton = [[[self wordSelectionView] headerView] bookButton];
    BOOL enabled = [[self textForActions] length] > 0;
    [bookButton setEnabled:enabled];
    [bookButton setAlpha:enabled ? 1.0 : 0.35];
    [bookButton setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle]
                                          localizedStringForKey:@"Look Up" value:nil table:@"Tweak"]];
}

@end
