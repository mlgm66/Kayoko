//
//  KayokoNotificationKeys.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>

static NSString *const kKayokoNotificationKeyCoreShow = @"com.mlgm.kayoko.core.show";
static NSString *const kKayokoLegacyNotificationKeyCoreShow = @"dev.traurige.kayoko.core.show";
static NSString *const kKayokoOriginalNotificationKeyCoreShow = @"codes.aurora.kayoko.core.show";
static NSString *const kKayokoNotificationKeyCoreHide = @"com.mlgm.kayoko.core.hide";
static NSString *const kKayokoLegacyNotificationKeyCoreHide = @"dev.traurige.kayoko.core.hide";
static NSString *const kKayokoNotificationKeyCoreReload = @"com.mlgm.kayoko.core.reload";
static NSString *const kKayokoNotificationKeyCoreCheckpointHistory = @"com.mlgm.kayoko.core.checkpoint-history";
static NSString *const kKayokoNotificationKeyCorePrepareMaintenance = @"com.mlgm.kayoko.core.prepare-maintenance";
static NSString *const kKayokoNotificationKeyCoreResetThumbnailMemoryCache =
    @"com.mlgm.kayoko.core.reset-thumbnail-memory-cache";
static NSString *const kKayokoNotificationKeyCoreClearFavorites = @"com.mlgm.kayoko.core.clear-favorites";
static NSString *const kKayokoNotificationKeyCoreClearHistory = @"com.mlgm.kayoko.core.clear-history";
static NSString *const kKayokoNotificationKeyHelperPaste = @"com.mlgm.kayoko.helper.paste";
static NSString *const kKayokoNotificationKeyHelperRestoreFocus = @"com.mlgm.kayoko.helper.restore-focus";
static NSString *const kKayokoNotificationKeyPreferencesReload = @"com.mlgm.kayoko.preferences.reload";
static NSString *const kKayokoNotificationKeyPreferencesHeightReload = @"com.mlgm.kayoko.preferences.height.reload";
static NSString *const kKayokoNotificationKeyExternalImportRequiresRestart =
    @"com.mlgm.kayoko.preferences.external-import-requires-restart";
static NSString *const kKayokoNotificationUserInfoKeyExternalImportSucceeded = @"succeeded";
static NSString *const kKayokoNotificationUserInfoKeyExternalImportSource = @"source";
static NSString *const kKayokoExternalImportSourceCopyLog = @"CopyLog";
static NSString *const kKayokoExternalImportSourceCopyVault = @"CopyVault";
static NSString *const kKayokoNotificationKeyPasteWillStart = @"com.mlgm.kayoko.paste.willstart";
static NSString *const kKayokoNotificationKeyPasteFeedback = @"com.mlgm.kayoko.paste.feedback";
