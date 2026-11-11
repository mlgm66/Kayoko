#import "KayokoScriptPanelController.h"
#import "KayokoActivitySharePresenter.h"
#import "KayokoEdgeFadingTableView.h"
#import "KayokoEdgeFadingTextView.h"
#import "KayokoHeaderButtonStyle.h"
#import "KayokoHeaderView.h"
#import "KayokoHistoryItemActionHandler.h"
#import "KayokoMainView.h"
#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"
#import "KayokoScriptPasteTarget.h"
#import "KayokoScripts.h"

static NSLayoutConstraint *KayokoFillView(UIView *view, UIView *parent) {
    [parent addSubview:view];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *bottom = [view.bottomAnchor constraintEqualToAnchor:parent.bottomAnchor];
    [NSLayoutConstraint activateConstraints:@[
        [view.topAnchor constraintEqualToAnchor:parent.topAnchor], bottom,
        [view.leadingAnchor constraintEqualToAnchor:parent.leadingAnchor], [view.trailingAnchor constraintEqualToAnchor:parent.trailingAnchor]
    ]];
    return bottom;
}

@interface KayokoScriptPanelController () <UITableViewDelegate, UITableViewDataSource>
@end

@implementation KayokoScriptPanelController {
    UITableView *_list, *_choices;
    UIView *_resultPage;
    KayokoEdgeFadingTextView *_text;
    UILabel *_count, *_notice, *_message;
    UIButton *_copy, *_paste;
    UIStackView *_footer;
    NSLayoutConstraint *_bodyBottom, *_resultBottom;
    KayokoActivitySharePresenter *_share;
    KayokoScriptPasteTarget *_target;
    KayokoPasteboardItem *_source;
    NSString *_input, *_historyKey;
    NSArray<NSDictionary *> *_scripts;
    NSArray<NSString *> *_values;
    NSInteger _selection;
    NSUInteger _generation;
    BOOL _showingResult, _running, _committing;
}

- (UITableView *)tableWithIdentifier:(NSString *)identifier {
    KayokoEdgeFadingTableView *table = [[KayokoEdgeFadingTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    table.edgeFadeAxis = KayokoEdgeFadeAxisVertical;
    table.edgeFadeWidth = kKayokoListEdgeFadeHeight;
    table.automaticallyAdjustsScrollIndicatorInsets = NO;
    table.dataSource = self;
    table.delegate = self;
    table.backgroundColor = UIColor.clearColor;
    table.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    table.estimatedRowHeight = 46;
    table.rowHeight = UITableViewAutomaticDimension;
    table.tableFooterView = [UIView new];
    table.accessibilityIdentifier = identifier;
    return table;
}

- (UIButton *)button:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    [button setTitle:KayokoScriptString(title) forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.layer.cornerRadius = 12;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    return button;
}

- (void)loadView {
    self.view = [UIView new];
    _headerView = [[KayokoHeaderView alloc] initWithTitle:KayokoScriptString(@"Scripts")];
    [self.view addSubview:_headerView];
    _headerView.translatesAutoresizingMaskIntoConstraints = NO;
    [_headerView.heightAnchor constraintEqualToConstant:KayokoHeaderView.preferredHeight].active = YES;
    [_headerView useCenteredPageTitle];
    _headerView.trailingButton.hidden = YES;
    [_headerView updateStyleForButton:_headerView.leadingButton withImageName:@"arrowshape.turn.up.backward" imageSize:kKayokoFavoritesButtonImageSize tintColor:UIColor.labelColor];
    [_headerView updateStyleForButton:_headerView.shareButton withImageName:@"square.and.arrow.up" imageSize:kKayokoBackButtonImageSize tintColor:UIColor.labelColor];
    [_headerView updateStyleForButton:_headerView.openLinkButton withImageName:@"arrow.up" imageSize:kKayokoBackButtonImageSize tintColor:UIColor.labelColor];
    _headerView.leadingButton.accessibilityLabel = KayokoScriptString(@"Back");
    _headerView.shareButton.accessibilityLabel = KayokoScriptString(@"Share");
    _headerView.openLinkButton.accessibilityLabel = KayokoScriptString(@"Open");
    [_headerView.leadingButton addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    [_headerView.shareButton addTarget:self action:@selector(shareResult) forControlEvents:UIControlEventTouchUpInside];
    [_headerView.openLinkButton addTarget:self action:@selector(openResult) forControlEvents:UIControlEventTouchUpInside];
    _share = [KayokoActivitySharePresenter new];

    _body = [UIView new];
    [self.view addSubview:_body];
    _body.translatesAutoresizingMaskIntoConstraints = NO;
    _bodyBottom = [_body.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor];
    [NSLayoutConstraint activateConstraints:@[
        [_body.topAnchor constraintEqualToAnchor:_headerView.bottomAnchor constant:kKayokoHeaderContentSpacing],
        [_body.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_body.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor], _bodyBottom
    ]];
    _list = [self tableWithIdentifier:@"KayokoScripts"];
    KayokoFillView(_list, _body);
    _resultPage = [UIView new];
    _resultBottom = KayokoFillView(_resultPage, _body);
    _resultPage.hidden = YES;
    _count = [UILabel new];
    _count.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    _count.textColor = UIColor.secondaryLabelColor;
    UIView *content = [UIView new];
    _text = [KayokoEdgeFadingTextView new];
    _text.edgeFadeAxis = KayokoEdgeFadeAxisVertical;
    _text.edgeFadeWidth = kKayokoListEdgeFadeHeight;
    _text.editable = NO;
    _text.selectable = NO;
    _text.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _text.adjustsFontForContentSizeCategory = YES;
    _text.textColor = UIColor.labelColor;
    _text.backgroundColor = UIColor.clearColor;
    _text.textContainerInset = UIEdgeInsetsMake(8, 0, 8, 0);
    _text.textContainer.lineFragmentPadding = 0;
    _text.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    KayokoFillView(_text, content);
    _choices = [self tableWithIdentifier:@"KayokoScriptResults"];
    KayokoFillView(_choices, content);
    _message = [UILabel new];
    _message.numberOfLines = 0;
    _message.textAlignment = NSTextAlignmentCenter;
    _message.textColor = UIColor.secondaryLabelColor;
    _message.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    KayokoFillView(_message, content);
    _notice = [UILabel new];
    _notice.numberOfLines = 0;
    _notice.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    _notice.textColor = UIColor.secondaryLabelColor;
    _copy = [self button:@"Copy script result" action:@selector(copyResult)];
    _paste = [self button:@"Copy and paste" action:@selector(pasteResult)];
    _footer = [[UIStackView alloc] initWithArrangedSubviews:@[_copy, _paste]];
    _footer.spacing = 8;
    _footer.distribution = UIStackViewDistributionFillEqually;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_count, content, _notice, _footer]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 6;
    stack.layoutMargins = UIEdgeInsetsMake(2, 16, 12, 16);
    stack.layoutMarginsRelativeArrangement = YES;
    KayokoFillView(stack, _resultPage);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat keyboard = MAX(0, self.keyboardBottomInset);
    CGFloat safeBottom = MAX(0, [self.panel safeAreaBottomInsetForContentView:self.view] - keyboard);
    if (_bodyBottom.constant != -keyboard) _bodyBottom.constant = -keyboard;
    if (_resultBottom.constant != -safeBottom) _resultBottom.constant = -safeBottom;
    UIEdgeInsets padding = UIEdgeInsetsMake(0, 0, MAX(safeBottom, 12), 0);
    if (!UIEdgeInsetsEqualToEdgeInsets(_list.contentInset, padding)) {
        _list.contentInset = padding;
        _list.verticalScrollIndicatorInsets = padding;
    }
}

- (void)setKeyboardBottomInset:(CGFloat)inset {
    _keyboardBottomInset = inset;
    [self.viewIfLoaded setNeedsLayout];
}

- (void)beginWithText:(NSString *)text item:(KayokoPasteboardItem *)item historyKey:(NSString *)historyKey {
    [self reset];
    _source = item;
    _input = [text copy];
    _historyKey = [historyKey copy];
    _target = KayokoPasteboardManager.sharedInstance.automaticallyPaste ? KayokoScriptPasteTarget.currentTarget : nil;
    NSError *error = nil;
    _scripts = [[KayokoScripts scriptsWithError:&error] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"enabled == YES"]];
    UILabel *empty = [UILabel new];
    empty.numberOfLines = 0;
    empty.textAlignment = NSTextAlignmentCenter;
    empty.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    empty.textColor = UIColor.secondaryLabelColor;
    empty.text = error.localizedDescription ?: KayokoScriptString(@"Add or enable a script in Kayoko settings");
    _list.backgroundView = _scripts.count ? nil : empty;
    [self.view setNeedsLayout];
    [_list reloadData];
    [_list setContentOffset:CGPointZero animated:NO];
    [_headerView setTitleText:KayokoScriptString(@"Scripts")];
    [self updateActions];
}

- (void)invalidatePendingActions { ++_generation; }

- (void)reset {
    [self invalidatePendingActions];
    [_share dismissActivityAnimated:NO];
    _source = nil; _input = nil; _historyKey = nil; _target = nil; _scripts = nil; _values = nil;
    _selection = NSNotFound;
    _running = _committing = _showingResult = NO;
    _resultPage.hidden = YES;
    _list.hidden = NO;
    _list.alpha = 1; _list.transform = CGAffineTransformIdentity;
    _text.text = nil;
    _notice.text = nil;
}

- (BOOL)protectsSystemAction { return _committing || [_share isPresentingActivity]; }

- (NSString *)selectedResult { return _selection >= 0 && _selection < (NSInteger)_values.count ? _values[_selection] : nil; }

- (NSURL *)selectedURL {
    NSString *value = [[self selectedResult] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!value.length || [value rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound) return nil;
    NSURLComponents *parts = [NSURLComponents componentsWithString:value];
    if (!parts.host.length || ![@[@"https", @"http"] containsObject:parts.scheme.lowercaseString]) return nil;
    return parts.URL;
}

- (void)updateActions {
    BOOL enabled = [self selectedResult] != nil && !_committing;
    _headerView.shareButton.hidden = !_showingResult || !_values.count;
    _headerView.shareButton.enabled = enabled;
    _headerView.openLinkButton.hidden = ![self selectedURL];
    _headerView.openLinkButton.enabled = enabled;
    _copy.enabled = _paste.enabled = enabled;
    _paste.hidden = !_target;
    _footer.hidden = !_values.count;
    _notice.hidden = !_notice.text.length;
    for (UIButton *button in @[_copy, _paste]) {
        BOOL primary = button == _paste || !_target;
        button.backgroundColor = primary ? UIColor.labelColor : UIColor.tertiarySystemFillColor;
        [button setTitleColor:primary ? UIColor.systemBackgroundColor : UIColor.labelColor forState:UIControlStateNormal];
        button.alpha = enabled ? 1 : 0.4;
    }
}

- (void)goBack {
    if (self.panel.isAnimating || _committing || !_source) return;
    ++_generation;
    _running = NO;
    if (!_showingResult) { self.returnToSource(NO); return; }
    _values = nil; _selection = NSNotFound; _showingResult = NO;
    [_headerView setTitleText:KayokoScriptString(@"Scripts")];
    [self updateActions];
    [self.panel showContentView:_list transitioningView:_list hideContentView:_resultPage transitioningView:_resultPage
        direction:KayokoContentTransitionDirectionBackward alongsideAnimations:nil completion:self.didFinishTransition];
}

- (void)showValues:(NSArray *)values error:(NSString *)error name:(NSString *)name {
    _values = error ? nil : values;
    _selection = _values.count == 1 ? 0 : NSNotFound;
    _showingResult = YES;
    [_headerView setTitleText:name];
    _choices.hidden = _values.count < 2;
    _text.hidden = _values.count != 1 && !error;
    _message.hidden = _values.count != 0 || error != nil;
    _count.hidden = _choices.hidden;
    _count.text = [NSString stringWithFormat:KayokoScriptString(@"%lu results"), (unsigned long)_values.count];
    _text.textColor = error ? UIColor.secondaryLabelColor : UIColor.labelColor;
    _text.text = error ?: [self selectedResult];
    _message.text = KayokoScriptString(@"No matching result");
    _notice.text = nil;
    [_choices reloadData];
    [_choices setContentOffset:CGPointZero animated:NO];
    [_text setContentOffset:CGPointZero animated:NO];
    [self updateActions];
    [self.panel showContentView:_resultPage transitioningView:_resultPage hideContentView:_list transitioningView:_list
        direction:KayokoContentTransitionDirectionForward alongsideAnimations:nil completion:self.didFinishTransition];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return table == _list ? _scripts.count : _values.count;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"row"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"row"];
    cell.backgroundColor = UIColor.clearColor;
    cell.tintColor = UIColor.labelColor;
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    cell.textLabel.numberOfLines = table == _list ? 2 : 0;
    cell.accessibilityTraits = UIAccessibilityTraitButton;
    if (table == _list) {
        cell.textLabel.text = _scripts[path.row][@"name"];
        cell.imageView.image = [UIImage systemImageNamed:@"terminal" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17]];
        cell.imageView.tintColor = UIColor.secondaryLabelColor;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.textLabel.text = _values[path.row];
        [self configureChoiceCell:cell atRow:path.row];
        cell.layoutMargins = UIEdgeInsetsZero;
    }
    return cell;
}

- (void)configureChoiceCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    BOOL selected = row == _selection;
    cell.backgroundColor = selected ? UIColor.tertiarySystemFillColor : UIColor.clearColor;
    cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (!_source || self.panel.isAnimating || _committing) return;
    if (table == _choices) {
        if (!_showingResult || path.row >= _values.count) return;
        _selection = path.row;
        _notice.text = nil;
        for (NSIndexPath *row in _choices.indexPathsForVisibleRows) {
            UITableViewCell *cell = [_choices cellForRowAtIndexPath:row];
            [self configureChoiceCell:cell atRow:row.row];
        }
        [self updateActions];
        return;
    }
    if (_running || _showingResult || path.row >= _scripts.count) return;
    _running = YES;
    NSUInteger generation = ++_generation;
    NSDictionary *script = _scripts[path.row];
    [KayokoScripts runCode:script[@"code"] input:_input completion:^(NSArray *values, NSString *error) {
        if (self->_generation != generation || !self.view.window || self.view.hidden) return;
        self->_running = NO;
        [self showValues:values error:error name:script[@"name"]];
    }];
}

- (void)shareResult {
    id item = [self selectedURL] ?: (id)[self selectedResult];
    if (item && !_committing) [_share presentActivityItems:@[item] fromController:self anchorView:_headerView.shareButton];
}

- (void)openResult {
    NSURL *url = [self selectedURL];
    if (!url || _committing) return;
    NSUInteger generation = _generation;
    _committing = YES;
    [self updateActions];
    [[KayokoHistoryItemActionHandler new] openURL:url completion:^(BOOL success) {
        if (self->_generation != generation) return;
        self->_committing = NO;
        if (success) self.dismissPanel();
        else { self->_notice.text = KayokoScriptString(@"Could not open link"); [self updateActions]; }
    }];
}

- (void)copyResult { [self commit:NO]; }
- (void)pasteResult { [self commit:YES]; }

- (void)commit:(BOOL)paste {
    NSString *value = [self selectedResult];
    if (!value || _committing || self.panel.isAnimating) return;
    KayokoPasteboardManager *manager = KayokoPasteboardManager.sharedInstance;
    if (paste && (!manager.automaticallyPaste || ![_target isCurrent])) {
        _notice.text = KayokoScriptString(@"Paste target changed");
        _target = nil; [self updateActions]; return;
    }
    KayokoPasteboardItem *source = _source;
    NSString *key = _historyKey;
    KayokoPasteboardItem *output = [[KayokoPasteboardItem alloc] initWithBundleIdentifier:source.bundleIdentifier andContent:value withImageNamed:@""];
    if (![manager copyPasteboardItemToPasteboard:output]) {
        _notice.text = KayokoScriptString(@"Copy failed"); [self updateActions]; return;
    }
    if (!paste) {
        [manager recordScriptResult:output source:source inHistoryKey:key pasted:NO];
        self.returnToSource(YES);
        return;
    }
    NSUInteger count = UIPasteboard.generalPasteboard.changeCount;
    if (![UIPasteboard.generalPasteboard.string isEqualToString:value]) {
        _notice.text = KayokoScriptString(@"Copy failed"); [self updateActions]; return;
    }
    NSUInteger generation = _generation;
    _committing = YES; [self updateActions];
    [_target pasteText:value atChangeCount:count completion:^(BOOL pasted) {
        [manager recordScriptResult:output source:source inHistoryKey:key pasted:pasted];
        if (self->_generation != generation) return;
        self->_committing = NO;
        if (pasted) self.dismissPanel();
        else { self->_target = nil; self->_notice.text = KayokoScriptString(@"Could not confirm script paste"); [self updateActions]; }
    }];
}
@end
