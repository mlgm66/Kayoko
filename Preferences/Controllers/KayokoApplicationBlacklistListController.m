#import "KayokoApplicationBlacklistListController.h"
#import "KayokoSearchPresentation.h"

@implementation KayokoApplicationBlacklistListController {
    BOOL _searchPositionedAtTop;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    KayokoConfigureSearchPresentation(self, self.navigationItem.searchController);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    KayokoRevealSearchOnFirstAppearance(self, self.table, &_searchPositionedAtTop);
}

@end
