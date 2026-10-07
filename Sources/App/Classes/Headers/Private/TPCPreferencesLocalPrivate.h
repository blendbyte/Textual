/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2019 Codeux Software, LLC & respective contributors.
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

#import "TPCPreferencesPrivate.h"
#import "TPCPreferencesLocal.h"

NS_ASSUME_NONNULL_BEGIN

@interface TPCPreferences (TPCPreferencesLocalPrivate)
+ (void)initPreferences;

+ (void)setAppNapEnabled:(BOOL)appNapEnabled;

+ (void)setDeveloperModeEnabled:(BOOL)developerModeEnabled;

+ (void)setLogToDisk:(BOOL)logToDisk;

+ (void)setOnlySpeakEventsForSelection:(BOOL)onlySpeakEventsForSelection;

+ (void)setChannelMessageSpeakChannelName:(BOOL)channelMessageSpeakChannelName;
+ (void)setChannelMessageSpeakNickname:(BOOL)channelMessageSpeakNickname;

+ (void)setHighlightCurrentNickname:(BOOL)highlightCurrentNickname;

+ (void)setLocationToSendNotices:(TXNoticeSendLocation)locationToSendNotices;

+ (void)setAppearance:(TXPreferredAppearance)appearance;

+ (void)setThemeName:(NSString *)value;
+ (void)setThemeNameWithExistenceCheck:(NSString *)value;

+ (void)setThemeChannelViewFontName:(NSString *)value;
+ (void)setThemeChannelViewFontNameWithExistenceCheck:(NSString *)value;

+ (void)setThemeChannelViewFontSize:(CGFloat)value;

+ (void)setThemeNicknameFormatPreferenceUserConfigurable:(BOOL)themeNicknameFormatPreferenceUserConfigurable;
+ (void)setThemeTimestampFormatPreferenceUserConfigurable:(BOOL)themeTimestampFormatPreferenceUserConfigurable;
+ (void)setThemeChannelViewFontPreferenceUserConfigurable:(BOOL)themeChannelViewFontPreferenceUserConfigurable;

+ (void)setThemeUserStyleSheetRules:(nullable NSString *)themeUserStyleSheetRules;

+ (void)setScrollbackSaveLimit:(NSUInteger)scrollbackSaveLimit;
+ (void)setScrollbackVisibleLimit:(NSUInteger)scrollbackVisibleLimit;

+ (void)setShowInlineMedia:(BOOL)showInlineMedia;

+ (void)setSoundIsMuted:(BOOL)soundIsMuted;

+ (void)setSound:(nullable NSString *)value forEvent:(TXNotificationType)event;

+ (void)setNotificationEnabled:(BOOL)value forEvent:(TXNotificationType)event;
+ (void)setDisabledWhileAway:(BOOL)value forEvent:(TXNotificationType)event;
+ (void)setBounceDockIcon:(BOOL)value forEvent:(TXNotificationType)event;
+ (void)setBounceDockIconRepeatedly:(BOOL)value forEvent:(TXNotificationType)event;
+ (void)setEventIsSpoken:(BOOL)value forEvent:(TXNotificationType)event;

+ (nullable NSString *)keyForEvent:(TXNotificationType)event category:(NSString *)category;

+ (void)setFileTransferPortRangeStart:(uint16_t)value;
+ (void)setFileTransferPortRangeEnd:(uint16_t)value;

+ (void)setTabCompletionSuffix:(NSString *)value;

+ (void)setClientList:(nullable NSArray<NSDictionary *> *)clientList;

+ (void)cleanUpHighlightKeywords;

+ (void)setTextFieldAutomaticSpellCheck:(BOOL)value;
+ (void)setTextFieldAutomaticGrammarCheck:(BOOL)value;
+ (void)setTextFieldAutomaticSpellCorrection:(BOOL)value;
+ (void)setTextFieldSmartCopyPaste:(BOOL)value;
+ (void)setTextFieldSmartQuotes:(BOOL)value;
+ (void)setTextFieldSmartDashes:(BOOL)value;
+ (void)setTextFieldSmartLinks:(BOOL)value;
+ (void)setTextFieldDataDetectors:(BOOL)value;
+ (void)setTextFieldTextReplacement:(BOOL)value;

+ (void)setWebKit2Enabled:(BOOL)webKit2Enabled;
@end

NS_ASSUME_NONNULL_END
