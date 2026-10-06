#import "KayokoSearchPresentation.h"

void KayokoConfigureSearchPresentation(UIViewController *controller,
                                      UISearchController *searchController) {
    if (!searchController) return;
    searchController.obscuresBackgroundDuringPresentation = NO;
    searchController.hidesNavigationBarDuringPresentation = NO;
    searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    controller.definesPresentationContext = YES;
    controller.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    controller.navigationItem.searchController = searchController;
    controller.navigationItem.hidesSearchBarWhenScrolling = YES;
}

void KayokoRevealSearchOnFirstAppearance(UIViewController *controller,
                                       UITableView *tableView,
                                       BOOL *positionedAtTop) {
    if (*positionedAtTop || !controller.navigationItem.searchController || !tableView) return;
    *positionedAtTop = YES;
    [tableView setContentOffset:CGPointMake(0, -tableView.adjustedContentInset.top) animated:NO];
}
