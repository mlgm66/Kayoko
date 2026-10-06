//
//  KayokoApplicationMetadataProvider.m
//  Kayoko
//

#import "KayokoApplicationMetadataProvider.h"
#import "KayokoFilterCatalog.h"
#import "KayokoPasteboardManager.h"

#import <objc/runtime.h>

static int const kKayokoApplicationIconFormatListRow = 1;
static int const kKayokoApplicationIconFormatSearchToken = 5;

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (IconCache)
+ (nullable instancetype)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier
                                                           format:(int)format
                                                            scale:(CGFloat)scale;
@end

@interface SBApplication : NSObject
@property(nonatomic, copy, readonly) NSString *displayName;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)bundleIdentifier;
@end

NS_ASSUME_NONNULL_END

@interface KayokoApplicationMetadataProvider ()
- (nullable SBApplication *)applicationForBundleIdentifier:(NSString *)bundleIdentifier;
@end

@implementation KayokoApplicationMetadataProvider

- (NSString *)displayNameForBundleIdentifier:(NSString *)bundleIdentifier {
    NSDictionary *special = KayokoFilterSpecialApplicationMetadata(bundleIdentifier);
    if (special) {
        return [[KayokoPasteboardManager localizationBundle] localizedStringForKey:special[@"title"]
                                                                             value:nil
                                                                             table:@"Tweak"];
    }

    NSString *displayName = [[self applicationForBundleIdentifier:bundleIdentifier] displayName];
    return [displayName length] > 0 ? displayName : bundleIdentifier;
}

- (nullable SBApplication *)applicationForBundleIdentifier:(NSString *)bundleIdentifier {
    return [[objc_getClass("SBApplicationController") sharedInstance] applicationWithBundleIdentifier:bundleIdentifier];
}

- (BOOL)hasApplicationForBundleIdentifier:(NSString *)bundleIdentifier {
    if (KayokoFilterSpecialApplicationMetadata(bundleIdentifier)) {
        return YES;
    }
    return [self applicationForBundleIdentifier:bundleIdentifier] != nil;
}

- (nullable UIImage *)applicationIconForBundleIdentifier:(NSString *)bundleIdentifier
                                                  format:(int)format
                                                   scale:(CGFloat)scale {
    NSString *effectiveBundleIdentifier = [bundleIdentifier length] > 0 ? bundleIdentifier : @"com.apple.WebSheet";
    UIImage *icon = [UIImage _applicationIconImageForBundleIdentifier:effectiveBundleIdentifier
                                                               format:format
                                                                scale:scale];
    if (!icon && ![effectiveBundleIdentifier isEqualToString:@"com.apple.WebSheet"]) {
        icon = [UIImage _applicationIconImageForBundleIdentifier:@"com.apple.WebSheet" format:format scale:scale];
    }
    return icon;
}

- (nullable UIImage *)iconForBundleIdentifier:(NSString *)bundleIdentifier {
    NSDictionary *special = KayokoFilterSpecialApplicationMetadata(bundleIdentifier);
    if (special) {
        return [UIImage imageNamed:special[@"image"] inBundle:[KayokoPasteboardManager localizationBundle]
            compatibleWithTraitCollection:nil];
    }

    return [self applicationIconForBundleIdentifier:bundleIdentifier
                                             format:kKayokoApplicationIconFormatListRow
                                              scale:[[UIScreen mainScreen] scale]];
}

- (nullable UIImage *)smallIconForBundleIdentifier:(NSString *)bundleIdentifier {
    NSDictionary *special = KayokoFilterSpecialApplicationMetadata(bundleIdentifier);
    if (special) {
        UIImage *icon = [UIImage imageNamed:[special[@"image"] stringByAppendingString:@"-Search"]
            inBundle:[KayokoPasteboardManager localizationBundle] compatibleWithTraitCollection:nil];
        return [icon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    }

    return [self applicationIconForBundleIdentifier:bundleIdentifier
                                             format:kKayokoApplicationIconFormatSearchToken
                                              scale:[[UIScreen mainScreen] scale]];
}

@end
