#import <Foundation/Foundation.h>
#import <sqlite3.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kKayokoSearchTokenTypeCategory;
extern NSString *const kKayokoSearchTokenTypeApp;
extern NSString *const kKayokoSearchTokenTypeTag;
extern NSString *const kKayokoSearchCategoryText;
extern NSString *const kKayokoSearchCategoryLink;
extern NSString *const kKayokoSearchCategoryPhone;
extern NSString *const kKayokoSearchCategoryDate;
extern NSString *const kKayokoSearchCategoryAddress;
extern NSString *const kKayokoSearchCategoryFlight;
extern NSString *const kKayokoSearchCategoryImage;

NSArray<NSString *> *KayokoFilterSectionIdentifiers(void);
NSArray<NSString *> *KayokoFilterCategoryIdentifiers(void);
NSDictionary<NSString *, NSString *> *_Nullable KayokoFilterCategoryMetadata(NSString *identifier);
NSDictionary<NSString *, NSString *> *_Nullable KayokoFilterSpecialApplicationMetadata(NSString *identifier);
NSString *KayokoHistoryDatabasePath(void);
NSArray<NSString *> *_Nullable KayokoReadSearchAppBundleIdentifiers(sqlite3 *database, NSError **error);

NS_ASSUME_NONNULL_END
