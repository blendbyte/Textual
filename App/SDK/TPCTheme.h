/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
 *       Please see Acknowledgements.pdf for additional information.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *  * Neither the name of Textual, "Codeux Software, LLC", nor the
 *    names of its contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *********************************************************************** */

#import "TVCLogLine.h"

NS_ASSUME_NONNULL_BEGIN

#define TPCThemeSettingsDisabledIndentationOffset	 -99

#define TPCThemeSettingsNewestTemplateEngineVersion		4

typedef NS_ENUM(NSUInteger, TPCThemeAppearanceType) {
	TPCThemeAppearanceTypeDefault = 0, // Automatically picked based on window appearance
	TPCThemeAppearanceTypeDark,
	TPCThemeAppearanceTypeLight
};

typedef NS_ENUM(NSUInteger, TPCThemeStorageLocation) {
	TPCThemeStorageLocationUnknown = 0,
	TPCThemeStorageLocationBundle,
	TPCThemeStorageLocationCustom
};

typedef NS_ENUM(NSUInteger, TPCThemeSettingsNicknameColorStyle) {
	TPCThemeSettingsNicknameColorStyleDefault = 0, // Automatically picked based on appearance
	TPCThemeSettingsNicknameColorStyleDark,
	TPCThemeSettingsNicknameColorStyleLight
};

/* If a theme is modified in such a way after it is initialized
 that it can no longer be used, then this notification is posted.
 A way, amongst many, in which the integrity of a theme can
 be compromised is by deleting the CSS or JavaScript file. */
TEXTUAL_EXTERN NSNotificationName const TPCThemeIntegrityCompromisedNotification;

/* If theme has been restored to a usable state. */
TEXTUAL_EXTERN NSNotificationName const TPCThemeIntegrityRestoredNotification;

/* If the theme has been deleted. Drop reference to theme object
 when this occurs. Holding a reference to a theme object after
 it has been deleted can result in undefined behavior especially
 if another theme is installed using the same URL. */
TEXTUAL_EXTERN NSNotificationName const TPCThemeWasDeletedNotification;

/* The theme can change the variety to match appearance changes,
 or when one variety becomes compromised and another must be used. */
/* Notification used for first case. */
TEXTUAL_EXTERN NSNotificationName const TPCThemeAppearanceChangedNotification;

/* Notification used for second case. */
TEXTUAL_EXTERN NSNotificationName const TPCThemeVarietyChangedNotification;

/* A CSS or JavaScript file within the global variety or the variety
 in use was modified. */
TEXTUAL_EXTERN NSNotificationName const TPCThemeWasModifiedNotification;

@class GRMustacheTemplate, GRMustacheTemplateRepository;
@class TPCThemeSettings;

@interface TPCTheme : NSObject
@property (readonly, copy) NSString *name;

@property (readonly, copy) NSURL *originalURL;
@property (readonly) TPCThemeStorageLocation storageLocation;

@property (readonly) BOOL usable; // If the theme is in a state that can be selected by the user.

@property (readonly) TPCThemeAppearanceType appearance;

/* Global files are listed first with variety specific files second. */
/* These properties DO NOT list all files of these types.
 Only files named "design.css" and "scripts.js" respectively. */
@property (readonly, copy) NSArray<NSURL *> *cssFiles;
@property (readonly, copy) NSArray<NSURL *> *jsFiles;

@property (readonly, copy) NSArray<NSString *> *cssFilePaths;
@property (readonly, copy) NSArray<NSString *> *jsFilePaths;

/* Order of repositories is: variety specific -> global -> app */
@property (readonly, copy) NSArray<GRMustacheTemplateRepository *> *templateRepositories;

/* Settings */
@property (readonly, strong) TPCThemeSettings *settings;

/* Temporary location */
/* Themes are copied to a temporary location when they are in use. */
/* These properties remap the relevant URLs to the temporary location. */
/* These files will not exist until the theme is in use. */
@property (readonly, copy) NSURL *temporaryURL;

@property (readonly, copy) NSArray<NSURL *> *temporaryCSSFiles;
@property (readonly, copy) NSArray<NSURL *> *temporaryJSFiles;

@property (readonly, copy) NSArray<NSString *> *temporaryCSSFilePaths;
@property (readonly, copy) NSArray<NSString *> *temporaryJSFilePaths;

- (instancetype)init NS_UNAVAILABLE;

/* Templates */
- (nullable GRMustacheTemplate *)templateWithLineType:(TVCLogLineType)type;
- (nullable GRMustacheTemplate *)templateWithName:(NSString *)name;
@end

@interface TPCThemeSettings : NSObject
@property (readonly) TPCThemeAppearanceType appearance;
@property (readonly) BOOL invertSidebarColors;
@property (readonly) BOOL js_postHandleEventNotifications;
@property (readonly) BOOL js_postAppearanceChangesNotification;
@property (readonly) BOOL js_postPreferencesDidChangesNotifications;
@property (readonly) BOOL usesIncompatibleTemplateEngineVersion;
@property (readonly, copy, nullable) NSFont *themeChannelViewFont;
@property (readonly, copy, nullable) NSString *themeNicknameFormat;
@property (readonly, copy, nullable) NSString *themeTimestampFormat;
@property (readonly, copy, nullable) NSString *settingsKeyValueStoreName;
@property (readonly, copy, nullable) NSColor *channelViewOverlayColor;
@property (readonly, copy, nullable) NSColor *underlyingWindowColor;
@property (readonly) BOOL underlyingWindowColorIsDark;
@property (readonly) double indentationOffset;
@property (readonly) TPCThemeSettingsNicknameColorStyle nicknameColorStyle;
@property (readonly) NSUInteger templateEngineVersion;

- (instancetype)init NS_UNAVAILABLE;

- (nullable id)styleSettingsRetrieveValueForKey:(NSString *)key error:(NSString * _Nullable * _Nullable)resultError;
- (BOOL)styleSettingsSetValue:(nullable id)objectValue forKey:(NSString *)objectKey error:(NSString * _Nullable * _Nullable)resultError;
@end

NS_ASSUME_NONNULL_END
