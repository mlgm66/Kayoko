#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

NSArray<NSDictionary<NSString *, NSString *> *> *_Nullable KayokoFilterApplicationEntries(NSBundle *bundle,
                                                                                         NSError **error);
UIImage *_Nullable KayokoFilterApplicationIcon(NSString *identifier, NSBundle *bundle);

NS_ASSUME_NONNULL_END
