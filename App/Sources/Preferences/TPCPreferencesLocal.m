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

#import "TXGlobalModels.h"
#import "IRCWorld.h"
#import "TPCNicknameColorStyleGeneratorPrivate.h"
#import "TPCApplicationInfoPrivate.h"
#import "TPCPathInfoPrivate.h"
#import "TPCPreferencesUserDefaultsLocal.h"
#import "TPCResourceManager.h"
#import "ICPCoreMediaPrivate.h"
#import "TPCThemeController.h"
#import "TPCTheme.h"
#import "TPCPreferencesLocalPrivate.h"
#import "IRCHighlightKeywordPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const TPCPreferencesThemeNameDefaultsKey	= @"Theme -> Name";

NSString * const TPCPreferencesThemeFontNameDefaultsKey	= @"Theme -> Font Name";
NSString * const TPCPreferencesThemeFontSizeDefaultsKey	= @"Theme -> Font Size";

NSString * const TPCPreferencesThemeFontNameSystemFont = @"-apple-system";

NSString * const TPCPreferencesGeneralEventDisplayDefaultsKey = @"DisplayEventInLogView -> Join, Part, Quit Display";
NSString * const TPCPreferencesGeneralEventCheckboxDefaultsKey = @"DisplayEventInLogView -> Join, Part, Quit";

NSString * const TPCPreferencesShowInlineMediaDefaultsKey = @"DisplayEventInLogView -> Inline Media";

NSString * const TPCPreferencesInputMarkdownDefaultsKey = @"Input -> Markdown Formatting";

NSArray<NSString *> *TPCPreferencesInputCompletionDefaultsKeys(void)
{
	return @[@"Input Completion -> Nicknames",
			 @"Input Completion -> Channels",
			 @"Input Completion -> Commands",
			 @"Input Completion -> Emoji"];
}

NSString * const TPCPreferencesThemeNameMissingLocallyDefaultsKey = @"Theme -> Name -> Did Not Exist During Last Sync";

NSString * const TPCPreferencesThemeFontNameMissingLocallyDefaultsKey = @"Theme -> Font Name -> Did Not Exist During Last Sync";

NSUInteger const TPCPreferencesDictionaryVersion = 602;

NSNotificationName const TPCPreferencesPreventSleepWhileConnectedChangedNotification = @"TPCPreferencesPreventSleepWhileConnectedChangedNotification";

@implementation TPCPreferences (TPCPreferencesLocal)

#pragma mark -
#pragma mark Default Identity

+ (NSString *)_defaultNicknamePrefix
{
	return [self defaultPreferences][@"DefaultIdentity -> Nickname"];
}

+ (void)_populateDefaultNickname
{
	/* Using "Guest" as the default nickname may create conflicts as nickname guesses are 
	 exhausted while appending underscores. To fix this, a random number is appended to 
	 the end of the default nickname. */
	NSString *nicknamePrefix = [self _defaultNicknamePrefix];

	NSString *nickname = [nicknamePrefix stringByAppendingFormat:@"%lu", TXRandomNumber(100)];

	[RZUserDefaults() registerDefaults:@{@"DefaultIdentity -> Nickname" : nickname}];
}

+ (NSString *)defaultNickname
{
	return [RZUserDefaults() objectForKey:@"DefaultIdentity -> Nickname"];
}

+ (nullable NSString *)defaultAwayNickname
{
	return [RZUserDefaults() objectForKey:@"DefaultIdentity -> AwayNickname"];
}

+ (NSString *)defaultUsername
{
	return [RZUserDefaults() objectForKey:@"DefaultIdentity -> Username"];
}

+ (NSString *)defaultRealName
{
	return [RZUserDefaults() objectForKey:@"DefaultIdentity -> Realname"];
}

#pragma mark -
#pragma mark General Preferences

+ (NSUInteger)autojoinMaximumChannelJoins
{
	return [RZUserDefaults() unsignedIntegerForKey:@"AutojoinMaximumChannelJoinCount"];
}

+ (NSTimeInterval)autojoinDelayBetweenChannelJoins
{
	return [RZUserDefaults() doubleForKey:@"AutojoinDelayBetweenChannelJoins"];
}

+ (NSTimeInterval)autojoinDelayAfterIdentification
{
	return [RZUserDefaults() doubleForKey:@"AutojoinDelayAfterIdentification"];
}

+ (NSString *)defaultKickMessage
{
	return [RZUserDefaults() objectForKey:@"ChannelOperatorDefaultLocalization -> Kick Reason"];
}

+ (NSString *)IRCopDefaultKillMessage
{
	return [RZUserDefaults() objectForKey:@"IRCopDefaultLocalizaiton -> Kill Reason"];
}

+ (NSString *)IRCopDefaultGlineMessage
{
	return [RZUserDefaults() objectForKey:@"IRCopDefaultLocalizaiton -> G:Line Reason"];
}

+ (NSString *)IRCopDefaultShunMessage
{
	return [RZUserDefaults() objectForKey:@"IRCopDefaultLocalizaiton -> Shun Reason"];
}

+ (nullable NSString *)masqueradeCTCPVersion
{
	return [RZUserDefaults() objectForKey:@"ApplicationCTCPVersionMasquerade"];
}

+ (BOOL)channelNavigationIsServerSpecific
{
	/* TDCChannelSpotlightController is observing this key with it hard coded.
	 If changed here, change there as well. */

	return [RZUserDefaults() boolForKey:@"ChannelNavigationIsServerSpecific"];
}

+ (BOOL)setAwayOnScreenSleep
{
	return [RZUserDefaults() boolForKey:@"SetAwayOnScreenSleep"];
}

+ (BOOL)disconnectOnSleep
{
	return [RZUserDefaults() boolForKey:@"AutomaticallyDisconnectForSleepMode"];
}

+ (BOOL)disableSidebarTranslucency
{
	return [RZUserDefaults() boolForKey:@"DisableSidebarTranslucency"];
}

+ (BOOL)hideMainWindowSegmentedController
{
	return [RZUserDefaults() boolForKey:@"DisableMainWindowSegmentedController"];
}

+ (BOOL)logHighlights
{
	return [RZUserDefaults() boolForKey:@"LogHighlights"];
}

+ (BOOL)clearAllConnections
{
	return [RZUserDefaults() boolForKey:@"ApplyCommandToAllConnections -> clearall"];
}

+ (BOOL)enableEchoMessageCapability
{
	return YES;
}

+ (BOOL)displayServerMOTD
{
	return [RZUserDefaults() boolForKey:@"DisplayServerMessageOfTheDayOnConnect"];
}

+ (BOOL)copyOnSelect
{
	return [RZUserDefaults() boolForKey:@"CopyTextSelectionOnMouseUp"];
}

+ (BOOL)replyToCTCPRequests
{
	return [RZUserDefaults() boolForKey:@"ReplyUnignoredExternalCTCPRequests"];
}

+ (BOOL)autoAddScrollbackMark
{
	return [RZUserDefaults() boolForKey:@"AutomaticallyAddScrollbackMarker"];
}

+ (BOOL)removeAllFormatting
{
	return [RZUserDefaults() boolForKey:@"RemoveIRCTextFormatting"];
}

+ (BOOL)automaticallyDetectHighlightSpam
{
	return [RZUserDefaults() boolForKey:@"AutomaticallyDetectHighlightSpam"];
}

/* Mass highlights (E3, 10.14): this many people named in one message, or more */
+ (NSUInteger)massHighlightThreshold
{
	NSInteger threshold = [RZUserDefaults() integerForKey:@"Highlights -> Mass Highlight Threshold"];

	if (threshold < 2) {
		return 2;
	}

	return threshold;
}

+ (BOOL)disableNicknameColorHashing
{
	return [RZUserDefaults() boolForKey:@"DisableRemoteNicknameColorHashing"];
}

+ (BOOL)conversationTrackingIncludesUserModeSymbol
{
	return [RZUserDefaults() boolForKey:@"ConversationTrackingIncludesUserModeSymbol"];
}

+ (BOOL)rightToLeftFormatting
{
	return [RZUserDefaults() boolForKey:@"RightToLeftTextFormatting"];
}

+ (BOOL)displayDockBadge
{
	return [RZUserDefaults() boolForKey:@"DisplayDockBadges"];
}

+ (BOOL)amsgAllConnections
{
	return [RZUserDefaults() boolForKey:@"ApplyCommandToAllConnections -> amsg"];
}

+ (BOOL)awayAllConnections
{
	return [RZUserDefaults() boolForKey:@"ApplyCommandToAllConnections -> away"];
}

+ (BOOL)giveFocusOnMessageCommand
{
	return [RZUserDefaults() boolForKey:@"FocusSelectionOnMessageCommandExecution"];
}

+ (BOOL)memberListSortFavorsServerStaff
{
	return [RZUserDefaults() boolForKey:@"MemberListSortFavorsServerStaff"];
}

+ (BOOL)memberListUpdatesUserInfoPopoverOnScroll
{
	return [RZUserDefaults() boolForKey:@"MemberListUpdatesUserInfoPopoverOnScroll"];
}

+ (BOOL)memberListDisplayNoModeSymbol
{
	return [RZUserDefaults() boolForKey:@"DisplayUserListNoModeSymbol"];
}

+ (BOOL)postNotificationsWhileInFocus
{
	return [RZUserDefaults() boolForKey:@"PostNotificationsWhileInFocus"];
}

+ (BOOL)automaticallyFilterUnicodeTextSpam
{
	return [RZUserDefaults() boolForKey:@"AutomaticallyFilterUnicodeTextSpam"];
}

+ (BOOL)nickAllConnections
{
	return [RZUserDefaults() boolForKey:@"ApplyCommandToAllConnections -> nick"];
}

+ (BOOL)confirmQuit
{
	return [RZUserDefaults() boolForKey:@"ConfirmApplicationQuit"];
}

+ (BOOL)rememberServerListQueryStates
{
	return [RZUserDefaults() boolForKey:@"ServerListRetainsQueriesBetweenRestarts"];
}

+ (BOOL)rejoinOnKick
{
	return [RZUserDefaults() boolForKey:@"RejoinChannelOnLocalKick"];
}

+ (BOOL)reloadScrollbackOnLaunch
{
	return [RZUserDefaults() boolForKey:@"ReloadScrollbackOnLaunch"];
}

+ (BOOL)autoJoinOnInvite
{
	return [RZUserDefaults() boolForKey:@"AutojoinChannelOnInvite"];
}

+ (BOOL)connectOnDoubleclick
{
	return [RZUserDefaults() boolForKey:@"ServerListDoubleClickConnectServer"];
}

+ (BOOL)disconnectOnDoubleclick
{
	return [RZUserDefaults() boolForKey:@"ServerListDoubleClickDisconnectServer"];
}

+ (BOOL)joinOnDoubleclick
{
	return [RZUserDefaults() boolForKey:@"ServerListDoubleClickJoinChannel"];
}

+ (BOOL)leaveOnDoubleclick
{
	return [RZUserDefaults() boolForKey:@"ServerListDoubleClickLeaveChannel"];
}

+ (BOOL)logToDisk
{
	return [RZUserDefaults() boolForKey:@"LogTranscript"];
}

+ (void)setLogToDisk:(BOOL)logToDisk
{
	[RZUserDefaults() setBool:logToDisk forKey:@"LogTranscript"];
}

+ (BOOL)logToDiskIsEnabled
{
	return ([RZUserDefaults() boolForKey:@"LogTranscript"] &&
			[TPCPathInfo transcriptFolderURL] != nil);
}

+ (BOOL)openBrowserInBackground
{
	return [RZUserDefaults() boolForKey:@"OpenClickedLinksInBackgroundBrowser"];
}

+ (BOOL)showDateChanges
{
	return [RZUserDefaults() boolForKey:@"DisplayEventInLogView -> Date Changes"];
}

+ (TVCLogLineGroupingStyle)messageGroupingStyle
{
	return (TVCLogLineGroupingStyle)[RZUserDefaults() unsignedIntegerForKey:@"DisplayEventInLogView -> Message Grouping Style"];
}

+ (void)setMessageGroupingStyle:(TVCLogLineGroupingStyle)messageGroupingStyle
{
	[RZUserDefaults() setUnsignedInteger:messageGroupingStyle forKey:@"DisplayEventInLogView -> Message Grouping Style"];
}

+ (void)setShowInlineMedia:(BOOL)showInlineMedia
{
	[RZUserDefaults() setBool:showInlineMedia forKey:TPCPreferencesShowInlineMediaDefaultsKey];
}

+ (BOOL)showInlineMedia
{
	return [RZUserDefaults() boolForKey:TPCPreferencesShowInlineMediaDefaultsKey];
}

+ (BOOL)highlightsNotifyWhenMuted
{
	return [RZUserDefaults() boolForKey:@"Notifications -> Highlights When Muted"];
}

+ (void)setHighlightsNotifyWhenMuted:(BOOL)highlightsNotifyWhenMuted
{
	[RZUserDefaults() setBool:highlightsNotifyWhenMuted forKey:@"Notifications -> Highlights When Muted"];
}

+ (BOOL)inputMarkdownEnabled
{
	return [RZUserDefaults() boolForKey:TPCPreferencesInputMarkdownDefaultsKey];
}

+ (void)setInputMarkdownEnabled:(BOOL)inputMarkdownEnabled
{
	[RZUserDefaults() setBool:inputMarkdownEnabled forKey:TPCPreferencesInputMarkdownDefaultsKey];
}

+ (BOOL)inputCompletionEnabledForKind:(NSUInteger)kind
{
	NSArray *keys = TPCPreferencesInputCompletionDefaultsKeys();

	if (kind >= keys.count) {
		return NO;
	}

	return [RZUserDefaults() boolForKey:keys[kind]];
}

+ (void)setInputCompletion:(BOOL)enabled forKind:(NSUInteger)kind
{
	NSArray *keys = TPCPreferencesInputCompletionDefaultsKeys();

	if (kind >= keys.count) {
		return;
	}

	[RZUserDefaults() setBool:enabled forKey:keys[kind]];
}

+ (NSArray<NSString *> *)inlineMediaDisabledServices
{
	NSArray *services = [RZUserDefaults() arrayForKey:@"InlineMediaDisabledServices"];

	if (services == nil) {
		return @[];
	}

	return services;
}

+ (void)setInlineMediaDisabledServices:(NSArray<NSString *> *)inlineMediaDisabledServices
{
	[RZUserDefaults() setObject:inlineMediaDisabledServices forKey:@"InlineMediaDisabledServices"];
}

+ (BOOL)inlineMediaServiceIsEnabled:(NSString *)serviceName
{
	NSParameterAssert(serviceName != nil);

	return ([[self inlineMediaDisabledServices] containsObject:serviceName] == NO);
}

+ (void)setInlineMediaService:(NSString *)serviceName enabled:(BOOL)enabled
{
	NSParameterAssert(serviceName != nil);

	NSMutableOrderedSet<NSString *> *services = [NSMutableOrderedSet orderedSetWithArray:[self inlineMediaDisabledServices]];

	if (enabled) {
		[services removeObject:serviceName];
	} else {
		[services addObject:serviceName];
	}

	[self setInlineMediaDisabledServices:services.array];
}

+ (void)setInlineMediaWebPageCards:(BOOL)inlineMediaWebPageCards
{
	[RZUserDefaults() setBool:inlineMediaWebPageCards forKey:@"InlineMediaWebPageCards"];
}

+ (BOOL)inlineMediaAudio
{
	return [RZUserDefaults() boolForKey:@"InlineMediaAudio"];
}

+ (void)setInlineMediaAudio:(BOOL)inlineMediaAudio
{
	[RZUserDefaults() setBool:inlineMediaAudio forKey:@"InlineMediaAudio"];
}

+ (TXInlineMediaDomainRuleMode)inlineMediaDomainRuleMode
{
	return (TXInlineMediaDomainRuleMode)[RZUserDefaults() unsignedIntegerForKey:@"InlineMediaDomainRuleMode"];
}

+ (void)setInlineMediaDomainRuleMode:(TXInlineMediaDomainRuleMode)inlineMediaDomainRuleMode
{
	[RZUserDefaults() setUnsignedInteger:inlineMediaDomainRuleMode forKey:@"InlineMediaDomainRuleMode"];
}

+ (NSArray<NSString *> *)inlineMediaDomains
{
	NSArray *domains = [RZUserDefaults() arrayForKey:@"InlineMediaDomainList"];

	if (domains == nil) {
		return @[];
	}

	return domains;
}

+ (void)setInlineMediaDomains:(NSArray<NSString *> *)inlineMediaDomains
{
	[RZUserDefaults() setObject:inlineMediaDomains forKey:@"InlineMediaDomainList"];
}

+ (nullable NSString *)normalizedInlineMediaDomain:(NSString *)domain
{
	NSParameterAssert(domain != nil);

	NSString *host = domain.trim.lowercaseString;

	/* An address pasted whole */
	if ([host containsString:@"://"]) {
		host = [NSURL URLWithString:host].host.lowercaseString;
	} else {
		NSRange pathStart = [host rangeOfString:@"/"];

		if (pathStart.location != NSNotFound) {
			host = [host substringToIndex:pathStart.location];
		}
	}

	if ([host hasPrefix:@"*."]) {
		host = [host substringFromIndex:2];
	}

	host = [host stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"."]];

	/* No port, no user, no spaces; at least one dot ("localhost" is never previewed anyway) */
	if (host.length == 0 ||
		[host containsString:@"."] == NO ||
		[host rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@":@ \t"]].location != NSNotFound)
	{
		return nil;
	}

	return host;
}

+ (void)migrateInlineMediaLimits
{
	NSArray<NSString *> *limitKeys = @[@"InlineMediaLimitToBasics",
									   @"InlineMediaLimitBasicsToFiles",
									   @"InlineMediaLimitInsecureContent",
									   @"InlineMediaLimitNaughtyContent",
									   @"InlineMediaLimitUnsafeContent",
									   @"InlineMediaCheckEverything"];

	id limitToBasics = [RZUserDefaults() objectForKey:@"InlineMediaLimitToBasics"];

	/* Files and clip services (Giphy, Gyazo, …) stay; "Including video
	 services" folds into this; the other limits go without effect: "safe
	 to view in public" (Pornhub only), plain HTTP (never previewed), "safe
	 sources" (X cards show for everyone), "Load everything" (web page cards) */
	if ([limitToBasics respondsToSelector:@selector(boolValue)] && [limitToBasics boolValue]) {
		[self setInlineMediaWebPageCards:NO];

		NSMutableOrderedSet<NSString *> *services = [NSMutableOrderedSet orderedSetWithArray:[self inlineMediaDisabledServices]];

		[services addObjectsFromArray:[ICPCoreMedia cardServiceNames]];

		[self setInlineMediaDisabledServices:services.array];
	}

	for (NSString *limitKey in limitKeys) {
		[RZUserDefaults() removeObjectForKey:limitKey];
	}
}

+ (BOOL)showJoinLeave
{
	return ([self generalEventDisplay] != TXGeneralEventDisplayHide);
}

+ (TXGeneralEventDisplay)generalEventDisplay
{
	NSUInteger generalEventDisplay = [RZUserDefaults() unsignedIntegerForKey:TPCPreferencesGeneralEventDisplayDefaultsKey];

	if (generalEventDisplay > TXGeneralEventDisplayHide) {
		return TXGeneralEventDisplayCollapse;
	}

	return (TXGeneralEventDisplay)generalEventDisplay;
}

+ (void)setGeneralEventDisplay:(TXGeneralEventDisplay)generalEventDisplay
{
	[RZUserDefaults() setUnsignedInteger:generalEventDisplay forKey:TPCPreferencesGeneralEventDisplayDefaultsKey];
}

/* The "Join, Part, Quit" checkbox became Show / Collapse / Hide (10.13): a
 setting someone made carries over once, then its key is gone */
+ (void)migrateGeneralEventPreference
{
	NSString *checkboxKey = TPCPreferencesGeneralEventCheckboxDefaultsKey;

	id checkboxValue = [RZUserDefaults() objectForKey:checkboxKey];

	if (checkboxValue == nil) {
		return;
	}

	[self setGeneralEventDisplay:[self generalEventDisplayForCheckboxValue:checkboxValue]];

	[RZUserDefaults() removeObjectForKey:checkboxKey];
}

/* The member list's default width went from 120 (its minimum) to 190 (10.5).
 The width is saved whether or not it was ever dragged, so a saved 120 is
 taken as "never resized" and moves to the new default, once */
+ (void)migrateMemberListWidth
{
#define _migratedKey		@"TPCPreferences -> Migration -> Member List Width (800)"
#define _framesKey			@"Window -> Main Window -> Split Channel View Saved Frames"

	if ([RZUserDefaults() boolForKey:_migratedKey]) {
		return;
	}

	[RZUserDefaults() setBool:YES forKey:_migratedKey];

	NSDictionary *frames = [RZUserDefaults() dictionaryForKey:_framesKey];

	if ([frames doubleForKey:@"memberList"] != 120) {
		return;
	}

	NSMutableDictionary *framesMutable = [frames mutableCopy];

	framesMutable[@"memberList"] = @(190);

	[RZUserDefaults() setObject:[framesMutable copy] forKey:_framesKey];

#undef _framesKey
#undef _migratedKey
}

+ (TXGeneralEventDisplay)generalEventDisplayForCheckboxValue:(nullable id)checkboxValue
{
	/* Textual 7 showed them unless the checkbox was turned off */
	if ([checkboxValue respondsToSelector:@selector(boolValue)] && [checkboxValue boolValue] == NO) {
		return TXGeneralEventDisplayHide;
	}

	return TXGeneralEventDisplayShow;
}

+ (BOOL)commandReturnSendsMessageAsAction
{
	return [RZUserDefaults() boolForKey:@"CommandReturnSendsMessageAsAction"];
}

+ (BOOL)controlEnterSendsMessage
{
	return [RZUserDefaults() boolForKey:@"ControlEnterSendsMessage"];
}

+ (BOOL)displayPublicMessageCountOnDockBadge
{
	return [RZUserDefaults() boolForKey:@"DisplayPublicMessageCountInDockBadge"];
}

+ (void)setHighlightCurrentNickname:(BOOL)highlightCurrentNickname
{
	[RZUserDefaults() setBool:highlightCurrentNickname forKey:@"TrackNicknameHighlightsOfLocalUser"];
}

+ (BOOL)highlightCurrentNickname
{
	return [RZUserDefaults() boolForKey:@"TrackNicknameHighlightsOfLocalUser"];
}

+ (BOOL)sendTypingNotifications
{
	return [RZUserDefaults() boolForKey:@"Typing Notifications -> Send"];
}

+ (void)setSendTypingNotifications:(BOOL)sendTypingNotifications
{
	[RZUserDefaults() setBool:sendTypingNotifications forKey:@"Typing Notifications -> Send"];
}

+ (BOOL)inputHistoryIsChannelSpecific
{
	return [RZUserDefaults() boolForKey:@"SaveInputHistoryPerSelection"];
}

+ (CGFloat)swipeMinimumLength
{
	return [RZUserDefaults() doubleForKey:@"SwipeMinimumLength"];
}

+ (NSUInteger)trackUserAwayStatusMaximumChannelSize
{
	return [RZUserDefaults() unsignedIntegerForKey:@"TrackUserAwayStatusMaximumChannelSize"];
}

+ (TXTabKeyAction)tabKeyAction
{
	return (TXTabKeyAction)[RZUserDefaults() unsignedIntegerForKey:@"Keyboard -> Tab Key Action"];
}

+ (TXNicknameHighlightMatchType)highlightMatchingMethod
{
	return (TXNicknameHighlightMatchType)[RZUserDefaults() unsignedIntegerForKey:@"NicknameHighlightMatchingType"];
}

+ (TXUserDoubleClickAction)userDoubleClickOption
{
	return (TXUserDoubleClickAction)[RZUserDefaults() unsignedIntegerForKey:@"UserListDoubleClickAction"];
}

+ (TXNoticeSendLocation)locationToSendNotices
{
	return (TXNoticeSendLocation)[RZUserDefaults() unsignedIntegerForKey:@"DestinationOfNonserverNotices"];
}

+ (void)setLocationToSendNotices:(TXNoticeSendLocation)locationToSendNotices
{
	[RZUserDefaults() setUnsignedInteger:locationToSendNotices forKey:@"DestinationOfNonserverNotices"];
}

+ (TXCommandWKeyAction)commandWKeyAction
{
	return (TXCommandWKeyAction)[RZUserDefaults() unsignedIntegerForKey:@"Keyboard -> Command+W Key Action"];
}

+ (TXHostmaskBanFormat)banFormat
{
	return (TXHostmaskBanFormat)[RZUserDefaults() unsignedIntegerForKey:@"DefaultBanCommandHostmaskFormat"];
}

+ (TVCMainWindowTextViewFontSize)mainTextViewFontSize
{
	return (TVCMainWindowTextViewFontSize)[RZUserDefaults() unsignedIntegerForKey:@"Main Input Text Field -> Font Size"];
}

+ (BOOL)focusMainTextViewOnSelectionChange
{
	return [RZUserDefaults() boolForKey:@"Main Input Text Field -> Focus When Changing Views"];
}

+ (BOOL)preferModernCiphers
{
	/* The name of this preference is somewhat of a misnomer.
	 Modern ciphers are always used, regardless of its value.
	 This preference defines whether the "deprecated" ciphers
	 are used as well. Whether we should prefer modern only. */

	return [RZUserDefaults() boolForKey:@"PreferModernCiphers"];
}

+ (BOOL)preferModernSockets
{
	return YES;
}

#pragma mark -
#pragma mark App Nap 

+ (BOOL)appNapEnabled
{
	return ([[NSUserDefaults standardUserDefaults] boolForKey:@"NSAppSleepDisabled"] == NO);
}

+ (BOOL)preventSleepWhileConnected
{
	return [RZUserDefaults() boolForKey:@"PreventSleepWhileConnected"];
}

+ (void)setPreventSleepWhileConnected:(BOOL)preventSleepWhileConnected
{
	[RZUserDefaults() setBool:preventSleepWhileConnected forKey:@"PreventSleepWhileConnected"];

	[RZNotificationCenter() postNotificationName:TPCPreferencesPreventSleepWhileConnectedChangedNotification object:nil];
}

+ (void)setAppNapEnabled:(BOOL)appNapEnabled
{
	[[NSUserDefaults standardUserDefaults] setBool:(appNapEnabled == NO) forKey:@"NSAppSleepDisabled"];
}

#pragma mark -
#pragma mark Updates

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
+ (BOOL)receiveBetaUpdates
{
	return [RZUserDefaults() boolForKey:@"ReceiveBetaUpdates"];
}
#endif

#pragma mark -
#pragma mark Developer Mode

+ (void)setDeveloperModeEnabled:(BOOL)developerModeEnabled
{
	[RZUserDefaults() setBool:developerModeEnabled forKey:@"TextualDeveloperEnvironment"];
}

+ (BOOL)developerModeEnabled
{
	return [RZUserDefaults() boolForKey:@"TextualDeveloperEnvironment"];
}

#pragma mark -
#pragma mark Theme

+ (void)setAppearance:(TXPreferredAppearance)appearance
{
	[RZUserDefaults() setUnsignedInteger:appearance forKey:@"Appearance"];
}

+ (TXPreferredAppearance)appearance
{
	return (TXPreferredAppearance)[RZUserDefaults() unsignedIntegerForKey:@"Appearance"];
}

+ (BOOL)invertSidebarColors
{
	return [RZUserDefaults() boolForKey:@"InvertSidebarColors"];
}

+ (NSString *)themeNameDefault
{
	return [self defaultPreferences][TPCPreferencesThemeNameDefaultsKey];
}

+ (NSString *)themeName
{
	return [RZUserDefaults() objectForKey:TPCPreferencesThemeNameDefaultsKey];
}

+ (void)setThemeName:(NSString *)value
{
	NSParameterAssert(value != nil);

	[RZUserDefaults() setObject:value forKey:TPCPreferencesThemeNameDefaultsKey];

	[RZUserDefaults() removeObjectForKey:TPCPreferencesThemeNameMissingLocallyDefaultsKey];
}

+ (void)setThemeNameWithExistenceCheck:(NSString *)value
{
	NSParameterAssert(value != nil);

	if ([themeController() themeExists:value]) {
		[self setThemeName:value];
	} else {
		[RZUserDefaults() setBool:YES forKey:TPCPreferencesThemeNameMissingLocallyDefaultsKey];
	}
}

+ (NSString *)themeChannelViewFontNameDefault
{
	return [self defaultPreferences][TPCPreferencesThemeFontNameDefaultsKey];
}

+ (NSString *)themeChannelViewFontName
{
	return [RZUserDefaults() objectForKey:TPCPreferencesThemeFontNameDefaultsKey];
}

+ (BOOL)themeChannelViewFontIsSystemFont
{
	return [[self themeChannelViewFontName] isEqualToString:TPCPreferencesThemeFontNameSystemFont];
}

/* The font panel names the system font ".AppleSystemUIFont" (or a weight of it):
 not a name WebKit or a later launch can use, so it's stored as the marker */
+ (BOOL)_fontNameIsSystemFont:(NSString *)fontName
{
	return ([fontName isEqualToString:TPCPreferencesThemeFontNameSystemFont] ||
			[fontName hasPrefix:@".AppleSystemUIFont"] ||
			[fontName isEqualToString:[NSFont systemFontOfSize:0].fontName]);
}

+ (void)setThemeChannelViewFontName:(NSString *)value
{
	NSParameterAssert(value != nil);

	if ([self _fontNameIsSystemFont:value]) {
		value = TPCPreferencesThemeFontNameSystemFont;
	}

	[RZUserDefaults() setObject:value forKey:TPCPreferencesThemeFontNameDefaultsKey];

	[RZUserDefaults() removeObjectForKey:TPCPreferencesThemeFontNameMissingLocallyDefaultsKey];
}

+ (void)setThemeChannelViewFontNameWithExistenceCheck:(NSString *)value
{
	NSParameterAssert(value != nil);

	if ([self _fontNameIsSystemFont:value] || [NSFont fontIsAvailable:value]) {
		[self setThemeChannelViewFontName:value];
	} else {
		[RZUserDefaults() setBool:YES forKey:TPCPreferencesThemeFontNameMissingLocallyDefaultsKey];
	}
}

+ (CGFloat)themeChannelViewFontSize
{
	return [RZUserDefaults() doubleForKey:@"Theme -> Font Size"];
}

+ (void)setThemeChannelViewFontSize:(CGFloat)value
{
	[RZUserDefaults() setDouble:value forKey:@"Theme -> Font Size"];
}

+ (nullable NSFont *)themeChannelViewFont
{
	if ([self themeChannelViewFontIsSystemFont]) {
		return [NSFont systemFontOfSize:[self themeChannelViewFontSize]];
	}

	return [NSFont fontWithName:[self themeChannelViewFontName]
						   size:[self themeChannelViewFontSize]];
}

+ (BOOL)themeChannelViewFontPreferenceUserConfigurable
{
	return [RZUserDefaults() boolForKey:@"Theme -> Channel Font Preference Enabled"];
}

+ (void)setThemeChannelViewFontPreferenceUserConfigurable:(BOOL)themeChannelViewFontPreferenceUserConfigurable
{
	[RZUserDefaults() registerDefault:@(themeChannelViewFontPreferenceUserConfigurable) forKey:@"Theme -> Channel Font Preference Enabled"];
}

+ (NSString *)themeNicknameFormatDefault
{
	return [self defaultPreferences][@"Theme -> Nickname Format"];
}

+ (NSString *)themeNicknameFormat
{
	return [RZUserDefaults() objectForKey:@"Theme -> Nickname Format"];
}

+ (void)setThemeNicknameFormat:(NSString *)value
{
	[RZUserDefaults() setObject:value forKey:@"Theme -> Nickname Format"];
}

+ (BOOL)themeNicknameFormatPreferenceUserConfigurable
{
	return [RZUserDefaults() boolForKey:@"Theme -> Nickname Format Preference Enabled"];
}

+ (void)setThemeNicknameFormatPreferenceUserConfigurable:(BOOL)themeNicknameFormatPreferenceUserConfigurable
{
	[RZUserDefaults() registerDefault:@(themeNicknameFormatPreferenceUserConfigurable) forKey:@"Theme -> Nickname Format Preference Enabled"];
}

+ (NSString *)themeTimestampFormatDefault
{
	return [self defaultPreferences][@"Theme -> Timestamp Format"];
}

+ (NSString *)themeTimestampFormat
{
	return [RZUserDefaults() objectForKey:@"Theme -> Timestamp Format"];
}

+ (void)setThemeTimestampFormat:(NSString *)value
{
	[RZUserDefaults() setObject:value forKey:@"Theme -> Timestamp Format"];
}

+ (BOOL)themeTimestampFormatPreferenceUserConfigurable
{
	return [RZUserDefaults() boolForKey:@"Theme -> Timestamp Format Preference Enabled"];
}

+ (void)setThemeTimestampFormatPreferenceUserConfigurable:(BOOL)themeTimestampFormatPreferenceUserConfigurable
{
	[RZUserDefaults() registerDefault:@(themeTimestampFormatPreferenceUserConfigurable) forKey:@"Theme -> Timestamp Format Preference Enabled"];
}

+ (nullable NSString *)themeUserStyleSheetRules
{
	return [RZUserDefaults() objectForKey:@"Theme -> User Style Sheet Rules"];
}

+ (void)setThemeUserStyleSheetRules:(nullable NSString *)themeUserStyleSheetRules
{
	[RZUserDefaults() setObject:themeUserStyleSheetRules forKey:@"Theme -> User Style Sheet Rules"];
}

+ (CGFloat)mainWindowTransparency
{
	return [RZUserDefaults() doubleForKey:@"MainWindowTransparencyLevel"];
}

+ (BOOL)automaticallyReloadCustomThemesWhenTheyChange
{
	return [RZUserDefaults() boolForKey:@"AutomaticallyReloadCustomThemesWhenTheyChange"];
}

+ (BOOL)webKit2Enabled
{
	return YES;
}

+ (BOOL)webKit2ProcessPoolSizeLimited
{
	return NO;
}

+ (BOOL)webKit2PreviewLinks
{
	return [RZUserDefaults() boolForKey:@"WebViewPreviewLinks"];
}

+ (BOOL)themeChannelViewUsesCustomScrollers
{
	return ([RZUserDefaults() boolForKey:@"WebViewDoNotUsesCustomScrollers"] == NO);
}

+ (TXChannelViewArrangement)channelViewArrangement
{
	return [RZUserDefaults() unsignedIntegerForKey:@"ChannelViewArrangement"];
}

#pragma mark -
#pragma mark Completion Suffix

+ (nullable NSString *)tabCompletionSuffix
{
	return [RZUserDefaults() objectForKey:@"Keyboard -> Tab Key Completion Suffix"];
}

+ (void)setTabCompletionSuffix:(NSString *)value
{
	NSParameterAssert(value != nil);

	[RZUserDefaults() setObject:value forKey:@"Keyboard -> Tab Key Completion Suffix"];
}

+ (BOOL)tabCompletionDoNotAppendWhitespace
{
	return [RZUserDefaults() boolForKey:@"Tab Completion -> Do Not Use Whitespace for Missing Completion Suffix"];
}

+ (BOOL)tabCompletionCutForwardToFirstWhitespace
{
	return [RZUserDefaults() boolForKey:@"Tab Completion -> Completion Suffix Cut Forward Until Space"];
}

#pragma mark -
#pragma mark File Transfers

+ (TXFileTransferRequestReply)fileTransferRequestReplyAction
{
	return [RZUserDefaults() unsignedIntegerForKey:@"File Transfers -> File Transfer Request Reply Action"];
}

+ (TXFileTransferIPAddressMethodDetection)fileTransferIPAddressDetectionMethod
{
	return [RZUserDefaults() unsignedIntegerForKey:@"File Transfers -> File Transfer IP Address Detection Method"];
}

+ (BOOL)fileTransferRequestsAreReversed
{
	return [RZUserDefaults() boolForKey:@"File Transfers -> File Transfer Requests Use Reverse DCC"];
}

+ (BOOL)fileTransfersPreventIdleSystemSleep
{
	return [RZUserDefaults() boolForKey:@"File Transfers -> Idle System Sleep Prevented During File Transfer"];
}

+ (uint16_t)fileTransferPortRangeStart
{
	return [RZUserDefaults() unsignedShortForKey:@"File Transfers -> File Transfer Port Range Start"];
}

+ (void)setFileTransferPortRangeStart:(uint16_t)value
{
	[RZUserDefaults() setUnsignedShort:value forKey:@"File Transfers -> File Transfer Port Range Start"];
}

+ (uint16_t)fileTransferPortRangeEnd
{
	return [RZUserDefaults() unsignedShortForKey:@"File Transfers -> File Transfer Port Range End"];
}

+ (void)setFileTransferPortRangeEnd:(uint16_t)value
{
	[RZUserDefaults() setUnsignedShort:value forKey:@"File Transfers -> File Transfer Port Range End"];
}

+ (nullable NSString *)fileTransferManuallyEnteredIPAddress
{
	return [RZUserDefaults() objectForKey:@"File Transfers -> File Transfer Manually Entered IP Address"];
}

+ (nullable NSString *)fileTransferIPAddressInterfaceName
{
	return [RZUserDefaults() objectForKey:@"File Transfers -> File Transfer IP Address Interface Name"];
}

#pragma mark -
#pragma mark Max Log Lines

+ (NSUInteger)scrollbackSaveLimit
{
	return [RZUserDefaults() unsignedIntegerForKey:@"ScrollbackMaximumSavedLineCount"];
}

+ (void)setScrollbackSaveLimit:(NSUInteger)scrollbackSaveLimit
{
	[RZUserDefaults() setUnsignedInteger:scrollbackSaveLimit forKey:@"ScrollbackMaximumSavedLineCount"];
}

+ (NSUInteger)scrollbackVisibleLimit
{
	return [RZUserDefaults() unsignedIntegerForKey:@"ScrollbackMaximumVisibleLineCount"];
}

+ (void)setScrollbackVisibleLimit:(NSUInteger)scrollbackVisibleLimit
{
	[RZUserDefaults() setUnsignedInteger:scrollbackVisibleLimit forKey:@"ScrollbackMaximumVisibleLineCount"];
}

#pragma mark -
#pragma mark Notifications

+ (BOOL)soundIsMuted
{
	return [RZUserDefaults() boolForKey:@"Notification Sound Is Muted"];
}

+ (void)setSoundIsMuted:(BOOL)soundIsMuted
{
	[RZUserDefaults() setBool:soundIsMuted forKey:@"Notification Sound Is Muted"];
}

+ (nullable NSString *)keyForEvent:(TXNotificationType)event category:(NSString *)category
{
	NSParameterAssert(category != nil);

	NSString *returnValue = nil;

	switch (event) {
#define _dv(key, value)		case (key): { returnValue = (value); break; }

		_dv(TXNotificationTypeAddressBookMatch, @"NotificationType -> Address Book Match -> ")
		_dv(TXNotificationTypeChannelMessage, @"NotificationType -> Public Message -> ")
		_dv(TXNotificationTypeChannelNotice, @"NotificationType -> Public Notice -> ")
		_dv(TXNotificationTypeConnect, @"NotificationType -> Connected -> ")
		_dv(TXNotificationTypeDisconnect, @"NotificationType -> Disconnected -> ")
		_dv(TXNotificationTypeHighlight, @"NotificationType -> Highlight -> ")
		_dv(TXNotificationTypeInvite, @"NotificationType -> Channel Invitation -> ")
		_dv(TXNotificationTypeKick, @"NotificationType -> Kicked from Channel -> ")
		_dv(TXNotificationTypeNewPrivateMessage, @"NotificationType -> Private Message (New) -> ")
		_dv(TXNotificationTypePrivateMessage, @"NotificationType -> Private Message -> ")
		_dv(TXNotificationTypePrivateNotice, @"NotificationType -> Private Notice -> ")
		_dv(TXNotificationTypeFileTransferSendSuccessful, @"NotificationType -> Successful File Transfer (Sending) -> ")
		_dv(TXNotificationTypeFileTransferReceiveSuccessful, @"NotificationType -> Successful File Transfer (Receiving) -> ")
		_dv(TXNotificationTypeFileTransferSendFailed, @"NotificationType -> Failed File Transfer (Sending) -> ")
		_dv(TXNotificationTypeFileTransferReceiveFailed, @"NotificationType -> Failed File Transfer (Receiving) -> ")
		_dv(TXNotificationTypeFileTransferReceiveRequested, @"NotificationType -> File Transfer Request -> ")
		_dv(TXNotificationTypeUserJoined, @"NotificationType -> User Joined -> ")
		_dv(TXNotificationTypeUserParted, @"NotificationType -> User Parted -> ")
		_dv(TXNotificationTypeUserDisconnected, @"NotificationType -> User Disconnected -> ")

#undef _dv
	}

	if (returnValue == nil) {
		return nil;
	}

	return [returnValue stringByAppendingString:category];
}

+ (nullable NSString *)soundForEvent:(TXNotificationType)event
{
	NSString *eventKey = [self keyForEvent:event category:@"Sound"];

	if (eventKey == nil) {
		return nil;
	}

	return [RZUserDefaults() objectForKey:eventKey];
}

+ (void)setSound:(nullable NSString *)value forEvent:(TXNotificationType)event
{
	NSString *eventKey = [self keyForEvent:event category:@"Sound"];

	if (eventKey == nil) {
		return;
	}

	[RZUserDefaults() setObject:value forKey:eventKey];
}

+ (BOOL)notificationEnabledForEvent:(TXNotificationType)event
{
	NSString *eventKey = [self keyForEvent:event category:@"Enabled"];

	if (eventKey == nil) {
		return NO;
	}

	return [RZUserDefaults() boolForKey:eventKey];
}

+ (void)setNotificationEnabled:(BOOL)value forEvent:(TXNotificationType)event
{
	NSString *eventKey = [self keyForEvent:event category:@"Enabled"];

	if (eventKey == nil) {
		return;
	}

	[RZUserDefaults() setBool:value forKey:eventKey];
}

+ (BOOL)disabledWhileAwayForEvent:(TXNotificationType)event
{
	NSString *eventKey = [self keyForEvent:event category:@"Disable While Away"];

	if (eventKey == nil) {
		return NO;
	}

	return [RZUserDefaults() boolForKey:eventKey];
}

+ (void)setDisabledWhileAway:(BOOL)value forEvent:(TXNotificationType)event
{
	NSString *eventKey = [self keyForEvent:event category:@"Disable While Away"];

	if (eventKey == nil) {
		return;
	}

	[RZUserDefaults() setBool:value forKey:eventKey];
}

+ (BOOL)bounceDockIconForEvent:(TXNotificationType)event
{
	NSString *eventKey = [self keyForEvent:event category:@"Bounce Dock Icon"];

	if (eventKey == nil) {
		return NO;
	}

	return [RZUserDefaults() boolForKey:eventKey];
}

+ (void)setBounceDockIcon:(BOOL)value forEvent:(TXNotificationType)event
{
	NSString *eventKey = [self keyForEvent:event category:@"Bounce Dock Icon"];

	if (eventKey == nil) {
		return;
	}

	[RZUserDefaults() setBool:value forKey:eventKey];
}

+ (BOOL)bounceDockIconRepeatedlyForEvent:(TXNotificationType)event
{
	NSString *eventKey = [self keyForEvent:event category:@"Bounce Dock Icon Repeatedly"];

	if (eventKey == nil) {
		return NO;
	}

	return [RZUserDefaults() boolForKey:eventKey];
}

+ (void)setBounceDockIconRepeatedly:(BOOL)value forEvent:(TXNotificationType)event
{
	NSString *eventKey = [self keyForEvent:event category:@"Bounce Dock Icon Repeatedly"];

	if (eventKey == nil) {
		return;
	}

	[RZUserDefaults() setBool:value forKey:eventKey];
}

+ (BOOL)speakEvent:(TXNotificationType)event
{
	NSString *eventKey = [self keyForEvent:event category:@"Speak"];

	if (eventKey == nil) {
		return NO;
	}

	return [RZUserDefaults() boolForKey:eventKey];
}

+ (void)setEventIsSpoken:(BOOL)value forEvent:(TXNotificationType)event
{
	NSString *eventKey = [self keyForEvent:event category:@"Speak"];

	if (eventKey == nil) {
		return;
	}

	[RZUserDefaults() setBool:value forKey:eventKey];
}

+ (BOOL)onlySpeakEventsForSelection
{
	return [RZUserDefaults() boolForKey:@"OnlySpeakNotificationsForSelection"];
}

+ (void)setOnlySpeakEventsForSelection:(BOOL)onlySpeakEventsForSelection
{
	[RZUserDefaults() setBool:onlySpeakEventsForSelection forKey:@"OnlySpeakNotificationsForSelection"];
}

+ (BOOL)channelMessageSpeakChannelName
{
	NSString *eventKey = [self keyForEvent:TXNotificationTypeChannelMessage category:@"Speak Channel Name"];

	return [RZUserDefaults() boolForKey:eventKey];
}

+ (void)setChannelMessageSpeakChannelName:(BOOL)channelMessageSpeakChannelName
{
	NSString *eventKey = [self keyForEvent:TXNotificationTypeChannelMessage category:@"Speak Channel Name"];

	[RZUserDefaults() setBool:channelMessageSpeakChannelName forKey:eventKey];
}

+ (BOOL)channelMessageSpeakNickname
{
	NSString *eventKey = [self keyForEvent:TXNotificationTypeChannelMessage category:@"Speak Nickname"];

	return [RZUserDefaults() boolForKey:eventKey];
}

+ (void)setChannelMessageSpeakNickname:(BOOL)channelMessageSpeakNickname
{
	NSString *eventKey = [self keyForEvent:TXNotificationTypeChannelMessage category:@"Speak Nickname"];

	[RZUserDefaults() setBool:channelMessageSpeakNickname forKey:eventKey];
}

#pragma mark -
#pragma mark World

+ (nullable NSArray<NSDictionary *> *)clientList
{
	/* Only a list: anything else (a damaged file) is treated as no servers */
	return [RZUserDefaults() arrayForKey:IRCWorldClientListDefaultsKey];
}

+ (void)setClientList:(nullable NSArray<NSDictionary *> *)clientList
{
	[RZUserDefaults() setObject:clientList forKey:IRCWorldClientListDefaultsKey];
}

#pragma mark -
#pragma mark Keywords

static NSArray<NSString *> *_excludeKeywords = nil;
static NSArray<NSString *> *_matchKeywords = nil;
static NSArray<IRCHighlightKeyword *> *_excludeKeywordEntries = nil;
static NSArray<IRCHighlightKeyword *> *_matchKeywordEntries = nil;

+ (void)_loadExcludeKeywords
{
	NSArray *keywordArrayIn = [RZUserDefaults() arrayForKey:@"Highlight List -> Excluded Matches"];

	_excludeKeywordEntries = [IRCHighlightKeyword keywordsWithDictionaries:keywordArrayIn];

	_excludeKeywords = [_excludeKeywordEntries valueForKey:@"keyword"];
}

+ (void)_loadMatchKeywords
{
	NSArray *keywordArrayIn = [RZUserDefaults() arrayForKey:@"Highlight List -> Primary Matches"];

	_matchKeywordEntries = [IRCHighlightKeyword keywordsWithDictionaries:keywordArrayIn];

	_matchKeywords = [_matchKeywordEntries valueForKey:@"keyword"];
}

/* Empty rows go, the rest is sorted; a keyword's limits and sound stay */
+ (void)_cleanUpKeywords:(NSString *)key
{
	NSArray *keywordArrayIn = [RZUserDefaults() arrayForKey:key];

	NSMutableArray<NSDictionary *> *keywordArrayOut = [NSMutableArray array];

	for (NSDictionary *keyword in keywordArrayIn) {
		if ([keyword isKindOfClass:[NSDictionary class]] == NO) {
			continue;
		}

		NSString *s = keyword[IRCHighlightKeywordStringKey];

		if ([s isKindOfClass:[NSString class]] && s.length > 0) {
			[keywordArrayOut addObject:[keyword mutableCopy]];
		}
	}

	[keywordArrayOut sortUsingComparator:^NSComparisonResult(NSDictionary *keyword1, NSDictionary *keyword2) {
		return [keyword1[IRCHighlightKeywordStringKey] caseInsensitiveCompare:keyword2[IRCHighlightKeywordStringKey]];
	}];

	[RZUserDefaults() setObject:keywordArrayOut forKey:key];
}

+ (void)cleanUpHighlightKeywords
{
	[self _cleanUpKeywords:@"Highlight List -> Primary Matches"];

	[self _cleanUpKeywords:@"Highlight List -> Excluded Matches"];
}

+ (nullable NSArray<NSString *> *)highlightMatchKeywords
{
	return _matchKeywords;
}

+ (nullable NSArray<NSString *> *)highlightExcludeKeywords
{
	return _excludeKeywords;
}

+ (nullable NSArray<IRCHighlightKeyword *> *)highlightMatchKeywordEntries
{
	return _matchKeywordEntries;
}

+ (nullable NSArray<IRCHighlightKeyword *> *)highlightExcludeKeywordEntries
{
	return _excludeKeywordEntries;
}

/* A server's own keywords (Textual 7, or a plugin) join the global lists
 once; the caller saves the server's configuration without them (D-E3.8) */
+ (void)moveServerHighlightConditions:(NSArray<IRCHighlightMatchCondition *> *)conditions clientId:(NSString *)clientId
{
	NSParameterAssert(conditions != nil);
	NSParameterAssert(clientId != nil);

	if (conditions.count == 0) {
		return;
	}

	NSArray *matchEntries = [RZUserDefaults() arrayForKey:@"Highlight List -> Primary Matches"];
	NSArray *excludeEntries = [RZUserDefaults() arrayForKey:@"Highlight List -> Excluded Matches"];

	matchEntries = [IRCHighlightKeyword entries:matchEntries mergingServerConditions:conditions excluded:NO clientId:clientId];
	excludeEntries = [IRCHighlightKeyword entries:excludeEntries mergingServerConditions:conditions excluded:YES clientId:clientId];

	[RZUserDefaults() setObject:matchEntries forKey:@"Highlight List -> Primary Matches"];
	[RZUserDefaults() setObject:excludeEntries forKey:@"Highlight List -> Excluded Matches"];

	[self cleanUpHighlightKeywords];
}

#pragma mark -
#pragma mark Key-Value Observing

+ (void)observeValueForKeyPath:(NSString *)key ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([key isEqualToString:@"Highlight List -> Primary Matches"]) {
		[self _loadMatchKeywords];
	} else if ([key isEqualToString:@"Highlight List -> Excluded Matches"]) {
		[self _loadExcludeKeywords];
	}
}

#pragma mark -
#pragma mark Migration

+ (void)_migrateWorldControllerToVersion600
{
#define _defaultsKey @"TPCPreferences -> Migration -> World Controller Migrated (600)"

	if ([RZUserDefaults() boolForKey:@"World Controller Migrated (600)"]) {
		[RZUserDefaults() removeObjectForKey:@"World Controller Migrated (600)"];

		[RZUserDefaults() setBool:YES forKey:_defaultsKey];
	}

	if ([RZUserDefaults() boolForKey:_defaultsKey]) {
		return;
	}

	BOOL clientListMigrated = [RZUserDefaults() boolForKey:_defaultsKey];

	if (clientListMigrated) {
		return;
	}

	NSDictionary *worldController = [RZUserDefaults() dictionaryForKey:@"World Controller"];

	NSArray<NSDictionary *> *clientList = [worldController arrayForKey:@"clients"];

	if (clientList.count > 0) {
		[self setClientList:clientList];
	}

	BOOL soundIsMuted = [worldController boolForKey:@"soundIsMuted"];

	if (soundIsMuted) {
		[self setSoundIsMuted:soundIsMuted];
	}

	[RZUserDefaults() setBool:YES forKey:_defaultsKey];

#undef _defaultsKey
}

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
+ (void)_migrateSparkleConfigurationToVersion601
{

#define _defaultsKey @"TPCPreferences -> Migration -> Sparkle (601)"

	BOOL sparkleMigrated = [RZUserDefaults() boolForKey:_defaultsKey];

	if (sparkleMigrated) {
		return;
	}

	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SUEnableAutomaticChecks"];

	[RZUserDefaults() setBool:YES forKey:_defaultsKey];

#undef _defaultsKey

}
#endif

+ (void)_migrateNicknameColorOverridesToVersion722
{
	/* Migrate from database that used NSArchiver to one that uses NSKeyedArchiver. */

#define _defaultsKey	@"TPCPreferences -> Migration -> Nickname Color Style Overrides"

	BOOL overridesMigrated = [RZUserDefaults() boolForKey:_defaultsKey];

	if (overridesMigrated) {
		return;
	}

	[TPCNicknameColorStyleGenerator migrateNicknameColorStyleOverrides];

	[RZUserDefaults() setBool:YES forKey:_defaultsKey];

#undef _defaultsKey

}

/* Textual 7's Caffeine extension became a built-in preference (8.0) */
+ (void)migrateCaffeinePreference
{
	NSString *extensionKey = @"Private Extension Store -> Caffeine Extension -> Prevent Sleep";

	if ([RZUserDefaults() objectForKey:extensionKey] == nil) {
		return;
	}

	/* Runs once: the extension's key is removed afterwards */
	[RZUserDefaults() setBool:[RZUserDefaults() boolForKey:extensionKey] forKey:@"PreventSleepWhileConnected"];

	[RZUserDefaults() removeObjectForKey:extensionKey];
}

+ (void)_migrateAppearanceToVersion7011 /* 7.0.11 turned into 7.1.0 */
{

#define _defaultsKey @"TPCPreferences -> Migration -> Appearance (7011)"

	BOOL appearanceMigrated = [RZUserDefaults() boolForKey:_defaultsKey];

	if (appearanceMigrated) {
		return;
	}

	BOOL invertSidebarColors = [self invertSidebarColors];

	if (invertSidebarColors) {
		[self setAppearance:TXPreferredAppearanceDark];
	}

	[RZUserDefaults() setBool:YES forKey:_defaultsKey];

#undef _defaultsKey

}

#pragma mark -
#pragma mark Dynamic Defaults 

+ (void)registerWebKit2DynamicDefaults
{
	/* The WebKit2 Web Inspector cannot work attached to Textual's main window.
	 Whose fault this is isn't clear, but I do not have time to take a deep
	 look at it at this time. To fix it temporarily, we always force it as
	 window. To prevent the user breaking Textual by attaching it, we force
	 reset the default here, every run. */

	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"__WebInspectorPageGroupLevel1__.WebKit2InspectorStartsAttached"];
}

+ (void)registerPreferencesDictionaryVersion
{
	/* We do not allow Textual to register a version lower than what is 
	 already set so that if the user opens an older version, we do not
	 perform migrations more than once. Probably would have been smart
	 to do this from the beginning. */
	NSNumber *dictionaryVersion = [RZUserDefaults() objectForKey:@"TPCPreferencesDictionaryVersion"];

	if (dictionaryVersion.integerValue >= TPCPreferencesDictionaryVersion) {
		return;
	}

	[RZUserDefaults() setUnsignedInteger:TPCPreferencesDictionaryVersion forKey:@"TPCPreferencesDictionaryVersion"];
}

#pragma mark -
#pragma mark Initialization

+ (NSDictionary<NSString *, id> *)defaultPreferences
{
	/* Note added October 2017:

	 I wrote this code a year ago and today (when the note was written),
	 I took another look at it. 95% of defaults are registered with
	 RZUserDefaults, not NSUserDefaults. So why has this code never
	 created a problem?

	 After performing more research, it turns out the registration domain
	 is app wide. It doesn't care which instance of NSUserDefaults you
	 set it on or read it from. It will be consistent app wide.

	 This is nothing exciting. I documenting this more for my own sanity. */

	return [RZUserDefaults() volatileDomainForName:NSRegistrationDomain];
}

+ (void)registerDynamicDefaults
{
	[self _populateDefaultNickname];

	[self registerWebKit2DynamicDefaults];

	NSMutableDictionary *dynamicDefaults = [NSMutableDictionary dictionary];

	[dynamicDefaults setBool:[TPCApplicationInfo sandboxEnabled]						forKey:@"Security -> Sandbox Enabled"];

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	[dynamicDefaults setBool:YES forKey:@"System -> 3rd-party Services -> Built with Sparkle Framework"];
#else
	[dynamicDefaults setBool:NO forKey:@"System -> 3rd-party Services -> Built with Sparkle Framework"];
#endif

	[RZUserDefaults() registerDefaults:dynamicDefaults];

	[self registerPreferencesDictionaryVersion];
}

+ (void)registerDefaults
{
	NSDictionary *defaults =
	[TPCResourceManager dictionaryFromResources:@"RegisteredUserDefaults" inDirectory:@"Preferences" cacheValue:NO];

	[RZUserDefaults() registerDefaults:defaults];

	[self registerDynamicDefaults];
}

+ (void)initPreferences
{
	[TPCApplicationInfo incrementApplicationRunCount];

	// ====================================================== //

	[self registerDefaults];

	[self _migrateWorldControllerToVersion600];

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	[self _migrateSparkleConfigurationToVersion601];
#endif

	[self _migrateAppearanceToVersion7011];

	[self _migrateNicknameColorOverridesToVersion722];

	[self migrateCaffeinePreference];

	[self migrateGeneralEventPreference];

	[self migrateInlineMediaLimits];

	[self migrateMemberListWidth];

	[TPCPathInfo startUsingTranscriptFolderURL];

	[RZUserDefaults() addObserver:(id)self forKeyPath:@"Highlight List -> Excluded Matches" options:NSKeyValueObservingOptionNew context:NULL];
	[RZUserDefaults() addObserver:(id)self forKeyPath:@"Highlight List -> Primary Matches" options:NSKeyValueObservingOptionNew context:NULL];

	[self _loadExcludeKeywords];
	[self _loadMatchKeywords];
}

#pragma mark -
#pragma mark NSTextView Preferences

+ (BOOL)textFieldAutomaticSpellCheck
{
	return [RZUserDefaults() boolForKey:@"TextFieldAutomaticSpellCheck"];
}

+ (void)setTextFieldAutomaticSpellCheck:(BOOL)value
{
	[RZUserDefaults() setBool:value forKey:@"TextFieldAutomaticSpellCheck"];
}

+ (BOOL)textFieldAutomaticGrammarCheck
{
	return [RZUserDefaults() boolForKey:@"TextFieldAutomaticGrammarCheck"];
}

+ (void)setTextFieldAutomaticGrammarCheck:(BOOL)value
{
	[RZUserDefaults() setBool:value forKey:@"TextFieldAutomaticGrammarCheck"];
}

+ (BOOL)textFieldAutomaticSpellCorrection
{
	return [RZUserDefaults() boolForKey:@"TextFieldAutomaticSpellCorrection"];
}

+ (void)setTextFieldAutomaticSpellCorrection:(BOOL)value
{
	[RZUserDefaults() setBool:value forKey:@"TextFieldAutomaticSpellCorrection"];
}

+ (BOOL)textFieldSmartCopyPaste
{
	return [RZUserDefaults() boolForKey:@"TextFieldSmartCopyPaste"];
}

+ (void)setTextFieldSmartCopyPaste:(BOOL)value
{
	[RZUserDefaults() setBool:value forKey:@"TextFieldSmartCopyPaste"];
}

+ (BOOL)textFieldSmartQuotes
{
	return [RZUserDefaults() boolForKey:@"TextFieldSmartQuotes"];
}

+ (void)setTextFieldSmartQuotes:(BOOL)value
{
	[RZUserDefaults() setBool:value forKey:@"TextFieldSmartQuotes"];
}

+ (BOOL)textFieldSmartDashes
{
	return [RZUserDefaults() boolForKey:@"TextFieldSmartDashes"];
}

+ (void)setTextFieldSmartDashes:(BOOL)value
{
	[RZUserDefaults() setBool:value forKey:@"TextFieldSmartDashes"];
}

+ (BOOL)textFieldSmartLinks
{
	return [RZUserDefaults() boolForKey:@"TextFieldSmartLinks"];
}

+ (void)setTextFieldSmartLinks:(BOOL)value
{
	[RZUserDefaults() setBool:value forKey:@"TextFieldSmartLinks"];
}

+ (BOOL)textFieldDataDetectors
{
	return [RZUserDefaults() boolForKey:@"TextFieldDataDetectors"];
}

+ (void)setTextFieldDataDetectors:(BOOL)value
{
	[RZUserDefaults() setBool:value forKey:@"TextFieldDataDetectors"];
}

+ (BOOL)textFieldTextReplacement
{
	return [RZUserDefaults() boolForKey:@"TextFieldTextReplacement"];
}

+ (void)setTextFieldTextReplacement:(BOOL)value
{
	[RZUserDefaults() setBool:value forKey:@"TextFieldTextReplacement"];
}

@end

NS_ASSUME_NONNULL_END
