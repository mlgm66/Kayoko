//
//  KayokoHeaderView.m
//  Kayoko
//

#import "KayokoHeaderView.h"

#import "KayokoGrabberView.h"
#import "KayokoHeaderButtonStyle.h"
#import "KayokoPasteboardManager.h"

static CGFloat const kKayokoHeaderHeight = 76;
static CGFloat const kKayokoTitleTapControlHeight = 44;
static CGFloat const kKayokoTitleTapControlTrailingSpacing = 8;
static CGFloat const kKayokoHistorySegmentWidth = 146;
static CGFloat const kKayokoHistorySegmentHeight = 28;
static CGFloat const kKayokoGrabberTopInset = 8;
static CGFloat const kKayokoSegmentBottomInset = 10;

@interface KayokoHeaderView ()

@property(nonatomic, strong, readwrite) KayokoGrabberView *grabber;
@property(nonatomic, strong, readwrite) UILabel *titleLabel;
@property(nonatomic, strong, readwrite) UIControl *titleTapControl;
@property(nonatomic, strong, readwrite) UIButton *leadingButton;
@property(nonatomic, strong, readwrite) UIButton *editButton;
@property(nonatomic, strong) UIStackView *trailingButtonStack;
@property(nonatomic, copy) NSArray<NSLayoutConstraint *> *trailingButtonWidthConstraints;
@property(nonatomic, strong, readwrite) UIButton *trailingButton;
@property(nonatomic, strong, readwrite) UIButton *alternateTrailingButton;
@property(nonatomic, strong, readwrite) UIButton *openLinkButton;
@property(nonatomic, strong, readwrite) UIButton *selectionActionButton;
@property(nonatomic, strong, readwrite) UIButton *translationButton;
@property(nonatomic, strong, readwrite) UIButton *bookButton;
@property(nonatomic, strong, readwrite) UIButton *shareButton;
@property(nonatomic, strong, readwrite) UISegmentedControl *historySegmentedControl;

@end

@implementation KayokoHeaderView

+ (CGFloat)preferredHeight {
    return kKayokoHeaderHeight;
}

- (instancetype)initWithTitle:(NSString *)title {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        [self setClipsToBounds:YES];
        [self setBackgroundColor:[UIColor clearColor]];
        [self setOpaque:NO];
        _historySwitcherVisible = YES;

        _grabber = [[KayokoGrabberView alloc] init];
        [self addSubview:_grabber];
        [_grabber setTranslatesAutoresizingMaskIntoConstraints:NO];

        _leadingButton = [[UIButton alloc] init];
        [self addSubview:_leadingButton];
        [_leadingButton setTranslatesAutoresizingMaskIntoConstraints:NO];

        _titleLabel = [[UILabel alloc] init];
        [_titleLabel setFont:[UIFont systemFontOfSize:26 weight:UIFontWeightSemibold]];
        [_titleLabel setTextColor:[UIColor labelColor]];
        [_titleLabel setNumberOfLines:1];
        [_titleLabel setLineBreakMode:NSLineBreakByTruncatingTail];
        [self addSubview:_titleLabel];
        [_titleLabel setTranslatesAutoresizingMaskIntoConstraints:NO];

        NSBundle *bundle = [KayokoPasteboardManager localizationBundle];
        NSString *clipboardTitle = [bundle localizedStringForKey:@"Clipboard" value:@"剪贴板" table:@"Tweak"];
        NSString *favoritesTitle = [bundle localizedStringForKey:@"Favorites" value:@"收藏夹" table:@"Tweak"];
        if ([clipboardTitle isEqualToString:@"Clipboard"]) {
            clipboardTitle = @"剪贴板";
        }
        if ([favoritesTitle isEqualToString:@"Favorites"]) {
            favoritesTitle = @"收藏夹";
        }

        _historySegmentedControl = [[UISegmentedControl alloc] initWithItems:@[ clipboardTitle, favoritesTitle ]];
        [_historySegmentedControl setSelectedSegmentIndex:0];
        [_historySegmentedControl setBackgroundColor:[UIColor colorWithWhite:0.55 alpha:0.22]];
        if (@available(iOS 13.0, *)) {
            [_historySegmentedControl setSelectedSegmentTintColor:[UIColor colorWithWhite:1.0 alpha:1.0]];
        }
        UIFont *normalFont = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
        UIFont *selectedFont = [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
        [_historySegmentedControl setTitleTextAttributes:@{
            NSForegroundColorAttributeName : [UIColor colorWithWhite:0.20 alpha:0.72],
            NSFontAttributeName : normalFont
        }
                                               forState:UIControlStateNormal];
        [_historySegmentedControl setTitleTextAttributes:@{
            NSForegroundColorAttributeName : [UIColor colorWithWhite:0.08 alpha:1.0],
            NSFontAttributeName : selectedFont
        }
                                         forState:UIControlStateSelected];
        [_historySegmentedControl setDividerImage:[[UIImage alloc] init]
                              forLeftSegmentState:UIControlStateNormal
                                rightSegmentState:UIControlStateNormal
                                       barMetrics:UIBarMetricsDefault];
        [self addSubview:_historySegmentedControl];
        [_historySegmentedControl setTranslatesAutoresizingMaskIntoConstraints:NO];

        _trailingButtonStack = [[UIStackView alloc] init];
        [_trailingButtonStack setAxis:UILayoutConstraintAxisHorizontal];
        [_trailingButtonStack setAlignment:UIStackViewAlignmentCenter];
        [_trailingButtonStack setDistribution:UIStackViewDistributionFill];
        [_trailingButtonStack setSpacing:12];
        [self addSubview:_trailingButtonStack];
        [_trailingButtonStack setTranslatesAutoresizingMaskIntoConstraints:NO];

        _selectionActionButton = [[UIButton alloc] init];
        [_selectionActionButton setHidden:YES];
        [_trailingButtonStack addArrangedSubview:_selectionActionButton];
        [_selectionActionButton setTranslatesAutoresizingMaskIntoConstraints:NO];

        _editButton = [[UIButton alloc] init];
        [_editButton setHidden:YES];
        [_trailingButtonStack addArrangedSubview:_editButton];
        [_editButton setTranslatesAutoresizingMaskIntoConstraints:NO];

        _alternateTrailingButton = [[UIButton alloc] init];
        [_alternateTrailingButton setHidden:YES];
        [_trailingButtonStack addArrangedSubview:_alternateTrailingButton];
        [_alternateTrailingButton setTranslatesAutoresizingMaskIntoConstraints:NO];

        _translationButton = [[UIButton alloc] init];
        [_translationButton setHidden:YES];
        [_trailingButtonStack addArrangedSubview:_translationButton];
        [_translationButton setTranslatesAutoresizingMaskIntoConstraints:NO];

        _bookButton = [[UIButton alloc] init];
        [_bookButton setHidden:YES];
        [_trailingButtonStack addArrangedSubview:_bookButton];
        [_bookButton setTranslatesAutoresizingMaskIntoConstraints:NO];

        _shareButton = [[UIButton alloc] init];
        [_shareButton setHidden:YES];
        [_trailingButtonStack addArrangedSubview:_shareButton];
        [_shareButton setTranslatesAutoresizingMaskIntoConstraints:NO];

        _openLinkButton = [[UIButton alloc] init];
        [_openLinkButton setHidden:YES];
        [_trailingButtonStack addArrangedSubview:_openLinkButton];
        [_openLinkButton setTranslatesAutoresizingMaskIntoConstraints:NO];

        _trailingButton = [[UIButton alloc] init];
        [_trailingButtonStack addArrangedSubview:_trailingButton];
        [_trailingButton setTranslatesAutoresizingMaskIntoConstraints:NO];

        NSMutableArray<NSLayoutConstraint *> *buttonWidthConstraints = [[NSMutableArray alloc] init];
        for (UIView *button in [_trailingButtonStack arrangedSubviews]) {
            NSLayoutConstraint *widthConstraint = [[button widthAnchor] constraintEqualToConstant:32];
            [widthConstraint setPriority:UILayoutPriorityRequired - 1];
            [buttonWidthConstraints addObject:widthConstraint];
            [[[button heightAnchor] constraintEqualToConstant:32] setActive:YES];
        }
        _trailingButtonWidthConstraints = [buttonWidthConstraints copy];
        [NSLayoutConstraint activateConstraints:_trailingButtonWidthConstraints];

        _titleTapControl = [[UIControl alloc] init];
        [_titleTapControl setBackgroundColor:[UIColor clearColor]];
        [_titleTapControl setAccessibilityTraits:[_titleTapControl accessibilityTraits] | UIAccessibilityTraitButton];
        [self addSubview:_titleTapControl];
        [_titleTapControl setTranslatesAutoresizingMaskIntoConstraints:NO];

        [NSLayoutConstraint activateConstraints:@[
            [[_grabber topAnchor] constraintEqualToAnchor:[self topAnchor] constant:kKayokoGrabberTopInset],
            [[_grabber centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
            [[_grabber widthAnchor] constraintEqualToConstant:42],
            [[_grabber heightAnchor] constraintEqualToConstant:14],

            [[_leadingButton bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]
                                                          constant:-kKayokoSegmentBottomInset],
            [[_leadingButton centerXAnchor] constraintEqualToAnchor:[self leadingAnchor]
                                                           constant:kKayokoLeadingHeaderButtonCenterXInset],
            [[_leadingButton topAnchor] constraintGreaterThanOrEqualToAnchor:[_grabber bottomAnchor] constant:8],

            [[_titleLabel centerYAnchor] constraintEqualToAnchor:[_leadingButton centerYAnchor]],
            [[_titleLabel leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]
                                                        constant:kKayokoTitleLabelLeadingInset],

            [[_historySegmentedControl centerYAnchor] constraintEqualToAnchor:[_leadingButton centerYAnchor]],
            [[_historySegmentedControl centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
            [[_historySegmentedControl widthAnchor] constraintEqualToConstant:kKayokoHistorySegmentWidth],
            [[_historySegmentedControl heightAnchor] constraintEqualToConstant:kKayokoHistorySegmentHeight],

            [[_trailingButtonStack centerYAnchor] constraintEqualToAnchor:[_leadingButton centerYAnchor]],
            [[_trailingButtonStack trailingAnchor] constraintEqualToAnchor:[self trailingAnchor] constant:-16],
            [[_trailingButtonStack heightAnchor] constraintEqualToConstant:32],
            [[_titleLabel trailingAnchor] constraintLessThanOrEqualToAnchor:[_trailingButtonStack leadingAnchor]
                                                                      constant:-kKayokoTitleTapControlTrailingSpacing],
            [[_titleTapControl leadingAnchor] constraintEqualToAnchor:[_titleLabel leadingAnchor]],
            [[_titleTapControl trailingAnchor] constraintEqualToAnchor:[_trailingButtonStack leadingAnchor]
                                                              constant:-kKayokoTitleTapControlTrailingSpacing],
            [[_titleTapControl centerYAnchor] constraintEqualToAnchor:[_titleLabel centerYAnchor]],
            [[_titleTapControl heightAnchor] constraintEqualToConstant:kKayokoTitleTapControlHeight]
        ]];

        [self setTitleText:title];
        [self setHistorySwitcherVisible:YES animated:NO];
    }
    return self;
}

- (void)layoutSubviews {
    NSUInteger visibleCount = 0;
    for (UIView *button in [[self trailingButtonStack] arrangedSubviews]) {
        if (![button isHidden]) visibleCount++;
    }
    CGFloat availableWidth = CGRectGetWidth([self bounds]) - 16 - kKayokoTitleLabelLeadingInset -
                             kKayokoTitleTapControlTrailingSpacing;
    CGFloat buttonWidth = visibleCount > 0 ? MIN(32, MAX(0, availableWidth) / visibleCount) : 32;
    for (NSLayoutConstraint *constraint in [self trailingButtonWidthConstraints]) {
        [constraint setConstant:buttonWidth];
    }
    CGFloat spacing = visibleCount > 1 ?
        MAX(0, MIN(12, (availableWidth - visibleCount * buttonWidth) / (visibleCount - 1))) : 12;
    [[self trailingButtonStack] setSpacing:spacing];
    [super layoutSubviews];
}

- (void)setTitleText:(NSString *)title {
    [[self titleLabel] setText:title];
    [[self titleTapControl] setAccessibilityLabel:title];
}

- (void)setHistorySwitcherVisible:(BOOL)historySwitcherVisible {
    [self setHistorySwitcherVisible:historySwitcherVisible animated:NO];
}

- (void)setHistorySwitcherVisible:(BOOL)historySwitcherVisible animated:(BOOL)animated {
    _historySwitcherVisible = historySwitcherVisible;
    void (^updates)(void) = ^{
      [[self historySegmentedControl] setAlpha:historySwitcherVisible ? 1.0 : 0.0];
      [[self historySegmentedControl] setHidden:!historySwitcherVisible];
      [[self titleLabel] setAlpha:historySwitcherVisible ? 0.0 : 1.0];
      [[self titleLabel] setHidden:historySwitcherVisible];
      [[self titleTapControl] setHidden:historySwitcherVisible];
      [[self titleTapControl] setUserInteractionEnabled:!historySwitcherVisible];
    };
    if (animated) {
        [UIView animateWithDuration:0.18 animations:updates];
    } else {
        updates();
    }
}

- (void)setSelectedHistorySegmentIndex:(NSInteger)index {
    if (index < 0 || index >= [[self historySegmentedControl] numberOfSegments]) {
        return;
    }
    [[self historySegmentedControl] setSelectedSegmentIndex:index];
}

- (void)updateStyleForButton:(UIButton *)button
               withImageName:(NSString *)imageName
                   imageSize:(NSUInteger)imageSize
                   tintColor:(UIColor *)color {
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:imageSize weight:UIImageSymbolWeightMedium];
    UIImage *image = [UIImage systemImageNamed:imageName] ?: [UIImage systemImageNamed:@"doc.on.doc"];
    [button setImage:[image imageWithConfiguration:configuration] forState:UIControlStateNormal];
    [button setTintColor:color];
}

@end
