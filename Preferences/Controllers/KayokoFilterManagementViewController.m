#import "KayokoFilterManagementViewController.h"
#import "KayokoFilterApplicationCatalog.h"
#import "KayokoFilterCatalog.h"
#import "KayokoFilterItemOrderViewController.h"
#import "KayokoFilterOrderStore.h"
#import "KayokoPreferenceKeys.h"
#import "KayokoTagManagementViewController.h"
#import "KayokoTagStore.h"

@interface KayokoFilterManagementViewController () <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) KayokoFilterOrderStore *orderStore;
@property(nonatomic, copy) NSArray<NSString *> *sectionOrder;
@property(nonatomic, strong) NSBundle *localizationBundle;
@property(nonatomic, copy) NSNumber *tagCount;
@property(nonatomic, copy) NSNumber *applicationCount;
@end

@implementation KayokoFilterManagementViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _localizationBundle = [NSBundle bundleForClass:[self class]];
    _orderStore = [[KayokoFilterOrderStore alloc] init];
    _sectionOrder = [_orderStore orderedIdentifiers:KayokoFilterSectionIdentifiers() forKey:kKayokoPreferenceKeyFilterSectionOrder];
    [self setTitle:[self localizedString:@"Tag Management"]];
    [[self navigationItem] setLargeTitleDisplayMode:UINavigationItemLargeTitleDisplayModeNever];
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    [_tableView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_tableView setDataSource:self];
    [_tableView setDelegate:self];
    [_tableView setRowHeight:57.0];
    [_tableView setAllowsSelectionDuringEditing:YES];
    [_tableView setEditing:YES];
    [[self view] addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [[_tableView topAnchor] constraintEqualToAnchor:[[self view] topAnchor]],
        [[_tableView bottomAnchor] constraintEqualToAnchor:[[self view] bottomAnchor]],
        [[_tableView leadingAnchor] constraintEqualToAnchor:[[self view] leadingAnchor]],
        [[_tableView trailingAnchor] constraintEqualToAnchor:[[self view] trailingAnchor]]
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[self navigationController] setToolbarHidden:YES animated:animated];
    [[self orderStore] reload];
    [self setSectionOrder:[[self orderStore] orderedIdentifiers:KayokoFilterSectionIdentifiers()
                                                      forKey:kKayokoPreferenceKeyFilterSectionOrder]];
    KayokoTagStore *tags = [[KayokoTagStore alloc] initWithTagsPath:[KayokoTagStore defaultTagsPath]
                                              localizationBundle:[self localizationBundle]];
    NSArray *loadedTags = [tags readTagsWithError:nil];
    [self setTagCount:loadedTags ? @([loadedTags count]) : nil];
    [[self tableView] reloadData];
    __weak typeof(self) weakSelf = self;
    NSBundle *bundle = [self localizationBundle];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *entries = KayokoFilterApplicationEntries(bundle, nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf setApplicationCount:entries ? @([entries count]) : nil];
            UITableViewCell *cell = [[strongSelf tableView] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:1]];
            NSString *count = entries ? [NSString stringWithFormat:[strongSelf localizedString:@"%@ items"], @([entries count])] : nil;
            [[cell detailTextLabel] setText:count];
        });
    });
}

- (NSString *)localizedString:(NSString *)key {
    return [[self localizationBundle] localizedStringForKey:key value:nil table:@"Tags"];
}

- (NSString *)titleForIdentifier:(NSString *)identifier {
    NSString *key = [identifier isEqualToString:kKayokoSearchTokenTypeCategory] ? @"Category Tags" :
                    [identifier isEqualToString:kKayokoSearchTokenTypeTag] ? @"Custom Tags" : @"Application Tags";
    return [self localizedString:key];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self localizedString:section == 0 ? @"Tag Row Order" : @"Tags Within Each Row"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return [self localizedString:section == 0 ? @"Drag the handles to change the order of the three rows." :
                                              @"Open a tag group to change its left-to-right order."];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FilterGroup"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"FilterGroup"];
    }
    NSString *identifier = [indexPath section] == 0 ? [self sectionOrder][[indexPath row]] :
                                                    KayokoFilterSectionIdentifiers()[[indexPath row]];
    [[cell textLabel] setText:[self titleForIdentifier:identifier]];
    [[cell detailTextLabel] setText:nil];
    BOOL reorders = [indexPath section] == 0;
    [cell setShowsReorderControl:reorders];
    [cell setSelectionStyle:reorders ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault];
    [cell setAccessoryType:reorders ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator];
    [cell setEditingAccessoryType:[cell accessoryType]];
    if (!reorders) {
        NSNumber *count = [identifier isEqualToString:kKayokoSearchTokenTypeCategory] ?
            @([KayokoFilterCategoryIdentifiers() count]) :
            [identifier isEqualToString:kKayokoSearchTokenTypeTag] ? [self tagCount] : [self applicationCount];
        if (count) {
            [[cell detailTextLabel] setText:[NSString stringWithFormat:[self localizedString:@"%@ items"], count]];
        }
    }
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return [indexPath section] == 0;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)source
      toProposedIndexPath:(NSIndexPath *)destination {
    return [destination section] == 0 ? destination : [NSIndexPath indexPathForRow:2 inSection:0];
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)source
      toIndexPath:(NSIndexPath *)destination {
    NSMutableArray *order = [[self sectionOrder] mutableCopy];
    NSString *identifier = order[[source row]];
    [order removeObjectAtIndex:[source row]];
    [order insertObject:identifier atIndex:[destination row]];
    NSError *error;
    if (![[self orderStore] saveOrder:order forKey:kKayokoPreferenceKeyFilterSectionOrder error:&error]) {
        [tableView moveRowAtIndexPath:destination toIndexPath:source];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self title]
            message:[self localizedString:@"Unable to Save Tag Order"] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:[self localizedString:@"OK"] style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    [self setSectionOrder:order];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([indexPath section] == 0) {
        return;
    }
    NSString *identifier = KayokoFilterSectionIdentifiers()[[indexPath row]];
    UIViewController *controller = [identifier isEqualToString:kKayokoSearchTokenTypeTag] ?
        [[KayokoTagManagementViewController alloc] init] :
        [[KayokoFilterItemOrderViewController alloc] initWithSectionIdentifier:identifier];
    [[self navigationController] pushViewController:controller animated:YES];
}

@end
