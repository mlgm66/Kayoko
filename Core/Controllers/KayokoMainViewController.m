//
//  KayokoMainViewController.m
//  Kayoko
//

#import "KayokoMainViewController.h"
#import "KayokoClearConfirmationView.h"
#import "KayokoClearConfirmationViewController.h"
#import "KayokoEmptyStateView.h"
#import "KayokoExternalHideCoordinator.h"
#import "KayokoHeaderButtonStyle.h"
#import "KayokoHeaderView.h"
#import "KayokoHistoryItemActionHandler.h"
#import "KayokoHistoryController.h"
#import "KayokoHistoryListView.h"
#import "KayokoHistoryListViewController.h"
#import "KayokoMainView.h"
#import "KayokoNoteEditorView.h"
#import "KayokoNoteEditorViewController.h"
#import "KayokoPanelPresentationController.h"
#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"
#import "KayokoPreviewView.h"
#import "KayokoPreviewViewController.h"
#import "KayokoTextEditorView.h"
#import "KayokoTextEditorViewController.h"
#import "KayokoSearchController.h"
#import "KayokoTagChipBarView.h"
#import "KayokoTableViewCell.h"
#import "KayokoTagCatalog.h"
#import "KayokoWordSelectionView.h"
#import "KayokoWordSelectionViewController.h"

#import <QuartzCore/QuartzCore.h>


static CGFloat const kKayokoTransientEdgeBackHorizontalDominance = 1.2;
static CGFloat const kKayokoTransientEdgeBackCompletionProgress = 0.35;
static CGFloat const kKayokoTransientEdgeBackCompletionVelocity = 650;
static NSTimeInterval const kKayokoTransientEdgeBackMinimumAnimationDuration = 0.08;
static NSTimeInterval const kKayokoTransientEdgeBackMaximumAnimationDuration = 0.22;
static NSTimeInterval const kKayokoSearchInputExternalHideSuppressionDuration = 0.75;

typedef NS_ENUM(NSUInteger, KayokoNoteEditingOrigin) {
    KayokoNoteEditingOriginNone = 0,
    KayokoNoteEditingOriginList,
    KayokoNoteEditingOriginPreview,
    KayokoNoteEditingOriginWordSelection,
};

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openSensitiveURL:(NSURL *)url withOptions:(NSDictionary *)options error:(NSError **)error;
@end

NS_ASSUME_NONNULL_BEGIN

@interface KayokoMainViewController () <KayokoClearConfirmationViewControllerDelegate, KayokoHistoryControllerDelegate,
                                        KayokoPanelPresentationControllerDelegate, KayokoSearchControllerDelegate,
                                        KayokoHistoryListViewControllerDelegate, KayokoNoteEditorViewControllerDelegate,
                                        KayokoPreviewViewControllerDelegate, KayokoTextEditorViewControllerDelegate,
                                        KayokoWordSelectionViewControllerDelegate,
                                        UIGestureRecognizerDelegate>
#pragma mark - Views

@property(nonatomic, strong) KayokoMainView *mainView;
@property(nonatomic, strong) KayokoEmptyStateView *historyEmptyStateView;
@property(nonatomic, strong) KayokoEmptyStateView *favoritesEmptyStateView;
@property(nonatomic, strong) KayokoEmptyStateView *storageErrorView;

#pragma mark - Child Controllers

@property(nonatomic, strong) KayokoHistoryListViewController *historyListViewController;
@property(nonatomic, strong) KayokoHistoryListViewController *favoritesListViewController;
@property(nonatomic, strong) KayokoClearConfirmationViewController *clearConfirmationViewController;
@property(nonatomic, strong) KayokoPreviewViewController *previewViewController;
@property(nonatomic, strong) KayokoTextEditorViewController *textEditorViewController;
@property(nonatomic, strong) KayokoWordSelectionViewController *wordSelectionViewController;
@property(nonatomic, strong) KayokoNoteEditorViewController *noteEditorViewController;

#pragma mark - Coordinators

@property(nonatomic, strong) KayokoHistoryController *historyController;
@property(nonatomic, strong) KayokoPanelPresentationController *panelPresentationController;
@property(nonatomic, strong) KayokoSearchController *searchController;

#pragma mark - State

@property(nonatomic, copy, nullable) NSString *clearConfirmationHistoryKey;
@property(nonatomic, strong, nullable) NSError *storageError;
@property(nonatomic, assign) BOOL preparingToShow;
@property(nonatomic, assign) NSUInteger showRequestIdentifier;
@property(nonatomic, assign, getter=isDismissingPanel) BOOL dismissingPanel;
@property(nonatomic, strong) KayokoExternalHideCoordinator *externalHideCoordinator;

#pragma mark - Transient Content

@property(nonatomic, assign) BOOL restoresSearchFirstResponderAfterTransientContent;
@property(nonatomic, assign) BOOL hasSearchContentOffsetBeforeTransientContent;
@property(nonatomic, assign) CGPoint searchContentOffsetBeforeTransientContent;
@property(nonatomic, weak, nullable) UIView *activeSourceContentView;
@property(nonatomic, strong) UIScreenEdgePanGestureRecognizer *transientEdgeBackGestureRecognizer;
@property(nonatomic, weak, nullable) UIView *interactiveTransientReturnSourceView;
@property(nonatomic, weak, nullable) UIView *interactiveTransientReturnContentView;
@property(nonatomic, assign) BOOL interactiveTransientReturnWasPreview;
@property(nonatomic, assign) BOOL didRestoreSearchDuringInteractiveTransientReturn;

#pragma mark - Note Editing

@property(nonatomic, strong, nullable) KayokoPasteboardItem *noteEditingItem;
@property(nonatomic, copy, nullable) NSString *noteEditingHistoryKey;
@property(nonatomic, weak, nullable) KayokoHistoryListViewController *noteEditingSourceListViewController;
@property(nonatomic, assign) NSUInteger noteEditingRequestIdentifier;
@property(nonatomic, assign) BOOL noteEditingBeganFromSearch;
@property(nonatomic, assign) BOOL noteEditingKeepsSearchHeaderHidden;
@property(nonatomic, assign, getter=isFinishingNoteEditing) BOOL finishingNoteEditing;
@property(nonatomic, assign) CGRect noteEditingOriginalPanelFrame;
@property(nonatomic, assign) NSTimeInterval noteEditingKeyboardAnimationDuration;
@property(nonatomic, assign) UIViewAnimationOptions noteEditingKeyboardAnimationOptions;
@property(nonatomic, assign) KayokoNoteEditingOrigin noteEditingOrigin;
@property(nonatomic, assign) BOOL previewTextEditingBeganFromWordSelection;
@property(nonatomic, assign) CGRect previewTextEditingOriginalPanelFrame;
@property(nonatomic, assign, getter=isPreviewTextEditingFinishing) BOOL previewTextEditingFinishing;
@property(nonatomic, assign) NSUInteger previewTextEditingRequestIdentifier;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoMainViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _itemDetailsMode = kKayokoPreferenceKeyItemDetailsModeDefaultValue;
        _clearButtonMode = kKayokoPreferenceKeyClearButtonModeDefaultValue;
        _kayokoSupportedInterfaceOrientations = UIInterfaceOrientationMaskAll;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePreviewTextEditingKeyboardWillChangeFrameNotification:)
                                                     name:UIKeyboardWillChangeFrameNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePreviewTextEditingKeyboardWillHideNotification:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];
        _presentationMode = KayokoPanelPresentationModePortraitDrawer;
        _externalHideCoordinator = [[KayokoExternalHideCoordinator alloc] init];
        _mainView = [[KayokoMainView alloc] initWithFrame:frame];
        [self setView:_mainView];
        _historyListViewController = [[KayokoHistoryListViewController alloc]
            initWithName:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"History"
                                                                                       value:nil
                                                                                       table:@"Tweak"]
              historyKey:kKayokoHistoryKeyHistory];
        [_historyListViewController setDelegate:self];
        [self addChildViewController:_historyListViewController];
        [_mainView installContentView:[_historyListViewController tableView] hidden:NO];
        [_historyListViewController didMoveToParentViewController:self];

        _favoritesListViewController = [[KayokoHistoryListViewController alloc]
            initWithName:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Favorites"
                                                                                       value:nil
                                                                                       table:@"Tweak"]
              historyKey:kKayokoHistoryKeyFavorites];
        [_favoritesListViewController setDelegate:self];
        [self addChildViewController:_favoritesListViewController];
        [_mainView installContentView:[_favoritesListViewController tableView] hidden:YES];
        [_favoritesListViewController didMoveToParentViewController:self];

        _historyController =
            [[KayokoHistoryController alloc] initWithHistoryListViewController:_historyListViewController
                                                   favoritesListViewController:_favoritesListViewController];
        [_historyController setDelegate:self];

        __weak typeof(self) weakSelf = self;
        [[[_mainView headerView] historySegmentedControl]
            addTarget:self
               action:@selector(handleHistorySegmentedControlChanged:)
     forControlEvents:UIControlEventValueChanged];
        [[[_mainView headerView] leadingButton] setHidden:NO];
        [[[_mainView headerView] leadingButton] setShowsMenuAsPrimaryAction:YES];
        [[[_mainView headerView] trailingButton] addTarget:self
                                                    action:@selector(handleClearButtonPressed)
                                          forControlEvents:UIControlEventTouchUpInside];
        [[[_mainView headerView] titleTapControl] addTarget:self
                                                     action:@selector(handleTitleTapControlPressed)
                                           forControlEvents:UIControlEventTouchUpInside];

        _panelPresentationController = [[KayokoPanelPresentationController alloc] initWithPanelView:_mainView];
        [_panelPresentationController setDelegate:self];

        _clearConfirmationViewController = [[KayokoClearConfirmationViewController alloc] init];
        [_clearConfirmationViewController setDelegate:self];
        [self addChildViewController:_clearConfirmationViewController];
        [_mainView installContentView:[_clearConfirmationViewController confirmationView] hidden:YES];
        [_clearConfirmationViewController didMoveToParentViewController:self];

        _historyEmptyStateView = [[KayokoEmptyStateView alloc] init];
        [_historyEmptyStateView updateWithHistoryKey:kKayokoHistoryKeyHistory];
        [_mainView installContentView:_historyEmptyStateView hidden:YES];

        _favoritesEmptyStateView = [[KayokoEmptyStateView alloc] init];
        [_favoritesEmptyStateView updateWithHistoryKey:kKayokoHistoryKeyFavorites];
        [_mainView installContentView:_favoritesEmptyStateView hidden:YES];

        _storageErrorView = [[KayokoEmptyStateView alloc] init];
        [_mainView installContentView:_storageErrorView hidden:YES];

        _previewViewController = [[KayokoPreviewViewController alloc] init];
        [_previewViewController setDelegate:self];
        [_previewViewController setHapticFeedbackHandler:^(UIImpactFeedbackStyle style) {
          [[weakSelf panelPresentationController] triggerHapticFeedbackWithStyle:style];
        }];
        [self addChildViewController:_previewViewController];
        KayokoHeaderView *previewHeaderView = [[_previewViewController previewView] headerView];
        [_mainView installFullContentView:[_previewViewController previewView] headerView:previewHeaderView hidden:YES];
        [_panelPresentationController registerHeaderView:previewHeaderView];
        [_previewViewController didMoveToParentViewController:self];
        [[previewHeaderView leadingButton] addTarget:self
                                              action:@selector(handleTransientBackButtonPressed)
                                    forControlEvents:UIControlEventTouchUpInside];
        [[previewHeaderView trailingButton] addTarget:self
                                               action:@selector(handlePreviewActionButtonPressed)
                                     forControlEvents:UIControlEventTouchUpInside];
        [[previewHeaderView openLinkButton] addTarget:self
            action:@selector(handleOpenLinkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [[previewHeaderView titleTapControl] addTarget:self
                                                action:@selector(handleTitleTapControlPressed)
                                      forControlEvents:UIControlEventTouchUpInside];

        _textEditorViewController = [[KayokoTextEditorViewController alloc] init];
        [_textEditorViewController setDelegate:self];
        [self addChildViewController:_textEditorViewController];
        KayokoHeaderView *textEditorHeaderView = [[_textEditorViewController textEditorView] headerView];
        [_mainView installFullContentView:[_textEditorViewController textEditorView]
                               headerView:textEditorHeaderView
                                   hidden:YES];
        [_panelPresentationController registerHeaderView:textEditorHeaderView];
        [_textEditorViewController didMoveToParentViewController:self];
        [[textEditorHeaderView leadingButton] addTarget:self
                                                 action:@selector(handleTransientBackButtonPressed)
                                       forControlEvents:UIControlEventTouchUpInside];

        _wordSelectionViewController = [[KayokoWordSelectionViewController alloc] init];
        [_wordSelectionViewController setDelegate:self];
        [self addChildViewController:_wordSelectionViewController];
        KayokoHeaderView *wordSelectionHeaderView = [[_wordSelectionViewController wordSelectionView] headerView];
        [_mainView installFullContentView:[_wordSelectionViewController view]
                               headerView:wordSelectionHeaderView
                                   hidden:YES];
        [_panelPresentationController registerHeaderView:wordSelectionHeaderView];
        [_wordSelectionViewController didMoveToParentViewController:self];
        [[wordSelectionHeaderView leadingButton] addTarget:self
                                                    action:@selector(handleTransientBackButtonPressed)
                                          forControlEvents:UIControlEventTouchUpInside];
        [[wordSelectionHeaderView trailingButton] addTarget:self
                                                     action:@selector(handlePreviewActionButtonPressed)
                                           forControlEvents:UIControlEventTouchUpInside];
        [[wordSelectionHeaderView openLinkButton] addTarget:self
            action:@selector(handleOpenLinkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [[wordSelectionHeaderView titleTapControl] addTarget:self
                                                      action:@selector(handleTitleTapControlPressed)
                                            forControlEvents:UIControlEventTouchUpInside];

        _searchController =
            [[KayokoSearchController alloc] initWithContainerView:_mainView
                                                       headerView:[_mainView headerView]
                                        historyListViewController:_historyListViewController
                                      favoritesListViewController:_favoritesListViewController
                                             panGestureRecognizer:[_panelPresentationController panGestureRecognizer]];
        [_searchController setDelegate:self];

        _noteEditorViewController = [[KayokoNoteEditorViewController alloc] init];
        [_noteEditorViewController setDelegate:self];
        [self addChildViewController:_noteEditorViewController];
        KayokoNoteEditorView *noteEditorView = (KayokoNoteEditorView *)[_noteEditorViewController view];
        [noteEditorView setHidden:YES];
        [[_mainView chromeClipView] addSubview:noteEditorView];
        [noteEditorView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[noteEditorView topAnchor] constraintEqualToAnchor:[[_mainView chromeClipView] topAnchor]],
            [[noteEditorView leadingAnchor] constraintEqualToAnchor:[[_mainView chromeClipView] leadingAnchor]],
            [[noteEditorView trailingAnchor] constraintEqualToAnchor:[[_mainView chromeClipView] trailingAnchor]],
            [[noteEditorView bottomAnchor] constraintEqualToAnchor:[[_mainView chromeClipView] bottomAnchor]]
        ]];
        [_noteEditorViewController didMoveToParentViewController:self];

        _transientEdgeBackGestureRecognizer = [[UIScreenEdgePanGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(handleTransientEdgeBackGestureRecognizer:)];
        [_transientEdgeBackGestureRecognizer setEdges:UIRectEdgeLeft];
        [_transientEdgeBackGestureRecognizer setDelegate:self];
        [_mainView addGestureRecognizer:_transientEdgeBackGestureRecognizer];

        [[_previewViewController previewView]
            requireImagePanGestureRecognizerToFailGestureRecognizer:_transientEdgeBackGestureRecognizer];
        [[_wordSelectionViewController wordSelectionView]
            requireSelectionGestureRecognizerToFailGestureRecognizer:_transientEdgeBackGestureRecognizer];
    }
    return self;
}

#pragma mark - Configuration

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return [self kayokoSupportedInterfaceOrientations];
}

- (BOOL)isHidden {
    return [[self mainView] isHidden];
}

- (void)setOutsideDismissOverlayView:(UIControl *)outsideDismissOverlayView {
    [[self panelPresentationController] setOutsideDismissOverlayView:outsideDismissOverlayView];
}

- (void)applyUserInterfaceStyle:(UIUserInterfaceStyle)style {
    [self setOverrideUserInterfaceStyle:style];
    [[self view] setOverrideUserInterfaceStyle:style];

    for (UIViewController *childViewController in [self childViewControllers]) {
        [childViewController setOverrideUserInterfaceStyle:style];
        [[childViewController view] setOverrideUserInterfaceStyle:style];
    }

    [[self historyEmptyStateView] setOverrideUserInterfaceStyle:style];
    [[self favoritesEmptyStateView] setOverrideUserInterfaceStyle:style];
    [[self storageErrorView] setOverrideUserInterfaceStyle:style];
}

- (void)setDismissOnOutsideTouch:(BOOL)dismissOnOutsideTouch {
    _dismissOnOutsideTouch = dismissOnOutsideTouch;
    [[self panelPresentationController] setDismissOnOutsideTouch:dismissOnOutsideTouch];
}

- (void)setPreviewLineCount:(NSUInteger)previewLineCount {
    _previewLineCount = previewLineCount;
    [[self historyListViewController] setPreviewLineCount:previewLineCount];
    [[self favoritesListViewController] setPreviewLineCount:previewLineCount];
}

- (void)setItemDetailsMode:(KayokoItemDetailsMode)itemDetailsMode {
    if (itemDetailsMode != kKayokoItemDetailsModeOff && itemDetailsMode != kKayokoItemDetailsModeImagesOnly &&
        itemDetailsMode != kKayokoItemDetailsModeAll) {
        itemDetailsMode = kKayokoPreferenceKeyItemDetailsModeDefaultValue;
    }
    _itemDetailsMode = itemDetailsMode;
    [[self historyListViewController] setItemDetailsMode:itemDetailsMode];
    [[self favoritesListViewController] setItemDetailsMode:itemDetailsMode];
}

- (void)setClearButtonMode:(KayokoClearButtonMode)clearButtonMode {
    if (clearButtonMode != kKayokoClearButtonModeOff && clearButtonMode != kKayokoClearButtonModeHistoryOnly &&
        clearButtonMode != kKayokoClearButtonModeAlways) {
        clearButtonMode = kKayokoPreferenceKeyClearButtonModeDefaultValue;
    }
    _clearButtonMode = clearButtonMode;
    [self updateClearButtonState];
}

- (void)setShouldPlayFeedback:(BOOL)shouldPlayFeedback {
    _shouldPlayFeedback = shouldPlayFeedback;
    [[self panelPresentationController] setShouldPlayFeedback:shouldPlayFeedback];
}


- (void)setPresentationMode:(KayokoPanelPresentationMode)presentationMode {
    _presentationMode = presentationMode;
    [[self panelPresentationController] setPresentationMode:presentationMode];
    [[self searchController] setPresentationMode:presentationMode];
    [[[self noteEditorViewController] noteEditorView]
        setCompactLayout:presentationMode == KayokoPanelPresentationModeCompactLandscapeFullscreen];
    [self applyBasePresentationLayout];
}

- (void)applyBasePresentationLayout {
    if ([self presentationMode] == KayokoPanelPresentationModeCompactLandscapeFullscreen) {
        [[self mainView] setContentSafeAreaAdditionalInsets:UIEdgeInsetsZero];
        [[self mainView] setContentRespectsSafeArea:YES];
        return;
    }

    if (![[self searchController] isSearchActive]) {
        [[self mainView] setContentRespectsSafeArea:NO];
        [[self mainView] setContentSafeAreaAdditionalInsets:UIEdgeInsetsZero];
    }
}


#pragma mark - Layout and Lookup

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self handleViewLayout];
}

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    [self handleViewLayout];
}

- (void)handleViewLayout {
    [[self searchController] layout];
}

- (NSString *)effectiveActiveHistoryKey {
    return [[self historyController]
        effectiveActiveHistoryKeyWithClearConfirmationHistoryKey:[self clearConfirmationHistoryKey]];
}

- (KayokoHistoryListView *)activeTableView {
    return [[self historyController] activeTableViewWithClearConfirmationHistoryKey:[self clearConfirmationHistoryKey]];
}

- (KayokoHistoryListViewController *)activeListViewController {
    return [[self historyController] listViewControllerForHistoryKey:[self effectiveActiveHistoryKey]];
}

- (KayokoHistoryListViewController *)listViewControllerForHistoryKey:(NSString *)historyKey {
    return [[self historyController] listViewControllerForHistoryKey:historyKey];
}

- (KayokoHistoryListViewController *)activeListViewControllerForSearchController:
    (KayokoSearchController *)searchController {
    (void)searchController;
    return [self activeListViewController];
}

#pragma mark - External Hide Coordinator

- (BOOL)externalHideRequestShouldWaitForAnimations {
    return [self preparingToShow] || [[self mainView] isAnimating] || [[self panelPresentationController] isAnimating];
}

- (void)executePendingExternalHideRequestIfReady {
    if ([[self externalHideCoordinator] shouldSuppressExternalHide] ||
        [[self previewViewController] shouldSuppressExternalHideRequest] ||
        [self externalHideRequestShouldWaitForAnimations]) {
        return;
    }

    if (([[self searchController] isSearchActive] && [[self searchController] isActiveSearchFirstResponder]) ||
        [self isPreviewTextEditing]) {
        return;
    }

    KayokoExternalHideRequest *request = [[self externalHideCoordinator] takePendingExternalHideRequest];
    if (!request || [self isHidden]) {
        return;
    }

    [self hideWithAnimationStyle:[request animationStyle] completion:[request completion]];
}

- (void)beginSearchInputExternalHideSuppression {
    __weak typeof(self) weakSelf = self;
    [[self externalHideCoordinator]
        beginSearchInputTransitionSuppressionWithDuration:kKayokoSearchInputExternalHideSuppressionDuration
                                        expirationHandler:^{
                                          [weakSelf executePendingExternalHideRequestIfReady];
                                        }];
}

- (void)endSearchInputExternalHideSuppression {
    if (![[self externalHideCoordinator] shouldSuppressExternalHide]) {
        return;
    }

    [[self externalHideCoordinator] endSearchInputTransitionSuppression];
    [self executePendingExternalHideRequestIfReady];
}

- (void)clearExternalHideCoordinator {
    [[self externalHideCoordinator] clear];
}

#pragma mark - KayokoSearchControllerDelegate

- (void)searchControllerWillBeginSearchInputTransition:(KayokoSearchController *)searchController {
    (void)searchController;
    [self beginSearchInputExternalHideSuppression];
}

- (void)searchControllerWillAnimateSearchState:(KayokoSearchController *)searchController {
    (void)searchController;
    [[self mainView] setAnimating:YES];
    [[self panelPresentationController] finishOutsideDismissOverlayShow];
}

- (void)searchControllerDidFinishAnimatingSearchState:(KayokoSearchController *)searchController {
    [[self mainView] setAnimating:NO];
    [[self panelPresentationController] finishOutsideDismissOverlayShow];
    if (![searchController isSearchActive]) {
        [self endSearchInputExternalHideSuppression];
    }
    [self executePendingExternalHideRequestIfReady];
}

- (void)searchController:(KayokoSearchController *)searchController
    didUpdateKeyboardBottomInset:(CGFloat)keyboardBottomInset {
    [[[self clearConfirmationViewController] confirmationView] setKeyboardBottomInset:keyboardBottomInset];
    [[self historyEmptyStateView] setKeyboardBottomInset:keyboardBottomInset];
    [[self favoritesEmptyStateView] setKeyboardBottomInset:keyboardBottomInset];
    [[self storageErrorView] setKeyboardBottomInset:keyboardBottomInset];
    if (![self isPreviewTextEditing]) {
        [[[self previewViewController] previewView] setKeyboardBottomInset:keyboardBottomInset];
    }
    [[[self wordSelectionViewController] wordSelectionView] setKeyboardBottomInset:keyboardBottomInset];
    [self updatePreviewTextEditingPanelForKeyboardBottomInset:keyboardBottomInset];
}

- (CGRect)previewTextEditingPanelFrameForKeyboardBottomInset:(CGFloat)keyboardBottomInset {
    UIView *mainView = [self mainView];
    UIView *superview = [mainView superview];
    if (!superview) {
        return [mainView frame];
    }

    CGRect bounds = [superview bounds];
    CGFloat inset = kKayokoPanelFloatingInset;
    CGRect referenceFrame = CGRectIsEmpty([self previewTextEditingOriginalPanelFrame])
                                ? [mainView frame]
                                : [self previewTextEditingOriginalPanelFrame];

    CGFloat width = CGRectGetWidth(referenceFrame);
    CGFloat x = CGRectGetMinX(referenceFrame);
    if (width <= 0.0 || width >= CGRectGetWidth(bounds) - 1.0) {
        width = MIN(kKayokoPanelFloatingMaxWidth, CGRectGetWidth(bounds) - inset * 2.0);
        width = MAX(width, 280.0);
        x = CGRectGetMidX(bounds) - width * 0.5;
    }

    CGFloat preferredHeight = CGRectGetHeight(referenceFrame);
    if (preferredHeight <= 0.0) {
        preferredHeight = MIN(420.0, CGRectGetHeight(bounds) - inset * 2.0);
        preferredHeight = MAX(preferredHeight, 220.0);
    }

    CGFloat availableBottom = CGRectGetMaxY(bounds) - MAX(keyboardBottomInset, 0.0) - inset;
    CGFloat maxHeight = MAX(availableBottom - inset, 220.0);
    CGFloat height = MIN(preferredHeight, maxHeight);
    CGFloat y = availableBottom - height;
    if (y < inset) {
        y = inset;
        height = MIN(height, MAX(availableBottom - y, 220.0));
    }
    return CGRectMake(x, y, width, height);
}

- (BOOL)shouldLiftPreviewTextEditingCard {
    return [self presentationMode] != KayokoPanelPresentationModeCompactLandscapeFullscreen;
}

- (void)updatePreviewTextEditingPanelForKeyboardBottomInset:(CGFloat)keyboardBottomInset
                                          animationDuration:(NSTimeInterval)duration
                                                    options:(UIViewAnimationOptions)options {
    BOOL liftsCard = [self shouldLiftPreviewTextEditingCard];
    [[[self textEditorViewController] textEditorView] setKeyboardBottomInset:liftsCard ? 0 : keyboardBottomInset];
    if ([self isDismissingPanel] || !liftsCard) {
        return;
    }
    if (![self isPreviewTextEditing] && ![self isPreviewTextEditingFinishing]) {
        return;
    }

    UIView *mainView = [self mainView];
    if (![mainView superview]) {
        return;
    }

    if (CGRectIsEmpty([self previewTextEditingOriginalPanelFrame])) {
        if ([self isPreviewTextEditingFinishing]) {
            return;
        }
        [self setPreviewTextEditingOriginalPanelFrame:[mainView frame]];
    }

    CGRect targetFrame = keyboardBottomInset > 0.5
                             ? [self previewTextEditingPanelFrameForKeyboardBottomInset:keyboardBottomInset]
                             : [self previewTextEditingOriginalPanelFrame];
    if (CGRectIsEmpty(targetFrame) || CGRectEqualToRect([mainView frame], targetFrame)) {
        return;
    }
    if (duration <= 0.01) {
        duration = 0.25;
        options = UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction |
                  UIViewAnimationOptionCurveEaseOut;
    }
    [mainView layoutIfNeeded];
    [UIView animateWithDuration:duration
                          delay:0
                        options:options | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                       [mainView setTransform:CGAffineTransformIdentity];
                       [mainView setFrame:targetFrame];
                       [mainView layoutIfNeeded];
                     }
                     completion:^(__unused BOOL finished) {
                       if (![self isPreviewTextEditingFinishing] || keyboardBottomInset > 0.5) {
                           return;
                       }
                       [self setPreviewTextEditingOriginalPanelFrame:CGRectZero];
                       [self setPreviewTextEditingFinishing:NO];
                     }];
}

- (void)updatePreviewTextEditingPanelForKeyboardBottomInset:(CGFloat)keyboardBottomInset {
    [self updatePreviewTextEditingPanelForKeyboardBottomInset:keyboardBottomInset
                                            animationDuration:0
                                                      options:0];
}

- (void)handlePreviewTextEditingKeyboardWillChangeFrameNotification:(NSNotification *)notification {
    if ([self isDismissingPanel] ||
        (![self isPreviewTextEditing] && ![self isPreviewTextEditingFinishing]) ||
        ![notification.userInfo[UIKeyboardIsLocalUserInfoKey] boolValue]) {
        return;
    }

    UIView *mainView = [self mainView];
    UIView *referenceView = [mainView superview] ?: mainView;
    CGRect keyboardEndFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameInView = [referenceView convertRect:keyboardEndFrame fromView:nil];
    CGFloat keyboardBottomInset = 0;
    if (!CGRectIsNull(keyboardFrameInView) && !CGRectIsEmpty(keyboardFrameInView)) {
        CGFloat referenceBottom = CGRectGetMaxY([referenceView bounds]);
        CGFloat keyboardTop = CGRectGetMinY(keyboardFrameInView);
        if (keyboardTop < referenceBottom - 0.5) {
            keyboardBottomInset = MAX(referenceBottom - keyboardTop, 0);
        }
    }

    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve =
        (UIViewAnimationCurve)[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    UIViewAnimationOptions options = (UIViewAnimationOptions)(curve << 16) |
                                     UIViewAnimationOptionBeginFromCurrentState |
                                     UIViewAnimationOptionAllowUserInteraction;
    [self updatePreviewTextEditingPanelForKeyboardBottomInset:keyboardBottomInset
                                            animationDuration:duration
                                                      options:options];
}

- (void)handlePreviewTextEditingKeyboardWillHideNotification:(NSNotification *)notification {
    if ([self isDismissingPanel] || (![self isPreviewTextEditing] && ![self isPreviewTextEditingFinishing])) {
        return;
    }
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve =
        (UIViewAnimationCurve)[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    UIViewAnimationOptions options = (UIViewAnimationOptions)(curve << 16) |
                                     UIViewAnimationOptionBeginFromCurrentState |
                                     UIViewAnimationOptionAllowUserInteraction;
    [self updatePreviewTextEditingPanelForKeyboardBottomInset:0 animationDuration:duration options:options];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == [self transientEdgeBackGestureRecognizer]) {
        return [self canBeginTransientEdgeBackGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)gestureRecognizer];
    }

    return YES;
}

#pragma mark - KayokoPanelPresentationControllerDelegate

- (void)panelPresentationControllerDidRequestDismiss:(KayokoPanelPresentationController *)controller {
    [self hideRestoringFocus];
}

- (void)panelPresentationControllerDidTapGrabberArea:(KayokoPanelPresentationController *)controller {
    if ([[self searchController] isSearchActive]) {
        [[self searchController] cancelSearchWithCompletion:nil];
    } else {
        [[self panelPresentationController] prepareStandardDismissAnimation];
        [self hideRestoringFocus];
    }
}

- (BOOL)panelPresentationControllerShouldHandleFullscreenSearchPan:(KayokoPanelPresentationController *)controller {
    return ![self isEditingAnyContent] && [self presentationMode] != KayokoPanelPresentationModeCompactLandscapeFullscreen &&
           [[self searchController] isSearchActive];
}

- (BOOL)panelPresentationController:(KayokoPanelPresentationController *)controller
    shouldBeginExpandedPanelPanFromView:(nullable UIView *)view
                               velocity:(CGPoint)velocity {
    (void)controller;
    (void)view;
    (void)velocity;
    if ([self isHidden] || [[self panelPresentationController] isAnimating]) {
        return NO;
    }
    if ([self isPreviewTextEditing]) {
        return NO;
    }
    if ([self isNoteEditing]) {
        KayokoNoteEditorView *noteEditorView = [[self noteEditorViewController] noteEditorView];
        if ([view isDescendantOfView:[noteEditorView textField]] ||
            [view isDescendantOfView:[noteEditorView saveButton]] ||
            [view isDescendantOfView:[noteEditorView cancelButton]] ||
            [view isDescendantOfView:[noteEditorView tagChipBarView]]) {
            return NO;
        }
        return [view isDescendantOfView:noteEditorView];
    }
    if ([self isShowingClearConfirmation] || [self isPreviewActive] || [self isWordSelectionActive]) {
        return NO;
    }

    UIView *activeContentView = [self activeHistoryContentView];
    return activeContentView == [[self historyListViewController] tableView] ||
           activeContentView == [[self favoritesListViewController] tableView] ||
           activeContentView == [self historyEmptyStateView] || activeContentView == [self favoritesEmptyStateView] ||
           activeContentView == [self storageErrorView];
}

- (BOOL)isFullscreenSearchActive {
    return [[self searchController] isSearchActive];
}

- (BOOL)shouldSuppressSystemMultitaskingGesture {
    return NO;
}

- (void)panelPresentationController:(KayokoPanelPresentationController *)controller
    handleFullscreenSearchPanGestureRecognizer:(UIPanGestureRecognizer *)recognizer
                                    headerView:(nullable KayokoHeaderView *)headerView {
    [[self searchController] handleFullscreenPanGestureRecognizer:recognizer headerView:headerView];
}

#pragma mark - KayokoHistoryControllerDelegate

- (BOOL)historyControllerIsPanelVisible:(KayokoHistoryController *)controller {
    return ![self isHidden];
}

- (BOOL)historyControllerShouldSuppressVisibleUpdates:(KayokoHistoryController *)controller {
    return [self isDismissingPanel];
}

- (void)historyControllerNeedsVisibleReload:(KayokoHistoryController *)controller {
    [self reload];
}

- (void)historyController:(KayokoHistoryController *)controller
    didUpdateActiveTableView:(KayokoHistoryListView *)tableView {
    [self setStorageError:nil];
    [self updateActiveTableViewState:tableView];
}

- (void)historyController:(KayokoHistoryController *)controller didFailLoadingHistoryWithError:(NSError *)error {
    [self showStorageError:error];
}

- (void)searchController:(KayokoSearchController *)searchController didFailLoadingSearchWithError:(NSError *)error {
    [self showStorageError:error];
}

- (void)handleApplicationMetadataChanged {
    [[self searchController] handleApplicationMetadataChanged];
}

#pragma mark - KayokoHistoryListViewControllerDelegate

- (void)historyListViewControllerDidRequestHide:(KayokoHistoryListViewController *)controller {
    [[self panelPresentationController] prepareStandardDismissAnimation];
    [self hideRestoringFocus];
}

- (void)historyListViewControllerDidRequestHideAfterDirectPaste:(KayokoHistoryListViewController *)controller {
    [[self panelPresentationController] prepareStandardDismissAnimation];
    [self hideAfterDirectPaste];
}

- (void)historyListViewController:(KayokoHistoryListViewController *)controller
         didRequestPreviewForItem:(KayokoPasteboardItem *)item {
    [self showContentForItem:item];
}

- (void)historyListViewController:(KayokoHistoryListViewController *)controller
        didRequestEditNoteForItem:(KayokoPasteboardItem *)item
                 presentationCell:(KayokoTableViewCell *)presentationCell
                       sourceCell:(KayokoTableViewCell *)sourceCell {
    [self beginNoteEditingForItem:item
               listViewController:controller
                 presentationCell:presentationCell
                       sourceCell:sourceCell];
}

- (void)historyListViewControllerDidChangeContentState:(KayokoHistoryListViewController *)controller {
    [self updateContentState];
}

- (void)historyListViewController:(KayokoHistoryListViewController *)controller
            didMoveItemDictionary:(NSDictionary<NSString *, id> *)dictionary
               fromHistoryWithKey:(NSString *)sourceHistoryKey
                 toHistoryWithKey:(NSString *)destinationHistoryKey {
    [self handlePasteboardItemDictionary:dictionary
                     movedFromHistoryKey:sourceHistoryKey
                            toHistoryKey:destinationHistoryKey];
}

#pragma mark - Content Lookup

- (KayokoHistoryListView *)tableViewForHistoryKey:(NSString *)historyKey {
    return [[self historyController] tableViewForHistoryKey:historyKey];
}

- (KayokoEmptyStateView *)emptyStateViewForHistoryKey:(NSString *)historyKey {
    return [historyKey isEqualToString:kKayokoHistoryKeyFavorites] ? [self favoritesEmptyStateView]
                                                                   : [self historyEmptyStateView];
}

- (UIView *)contentViewForHistoryKey:(NSString *)historyKey {

    if ([self storageError]) {
        [[self storageErrorView] updateWithStorageError:[self storageError]];
        [[self storageErrorView] setKeyboardBottomInset:[[self searchController] keyboardBottomInset]];
        return [self storageErrorView];
    }

    KayokoHistoryListViewController *listViewController = [self listViewControllerForHistoryKey:historyKey];
    if ([[listViewController items] count] > 0) {
        return [listViewController tableView];
    }

    KayokoEmptyStateView *emptyStateView = [self emptyStateViewForHistoryKey:historyKey];
    [emptyStateView setKeyboardBottomInset:[[self searchController] keyboardBottomInset]];
    return emptyStateView;
}

- (UIView *)activeHistoryContentView {
    if (![[[self historyListViewController] tableView] isHidden]) {
        return [[self historyListViewController] tableView];
    }

    if (![[[self favoritesListViewController] tableView] isHidden]) {
        return [[self favoritesListViewController] tableView];
    }

    if (![[self historyEmptyStateView] isHidden]) {
        return [self historyEmptyStateView];
    }

    if (![[self favoritesEmptyStateView] isHidden]) {
        return [self favoritesEmptyStateView];
    }

    if (![[self storageErrorView] isHidden]) {
        return [self storageErrorView];
    }

    return [self emptyStateViewForHistoryKey:[self effectiveActiveHistoryKey]];
}

- (NSString *)titleForContentView:(UIView *)view {
    if (view == [[self historyListViewController] tableView] || view == [self historyEmptyStateView]) {
        return [[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"History" value:nil table:@"Tweak"];
    }
    if (view == [[self favoritesListViewController] tableView] || view == [self favoritesEmptyStateView]) {
        return [[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Favorites" value:nil table:@"Tweak"];
    }
    if (view == [self storageErrorView]) {
        return [[self storageErrorView] name] ?: @"";
    }
    if (view == [[self clearConfirmationViewController] confirmationView]) {
        return [[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Clear" value:nil table:@"Tweak"]
            ?: @"Clear";
    }
    if (view == [[self previewViewController] previewView]) {
        return [[[self previewViewController] previewView] name] ?: @"";
    }
    if (view == [[self wordSelectionViewController] view] ||
        view == [[self wordSelectionViewController] wordSelectionView]) {
        return [[[self wordSelectionViewController] wordSelectionView].headerView.titleLabel text] ?: @"";
    }
    return [[[[[self mainView] headerView] titleLabel] text] copy] ?: @"";
}


#pragma mark - History Content

- (void)prepareHistoryListForDisplayIfNeededForHistoryKey:(NSString *)historyKey contentView:(UIView *)contentView {
    KayokoHistoryListViewController *listViewController = [self listViewControllerForHistoryKey:historyKey];
    if (contentView != [listViewController tableView] || [[self searchController] isSearchActive] ||
        [listViewController hasActiveSearch]) {
        return;
    }

    if (![[self historyController] consumeScrollToTopBeforeNextDisplayForHistoryKey:historyKey]) {
        return;
    }

    [[listViewController tableView] scrollToFirstItemKeepingSearchHeaderHiddenWithoutAnimation];
}

- (void)setHistoryContentVisibleForKey:(NSString *)historyKey {
    [[self historyController] setActiveHistoryKey:historyKey];
    UIView *contentView = [self contentViewForHistoryKey:historyKey];
    KayokoHistoryListView *tableView = [[self listViewControllerForHistoryKey:historyKey] tableView];
    BOOL preparesListBeforeDisplay = [self isHidden] || [tableView isHidden];
    [[[self historyListViewController] tableView]
        setHidden:contentView != [[self historyListViewController] tableView]];
    [[[self favoritesListViewController] tableView]
        setHidden:contentView != [[self favoritesListViewController] tableView]];
    [[self historyEmptyStateView] setHidden:contentView != [self historyEmptyStateView]];
    [[self favoritesEmptyStateView] setHidden:contentView != [self favoritesEmptyStateView]];
    [[self storageErrorView] setHidden:contentView != [self storageErrorView]];
    [contentView setAlpha:1];
    [contentView setTransform:CGAffineTransformIdentity];

    [self restoreHistoryHeaderIconForHistoryKey:historyKey];
    [[[self mainView] headerView] setHistorySwitcherVisible:YES animated:NO];
    [self updateFavoritesButtonForHistoryKey:historyKey];
    [[[[self mainView] headerView] alternateTrailingButton] setHidden:YES];
    [[[[self mainView] headerView] titleTapControl] setEnabled:NO];
    [[self searchController] attachToListViewController:[self listViewControllerForHistoryKey:historyKey]
                                         hidesSearchBar:![[self searchController] isSearchActive]];
    [[self searchController] refreshForListViewController:[self activeListViewController]];
    if (preparesListBeforeDisplay) {
        [self prepareHistoryListForDisplayIfNeededForHistoryKey:historyKey contentView:contentView];
    }
    [[self mainView] setTitleText:[self titleForContentView:contentView]];
    [self updateClearButtonState];
}

- (void)markHistoryKeyLoaded:(NSString *)historyKey {
    [[self historyController] markHistoryKeyLoaded:historyKey];
}

- (void)markHistoryKeyDirty:(NSString *)historyKey {
    [[self historyController] markHistoryKeyDirty:historyKey];
}

- (void)updateActiveTableViewState:(KayokoHistoryListView *)tableView {
    if (tableView == [self activeTableView]) {
        KayokoHistoryListViewController *activeListViewController = [self activeListViewController];

        if ([self shouldDeferHistoryPresentationUpdates]) {
            [self updateClearButtonState];
            return;
        }
        if ([self cancelSearchForEmptyActiveHistoryIfNeededHidingView:[self activeHistoryContentView]
                                                            direction:KayokoContentTransitionDirectionForward
                                                           completion:nil]) {
            return;
        }
        if ([[self searchController] isSearchActive] || [activeListViewController hasActiveSearch]) {
            [[self searchController] refreshForListViewController:activeListViewController];
        }
        [self updateClearButtonState];
        if ([self activeHistoryContentView] != [self contentViewForHistoryKey:[self effectiveActiveHistoryKey]]) {
            [self updateContentState];
        }
    }
}

- (void)handleHistoryChanged {
    [[self historyController] handleHistoryChanged];
}

- (nullable NSString *)historyKeyForInitialViewMode {
    switch ([self initialViewMode]) {
    case kKayokoInitialViewModeFavorites:
        return kKayokoHistoryKeyFavorites;
    case kKayokoInitialViewModeHistory:
        return kKayokoHistoryKeyHistory;
    case kKayokoInitialViewModePreviousSelection:
        return nil;
    }
    return nil;
}

- (void)reloadTableViewForHistoryKey:(NSString *)historyKey
              animatingTopInsertions:(BOOL)animatingTopInsertions
                          completion:(void (^)(KayokoHistoryListView *tableView))completion {
    [[self historyController] reloadTableViewForHistoryKey:historyKey
                                    animatingTopInsertions:animatingTopInsertions
                                                completion:completion];
}

- (void)reloadTableViewForHistoryKey:(NSString *)historyKey
                          completion:(void (^)(KayokoHistoryListView *tableView))completion {
    [[self historyController] reloadTableViewForHistoryKey:historyKey completion:completion];
}

#pragma mark - Clear Confirmation

- (void)showClearConfirmationForHistoryKey:(NSString *)historyKey {
    [self showClearConfirmationForHistoryKey:historyKey imagesOnly:NO];
}

- (void)showClearConfirmationForHistoryKey:(NSString *)historyKey imagesOnly:(BOOL)imagesOnly {
    [[self historyController] setActiveHistoryKey:historyKey];
    [self setClearConfirmationHistoryKey:historyKey];
    [[self clearConfirmationViewController] beginWithHistoryKey:historyKey imagesOnly:imagesOnly];
    [[[self clearConfirmationViewController] confirmationView]
        setKeyboardBottomInset:[[self searchController] keyboardBottomInset]];
    [[[[self mainView] headerView] trailingButton] setHidden:YES];

    [[self mainView]
        showContentView:[[self clearConfirmationViewController] confirmationView]
        hideContentView:[self activeHistoryContentView]
                  title:[self titleForContentView:[[self clearConfirmationViewController] confirmationView]]
              direction:KayokoContentTransitionDirectionModalPresenting];
}

- (void)finishHidingClearConfirmationForHistoryKey:(NSString *)historyKey {
    [self setClearConfirmationHistoryKey:nil];
    [self updateClearButtonState];
    UIView *contentView = [self contentViewForHistoryKey:historyKey];
    [self prepareHistoryListForDisplayIfNeededForHistoryKey:historyKey contentView:contentView];
    [[self mainView] showContentView:contentView
                     hideContentView:[[self clearConfirmationViewController] confirmationView]
                               title:[self titleForContentView:contentView]
                           direction:KayokoContentTransitionDirectionModalDismissing];
}

- (void)hideClearConfirmationWithReload:(BOOL)reload {
    [[[self mainView] headerView] setHistorySwitcherVisible:YES animated:NO];
    [self updateFavoritesButtonForHistoryKey:[self effectiveActiveHistoryKey]];
    if ([[[self clearConfirmationViewController] confirmationView] isHidden] || ![self clearConfirmationHistoryKey]) {
        return;
    }

    NSString *historyKey = [self clearConfirmationHistoryKey];
    if (reload) {
        BOOL imagesOnly = [[self clearConfirmationViewController] isImagesOnly];
        if (imagesOnly) {

            [self markHistoryKeyDirty:historyKey];
        } else {
            [[self listViewControllerForHistoryKey:historyKey] clearItems];
            [self markHistoryKeyLoaded:historyKey];
        }
        if ([[self effectiveActiveHistoryKey] isEqualToString:historyKey]) {
            [self setClearConfirmationHistoryKey:nil];
            [self updateClearButtonState];
            if (!imagesOnly &&
                [self cancelSearchForEmptyActiveHistoryIfNeededHidingView:[[self clearConfirmationViewController]
                                                                              confirmationView]
                                                                direction:KayokoContentTransitionDirectionModalDismissing
                                                               completion:nil]) {
                return;
            }
            if (imagesOnly) {
                [self reloadTableViewForHistoryKey:historyKey
                            animatingTopInsertions:NO
                                        completion:^(KayokoHistoryListView *tableView) {
                                          (void)tableView;
                                        }];
            }
            [[self searchController] refreshForListViewController:[self activeListViewController]];
        }
    }
    [self finishHidingClearConfirmationForHistoryKey:historyKey];
}

- (void)resetClearConfirmationIfNeeded {
    if (![self clearConfirmationHistoryKey]) {
        return;
    }

    [[[self clearConfirmationViewController] confirmationView] setHidden:YES];
    [[[self clearConfirmationViewController] confirmationView] setAlpha:1];
    [[[self clearConfirmationViewController] confirmationView] setTransform:CGAffineTransformIdentity];
    [self setHistoryContentVisibleForKey:[self clearConfirmationHistoryKey]];
    [self setClearConfirmationHistoryKey:nil];
    [self updateClearButtonState];
}

- (BOOL)isShowingClearConfirmation {
    return [self clearConfirmationHistoryKey] && ![[[self clearConfirmationViewController] confirmationView] isHidden];
}

#pragma mark - Content State

- (void)updateClearButtonState {
    [[[[self mainView] headerView] trailingButton] setHidden:YES];
    NSUInteger itemCount = [self storageError] ? 0 : [[[self activeListViewController] items] count];
    [[self mainView] setClearButtonEnabledForItemCount:itemCount];
}

- (void)showStorageError:(NSError *)error {
    if (!error) {
        return;
    }

    [self setStorageError:error];
    [[self storageErrorView] updateWithStorageError:error];
    [[self storageErrorView] setKeyboardBottomInset:[[self searchController] keyboardBottomInset]];
    [self updateClearButtonState];

    if ([self isHidden]) {
        return;
    }

    UIView *viewToHide = [self activeHistoryContentView];
    UIView *viewToShow = [self storageErrorView];
    if (viewToHide == viewToShow) {
        [[self mainView] setTitleText:[self titleForContentView:viewToShow]];
        return;
    }
    [[self mainView] showContentView:viewToShow
                     hideContentView:viewToHide
                               title:[self titleForContentView:viewToShow]
                           direction:KayokoContentTransitionDirectionForward];
}

#pragma mark - Transient Content

- (BOOL)isNoteEditing {
    return [self noteEditingItem] != nil || ![[[self noteEditorViewController] noteEditorView] isHidden];
}

- (BOOL)isPreviewTextEditing {
    return [[self textEditorViewController] isEditing] || ![[[self textEditorViewController] textEditorView] isHidden];
}

- (BOOL)isEditingAnyContent {
    return [self isNoteEditing] || [self isPreviewTextEditing];
}

- (BOOL)isPreviewActive {
    return ![[[self previewViewController] previewView] isHidden] || [[self previewViewController] previewItem] != nil;
}

- (BOOL)isWordSelectionActive {
    return ![[[self wordSelectionViewController] view] isHidden] ||
           [[self wordSelectionViewController] sourceItem] != nil;
}

- (UIView *)activeTransientContentViewForEdgeBackGesture {
    KayokoPreviewView *previewView = [[self previewViewController] previewView];
    if (![previewView isHidden] && [[self previewViewController] previewItem]) {
        return previewView;
    }

    UIView *wordSelectionView = [[self wordSelectionViewController] view];
    if (![wordSelectionView isHidden] && [[self wordSelectionViewController] sourceItem]) {
        return wordSelectionView;
    }

    return nil;
}

- (BOOL)canBeginTransientEdgeBackGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)recognizer {
    if ([self isHidden] || [self isEditingAnyContent] || [[self mainView] isAnimating] ||
        [[self panelPresentationController] isAnimating]) {
        return NO;
    }

    UIView *sourceView = [self activeSourceContentView];
    UIView *contentView = [self activeTransientContentViewForEdgeBackGesture];
    if (!sourceView || !contentView) {
        return NO;
    }

    CGPoint velocity = [recognizer velocityInView:[self mainView]];
    if (velocity.x <= 0 || fabs(velocity.x) <= fabs(velocity.y) * kKayokoTransientEdgeBackHorizontalDominance) {
        return NO;
    }

    if (contentView == [[self previewViewController] previewView] &&
        ![[[self previewViewController] previewView] canBeginEdgeBackGesture]) {
        return NO;
    }

    return YES;
}

- (CGFloat)progressForTransientEdgeBackGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)recognizer {
    CGFloat width = MAX(CGRectGetWidth([[[self mainView] contentContainerView] bounds]), 1);
    CGFloat progress = [recognizer translationInView:[self mainView]].x / width;
    return MIN(MAX(progress, 0), 1);
}

- (NSTimeInterval)transientEdgeBackAnimationDurationWithProgress:(CGFloat)progress finishing:(BOOL)finishing {
    CGFloat remainingProgress = finishing ? 1 - progress : progress;
    NSTimeInterval duration = kKayokoTransientEdgeBackMaximumAnimationDuration * remainingProgress;
    return MIN(MAX(duration, kKayokoTransientEdgeBackMinimumAnimationDuration),
               kKayokoTransientEdgeBackMaximumAnimationDuration);
}

- (void)resetInteractiveTransientReturnState {
    [self setInteractiveTransientReturnSourceView:nil];
    [self setInteractiveTransientReturnContentView:nil];
    [self setInteractiveTransientReturnWasPreview:NO];
    [self setDidRestoreSearchDuringInteractiveTransientReturn:NO];
}

- (void)clearSearchAfterTransientContentState {
    [self setRestoresSearchFirstResponderAfterTransientContent:NO];
    [self setHasSearchContentOffsetBeforeTransientContent:NO];
}

- (BOOL)restoreSearchAfterTransientContentIfNeededClearingState:(BOOL)clearsState {
    BOOL didRestore = NO;
    if ([[self searchController] isSearchActive]) {
        CGPoint targetContentOffset = [[[self activeListViewController] tableView] contentOffset];
        if ([self hasSearchContentOffsetBeforeTransientContent]) {
            targetContentOffset = [self searchContentOffsetBeforeTransientContent];
        }
        [[self searchController]
            refreshAfterTransientContentForListViewController:[self activeListViewController]
                                       restoresFirstResponder:[self restoresSearchFirstResponderAfterTransientContent]
                                          targetContentOffset:targetContentOffset];
        didRestore = YES;
    }

    if (clearsState) {
        [self clearSearchAfterTransientContentState];
    }
    return didRestore;
}

- (void)beginInteractiveTransientReturnWithGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)recognizer {
    UIView *sourceView = [self activeSourceContentView];
    UIView *contentView = [self activeTransientContentViewForEdgeBackGesture];
    if (!sourceView || !contentView) {
        return;
    }

    CGFloat progress = [self progressForTransientEdgeBackGestureRecognizer:recognizer];
    UIView *mainHeaderView = [[self mainView] headerView];

    [self setInteractiveTransientReturnSourceView:sourceView];
    [self setInteractiveTransientReturnContentView:contentView];
    [self setInteractiveTransientReturnWasPreview:(contentView == [[self previewViewController] previewView])];
    [[self mainView] beginInteractiveBackwardContentTransitionToView:sourceView
                                                 alongsideViewToShow:mainHeaderView
                                                     hideContentView:contentView];
    [[self mainView] updateInteractiveBackwardContentTransitionToView:sourceView
                                                  alongsideViewToShow:mainHeaderView
                                                      hideContentView:contentView
                                                             progress:progress];
    [self setDidRestoreSearchDuringInteractiveTransientReturn:
              [self restoreSearchAfterTransientContentIfNeededClearingState:NO]];
}

- (void)updateInteractiveTransientReturnWithGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)recognizer {
    UIView *sourceView = [self interactiveTransientReturnSourceView];
    UIView *contentView = [self interactiveTransientReturnContentView];
    if (!sourceView || !contentView) {
        return;
    }

    CGFloat progress = [self progressForTransientEdgeBackGestureRecognizer:recognizer];
    [[self mainView] updateInteractiveBackwardContentTransitionToView:sourceView
                                                  alongsideViewToShow:[[self mainView] headerView]
                                                      hideContentView:contentView
                                                             progress:progress];
}

- (void)finishInteractiveTransientReturnWithDuration:(NSTimeInterval)duration {
    UIView *sourceView = [self interactiveTransientReturnSourceView];
    UIView *contentView = [self interactiveTransientReturnContentView];
    if (!sourceView || !contentView) {
        [self resetInteractiveTransientReturnState];
        return;
    }

    BOOL wasPreview = [self interactiveTransientReturnWasPreview];
    BOOL didRestoreSearch = [self didRestoreSearchDuringInteractiveTransientReturn];
    if (didRestoreSearch) {
        [self clearSearchAfterTransientContentState];
    }
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
    UIView *mainHeaderView = [[self mainView] headerView];

    [[self mainView] finishInteractiveBackwardContentTransitionToView:sourceView
        alongsideViewToShow:mainHeaderView
        hideContentView:contentView
        duration:duration
        alongsideAnimations:^{
          if (!didRestoreSearch) {
              [self restoreSearchAfterTransientContentIfNeededClearingState:YES];
          }
        }
        completion:^{
          if (wasPreview) {
              [[self previewViewController] hidePreview];
          } else {
              [[self wordSelectionViewController] hideWordSelection];
          }
          [self setActiveSourceContentView:nil];
          [self resetInteractiveTransientReturnState];
        }];
}

- (void)cancelInteractiveTransientReturnWithDuration:(NSTimeInterval)duration {
    UIView *sourceView = [self interactiveTransientReturnSourceView];
    UIView *contentView = [self interactiveTransientReturnContentView];
    if (!sourceView || !contentView) {
        [self resetInteractiveTransientReturnState];
        return;
    }

    if ([self didRestoreSearchDuringInteractiveTransientReturn]) {
        [[self searchController] resignSearchFirstResponder];
    }

    [[self mainView] cancelInteractiveBackwardContentTransitionToView:sourceView
                                                  alongsideViewToShow:[[self mainView] headerView]
                                                      hideContentView:contentView
                                                             duration:duration
                                                           completion:^{
                                                             [self resetInteractiveTransientReturnState];
                                                           }];
}

- (void)finishOrCancelInteractiveTransientReturnWithGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)recognizer {
    if ([recognizer state] == UIGestureRecognizerStateCancelled ||
        [recognizer state] == UIGestureRecognizerStateFailed) {
        CGFloat progress = [self progressForTransientEdgeBackGestureRecognizer:recognizer];
        [self cancelInteractiveTransientReturnWithDuration:[self transientEdgeBackAnimationDurationWithProgress:progress
                                                                                                      finishing:NO]];
        return;
    }

    CGFloat progress = [self progressForTransientEdgeBackGestureRecognizer:recognizer];
    CGPoint velocity = [recognizer velocityInView:[self mainView]];
    BOOL shouldFinish = progress >= kKayokoTransientEdgeBackCompletionProgress ||
                        velocity.x >= kKayokoTransientEdgeBackCompletionVelocity;
    NSTimeInterval duration = [self transientEdgeBackAnimationDurationWithProgress:progress finishing:shouldFinish];
    if (shouldFinish) {
        [self finishInteractiveTransientReturnWithDuration:duration];
    } else {
        [self cancelInteractiveTransientReturnWithDuration:duration];
    }
}

- (void)handleTransientEdgeBackGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)recognizer {
    switch ([recognizer state]) {
    case UIGestureRecognizerStateBegan:
        [self beginInteractiveTransientReturnWithGestureRecognizer:recognizer];
        break;
    case UIGestureRecognizerStateChanged:
        [self updateInteractiveTransientReturnWithGestureRecognizer:recognizer];
        break;
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateFailed:
        [self finishOrCancelInteractiveTransientReturnWithGestureRecognizer:recognizer];
        break;
    default:
        break;
    }
}

- (void)restoreActiveSourceContentView {
    UIView *sourceContentView = [self activeSourceContentView];
    if (!sourceContentView) {
        return;
    }

    [sourceContentView setHidden:NO];
    [sourceContentView setAlpha:1];
    [sourceContentView setTransform:CGAffineTransformIdentity];
}

- (void)refreshSearchAfterEndingTransientContentIfNeeded {
    [self restoreSearchAfterTransientContentIfNeededClearingState:YES];
}

#pragma mark - Header State

- (void)updateFavoritesButtonForHistoryKey:(NSString *)historyKey {
    BOOL showingFavorites = [historyKey isEqualToString:kKayokoHistoryKeyFavorites];
    KayokoHeaderView *headerView = [[self mainView] headerView];
    [headerView setHistorySwitcherVisible:YES animated:NO];
    [headerView setSelectedHistorySegmentIndex:showingFavorites ? 1 : 0];
    [headerView updateStyleForButton:[headerView leadingButton]
                       withImageName:@"list.bullet"
                           imageSize:kKayokoFavoritesButtonImageSize
                           tintColor:[UIColor labelColor]];
    [self updateFavoritesFilterMenuForHistoryKey:historyKey];
}

- (void)updateFavoritesFilterMenuForHistoryKey:(NSString *)historyKey {
    UIButton *leadingButton = [[[self mainView] headerView] leadingButton];
    [leadingButton setShowsMenuAsPrimaryAction:YES];
    if ([historyKey isEqualToString:kKayokoHistoryKeyFavorites]) {
        [leadingButton setMenu:[self favoritesFilterMenu]];
    } else {
        [leadingButton setMenu:[self clipboardClearMenu]];
    }
}

- (UIMenu *)favoritesFilterMenu {
    NSBundle *bundle = [KayokoPasteboardManager localizationBundle];
    KayokoSearchController *searchController = [self searchController];
    __weak typeof(self) weakSelf = self;

    UIAction *(^makeAction)(NSString *, BOOL, void (^)(KayokoSearchController *, BOOL)) =
        ^UIAction *(NSString *title, BOOL enabled, void (^apply)(KayokoSearchController *, BOOL)) {
          UIImage *image = [UIImage systemImageNamed:enabled ? @"eye" : @"eye.slash"];
          return [UIAction actionWithTitle:title
                                     image:image
                                identifier:nil
                                   handler:^(__kindof UIAction *_Nonnull unusedAction) {
                                     (void)unusedAction;
                                     __strong typeof(weakSelf) strongSelf = weakSelf;
                                     if (!strongSelf) {
                                         return;
                                     }
                                     apply([strongSelf searchController], !enabled);
                                     [strongSelf updateFavoritesFilterMenuForHistoryKey:
                                                     [strongSelf effectiveActiveHistoryKey]];
                                   }];
        };

    UIAction *categories = makeAction(
        [bundle localizedStringForKey:@"Categories" value:nil table:@"Tweak"],
        [searchController favoritesFilterShowsCategories],
        ^(KayokoSearchController *controller, BOOL value) { [controller setFavoritesFilterShowsCategories:value]; });
    UIAction *tags = makeAction(
        [bundle localizedStringForKey:@"Tags" value:nil table:@"Tweak"],
        [searchController favoritesFilterShowsTags],
        ^(KayokoSearchController *controller, BOOL value) { [controller setFavoritesFilterShowsTags:value]; });
    UIAction *apps = makeAction(
        [bundle localizedStringForKey:@"Applications" value:nil table:@"Tweak"],
        [searchController favoritesFilterShowsApps],
        ^(KayokoSearchController *controller, BOOL value) { [controller setFavoritesFilterShowsApps:value]; });

    return [UIMenu menuWithTitle:@"" children:@[ categories, tags, apps ]];
}

- (UIMenu *)clipboardClearMenu {
    NSBundle *bundle = [KayokoPasteboardManager localizationBundle];
    __weak typeof(self) weakSelf = self;

    UIAction *clearClipboard =
        [UIAction actionWithTitle:[bundle localizedStringForKey:@"Clear Clipboard" value:nil table:@"Tweak"]
                            image:[UIImage systemImageNamed:@"trash"]
                       identifier:nil
                          handler:^(__kindof UIAction *_Nonnull unusedAction) {
                            (void)unusedAction;
                            [weakSelf requestClearClipboardImagesOnly:NO];
                          }];
    [clearClipboard setAttributes:UIMenuElementAttributesDestructive];

    UIAction *clearImages =
        [UIAction actionWithTitle:[bundle localizedStringForKey:@"Clear Images" value:nil table:@"Tweak"]
                            image:[UIImage systemImageNamed:@"photo"]
                       identifier:nil
                          handler:^(__kindof UIAction *_Nonnull unusedAction) {
                            (void)unusedAction;
                            [weakSelf requestClearClipboardImagesOnly:YES];
                          }];

    return [UIMenu menuWithTitle:@"" children:@[ clearClipboard, clearImages ]];
}

- (void)requestClearClipboardImagesOnly:(BOOL)imagesOnly {
    if ([[self panelPresentationController] isAnimating] || ![[[self previewViewController] previewView] isHidden] ||
        ![[[self wordSelectionViewController] view] isHidden] || [self isShowingClearConfirmation]) {
        return;
    }
    [self showClearConfirmationForHistoryKey:kKayokoHistoryKeyHistory imagesOnly:imagesOnly];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)dismissLeadingButtonMenu {
    UIButton *leadingButton = [[[self mainView] headerView] leadingButton];
    SEL dismissMenuSelector = NSSelectorFromString(@"dismissMenu");
    if ([leadingButton respondsToSelector:dismissMenuSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [leadingButton performSelector:dismissMenuSelector];
#pragma clang diagnostic pop
    }
}


- (void)restoreHistoryHeaderIconForHistoryKey:(NSString *)historyKey {
    UIButton *favoritesButton = [[[self mainView] headerView] leadingButton];
    [favoritesButton setHidden:NO];
    [favoritesButton setEnabled:YES];
    [favoritesButton setUserInteractionEnabled:YES];
    [[[favoritesButton imageView] layer] setCornerRadius:0];
    [[favoritesButton imageView] setClipsToBounds:NO];
    [self updateFavoritesButtonForHistoryKey:historyKey];
}

#pragma mark - Content Presentation

- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
              direction:(KayokoContentTransitionDirection)direction
             completion:(nullable void (^)(void))completion {
    [[self mainView] showContentView:viewToShow
                     hideContentView:viewToHide
                               title:[self titleForContentView:viewToShow]
                           direction:direction
                          completion:completion];
}

- (BOOL)cancelSearchForEmptyActiveHistoryIfNeededHidingView:(UIView *)viewToHide
                                                  direction:(KayokoContentTransitionDirection)direction
                                                 completion:(void (^)(void))completion {
    if (![[self searchController] isSearchActive] || [[[self activeListViewController] items] count] > 0) {
        return NO;
    }

    [self updateClearButtonState];
    UIView *viewToShow = [self contentViewForHistoryKey:[self effectiveActiveHistoryKey]];
    if (viewToShow == viewToHide) {
        [[self searchController] cancelSearchWithCompletion:completion];
        return YES;
    }

    [[self mainView] prepareContentTransitionToView:viewToShow
                                    hideContentView:viewToHide
                                              title:[self titleForContentView:viewToShow]
                                          direction:direction];
    [[self searchController]
        cancelSearchWithAnimations:^{
          [[self mainView] applyPreparedContentTransitionToView:viewToShow
                                                hideContentView:viewToHide
                                                      direction:direction];
        }
        completion:^{
          [[self mainView] completePreparedContentTransitionHidingView:viewToHide completion:completion];
        }];
    return YES;
}

- (void)updateContentState {

    if (![self shouldDeferHistoryPresentationUpdates]) {
        if ([self cancelSearchForEmptyActiveHistoryIfNeededHidingView:[self activeHistoryContentView]
                                                            direction:KayokoContentTransitionDirectionForward
                                                           completion:nil]) {
            return;
        }

        UIView *viewToHide = [self activeHistoryContentView];
        UIView *viewToShow = [self contentViewForHistoryKey:[self effectiveActiveHistoryKey]];

        if (viewToShow != viewToHide) {
            [self prepareHistoryListForDisplayIfNeededForHistoryKey:[self effectiveActiveHistoryKey]
                                                        contentView:viewToShow];
            [[self mainView] showContentView:viewToShow
                             hideContentView:viewToHide
                                       title:[self titleForContentView:viewToShow]
                                   direction:KayokoContentTransitionDirectionForward];
        } else {
            [[self mainView] setTitleText:[self titleForContentView:viewToShow]];
        }
    }

    [self updateClearButtonState];
}

- (BOOL)shouldDeferHistoryPresentationUpdates {
    return [self isEditingAnyContent] || [self isShowingClearConfirmation] || [self isPreviewActive] ||
           [self isWordSelectionActive];
}


#pragma mark - Actions

- (void)handleHistorySegmentedControlChanged:(UISegmentedControl *)sender {
    if (!sender) {
        return;
    }

    BOOL wantsFavorites = [sender selectedSegmentIndex] == 1;
    NSString *targetKey = wantsFavorites ? kKayokoHistoryKeyFavorites : kKayokoHistoryKeyHistory;
    NSString *currentKey = [self effectiveActiveHistoryKey];
    if ([currentKey isEqualToString:targetKey]) {
        [self updateFavoritesButtonForHistoryKey:currentKey];
        return;
    }

    if ([[self panelPresentationController] isAnimating]) {
        [self updateFavoritesButtonForHistoryKey:currentKey];
        return;
    }

    [self switchToHistoryKey:targetKey animated:YES];
}

- (void)switchToHistoryKey:(NSString *)targetKey animated:(BOOL)animated {
    if ([targetKey length] == 0) {
        return;
    }
    if ([[self panelPresentationController] isAnimating]) {
        [self updateFavoritesButtonForHistoryKey:[self effectiveActiveHistoryKey]];
        return;
    }
    if ([self isShowingClearConfirmation]) {
        [self resetClearConfirmationIfNeeded];
    }

    NSString *historyKey = [self effectiveActiveHistoryKey];
    if ([historyKey isEqualToString:targetKey]) {
        [self updateFavoritesButtonForHistoryKey:targetKey];
        return;
    }

    BOOL targetIsFavorites = [targetKey isEqualToString:kKayokoHistoryKeyFavorites];
    UIView *viewToHide = [self activeHistoryContentView];
    KayokoContentTransitionDirection direction =
        animated ? (targetIsFavorites ? KayokoContentTransitionDirectionSiblingForward
                                      : KayokoContentTransitionDirectionSiblingBackward)
                 : KayokoContentTransitionDirectionForward;

    __weak typeof(self) weakSelf = self;
    [self reloadTableViewForHistoryKey:targetKey
                            completion:^(KayokoHistoryListView *targetTableView) {
                              __strong typeof(weakSelf) strongSelf = weakSelf;
                              (void)targetTableView;
                              if (!strongSelf) {
                                  return;
                              }
                              if (![[strongSelf effectiveActiveHistoryKey] isEqualToString:historyKey] ||
                                  [[strongSelf panelPresentationController] isAnimating]) {
                                  [strongSelf updateFavoritesButtonForHistoryKey:[strongSelf effectiveActiveHistoryKey]];
                                  return;
                              }

                              [[strongSelf historyController] setActiveHistoryKey:targetKey];
                              [[strongSelf searchController]
                                  attachToListViewController:[strongSelf listViewControllerForHistoryKey:targetKey]
                                              hidesSearchBar:![[strongSelf searchController] isSearchActive]];
                              [[strongSelf searchController]
                                  refreshForListViewController:[strongSelf activeListViewController]];
                              [strongSelf updateClearButtonState];

                              UIView *viewToShow = [strongSelf contentViewForHistoryKey:targetKey];
                              [strongSelf prepareHistoryListForDisplayIfNeededForHistoryKey:targetKey
                                                                                contentView:viewToShow];
                              if (viewToShow != viewToHide) {
                                  [[strongSelf mainView] showContentView:viewToShow
                                                         hideContentView:viewToHide
                                                                   title:[strongSelf titleForContentView:viewToShow]
                                                               direction:direction];
                              } else {
                                  [[strongSelf mainView] setTitleText:[strongSelf titleForContentView:viewToShow]];
                              }

                              [strongSelf updateFavoritesButtonForHistoryKey:targetKey];
                              [[strongSelf panelPresentationController]
                                  triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
                            }];
}

- (void)handleFavoritesButtonPressed {

    if ([[self panelPresentationController] isAnimating]) {
        return;
    }

    if ([self isShowingClearConfirmation]) {
        [self hideClearConfirmationWithReload:NO];
        [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
        return;
    }

    NSString *historyKey = [self effectiveActiveHistoryKey];
    BOOL showingFavorites = [historyKey isEqualToString:kKayokoHistoryKeyFavorites];
    NSString *targetKey = showingFavorites ? kKayokoHistoryKeyHistory : kKayokoHistoryKeyFavorites;
    [self switchToHistoryKey:targetKey animated:YES];
}

- (void)handleTransientBackButtonPressed {
    if ([self isNoteEditing] || [[self panelPresentationController] isAnimating] || [[self mainView] isAnimating]) {
        return;
    }

    if (![[[self textEditorViewController] textEditorView] isHidden] && [[self textEditorViewController] isEditing]) {
        [self textEditorViewControllerDidRequestCancel:[self textEditorViewController]];
        return;
    }

    if (![[[self previewViewController] previewView] isHidden]) {
        [self hidePreview];
        [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
        return;
    }

    if (![[[self wordSelectionViewController] view] isHidden]) {
        [self hideWordSelection];
        [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
    }
}

- (void)handlePreviewActionButtonPressed {
    if (![[[self wordSelectionViewController] view] isHidden]) {
        [[self wordSelectionViewController] handleActionButtonWithAutomaticallyPaste:[self automaticallyPaste]];
        return;
    }

    if (![[[self previewViewController] previewView] isHidden]) {
        BOOL savesImage = [[[[self previewViewController] previewItem] imageName] length] > 0;
        [[self previewViewController] handleActionButtonWithCompletion:^(BOOL success) {
          if (success) {
              if (savesImage && ([self isDismissingPanel] || [[self mainView] isAnimating] ||
                                [[self panelPresentationController] isAnimating])) {
                  return;
              }
              [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
              [[self panelPresentationController] prepareStandardDismissAnimation];
              [self hideAfterDirectPaste];
          }
        }];
    }
}

- (void)handleOpenLinkButtonPressed {
    KayokoPasteboardItem *item = [self isWordSelectionActive] ? [[self wordSelectionViewController] sourceItem] :
        ([self isPreviewActive] ? [[self previewViewController] previewItem] : nil);
    if (![item hasLink]) return;
    __weak typeof(self) weakSelf = self;
    [[[KayokoHistoryItemActionHandler alloc] init] openLinkForItem:item completion:^(BOOL success) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!success || !strongSelf || [strongSelf isHidden] || [strongSelf isDismissingPanel]) return;
        KayokoPasteboardItem *currentItem = [strongSelf isWordSelectionActive] ?
            [[strongSelf wordSelectionViewController] sourceItem] : [[strongSelf previewViewController] previewItem];
        if (currentItem != item) return;
        [[strongSelf panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
        [[strongSelf panelPresentationController] prepareStandardDismissAnimation];
        [strongSelf hideAfterDirectPaste];
    }];
}

- (void)handleClearButtonPressed {
    if ([[self panelPresentationController] isAnimating] || ![[[self previewViewController] previewView] isHidden] ||
        ![[[self wordSelectionViewController] view] isHidden] || [self isShowingClearConfirmation] ||
        NO) {
        return;
    }

    [self showClearConfirmationForHistoryKey:[self effectiveActiveHistoryKey]];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)handleTitleTapControlPressed {
    if ([[self panelPresentationController] isAnimating] || [[self mainView] isAnimating]) {
        return;
    }

    if (![[[self wordSelectionViewController] view] isHidden]) {
        [[self wordSelectionViewController] scrollToTopAnimated:YES];
        return;
    }

    if (![[[self previewViewController] previewView] isHidden]) {
        [[self previewViewController] scrollToTopAnimated:YES];
        return;
    }

    [[self activeListViewController] scrollToTopAnimated:YES];
}

#pragma mark - Item Handling

- (void)handlePasteboardItemDictionary:(NSDictionary<NSString *, id> *)dictionary
                   movedFromHistoryKey:(NSString *)sourceHistoryKey
                          toHistoryKey:(NSString *)destinationHistoryKey {
    [[self historyController] handlePasteboardItemDictionary:dictionary
                                         movedFromHistoryKey:sourceHistoryKey
                                                toHistoryKey:destinationHistoryKey];
}

#pragma mark - Note Editing

- (CGRect)noteEditingPanelFrameForKeyboardBottomInset:(CGFloat)keyboardBottomInset {
    UIView *mainView = [self mainView];
    UIView *superview = [mainView superview];
    if (!superview) {
        return [mainView frame];
    }

    CGRect bounds = [superview bounds];
    CGRect currentFrame = [mainView frame];
    CGFloat inset = kKayokoPanelFloatingInset;

    // Preserve floating-card width/x. Never expand note editing to full host bounds.
    CGFloat width = CGRectGetWidth(currentFrame);
    CGFloat x = CGRectGetMinX(currentFrame);
    if (width <= 0.0 || width >= CGRectGetWidth(bounds) - 1.0) {
        width = MIN(kKayokoPanelFloatingMaxWidth, CGRectGetWidth(bounds) - inset * 2.0);
        width = MAX(width, 280.0);
        x = CGRectGetMidX(bounds) - width * 0.5;
    }

    CGFloat contentHeight = [[[self noteEditorViewController] noteEditorView] editingContentHeight];
    CGFloat preferredHeight = contentHeight + 12.0;
    CGFloat availableBottom = CGRectGetMaxY(bounds) - MAX(keyboardBottomInset, 0.0) - inset;
    CGFloat maximumHeight = MAX(availableBottom - inset, 0.0);
    CGFloat targetHeight = MIN(preferredHeight, maximumHeight);
    CGFloat y = availableBottom - targetHeight;
    if (y < inset) {
        y = inset;
        targetHeight = MIN(preferredHeight, MAX(CGRectGetHeight(bounds) - inset * 2.0, 0.0));
    }
    return CGRectMake(x, y, width, targetHeight);
}

- (BOOL)canBeginNoteEditing {
    return ![self isNoteEditing] && ![[self mainView] isAnimating] && ![[self panelPresentationController] isAnimating];
}

- (NSUInteger)prepareNoteEditingSessionForItem:(KayokoPasteboardItem *)item
                            listViewController:(KayokoHistoryListViewController *)listViewController
                              presentationCell:(KayokoTableViewCell *)presentationCell
                                    cellHeight:(CGFloat)cellHeight
                           keyboardBottomInset:(CGFloat)keyboardBottomInset
                                        origin:(KayokoNoteEditingOrigin)origin {
    [self setNoteEditingOrigin:origin];
    [self setFinishingNoteEditing:NO];
    [self setNoteEditingItem:item];
    [self setNoteEditingHistoryKey:[listViewController historyKey]];
    [self setNoteEditingSourceListViewController:listViewController];
    NSUInteger requestIdentifier = [self noteEditingRequestIdentifier] + 1;
    [self setNoteEditingRequestIdentifier:requestIdentifier];
    [self clearExternalHideCoordinator];

    KayokoNoteEditorView *noteEditorView = [[self noteEditorViewController] noteEditorView];
    [noteEditorView setCompactLayout:[self presentationMode] == KayokoPanelPresentationModeCompactLandscapeFullscreen];
    [[self noteEditorViewController] prepareForItem:item
                                   presentationCell:presentationCell
                                         cellHeight:cellHeight
                                keyboardBottomInset:keyboardBottomInset];
    return requestIdentifier;
}

- (void)beginNoteEditingForItem:(KayokoPasteboardItem *)item
             listViewController:(KayokoHistoryListViewController *)listViewController
               presentationCell:(KayokoTableViewCell *)presentationCell
                     sourceCell:(KayokoTableViewCell *)sourceCell {
    if (!item || !listViewController || !presentationCell || ![self canBeginNoteEditing]) {
        return;
    }

    UIView *mainView = [self mainView];
    BOOL beganFromSearch = [[self searchController] isSearchActive];
    UIWindow *searchSourceWindow = beganFromSearch ? [sourceCell window] : nil;
    BOOL hasSearchSourceFrame = searchSourceWindow != nil;
    CGRect searchSourceFrameInWindow =
        hasSearchSourceFrame ? [sourceCell convertRect:[sourceCell bounds] toView:searchSourceWindow] : CGRectNull;
    CGFloat keyboardBottomInset = [[self noteEditorViewController] visibleKeyboardBottomInset];
    [listViewController setCellPresentationHidden:YES forItem:item];
    [self clearSearchAfterTransientContentState];
    [self setNoteEditingBeganFromSearch:beganFromSearch];
    if (beganFromSearch) {
        [self setNoteEditingOriginalPanelFrame:[[self searchController] resetSearchStatePreservingContainerFrame]];
        sourceCell = [listViewController scrollItemToVisible:item];
        presentationCell = [listViewController presentationCellForItem:item];
    } else {
        [self setNoteEditingOriginalPanelFrame:[mainView frame]];
    }
    [self setNoteEditingKeyboardAnimationDuration:0.25];
    [self setNoteEditingKeyboardAnimationOptions:UIViewAnimationOptionCurveEaseInOut |
                                                 UIViewAnimationOptionBeginFromCurrentState |
                                                 UIViewAnimationOptionAllowUserInteraction];

    KayokoHistoryListView *sourceTableView = [listViewController tableView];
    BOOL keepsSearchHeaderHidden =
        beganFromSearch || ![sourceTableView isSearchHeaderExposedAtContentOffset:[sourceTableView contentOffset]];
    [self setNoteEditingKeepsSearchHeaderHidden:keepsSearchHeaderHidden];
    [self setActiveSourceContentView:sourceTableView];

    CGFloat cellHeight = CGRectGetHeight([sourceCell bounds]);
    if (cellHeight <= 0) {
        cellHeight = [[listViewController tableView] rowHeight];
    }
    NSUInteger requestIdentifier = [self prepareNoteEditingSessionForItem:item
                                                       listViewController:listViewController
                                                         presentationCell:presentationCell
                                                               cellHeight:cellHeight
                                                      keyboardBottomInset:keyboardBottomInset
                                                                   origin:KayokoNoteEditingOriginList];
    KayokoNoteEditorView *noteEditorView = [[self noteEditorViewController] noteEditorView];

    [[self mainView] layoutIfNeeded];
    [noteEditorView setHidden:NO];
    [noteEditorView setAlpha:1];
    [noteEditorView setAutomaticallyPositionsPreviewCell:NO];
    [noteEditorView layoutIfNeeded];

    CGRect targetPanelFrame = [self noteEditingPanelFrameForKeyboardBottomInset:keyboardBottomInset];

    BOOL usesSearchSourceFrame = hasSearchSourceFrame && [noteEditorView window] == searchSourceWindow;
    BOOL hasSourceFrame = usesSearchSourceFrame || (sourceCell && [sourceCell window]);
    CGRect sourceFrame = [noteEditorView targetPreviewCellFrame];
    if (usesSearchSourceFrame) {
        sourceFrame = [noteEditorView convertRect:searchSourceFrameInWindow fromView:searchSourceWindow];
    } else if (hasSourceFrame) {
        sourceFrame = [sourceCell convertRect:[sourceCell bounds] toView:noteEditorView];
    }
    [[noteEditorView previewCell] setFrame:sourceFrame];
    [[noteEditorView previewCell] setAlpha:hasSourceFrame ? 1 : 0];
    [[noteEditorView inputRowView] setAlpha:0];
    [[noteEditorView tagChipBarView] setAlpha:0];

    KayokoHeaderView *headerView = [[self mainView] headerView];
    [[self mainView] setAnimating:YES];
    [UIView animateWithDuration:0.3
        delay:0
        usingSpringWithDamping:1
        initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          [mainView setFrame:targetPanelFrame];
          [mainView layoutIfNeeded];
          [noteEditorView layoutIfNeeded];
          [headerView setAlpha:0];
          [sourceTableView setAlpha:0];
          [[noteEditorView previewCell] setFrame:[noteEditorView targetPreviewCellFrame]];
          [[noteEditorView previewCell] setAlpha:1];
          [[noteEditorView inputRowView] setAlpha:1];
          [[noteEditorView tagChipBarView] setAlpha:1];
        }
        completion:^(__unused BOOL finished) {
          [listViewController setCellPresentationHidden:NO forItem:item];
          if ([self noteEditingRequestIdentifier] != requestIdentifier || ![self isNoteEditing]) {
              return;
          }
          [headerView setHidden:YES];
          [sourceTableView setHidden:YES];
          [noteEditorView setAutomaticallyPositionsPreviewCell:YES];
          [noteEditorView setNeedsLayout];
          [[self mainView] setAnimating:NO];
          [[self searchController] resignSearchFirstResponder];
          [[self noteEditorViewController] beginEditing];
          [self executePendingExternalHideRequestIfReady];
        }];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)resetNoteEditingState {
    KayokoNoteEditorView *noteEditorView = [[self noteEditorViewController] noteEditorView];
    [noteEditorView setHidden:YES];
    [[self noteEditingSourceListViewController] setCellPresentationHidden:NO forItem:[self noteEditingItem]];
    [noteEditorView setAlpha:1];
    [noteEditorView setAutomaticallyPositionsPreviewCell:YES];
    [[noteEditorView inputRowView] setAlpha:1];
    [[noteEditorView tagChipBarView] setAlpha:1];
    [[self noteEditorViewController] reset];
    [self setNoteEditingItem:nil];
    [self setNoteEditingHistoryKey:nil];
    [self setNoteEditingSourceListViewController:nil];
    [self setNoteEditingBeganFromSearch:NO];
    [self setNoteEditingKeepsSearchHeaderHidden:NO];
    [self setFinishingNoteEditing:NO];
    [self setNoteEditingOriginalPanelFrame:CGRectZero];
    [self setNoteEditingOrigin:KayokoNoteEditingOriginNone];
    [self setNoteEditingRequestIdentifier:[self noteEditingRequestIdentifier] + 1];
}

- (void)animateNoteEditingReturnWithRequestIdentifier:(NSUInteger)requestIdentifier
                                   ensuresItemVisible:(BOOL)ensuresItemVisible
                                     targetPanelFrame:(CGRect)targetPanelFrame
                                             duration:(NSTimeInterval)duration
                                              options:(UIViewAnimationOptions)options {
    if ([self noteEditingRequestIdentifier] != requestIdentifier || ![self isNoteEditing] || [self isDismissingPanel]) {
        return;
    }

    UIView *sourceView = [self activeSourceContentView];
    KayokoHeaderView *headerView = [[self mainView] headerView];
    KayokoNoteEditorView *noteEditorView = [[self noteEditorViewController] noteEditorView];
    KayokoMainView *mainView = [self mainView];
    [sourceView setHidden:NO];
    [sourceView setAlpha:0];
    [headerView setHidden:NO];
    [headerView setAlpha:0];
    [noteEditorView setAutomaticallyPositionsPreviewCell:NO];

    KayokoHistoryListViewController *listViewController = [self noteEditingSourceListViewController];
    KayokoPasteboardItem *item = [self noteEditingItem];
    [listViewController setCellPresentationHidden:YES forItem:item];
    KayokoHistoryListView *tableView = [listViewController tableView];
    [mainView setAnimating:YES];

    duration = duration > 0 ? duration : 0.3;
    options |= UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction;
    [UIView animateWithDuration:duration
        delay:0
        options:options
        animations:^{
          [mainView setFrame:targetPanelFrame];
          [mainView layoutIfNeeded];
          [UIView performWithoutAnimation:^{
            if (ensuresItemVisible) {
                [listViewController scrollItemToVisible:item];
            }
            if ([self noteEditingKeepsSearchHeaderHidden]) {
                [tableView restoreHiddenSearchHeaderOffsetWithoutAnimation];
            } else {
                [tableView layoutIfNeeded];
            }
          }];

          [sourceView setAlpha:1];
          [headerView setAlpha:1];
          [[noteEditorView inputRowView] setAlpha:0];
          [[noteEditorView tagChipBarView] setAlpha:0];
          KayokoTableViewCell *targetCell = [listViewController visibleCellForItem:item];
          if (targetCell && [targetCell window]) {
              [[noteEditorView previewCell] setFrame:[targetCell convertRect:[targetCell bounds]
                                                                      toView:noteEditorView]];
          } else {
              [[noteEditorView previewCell] setAlpha:0];
          }
        }
        completion:^(__unused BOOL finished) {
          if ([self noteEditingRequestIdentifier] != requestIdentifier) {
              [listViewController setCellPresentationHidden:NO forItem:item];
              return;
          }
          [sourceView setAlpha:1];
          [sourceView setTransform:CGAffineTransformIdentity];
          [headerView setHidden:NO];
          [headerView setAlpha:1];
          [self setActiveSourceContentView:nil];
          [self resetNoteEditingState];
          [[self mainView] setAnimating:NO];
        }];
}

- (void)finishNoteEditingWithRequestIdentifier:(NSUInteger)requestIdentifier {
    if ([self noteEditingRequestIdentifier] != requestIdentifier || ![self isNoteEditing] || [self isDismissingPanel]) {
        return;
    }

    [self setFinishingNoteEditing:YES];
    KayokoNoteEditorView *noteEditorView = [[self noteEditorViewController] noteEditorView];
    [noteEditorView setAutomaticallyPositionsPreviewCell:NO];
    [[self noteEditorViewController] resignEditing];

    NSTimeInterval duration = [self noteEditingKeyboardAnimationDuration];
    UIViewAnimationOptions options = [self noteEditingKeyboardAnimationOptions];
    if ([self noteEditingOrigin] == KayokoNoteEditingOriginPreview ||
        [self noteEditingOrigin] == KayokoNoteEditingOriginWordSelection) {
        [self animateNoteEditingReturnToTransientContentWithRequestIdentifier:requestIdentifier
                                                             targetPanelFrame:[self noteEditingOriginalPanelFrame]
                                                                     duration:duration
                                                                      options:options];
        return;
    }

    [self clearSearchAfterTransientContentState];
    if ([[self searchController] isSearchActive]) {
        [[self searchController] resetSearchState];
    }
    [self animateNoteEditingReturnWithRequestIdentifier:requestIdentifier
                                     ensuresItemVisible:[self noteEditingBeganFromSearch]
                                       targetPanelFrame:[self noteEditingOriginalPanelFrame]
                                               duration:duration
                                                options:options];
}

- (void)noteEditorViewControllerDidRequestCancel:(KayokoNoteEditorViewController *)controller {
    if (![self isNoteEditing] || [self isDismissingPanel] || [self isFinishingNoteEditing]) {
        return;
    }

    [controller restorePreviewToSavedState];
    [self finishNoteEditingWithRequestIdentifier:[self noteEditingRequestIdentifier]];
}

- (void)noteEditorViewController:(KayokoNoteEditorViewController *)controller
                 didSelectTagUUID:(NSString *)tagUUID {
    (void)controller;
    (void)tagUUID;
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleLight];
}

- (void)noteEditorViewController:(KayokoNoteEditorViewController *)controller
              didRequestSaveNote:(NSString *)note
                       tagUUID:(NSString *)tagUUID {
    KayokoPasteboardItem *item = [self noteEditingItem];
    NSString *historyKey = [self noteEditingHistoryKey];
    KayokoHistoryListViewController *listViewController = [self noteEditingSourceListViewController];
    NSUInteger requestIdentifier = [self noteEditingRequestIdentifier];
    if (!item || [historyKey length] == 0 || !listViewController) {
        [controller setSaving:NO];
        return;
    }

    [[KayokoPasteboardManager sharedInstance]
                  setNote:note
                  tagUUID:tagUUID
        forPasteboardItem:item
         inHistoryWithKey:historyKey
               completion:^(BOOL success) {
                 if (!success) {
                     if ([self noteEditingRequestIdentifier] == requestIdentifier && [self isNoteEditing] &&
                         ![self isDismissingPanel]) {
                         [controller setSaving:NO];
                         [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleRigid];
                     }
                     return;
                 }

                 [item setNote:note];
                 [item setTagUUID:tagUUID];
                 [listViewController updateNote:note
                                        tagUUID:tagUUID
                                        forItem:item
                                     completion:^{
                                       [self finishNoteEditingWithRequestIdentifier:requestIdentifier];
                                     }];
               }];
}

- (void)noteEditorViewController:(KayokoNoteEditorViewController *)controller
    didUpdateKeyboardBottomInset:(CGFloat)keyboardBottomInset
               animationDuration:(NSTimeInterval)animationDuration
                         options:(UIViewAnimationOptions)options {
    if (controller != [self noteEditorViewController] || ![self isNoteEditing]) {
        return;
    }

    if ([self isFinishingNoteEditing] || [self isDismissingPanel]) {
        return;
    }

    [self setNoteEditingKeyboardAnimationDuration:animationDuration];
    [self setNoteEditingKeyboardAnimationOptions:options];

    KayokoNoteEditorView *noteEditorView = [controller noteEditorView];
    UIView *mainView = [self mainView];
    UIView *superview = [mainView superview];
    BOOL adjustsPanelFrame = superview != nil;
    CGRect targetFrame =
        adjustsPanelFrame ? [self noteEditingPanelFrameForKeyboardBottomInset:keyboardBottomInset] : [mainView frame];

    void (^updates)(void) = ^{
      [noteEditorView setAnchorsEditingContentToTop:YES];
      [noteEditorView setKeyboardBottomInset:0];
      if (adjustsPanelFrame) {
          [mainView setFrame:targetFrame];
      }
      [mainView layoutIfNeeded];
    };
    if (animationDuration <= 0) {
        updates();
        return;
    }
    [mainView layoutIfNeeded];
    [UIView animateWithDuration:animationDuration delay:0 options:options animations:updates completion:nil];
}

#pragma mark - Preview Note Editing

- (void)wordSelectionViewControllerDidRequestEdit:(KayokoWordSelectionViewController *)controller {
    if (controller != [self wordSelectionViewController] || [[self mainView] isAnimating] ||
        [[self panelPresentationController] isAnimating] || [self isNoteEditing]) {
        [[self wordSelectionViewController] setEditButtonEnabled:YES];
        return;
    }

    KayokoPasteboardItem *item = [controller sourceItem];
    NSString *historyKey = [controller sourceHistoryKey];
    if (!item || [historyKey length] == 0 || [[item imageName] length] > 0) {
        [[self wordSelectionViewController] setEditButtonEnabled:YES];
        return;
    }

    [self setPreviewTextEditingBeganFromWordSelection:YES];
    NSRange replacementRange = [controller hasSelectedText] ? [controller selectedTextRangeInOriginalText]
                                                            : NSMakeRange(NSNotFound, 0);
    UIView *wordSelectionView = [controller view];
    UIView *editorView = [[self textEditorViewController] textEditorView];
    [wordSelectionView setHidden:YES];
    [editorView setHidden:NO];
    [editorView setAlpha:1];
    [[self textEditorViewController] beginEditingItem:item
                                     sourceHistoryKey:historyKey
                                     replacementRange:replacementRange];
}

- (void)previewViewControllerDidRequestEdit:(KayokoPreviewViewController *)controller {
    if (controller != [self previewViewController] || [[self mainView] isAnimating] ||
        [[self panelPresentationController] isAnimating] || [self isNoteEditing]) {
        [[self previewViewController] setEditButtonEnabled:YES];
        return;
    }

    KayokoPasteboardItem *item = [controller previewItem];
    NSString *historyKey = [controller sourceHistoryKey];
    if (!item || [historyKey length] == 0) {
        [[self previewViewController] setEditButtonEnabled:YES];
        return;
    }
    if ([[item imageName] length] > 0) {
        [self clearExternalHideCoordinator];
        [controller beginImageEditing];
        return;
    }

    [self setPreviewTextEditingBeganFromWordSelection:NO];
    UIView *previewView = [controller previewView];
    UIView *editorView = [[self textEditorViewController] textEditorView];
    [previewView setHidden:YES];
    [editorView setHidden:NO];
    [editorView setAlpha:1];
    [[self textEditorViewController] beginEditingItem:item
                                     sourceHistoryKey:historyKey
                                     replacementRange:NSMakeRange(NSNotFound, 0)];
}

- (void)previewViewControllerDidFinishImageEditing:(KayokoPreviewViewController *)controller {
    if (controller == [self previewViewController] && ![self isHidden] && ![self isDismissingPanel]) {
        [[self delegate] mainViewControllerDidFinishImageEditing:self];
    }
}

- (void)textEditorViewControllerDidBeginEditing:(KayokoTextEditorViewController *)controller {
    (void)controller;
    if (CGRectIsEmpty([self previewTextEditingOriginalPanelFrame])) {
        [self setPreviewTextEditingOriginalPanelFrame:[[self mainView] frame]];
    }
    [self beginSearchInputExternalHideSuppression];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleLight];
}

- (void)restorePreviewTextEditingPanelFrameIfNeeded {
    [[[self previewViewController] previewView] setKeyboardBottomInset:0];
    [[[self textEditorViewController] textEditorView] setKeyboardBottomInset:0];
    [[[self textEditorViewController] textEditorView] setHidden:YES];
    [self endSearchInputExternalHideSuppression];
}

- (void)finishPreviewTextEditingFromController:(KayokoTextEditorViewController *)controller {
    [self setPreviewTextEditingFinishing:YES];
    [controller finishEditing];
    [self restorePreviewTextEditingPanelFrameIfNeeded];
    [self restoreWordSelectionAfterPreviewTextEditingIfNeeded];
    if ([self shouldLiftPreviewTextEditingCard] && !CGRectIsEmpty([self previewTextEditingOriginalPanelFrame]) &&
        !CGRectEqualToRect([[self mainView] frame], [self previewTextEditingOriginalPanelFrame])) {
        [self updatePreviewTextEditingPanelForKeyboardBottomInset:0
                                               animationDuration:0.25
                                                         options:UIViewAnimationOptionCurveEaseInOut |
                                                                 UIViewAnimationOptionBeginFromCurrentState |
                                                                 UIViewAnimationOptionAllowUserInteraction];
    } else {
        [self setPreviewTextEditingOriginalPanelFrame:CGRectZero];
        [self setPreviewTextEditingFinishing:NO];
    }
}

- (void)restoreWordSelectionAfterPreviewTextEditingIfNeeded {
    BOOL beganFromWordSelection = [self previewTextEditingBeganFromWordSelection];
    KayokoPasteboardItem *item = [[self textEditorViewController] item];
    NSString *historyKey = [[self textEditorViewController] sourceHistoryKey];
    UIView *editorView = [[self textEditorViewController] textEditorView];
    UIView *wordSelectionView = [[self wordSelectionViewController] view];
    UIView *previewView = [[self previewViewController] previewView];

    [editorView setHidden:YES];
    [[self textEditorViewController] reset];
    [self setPreviewTextEditingBeganFromWordSelection:NO];

    if (!item || [historyKey length] == 0) {
        return;
    }

    if (beganFromWordSelection) {
        [[self wordSelectionViewController] showWordSelectionWithItem:item
                                                     sourceHistoryKey:historyKey
                                                   automaticallyPaste:[self automaticallyPaste]];
        [wordSelectionView setHidden:NO];
        [wordSelectionView setAlpha:1];
        [[self wordSelectionViewController] setEditButtonEnabled:YES];
        return;
    }

    [[self previewViewController] showPreviewWithItem:item sourceHistoryKey:historyKey];
    [previewView setHidden:NO];
    [previewView setAlpha:1];
    [[self previewViewController] setEditButtonEnabled:YES];
}

- (void)textEditorViewControllerDidRequestCancel:(KayokoTextEditorViewController *)controller {
    if (controller != [self textEditorViewController] || [self isPreviewTextEditingFinishing] || [controller isSaving]) {
        return;
    }
    [self finishPreviewTextEditingFromController:controller];
}

- (void)textEditorViewControllerDidRequestSave:(KayokoTextEditorViewController *)controller {
    if (controller != [self textEditorViewController] || [self isPreviewTextEditingFinishing]) {
        return;
    }

    KayokoPasteboardItem *item = [controller item];
    NSString *historyKey = [controller sourceHistoryKey];
    NSString *updatedText = [controller composedEditedContent];
    if (!item || [historyKey length] == 0) {
        [controller setSaving:NO];
        return;
    }

    NSString *normalizedText = [(updatedText ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    if ([normalizedText length] == 0) {
        [controller setSaving:NO];
        [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleRigid];
        return;
    }

    if ([normalizedText isEqualToString:[item content]]) {
        [self finishPreviewTextEditingFromController:controller];
        return;
    }

    NSDictionary<NSString *, id> *originalDictionary = [item dictionaryRepresentation];
    KayokoHistoryListViewController *listViewController = [self listViewControllerForHistoryKey:historyKey];
    NSUInteger requestIdentifier = [self previewTextEditingRequestIdentifier] + 1;
    [self setPreviewTextEditingRequestIdentifier:requestIdentifier];
    [[KayokoPasteboardManager sharedInstance] replaceContent:normalizedText
                                          forPasteboardItem:item
                                           inHistoryWithKey:historyKey
                                                 completion:^(BOOL success) {
                                                   if ([self previewTextEditingRequestIdentifier] != requestIdentifier ||
                                                       controller != [self textEditorViewController] ||
                                                       ![controller isEditing]) {
                                                       return;
                                                   }
                                                   if (!success) {
                                                       [controller setSaving:NO];
                                                       [[self panelPresentationController]
                                                           triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleRigid];
                                                       return;
                                                   }

                                                   [listViewController replaceContent:normalizedText
                                                           forItemMatchingDictionary:originalDictionary
                                                                           completion:^{
                                                                             if ([self previewTextEditingRequestIdentifier] !=
                                                                                     requestIdentifier ||
                                                                                 controller != [self textEditorViewController] ||
                                                                                 ![controller isEditing]) {
                                                                                 return;
                                                                             }
                                                                             [item setContent:normalizedText];
                                                                             [item setHasLink:[normalizedText hasPrefix:@"http://"] ||
                                                                                              [normalizedText hasPrefix:@"https://"]];
                                                                             [self finishPreviewTextEditingFromController:controller];
                                                                             [[self panelPresentationController]
                                                                                 triggerHapticFeedbackWithStyle:
                                                                                     UIImpactFeedbackStyleMedium];
                                                                           }];
                                                 }];
}

- (void)beginNoteEditingFromPreviewController:(KayokoPreviewViewController *)controller {
    KayokoPasteboardItem *item = [controller previewItem];
    NSString *historyKey = [controller sourceHistoryKey];
    KayokoPreviewView *previewView = [controller previewView];
    if (!item || [historyKey length] == 0 || [previewView isHidden]) {
        [controller setEditButtonEnabled:YES];
        return;
    }

    KayokoHistoryListViewController *listViewController = [self listViewControllerForHistoryKey:historyKey];
    KayokoTableViewCell *presentationCell = [listViewController presentationCellForItem:item];
    if (!listViewController || !presentationCell) {
        [controller setEditButtonEnabled:YES];
        return;
    }

    [controller setEditButtonEnabled:NO];
    [previewView setUserInteractionEnabled:NO];

    UIView *mainView = [self mainView];
    CGFloat keyboardBottomInset = [[self noteEditorViewController] visibleKeyboardBottomInset];
    [self setNoteEditingBeganFromSearch:NO];
    [self setNoteEditingKeepsSearchHeaderHidden:NO];
    [self setNoteEditingOriginalPanelFrame:[mainView frame]];
    [self setNoteEditingKeyboardAnimationDuration:0.25];
    [self setNoteEditingKeyboardAnimationOptions:UIViewAnimationOptionCurveEaseInOut |
                                                 UIViewAnimationOptionBeginFromCurrentState |
                                                 UIViewAnimationOptionAllowUserInteraction];

    KayokoTableViewCell *visibleCell = [listViewController visibleCellForItem:item];
    CGFloat cellHeight = CGRectGetHeight([visibleCell bounds]);
    if (cellHeight <= 0) {
        cellHeight = [[listViewController tableView] rowHeight];
    }
    NSUInteger requestIdentifier = [self prepareNoteEditingSessionForItem:item
                                                       listViewController:listViewController
                                                         presentationCell:presentationCell
                                                               cellHeight:cellHeight
                                                      keyboardBottomInset:keyboardBottomInset
                                                                   origin:KayokoNoteEditingOriginPreview];

    KayokoNoteEditorView *noteEditorView = [[self noteEditorViewController] noteEditorView];
    [[self mainView] layoutIfNeeded];
    [noteEditorView setHidden:NO];
    [noteEditorView setAlpha:0];
    [noteEditorView setAutomaticallyPositionsPreviewCell:YES];
    [noteEditorView layoutIfNeeded];
    [[noteEditorView previewCell] setFrame:[noteEditorView targetPreviewCellFrame]];
    [[noteEditorView previewCell] setAlpha:1];
    [[noteEditorView inputRowView] setAlpha:1];
    [[noteEditorView tagChipBarView] setAlpha:1];

    CGRect targetPanelFrame = [self noteEditingPanelFrameForKeyboardBottomInset:keyboardBottomInset];
    [[self mainView] setAnimating:YES];
    [UIView animateWithDuration:0.25
        delay:0
        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          [mainView setFrame:targetPanelFrame];
          [mainView layoutIfNeeded];
          [noteEditorView layoutIfNeeded];
          [previewView setAlpha:0];
          [noteEditorView setAlpha:1];
        }
        completion:^(__unused BOOL finished) {
          if ([self noteEditingRequestIdentifier] != requestIdentifier || ![self isNoteEditing]) {
              [previewView setHidden:NO];
              [previewView setAlpha:1];
              [previewView setUserInteractionEnabled:YES];
              [controller setEditButtonEnabled:YES];
              return;
          }
          [previewView setHidden:YES];
          [previewView setAlpha:1];
          [noteEditorView setAutomaticallyPositionsPreviewCell:YES];
          [noteEditorView setNeedsLayout];
          [[self mainView] setAnimating:NO];
          [[self noteEditorViewController] beginEditing];
          [self executePendingExternalHideRequestIfReady];
        }];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (UIView *)transientContentViewForNoteEditingOrigin:(KayokoNoteEditingOrigin)origin {
    if (origin == KayokoNoteEditingOriginPreview) {
        return [[self previewViewController] previewView];
    }
    if (origin == KayokoNoteEditingOriginWordSelection) {
        return [[self wordSelectionViewController] view];
    }
    return nil;
}

- (void)restoreTransientEditButtonForOrigin:(KayokoNoteEditingOrigin)origin {
    if (origin == KayokoNoteEditingOriginPreview) {
        [[self previewViewController] setEditButtonEnabled:YES];
    } else if (origin == KayokoNoteEditingOriginWordSelection) {
        [[self wordSelectionViewController] setEditButtonEnabled:YES];
    }
}

- (void)beginNoteEditingFromWordSelectionController:(KayokoWordSelectionViewController *)controller {
    KayokoPasteboardItem *item = [controller sourceItem];
    NSString *historyKey = [controller sourceHistoryKey];
    UIView *contentView = [controller view];
    if (!item || [historyKey length] == 0 || [contentView isHidden]) {
        [controller setEditButtonEnabled:YES];
        return;
    }

    KayokoHistoryListViewController *listViewController = [self listViewControllerForHistoryKey:historyKey];
    KayokoTableViewCell *presentationCell = [listViewController presentationCellForItem:item];
    if (!listViewController || !presentationCell) {
        [controller setEditButtonEnabled:YES];
        return;
    }

    [controller setEditButtonEnabled:NO];
    [contentView setUserInteractionEnabled:NO];

    UIView *mainView = [self mainView];
    CGFloat keyboardBottomInset = [[self noteEditorViewController] visibleKeyboardBottomInset];
    [self setNoteEditingBeganFromSearch:NO];
    [self setNoteEditingKeepsSearchHeaderHidden:NO];
    [self setNoteEditingOriginalPanelFrame:[mainView frame]];
    [self setNoteEditingKeyboardAnimationDuration:0.25];
    [self setNoteEditingKeyboardAnimationOptions:UIViewAnimationOptionCurveEaseInOut |
                                                 UIViewAnimationOptionBeginFromCurrentState |
                                                 UIViewAnimationOptionAllowUserInteraction];

    KayokoTableViewCell *visibleCell = [listViewController visibleCellForItem:item];
    CGFloat cellHeight = CGRectGetHeight([visibleCell bounds]);
    if (cellHeight <= 0) {
        cellHeight = [[listViewController tableView] rowHeight];
    }
    NSUInteger requestIdentifier = [self prepareNoteEditingSessionForItem:item
                                                       listViewController:listViewController
                                                         presentationCell:presentationCell
                                                               cellHeight:cellHeight
                                                      keyboardBottomInset:keyboardBottomInset
                                                                   origin:KayokoNoteEditingOriginWordSelection];

    KayokoNoteEditorView *noteEditorView = [[self noteEditorViewController] noteEditorView];
    [[self mainView] layoutIfNeeded];
    [noteEditorView setHidden:NO];
    [noteEditorView setAlpha:0];
    [noteEditorView setAutomaticallyPositionsPreviewCell:YES];
    [noteEditorView layoutIfNeeded];
    [[noteEditorView previewCell] setFrame:[noteEditorView targetPreviewCellFrame]];
    [[noteEditorView previewCell] setAlpha:1];
    [[noteEditorView inputRowView] setAlpha:1];
    [[noteEditorView tagChipBarView] setAlpha:1];

    CGRect targetPanelFrame = [self noteEditingPanelFrameForKeyboardBottomInset:keyboardBottomInset];
    [[self mainView] setAnimating:YES];
    [UIView animateWithDuration:0.25
        delay:0
        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          [mainView setFrame:targetPanelFrame];
          [mainView layoutIfNeeded];
          [noteEditorView layoutIfNeeded];
          [contentView setAlpha:0];
          [noteEditorView setAlpha:1];
        }
        completion:^(__unused BOOL finished) {
          if ([self noteEditingRequestIdentifier] != requestIdentifier || ![self isNoteEditing]) {
              [contentView setHidden:NO];
              [contentView setAlpha:1];
              [contentView setUserInteractionEnabled:YES];
              [controller setEditButtonEnabled:YES];
              return;
          }
          [contentView setHidden:YES];
          [contentView setAlpha:1];
          [noteEditorView setAutomaticallyPositionsPreviewCell:YES];
          [noteEditorView setNeedsLayout];
          [[self mainView] setAnimating:NO];
          [[self noteEditorViewController] beginEditing];
          [self executePendingExternalHideRequestIfReady];
        }];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)animateNoteEditingReturnToTransientContentWithRequestIdentifier:(NSUInteger)requestIdentifier
                                                       targetPanelFrame:(CGRect)targetPanelFrame
                                                               duration:(NSTimeInterval)duration
                                                                options:(UIViewAnimationOptions)options {
    if ([self noteEditingRequestIdentifier] != requestIdentifier || ![self isNoteEditing] || [self isDismissingPanel]) {
        return;
    }

    KayokoNoteEditingOrigin origin = [self noteEditingOrigin];
    UIView *contentView = [self transientContentViewForNoteEditingOrigin:origin];
    if (!contentView) {
        return;
    }

    KayokoNoteEditorView *noteEditorView = [[self noteEditorViewController] noteEditorView];
    KayokoMainView *mainView = [self mainView];
    [contentView setHidden:NO];
    [contentView setAlpha:0];
    [contentView setUserInteractionEnabled:NO];
    [noteEditorView setAutomaticallyPositionsPreviewCell:YES];
    [[self mainView] setAnimating:YES];

    duration = duration > 0 ? duration : 0.25;
    options |= UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction;
    [UIView animateWithDuration:duration
        delay:0
        options:options
        animations:^{
          [mainView setFrame:targetPanelFrame];
          [mainView layoutIfNeeded];
          [noteEditorView setAlpha:0];
          [contentView setAlpha:1];
        }
        completion:^(__unused BOOL finished) {
          if ([self noteEditingRequestIdentifier] != requestIdentifier) {
              [contentView setAlpha:1];
              [contentView setUserInteractionEnabled:YES];
              return;
          }
          [contentView setHidden:NO];
          [contentView setAlpha:1];
          [contentView setUserInteractionEnabled:YES];
          [self resetNoteEditingState];
          [self restoreTransientEditButtonForOrigin:origin];
          [[self mainView] setAnimating:NO];
        }];
}

#pragma mark - Transient Presentation

- (void)showContentForItem:(KayokoPasteboardItem *)item {
    BOOL restoresSearchFirstResponder = [[self searchController] isActiveSearchFirstResponder];
    [self setRestoresSearchFirstResponderAfterTransientContent:restoresSearchFirstResponder];
    if (restoresSearchFirstResponder) {
        [self setSearchContentOffsetBeforeTransientContent:[[[self activeListViewController] tableView] contentOffset]];
        [self setHasSearchContentOffsetBeforeTransientContent:YES];
    } else {
        [self setHasSearchContentOffsetBeforeTransientContent:NO];
    }
    NSString *historyKey = [self effectiveActiveHistoryKey];
    KayokoHistoryListView *sourceTableView = [self tableViewForHistoryKey:historyKey];
    [self setActiveSourceContentView:sourceTableView];
    NSString *previewText =
        [([item content] ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    BOOL canUseWordSelection = [self swipeToSelectWords] && [[item imageName] isEqualToString:@""] &&
                               [[self wordSelectionViewController] canShowText:previewText];
    UIView *viewToShow = nil;
    UIView *transitionContentView = nil;
    if (canUseWordSelection) {
        [[self wordSelectionViewController] showWordSelectionWithItem:item
                                                     sourceHistoryKey:historyKey
                                                   automaticallyPaste:[self automaticallyPaste]];
        viewToShow = [[self wordSelectionViewController] view];
        transitionContentView = [[self wordSelectionViewController] wordSelectionView].transitionContentView;
    } else {
        [[self previewViewController] showPreviewWithItem:item sourceHistoryKey:historyKey];
        viewToShow = [[self previewViewController] previewView];
        transitionContentView = [[self previewViewController] previewView].transitionContentView;
    }

    KayokoHeaderView *mainHeaderView = [[self mainView] headerView];
    [mainHeaderView setHidden:YES];
    [mainHeaderView setAlpha:1.0];
    [[self mainView] showContentView:viewToShow
                   transitioningView:transitionContentView
                     hideContentView:sourceTableView
                   transitioningView:sourceTableView
                           direction:KayokoContentTransitionDirectionForward
                 alongsideAnimations:nil
                          completion:^{
                            if (restoresSearchFirstResponder) {
                                [[self searchController] resignSearchFirstResponder];
                            }
                          }];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)hidePreview {
    [[[self mainView] headerView] setHistorySwitcherVisible:YES animated:NO];
    [self updateFavoritesButtonForHistoryKey:[self effectiveActiveHistoryKey]];
    if ([[[self previewViewController] previewView] isHidden] || [[self panelPresentationController] isAnimating]) {
        return;
    }

    UIView *sourceView = [self activeSourceContentView];
    KayokoPreviewView *previewView = [[self previewViewController] previewView];
    if (!sourceView) {
        [[self previewViewController] resetPreviewState];
        [[previewView headerView] setHidden:NO];
        [self setActiveSourceContentView:nil];
        [[[self mainView] headerView] setHidden:NO];
        [[[self mainView] headerView] setAlpha:1.0];
        [self refreshSearchAfterEndingTransientContentIfNeeded];
        return;
    }

    UIView *mainHeaderView = [[self mainView] headerView];
    [mainHeaderView setHidden:NO];
    [mainHeaderView setAlpha:1.0];
    [[previewView headerView] setHidden:YES];
    [[self mainView] showContentView:sourceView
        transitioningView:sourceView
        hideContentView:previewView
        transitioningView:[previewView transitionContentView]
        direction:KayokoContentTransitionDirectionBackward
        alongsideAnimations:^{
          [self refreshSearchAfterEndingTransientContentIfNeeded];
        }
        completion:^{
          [[self previewViewController] hidePreview];
          [[previewView headerView] setHidden:NO];
          [self setActiveSourceContentView:nil];
          [mainHeaderView setHidden:NO];
          [mainHeaderView setAlpha:1.0];
        }];
}

- (void)hideWordSelection {
    [[[self mainView] headerView] setHistorySwitcherVisible:YES animated:NO];
    [self updateFavoritesButtonForHistoryKey:[self effectiveActiveHistoryKey]];
    if ([[[self wordSelectionViewController] view] isHidden] || [[self panelPresentationController] isAnimating]) {
        return;
    }

    UIView *sourceView = [self activeSourceContentView];
    UIView *wordSelectionView = [[self wordSelectionViewController] view];
    if (!sourceView) {
        [[self wordSelectionViewController] resetWordSelectionState];
        [[[[self wordSelectionViewController] wordSelectionView] headerView] setHidden:NO];
        [self setActiveSourceContentView:nil];
        [[[self mainView] headerView] setHidden:NO];
        [[[self mainView] headerView] setAlpha:1.0];
        [self refreshSearchAfterEndingTransientContentIfNeeded];
        return;
    }

    UIView *mainHeaderView = [[self mainView] headerView];
    [mainHeaderView setHidden:NO];
    [mainHeaderView setAlpha:1.0];
    [[[[self wordSelectionViewController] wordSelectionView] headerView] setHidden:YES];
    [[self mainView] showContentView:sourceView
        transitioningView:sourceView
        hideContentView:wordSelectionView
        transitioningView:[[self wordSelectionViewController] wordSelectionView].transitionContentView
        direction:KayokoContentTransitionDirectionBackward
        alongsideAnimations:^{
          [self refreshSearchAfterEndingTransientContentIfNeeded];
        }
        completion:^{
          [[self wordSelectionViewController] hideWordSelection];
          [[[[self wordSelectionViewController] wordSelectionView] headerView] setHidden:NO];
          [self setActiveSourceContentView:nil];
          [mainHeaderView setHidden:NO];
          [mainHeaderView setAlpha:1.0];
        }];
}

#pragma mark - KayokoClearConfirmationViewControllerDelegate

- (void)clearConfirmationViewControllerDidCancel:(KayokoClearConfirmationViewController *)controller {
    if ([[self panelPresentationController] isAnimating]) {
        return;
    }

    [self hideClearConfirmationWithReload:NO];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
}

- (void)clearConfirmationViewControllerDidClearHistoryKey:(NSString *)historyKey {
    [self hideClearConfirmationWithReload:YES];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleHeavy];
}

- (void)clearConfirmationViewController:(KayokoClearConfirmationViewController *)controller
              didFailClearingHistoryKey:(NSString *)historyKey {
}

#pragma mark - KayokoWordSelectionViewControllerDelegate

- (void)wordSelectionViewController:(KayokoWordSelectionViewController *)controller
    didRequestHideContainerAfterDirectPaste:(BOOL)directPaste {
    [[self panelPresentationController] prepareStandardDismissAnimation];
    if (directPaste) {
        [self hideAfterDirectPaste];
    } else {
        [self hideRestoringFocus];
    }
}

- (void)wordSelectionViewController:(KayokoWordSelectionViewController *)controller
     triggerHapticFeedbackWithStyle:(UIImpactFeedbackStyle)style {
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:style];
}


#pragma mark - Public API

- (void)reload {

    NSString *historyKey = [self effectiveActiveHistoryKey];
    [self reloadTableViewForHistoryKey:historyKey
                animatingTopInsertions:![self isHidden] && [historyKey isEqualToString:kKayokoHistoryKeyHistory]
                            completion:^(KayokoHistoryListView *tableView) {
                              if (![[self effectiveActiveHistoryKey] isEqualToString:historyKey]) {
                                  return;
                              }
                              if ([self isShowingClearConfirmation] ||
                                  ![[[self previewViewController] previewView] isHidden] ||
                                  ![[[self wordSelectionViewController] view] isHidden] || [self isNoteEditing]) {
                                  return;
                              }
                              [self setHistoryContentVisibleForKey:historyKey];
                              [[self searchController] refreshForListViewController:[self activeListViewController]];
                            }];
}

- (void)preloadHistoryIfNeeded {
    [[self historyController] preloadHistoryWithCompletion:nil];
}

- (void)show {
    if ([[self panelPresentationController] isAnimating] || [self preparingToShow]) {
        return;
    }
    if (![self isHidden]) {
        return;
    }

    [self clearExternalHideCoordinator];
    [self setDismissingPanel:NO];
    [self setPreparingToShow:YES];
    [[KayokoTagCatalog sharedCatalog] reloadTags];
    [[self searchController] reloadFilterOrder];
    NSUInteger showRequestIdentifier = [self showRequestIdentifier] + 1;
    [self setShowRequestIdentifier:showRequestIdentifier];
    [self resetClearConfirmationIfNeeded];

    [[self historyListViewController] setAutomaticallyPaste:[self automaticallyPaste]];
    [[self favoritesListViewController] setAutomaticallyPaste:[self automaticallyPaste]];
    [[[self historyListViewController] tableView] reloadData];
    [[[self favoritesListViewController] tableView] reloadData];

    NSString *initialHistoryKey = [self historyKeyForInitialViewMode];
    if ([initialHistoryKey length] > 0) {
        [[self historyController] setActiveHistoryKey:initialHistoryKey];
    }

    NSString *historyKey = [self effectiveActiveHistoryKey];
    [self reloadTableViewForHistoryKey:historyKey
                animatingTopInsertions:NO
                            completion:^(KayokoHistoryListView *tableView) {
                              if ([self showRequestIdentifier] != showRequestIdentifier) {
                                  return;
                              }
                              [self setPreparingToShow:NO];
                              if (![[self effectiveActiveHistoryKey] isEqualToString:historyKey] || ![self isHidden] ||
                                  [[self panelPresentationController] isAnimating]) {
                                  return;
                              }

                              [self setHistoryContentVisibleForKey:historyKey];
                              [[self searchController] attachToListViewController:[self activeListViewController]
                                                                   hidesSearchBar:YES];
                              [[self panelPresentationController] showPanelWithCompletion:^{
                                [self executePendingExternalHideRequestIfReady];
                              }];
                            }];
}

#pragma mark - Hiding

- (void)hide {
    [self hideWithCompletion:nil];
}

- (void)hideWithStandardDismissAnimation {
    [[self panelPresentationController] prepareStandardDismissAnimation];
    [self hideWithCompletion:nil];
}

- (void)hideAfterDirectPaste {
    BOOL shouldRestoreFocusAfterHide = [self isFullscreenSearchActive];
    [self hideWithCompletion:^{
      if (!shouldRestoreFocusAfterHide) {
          return;
      }
      [[self delegate] mainViewControllerDidRequestFocusRestore:self];
    }];
}

- (void)hideRestoringFocus {
    [self hideWithCompletion:^{
      [[self delegate] mainViewControllerDidRequestFocusRestore:self];
    }];
}

- (void)completeHideAfterShowingTransientContent:(BOOL)wasShowingTransientContent
                                      completion:(void (^)(void))completion {
    [self restoreActiveSourceContentView];
    [[[self mainView] headerView] setHidden:NO];
    [[[self mainView] headerView] setAlpha:1.0];
    [[self previewViewController] resetPreviewState];
    [[self wordSelectionViewController] resetWordSelectionState];
    [[self textEditorViewController] reset];
    [self setPreviewTextEditingRequestIdentifier:[self previewTextEditingRequestIdentifier] + 1];
    [self setPreviewTextEditingOriginalPanelFrame:CGRectZero];
    [self setPreviewTextEditingFinishing:NO];
    [self resetNoteEditingState];
    [self setActiveSourceContentView:nil];
    [self setDismissingPanel:NO];
    if (wasShowingTransientContent) {
        [self refreshSearchAfterEndingTransientContentIfNeeded];
    }
    if ([self alwaysScrollToTop]) {
        [[self historyController] markAllHistoryKeysForScrollToTopBeforeNextDisplay];
    }
    [[self delegate] mainViewControllerDidHide:self];
    if (completion) {
        completion();
    }
}

- (void)hideWithCompletion:(void (^)(void))completion {
    [self hideWithAnimationStyle:KayokoPanelHideAnimationStyleDefault completion:completion];
}

- (void)hideWithAnimationStyle:(KayokoPanelHideAnimationStyle)animationStyle completion:(void (^)(void))completion {
    [self setShowRequestIdentifier:[self showRequestIdentifier] + 1];
    [self setPreparingToShow:NO];

    if ([[self panelPresentationController] isAnimating]) {
        return;
    }
    [[self previewViewController] dismissImageEditing];

    [self dismissLeadingButtonMenu];

    [self clearExternalHideCoordinator];
    [self setDismissingPanel:YES];
    BOOL wasShowingTransientContent =
        [self isPreviewActive] || [self isWordSelectionActive] || [self isNoteEditing] || [self isPreviewTextEditing];
    [[self searchController] resignSearchFirstResponder];
    [[self noteEditorViewController] resignEditing];
    [[[[self textEditorViewController] textEditorView] textView] resignFirstResponder];
    [[self panelPresentationController]
        hidePanelWithAnimationStyle:animationStyle
                         completion:^{
                           [[self searchController] resetSearchState];
                           [self completeHideAfterShowingTransientContent:wasShowingTransientContent
                                                               completion:completion];
                         }];
}

- (void)hideForExternalRequestWithAnimationStyle:(KayokoPanelHideAnimationStyle)animationStyle
                                      completion:(nullable void (^)(void))completion {
    if ([self isHidden]) {
        return;
    }

    if ([[self wordSelectionViewController] shouldSuppressExternalHideRequest] ||
        [[self previewViewController] shouldSuppressExternalHideRequest]) {
        return;
    }

    if ([self isEditingAnyContent]) {
        return;
    }

    if ([[self externalHideCoordinator] shouldSuppressExternalHide]) {
        return;
    }

    if ([self externalHideRequestShouldWaitForAnimations]) {
        [[self externalHideCoordinator] recordPendingExternalHideRequestWithAnimationStyle:animationStyle
                                                                                completion:completion];
        return;
    }

    [self hideWithAnimationStyle:animationStyle completion:completion];
}

- (void)hideImmediately {
    [self setShowRequestIdentifier:[self showRequestIdentifier] + 1];
    [self setPreparingToShow:NO];
    [[self previewViewController] dismissImageEditing];

    if ([self isHidden]) {
        return;
    }

    [self dismissLeadingButtonMenu];
    [self clearExternalHideCoordinator];
    [self setDismissingPanel:YES];
    BOOL wasShowingTransientContent =
        [self isPreviewActive] || [self isWordSelectionActive] || [self isNoteEditing] || [self isPreviewTextEditing];
    [[self searchController] resignSearchFirstResponder];
    [[self noteEditorViewController] resignEditing];
    [[[[self textEditorViewController] textEditorView] textView] resignFirstResponder];
    [[self panelPresentationController] hidePanelImmediatelyWithCompletion:^{
      [[self searchController] resetSearchState];
      [self completeHideAfterShowingTransientContent:wasShowingTransientContent completion:nil];
    }];
}

@end
