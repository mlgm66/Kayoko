#import <Foundation/Foundation.h>

NSString *KayokoScriptString(NSString *key);

@interface KayokoScripts : NSObject
+ (NSArray<NSDictionary *> *)scriptsWithError:(NSError **)error;
+ (BOOL)saveScript:(NSDictionary *)script error:(NSError **)error;
+ (BOOL)deleteScriptWithID:(NSString *)identifier error:(NSError **)error;
+ (NSArray<NSDictionary *> *)reorderScriptsWithIDs:(NSArray<NSString *> *)identifiers error:(NSError **)error;
+ (void)runCode:(NSString *)code input:(NSString *)input
     completion:(void (^)(NSArray<NSString *> *results, NSString *error))completion;
@end
