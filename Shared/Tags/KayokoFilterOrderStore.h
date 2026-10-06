#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoFilterOrderStore : NSObject
- (instancetype)initWithPreferences:(NSUserDefaults *)preferences;
- (void)reload;
- (NSArray<NSString *> *)orderedIdentifiers:(NSArray<NSString *> *)identifiers forKey:(NSString *)key;
- (BOOL)saveOrder:(NSArray<NSString *> *)order forKey:(NSString *)key error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
