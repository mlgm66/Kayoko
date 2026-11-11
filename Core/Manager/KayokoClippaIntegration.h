#import <Foundation/Foundation.h>
@class KayokoPasteboardItem;
NS_ASSUME_NONNULL_BEGIN
@interface KayokoClippaIntegration : NSObject
+ (BOOL)isAvailable;
+ (BOOL)floatPasteboardItem:(KayokoPasteboardItem *)item error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
