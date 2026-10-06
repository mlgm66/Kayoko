//
//  KayokoPreferenceKeys.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, ActivationMethod) {
    kActivationMethodPredictionBar = 1 << 0,
    kActivationMethodDictationKey = 1 << 1,
    kActivationMethodInputSwitcher = 1 << 2,
    kActivationMethodCalloutBar = 1 << 3,
    kActivationMethodSwipeUp = 1 << 4,
    kActivationMethodExternalKeyboard = 1 << 5
};

typedef NS_ENUM(NSUInteger, KayokoAutomaticPasteMode) {
    kKayokoAutomaticPasteModeClassic = 0,
    kKayokoAutomaticPasteModeSimulated = 1,
    kKayokoAutomaticPasteModeAutomatic = 2
};

typedef NS_ENUM(NSUInteger, KayokoAutomaticPromotionMode) {
    kKayokoAutomaticPromotionModeOff = 0,
    kKayokoAutomaticPromotionModeHistoryOnly = 1,
    kKayokoAutomaticPromotionModeAlways = 2
};

typedef NS_ENUM(NSUInteger, KayokoGestureRecognizerMode) {
    kKayokoGestureRecognizerModeClassic = 0,
    kKayokoGestureRecognizerModeSystem = 1
};

typedef NS_ENUM(NSUInteger, KayokoInitialViewMode) {
    kKayokoInitialViewModeHistory = 0,
    kKayokoInitialViewModeFavorites = 1,
    kKayokoInitialViewModePreviousSelection = 2
};

typedef NS_ENUM(NSUInteger, KayokoClearButtonMode) {
    kKayokoClearButtonModeOff = 0,
    kKayokoClearButtonModeHistoryOnly = 1,
    kKayokoClearButtonModeAlways = 2
};

typedef NS_ENUM(NSUInteger, KayokoItemDetailsMode) {
    kKayokoItemDetailsModeOff = 0,
    kKayokoItemDetailsModeImagesOnly = 1,
    kKayokoItemDetailsModeAll = 2
};

typedef NS_ENUM(NSUInteger, KayokoOverlayWindowLevelMode) {
    kKayokoOverlayWindowLevelModeCustom = 0,
    kKayokoOverlayWindowLevelModeMaximum = 1
};

static NSString *const kKayokoPreferencesIdentifier = @"com.mlgm.kayoko.preferences";
static NSString *const kKayokoPreferenceKeyFilterSectionOrder = @"FilterSectionOrder";
static NSString *const kKayokoPreferenceKeyFilterCategoryOrder = @"FilterCategoryOrder";
static NSString *const kKayokoPreferenceKeyFilterApplicationOrder = @"FilterApplicationOrder";

static NSString *const kKayokoPreferenceKeyEnabled = @"Enabled";
static NSString *const kKayokoPreferenceKeyMaximumHistoryAmount = @"MaximumHistoryAmount";
static NSString *const kKayokoPreferenceKeySaveText = @"SaveText";
static NSString *const kKayokoPreferenceKeySaveImages = @"SaveImages";
static NSString *const kKayokoPreferenceKeySwipeToSelectWords = @"SwipeToSelectWords";
static NSString *const kKayokoPreferenceKeyActivationMethod = @"ActivationMethod";
static NSString *const kKayokoPreferenceKeyGestureRecognizerMode = @"GestureRecognizerMode";
static NSString *const kKayokoPreferenceKeyAutomaticallyPaste = @"AutomaticallyPaste";
static NSString *const kKayokoPreferenceKeyAutomaticPasteMode = @"AutomaticPasteMode";
static NSString *const kKayokoPreferenceKeyAutomaticPromotionMode = @"AutomaticPromotionMode";
static NSString *const kKayokoPreferenceKeyInitialViewMode = @"InitialViewMode";
static NSString *const kKayokoPreferenceKeyAlwaysScrollToTop = @"AlwaysScrollToTop";
static NSString *const kKayokoPreferenceKeyClearButtonMode = @"ClearButtonMode";
static NSString *const kKayokoPreferenceKeyDismissOnOutsideTouch = @"DismissOnOutsideTouch";
static NSString *const kKayokoPreferenceKeyDisablePasteTips = @"DisablePasteTips";
static NSString *const kKayokoPreferenceKeyIgnoreRemoteReplication = @"IgnoreRemoteReplication";
static NSString *const kKayokoPreferenceKeyApplicationBlacklist = @"ApplicationBlacklist";
static NSString *const kKayokoPreferenceKeyPlaySoundEffects = @"PlaySoundEffects";
static NSString *const kKayokoPreferenceKeyPlayHapticFeedback = @"PlayHapticFeedback";
static NSString *const kKayokoPreferenceKeyPreviewLineCount = @"PreviewLineCount";
static NSString *const kKayokoPreferenceKeyItemDetailsMode = @"ItemDetailsMode";
static NSString *const kKayokoPreferenceKeyHeightInPoints = @"HeightInPoints";
static NSString *const kKayokoPreferenceKeyOverlayWindowLevelMode = @"OverlayWindowLevelMode";
static NSString *const kKayokoPreferenceKeyOverlayWindowLevel = @"OverlayWindowLevel";
static NSString *const kKayokoPreferenceKeyFavoritesFilterPanelVisible = @"FavoritesFilterPanelVisible";
static NSString *const kKayokoPreferenceKeyFavoritesFilterShowsCategories = @"FavoritesFilterShowsCategories";
static NSString *const kKayokoPreferenceKeyFavoritesFilterShowsTags = @"FavoritesFilterShowsTags";
static NSString *const kKayokoPreferenceKeyFavoritesFilterShowsApps = @"FavoritesFilterShowsApps";

static BOOL const kKayokoPreferenceKeyEnabledDefaultValue = YES;
static NSUInteger const kKayokoPreferenceKeyMaximumHistoryAmountDefaultValue = 200;
static BOOL const kKayokoPreferenceKeySaveTextDefaultValue = YES;
static BOOL const kKayokoPreferenceKeySaveImagesDefaultValue = YES;
static BOOL const kKayokoPreferenceKeySwipeToSelectWordsDefaultValue = YES;
static ActivationMethod const kKayokoPreferenceKeyActivationMethodDefaultValue =
    kActivationMethodDictationKey | kActivationMethodInputSwitcher | kActivationMethodExternalKeyboard;
static KayokoGestureRecognizerMode const kKayokoPreferenceKeyGestureRecognizerModeDefaultValue =
    kKayokoGestureRecognizerModeClassic;
static BOOL const kKayokoPreferenceKeyAutomaticallyPasteDefaultValue = YES;
static KayokoAutomaticPasteMode const kKayokoPreferenceKeyAutomaticPasteModeDefaultValue =
    kKayokoAutomaticPasteModeAutomatic;
static KayokoAutomaticPromotionMode const kKayokoPreferenceKeyAutomaticPromotionModeDefaultValue =
    kKayokoAutomaticPromotionModeHistoryOnly;
static KayokoInitialViewMode const kKayokoPreferenceKeyInitialViewModeDefaultValue =
    kKayokoInitialViewModePreviousSelection;
static BOOL const kKayokoPreferenceKeyAlwaysScrollToTopDefaultValue = NO;
static KayokoClearButtonMode const kKayokoPreferenceKeyClearButtonModeDefaultValue = kKayokoClearButtonModeHistoryOnly;
static BOOL const kKayokoPreferenceKeyDismissOnOutsideTouchDefaultValue = YES;
static BOOL const kKayokoPreferenceKeyDisablePasteTipsDefaultValue = NO;
static BOOL const kKayokoPreferenceKeyIgnoreRemoteReplicationDefaultValue = NO;
static BOOL const kKayokoPreferenceKeyPlaySoundEffectsDefaultValue = YES;
static BOOL const kKayokoPreferenceKeyPlayHapticFeedbackDefaultValue = YES;
static NSUInteger const kKayokoPreferenceKeyPreviewLineCountDefaultValue = 1;
static KayokoItemDetailsMode const kKayokoPreferenceKeyItemDetailsModeDefaultValue = kKayokoItemDetailsModeImagesOnly;
static CGFloat const kKayokoPreferenceKeyHeightInPointsDefaultValue = 420;
static KayokoOverlayWindowLevelMode const kKayokoPreferenceKeyOverlayWindowLevelModeDefaultValue =
    kKayokoOverlayWindowLevelModeCustom;
static CGFloat const kKayokoPreferenceKeyOverlayWindowLevelDefaultValue = 998;
static CGFloat const kKayokoPreferenceKeyOverlayWindowLevelMinimumValue = 10;
static CGFloat const kKayokoPreferenceKeyOverlayWindowLevelMaximumValue = 2000;

static BOOL const kKayokoPreferenceKeyFavoritesFilterPanelVisibleDefaultValue = YES;
static BOOL const kKayokoPreferenceKeyFavoritesFilterShowsCategoriesDefaultValue = YES;
static BOOL const kKayokoPreferenceKeyFavoritesFilterShowsTagsDefaultValue = NO;
static BOOL const kKayokoPreferenceKeyFavoritesFilterShowsAppsDefaultValue = NO;
