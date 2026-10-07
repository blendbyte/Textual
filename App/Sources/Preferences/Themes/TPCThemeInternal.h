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

#import "TPCThemePrivate.h"
#import "TPCThemeVarietyPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* Shared by TPCTheme.m, TPCThemeSettings.m and TPCThemeVariety.m only */

@interface TPCTheme ()
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, copy, readwrite) NSURL *originalURL;
@property (nonatomic, copy, readwrite) NSURL *temporaryURL;
@property (nonatomic, assign, readwrite) TPCThemeStorageLocation storageLocation;
@property (nonatomic, assign, readwrite) BOOL usable;
@property (nonatomic, strong) TPCThemeVariety *globalVariety;
@property (nonatomic, strong, nullable) TPCThemeVariety *variety;
@property (nonatomic, copy) NSArray<TPCThemeVariety *> *varieties;
@property (nonatomic, strong, nullable) NSCache *templateCache;
@property (nonatomic, copy, readwrite) NSArray<NSURL *> *cssFiles;
@property (nonatomic, copy, readwrite) NSArray<NSURL *> *jsFiles;
@property (nonatomic, copy, readwrite) NSArray<NSURL *> *temporaryCSSFiles;
@property (nonatomic, copy, readwrite) NSArray<NSURL *> *temporaryJSFiles;
@property (nonatomic, copy, readwrite) NSArray<GRMustacheTemplateRepository *> *templateRepositories;
@property (nonatomic, strong) GRMustacheTemplateRepository *defaultTemplateRepository;
@property (nonatomic, strong, readwrite) TPCThemeSettings *settings;
@property (nonatomic, strong, nullable) XRFileSystemMonitor *fileSystemMonitor;
@end

@interface TPCThemeSettings ()
@property (nonatomic, assign, readwrite) BOOL supportsMultipleAppearances;
@property (nonatomic, assign, readwrite) BOOL invertSidebarColors;
@property (nonatomic, assign, readwrite) BOOL js_postHandleEventNotifications;
@property (nonatomic, assign, readwrite) BOOL js_postAppearanceChangesNotification;
@property (nonatomic, assign, readwrite) BOOL js_postPreferencesDidChangesNotifications;
@property (nonatomic, assign, readwrite) BOOL usesIncompatibleTemplateEngineVersion;
@property (nonatomic, copy, readwrite, nullable) NSFont *themeChannelViewFont;
@property (nonatomic, copy, readwrite, nullable) NSString *themeNicknameFormat;
@property (nonatomic, copy, readwrite, nullable) NSString *themeTimestampFormat;
@property (nonatomic, copy, readwrite, nullable) NSString *settingsKeyValueStoreName;
@property (nonatomic, copy, readwrite, nullable) NSColor *channelViewOverlayColor;
@property (nonatomic, copy, readwrite, nullable) NSColor *underlyingWindowColor;
@property (nonatomic, copy, readwrite, nullable) NSURL *cssFile;
@property (nonatomic, copy, readwrite, nullable) NSURL *jsFile;
@property (nonatomic, assign, readwrite) double indentationOffset;
@property (nonatomic, assign, readwrite) TPCThemeSettingsNicknameColorStyle nicknameColorStyle;
@property (nonatomic, assign, readwrite) NSUInteger templateEngineVersion;

- (instancetype)initWithTheme:(TPCTheme *)theme NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
