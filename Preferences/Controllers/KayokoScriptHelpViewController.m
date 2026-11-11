#import "KayokoScriptHelpViewController.h"
#import "KayokoScripts.h"

static NSString *const KayokoExampleCode = @"function main(text) {\n  return text.match(/[0-9]+/g) || [];\n}";

@implementation KayokoScriptHelpViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = KayokoScriptString(@"Script examples");
    self.tableView.allowsSelection = NO;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 48;

    UILabel *title = [UILabel new];
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle3];
    title.text = KayokoScriptString(@"Example: Extract numbers");
    title.accessibilityTraits |= UIAccessibilityTraitHeader;
    UILabel *note = [UILabel new];
    note.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    note.textColor = UIColor.secondaryLabelColor;
    note.text = KayokoScriptString(@"Find each number in the text and choose one.");
    for (UILabel *label in @[title, note]) {
        label.adjustsFontForContentSizeCategory = YES;
        label.numberOfLines = 0;
    }
    UIStackView *intro = [[UIStackView alloc] initWithArrangedSubviews:@[title, note]];
    intro.axis = UILayoutConstraintAxisVertical;
    intro.spacing = 4;
    intro.layoutMarginsRelativeArrangement = YES;
    intro.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(16, 32, 4, 32);
    self.tableView.tableHeaderView = intro;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIView *intro = self.tableView.tableHeaderView;
    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    CGFloat height = ceil([intro systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
        withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height);
    if (CGRectGetWidth(intro.frame) == width && CGRectGetHeight(intro.frame) == height) return;
    intro.frame = CGRectMake(0, 0, width, height);
    self.tableView.tableHeaderView = intro;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return 3; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return section == 2 ? 2 : 1; }
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section {
    return KayokoScriptString(@[@"Code", @"Input text", @"Results · 2 choices"][section]);
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    if (section != 0) return nil;
    UILabel *label = [UILabel new];
    label.text = KayokoScriptString(@"Code");
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = UIColor.secondaryLabelColor;
    label.accessibilityTraits |= UIAccessibilityTraitHeader;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    [self resetCopyTitle:button];
    button.accessibilityIdentifier = @"kayoko.script.help.copy";
    [button addTarget:self action:@selector(copyExample:) forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [button setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[label, button]];
    header.alignment = UIStackViewAlignmentCenter;
    header.layoutMarginsRelativeArrangement = YES;
    header.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(0, 20, 0, 20);
    return header;
}

- (void)copyExample:(UIButton *)button {
    UIPasteboard.generalPasteboard.string = KayokoExampleCode;
    NSString *copied = KayokoScriptString(@"Copied");
    [button setTitle:copied forState:UIControlStateNormal];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, copied);
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(resetCopyTitle:) object:button];
    [self performSelector:@selector(resetCopyTitle:) withObject:button afterDelay:1.5];
}

- (void)resetCopyTitle:(UIButton *)button {
    [button setTitle:KayokoScriptString(@"Copy code") forState:UIControlStateNormal];
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    UILabel *label = cell.textLabel;
    label.numberOfLines = 0;
    label.adjustsFontForContentSizeCategory = YES;
    if (path.section == 1) {
        label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        label.text = KayokoScriptString(@"Order A-42, backup B-7314");
    } else {
        UIFont *mono = [UIFont monospacedSystemFontOfSize:path.section == 0 ? 14 : 16 weight:UIFontWeightRegular];
        label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:mono];
        if (path.section == 2) {
            label.text = path.row == 0 ? @"42" : @"7314";
        } else {
            NSString *code = KayokoExampleCode;
            NSMutableAttributedString *example = [[NSMutableAttributedString alloc] initWithString:code];
            for (NSString *keyword in @[@"function", @"return"])
                [example addAttribute:NSForegroundColorAttributeName value:UIColor.systemPurpleColor range:[code rangeOfString:keyword]];
            [example addAttribute:NSForegroundColorAttributeName value:UIColor.systemBrownColor range:[code rangeOfString:@"/[0-9]+/g"]];
            label.attributedText = example;
        }
    }
    return cell;
}

@end
