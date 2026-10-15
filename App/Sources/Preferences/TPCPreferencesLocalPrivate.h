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

@class IRCHighlightKeyword, IRCHighlightMatchCondition;

NS_ASSUME_NONNULL_BEGIN

TEXTUAL_EXTERN NSNotificationName const TPCPreferencesPreventSleepWhileConnectedChangedNotification;

TEXTUAL_EXTERN NSString * const TPCPreferencesGeneralEventDisplayDefaultsKey;
TEXTUAL_EXTERN NSString * const TPCPreferencesGeneralEventCheckboxDefaultsKey; // Textual 7's, before Show / Collapse / Hide

TEXTUAL_EXTERN NSString * const TPCPreferencesShowInlineMediaDefaultsKey;

/* Suggestions while typing, per kind (TVCInputCompletionKind order):
 nicknames, channels, commands, emoji */
TEXTUAL_EXTERN NSArray<NSString *> *TPCPreferencesInputCompletionDefaultsKeys(void);

TEXTUAL_EXTERN NSString * const TPCPreferencesInputMarkdownDefaultsKey; // Markdown when sending

typedef NS_ENUM(NSUInteger, TXInlineMediaDomainRuleMode) {
	TXInlineMediaDomainRuleModeExcept = 0, // links from every site except those listed
	TXInlineMediaDomainRuleModeOnly = 1 // links only from the sites listed
};

@interface TPCPreferences (TPCPreferencesLocalPrivate)
+ (void)initPreferences;

/* Textual 7's Caffeine extension setting becomes "PreventSleepWhileConnected" (once) */
+ (void)migrateCaffeinePreference;

+ (void)setAppNapEnabled:(BOOL)appNapEnabled;

/* Posts TPCPreferencesPreventSleepWhileConnectedChangedNotification */
+ (void)setPreventSleepWhileConnected:(BOOL)preventSleepWhileConnected;

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

@property (class) BOOL inputMarkdownEnabled;

/* Muted channels and networks still notify highlights (E3) */
@property (class) BOOL highlightsNotifyWhenMuted;

/* "Automatically ignore highlight spam": a message naming this many people in the channel or more (E3, 10.14) */
@property (readonly, class) NSUInteger massHighlightThreshold;

+ (BOOL)inputCompletionEnabledForKind:(NSUInteger)kind;
+ (void)setInputCompletion:(BOOL)enabled forKind:(NSUInteger)kind;

/* Inline media (E2.6): services turned off by name (+[ICPCoreMedia serviceNames]),
 web page cards, audio, and which sites' links are previewed */
@property (class, copy) NSArray<NSString *> *inlineMediaDisabledServices;
+ (BOOL)inlineMediaServiceIsEnabled:(NSString *)serviceName;
+ (void)setInlineMediaService:(NSString *)serviceName enabled:(BOOL)enabled;

+ (void)setInlineMediaWebPageCards:(BOOL)inlineMediaWebPageCards;

@property (class) BOOL inlineMediaAudio;

@property (class) TXInlineMediaDomainRuleMode inlineMediaDomainRuleMode;
@property (class, copy) NSArray<NSString *> *inlineMediaDomains; // normalized: "example.com"

/* "https://www.Example.com/x" → "www.example.com", "*.example.com" → "example.com"; nil if not a domain */
+ (nullable NSString *)normalizedInlineMediaDomain:(NSString *)domain;

/* Textual 7's limits (D-E2.12): "Only inline images and videos" turns every
 service card and web page cards off; the limits are removed */
+ (void)migrateInlineMediaLimits;

+ (void)setMessageGroupingStyle:(TVCLogLineGroupingStyle)messageGroupingStyle;

/* Event messages, per kind (Preferences → Style → Events): shown, dimmed or
 hidden in the chat view (hidden ones are still printed and stored, so showing
 them again brings the earlier ones back), and runs of joins, parts, quits,
 nickname and away changes collapsed into one line */
typedef NS_ENUM(NSUInteger, TPCEventKind) {
	TPCEventKindJoins = 0,
	TPCEventKindParts,
	TPCEventKindQuits,
	TPCEventKindNicknameChanges,
	TPCEventKindAwayChanges,
	TPCEventKindKicks,
	TPCEventKindModeChanges,
	TPCEventKindTopicChanges,
	TPCEventKindCount
};

typedef NS_ENUM(NSUInteger, TPCEventDisplay) {
	TPCEventDisplayShow = 0,
	TPCEventDisplayDim,
	TPCEventDisplayHide
};

+ (TPCEventDisplay)eventDisplayForKind:(TPCEventKind)kind;
+ (void)setEventDisplay:(TPCEventDisplay)display forKind:(TPCEventKind)kind;

@property (class, readonly) BOOL collapseEvents;
+ (void)setCollapseEvents:(BOOL)collapseEvents;

/* For the chat view: line type ("join", "away", …) → "show", "dim" or "hide" */
@property (class, readonly, copy) NSDictionary<NSString *, NSString *> *eventDisplayByLineType;

/* Show / Collapse / Hide as the one setting before (10.13), onto the kinds */
+ (void)setGeneralEventDisplay:(TXGeneralEventDisplay)generalEventDisplay;

+ (void)migrateGeneralEventPreference;
+ (TXGeneralEventDisplay)generalEventDisplayForCheckboxValue:(nullable id)checkboxValue;

+ (void)setThemeNicknameFormat:(NSString *)value;
+ (void)setThemeTimestampFormat:(NSString *)value;

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

+ (void)setSendTypingNotifications:(BOOL)sendTypingNotifications;

/* Channels and private messages kept in Window → Sort Channel List's order (10.10) */
@property (class, readonly) BOOL keepChannelListSorted;
+ (void)setKeepChannelListSorted:(BOOL)keepChannelListSorted;

/* The keyword lists with their limits and sounds (E3, D-E3.8) */
@property (class, readonly, copy, nullable) NSArray<IRCHighlightKeyword *> *highlightMatchKeywordEntries;
@property (class, readonly, copy, nullable) NSArray<IRCHighlightKeyword *> *highlightExcludeKeywordEntries;

+ (void)moveServerHighlightConditions:(NSArray<IRCHighlightMatchCondition *> *)conditions clientId:(NSString *)clientId;

+ (void)setTextFieldAutomaticSpellCheck:(BOOL)value;
+ (void)setTextFieldAutomaticGrammarCheck:(BOOL)value;
+ (void)setTextFieldAutomaticSpellCorrection:(BOOL)value;
+ (void)setTextFieldSmartCopyPaste:(BOOL)value;
+ (void)setTextFieldSmartQuotes:(BOOL)value;
+ (void)setTextFieldSmartDashes:(BOOL)value;
+ (void)setTextFieldSmartLinks:(BOOL)value;
+ (void)setTextFieldDataDetectors:(BOOL)value;
+ (void)setTextFieldTextReplacement:(BOOL)value;

@end

NS_ASSUME_NONNULL_END
