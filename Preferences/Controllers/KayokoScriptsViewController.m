#import <Preferences/PSViewController.h>
#import "KayokoScripts.h"
#import "KayokoScriptEditorViewController.h"
#import "KayokoScriptHelpViewController.h"

@interface KayokoScriptsViewController : PSViewController <UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, strong) UITableView *table;
@property(nonatomic, copy) NSArray<NSDictionary *> *scripts;
@property(nonatomic, strong) NSError *libraryError;
@property(nonatomic) BOOL orderChanged;
@end

@implementation KayokoScriptsViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = KayokoScriptString(@"Scripts");
    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    self.table.delegate = self;
    self.table.dataSource = self;
    [self.view addSubview:self.table];
    [NSLayoutConstraint activateConstraints:@[
        [self.table.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!self.isEditing) [self reloadScripts];
}

- (void)reloadScripts {
    NSError *error = nil;
    self.scripts = [KayokoScripts scriptsWithError:&error];
    self.libraryError = error;
    [self.table reloadData];
    [self updateMenu];
}

- (void)updateMenu {
    __weak typeof(self) weakSelf = self;
    UIAction *add = [UIAction actionWithTitle:KayokoScriptString(@"New script") image:[UIImage systemImageNamed:@"square.and.pencil"]
        identifier:nil handler:^(__unused UIAction *action) { [weakSelf add]; }];
    UIAction *sort = [UIAction actionWithTitle:KayokoScriptString(@"Sort scripts") image:[UIImage systemImageNamed:@"arrow.up.arrow.down"]
        identifier:nil handler:^(__unused UIAction *action) { [weakSelf beginSorting]; }];
    UIAction *examples = [UIAction actionWithTitle:KayokoScriptString(@"Script examples") image:[UIImage systemImageNamed:@"book"]
        identifier:nil handler:^(__unused UIAction *action) {
            [weakSelf.navigationController pushViewController:[KayokoScriptHelpViewController new] animated:YES];
        }];
    if (!self.scripts) add.attributes = UIMenuElementAttributesDisabled;
    if (self.scripts.count < 2) sort.attributes = UIMenuElementAttributesDisabled;
    UIMenu *menu = [UIMenu menuWithTitle:@"" children:@[add, sort, examples]];
    UIBarButtonItem *more = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"] menu:menu];
    more.accessibilityLabel = KayokoScriptString(@"More");
    self.navigationItem.rightBarButtonItem = more;
}

- (void)beginSorting {
    self.orderChanged = NO;
    [self setEditing:YES animated:YES];
    [self.navigationItem setHidesBackButton:YES animated:YES];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self action:@selector(finishSorting)];
}

- (void)finishSorting {
    NSError *error = nil;
    if (self.orderChanged) [KayokoScripts reorderScriptsWithIDs:[self.scripts valueForKey:@"id"] error:&error];
    [self setEditing:NO animated:YES];
    [self.navigationItem setHidesBackButton:NO animated:YES];
    [self reloadScripts];
    if (error) [self showError:error];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.table setEditing:editing animated:animated];
    for (UITableViewCell *cell in self.table.visibleCells) cell.detailTextLabel.hidden = editing;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return self.scripts.count; }

- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section { return KayokoScriptString(@"Script list"); }

- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    if (self.libraryError) return self.libraryError.localizedDescription;
    return KayokoScriptString(self.scripts.count ? @"Script writing hint" : @"Choose New script in More to add your first script.");
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"Script"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"Script"];
    NSDictionary *script = self.scripts[path.row];
    cell.textLabel.text = script[@"name"];
    cell.detailTextLabel.text = KayokoScriptString([script[@"enabled"] boolValue] ? @"Enabled" : @"Disabled");
    cell.detailTextLabel.hidden = self.isEditing;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.showsReorderControl = YES;
    return cell;
}

- (void)editScript:(NSDictionary *)script {
    KayokoScriptEditorViewController *editor = [KayokoScriptEditorViewController new];
    editor.script = script;
    editor.save = ^BOOL(NSDictionary *updated, NSError **error) {
        if (![KayokoScripts saveScript:updated error:error]) return NO;
        [self reloadScripts];
        return YES;
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:editor];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)add {
    [self editScript:@{@"id":NSUUID.UUID.UUIDString, @"name":@"", @"enabled":@YES, @"input":@"Kayoko",
                       @"code":@"function main(text) {\n  return text;\n}"}];
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (!self.isEditing) [self editScript:self.scripts[path.row]];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)table editingStyleForRowAtIndexPath:(NSIndexPath *)path {
    return self.isEditing ? UITableViewCellEditingStyleNone : UITableViewCellEditingStyleDelete;
}

- (BOOL)tableView:(UITableView *)table shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)path { return NO; }

- (BOOL)tableView:(UITableView *)table canMoveRowAtIndexPath:(NSIndexPath *)path { return self.isEditing; }

- (void)tableView:(UITableView *)table moveRowAtIndexPath:(NSIndexPath *)source toIndexPath:(NSIndexPath *)target {
    if ([source isEqual:target]) return;
    NSMutableArray *ordered = [self.scripts mutableCopy];
    NSDictionary *script = ordered[source.row];
    [ordered removeObjectAtIndex:source.row];
    [ordered insertObject:script atIndex:target.row];
    self.scripts = ordered;
    self.orderChanged = YES;
}

- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if (style != UITableViewCellEditingStyleDelete || self.isEditing) return;
    NSError *error = nil;
    if ([KayokoScripts deleteScriptWithID:self.scripts[path.row][@"id"] error:&error]) {
        [self reloadScripts];
    } else {
        [self showError:error];
    }
}

- (void)showError:(NSError *)error {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:KayokoScriptString(@"Scripts")
        message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:KayokoScriptString(@"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
