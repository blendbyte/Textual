/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
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

#import "NSObjectHelperPrivate.h"
#import "TXAppearance.h"
#import "TPCApplicationInfo.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCResourceManager.h"
#import "TPCThemeInternal.h"

NS_ASSUME_NONNULL_BEGIN

#define _templateEngineVersionMaximum			TPCThemeSettingsNewestTemplateEngineVersion
#define _templateEngineVersionMinimum			TPCThemeSettingsNewestTemplateEngineVersion

#pragma mark -
#pragma mark Theme Settings

@implementation TPCThemeSettings

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithTheme:(TPCTheme *)theme
{
	NSParameterAssert(theme != nil);

	if ((self = [super init])) {
		[self _loadSettingsForTheme:theme];

		return self;
	}

	return nil;
}

- (void)_loadSettingsForTheme:(TPCTheme *)theme
{
	/* Combine both setting dictionaries */
	TPCThemeVariety *globalVariety = theme.globalVariety;

	NSDictionary *settings = globalVariety.settings;

	TPCThemeVariety *variety = theme.variety;

	if (variety && variety.isGlobalVariety == NO) {
		NSDictionary *settingsNew = variety.settings;

		if (settings == nil) {
			settings = settingsNew;
		} else {
			settings = [settings dictionaryByAddingEntries:variety.settings];
		}
	}

	/* Populate settings */
	self.themeChannelViewFont = [self.class _fontForKey:@"Override Channel Font" fromDictionary:settings];

	self.themeNicknameFormat = [self.class _stringForKey:@"Nickname Format" fromDictionary:settings];
	self.themeTimestampFormat = [self.class _stringForKey:@"Timestamp Format" fromDictionary:settings];

	self.invertSidebarColors = [settings boolForKey:@"Force Invert Sidebars"];

	self.channelViewOverlayColor = [self.class _colorForKey:@"Channel View Overlay Color" fromDictionary:settings];
	self.underlyingWindowColor = [self.class _colorForKey:@"Underlying Window Color" fromDictionary:settings];

	self.settingsKeyValueStoreName = [self.class _stringForKey:@"Key-value Store Name" fromDictionary:settings];

	self.js_postHandleEventNotifications = [settings boolForKey:@"Post Textual.handleEvent() Notifications"];
	self.js_postAppearanceChangesNotification = [settings boolForKey:@"Post Textual.appearanceDidChange() Notifications"];
	self.js_postPreferencesDidChangesNotifications = [settings boolForKey:@"Post Textual.preferencesDidChange() Notifications"];

	/* Disable indentation? */
	id indentationOffset = settings[@"Indentation Offset"];

	if (indentationOffset == nil) {
		self.indentationOffset = TPCThemeSettingsDisabledIndentationOffset;
	} else {
		double indentationOffsetDouble = [indentationOffset doubleValue];

		if (indentationOffsetDouble < 0.0) {
			self.indentationOffset = TPCThemeSettingsDisabledIndentationOffset;
		} else {
			self.indentationOffset = indentationOffsetDouble;
		}
	}

	/* Nickname color style */
	TPCThemeAppearanceType appearance = variety.appearance;

	id nicknameColorStyle = settings[@"Nickname Color Style"];

	if ([nicknameColorStyle isEqual:@"HSL-light"]) {
		self.nicknameColorStyle = TPCThemeSettingsNicknameColorStyleLight;
	} else if ([nicknameColorStyle isEqual:@"HSL-dark"]) {
		self.nicknameColorStyle = TPCThemeSettingsNicknameColorStyleDark;
	} else if (appearance == TPCThemeAppearanceTypeLight) {
		self.nicknameColorStyle = TPCThemeSettingsNicknameColorStyleLight;
	} else if (appearance == TPCThemeAppearanceTypeDark) {
		self.nicknameColorStyle = TPCThemeSettingsNicknameColorStyleDark;
	} else {
		if (self.underlyingWindowColorIsDark == NO) {
			self.nicknameColorStyle = TPCThemeSettingsNicknameColorStyleLight;
		} else {
			self.nicknameColorStyle = TPCThemeSettingsNicknameColorStyleDark;
		}
	}

	/* Get style template version */
	BOOL usesIncompatibleTemplateEngineVersion = YES;

	NSUInteger templateEngineVersion = 0;

	NSDictionary<NSString *, NSNumber *> *templateVersions = [settings dictionaryForKey:@"Template Engine Versions"];

	{
		NSString *applicationVersion = [TPCApplicationInfo applicationVersionShort];

		NSUInteger targetVersion = [templateVersions unsignedIntegerForKey:applicationVersion];

		if (NSNumberInRange(targetVersion, _templateEngineVersionMinimum, _templateEngineVersionMaximum)) {
			templateEngineVersion = targetVersion;

			usesIncompatibleTemplateEngineVersion = NO;
		}
	}

	if (templateEngineVersion == 0) {
		NSUInteger defaultVersion = [templateVersions unsignedIntegerForKey:@"default"];

		if (NSNumberInRange(defaultVersion, _templateEngineVersionMinimum, _templateEngineVersionMaximum)) {
			templateEngineVersion = defaultVersion;

			usesIncompatibleTemplateEngineVersion = NO;
		}
	}

	if (templateEngineVersion == 0) {
		templateEngineVersion = _templateEngineVersionMaximum;
	}

	self.usesIncompatibleTemplateEngineVersion = usesIncompatibleTemplateEngineVersion;

	self.templateEngineVersion = templateEngineVersion;
}

#pragma mark -
#pragma mark Getters

- (BOOL)underlyingWindowColorIsDark
{
	NSColor *windowColor = self.underlyingWindowColor;

	if (windowColor == nil) {
		return NO;
	}

	@try {
		CGFloat brightness = windowColor.brightnessComponent;

		if (brightness < 0.5) {
			return YES;
		}
	}
	@catch (NSException *exception) {
		LogToConsoleError("Caught exception: %{public}@", exception.reason);
		LogStackTrace();
	}

	return NO;
}

#pragma mark -
#pragma mark Setting Loaders

+ (nullable NSString *)_stringForKey:(NSString *)key fromDictionary:(NSDictionary<NSString *, id> *)dic
{
	NSParameterAssert(key != nil);
	NSParameterAssert(dic != nil);

	NSString *stringValue = [dic stringForKey:key];

	/* An empty string should not be considered a valid value */
	if (stringValue.length == 0) {
		return nil;
	}

	return stringValue;
}

+ (nullable NSColor *)_colorForKey:(NSString *)key fromDictionary:(NSDictionary<NSString *, id> *)dic
{
	NSParameterAssert(key != nil);
	NSParameterAssert(dic != nil);

	NSString *colorValue = [dic stringForKey:key];

	return [NSColor colorWithHexadecimalValue:colorValue];
}

+ (nullable NSFont *)_fontForKey:(NSString *)key fromDictionary:(NSDictionary<NSString *, id> *)dic
{
	NSParameterAssert(key != nil);
	NSParameterAssert(dic != nil);

	NSDictionary<NSString *, id> *fontDictionary = [dic dictionaryForKey:key];

	if (fontDictionary == nil) {
		return nil;
	}

	NSString *fontName = [fontDictionary stringForKey:@"Font Name"];

	if (fontName == nil || [NSFont fontIsAvailable:fontName] == NO) {
		return nil;
	}

	CGFloat fontSize = [fontDictionary doubleForKey:@"Font Size"];

	if (fontSize < 5.0) {
		return nil;
	}

	return [NSFont fontWithName:fontName size:fontSize];
}

#pragma mark -
#pragma mark Style Settings

- (nullable NSString *)_keyValueStoreName
{
	NSString *storeName = self.settingsKeyValueStoreName;

	if (storeName.length == 0) {
		return nil;
	}

	return [NSString stringWithFormat:@"Internal Theme Settings Key-value Store -> %@", storeName];
}

- (nullable id)styleSettingsRetrieveValueForKey:(NSString *)key error:(NSString * _Nullable *)resultError
{
	if (key == nil || key.length == 0) {
		if ( resultError) {
			*resultError = @"Empty key value";
		}

		return nil;
	}

	NSString *storeKey = [self _keyValueStoreName];

	if (storeKey == nil) {
		if ( resultError) {
			*resultError = @"Empty key-value store name in settings.plist — Set the key \"Key-value Store Name\" in settings.plist as a string. The current style name is the recommended value.";
		}

		return nil;
	}

	NSDictionary *styleSettings = [RZUserDefaults() dictionaryForKey:storeKey];

	if (styleSettings == nil) {
		return nil;
	}

	return styleSettings[key];
}

- (BOOL)styleSettingsSetValue:(nullable id)objectValue forKey:(NSString *)objectKey error:(NSString * _Nullable *)resultError
{
	if (objectKey == nil || objectKey.length <= 0) {
		if (resultError) {
			*resultError = @"Empty key value";
		}

		return NO;
	}

	NSString *storeKey = [self _keyValueStoreName];

	if (storeKey == nil) {
		if (resultError) {
			*resultError = @"Empty key-value store name in settings.plist — Set the key \"Key-value Store Name\" in settings.plist as a string. The current style name is the recommended value.";
		}

		return NO;
	}

	BOOL removeValue = (objectValue == nil || [objectValue isKindOfClass:[NSNull class]]);

	NSDictionary *styleSettings = [RZUserDefaults() dictionaryForKey:storeKey];

	NSMutableDictionary<NSString *, id> *styleSettingsMutable = nil;

	if (styleSettings == nil) {
		if (removeValue) {
			return YES;
		}

		styleSettingsMutable = [NSMutableDictionary dictionaryWithCapacity:1];
	} else {
		styleSettingsMutable = [styleSettings mutableCopy];
	}

	if (removeValue) {
		[styleSettingsMutable removeObjectForKey:objectKey];
	} else {
		styleSettingsMutable[objectKey] = objectValue;
	}

	[RZUserDefaults() setObject:[styleSettingsMutable copy] forKey:storeKey];

	return YES;
}

@end

NS_ASSUME_NONNULL_END
