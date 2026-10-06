#import "KayokoFilterItemOrderViewController.h"
#import "KayokoFilterApplicationCatalog.h"
#import "KayokoFilterCatalog.h"
#import "KayokoFilterOrderStore.h"
#import "KayokoPreferenceKeys.h"

@interface KayokoFilterItemOrderViewController () <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, copy) NSString *sectionIdentifier;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) KayokoFilterOrderStore *orderStore;
@property(nonatomic, strong) NSBundle *localizationBundle;
@property(nonatomic, copy) NSArray<NSString *> *identifiers;
@property(nonatomic, copy) NSDictionary<NSString *, NSString *> *applicationTitles;
@property(nonatomic, assign) BOOL loading;
@property(nonatomic, assign) BOOL loadFailed;
@end

@implementation KayokoFilterItemOrderViewController

- (instancetype)initWithSectionIdentifier:(NSString *)identifier {
    self = [super init];
    if (self) {
        _sectionIdentifier = [identifier copy];
        _identifiers = @[];
        _applicationTitles = @{};
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _localizationBundle = [NSBundle bundleForClass:[self class]];
    _orderStore = [[KayokoFilterOrderStore alloc] init];
    [self setTitle:[self localizedString:[self isApplicationSection] ? @"Application Tags" : @"Category Tags"]];
    [[self navigationItem] setLargeTitleDisplayMode:UINavigationItemLargeTitleDisplayModeNever];
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    [_tableView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_tableView setRowHeight:58.0];
    [_tableView setDataSource:self];
    [_tableView setDelegate:self];
    [_tableView setAllowsSelection:NO];
    [_tableView setEditing:YES];
    [[self view] addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [[_tableView topAnchor] constraintEqualToAnchor:[[self view] topAnchor]],
        [[_tableView bottomAnchor] constraintEqualToAnchor:[[self view] bottomAnchor]],
        [[_tableView leadingAnchor] constraintEqualToAnchor:[[self view] leadingAnchor]],
        [[_tableView trailingAnchor] constraintEqualToAnchor:[[self view] trailingAnchor]]
    ]];
    if (![self isApplicationSection]) {
        [self setIdentifiers:[[self orderStore] orderedIdentifiers:KayokoFilterCategoryIdentifiers() forKey:[self orderKey]]];
        return;
    }
    [self setLoading:YES];
    __weak typeof(self) weakSelf = self;
    NSBundle *bundle = [self localizationBundle];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *entries = KayokoFilterApplicationEntries(bundle, nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf setLoading:NO];
            [strongSelf setLoadFailed:entries == nil];
            if (entries) {
                NSMutableDictionary *titles = [NSMutableDictionary dictionary];
                NSMutableArray *identifiers = [NSMutableArray array];
                for (NSDictionary *entry in entries) {
                    titles[entry[@"identifier"]] = entry[@"title"];
                    [identifiers addObject:entry[@"identifier"]];
                }
                [strongSelf setApplicationTitles:titles];
                [[strongSelf orderStore] reload];
                [strongSelf setIdentifiers:[[strongSelf orderStore] orderedIdentifiers:identifiers forKey:[strongSelf orderKey]]];
            }
            [[strongSelf tableView] reloadData];
        });
    });
}

- (BOOL)isApplicationSection {
    return [[self sectionIdentifier] isEqualToString:kKayokoSearchTokenTypeApp];
}

- (NSString *)orderKey {
    return [self isApplicationSection] ? kKayokoPreferenceKeyFilterApplicationOrder : kKayokoPreferenceKeyFilterCategoryOrder;
}

- (NSString *)localizedString:(NSString *)key {
    return [[self localizationBundle] localizedStringForKey:key value:nil table:@"Tags"];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self identifiers] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self localizedString:@"Drag the handles. Tags at the top appear on the left."];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if ([self loading]) {
        return [self localizedString:@"Loading Applications…"];
    }
    if ([self loadFailed]) {
        return [self localizedString:@"Unable to Load Application Tags"];
    }
    if ([self isApplicationSection]) {
        NSString *key = [[self identifiers] count] == 0 ? @"No Application Tags" :
            @"Only applications with clipboard records are listed. New applications are added at the end.";
        return [[self localizedString:key] stringByAppendingFormat:@"\n%@",
            [self localizedString:@"Changes are saved automatically. Reopen the panel to see them."]];
    }
    return [self localizedString:@"Changes are saved automatically. Reopen the panel to see them."];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FilterItem"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"FilterItem"];
    }
    NSString *identifier = [self identifiers][[indexPath row]];
    if ([self isApplicationSection]) {
        [[cell textLabel] setText:[self applicationTitles][identifier]];
        [[cell imageView] setImage:KayokoFilterApplicationIcon(identifier, [self localizationBundle])];
    } else {
        NSDictionary *metadata = KayokoFilterCategoryMetadata(identifier);
        [[cell textLabel] setText:[[self localizationBundle] localizedStringForKey:metadata[@"title"] value:nil table:@"Tweak"]];
        [[cell imageView] setImage:[UIImage systemImageNamed:metadata[@"image"]]];
        [[cell imageView] setTintColor:[UIColor labelColor]];
    }
    [cell setShowsReorderControl:YES];
    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)source
      toIndexPath:(NSIndexPath *)destination {
    NSMutableArray *order = [[self identifiers] mutableCopy];
    NSString *identifier = order[[source row]];
    [order removeObjectAtIndex:[source row]];
    [order insertObject:identifier atIndex:[destination row]];
    NSError *error;
    if (![[self orderStore] saveOrder:order forKey:[self orderKey] error:&error]) {
        [tableView moveRowAtIndexPath:destination toIndexPath:source];
        [self presentError:error];
        return;
    }
    [self setIdentifiers:order];
}

- (void)presentError:(NSError *)error {
    NSString *message = [error localizedDescription] ?: [self localizedString:@"Unable to Save Tag Order"];
    if ([[error domain] isEqualToString:@"com.mlgm.kayoko.filter-order"]) {
        message = [self localizedString:message];
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self title] message:message
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:[self localizedString:@"OK"] style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
