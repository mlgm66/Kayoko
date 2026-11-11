#import <Foundation/Foundation.h>

@interface KayokoScriptPasteTarget : NSObject
+ (instancetype)currentTarget;
- (BOOL)isCurrent;
- (void)pasteText:(NSString *)text atChangeCount:(NSUInteger)changeCount completion:(void (^)(BOOL pasted))completion;
@end
