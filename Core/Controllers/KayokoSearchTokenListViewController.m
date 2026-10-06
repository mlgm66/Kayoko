//
//  KayokoSearchTokenListViewController.m
//  Kayoko
//

#import "KayokoSearchTokenListViewController.h"

#import "KayokoApplicationMetadataProvider.h"
#import "KayokoFilterOrderStore.h"
#import "KayokoPreferenceKeys.h"
#import "KayokoPasteboardManager.h"
#import "KayokoSearchCriteria.h"
#import "KayokoSearchTokenCollectionView.h"
#import "KayokoSearchTokenCollectionViewCell.h"
#import "KayokoSearchTokenSectionView.h"
#import "KayokoTagColorFormatter.h"

static CGFloat const kKayokoSearchTokenTopInset = 12;
static CGFloat const kKayokoSearchTokenBottomInset = 20;
static CGFloat const kKayokoSearchTokenSectionSpacing = 16;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchTokenListViewController () <UICollectionViewDataSource, UICollectionViewDelegate>
#pragma mark - Views

@property(nonatomic, strong) KayokoSearchTokenSectionView *categorySectionView;
@property(nonatomic, strong) KayokoSearchTokenSectionView *tagSectionView;
@property(nonatomic, strong) KayokoSearchTokenSectionView *appSectionView;

#pragma mark - Data

@property(nonatomic, copy) NSArray<NSString *> *sectionOrder;
@property(nonatomic, strong) NSArray<KayokoSearchToken *> *categoryTokens;
@property(nonatomic, strong) NSArray<KayokoSearchToken *> *tagTokens;
@property(nonatomic, strong) NSArray<KayokoSearchToken *> *appTokens;
@property(nonatomic, strong) KayokoSearchCriteria *searchCriteria;
@property(nonatomic, strong) KayokoApplicationMetadataProvider *metadataProvider;

#pragma mark - Layout State

@property(nonatomic, assign) CGFloat lastPreferredHeight;
@property(nonatomic, assign) BOOL needsCategoryContentOffsetReset;
@property(nonatomic, assign) BOOL needsTagContentOffsetReset;
@property(nonatomic, assign) BOOL needsAppContentOffsetReset;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoSearchTokenListViewController

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _searchCriteria = [KayokoSearchCriteria emptyCriteria];
        _sectionOrder = KayokoFilterSectionIdentifiers();
        _categoryTokens = [self newCategoryTokensWithIdentifiers:KayokoFilterCategoryIdentifiers()];
        _tagTokens = @[];
        _appTokens = @[];
        _metadataProvider = [[KayokoApplicationMetadataProvider alloc] init];
        _showsCategorySectionEnabled = YES;
        _showsTagSectionEnabled = YES;
        _showsAppSectionEnabled = YES;
        _needsCategoryContentOffsetReset = YES;
        _needsTagContentOffsetReset = YES;
        _needsAppContentOffsetReset = YES;
    }
    return self;
}

#pragma mark - View Setup

- (void)loadView {
    UIView *view = [[UIView alloc] init];
    [view setBackgroundColor:[UIColor clearColor]];
    [self setView:view];

    NSBundle *bundle = [KayokoPasteboardManager localizationBundle];
    _categorySectionView = [[KayokoSearchTokenSectionView alloc]
        initWithTitle:[bundle localizedStringForKey:@"Categories" value:nil table:@"Tweak"]];
    _tagSectionView = [[KayokoSearchTokenSectionView alloc] initWithTitle:[bundle localizedStringForKey:@"Tags"
                                                                                                  value:nil
                                                                                                  table:@"Tweak"]];
    _appSectionView = [[KayokoSearchTokenSectionView alloc] initWithTitle:[bundle localizedStringForKey:@"Applications"
                                                                                                  value:nil
                                                                                                  table:@"Tweak"]];
    [view addSubview:_categorySectionView];
    [view addSubview:_tagSectionView];
    [view addSubview:_appSectionView];

    [self configureCollectionView:[_categorySectionView collectionView]];
    [self configureCollectionView:[_tagSectionView collectionView]];
    [self configureCollectionView:[_appSectionView collectionView]];
}

- (void)configureCollectionView:(UICollectionView *)collectionView {
    [collectionView setDataSource:self];
    [collectionView setDelegate:self];
    [collectionView registerClass:[KayokoSearchTokenCollectionViewCell class]
        forCellWithReuseIdentifier:[KayokoSearchTokenCollectionViewCell reuseIdentifier]];
}

#pragma mark - Token Sources

- (NSArray<KayokoSearchToken *> *)newCategoryTokensWithIdentifiers:(NSArray<NSString *> *)identifiers {
    NSBundle *bundle = [KayokoPasteboardManager localizationBundle];
    NSMutableArray *tokens = [NSMutableArray array];
    for (NSString *identifier in identifiers) {
        NSDictionary *metadata = KayokoFilterCategoryMetadata(identifier);
        [tokens addObject:[KayokoSearchToken tokenWithType:kKayokoSearchTokenTypeCategory
                                                     value:identifier
                                                     title:[bundle localizedStringForKey:metadata[@"title"] value:nil table:@"Tweak"]
                                                 imageName:metadata[@"image"]]];
    }
    return tokens;
}

- (void)applyFilterOrder:(KayokoFilterOrderStore *)orderStore {
    NSArray *sectionOrder = [orderStore orderedIdentifiers:KayokoFilterSectionIdentifiers()
                                                  forKey:kKayokoPreferenceKeyFilterSectionOrder];
    NSArray *categoryIdentifiers = [orderStore orderedIdentifiers:KayokoFilterCategoryIdentifiers()
                                                         forKey:kKayokoPreferenceKeyFilterCategoryOrder];
    NSArray *categoryTokens = [self newCategoryTokensWithIdentifiers:categoryIdentifiers];
    BOOL sectionsChanged = ![[self sectionOrder] isEqualToArray:sectionOrder];
    BOOL categoriesChanged = ![self tokenArray:[self categoryTokens] isDisplayEqualToTokenArray:categoryTokens];
    [self setSectionOrder:sectionOrder];
    [self setCategoryTokens:categoryTokens];
    if (![self isViewLoaded]) {
        return;
    }
    if (categoriesChanged) {
        [self setNeedsCategoryContentOffsetReset:YES];
        [[[self categorySectionView] collectionView] reloadData];
    }
    if (sectionsChanged || categoriesChanged) {
        [[self view] setNeedsLayout];
        [self notifyContentHeightIfNeeded];
    }
}

#pragma mark - State

- (BOOL)showsCategorySection {
    return [self showsCategorySectionEnabled] &&
           ([self keepsSelectedSectionsVisible] || ![[self searchCriteria] hasCategoryToken]);
}

- (BOOL)showsAppSection {
    return [self showsAppSectionEnabled] &&
           ([self keepsSelectedSectionsVisible] || ![[self searchCriteria] hasAppToken]) &&
           [[self appTokens] count] > 0;
}

- (BOOL)showsTagSection {
    return [self showsTagSectionEnabled] &&
           ([self keepsSelectedSectionsVisible] || ![[self searchCriteria] hasTagToken]) &&
           [[self tagTokens] count] > 0;
}

- (void)setShowsCategorySectionEnabled:(BOOL)showsCategorySectionEnabled {
    if (_showsCategorySectionEnabled == showsCategorySectionEnabled) {
        return;
    }
    _showsCategorySectionEnabled = showsCategorySectionEnabled;
    [self updateSectionVisibility];
    [[self view] setNeedsLayout];
    [self notifyContentHeightIfNeeded];
}

- (void)setShowsTagSectionEnabled:(BOOL)showsTagSectionEnabled {
    if (_showsTagSectionEnabled == showsTagSectionEnabled) {
        return;
    }
    _showsTagSectionEnabled = showsTagSectionEnabled;
    [self updateSectionVisibility];
    [[self view] setNeedsLayout];
    [self notifyContentHeightIfNeeded];
}

- (void)setShowsAppSectionEnabled:(BOOL)showsAppSectionEnabled {
    if (_showsAppSectionEnabled == showsAppSectionEnabled) {
        return;
    }
    _showsAppSectionEnabled = showsAppSectionEnabled;
    [self updateSectionVisibility];
    [[self view] setNeedsLayout];
    [self notifyContentHeightIfNeeded];
}

- (BOOL)tokenArray:(NSArray<KayokoSearchToken *> *)left
    isDisplayEqualToTokenArray:(NSArray<KayokoSearchToken *> *)right {
    if ([left count] != [right count]) {
        return NO;
    }

    for (NSUInteger index = 0; index < [left count]; index++) {
        if (![left[index] isDisplayEqualToToken:right[index]]) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)searchCriteria:(KayokoSearchCriteria *)left
    hasSameSelectedTokensAsSearchCriteria:(KayokoSearchCriteria *)right {
    return [([left categoryValue] ?: @"") isEqualToString:([right categoryValue] ?: @"")] &&
           [([left tagUUID] ?: @"") isEqualToString:([right tagUUID] ?: @"")] &&
           [([left appBundleIdentifier] ?: @"") isEqualToString:([right appBundleIdentifier] ?: @"")];
}

- (void)updateWithSearchCriteria:(KayokoSearchCriteria *)searchCriteria
                       tagTokens:(NSArray<KayokoSearchToken *> *)tagTokens
                       appTokens:(NSArray<KayokoSearchToken *> *)appTokens {
    KayokoSearchCriteria *newSearchCriteria = searchCriteria ?: [KayokoSearchCriteria emptyCriteria];
    NSArray<KayokoSearchToken *> *newTagTokens = tagTokens ?: @[];
    NSArray<KayokoSearchToken *> *newAppTokens = appTokens ?: @[];

    BOOL oldShowsCategory = [self showsCategorySection];
    BOOL oldShowsTag = [self showsTagSection];
    BOOL oldShowsApp = [self showsAppSection];
    BOOL oldTagUsesHorizontalLayout = [self usesHorizontalScrollingLayoutForTagSection];
    BOOL oldAppUsesHorizontalLayout = [self usesHorizontalScrollingLayoutForAppSection];

    BOOL selectedTokensChanged = ![self searchCriteria:[self searchCriteria]
                 hasSameSelectedTokensAsSearchCriteria:newSearchCriteria];
    BOOL tagTokensChanged = ![self tokenArray:[self tagTokens] isDisplayEqualToTokenArray:newTagTokens];
    BOOL appTokensChanged = ![self tokenArray:[self appTokens] isDisplayEqualToTokenArray:newAppTokens];

    [self setSearchCriteria:newSearchCriteria];
    if (tagTokensChanged) {
        [self setTagTokens:newTagTokens];
    }
    if (appTokensChanged) {
        [self setAppTokens:newAppTokens];
    }

    CGFloat width = CGRectGetWidth([[self view] bounds]);
    BOOL tagLayoutChanged = oldTagUsesHorizontalLayout != [self usesHorizontalScrollingLayoutForTagSection];
    BOOL appLayoutChanged = oldAppUsesHorizontalLayout != [self usesHorizontalScrollingLayoutForAppSection];
    if (tagTokensChanged || tagLayoutChanged) {
        [self setNeedsTagContentOffsetReset:YES];
        [self configureTagSectionForWidth:width];
        [[[self tagSectionView] collectionView] reloadData];
    }
    if (appTokensChanged || appLayoutChanged) {
        [self setNeedsAppContentOffsetReset:YES];
        [self configureAppSectionForWidth:width];
        [[[self appSectionView] collectionView] reloadData];
    }

    if (selectedTokensChanged) {
        if (!tagTokensChanged && !tagLayoutChanged) {
            [[[self tagSectionView] collectionView] reloadData];
        }
        if (!appTokensChanged && !appLayoutChanged) {
            [[[self appSectionView] collectionView] reloadData];
        }
        [[[self categorySectionView] collectionView] reloadData];
    }

    [self updateSectionVisibility];

    BOOL visibilityChanged = oldShowsCategory != [self showsCategorySection] || oldShowsTag != [self showsTagSection] ||
                             oldShowsApp != [self showsAppSection];
    if (selectedTokensChanged || tagTokensChanged || appTokensChanged || tagLayoutChanged || appLayoutChanged ||
        visibilityChanged) {
        [[self view] setNeedsLayout];
        [self notifyContentHeightIfNeeded];
    }
}

- (void)resetCollectionViewSessionState:(KayokoSearchTokenCollectionView *)collectionView {
    for (NSIndexPath *indexPath in [collectionView indexPathsForSelectedItems]) {
        [collectionView deselectItemAtIndexPath:indexPath animated:NO];
    }
    [collectionView resetContentOffsetToLeadingEdge];
}

- (void)resetSearchSessionState {
    [self setSearchCriteria:[KayokoSearchCriteria emptyCriteria]];
    [self setLastPreferredHeight:0];
    [self setNeedsCategoryContentOffsetReset:YES];
    [self setNeedsTagContentOffsetReset:YES];
    [self setNeedsAppContentOffsetReset:YES];
    if (![self isViewLoaded]) {
        return;
    }

    [self updateSectionVisibility];
    [self resetCollectionViewSessionState:[[self categorySectionView] collectionView]];
    [self resetCollectionViewSessionState:[[self tagSectionView] collectionView]];
    [self resetCollectionViewSessionState:[[self appSectionView] collectionView]];
    [[self view] setNeedsLayout];
}

#pragma mark - Layout

- (void)updateSectionVisibility {
    BOOL showsCategory = [self showsCategorySection];
    BOOL showsTag = [self showsTagSection];
    BOOL showsApp = [self showsAppSection];
    [[self categorySectionView] setHidden:!showsCategory];
    [[self tagSectionView] setHidden:!showsTag];
    [[self appSectionView] setHidden:!showsApp];
}

- (BOOL)usesHorizontalScrollingLayoutForAppSection {
    return YES;
}

- (BOOL)usesHorizontalScrollingLayoutForTagSection {
    return YES;
}

- (void)configureTagSectionForWidth:(CGFloat)width {
    BOOL usesHorizontalScrollingLayout = [self usesHorizontalScrollingLayoutForTagSection];
    NSUInteger numberOfRows = [KayokoSearchTokenSectionView numberOfRowsForItemCount:[[self tagTokens] count]
                                                                               width:width
                                                           horizontalScrollingLayout:usesHorizontalScrollingLayout];
    [[self tagSectionView] setHorizontalScrollingLayout:usesHorizontalScrollingLayout];
    if (numberOfRows > 0) {
        [[self tagSectionView] setNumberOfRows:numberOfRows];
    }
}

- (void)configureAppSectionForWidth:(CGFloat)width {
    BOOL usesHorizontalScrollingLayout = [self usesHorizontalScrollingLayoutForAppSection];
    NSUInteger numberOfRows = [KayokoSearchTokenSectionView numberOfRowsForItemCount:[[self appTokens] count]
                                                                               width:width
                                                           horizontalScrollingLayout:usesHorizontalScrollingLayout];
    [[self appSectionView] setHorizontalScrollingLayout:usesHorizontalScrollingLayout];
    if (numberOfRows > 0) {
        [[self appSectionView] setNumberOfRows:numberOfRows];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutSectionsForWidth:CGRectGetWidth([[self view] bounds])];
    [self resetPendingCollectionViewContentOffsetsIfNeeded];
    [self updateVisibleEdgeFadeMasks];
    [self notifyContentHeightIfNeeded];
}

- (NSArray<NSString *> *)orderedVisibleSectionIdentifiers {
    NSMutableArray *sections = [NSMutableArray array];
    for (NSString *identifier in [self sectionOrder]) {
        if ([identifier isEqualToString:kKayokoSearchTokenTypeCategory] && [self showsCategorySection]) {
            [sections addObject:identifier];
        } else if ([identifier isEqualToString:kKayokoSearchTokenTypeTag] && [self showsTagSection]) {
            [sections addObject:identifier];
        } else if ([identifier isEqualToString:kKayokoSearchTokenTypeApp] && [self showsAppSection]) {
            [sections addObject:identifier];
        }
    }
    return sections;
}

- (CGFloat)heightForSectionIdentifier:(NSString *)identifier width:(CGFloat)width {
    if ([identifier isEqualToString:kKayokoSearchTokenTypeCategory]) {
        return [KayokoSearchTokenSectionView preferredHeight];
    }
    BOOL tagSection = [identifier isEqualToString:kKayokoSearchTokenTypeTag];
    NSUInteger count = tagSection ? [[self tagTokens] count] : [[self appTokens] count];
    BOOL horizontal = tagSection ? [self usesHorizontalScrollingLayoutForTagSection] :
                                  [self usesHorizontalScrollingLayoutForAppSection];
    return [KayokoSearchTokenSectionView preferredHeightForItemCount:count width:width horizontalScrollingLayout:horizontal];
}

- (CGFloat)preferredContentHeightForWidth:(CGFloat)width {
    NSArray *sections = [self orderedVisibleSectionIdentifiers];
    if ([sections count] == 0) {
        return 0;
    }
    CGFloat height = kKayokoSearchTokenTopInset + kKayokoSearchTokenBottomInset +
                     ([sections count] - 1) * kKayokoSearchTokenSectionSpacing;
    for (NSString *identifier in sections) {
        height += [self heightForSectionIdentifier:identifier width:width];
    }
    return height;
}

- (void)layoutSectionsForWidth:(CGFloat)width {
    [self configureTagSectionForWidth:width];
    [self configureAppSectionForWidth:width];
    CGFloat y = kKayokoSearchTokenTopInset;
    for (NSString *identifier in [self orderedVisibleSectionIdentifiers]) {
        KayokoSearchTokenSectionView *section = [identifier isEqualToString:kKayokoSearchTokenTypeCategory] ?
            [self categorySectionView] : [identifier isEqualToString:kKayokoSearchTokenTypeTag] ?
            [self tagSectionView] : [self appSectionView];
        CGFloat height = [self heightForSectionIdentifier:identifier width:width];
        [section setFrame:CGRectMake(0, y, width, height)];
        [section layoutIfNeeded];
        y += height + kKayokoSearchTokenSectionSpacing;
    }
}

- (void)updateVisibleEdgeFadeMasks {
    if (![[self categorySectionView] isHidden]) {
        [[[self categorySectionView] collectionView] updateEdgeFadeMask];
    }
    if (![[self tagSectionView] isHidden]) {
        [[[self tagSectionView] collectionView] updateEdgeFadeMask];
    }
    if (![[self appSectionView] isHidden]) {
        [[[self appSectionView] collectionView] updateEdgeFadeMask];
    }
}

- (void)resetPendingCollectionViewContentOffsetsIfNeeded {
    if ([self needsCategoryContentOffsetReset] && ![[self categorySectionView] isHidden]) {
        [[[self categorySectionView] collectionView] resetContentOffsetToLeadingEdge];
        [self setNeedsCategoryContentOffsetReset:NO];
    }
    if ([self needsTagContentOffsetReset] && ![[self tagSectionView] isHidden]) {
        [[[self tagSectionView] collectionView] resetContentOffsetToLeadingEdge];
        [self setNeedsTagContentOffsetReset:NO];
    }
    if ([self needsAppContentOffsetReset] && ![[self appSectionView] isHidden]) {
        [[[self appSectionView] collectionView] resetContentOffsetToLeadingEdge];
        [self setNeedsAppContentOffsetReset:NO];
    }
}

- (void)notifyContentHeightIfNeeded {
    CGFloat preferredHeight = [self preferredContentHeightForWidth:CGRectGetWidth([[self view] bounds])];
    if (fabs(preferredHeight - [self lastPreferredHeight]) < 0.5) {
        return;
    }
    [self setLastPreferredHeight:preferredHeight];
    if ([self contentHeightDidChange]) {
        [self contentHeightDidChange]();
    }
}

#pragma mark - UICollectionViewDataSource

- (NSArray<KayokoSearchToken *> *)tokensForCollectionView:(UICollectionView *)collectionView {
    if (collectionView == [[self appSectionView] collectionView]) {
        return [self appTokens];
    }
    if (collectionView == [[self tagSectionView] collectionView]) {
        return [self tagTokens];
    }
    return [self categoryTokens];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    (void)section;
    return (NSInteger)[[self tokensForCollectionView:collectionView] count];
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    KayokoSearchTokenCollectionViewCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:[KayokoSearchTokenCollectionViewCell reuseIdentifier]
                                                  forIndexPath:indexPath];
    KayokoSearchToken *token = [self tokensForCollectionView:collectionView][(NSUInteger)[indexPath item]];
    UIImage *icon = nil;
    UIColor *dotColor = nil;
    UIColor *dotBorderColor = nil;
    if ([[token type] isEqualToString:kKayokoSearchTokenTypeApp]) {
        icon = [[self metadataProvider] smallIconForBundleIdentifier:[token value]];
    } else if ([[token type] isEqualToString:kKayokoSearchTokenTypeTag]) {
        dotColor = [KayokoTagColorFormatter visibleColorFromHexColor:[token displaySignature]];
        dotBorderColor = [KayokoTagColorFormatter borderColorFromHexColor:[token displaySignature]];
    } else if ([[token imageName] length] > 0) {
        icon = [UIImage systemImageNamed:[token imageName]];
    }
    [cell configureWithTitle:[token title] icon:icon dotColor:dotColor dotBorderColor:dotBorderColor];
    [cell setActiveFilterHighlighted:[self tokenIsActiveInCriteria:token]];
    return cell;
}

- (BOOL)tokenIsActiveInCriteria:(KayokoSearchToken *)token {
    NSString *type = [token type];
    if ([type isEqualToString:kKayokoSearchTokenTypeCategory]) {
        return [[token value] isEqualToString:([[self searchCriteria] categoryValue] ?: @"")];
    }
    if ([type isEqualToString:kKayokoSearchTokenTypeTag]) {
        return [[token value] isEqualToString:([[self searchCriteria] tagUUID] ?: @"")];
    }
    if ([type isEqualToString:kKayokoSearchTokenTypeApp]) {
        return [[token value] isEqualToString:([[self searchCriteria] appBundleIdentifier] ?: @"")];
    }
    return NO;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<KayokoSearchToken *> *tokens = [self tokensForCollectionView:collectionView];
    if ((NSUInteger)[indexPath item] >= [tokens count]) {
        return;
    }
    [[self delegate] searchTokenListViewController:self didSelectToken:tokens[(NSUInteger)[indexPath item]]];
}

@end
