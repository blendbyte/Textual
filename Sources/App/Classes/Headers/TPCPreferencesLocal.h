/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
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

#import "TLONotificationController.h"
#import "TPCPreferences.h"

NS_ASSUME_NONNULL_BEGIN

TEXTUAL_EXTERN NSString * const TPCPreferencesThemeNameDefaultsKey;
TEXTUAL_EXTERN NSString * const TPCPreferencesThemeFontNameDefaultsKey;
TEXTUAL_EXTERN NSString * const TPCPreferencesThemeFontSizeDefaultsKey;

TEXTUAL_EXTERN NSString * const TPCPreferencesThemeNameMissingLocallyDefaultsKey;
TEXTUAL_EXTERN NSString * const TPCPreferencesThemeFontNameMissingLocallyDefaultsKey;

TEXTUAL_EXTERN NSUInteger const TPCPreferencesDictionaryVersion;

typedef NS_ENUM(NSUInteger, TXNicknameHighlightMatchType) {
	TXNicknameHighlightMatchTypePartial = 0,
	TXNicknameHighlightMatchTypeExact,
    TXNicknameHighlightMatchTypeRegularExpression,
};

typedef NS_ENUM(NSUInteger, TXTabKeyAction) {
	TXTabKeyActionNicknameComplete = 0,
	TXTabKeyActionUnreadChannel,
	TXTabKeyActionNone = 100,
};

typedef NS_ENUM(NSUInteger, TXUserDoubleClickAction) {
	TXUserDoubleClickActionWhois = 100,
	TXUserDoubleClickActionPrivateMessage = 200,
	TXUserDoubleClickActionInsertTextField = 300,
};

typedef NS_ENUM(NSUInteger, TXNoticeSendLocation) {
	TXNoticeSendLocationServerConsole = 0,
	TXNoticeSendLocationSelectedChannel = 1,
	TXNoticeSendLocationQuery = 2,
};

typedef NS_ENUM(NSUInteger, TXCommandWKeyAction) {
	TXCommandWKeyActionCloseWindow = 0,
	TXCommandWKeyActionPartChannel = 1,
	TXCommandWKeyActionDisconnect = 2,
	TXCommandWKeyActionTerminate = 3,
};

typedef NS_ENUM(NSUInteger, TXHostmaskBanFormat) {
	TXHostmaskBanFormatWHNIN  = 0, // With Hostmask, No Username/Nickname
	TXHostmaskBanFormatWHAINN = 1, // With Hostmask and Username, No Nickname
	TXHostmaskBanFormatWHANNI = 2, // With Hostmask and Nickname, No Username
	TXHostmaskBanFormatExact  = 3, // Exact Match
};

typedef NS_ENUM(NSUInteger, TVCMainWindowTextViewFontSize) {
	TVCMainWindowTextViewFontSizeNormal			= 1,
	TVCMainWindowTextViewFontSizeLarge			= 2,
	TVCMainWindowTextViewFontSizeExtraLarge		= 3,
	TVCMainWindowTextViewFontSizeHumongous		= 4,
};

typedef NS_ENUM(NSUInteger, TXFileTransferRequestReply) {
	TXFileTransferRequestReplyIgnore					= 1,
	TXFileTransferRequestReplyOpenDialog				= 2,
	TXFileTransferRequestReplyAutomaticallyDownload		= 3,
};

typedef NS_ENUM(NSUInteger, TXFileTransferIPAddressMethodDetection) {
	/* integers are out of order to preserve existing preferences */
	TXFileTransferIPAddressMethodRouterOnly 			NS_SWIFT_NAME(routerOnly)			= 3,
	TXFileTransferIPAddressMethodRouterAndFirstParty 	NS_SWIFT_NAME(routerAndFirstParty)	= 1,
	TXFileTransferIPAddressMethodRouterAndThirdParty	NS_SWIFT_NAME(routerAndThirdParty)	= 4,
	TXFileTransferIPAddressMethodManual					NS_SWIFT_NAME(manual)				= 2,
};

typedef NS_ENUM(NSUInteger, TXChannelViewArrangement) {
	TXChannelViewArrangedHorizontally	NS_SWIFT_NAME(horizontal) 	= 0,
	TXChannelViewArrangedVertically 	NS_SWIFT_NAME(vertical)		= 1
};

typedef NS_ENUM(NSUInteger, TXPreferredAppearance) {
	TXPreferredAppearanceInherited 	= 0,
	TXPreferredAppearanceLight 		= 1,
	TXPreferredAppearanceDark		= 2
};

@interface TPCPreferences (TPCPreferencesLocal)
+ (BOOL)appNapEnabled;

+ (BOOL)developerModeEnabled;

+ (nullable NSString *)masqueradeCTCPVersion;

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
+ (BOOL)receiveBetaUpdates;
#endif

+ (BOOL)channelNavigationIsServerSpecific;

+ (BOOL)automaticallyDetectHighlightSpam;

+ (BOOL)rememberServerListQueryStates;

+ (TVCMainWindowTextViewFontSize)mainTextViewFontSize;
+ (BOOL)focusMainTextViewOnSelectionChange;

+ (BOOL)logToDisk; // Checks whether checkbox for logging is checked.
+ (BOOL)logToDiskIsEnabled; // Checks whether checkbox is checked and whether an actual path is configured.

+ (BOOL)postNotificationsWhileInFocus;

+ (BOOL)automaticallyFilterUnicodeTextSpam;

+ (BOOL)conversationTrackingIncludesUserModeSymbol;

+ (NSString *)defaultRealName;
+ (NSString *)defaultUsername;
+ (NSString *)defaultNickname;
+ (nullable NSString *)defaultAwayNickname;
+ (NSString *)defaultKickMessage;

+ (NSString *)IRCopDefaultKillMessage;
+ (NSString *)IRCopDefaultGlineMessage;
+ (NSString *)IRCopDefaultShunMessage;

+ (BOOL)enableEchoMessageCapability;

+ (BOOL)giveFocusOnMessageCommand;

+ (BOOL)amsgAllConnections;
+ (BOOL)awayAllConnections;
+ (BOOL)nickAllConnections;
+ (BOOL)clearAllConnections;

+ (BOOL)memberListSortFavorsServerStaff;
+ (BOOL)memberListUpdatesUserInfoPopoverOnScroll;
+ (BOOL)memberListDisplayNoModeSymbol;

+ (TXNoticeSendLocation)locationToSendNotices;

+ (BOOL)disableNicknameColorHashing;

+ (BOOL)displayDockBadge;
+ (BOOL)displayPublicMessageCountOnDockBadge;

+ (BOOL)setAwayOnScreenSleep;
+ (BOOL)disconnectOnSleep;

+ (BOOL)preferModernCiphers;
+ (BOOL)preferModernSockets;

+ (BOOL)autoAddScrollbackMark;
+ (BOOL)showDateChanges;
+ (BOOL)showInlineMedia;
+ (BOOL)showJoinLeave;
+ (BOOL)displayServerMOTD;
+ (BOOL)rightToLeftFormatting;
+ (BOOL)removeAllFormatting;

+ (NSUInteger)trackUserAwayStatusMaximumChannelSize;

+ (TXPreferredAppearance)appearance;

+ (BOOL)disableSidebarTranslucency;
+ (BOOL)hideMainWindowSegmentedController;

+ (BOOL)reloadScrollbackOnLaunch;

+ (BOOL)automaticallyReloadCustomThemesWhenTheyChange;

+ (BOOL)autoJoinOnInvite;

+ (BOOL)confirmQuit;
+ (BOOL)rejoinOnKick;
+ (BOOL)copyOnSelect;
+ (BOOL)replyToCTCPRequests;

+ (BOOL)inputHistoryIsChannelSpecific;

+ (TXCommandWKeyAction)commandWKeyAction;

+ (BOOL)commandReturnSendsMessageAsAction;
+ (BOOL)controlEnterSendsMessage;

+ (BOOL)openBrowserInBackground;

+ (BOOL)connectOnDoubleclick;
+ (BOOL)disconnectOnDoubleclick;
+ (BOOL)joinOnDoubleclick;
+ (BOOL)leaveOnDoubleclick;

+ (NSUInteger)autojoinMaximumChannelJoins;
+ (NSTimeInterval)autojoinDelayBetweenChannelJoins;
+ (NSTimeInterval)autojoinDelayAfterIdentification;

+ (TXUserDoubleClickAction)userDoubleClickOption;

+ (TXHostmaskBanFormat)banFormat;

+ (BOOL)webKit2Enabled;
+ (BOOL)webKit2ProcessPoolSizeLimited;
+ (BOOL)webKit2PreviewLinks;

+ (NSString *)themeName;
+ (NSString *)themeNameDefault;

+ (NSString *)themeNicknameFormat;
+ (NSString *)themeNicknameFormatDefault;

+ (NSString *)themeTimestampFormat;
+ (NSString *)themeTimestampFormatDefault;

+ (nullable NSString *)themeUserStyleSheetRules;

+ (CGFloat)mainWindowTransparency;

+ (nullable NSFont *)themeChannelViewFont;
+ (NSString *)themeChannelViewFontName;
+ (NSString *)themeChannelViewFontNameDefault;
+ (CGFloat)themeChannelViewFontSize;

+ (BOOL)themeNicknameFormatPreferenceUserConfigurable;
+ (BOOL)themeTimestampFormatPreferenceUserConfigurable;
+ (BOOL)themeChannelViewFontPreferenceUserConfigurable;

+ (BOOL)themeChannelViewUsesCustomScrollers;

+ (NSUInteger)scrollbackSaveLimit;
+ (NSUInteger)scrollbackVisibleLimit;

+ (TXChannelViewArrangement)channelViewArrangement;

+ (BOOL)soundIsMuted;

+ (BOOL)onlySpeakEventsForSelection;

+ (BOOL)channelMessageSpeakChannelName;
+ (BOOL)channelMessageSpeakNickname;

+ (nullable NSString *)soundForEvent:(TXNotificationType)event;

+ (BOOL)speakEvent:(TXNotificationType)event;
+ (BOOL)notificationEnabledForEvent:(TXNotificationType)event;
+ (BOOL)disabledWhileAwayForEvent:(TXNotificationType)event;
+ (BOOL)bounceDockIconForEvent:(TXNotificationType)event;
+ (BOOL)bounceDockIconRepeatedlyForEvent:(TXNotificationType)event;

+ (TXTabKeyAction)tabKeyAction;

+ (BOOL)fileTransferRequestsAreReversed;
+ (BOOL)fileTransfersPreventIdleSystemSleep;

+ (TXFileTransferRequestReply)fileTransferRequestReplyAction;
+ (TXFileTransferIPAddressMethodDetection)fileTransferIPAddressDetectionMethod;

+ (uint16_t)fileTransferPortRangeStart;
+ (uint16_t)fileTransferPortRangeEnd;

+ (nullable NSString *)fileTransferManuallyEnteredIPAddress;
+ (nullable NSString *)fileTransferIPAddressInterfaceName;

+ (nullable NSString *)tabCompletionSuffix;

+ (BOOL)tabCompletionDoNotAppendWhitespace;
+ (BOOL)tabCompletionCutForwardToFirstWhitespace;

+ (nullable NSArray<NSDictionary *> *)clientList;

+ (TXNicknameHighlightMatchType)highlightMatchingMethod;

+ (BOOL)logHighlights;
+ (BOOL)highlightCurrentNickname;

+ (CGFloat)swipeMinimumLength;

+ (nullable NSArray<NSString *> *)highlightMatchKeywords;
+ (nullable NSArray<NSString *> *)highlightExcludeKeywords;

+ (NSDictionary<NSString *, id> *)defaultPreferences;

+ (BOOL)textFieldAutomaticSpellCheck;
+ (BOOL)textFieldAutomaticGrammarCheck;
+ (BOOL)textFieldAutomaticSpellCorrection;
+ (BOOL)textFieldSmartCopyPaste;
+ (BOOL)textFieldSmartQuotes;
+ (BOOL)textFieldSmartDashes;
+ (BOOL)textFieldSmartLinks;
+ (BOOL)textFieldDataDetectors;
+ (BOOL)textFieldTextReplacement;
@end

NS_ASSUME_NONNULL_END
