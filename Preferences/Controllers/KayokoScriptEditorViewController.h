#import <UIKit/UIKit.h>

@interface KayokoScriptEditorViewController : UIViewController
@property(nonatomic, copy) NSDictionary *script;
@property(nonatomic, copy) BOOL (^save)(NSDictionary *, NSError **);
@end
