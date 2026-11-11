#import "KayokoScriptCodeView.h"
#import "KayokoScripts.h"

static const CGFloat KayokoKeycapDiameter = 36;

@interface KayokoScriptEditingKey : UIButton
@property(nonatomic, strong) UIView *keycap;
@end

@implementation KayokoScriptEditingKey
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.keycap = [UIView new];
        self.keycap.userInteractionEnabled = NO;
        self.keycap.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark ?
                [UIColor colorWithRed:0.204 green:0.204 blue:0.220 alpha:1] :
                [UIColor colorWithRed:0.910 green:0.910 blue:0.929 alpha:1];
        }];
        self.keycap.layer.cornerRadius = KayokoKeycapDiameter / 2;
        [self insertSubview:self.keycap atIndex:0];
        self.tintColor = UIColor.labelColor;
        [self setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightMedium];
        [self setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18
            weight:UIImageSymbolWeightRegular] forImageInState:UIControlStateNormal];
        self.adjustsImageWhenDisabled = NO;
        self.adjustsImageWhenHighlighted = NO;
        [self.widthAnchor constraintEqualToConstant:44].active = YES;
        [self.heightAnchor constraintEqualToConstant:44].active = YES;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.keycap.frame = CGRectMake((CGRectGetWidth(self.bounds) - KayokoKeycapDiameter) / 2,
        (CGRectGetHeight(self.bounds) - KayokoKeycapDiameter) / 2, KayokoKeycapDiameter, KayokoKeycapDiameter);
    [self sendSubviewToBack:self.keycap];
}

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    self.alpha = enabled ? 1 : 0.36;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.keycap.alpha = highlighted ? 0.65 : 1;
}
@end

@interface KayokoScriptLineNumbers : UIView
@property(nonatomic, weak) KayokoScriptCodeView *editor;
@end

@interface KayokoScriptCodeView ()
@property(nonatomic, strong) KayokoScriptLineNumbers *lineNumbers;
@property(nonatomic, strong) UIButton *undoKey;
@property(nonatomic, strong) UIButton *redoKey;
@property(nonatomic, strong) NSMutableArray<UIButton *> *editingKeys;
@property(nonatomic) BOOL styling;
@property(nonatomic) NSRange pendingStyleRange;
@end

@implementation KayokoScriptLineNumbers
- (void)drawRect:(CGRect)rect {
    KayokoScriptCodeView *editor = self.editor;
    NSLayoutManager *layout = editor.layoutManager;
    NSString *text = editor.text;
    CGRect visible = CGRectMake(0, editor.contentOffset.y, CGRectGetWidth(editor.bounds), CGRectGetHeight(editor.bounds));
    visible.origin.y -= editor.textContainerInset.top;
    NSRange glyphs = [layout glyphRangeForBoundingRect:visible inTextContainer:editor.textContainer];
    __block NSUInteger line = 1, lineStart = 0;
    __block NSUInteger next = text.length ? NSMaxRange([text lineRangeForRange:NSMakeRange(0, 0)]) : 0;
    void (^advanceTo)(NSUInteger) = ^(NSUInteger position) {
        while (lineStart < text.length && next <= position) {
            lineStart = next;
            line++;
            if (lineStart < text.length) next = NSMaxRange([text lineRangeForRange:NSMakeRange(lineStart, 0)]);
        }
    };
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular],
                                 NSForegroundColorAttributeName:UIColor.tertiaryLabelColor};
    [layout enumerateLineFragmentsForGlyphRange:glyphs usingBlock:^(CGRect fragment, CGRect used, NSTextContainer *container, NSRange range, BOOL *stop) {
        NSUInteger start = [layout characterIndexForGlyphAtIndex:range.location];
        advanceTo(start);
        if (start != lineStart) return;
        CGFloat y = fragment.origin.y + editor.textContainerInset.top - editor.contentOffset.y + 3;
        [[NSString stringWithFormat:@"%lu", (unsigned long)line] drawInRect:CGRectMake(4, y, 28, 22) withAttributes:attributes];
    }];
    CGRect extra = layout.extraLineFragmentRect;
    if (layout.extraLineFragmentTextContainer && CGRectIntersectsRect(extra, visible)) {
        advanceTo(text.length);
        CGFloat y = extra.origin.y + editor.textContainerInset.top - editor.contentOffset.y + 3;
        [[NSString stringWithFormat:@"%lu", (unsigned long)line] drawInRect:CGRectMake(4, y, 28, 22) withAttributes:attributes];
    }
}
@end

@implementation KayokoScriptCodeView

- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)container {
    self = [super initWithFrame:frame textContainer:container];
    if (self) {
        self.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
        self.textColor = UIColor.labelColor;
        self.backgroundColor = UIColor.systemBackgroundColor;
        self.textContainerInset = UIEdgeInsetsMake(16, 40, 16, 14);
        self.textContainer.lineFragmentPadding = 0;
        self.layoutManager.allowsNonContiguousLayout = NO;
        self.pendingStyleRange = NSMakeRange(NSNotFound, 0);
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(storageDidEdit:)
            name:NSTextStorageDidProcessEditingNotification object:self.textStorage];
        self.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.autocorrectionType = UITextAutocorrectionTypeNo;
        self.spellCheckingType = UITextSpellCheckingTypeNo;
        self.smartDashesType = UITextSmartDashesTypeNo;
        self.smartQuotesType = UITextSmartQuotesTypeNo;
        self.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
        self.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
        self.accessibilityLabel = @"JavaScript";
        self.accessibilityIdentifier = @"kayoko.script.code";
        self.lineNumbers = [KayokoScriptLineNumbers new];
        self.lineNumbers.editor = self;
        self.lineNumbers.userInteractionEnabled = NO;
        self.lineNumbers.backgroundColor = self.backgroundColor;
        [self addSubview:self.lineNumbers];
        self.inputAccessoryView = [self editingBar];
    }
    return self;
}

- (UIButton *)key:(NSString *)action image:(NSString *)image title:(NSString *)title label:(NSString *)label {
    UIButton *button = [KayokoScriptEditingKey new];
    if (image) [button setImage:[UIImage systemImageNamed:image] forState:UIControlStateNormal];
    if (title) [button setTitle:title forState:UIControlStateNormal];
    button.accessibilityLabel = KayokoScriptString(label ?: title);
    button.accessibilityIdentifier = [@"kayoko.script.key." stringByAppendingString:action];
    [button addTarget:self action:@selector(editingKeyPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.editingKeys addObject:button];
    return button;
}

- (UIView *)editingBar {
    UIVisualEffectView *bar = [[UIVisualEffectView alloc] initWithEffect:
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
    bar.frame = CGRectMake(0, 0, 0, 52);
    bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.editingKeys = [NSMutableArray array];
    UIScrollView *scroll = [UIScrollView new];
    scroll.showsHorizontalScrollIndicator = NO;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [bar.contentView addSubview:scroll];
    UIStackView *keys = [UIStackView new];
    keys.alignment = UIStackViewAlignmentCenter;
    keys.spacing = 0;
    keys.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:keys];
    NSArray *actions = @[@[@"undo", @"arrow.uturn.backward", @"Undo"], @[@"redo", @"arrow.uturn.forward", @"Redo"],
                         @[@"indent", @"increase.indent", @"Indent"], @[@"outdent", @"decrease.indent", @"Outdent"]];
    for (NSUInteger i = 0; i < actions.count; i++) {
        if (i == 2) [self addGroupSeparatorTo:keys];
        NSArray *item = actions[i];
        UIButton *button = [self key:item[0] image:item[1] title:nil label:item[2]];
        if (i == 0) self.undoKey = button;
        if (i == 1) self.redoKey = button;
        [keys addArrangedSubview:button];
    }
    [self addGroupSeparatorTo:keys];
    NSArray *symbols = @[@"()", @"{}", @"[]", @"\"\"", @"''", @";", @"=", @"/"];
    for (NSUInteger i = 0; i < symbols.count; i++)
        [keys addArrangedSubview:[self key:[NSString stringWithFormat:@"symbol%lu", (unsigned long)i]
            image:nil title:symbols[i] label:nil]];
    [self addGroupSeparatorTo:keys];
    [keys addArrangedSubview:[self key:@"left" image:@"arrow.left" title:nil label:@"Move left"]];
    [keys addArrangedSubview:[self key:@"right" image:@"arrow.right" title:nil label:@"Move right"]];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:bar.contentView.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:bar.contentView.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:bar.contentView.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:bar.contentView.bottomAnchor],
        [keys.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:8],
        [keys.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-8],
        [keys.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [keys.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [keys.heightAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.heightAnchor]
    ]];
    return bar;
}

- (void)addGroupSeparatorTo:(UIStackView *)stack {
    UIView *group = [UIView new];
    group.userInteractionEnabled = NO;
    [group.widthAnchor constraintEqualToConstant:12].active = YES;
    [group.heightAnchor constraintEqualToConstant:44].active = YES;
    UIView *dot = [UIView new];
    dot.backgroundColor = UIColor.tertiaryLabelColor;
    dot.layer.cornerRadius = 2;
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    [group addSubview:dot];
    [NSLayoutConstraint activateConstraints:@[
        [dot.widthAnchor constraintEqualToConstant:4], [dot.heightAnchor constraintEqualToConstant:4],
        [dot.centerXAnchor constraintEqualToAnchor:group.centerXAnchor],
        [dot.centerYAnchor constraintEqualToAnchor:group.centerYAnchor]
    ]];
    [stack addArrangedSubview:group];
}

- (void)storageDidEdit:(NSNotification *)notification {
    NSTextStorage *storage = notification.object;
    if (!(storage.editedMask & NSTextStorageEditedCharacters)) return;
    NSRange edit = storage.editedRange;
    NSRange pending = self.pendingStyleRange;
    if (pending.location != NSNotFound) {
        NSUInteger start = MIN(edit.location, pending.location);
        NSInteger oldEnd = NSMaxRange(pending);
        NSInteger end = oldEnd > (NSInteger)edit.location ? oldEnd + storage.changeInLength : oldEnd;
        NSUInteger last = MAX(NSMaxRange(edit), (NSUInteger)MAX(0, end));
        edit = NSMakeRange(start, MIN(storage.length, last) - start);
    }
    self.pendingStyleRange = edit;
}

- (void)setText:(NSString *)text {
    [super setText:text];
    self.pendingStyleRange = NSMakeRange(0, self.textStorage.length);
    [self refreshCodeAppearance];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.lineNumbers.frame = CGRectMake(self.contentOffset.x, self.contentOffset.y, 36, CGRectGetHeight(self.bounds));
    [self.lineNumbers setNeedsDisplay];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    [self refreshCodeAppearance];
}

- (void)refreshCodeAppearance {
    if (self.styling || self.markedTextRange) return;
    NSRange dirty = self.pendingStyleRange;
    if (dirty.location == NSNotFound) { [self updateEditingKeys]; return; }
    self.pendingStyleRange = NSMakeRange(NSNotFound, 0);
    self.styling = YES;
    NSString *text = self.textStorage.string;
    NSTextStorage *storage = self.textStorage;
    NSUInteger start = dirty.location ? dirty.location - 1 : 0;
    NSUInteger end = MIN(text.length, NSMaxRange(dirty) + 1);
    NSRange lines = [text lineRangeForRange:NSMakeRange(start, end - start)];
    static NSString *const continuation = @"KayokoScriptContinuation";
    while (lines.location) {
        NSRange spill;
        if (![storage attribute:continuation atIndex:lines.location - 1 longestEffectiveRange:&spill inRange:NSMakeRange(0, text.length)]) break;
        lines = NSUnionRange(lines, [text lineRangeForRange:spill]);
    }
    __block NSUInteger finish = NSMaxRange(lines);
    void (^extendPastOldToken)(void) = ^{
        NSRange spill;
        while (finish && finish < text.length && [storage attribute:continuation atIndex:finish - 1 longestEffectiveRange:&spill inRange:NSMakeRange(0, text.length)]
            && NSMaxRange(spill) > finish) finish = NSMaxRange([text lineRangeForRange:spill]);
    };
    extendPastOldToken();
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.minimumLineHeight = 24;
    NSDictionary *base = @{NSFontAttributeName:[UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular],
        NSForegroundColorAttributeName:UIColor.labelColor, NSParagraphStyleAttributeName:paragraph};
    NSUndoManager *undo = self.undoManager;
    BOOL undoEnabled = undo.isUndoRegistrationEnabled;
    if (undoEnabled) [undo disableUndoRegistration];

    static NSRegularExpression *tokens;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        tokens = [NSRegularExpression regularExpressionWithPattern:
            @"(//[^\\r\\n]*|/\\*(?:[^*]++|\\*(?!/))*+(?:\\*/|\\z))|"
             "('(?:[^'\\\\\\r\\n]++|\\\\(?:\\r\\n|[\\s\\S])?)*+'?|"
             "\"(?:[^\"\\\\\\r\\n]++|\\\\(?:\\r\\n|[\\s\\S])?)*+\"?|"
             "`(?:[^`\\\\]++|\\\\[\\s\\S]?)*+`?|"
             "(?m:(?:^|(?<=[=(:,!&|?;{\\[])|(?<=\\breturn))[\\t ]*+/(?![/*])"
             "(?:\\\\[^\\r\\n]?|\\[(?:[^\\]\\\\\\r\\n]++|\\\\[^\\r\\n]?)*+\\]?|[^/\\\\\\[\\r\\n]++)*+(?:/[dgimsuvy]*)?))|"
             "\\b(function|const|let|var|return|if|else|for|while|true|false|null|undefined|new|throw|try|catch|async|await|of|in|typeof)\\b|\\b[0-9]+(?:\\.[0-9]+)?\\b"
             "|([\\r\\n\\u0085\\u2028\\u2029])"
            options:0 error:nil];
    });
    NSMutableArray<NSTextCheckingResult *> *matches = [NSMutableArray array];
    [tokens enumerateMatchesInString:text options:NSMatchingWithTransparentBounds | NSMatchingWithoutAnchoringBounds
        range:NSMakeRange(lines.location, text.length - lines.location) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
            if (match.range.location >= finish) { *stop = YES; return; }
        if (NSMaxRange(match.range) > finish) {
            finish = NSMaxRange([text lineRangeForRange:match.range]);
            extendPastOldToken();
        }
        if ([match rangeAtIndex:4].location == NSNotFound) [matches addObject:match];
        if (NSMaxRange(match.range) >= finish) *stop = YES;
    }];
    [storage beginEditing];
    [storage setAttributes:base range:NSMakeRange(lines.location, finish - lines.location)];
    for (NSTextCheckingResult *match in matches) {
        UIColor *color = [match rangeAtIndex:1].location != NSNotFound ? UIColor.secondaryLabelColor :
                [match rangeAtIndex:2].location != NSNotFound ? UIColor.systemGreenColor :
                [match rangeAtIndex:3].location != NSNotFound ? UIColor.systemPurpleColor : UIColor.systemOrangeColor;
        [storage addAttribute:NSForegroundColorAttributeName value:color range:match.range];
        if ([text rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet options:0 range:match.range].location != NSNotFound)
            [storage addAttribute:continuation value:@YES range:match.range];
    }
    [self.textStorage endEditing];
    if (undoEnabled) [undo enableUndoRegistration];
    self.typingAttributes = base;
    self.lineNumbers.backgroundColor = self.backgroundColor;
    [self.lineNumbers setNeedsDisplay];
    self.styling = NO;
    [self updateEditingKeys];
}

- (void)updateEditingKeys {
    BOOL composing = self.markedTextRange != nil;
    for (UIButton *button in self.editingKeys) button.enabled = !composing;
    self.undoKey.enabled = !composing && self.undoManager.canUndo;
    self.redoKey.enabled = !composing && self.undoManager.canRedo;
}

- (void)editingKeyPressed:(UIButton *)button {
    if (!self.isFirstResponder || self.markedTextRange) return;
    NSString *action = button.accessibilityIdentifier.lastPathComponent;
    action = [action componentsSeparatedByString:@"."].lastObject;
    NSRange selection = self.selectedRange;
    if ([action isEqualToString:@"left"] || [action isEqualToString:@"right"]) {
        BOOL right = [action isEqualToString:@"right"];
        UITextPosition *position = [self positionFromPosition:right ? self.selectedTextRange.end : self.selectedTextRange.start
            inDirection:right ? UITextLayoutDirectionRight : UITextLayoutDirectionLeft offset:selection.length ? 0 : 1];
        if (position) self.selectedTextRange = [self textRangeFromPosition:position toPosition:position];
        [self scrollRangeToVisible:self.selectedRange];
        return;
    }
    NSString *original = self.text;
    if ([action isEqualToString:@"undo"]) [self.undoManager undo];
    else if ([action isEqualToString:@"redo"]) [self.undoManager redo];
    else if ([action isEqualToString:@"indent"] || [action isEqualToString:@"outdent"]) {
        [self changeIndent:[action isEqualToString:@"indent"]];
    } else {
        NSString *symbol = [button titleForState:UIControlStateNormal];
        if (symbol.length == 2) {
            NSString *selected = [self.text substringWithRange:selection];
            [self insertText:[NSString stringWithFormat:@"%@%@%@", [symbol substringToIndex:1], selected, [symbol substringFromIndex:1]]];
            self.selectedRange = NSMakeRange(selection.location + 1, selection.length);
        } else [self insertText:symbol];
    }
    [self scrollRangeToVisible:self.selectedRange];
    if (![original isEqualToString:self.text]) {
        if ([self.delegate respondsToSelector:@selector(textViewDidChange:)]) [self.delegate textViewDidChange:self];
        else [self refreshCodeAppearance];
    }
    if ([self.delegate respondsToSelector:@selector(textViewDidChangeSelection:)]) [self.delegate textViewDidChangeSelection:self];
}

- (void)changeIndent:(BOOL)increase {
    NSString *text = self.text;
    NSRange selection = self.selectedRange;
    NSRange range = [text lineRangeForRange:selection];
    NSMutableString *replacement = [NSMutableString string];
    NSInteger firstChange = 0;
    NSUInteger pos = range.location;
    do {
        NSUInteger end = pos;
        if (pos < NSMaxRange(range)) [text getLineStart:NULL end:&end contentsEnd:NULL forRange:NSMakeRange(pos, 0)];
        NSString *line = [text substringWithRange:NSMakeRange(pos, end - pos)];
        NSUInteger removed = increase ? 0 : [line hasPrefix:@"  "] ? 2 : ([line hasPrefix:@" "] || [line hasPrefix:@"\t"]) ? 1 : 0;
        if (increase) [replacement appendString:@"  "];
        [replacement appendString:[line substringFromIndex:removed]];
        if (pos == range.location) firstChange = increase ? 2 : -(NSInteger)MIN(removed, selection.location - pos);
        pos = end;
    } while (pos < NSMaxRange(range));
    self.selectedRange = range;
    [self insertText:replacement];
    self.selectedRange = selection.length ? NSMakeRange(range.location, replacement.length) :
        NSMakeRange((NSUInteger)((NSInteger)selection.location + firstChange), 0);
}
@end
