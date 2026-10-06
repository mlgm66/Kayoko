//
//  KayokoRootListController.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoRootListController.h"
#import "KayokoNotificationKeys.h"
#import "KayokoPreferenceKeys.h"
#import "KayokoRespringControllerSupport.h"
#import "KayokoSearchPresentation.h"
#import "KayokoSliderCell.h"

#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <roothide.h>

@interface NSConcreteNotification : NSNotification
@end

@interface PSListController (Private)
- (void)_returnKeyPressed:(NSConcreteNotification *)notification;
@end



NS_ASSUME_NONNULL_BEGIN

@interface KayokoRootListController () <UISearchResultsUpdating>
- (void)presentExternalImportRestartReminderIfNeeded;
- (void)updateOverlayWindowLevelSpecifierAvailability;
@end

NS_ASSUME_NONNULL_END


@implementation KayokoRootListController {
    ActivationMethod _lastActivationMethod;
    BOOL _hasActivationMethodSnapshot;
    UISearchController *_testInputSearchController;
    BOOL _searchPositionedAtTop;
    BOOL _externalImportRestartReminderPending;
    BOOL _externalImportRestartReminderSucceeded;
    NSString *_externalImportRestartReminderSource;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    [self configureTestInputSearchController];

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *title = [bundle localizedStringForKey:@"Respring" value:nil table:@"Root"];
    UIBarButtonItem *respringButton = [[UIBarButtonItem alloc] initWithTitle:title
                                                                       style:UIBarButtonItemStyleDone
                                                                      target:self
                                                                      action:@selector(respringPrompt)];

    [[self navigationItem] setLargeTitleDisplayMode:UINavigationItemLargeTitleDisplayModeNever];
    [[self navigationItem] setRightBarButtonItem:respringButton];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(externalImportRequiresRestart:)
                                                 name:kKayokoNotificationKeyExternalImportRequiresRestart
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Test Input Search

- (void)configureTestInputSearchController {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    _testInputSearchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    _testInputSearchController.searchResultsUpdater = self;
    _testInputSearchController.searchBar.placeholder = [bundle localizedStringForKey:@"Wishing on a star…"
                                                                               value:nil
                                                                               table:@"Root"];

    KayokoConfigureSearchPresentation(self, _testInputSearchController);
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    (void)searchController;
}

#pragma mark - Specifiers

- (NSArray<PSSpecifier *> *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        [self configureConditionalFootersInSpecifiers:_specifiers];
        [self updateOverlayWindowLevelSpecifierAvailability];
    }

    return _specifiers;
}

- (void)configureConditionalFootersInSpecifiers:(NSArray<PSSpecifier *> *)specifiers {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    for (PSSpecifier *specifier in specifiers) {
        NSString *preferenceKey = [specifier propertyForKey:@"hideFooterTextAfterPreferenceKey"];
        NSString *condensedFooterText = [specifier propertyForKey:@"condensedFooterText"];
        if (![preferenceKey isKindOfClass:[NSString class]] || [preferenceKey length] == 0 ||
            ![condensedFooterText isKindOfClass:[NSString class]] || [condensedFooterText length] == 0) {
            continue;
        }

        NSString *defaultsIdentifier = [specifier propertyForKey:@"hideFooterTextAfterPreferenceDefaults"];
        NSUserDefaults *userDefaults = [defaultsIdentifier length] > 0
                                           ? [[NSUserDefaults alloc] initWithSuiteName:defaultsIdentifier]
                                           : [NSUserDefaults standardUserDefaults];
        if ([userDefaults boolForKey:preferenceKey]) {
            NSString *localizedFooterText = [bundle localizedStringForKey:condensedFooterText value:nil table:@"Root"];
            [specifier setProperty:localizedFooterText forKey:@"footerText"];
        }
    }
}

#pragma mark - Preference State

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateOverlayWindowLevelSpecifierAvailability];

    id<UIViewControllerTransitionCoordinator> transitionCoordinator = [self transitionCoordinator];
    if (![transitionCoordinator isInteractive]) {
        [[self navigationController] setToolbarHidden:YES animated:animated];
    }

    ActivationMethod currentActivationMethod = [self currentActivationMethod];
    if (!_hasActivationMethodSnapshot) {
        _lastActivationMethod = currentActivationMethod;
        _hasActivationMethodSnapshot = YES;
        return;
    }

    if (currentActivationMethod != _lastActivationMethod) {
        _lastActivationMethod = currentActivationMethod;
        [self promptToRespring];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    KayokoRevealSearchOnFirstAppearance(self, self.table, &_searchPositionedAtTop);
    [[self navigationController] setToolbarHidden:YES animated:animated];
    [self presentExternalImportRestartReminderIfNeeded];
}

- (void)externalImportRequiresRestart:(NSNotification *)notification {
    _externalImportRestartReminderPending = YES;
    _externalImportRestartReminderSucceeded =
        [notification.userInfo[kKayokoNotificationUserInfoKeyExternalImportSucceeded] boolValue];
    NSString *source = notification.userInfo[kKayokoNotificationUserInfoKeyExternalImportSource];
    _externalImportRestartReminderSource = [source isKindOfClass:[NSString class]] ? [source copy] : nil;
}

- (void)presentExternalImportRestartReminderIfNeeded {
    if (!_externalImportRestartReminderPending || self.presentedViewController) {
        return;
    }
    _externalImportRestartReminderPending = NO;

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *message = nil;
    if (_externalImportRestartReminderSucceeded && [_externalImportRestartReminderSource length] > 0) {
        NSString *format = [bundle localizedStringForKey:@"%@ data was imported successfully. Restart SpringBoard "
                                                          "now to finish the import and continue using Kayoko."
                                                   value:nil
                                                   table:@"Root"];
        message = [NSString stringWithFormat:format, _externalImportRestartReminderSource];
    } else if (_externalImportRestartReminderSucceeded) {
        message = [bundle localizedStringForKey:@"The data was imported successfully. Restart SpringBoard now to "
                                                 "finish the import and continue using Kayoko."
                                          value:nil
                                          table:@"Root"];
    } else {
        message = [bundle localizedStringForKey:@"Kayoko entered maintenance mode before the import failed. Restart "
                                                 "SpringBoard now to continue using Kayoko."
                                          value:nil
                                          table:@"Root"];
    }
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Restart Required" value:nil table:@"Root"]
                         message:message
                  preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *restartAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Respring Now"
                                                                                          value:nil
                                                                                          table:@"Root"]
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction *action) {
                                                            (void)action;
                                                            [self respring];
                                                          }];
    [alert addAction:restartAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (ActivationMethod)currentActivationMethod {
    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:kKayokoPreferencesIdentifier];
    ActivationMethod activationMethod = [userDefaults integerForKey:kKayokoPreferenceKeyActivationMethod];
    return activationMethod == 0 ? kKayokoPreferenceKeyActivationMethodDefaultValue : activationMethod;
}

- (void)updateOverlayWindowLevelSpecifierAvailability {
    PSSpecifier *levelSpecifier = nil;
    for (PSSpecifier *specifier in _specifiers) {
        if ([[specifier propertyForKey:@"id"] isEqualToString:@"OverlayWindowLevel"]) {
            levelSpecifier = specifier;
            break;
        }
    }
    if (!levelSpecifier) {
        return;
    }

    NSUserDefaults *preferences = [[NSUserDefaults alloc] initWithSuiteName:kKayokoPreferencesIdentifier];
    [preferences registerDefaults:@{
        kKayokoPreferenceKeyOverlayWindowLevelMode : @(kKayokoPreferenceKeyOverlayWindowLevelModeDefaultValue),
    }];
    BOOL usesCustomLevel =
        [preferences integerForKey:kKayokoPreferenceKeyOverlayWindowLevelMode] == kKayokoOverlayWindowLevelModeCustom;
    [levelSpecifier setProperty:@(usesCustomLevel) forKey:@"enabled"];

    PSTableCell *cachedCell = [self cachedCellForSpecifier:levelSpecifier];
    if ([cachedCell isKindOfClass:[KayokoSliderCell class]]) {
        [(KayokoSliderCell *)cachedCell setKayokoControlEnabled:usesCustomLevel];
    }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];

    if ([[specifier propertyForKey:@"key"] isEqualToString:kKayokoPreferenceKeyOverlayWindowLevelMode]) {
        [self updateOverlayWindowLevelSpecifierAvailability];
    }

    if ([[specifier propertyForKey:@"key"] isEqualToString:kKayokoPreferenceKeyEnabled] ||
        [[specifier propertyForKey:@"key"] isEqualToString:kKayokoPreferenceKeyActivationMethod] ||
        [[specifier propertyForKey:@"key"] isEqualToString:kKayokoPreferenceKeyAutomaticallyPaste]) {
        if ([[specifier propertyForKey:@"key"] isEqualToString:kKayokoPreferenceKeyActivationMethod]) {
            _lastActivationMethod = [self currentActivationMethod];
            _hasActivationMethodSnapshot = YES;
        }
        [self promptToRespring];
    }
}

#pragma mark - Actions

- (void)_returnKeyPressed:(NSConcreteNotification *)notification {
    [[self view] endEditing:YES];
    [super _returnKeyPressed:notification];
}

- (void)respringPrompt {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    UIAlertController *respringAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:@"Respringing will restart SpringBoard and close all "
                                                               @"apps. Unsaved work may be lost."
                                                         value:nil
                                                         table:@"Root"]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *respringAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Respring Now"
                                                                                           value:nil
                                                                                           table:@"Root"]
                                                             style:UIAlertActionStyleDestructive
                                                           handler:^(UIAlertAction *action) {
                                                             [self respring];
                                                           }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Cancel"
                                                                                         value:nil
                                                                                         table:@"Root"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [respringAlert addAction:respringAction];
    [respringAlert addAction:cancelAction];

    [self presentViewController:respringAlert animated:YES completion:nil];
}

- (void)showKayoko {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kKayokoNotificationKeyCoreShow, nil, nil, YES);
}



#pragma mark - Cell Helpers

- (UISlider *_Nullable)findSliderInView:(UIView *)view {
    if ([view isKindOfClass:[UISlider class]]) {
        return (UISlider *)view;
    }
    for (UIView *subview in view.subviews) {
        UISlider *slider = [self findSliderInView:subview];
        if (slider) {
            return slider;
        }
    }
    return nil;
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
    NSString *key = [specifier propertyForKey:@"cell"];
    if ([key isEqualToString:@"PSButtonCell"]) {
        UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
        NSNumber *isDestructiveValue = [specifier propertyForKey:@"isDestructive"];
        BOOL isDestructive = [isDestructiveValue boolValue];
        cell.textLabel.textColor = isDestructive ? [UIColor systemRedColor] : [UIColor systemBlueColor];
        cell.textLabel.highlightedTextColor = isDestructive ? [UIColor systemRedColor] : [UIColor systemBlueColor];
        return cell;
    }
    if ([key isEqualToString:@"PSSliderCell"]) {
        UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
        NSNumber *isContinuousValue = [specifier propertyForKey:@"isContinuous"];
        BOOL isContinuous = [isContinuousValue boolValue];
        UISlider *slider = [self findSliderInView:cell];
        if (slider) {
            slider.continuous = isContinuous;
        }
        return cell;
    }
    if ([key isEqualToString:@"PSLinkListCell"]) {
        NSString *detail = [specifier propertyForKey:@"detail"];
        if ([detail isEqualToString:@"KayokoListItemsController"]) {
            UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
            NSBundle *bundle = [NSBundle bundleForClass:[self class]];

            ActivationMethod currentOptions = [self currentActivationMethod];
            NSArray<NSNumber *> *validValues = [specifier propertyForKey:@"validValues"];
            NSArray<NSString *> *validTitles = [specifier propertyForKey:@"validTitles"];
            NSMutableArray<NSString *> *selectedTitles = [NSMutableArray array];
            for (NSUInteger i = 0; i < validValues.count; i++) {
                NSNumber *value = validValues[i];
                if (currentOptions & [value integerValue]) {
                    [selectedTitles addObject:[bundle localizedStringForKey:validTitles[i] value:nil table:@"Root"]];
                }
            }
            NSString *detailText;
            if (selectedTitles.count == 1) {
                detailText = selectedTitles[0];
            } else if (selectedTitles.count == 2) {
                NSString *format = [bundle localizedStringForKey:@"%@ and %@" value:nil table:@"Root"];
                detailText = [NSString stringWithFormat:format, selectedTitles[0], selectedTitles[1]];
            } else if (selectedTitles.count > 2) {
                NSString *format = [bundle localizedStringForKey:@"%@ and %d others" value:nil table:@"Root"];
                detailText = [NSString stringWithFormat:format, selectedTitles[0], (int)selectedTitles.count - 1];
            } else {
                detailText = @"";
            }

            cell.detailTextLabel.text = detailText;
            return cell;
        }
    }
    return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return 20.0;
    }
    return [super tableView:tableView heightForHeaderInSection:section];
}

@end
