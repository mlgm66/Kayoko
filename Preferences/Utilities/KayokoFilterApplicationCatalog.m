#import "KayokoFilterApplicationCatalog.h"
#import "KayokoFilterApplicationBridge.h"
#import "KayokoFilterCatalog.h"
#import <MobileCoreServices/LSApplicationProxy.h>

@interface LSApplicationProxy (AltList)
- (NSString *)atl_nameToDisplay;
@end

@interface UIImage (KayokoApplicationIcon)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)identifier format:(int)format scale:(CGFloat)scale;
@end

NSArray<NSDictionary<NSString *, NSString *> *> *KayokoFilterApplicationEntries(NSBundle *bundle, NSError **error) {
    NSError *requestError = nil;
    NSArray<NSString *> *identifiers = [[KayokoFilterApplicationBridge sharedBridge] applicationIdentifiersWithError:&requestError];
    if (!identifiers) {
        NSLog(@"Kayoko application catalog request: %@", requestError);
        if (error) {
            *error = requestError;
        }
        return nil;
    }
    NSMutableArray *entries = [NSMutableArray array];
    for (NSString *identifier in identifiers) {
        NSDictionary *special = KayokoFilterSpecialApplicationMetadata(identifier);
        NSString *title;
        if (special) {
            title = [bundle localizedStringForKey:special[@"title"] value:nil table:@"Tweak"];
        } else {
            LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:identifier];
            if (![proxy isInstalled] || [proxy isPlaceholder]) {
                continue;
            }
            title = [proxy atl_nameToDisplay];
        }
        [entries addObject:@{@"identifier" : identifier, @"title" : [title length] > 0 ? title : identifier}];
    }
    return [entries sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        NSComparisonResult result = [left[@"title"] localizedStandardCompare:right[@"title"]];
        return result == NSOrderedSame ? [left[@"identifier"] localizedStandardCompare:right[@"identifier"]] : result;
    }];
}

UIImage *KayokoFilterApplicationIcon(NSString *identifier, NSBundle *bundle) {
    NSDictionary *special = KayokoFilterSpecialApplicationMetadata(identifier);
    if (special) {
        return [UIImage imageNamed:special[@"image"] inBundle:bundle compatibleWithTraitCollection:nil];
    }
    return [UIImage _applicationIconImageForBundleIdentifier:identifier format:1 scale:[[UIScreen mainScreen] scale]];
}
