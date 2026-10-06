#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^KayokoFilterApplicationCompletion)(NSArray<NSString *> *_Nullable identifiers, NSError *_Nullable error);
typedef void (^KayokoFilterApplicationProvider)(KayokoFilterApplicationCompletion completion);

@interface KayokoFilterApplicationBridge : NSObject
+ (instancetype)sharedBridge;
- (instancetype)initWithDirectoryPath:(NSString *)path notificationName:(NSString *)name;
- (BOOL)startServingWithProvider:(KayokoFilterApplicationProvider)provider;
- (void)stopServing;
- (NSArray<NSString *> *_Nullable)applicationIdentifiersWithError:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
