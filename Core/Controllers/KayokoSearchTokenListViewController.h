//
//  KayokoSearchTokenListViewController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoFilterOrderStore;

@class KayokoSearchCriteria;
@class KayokoSearchToken;
@class KayokoSearchTokenListViewController;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoSearchTokenListViewControllerDelegate <NSObject>

- (void)searchTokenListViewController:(KayokoSearchTokenListViewController *)controller
                       didSelectToken:(KayokoSearchToken *)token;

@end

@interface KayokoSearchTokenListViewController : UIViewController

@property(nonatomic, weak, nullable) id<KayokoSearchTokenListViewControllerDelegate> delegate;
@property(nonatomic, copy, nullable) void (^contentHeightDidChange)(void);
@property(nonatomic, assign) BOOL showsCategorySectionEnabled;
@property(nonatomic, assign) BOOL showsTagSectionEnabled;
@property(nonatomic, assign) BOOL showsAppSectionEnabled;
@property(nonatomic, assign) BOOL keepsSelectedSectionsVisible;

- (void)updateWithSearchCriteria:(KayokoSearchCriteria *)searchCriteria
                       tagTokens:(NSArray<KayokoSearchToken *> *)tagTokens
                       appTokens:(NSArray<KayokoSearchToken *> *)appTokens;
- (void)applyFilterOrder:(KayokoFilterOrderStore *)orderStore;
- (void)resetSearchSessionState;
- (CGFloat)preferredContentHeightForWidth:(CGFloat)width;

@end

NS_ASSUME_NONNULL_END
