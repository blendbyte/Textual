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

#import "TXAppearancePrivate.h"
#import "NSObjectHelperPrivate.h"
#import "TXMasterControllerPrivate.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCThemeControllerPrivate.h"
#import "IRCClientPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCCommandIndexPrivate.h"
#import "IRCWorld.h"
#import "TLOInputHistoryPrivate.h"
#import "TVCDockIconPrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogControllerHistoricLogFilePrivate.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowTextViewPrivate.h"
#import "TVCServerListPrivate.h"
#import "TVCMemberListPrivate.h"
#import "TVCMemberListAppearance.h"
#import "TPCPreferencesReload.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Public

@implementation TPCPreferences (TPCPreferencesReload)

+ (void)performReloadActionForKeys:(NSArray<NSString *> *)keys
{
	NSParameterAssert(keys != nil);

	TPCPreferencesReloadAction reloadAction = 0;

	/* Style specific reloads... */
	if ([keys containsObject:@"AutomaticallyFilterUnicodeTextSpam"] ||
		[keys containsObject:@"ConversationTrackingIncludesUserModeSymbol"] ||
		[keys containsObject:@"DisableRemoteNicknameColorHashing"] ||
		[keys containsObject:@"DisplayEventInLogView -> Date Changes"] ||
		[keys containsObject:@"DisplayEventInLogView -> Inline Media"] ||
		[keys containsObject:@"DisplayEventInLogView -> Join, Part, Quit"] ||
		[keys containsObject:@"Theme -> Nickname Format"] ||
		[keys containsObject:@"Theme -> Timestamp Format"] ||
		[keys containsObject:@"Theme -> Channel Font Preference Enabled"] ||
		[keys containsObject:@"Theme -> Nickname Format Preference Enabled"] ||
		[keys containsObject:@"Theme -> Timestamp Format Preference Enabled"] ||
		[keys containsObject:TPCPreferencesThemeFontNameDefaultsKey] ||
		[keys containsObject:TPCPreferencesThemeFontSizeDefaultsKey] ||
		[keys containsObject:TPCPreferencesThemeNameDefaultsKey])
	{
		reloadAction |= TPCPreferencesReloadActionStyle;
	}

	/* Highlight lists */
	if ([keys containsObject:@"Highlight List -> Excluded Matches"] ||
		[keys containsObject:@"Highlight List -> Primary Matches"])
	{
		reloadAction |= TPCPreferencesReloadActionHighlightKeywords;
	}

	/* Highlight logging */
	if ([keys containsObject:@"LogHighlights"]) {
		reloadAction |= TPCPreferencesReloadActionHighlightLogging;
	}

	/* Text direction: right-to-left, left-to-right */
	if ([keys containsObject:@"RightToLeftTextFormatting"]) {
		reloadAction |= TPCPreferencesReloadActionTextDirection;
	}

	/* Text field font size */
	if ([keys containsObject:@"Main Input Text Field -> Font Size"]) {
		reloadAction |= TPCPreferencesReloadActionTextFieldFontSize;
	}

	/* Input history scope */
	if ([keys containsObject:@"SaveInputHistoryPerSelection"]) {
		reloadAction |= TPCPreferencesReloadActionInputHistoryScope;
	}

	/* Main window segmented controller */
	if ([keys containsObject:@"DisableMainWindowSegmentedController"]) {
		reloadAction |= TPCPreferencesReloadActionTextFieldSegmentedControllerOrigin;
	}

	/* Main window alpha level */
	if ([keys containsObject:@"MainWindowTransparencyLevel"]) {
		reloadAction |= TPCPreferencesReloadActionMainWindowTransparencyLevel;
	}

	/* Dock icon */
	if ([keys containsObject:@"DisplayDockBadges"] ||
		[keys containsObject:@"DisplayPublicMessageCountInDockBadge"])
	{
		reloadAction |= TPCPreferencesReloadActionDockIconBadges;
	}

	/* Main window appearance */
	if ([keys containsObject:@"Appearance"]) {
		reloadAction |= TPCPreferencesReloadActionAppearance;
	}

	/* Member list sort order */
	if ([keys containsObject:@"MemberListSortFavorsServerStaff"]) {
		reloadAction |= TPCPreferencesReloadActionMemberListSortOrder;
	}

	/* Member list user badge colors */
	if ([keys containsObject:@"DisplayUserListNoModeSymbol"] ||
		[keys containsObject:@"User List Mode Badge Colors -> +y"] ||
		[keys containsObject:@"User List Mode Badge Colors -> +q"] ||
		[keys containsObject:@"User List Mode Badge Colors -> +a"] ||
		[keys containsObject:@"User List Mode Badge Colors -> +o"] ||
		[keys containsObject:@"User List Mode Badge Colors -> +h"] ||
		[keys containsObject:@"User List Mode Badge Colors -> +v"] ||
		[keys containsObject:@"User List Mode Badge Colors -> no mode"])
	{
		reloadAction |= TPCPreferencesReloadActionMemberList;
		reloadAction |= TPCPreferencesReloadActionMemberListUserBadges;
	}

	/* Server list unread count badge colors */
	if ([keys containsObject:@"Server List Unread Message Count Badge Colors -> Highlight"]) {
		reloadAction |= TPCPreferencesReloadActionServerListUnreadBadges;
	}

	/* Sparkle framework update feed URL */
#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	if ([keys containsObject:@"ReceiveBetaUpdates"]) {
		reloadAction |= TPCPreferencesReloadActionSparkleFrameworkFeedURL;
	}
#endif

	/* Developer mode */
	if ([keys containsObject:@"TextualDeveloperEnvironment"]) {
		reloadAction |= TPCPreferencesReloadActionIRCCommandCache;
	}

	/* Scrollback limit */
	if ([keys containsObject:@"ScrollbackMaximumSavedLineCount"]) {
		reloadAction |= TPCPreferencesReloadActionScrollbackSaveLimit;
	}

	if ([keys containsObject:@"ScrollbackMaximumVisibleLineCount"]) {
		reloadAction |= TPCPreferencesReloadActionScrollbackVisibleLimit;
	}

	/* Channel view arrangement */
	if ([keys containsObject:@"ChannelViewArrangement"]) {
		reloadAction |= TPCPreferencesReloadActionChannelViewArrangement;
	}

	/* After this is all complete; we call -preferencesChanged just to take 
	 care of everything else that does not need specific reloads. */
	reloadAction |= TPCPreferencesReloadActionPreferencesChanged;

	[self performReloadAction:reloadAction];
}

+ (void)performReloadAction:(TPCPreferencesReloadAction)reloadAction
{
	[self performReloadAction:reloadAction forKey:nil];
}

+ (void)performReloadAction:(TPCPreferencesReloadAction)reloadAction forKey:(nullable NSString *)key
{
	/* Update dock icon */
	if ((reloadAction & TPCPreferencesReloadActionDockIconBadges) == TPCPreferencesReloadActionDockIconBadges) {
		[TVCDockIcon updateDockIcon];
	}

	/* As reloading the theme will also reload the server and member list, we keep
	 track of whether that happened so it is not performed more than one time. */
	BOOL didReloadActiveStyle = NO;

	BOOL didReloadUserInterface = NO;

	/* Member list appearance */
	if ((reloadAction & TPCPreferencesReloadActionMemberListUserBadges) == TPCPreferencesReloadActionMemberListUserBadges) {
		/* We invalidate this early because a separate action may
		 which is attached to our mask may reload the drawings for
		 us so until we know if that happened, we wait. */

		/* If we know FOR CERTAIN we only are ONLY reloading the user badges
		 and we have a key for context, then be more efficient by only updating
		 drawings related to this preference. The member list automatically
		 invalidates its caches when passing a recognized key. */ 
		if (reloadAction == TPCPreferencesReloadActionMemberListUserBadges && key != nil) {
			[mainWindowMemberList() refreshDrawingForChangesToPreference:key];
		} else {
			[mainWindowMemberList().userInterfaceObjects invalidateUserMarkBadgeCaches];
		}
	}

	/* Window appearance */
	if ((reloadAction & TPCPreferencesReloadActionAppearance) == TPCPreferencesReloadActionAppearance) {
		[[TXSharedApplication sharedAppearance] updateAppearance];

		didReloadUserInterface = YES;
	}

	/* Active style */
	if ((reloadAction & TPCPreferencesReloadActionStyle) == TPCPreferencesReloadActionStyle) {
		[themeController() reload];

		[mainWindow() reloadTheme];

		didReloadActiveStyle = YES;
	}

	/* Server list */
	if ((reloadAction & TPCPreferencesReloadActionServerList) == TPCPreferencesReloadActionServerList) {
		if (didReloadUserInterface == NO) {
			[mainWindowServerList() applicationAppearanceChanged];
		}
	} else if ((reloadAction & TPCPreferencesReloadActionServerListUnreadBadges) == TPCPreferencesReloadActionServerListUnreadBadges) {
		if (didReloadUserInterface == NO) {
			/* The color used for unread badges also apply to the text color so
			 we must reload all drawings instead of only the badges themselves. */
			[mainWindowServerList() refreshAllDrawings];
		}
	}

	/* Member list appearance */
	if ((reloadAction & TPCPreferencesReloadActionMemberList) == TPCPreferencesReloadActionMemberList) {
		if (didReloadUserInterface == NO) {
			[mainWindowMemberList() applicationAppearanceChanged];
		}
	}

	/* Member list sort order */
	BOOL didReloadMemberListSortOrder = NO;

	if ((reloadAction & TPCPreferencesReloadActionMemberListSortOrder) == TPCPreferencesReloadActionMemberListSortOrder) {
		for (IRCClient *u in worldController().clientList) {
			for (IRCChannel *c in u.channelList) {
				[c sortMembers];
			}
		}

		didReloadMemberListSortOrder = YES;
	}

	/* Member list appearance */
	if ((reloadAction & TPCPreferencesReloadActionMemberList) == TPCPreferencesReloadActionMemberList) {
		/* Sort order will redraw these for us */
		if (didReloadMemberListSortOrder == NO) {
			[mainWindowMemberList() refreshAllDrawings];
		}
	}

	/* Main window segmented controller */
	if ((reloadAction & TPCPreferencesReloadActionTextFieldSegmentedControllerOrigin) == TPCPreferencesReloadActionTextFieldSegmentedControllerOrigin) {
		[mainWindowTextField() reloadOriginPointsAndRecalculateSize];
	}

	/* Main window alpha level */
	if ((reloadAction & TPCPreferencesReloadActionMainWindowTransparencyLevel) == TPCPreferencesReloadActionMainWindowTransparencyLevel) {
		[mainWindow() updateAlphaValueToReflectPreferences];
	}

	/* Highlight keywords */
	if ((reloadAction & TPCPreferencesReloadActionHighlightKeywords) == TPCPreferencesReloadActionHighlightKeywords) {
		[self cleanUpHighlightKeywords];
	}

	/* Highlight logging */
	if ((reloadAction & TPCPreferencesReloadActionHighlightLogging) == TPCPreferencesReloadActionHighlightLogging) {
		if ([self logHighlights] == NO) {
			for (IRCClient *u in worldController().clientList) {
				[u clearCachedHighlights];
			}
		}
	}

	/* Text direction: right-to-left, left-to-right */
	if ((reloadAction & TPCPreferencesReloadActionTextDirection) == TPCPreferencesReloadActionTextDirection) {
		[mainWindowTextField() updateTextDirection];

		if (didReloadActiveStyle == NO) {
			[mainWindow() reloadTheme];
		}
	}

	/* Text field font size */
	if ((reloadAction & TPCPreferencesReloadActionTextFieldFontSize) == TPCPreferencesReloadActionTextFieldFontSize) {
		[mainWindowTextField() updateTextBasedOnPreferredFontSize];
	}

	/* Input history scope */
	if ((reloadAction & TPCPreferencesReloadActionInputHistoryScope) == TPCPreferencesReloadActionInputHistoryScope) {
		[mainWindow().inputHistoryManager noteInputHistoryObjectScopeDidChange];
	}

	/* Sparkle framework update feed URL */
#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	if ((reloadAction & TPCPreferencesReloadActionSparkleFrameworkFeedURL) == TPCPreferencesReloadActionSparkleFrameworkFeedURL) {
		[masterController() prepareThirdPartyServiceSparkleFramework];
	}
#endif

	/* Command index cache */
	if ((reloadAction & TPCPreferencesReloadActionIRCCommandCache) == TPCPreferencesReloadActionIRCCommandCache) {
		[IRCCommandIndex invalidateCaches];
	}

	/* Transcript folder URL */
	if ((reloadAction & TPCPreferencesReloadActionLogTranscripts) == TPCPreferencesReloadActionLogTranscripts) {
		for (IRCClient *u in worldController().clientList) {
			[u reopenLogFileIfNeeded];

			for (IRCChannel *c in u.channelList) {
				[c reopenLogFileIfNeeded];
			}
		}
	}

	/* Scrollback limit */
	if ((reloadAction & TPCPreferencesReloadActionScrollbackSaveLimit) == TPCPreferencesReloadActionScrollbackSaveLimit) {
		[TVCLogControllerHistoricLogSharedInstance() resetMaximumLineCount];
	}

	if ((reloadAction & TPCPreferencesReloadActionScrollbackVisibleLimit) == TPCPreferencesReloadActionScrollbackSaveLimit) {
		for (IRCClient *u in worldController().clientList) {
			[u.viewController changeScrollbackLimit];

			for (IRCChannel *c in u.channelList) {
				[c.viewController changeScrollbackLimit];
			}
		}
	}

	/* Channel view arrangement */
	if ((reloadAction & TPCPreferencesReloadActionChannelViewArrangement) == TPCPreferencesReloadActionChannelViewArrangement) {
		[mainWindow() updateChannelViewArrangement];
	}

	/* World controller preferences changed call */
	if ((reloadAction & TPCPreferencesReloadActionPreferencesChanged) == TPCPreferencesReloadActionPreferencesChanged) {
		[worldController() preferencesChanged];

		[mainWindow() preferencesChanged];
	}
}

@end

NS_ASSUME_NONNULL_END
