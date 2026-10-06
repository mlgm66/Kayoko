#import "KayokoFilterCatalog.h"
#import <roothide.h>

NSString *const kKayokoSearchTokenTypeCategory = @"category";
NSString *const kKayokoSearchTokenTypeApp = @"app";
NSString *const kKayokoSearchTokenTypeTag = @"tag";
NSString *const kKayokoSearchCategoryText = @"text";
NSString *const kKayokoSearchCategoryLink = @"link";
NSString *const kKayokoSearchCategoryPhone = @"phone";
NSString *const kKayokoSearchCategoryDate = @"date";
NSString *const kKayokoSearchCategoryAddress = @"address";
NSString *const kKayokoSearchCategoryFlight = @"flight";
NSString *const kKayokoSearchCategoryImage = @"image";

NSArray<NSString *> *KayokoFilterSectionIdentifiers(void) {
    return @[kKayokoSearchTokenTypeCategory, kKayokoSearchTokenTypeTag, kKayokoSearchTokenTypeApp];
}

NSArray<NSString *> *KayokoFilterCategoryIdentifiers(void) {
    return @[kKayokoSearchCategoryText, kKayokoSearchCategoryLink, kKayokoSearchCategoryImage,
             kKayokoSearchCategoryPhone, kKayokoSearchCategoryDate, kKayokoSearchCategoryFlight,
             kKayokoSearchCategoryAddress];
}

NSDictionary<NSString *, NSString *> *KayokoFilterCategoryMetadata(NSString *identifier) {
    static NSDictionary *metadata;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        metadata = @{
            kKayokoSearchCategoryText : @{@"title" : @"Text", @"image" : @"text.alignleft"},
            kKayokoSearchCategoryLink : @{@"title" : @"Links", @"image" : @"link"},
            kKayokoSearchCategoryImage : @{@"title" : @"Images", @"image" : @"photo.fill"},
            kKayokoSearchCategoryPhone : @{@"title" : @"Phone Numbers", @"image" : @"phone.fill"},
            kKayokoSearchCategoryDate : @{@"title" : @"Dates", @"image" : @"calendar"},
            kKayokoSearchCategoryFlight : @{@"title" : @"Flights", @"image" : @"airplane"},
            kKayokoSearchCategoryAddress : @{@"title" : @"Addresses", @"image" : @"mappin.and.ellipse"}
        };
    });
    return metadata[identifier];
}

NSDictionary<NSString *, NSString *> *KayokoFilterSpecialApplicationMetadata(NSString *identifier) {
    NSString *value = [[identifier stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        lowercaseString];
    if ([value isEqualToString:@"continuity"] || [value isEqualToString:@"handoff"] ||
        [value isEqualToString:@"com.apple.continuity"]) {
        return @{@"title" : @"Continuity", @"image" : @"HandOff"};
    }
    if ([value isEqualToString:@"com.apple.spotlight"] || [value isEqualToString:@"spotlight"]) {
        return @{@"title" : @"Spotlight", @"image" : @"Spotlight"};
    }
    if ([value isEqualToString:@"com.apple.springboard"] || [value isEqualToString:@"springboard"]) {
        return @{@"title" : @"SpringBoard", @"image" : @"HomeScreen"};
    }
    return nil;
}

NSString *KayokoHistoryDatabasePath(void) {
    return jbroot(@"/var/mobile/Library/com.mlgm.kayoko/history-v4.sqlite");
}

static void KayokoPopulateAppCatalogError(sqlite3 *database, int code, NSError **error) {
    if (!error) {
        return;
    }
    const char *message = database ? sqlite3_errmsg(database) : sqlite3_errstr(code);
    *error = [NSError errorWithDomain:@"com.mlgm.kayoko.app-catalog"
                                code:code
                            userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithUTF8String:message]}];
}

NSArray<NSString *> *KayokoReadSearchAppBundleIdentifiers(sqlite3 *database, NSError **error) {
    const char *sql = "SELECT DISTINCT bundle_identifier FROM history_items "
                      "WHERE bundle_identifier <> '' ORDER BY bundle_identifier COLLATE NOCASE";
    sqlite3_stmt *statement = NULL;
    int result = sqlite3_prepare_v2(database, sql, -1, &statement, NULL);
    if (result != SQLITE_OK) {
        KayokoPopulateAppCatalogError(database, result, error);
        sqlite3_finalize(statement);
        return nil;
    }
    NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
    while ((result = sqlite3_step(statement)) == SQLITE_ROW) {
        const unsigned char *value = sqlite3_column_text(statement, 0);
        NSString *identifier = value ? [NSString stringWithUTF8String:(const char *)value] : nil;
        if ([identifier length] > 0) {
            [identifiers addObject:identifier];
        }
    }
    if (result != SQLITE_DONE) {
        KayokoPopulateAppCatalogError(database, result, error);
        sqlite3_finalize(statement);
        return nil;
    }
    sqlite3_finalize(statement);
    return identifiers;
}
