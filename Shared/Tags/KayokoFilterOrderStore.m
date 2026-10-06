#import "KayokoFilterOrderStore.h"
#import <CoreGraphics/CoreGraphics.h>
#import "KayokoPreferenceKeys.h"

@interface KayokoFilterOrderStore ()
@property(nonatomic, strong) NSUserDefaults *preferences;
@property(nonatomic, copy) NSDictionary<NSString *, NSArray<NSString *> *> *orders;
@end

@implementation KayokoFilterOrderStore

- (instancetype)init {
    return [self initWithPreferences:[[NSUserDefaults alloc] initWithSuiteName:kKayokoPreferencesIdentifier]];
}

- (instancetype)initWithPreferences:(NSUserDefaults *)preferences {
    self = [super init];
    if (self) {
        _preferences = preferences;
        [self reload];
    }
    return self;
}

- (NSArray<NSString *> *)uniqueIdentifiersFromValue:(id)value {
    NSMutableOrderedSet<NSString *> *identifiers = [NSMutableOrderedSet orderedSet];
    if ([value isKindOfClass:[NSArray class]]) {
        for (id identifier in value) {
            if ([identifier isKindOfClass:[NSString class]] && [identifier length] > 0) {
                [identifiers addObject:identifier];
            }
        }
    }
    return [identifiers array];
}

- (void)reload {
    [[self preferences] synchronize];
    NSMutableDictionary *orders = [NSMutableDictionary dictionary];
    for (NSString *key in @[kKayokoPreferenceKeyFilterSectionOrder, kKayokoPreferenceKeyFilterCategoryOrder,
                            kKayokoPreferenceKeyFilterApplicationOrder]) {
        orders[key] = [self uniqueIdentifiersFromValue:[[self preferences] objectForKey:key]];
    }
    [self setOrders:orders];
}

- (NSArray<NSString *> *)orderedIdentifiers:(NSArray<NSString *> *)identifiers forKey:(NSString *)key {
    NSArray<NSString *> *availableIdentifiers = [self uniqueIdentifiersFromValue:identifiers];
    NSSet *available = [NSSet setWithArray:availableIdentifiers];
    NSMutableOrderedSet<NSString *> *ordered = [NSMutableOrderedSet orderedSet];
    for (NSString *identifier in [self orders][key]) {
        if ([available containsObject:identifier]) {
            [ordered addObject:identifier];
        }
    }
    [ordered addObjectsFromArray:availableIdentifiers];
    return [ordered array];
}

- (BOOL)saveOrder:(NSArray<NSString *> *)order forKey:(NSString *)key error:(NSError **)error {
    NSArray<NSString *> *updatedOrder = [self uniqueIdentifiersFromValue:order];
    [self reload];
    if ([key isEqualToString:kKayokoPreferenceKeyFilterApplicationOrder]) {
        NSSet *visible = [NSSet setWithArray:updatedOrder];
        NSMutableArray<NSString *> *merged = [NSMutableArray array];
        NSUInteger next = 0;
        for (NSString *identifier in [self orders][key]) {
            if ([visible containsObject:identifier]) {
                [merged addObject:updatedOrder[next++]];
            } else {
                [merged addObject:identifier];
            }
        }
        while (next < [updatedOrder count]) {
            [merged addObject:updatedOrder[next++]];
        }
        updatedOrder = merged;
    }
    id previous = [[self preferences] objectForKey:key];
    [[self preferences] setObject:updatedOrder forKey:key];
    if (![[self preferences] synchronize]) {
        if (previous) {
            [[self preferences] setObject:previous forKey:key];
        } else {
            [[self preferences] removeObjectForKey:key];
        }
        [[self preferences] synchronize];
        if (error) {
            *error = [NSError errorWithDomain:@"com.mlgm.kayoko.filter-order"
                                        code:1
                                    userInfo:@{NSLocalizedDescriptionKey : @"Unable to Save Tag Order"}];
        }
        return NO;
    }
    NSMutableDictionary *orders = [[self orders] mutableCopy];
    orders[key] = [updatedOrder copy];
    [self setOrders:orders];
    return YES;
}

@end
