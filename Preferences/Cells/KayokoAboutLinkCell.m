#import "KayokoAboutLinkCell.h"
#import <Preferences/PSSpecifier.h>

@interface KayokoAboutLinkCell ()
@property(nonatomic, strong) NSURL *destinationURL;
@end

@implementation KayokoAboutLinkCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (!self) {
        return nil;
    }

    _destinationURL = [NSURL URLWithString:[specifier propertyForKey:@"url"]];
    BOOL developer = [[specifier propertyForKey:@"id"] isEqualToString:@"AboutDeveloper"];
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    UILabel *label = [[UILabel alloc] init];
    [label setText:[bundle localizedStringForKey:[specifier propertyForKey:@"label"] value:nil table:@"Root"]];
    [label setTextColor:[UIColor labelColor]];
    [label setFont:developer ? [UIFont preferredFontForTextStyle:UIFontTextStyleBody] :
        [UIFont systemFontOfSize:15 weight:UIFontWeightMedium]];
    [label setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[self contentView] addSubview:label];
    [[self textLabel] setHidden:YES];
    [[self detailTextLabel] setHidden:YES];
    [self setAccessoryType:UITableViewCellAccessoryNone];
    [self setSelectionStyle:UITableViewCellSelectionStyleNone];
    [[self contentView] setPreservesSuperviewLayoutMargins:YES];

    UIButton *link = [UIButton buttonWithType:UIButtonTypeSystem];
    [link setTranslatesAutoresizingMaskIntoConstraints:NO];
    [link setTintColor:[UIColor systemBlueColor]];
    [link setAccessibilityTraits:UIAccessibilityTraitLink];
    [link addTarget:self action:@selector(openURL) forControlEvents:UIControlEventTouchUpInside];
    UILayoutGuide *margins = [[self contentView] layoutMarginsGuide];
    [NSLayoutConstraint activateConstraints:@[
        [[label leadingAnchor] constraintEqualToAnchor:[margins leadingAnchor]],
        [[label centerYAnchor] constraintEqualToAnchor:[[self contentView] centerYAnchor]]
    ]];

    if (developer) {
        [link setTitle:@"mlgm" forState:UIControlStateNormal];
        [link setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
        [[link titleLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleBody]];
        [link setContentHorizontalAlignment:UIControlContentHorizontalAlignmentRight];
        [[self contentView] addSubview:link];
        [NSLayoutConstraint activateConstraints:@[
            [[link trailingAnchor] constraintEqualToAnchor:[margins trailingAnchor]],
            [[link centerYAnchor] constraintEqualToAnchor:[[self contentView] centerYAnchor]],
            [[link heightAnchor] constraintEqualToAnchor:[[self contentView] heightAnchor]],
            [[label trailingAnchor] constraintLessThanOrEqualToAnchor:[link leadingAnchor] constant:-16]
        ]];
        [self setAccessibilityElements:@[label, link]];
    } else {
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:20];
        UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"safari"
            withConfiguration:configuration]];
        [icon setTintColor:[UIColor systemBlueColor]];
        [icon setContentMode:UIViewContentModeScaleAspectFit];
        [icon setTranslatesAutoresizingMaskIntoConstraints:NO];
        [[self contentView] addSubview:icon];
        [NSLayoutConstraint activateConstraints:@[
            [[icon trailingAnchor] constraintEqualToAnchor:[margins trailingAnchor]],
            [[icon centerYAnchor] constraintEqualToAnchor:[[self contentView] centerYAnchor]],
            [[icon widthAnchor] constraintEqualToConstant:20],
            [[icon heightAnchor] constraintEqualToConstant:20],
            [[label trailingAnchor] constraintLessThanOrEqualToAnchor:[icon leadingAnchor] constant:-16]
        ]];
        [link setAccessibilityLabel:[label text]];
        [[self contentView] addSubview:link];
        [NSLayoutConstraint activateConstraints:@[
            [[link topAnchor] constraintEqualToAnchor:[[self contentView] topAnchor]],
            [[link bottomAnchor] constraintEqualToAnchor:[[self contentView] bottomAnchor]],
            [[link leadingAnchor] constraintEqualToAnchor:[[self contentView] leadingAnchor]],
            [[link trailingAnchor] constraintEqualToAnchor:[[self contentView] trailingAnchor]]
        ]];
        [self setAccessibilityElements:@[link]];
    }
    return self;
}

- (void)openURL {
    [[UIApplication sharedApplication] openURL:[self destinationURL] options:@{} completionHandler:nil];
}

@end
