#import "KayokoScriptEditorViewController.h"
#import "KayokoKeyboardAvoidanceCoordinator.h"
#import "KayokoScriptCodeView.h"
#import "KayokoScripts.h"

@interface KayokoScriptNameCell : UITableViewCell
@end

@implementation KayokoScriptNameCell
- (void)layoutSubviews {
    UITextField *field = (UITextField *)self.accessoryView;
    UIFont *font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody compatibleWithTraitCollection:self.traitCollection];
    CGFloat labelWidth = [KayokoScriptString(@"Name") sizeWithAttributes:@{NSFontAttributeName:font}].width;
    CGFloat room = self.bounds.size.width - self.layoutMargins.left - self.layoutMargins.right - ceil(labelWidth) - 12;
    CGFloat width = MAX(0, MIN(self.bounds.size.width * 0.62, room));
    field.bounds = CGRectMake(0, 0, floor(width), MAX(36, ceil(font.lineHeight) + 4));
    [super layoutSubviews];
}
@end

@interface KayokoScriptEditorViewController () <UITextFieldDelegate, UITextViewDelegate, UIAdaptivePresentationControllerDelegate, UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, strong) UITextField *nameField;
@property(nonatomic, strong) UISwitch *enabled;
@property(nonatomic, strong) KayokoScriptCodeView *code;
@property(nonatomic, strong) UITextView *input;
@property(nonatomic, strong) UITextView *output;
@property(nonatomic, strong) UILabel *resultTitle;
@property(nonatomic, strong) UILabel *resultCount;
@property(nonatomic, strong) UIButton *run;
@property(nonatomic, strong) UISegmentedControl *segments;
@property(nonatomic, strong) UITableView *infoTable;
@property(nonatomic, strong) UIScrollView *scroll;
@property(nonatomic, strong) NSLayoutConstraint *codeBottom;
@property(nonatomic, strong) NSLayoutConstraint *infoBottom;
@property(nonatomic, strong) KayokoKeyboardAvoidanceCoordinator *keyboard;
@property(nonatomic) NSUInteger testGeneration;
@property(nonatomic) BOOL hasResult;
@end

@implementation KayokoScriptEditorViewController

- (UILabel *)label:(NSString *)text size:(CGFloat)size color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size];
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

- (UIView *)card {
    UIView *view = [UIView new];
    view.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    view.layer.cornerRadius = 14;
    view.clipsToBounds = YES;
    return view;
}

- (void)fill:(UIView *)view in:(UIView *)container inset:(CGFloat)inset {
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:view];
    [NSLayoutConstraint activateConstraints:@[
        [view.topAnchor constraintEqualToAnchor:container.topAnchor constant:inset],
        [view.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-inset],
        [view.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:inset],
        [view.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-inset]
    ]];
}

- (UIStackView *)column:(NSArray<UIView *> *)views spacing:(CGFloat)spacing {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = spacing;
    return stack;
}

- (UIView *)heading:(NSString *)key trailing:(UIView *)trailing {
    UILabel *title = [self label:KayokoScriptString(key) size:13 color:UIColor.secondaryLabelColor];
    UIView *space = [UIView new];
    [title setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [space setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisHorizontal];
    [trailing setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:trailing ? @[title, space, trailing] : @[title, space]];
    row.alignment = UIStackViewAlignmentCenter;
    return row;
}

- (UIToolbar *)dismissAccessory {
    UIToolbar *bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 44)];
    bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UIBarButtonItem *hide = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"keyboard.chevron.compact.down"]
        style:UIBarButtonItemStylePlain target:self action:@selector(hideKeyboard)];
    hide.accessibilityLabel = KayokoScriptString(@"Hide keyboard");
    hide.accessibilityIdentifier = @"kayoko.script.hideKeyboard";
    bar.items = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil], hide];
    return bar;
}

- (UITextView *)textEditor:(NSString *)text label:(NSString *)label height:(CGFloat)height {
    UITextView *field = [UITextView new];
    field.text = text;
    field.font = [UIFont systemFontOfSize:15];
    field.textColor = UIColor.labelColor;
    field.backgroundColor = UIColor.clearColor;
    field.textContainerInset = UIEdgeInsetsMake(14, 10, 14, 10);
    field.accessibilityLabel = KayokoScriptString(label);
    field.smartDashesType = UITextSmartDashesTypeNo;
    field.smartQuotesType = UITextSmartQuotesTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.spellCheckingType = UITextSpellCheckingTypeNo;
    field.delegate = self;
    field.inputAccessoryView = [self dismissAccessory];
    [field.heightAnchor constraintEqualToConstant:height].active = YES;
    return field;
}

- (UITableView *)makeInfoTable {
    self.nameField = [UITextField new];
    self.nameField.text = self.script[@"name"];
    self.nameField.placeholder = KayokoScriptString(@"Give this script a name");
    self.nameField.accessibilityLabel = KayokoScriptString(@"Script name");
    self.nameField.accessibilityIdentifier = @"kayoko.script.name";
    self.nameField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.nameField.adjustsFontForContentSizeCategory = YES;
    self.nameField.textColor = UIColor.secondaryLabelColor;
    self.nameField.textAlignment = NSTextAlignmentRight;
    self.nameField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.nameField.returnKeyType = UIReturnKeyDone;
    self.nameField.delegate = self;
    self.nameField.inputAccessoryView = [self dismissAccessory];
    [self.nameField addTarget:self action:@selector(updateEditingState) forControlEvents:UIControlEventEditingChanged];
    self.enabled = [UISwitch new];
    self.enabled.on = [self.script[@"enabled"] boolValue];
    self.enabled.accessibilityLabel = KayokoScriptString(@"Enable");
    self.enabled.accessibilityIdentifier = @"kayoko.script.enabled";
    [self.enabled addTarget:self action:@selector(updateEditingState) forControlEvents:UIControlEventValueChanged];

    UITableView *table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    table.dataSource = self;
    table.delegate = self;
    table.rowHeight = UITableViewAutomaticDimension;
    table.estimatedRowHeight = 44;
    table.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    table.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    return table;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return 2; }

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section { return 8; }
- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section { return [UIView new]; }

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    Class cellClass = path.row == 0 ? KayokoScriptNameCell.class : UITableViewCell.class;
    UITableViewCell *cell = [[cellClass alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    UIListContentConfiguration *content = cell.defaultContentConfiguration;
    content.text = KayokoScriptString(path.row == 0 ? @"Name" : @"Enable");
    cell.contentConfiguration = content;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = path.row == 0 ? self.nameField : self.enabled;
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:NO];
    if (path.row == 0) [self.nameField becomeFirstResponder];
}

- (UIView *)makeTestPanel {
    self.input = [self textEditor:self.script[@"input"] label:@"Test input" height:104];
    self.input.accessibilityIdentifier = @"kayoko.script.input";
    UIView *inputCard = [self card];
    [self fill:self.input in:inputCard inset:0];
    self.run = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.run setTitle:KayokoScriptString(@"Test run") forState:UIControlStateNormal];
    [self.run setImage:[UIImage systemImageNamed:@"play.fill" withConfiguration:
        [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
    self.run.contentEdgeInsets = UIEdgeInsetsMake(10, 12, 10, 12);
    self.run.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 4);
    self.run.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.run.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.10];
    self.run.layer.cornerRadius = 9;
    self.run.accessibilityLabel = KayokoScriptString(@"Test run");
    self.run.accessibilityIdentifier = @"kayoko.script.run";
    [self.run addTarget:self action:@selector(test) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *inputSection = [self column:@[[self heading:@"Test input" trailing:self.run], inputCard] spacing:10];
    self.resultTitle = [self label:KayokoScriptString(@"Result") size:13 color:UIColor.secondaryLabelColor];
    self.resultCount = [self label:@"" size:12 color:UIColor.secondaryLabelColor];
    UIView *space = [UIView new];
    UIStackView *resultHeading = [[UIStackView alloc] initWithArrangedSubviews:@[self.resultTitle, space, self.resultCount]];
    resultHeading.alignment = UIStackViewAlignmentCenter;
    self.output = [self textEditor:@"" label:@"Result" height:180];
    self.output.accessibilityIdentifier = @"kayoko.script.output";
    self.output.editable = NO;
    self.output.delegate = nil;
    self.output.inputAccessoryView = nil;
    UIView *outputCard = [self card];
    [self fill:self.output in:outputCard inset:0];
    UIStackView *resultSection = [self column:@[resultHeading, outputCard,
        [self label:KayokoScriptString(@"Test runs do not change the clipboard.") size:12 color:UIColor.secondaryLabelColor]] spacing:10];
    return [self column:@[inputSection, resultSection] spacing:24];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
        target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
        target:self action:@selector(saveScript)];
    self.segments = [[UISegmentedControl alloc] initWithItems:@[KayokoScriptString(@"Code"), KayokoScriptString(@"Test"), KayokoScriptString(@"Info")]];
    self.segments.selectedSegmentIndex = 0;
    self.segments.accessibilityIdentifier = @"kayoko.script.workspace";
    [self.segments addTarget:self action:@selector(changeWorkspace) forControlEvents:UIControlEventValueChanged];
    self.segments.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *header = [UIView new];
    header.backgroundColor = UIColor.systemGroupedBackgroundColor;
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:header];
    [header addSubview:self.segments];
    UIView *workspace = [UIView new];
    workspace.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:workspace];
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [header.bottomAnchor constraintEqualToAnchor:self.segments.bottomAnchor constant:12],
        [self.segments.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [self.segments.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [self.segments.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [self.segments.heightAnchor constraintEqualToConstant:32],
        [workspace.topAnchor constraintEqualToAnchor:header.bottomAnchor],
        [workspace.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [workspace.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [workspace.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
    self.code = [KayokoScriptCodeView new];
    self.code.text = self.script[@"code"];
    self.code.delegate = self;
    self.code.translatesAutoresizingMaskIntoConstraints = NO;
    [workspace addSubview:self.code];
    self.codeBottom = [self.code.bottomAnchor constraintEqualToAnchor:workspace.bottomAnchor];
    [NSLayoutConstraint activateConstraints:@[
        [self.code.topAnchor constraintEqualToAnchor:workspace.topAnchor],
        [self.code.leadingAnchor constraintEqualToAnchor:workspace.leadingAnchor],
        [self.code.trailingAnchor constraintEqualToAnchor:workspace.trailingAnchor], self.codeBottom
    ]];
    self.scroll = [UIScrollView new];
    self.scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self fill:self.scroll in:workspace inset:0];
    UIView *test = [self makeTestPanel];
    test.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:test];
    [NSLayoutConstraint activateConstraints:@[
        [test.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:20],
        [test.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-24],
        [test.leadingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.leadingAnchor constant:20],
        [test.trailingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.trailingAnchor constant:-20],
        [test.widthAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.widthAnchor constant:-40]
    ]];
    self.infoTable = [self makeInfoTable];
    self.infoTable.translatesAutoresizingMaskIntoConstraints = NO;
    [workspace addSubview:self.infoTable];
    self.infoBottom = [self.infoTable.bottomAnchor constraintEqualToAnchor:workspace.bottomAnchor];
    [NSLayoutConstraint activateConstraints:@[
        [self.infoTable.topAnchor constraintEqualToAnchor:workspace.topAnchor],
        [self.infoTable.leadingAnchor constraintEqualToAnchor:workspace.leadingAnchor],
        [self.infoTable.trailingAnchor constraintEqualToAnchor:workspace.trailingAnchor],
        self.infoBottom
    ]];
    self.keyboard = [[KayokoKeyboardAvoidanceCoordinator alloc] initWithView:workspace scrollView:self.scroll];
    __weak typeof(self) weakSelf = self;
    self.keyboard.keyboardBottomInsetChangeHandler = ^(CGFloat inset) {
        weakSelf.codeBottom.constant = -inset;
        weakSelf.infoBottom.constant = -inset;
        [weakSelf.view layoutIfNeeded];
        if (inset > 0) dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf revealSelection]; });
    };
    [self resetResult];
    [self changeWorkspace];
    [self updateEditingState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.keyboard startObserving];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.navigationController.presentationController.delegate = self;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.keyboard stopObservingAndRestoreInsets];
}

- (void)changeWorkspace {
    [self hideKeyboard];
    NSInteger page = self.segments.selectedSegmentIndex;
    self.code.hidden = page != 0;
    self.view.backgroundColor = page == 0 ? self.code.backgroundColor : UIColor.systemGroupedBackgroundColor;
    self.scroll.hidden = page != 1;
    self.infoTable.hidden = page != 2;
    [self.scroll setContentOffset:CGPointZero animated:NO];
}

- (BOOL)hasChanges {
    return ![self.nameField.text isEqualToString:self.script[@"name"]] ||
           ![self.code.text isEqualToString:self.script[@"code"]] ||
           ![self.input.text isEqualToString:self.script[@"input"]] ||
           self.enabled.on != [self.script[@"enabled"] boolValue];
}

- (void)updateEditingState {
    BOOL dirty = [self hasChanges];
    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.title = name.length ? name : KayokoScriptString(@"New script");
    self.navigationItem.rightBarButtonItem.enabled = dirty && name.length && self.code.text.length;
    self.modalInPresentation = dirty;
    self.navigationController.modalInPresentation = dirty;
}

- (void)resetResult {
    self.hasResult = NO;
    self.resultTitle.text = KayokoScriptString(@"Result");
    self.resultTitle.textColor = UIColor.secondaryLabelColor;
    self.resultCount.text = @"";
    self.output.text = KayokoScriptString(@"Run the script to preview its result");
    self.output.textColor = UIColor.tertiaryLabelColor;
}

- (void)textViewDidChange:(UITextView *)textView {
    self.testGeneration++;
    if (self.hasResult) [self resetResult];
    if (textView == self.code) [self.code refreshCodeAppearance];
    [self updateEditingState];
}

- (void)textViewDidChangeSelection:(UITextView *)textView { if (textView == self.code) [self.code updateEditingKeys]; }
- (void)textViewDidBeginEditing:(UITextView *)textView { [self revealSelection]; }
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    textField.textColor = UIColor.labelColor;
    [self revealSelection];
}
- (void)textFieldDidEndEditing:(UITextField *)textField { textField.textColor = UIColor.secondaryLabelColor; }
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [textField resignFirstResponder]; return YES; }

- (void)revealSelection {
    if (self.code.isFirstResponder) { [self.code scrollRangeToVisible:self.code.selectedRange]; return; }
    if (self.nameField.isFirstResponder) {
        [self.infoTable scrollRectToVisible:[self.infoTable rectForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]] animated:NO];
    } else if (self.input.isFirstResponder && self.input.selectedTextRange) {
        CGRect caret = [self.input caretRectForPosition:self.input.selectedTextRange.end];
        CGRect frame = [self.input convertRect:caret toView:self.scroll];
        [self.scroll scrollRectToVisible:CGRectInset(frame, -8, -18) animated:NO];
    }
}

- (void)hideKeyboard { [self.view endEditing:YES]; }

- (void)test {
    [self hideKeyboard];
    self.run.enabled = NO;
    NSUInteger generation = ++self.testGeneration;
    __weak typeof(self) weakSelf = self;
    [KayokoScripts runCode:self.code.text input:self.input.text completion:^(NSArray *values, NSString *error) {
        KayokoScriptEditorViewController *editor = weakSelf;
        if (!editor) return;
        editor.run.enabled = YES;
        if (editor.testGeneration != generation || !editor.viewIfLoaded.window) return;
        editor.hasResult = YES;
        editor.resultTitle.text = KayokoScriptString(error ? @"Script error" : @"Result");
        editor.resultTitle.textColor = error ? UIColor.systemRedColor : UIColor.secondaryLabelColor;
        editor.resultCount.text = !error && values.count ?
            [NSString stringWithFormat:KayokoScriptString(@"%lu results"), (unsigned long)values.count] : @"";
        editor.output.textColor = error ? UIColor.systemRedColor : values.count ? UIColor.labelColor : UIColor.secondaryLabelColor;
        editor.output.text = error ?: (values.count ? [values componentsJoinedByString:@"\n\n"] : KayokoScriptString(@"No matching result"));
        [editor.output setContentOffset:CGPointZero animated:NO];
    }];
}

- (void)cancel {
    [self hideKeyboard];
    if (![self hasChanges]) { [self dismissViewControllerAnimated:YES completion:nil]; return; }
    if (self.presentedViewController) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:KayokoScriptString(@"Discard changes?")
        message:KayokoScriptString(@"Your changes have not been saved.") preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:KayokoScriptString(@"Discard changes") style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *action) {
            [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        }]];
    [alert addAction:[UIAlertAction actionWithTitle:KayokoScriptString(@"Keep editing") style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.barButtonItem = self.navigationItem.leftBarButtonItem;
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentationControllerDidAttemptToDismiss:(UIPresentationController *)presentationController { [self cancel]; }

- (void)saveScript {
    [self hideKeyboard];
    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!name.length || !self.code.text.length) return;
    NSDictionary *updated = @{@"id":self.script[@"id"], @"name":name, @"enabled":@(self.enabled.on),
                              @"code":self.code.text, @"input":self.input.text};
    NSError *error = nil;
    if (self.save(updated, &error)) [self dismissViewControllerAnimated:YES completion:nil];
    else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:KayokoScriptString(@"Edit script")
            message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:KayokoScriptString(@"OK") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}
@end
