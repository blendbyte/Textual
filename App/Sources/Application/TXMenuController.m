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

#import "NSObjectHelperPrivate.h"
#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCChannelMode.h"
#import "IRCChannelUser.h"
#import "IRCExtrasPrivate.h"
#import "IRCISupportInfo.h"
#import "IRCUser.h"
#import "IRCWorldPrivate.h"
#import "TVCBasicTableView.h"
#import "TVCLogController.h"
#import "TVCLogViewPrivate.h"
#import "TVCLogViewInternalWK2.h"
#import "TVCMemberList.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowSplitView.h"
#import "TVCMainWindowTextView.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLOLocalization.h"
#import "TLOpenLink.h"
#import "TDCAboutDialogPrivate.h"
#import "TDCAlert.h"
#import "TDCChannelInviteSheetPrivate.h"
#import "TDCChannelModifyModesSheetPrivate.h"
#import "TDCChannelModifyTopicSheetPrivate.h"
#import "TDCChannelPropertiesSheetPrivate.h"
#import "TDCChannelSpotlightControllerPrivate.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCInputPrompt.h"
#import "TDCLicenseManagerDialogPrivate.h"
#import "TDCNicknameColorSheetPrivate.h"
#import "TDCPreferencesControllerPrivate.h"
#import "TDCServerChangeNicknameSheetPrivate.h"
#import "TDCServerHighlightListSheetPrivate.h"
#import "TDCServerPropertiesSheetPrivate.h"
#import "TDCWelcomeSheetPrivate.h"
#import "TPCPathInfoPrivate.h"
#import "TPCPreferencesImportExport.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesReload.h"
#import "TPCPreferencesUserDefaults.h"
#import "TXMasterControllerPrivate.h"
#import "TXWindowControllerPrivate.h"
#import "TXMenuControllerInternal.h"

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
#import <Sparkle/Sparkle.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation TXMenuController

- (void)prepareInitialState
{
	self.currentSearchPhrase = @"";

	if ([TPCPreferences soundIsMuted]) {
		self.muteNotificationsSoundsDockMenuItem.state = NSControlStateValueOn;
		self.muteNotificationsSoundsFileMenuItem.state = NSControlStateValueOn;
	}

	[self.channelViewGeneralMenu itemWithTag:MTWKGeneralChannelMenu].submenu = [self.mainMenuChannelMenu copy];

	[self setupOtherServices];

	[RZNotificationCenter() addObserver:self selector:@selector(menuItemWillPerformedAction:) name:NSMenuWillSendActionNotification object:nil];
	[RZNotificationCenter() addObserver:self selector:@selector(menuItemPerformedAction:) name:NSMenuDidSendActionNotification object:nil];

	[RZNotificationCenter() addObserver:self selector:@selector(mainWindowSelectionChanged:) name:TVCMainWindowSelectionChangedNotification object:nil];
}

- (void)setupOtherServices
{
	[self.fileTransferController startUsingDownloadDestinationURL];
}

- (void)prepareForApplicationTermination
{
	LogToConsoleTerminationProgress("Preparing menu controller");

	[self.fileTransferController prepareForApplicationTermination];
}

- (void)preferencesChanged
{
	[self.fileTransferController clearIPAddress];
}

- (void)mainWindowSelectionChanged:(NSNotification *)notification
{
	if (self.menuIsOpen == NO) {
		[self resetSelectedItems];
	}

	/* When the selection changes, menus that may be dynamic are force
	 revalidated so that Command I (or other shortcuts) work with channel
	 selected, but not for the server console. */
	NSMenuItem *channelMenu = self.mainMenuChannelMenuItem;

	[self _forceMenuItemValidation:channelMenu];

	NSMenuItem *queryMenu = self.mainMenuQueryMenuItem;

	[self _forceMenuItemValidation:queryMenu];
}

- (void)_forceMenuValidation:(NSMenu *)menu
{
	NSParameterAssert(menu != nil);

	for (NSMenuItem *menuItem in menu.itemArray) {
		[self _forceMenuItemValidation:menuItem];
	}
}

- (void)_forceMenuItemValidation:(NSMenuItem *)menuItem
{
	NSParameterAssert(menuItem != nil);

	id target = menuItem.target;

	if (target == nil) {
		return;
	}

	if ([target respondsToSelector:@selector(validateMenuItem:)]) {
		[target performSelector:@selector(validateMenuItem:) withObject:menuItem];
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	NSParameterAssert(menuItem != nil);

	if (masterController().applicationIsTerminating) {
		return NO;
	}

	/* Menu validation works in two passes:
		 1. First -_validateMenuItem: is called which performs validation for
		    the individual menu item including hiding it and related items.
		 2. The result is then passed to the logic below which performs more
		    specialized work such as disabling large group of menu items when
		    the trial has expired.
	 */
	BOOL validationResult = [self _validateMenuItem:menuItem];

	if (validationResult == NO) {
		return NO;
	}

	NSUInteger tag = menuItem.tag;

	/* The submenus of the main menu are all targets of the menu
	 controller so that we can chose to hide or show some depending
	 on context. For the top most submenus, we have nothing further
	 to do after performing initial validation. */
	switch (tag) {
		case MTMainMenuApp:
		case MTMainMenuFile:
		case MTMainMenuEdit:
		case MTMainMenuView:
		case MTMainMenuServer:
		case MTMainMenuChannel:
		case MTMainMenuQuery:
		case MTMainMenuNavigate:
		case MTMainMenuWindow:
		case MTMainMenuHelp:
		{
			return YES;
		}
	} // switch

	/* When the main window is not the focused window or when we are
	 in a sheet, most items can be disabled which means at this point
	 we will default to disabled and allow the bottom logic to enable
	 only the bare essentials. */
	BOOL defaultToNoForSheet = ( mainWindow().attachedSheet != nil ||
								(mainWindow().mainWindow == NO &&
								 mainWindow().isBeneathMouse == NO));

	if (defaultToNoForSheet) {
		validationResult = NO;
	}

	/* If the app has not finished launching,
	 then default everything to disabled. */
	if (masterController().applicationIsLaunched == NO) {
		validationResult = NO;
	}

	/* If trial is expired, then default everything to disabled. */
	BOOL isTrialExpired = NO;

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
	if (TLOLicenseManagerTextualIsRegistered() == NO && TLOLicenseManagerIsTrialExpired()) {
		/* Set flag letting logic know trial expired */
		isTrialExpired = YES;

		/* Disable everything by default except "Manage license…" and the
		 import, which brings a Textual 7 licence along */
		validationResult = (tag == MTMMAppManageLicense || tag == MTMMFileImportFromEarlierVersion);
	} // if
#endif

	/* If certain items are hidden because of sheet but not because
	 of the trial being expired, then enable additional items. */
	if (validationResult == NO && defaultToNoForSheet && isTrialExpired == NO) {
		switch (tag) {
			case MTMMAppAboutApp: // "About Textual"
			case MTMMAppPreferences: // "Preferences…"
			case MTMMAppManageLicense: // "Manage license…"
			case MTMMAppCheckForUpdates: // "Check for updates…"
			case MTMMHelpAdvancedMenuEnableDeveloperMode: // "Enable Developer Mode"
			case MTMMHelpAdvancedMenuHiddenPreferences: // "Hidden Preferences…"
			case MTMMFileDisableAllNotifications: // "Disable All Notifications"
			case MTMMFileDisableAllNotificationSounds: // "Disable All Notification Sounds"
			case MTDockMenuDisableAllNotifications: // "Disable All Notifications"
			case MTDockMenuDisableAllNotificationSounds: // "Disable All Notification Sounds"
			{
				validationResult = YES;

				break;
			}
		} // switch
	} // if

	/* These are the bare minimum of menu items that must be enabled
	 at all times because they are essential to the entire application. */
	/* This list may look incomplete but it isn't. Many menu items,
	 such as Undo, Cut, Copy, Quit, etc. are not a target of the menu
	 controller which means they never pass through this logic. */
	if (validationResult == NO) {
		switch (tag) {
			case MTMMAppAboutApp: // "About Textual"
			case MTMMAppQuitApp: // "Quit Textual & IRC"
			case MTMMFilePrint: // "Print"
			case MTMMFileCloseWindow: // "Close Window"
			case MTMMEditPaste: // "Paste"
			case MTMMViewToggleFullscreen: // "Toggle Fullscreen"
			case MTMMWindowMainWindow: // "Main Window"
			case MTMMHelpAcknowledgements: // "Acknowledgements"
			case MTMMHelpLicenseAgreement: // "License Agreement"
			case MTMMHelpPrivacyPolicy: // "Privacy Policy"
			case MTMMHelpFrequentlyAskedQuestions: // "Frequently Asked Questions"
			case MTMMHelpKnowledgeBaseMenu: // "Knowledge Base"
			case MTMMHelpAdvancedMenu: // "Advanced"
			case MTMMHelpAdvancedMenuExportPreferences: // "Export Preferences"
			{
				validationResult = YES;

				break;
			}
			default:
			{
				if (menuItem.parentItem.tag == MTMMHelpKnowledgeBaseMenu) {
					validationResult = YES;
				}

				break;
			}
		} // switch
	} // if

	return validationResult;
}

- (BOOL)_validateMenuItem:(NSMenuItem *)menuItem
{
	NSParameterAssert(menuItem != nil);

	NSUInteger tag = menuItem.tag;

	IRCClient *u = mainWindow().selectedClient;
	IRCChannel *c = mainWindow().selectedChannel;

	switch (tag) {
		case MTMainMenuChannel: // "Channel"
		{
			BOOL isChannel = c.isChannel;

			menuItem.hidden = (isChannel == NO);

			if (isChannel) {
				menuItem.submenu = self.mainMenuChannelMenu;
			} else {
				menuItem.submenu = nil;
			}

			return YES;
		}
		case MTMainMenuQuery: // "Query"
		{
			BOOL isQuery = (c.isPrivateMessage || c.isUtility);

			menuItem.hidden = (isQuery == NO);

			if (isQuery) {
				menuItem.submenu = self.mainMenuQueryMenu;
			} else {
				menuItem.submenu = nil;
			}

			return YES;
		}

		case MTMMAppManageLicense: // "Manage license…"
		{
#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 0
			menuItem.hidden = YES;
#endif

			return YES;
		}
		case MTMMAppCheckForUpdates: // "Check for Updates"
		{
#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 0
			menuItem.hidden = YES;
#endif

			return YES;
		}

		case MTMMFileCloseWindow: // "Close Window"
		{
			TXCommandWKeyAction keyAction = [TPCPreferences commandWKeyAction];

			if (keyAction == TXCommandWKeyActionCloseWindow || mainWindow().keyWindow == NO) {
				menuItem.title = TXTLS(@"BasicLanguage[1f6-bg]");

				return YES;
			}

			if (u == nil) {
				return NO;
			}

			switch (keyAction) {
				case TXCommandWKeyActionPartChannel:
				{
					if (c == nil) {
						menuItem.title = TXTLS(@"BasicLanguage[1f6-bg]");

						return NO;
					}

					if (c.isChannel) {
						menuItem.title = TXTLS(@"BasicLanguage[5td-3f]");

						if (c.isActive == NO) {
							return NO;
						}
					} else if (c.isPrivateMessage) {
						menuItem.title = TXTLS(@"BasicLanguage[hri-l0]");
					} else if (c.isUtility) {
						menuItem.title = TXTLS(@"BasicLanguage[hri-l0]");
					}

					break;
				}
				case TXCommandWKeyActionDisconnect:
				{
					menuItem.title = TXTLS(@"BasicLanguage[w3a-je]", u.networkNameAlt);

					if (u.isConnecting == NO && u.isConnected == NO) {
						return NO;
					}

					break;
				}
				case TXCommandWKeyActionTerminate:
				{
					menuItem.title = TXTLS(@"BasicLanguage[x97-ro]");

					break;
				}
				default:
				{
					break;
				}
			}

			return YES;
		}

		case MTMMEditPaste: // "Paste"
		case MTWKGeneralPaste: // "Paste" (WebView)
		{
			NSString *currentPasteboard = RZPasteboard().stringContent;

			if (currentPasteboard.length == 0) {
				return NO;
			}

			if (mainWindow().keyWindow) {
				return mainWindowTextField().editable;
			}

			id firstResponder = [NSApp keyWindow].firstResponder;

			if ([firstResponder respondsToSelector:@selector(isEditable)]) {
				return [firstResponder isEditable];
			}

			return NO;
		}

		case MTMMViewMarkScrollback: // "Mark Scrollback"
		case MTMMViewScrollbackMarker: // "Scrollback Marker"
		case MTMMViewMarkAllAsRead: // "Mark All as Read"
		case MTMMViewClearScrollback: // "Clear Scrollback"
		case MTMMViewIncreaseFontSize: // "Increase Font Size"
		case MTMMViewDecreaseFontSize: // "Decrease Font Size"
		case MTMMNavigationJumpToCurrentSession: // "Jump to Current Session"
		case MTMMNavigationJumpToPresent: // "Jump to Present"
		{
			return (self.selectedViewController != nil);
		}
		case MTMMViewToggleFullscreen:
		{
			NSWindowCollectionBehavior collectionBehavior = [NSApp keyWindow].collectionBehavior;

			return ((collectionBehavior & NSWindowCollectionBehaviorFullScreenAuxiliary) == NSWindowCollectionBehaviorFullScreenAuxiliary ||
					(collectionBehavior & NSWindowCollectionBehaviorFullScreenPrimary) == NSWindowCollectionBehaviorFullScreenPrimary);
		}

		case MTMMServerConnect: // "Connect"
		{
			if (u == nil) {
				menuItem.hidden = NO;
				
				return NO;
			}

			BOOL connected = (u.isConnected || u.isConnecting);
			
			menuItem.hidden = connected;

			return (connected == NO && u.isQuitting == NO);
		}
		case MTMMServerConnectWithoutProxy: // "Connect Without Proxy"
		{
			NSUInteger flags = ([NSEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask);

			if (flags != NSEventModifierFlagShift) {
				menuItem.hidden = YES;

				return NO;
			}

			if (u == nil) {
				menuItem.hidden = YES;

				return NO;
			}

			BOOL condition = (u.isConnected || u.isConnecting ||
					u.config.proxyType == IRCConnectionProxyTypeNone);

			menuItem.hidden = condition;

			return (condition == NO && u.isQuitting == NO);
		}
		case MTMMServerDisconnect: // "Disconnect"
		{
			BOOL connected = (u.isConnected || u.isConnecting);
			
			menuItem.hidden = (connected == NO);
			
			return connected;
		}
		case MTMMServerCancelReconnect: // "Cancel Reconnect"
		{
			BOOL reconnecting = u.isReconnecting;
			
			menuItem.hidden = (reconnecting == NO);
			
			return reconnecting;
		}
		case MTMMServerChannelList: // "Channel List…"
		{
			return u.isLoggedIn;
		}
		case MTMMServerChangeNickname: // "Change Nickname…"
		case MTWKGeneralChangeNickname: // "Change Nickname…"
		{
			return u.isConnected;
		}
		case MTMMServerDuplicateServer: // "Duplicate Server"
		case MTMMServerAddChannel: // "Add Channel…"
		case MTMMServerServerProperties: // "Server Properties…"
		{
			return (u != nil);
		}
		case MTMMServerDeleteServer: // "Delete Server…"
		{
			return (u && u.isConnecting == NO && u.isConnected == NO);
		}

		case MTMMNavigationNextHighlight: // "Next Highlight"
		case MTMMNavigationPreviousHighlight: // "Previous Highlight"
		{
			TVCLogController *viewController = self.selectedViewController;

			if (viewController == nil) {
				return NO;
			}

			return [viewController highlightAvailable:(tag == MTMMNavigationPreviousHighlight)];
		}

		case MTMMChannelJoinChannel: // "Join Channel"
		{
			menuItem.hidden = (u.isLoggedIn == NO || c.isActive);

			return YES;
		}
		case MTMMChannelLeaveChannel: // "Leave Channel"
		{
			menuItem.hidden = (u.isLoggedIn == NO || c.isActive == NO);

			NSMenuItem *joinChannel = [menuItem.menu itemWithTag:MTMMChannelJoinChannel];

			[menuItem.menu itemWithTag:MTMMChannelLeaveChannelSeparator].hidden = (menuItem.hidden && joinChannel.hidden);

			return YES;
		}
		case MTMMChannelAddChannel: // "Add Channel…"
		{
			return (u != nil);
		}
		case MTMMChannelViewLogs: // "View Logs"
		{
			return [TPCPreferences logToDiskIsEnabled];
		}
		case MTMMChannelModifyTopic: // "Modify Topic"
		case MTMMChannelModesMenu: // "Modes"
		case MTMMChannelListOfBans: // "List of Bans"
		{
			return (u.isLoggedIn && c.isActive);
		}
		case MTMMChannelListOfBanExceptions: // "List of Ban Exceptions"
		{
			menuItem.hidden = ([u.supportInfo isListSupported:IRCISupportInfoListTypeBanException] == NO);

			return (u.isLoggedIn && c.isActive);
		}
		case MTMMChannelListOfInviteExceptions: // "List of Invite Exceptions"
		{
			menuItem.hidden = ([u.supportInfo isListSupported:IRCISupportInfoListTypeInviteException] == NO);

			return (u.isLoggedIn && c.isActive);
		}
		case MTMMChannelListOfQuiets: // "List of Quiets"
		{
			menuItem.hidden = ([u.supportInfo isListSupported:IRCISupportInfoListTypeQuiet] == NO);

			return (u.isLoggedIn && c.isActive);
		}

		case MTMMQueryQueryLogs: // "Query Logs"
		{
			/* Query menu is used for utility windows too so we
			 hide "Query Logs" for anything except private messages. */
			BOOL isQuery = c.isPrivateMessage;

			menuItem.hidden = (isQuery == NO);

			[menuItem.menu itemWithTag:MTMMQueryCloseQuerySeparator].hidden = (isQuery == NO);

			return [TPCPreferences logToDiskIsEnabled];
		}

		case MTMMWindowToggleVisibilityOfServerList: // "Toggle Visibility of Server List"
		case MTMMWindowSortChannelList: // "Sort Channel List"
		case MTMMWindowCenterWindow: // "Center Window"
		case MTMMWindowResetWindowToDefaultSize: // "Reset Window to Default Size"
		{
			BOOL isMainWindowMain = mainWindow().mainWindow;

			menuItem.hidden = (isMainWindowMain == NO);

			if (tag == MTMMWindowSortChannelList) {
				[menuItem.menu itemWithTag:MTMMWindowSortChannelListSeparator].hidden = (isMainWindowMain == NO);
			} else if (tag == MTMMWindowResetWindowToDefaultSize) {
				[menuItem.menu itemWithTag:MTMMWindowResetWindowToDefaultSizeSeparator].hidden = (isMainWindowMain == NO);
			}

			return YES;
		}
		case MTMMWindowMainWindow: // "Main Window"
		{
			BOOL isMainWindowMain = mainWindow().mainWindow;
			BOOL isMainWindowDisabled = mainWindow().disabled;

			menuItem.hidden = isMainWindowMain;

			return (isMainWindowDisabled == NO);
		}
		case MTMMWindowToggleVisibilityOfMemberList: // "Toggle Visibility of Member List"
		{
			BOOL isMainWindowMain = mainWindow().mainWindow;

			menuItem.hidden = (isMainWindowMain == NO);

			return c.isChannel;
		}
		case MTMMWindowToggleWindowAppearance: // "Toggle Window Appearance"
		{
			BOOL isMainWindowMain = mainWindow().mainWindow;

			menuItem.hidden = (isMainWindowMain == NO);

			[menuItem.menu itemWithTag:MTMMWindowToggleWindowAppearanceSeparator].hidden = (isMainWindowMain == NO);

			return YES;
		}
		case MTMMWindowAddressBook: // "Address Book"
		case MTMMWindowIgnoreList: // "Ignore List"
		{
			BOOL isMainWindowMain = mainWindow().mainWindow;

			menuItem.hidden = (isMainWindowMain == NO);

			return (u != nil);
		}
		case MTMMWindowViewLogs: // "View Logs"
		{
			return [TPCPreferences logToDiskIsEnabled];
		}
		case MTMMWindowHighlightList: // "Highlight List"
		{
			BOOL isMainWindowMain = mainWindow().mainWindow;

			menuItem.hidden = (isMainWindowMain == NO);

			if (u == nil) {
				return NO;
			}

			return [TPCPreferences logHighlights];
		}

		case MTUserControlsAddIgnore: // "Add Ignore"
		{
			/* To make it as efficient as possible, we only check for ignore
			 for the "Add Ignore" menu item. When that menu item is validated,
			 we validate "Modify Ignore" and "Remove Ignore" at the same time. */
			NSMenuItem *modifyIgnoreMenuItem = [menuItem.menu itemWithTag:MTUserControlsModifyIgnore];
			NSMenuItem *removeIgnoreMenuItem = [menuItem.menu itemWithTag:MTUserControlsRemoveIgnore];

			if (c.isUtility) {
				modifyIgnoreMenuItem.hidden = YES;

				removeIgnoreMenuItem.hidden = YES;

				menuItem.hidden = NO;

				return NO;
			}

			/* If less than or more than one user is selected, then hide all
			 menu items except "Add Ignore" and disable the "Add Ignore" item. */
			NSArray<IRCChannelUser *> *nicknames = [self selectedMembers:menuItem];

			NSString *hostmask = nicknames.firstObject.user.hostmask;

			if (nicknames.count != 1 || hostmask == nil) {
				modifyIgnoreMenuItem.hidden = YES;

				removeIgnoreMenuItem.hidden = YES;

				menuItem.hidden = NO;

				return NO;
			}

			/* Update visibility depending on whether ignore is available */
			/* When this logic was first introduced, we kept a reference to
			 the ignores in the represented object of the menu item.
			 This was stopped because information about the ignore can
			 change while the menu item is still open, making the object
			 we will reference when action is performed garbage. */
			NSArray *userIgnores = [u findIgnoresForHostmask:hostmask];

			BOOL condition = (userIgnores.count == 0);

			modifyIgnoreMenuItem.hidden = condition;

			removeIgnoreMenuItem.hidden = condition;

			menuItem.hidden = (condition == NO);

			return YES;
		}
		case MTUserControlsModifyIgnore: // "Modify Ignore"
		case MTUserControlsRemoveIgnore: // "Remove Ignore"
		{
			return YES;
		}
		case MTUserControlsInviteTo: // "Invite To…"
		{
			if (u.isLoggedIn == NO || c.isUtility) {
				return NO;
			}

			NSUInteger channelCount = 0;

			for (IRCChannel *e in u.channelList) {
				if (c != e && e.isChannel) {
					channelCount++;
				}
			}

			return (channelCount > 0);
		}
		case MTUserControlsGetInfo: // "Get Info (Whois)"
		case MTUserControlsClientToClientMenu: // "Client-to-Client"
		{
			return (u.isLoggedIn && c.isUtility == NO);
		}
		case MTUserControlsPrivateMessage: // "Private Message (Query)"
		{
			menuItem.hidden = (c.isChannel == NO);

			return (u.isLoggedIn && c.isUtility == NO);
		}
		case MTUserControlsGiveOp: // "Give Op (+o)"
		case MTUserControlsGiveHalfop: // "Give Halfop (+h)"
		case MTUserControlsGiveVoice: // "Give Voice (+v)"
		case MTUserControlsTakeOp: // "Take Op (-o)"
		case MTUserControlsTakeHalfop: // "Take Halfop (-h)"
		case MTUserControlsTakeVoice: // "Take Voice (-v)"
		{
			return (u.isLoggedIn && c.isActive);
		}
		case MTUserControlsAllModesGiven: // "All Modes Given"
		{
			return NO;
		}
		case MTUserControlsAllModesTaken: // "All Modes Taken"
		{
#define _setHidden(tag, value)		[menuItem.menu itemWithTag:(tag)].hidden = (value)

			if (c.isChannel == NO) {
				_setHidden(MTUserControlsGiveOp, YES);
				_setHidden(MTUserControlsGiveHalfop, YES);
				_setHidden(MTUserControlsGiveVoice, YES);
				_setHidden(MTUserControlsTakeOp, YES);
				_setHidden(MTUserControlsTakeHalfop, YES);
				_setHidden(MTUserControlsTakeVoice, YES);

				_setHidden(MTUserControlsAllModesGiven, YES);
				_setHidden(MTUserControlsAllModesGivenSeparator, YES);
				_setHidden(MTUserControlsAllModesTaken, YES);
				_setHidden(MTUserControlsAllModesTakenSeparator, YES);

				return NO;
			}

			_setHidden(MTUserControlsAllModesGivenSeparator, NO);
			_setHidden(MTUserControlsAllModesTakenSeparator, NO);

			NSArray *nicknames = [self selectedMembers:menuItem];

			if (nicknames.count == 1)
			{
				IRCChannelUser *user = nicknames[0];

				IRCUserRank userRanks = user.ranks;

				BOOL UserHasModeO = ((userRanks & IRCUserRankNormalOperator) == IRCUserRankNormalOperator);
				BOOL UserHasModeH = NO;
				BOOL UserHasModeV = ((userRanks & IRCUserRankVoiced) == IRCUserRankVoiced);

				_setHidden(MTUserControlsGiveOp, UserHasModeO);
				_setHidden(MTUserControlsGiveVoice, UserHasModeV);
				_setHidden(MTUserControlsTakeOp, (UserHasModeO == NO));
				_setHidden(MTUserControlsTakeVoice, (UserHasModeV == NO));

				BOOL halfOpModeSupported = [u.supportInfo modeSymbolIsUserPrefix:@"h"];

				if (halfOpModeSupported == NO) {
					_setHidden(MTUserControlsGiveHalfop, YES);
					_setHidden(MTUserControlsTakeHalfop, YES);
				} else {
					UserHasModeH = ((userRanks & IRCUserRankHalfOperator) == IRCUserRankHalfOperator);

					_setHidden(MTUserControlsGiveHalfop, UserHasModeH);
					_setHidden(MTUserControlsTakeHalfop, (UserHasModeH == NO));
				}

				BOOL hideGiveSepItem = ((UserHasModeO == NO || UserHasModeV == NO) || (UserHasModeH == NO && halfOpModeSupported));

				_setHidden(MTUserControlsAllModesGiven, hideGiveSepItem);

				BOOL hideTakenSepItem = (UserHasModeO || UserHasModeH || UserHasModeV);

				_setHidden(MTUserControlsAllModesTaken, hideTakenSepItem);
			}
			else
			{
				_setHidden(MTUserControlsGiveOp, NO);
				_setHidden(MTUserControlsGiveHalfop, NO);
				_setHidden(MTUserControlsGiveVoice, NO);
				_setHidden(MTUserControlsTakeOp, NO);
				_setHidden(MTUserControlsTakeHalfop, NO);
				_setHidden(MTUserControlsTakeVoice, NO);

				_setHidden(MTUserControlsAllModesGiven, YES);
				_setHidden(MTUserControlsAllModesTaken, YES);
			}

			return NO;

#undef _setHidden
		}
		case MTUserControlsBan: // "Ban"
		case MTUserControlsKick: // "Kick"
		case MTUserControlsBanAndKick: // "Ban and Kick"
		{
			BOOL isChannel = c.isChannel;

			menuItem.hidden = (isChannel == NO);

			[menuItem.menu itemWithTag:MTUserControlsBanAndKickSeparator].hidden = (isChannel == NO);

			return (u.isLoggedIn && isChannel && c.isActive);
		}
		case MTUserControlsIRCOperatorMenu: // "IRC Operator"
		{
			menuItem.hidden = (u.userIsIRCop == NO);

			return (u.isLoggedIn && c.isUtility == NO);
		}

		case MTWKGeneralSearchWithGoogle: // "Search With Google"
		{
			TVCLogView *webView = self.selectedViewControllerBackingView;

			if (webView == nil) {
				return NO;
			}

			NSString *searchProviderName = [self searchProviderName];

			menuItem.title = TXTLS(@"BasicLanguage[1ll-h9]", searchProviderName);

			return webView.hasSelection;
		}
		case MTWKGeneralLookUpInDictionary: // "Look Up in Dictionary"
		{
			TVCLogView *webView = self.selectedViewControllerBackingView;

			if (webView == nil) {
				return NO;
			}

			NSString *selection = webView.selection;

			NSUInteger selectionLength = selection.length;

			if (selectionLength == 0 || selectionLength > 40) {
				menuItem.title = TXTLS(@"BasicLanguage[o5l-4s]");

				return NO;
			}

			if (selectionLength > 25) {
				selection = [selection substringToIndex:24];

				selection = [NSString stringWithFormat:@"%@…", selection.trim];
			}

			menuItem.title = TXTLS(@"BasicLanguage[zxs-yy]", selection);

			return (selectionLength > 0);
		}
		case MTWKGeneralCopy: // "Copy" (WebView)
		{
			TVCLogView *webView = self.selectedViewControllerBackingView;

			if (webView == nil) {
				return NO;
			}

			return webView.hasSelection;
		}
		case MTWKGeneralQueryLogs: // "Query Logs" (WebKit)
		{
			menuItem.hidden = (c.isPrivateMessage == NO);

			return [TPCPreferences logToDiskIsEnabled];
		}
		case MTWKGeneralChannelMenu: // "Channel" (WebKit)
		{
			menuItem.hidden = (c.isChannel == NO);

			/* "Query Logs" will appear above this menu item,
			 but if this is neither channel or query, then we
			 have to hide the separator above that so it's not
			 just sitting there with nothing beneath it. */
			NSMenuItem *queryLogs = [menuItem.menu itemWithTag:MTWKGeneralQueryLogs];

			[menuItem.menu itemWithTag:MTWKGeneralPasteSeparator].hidden = (menuItem.hidden && queryLogs.hidden);

			return YES;
		}

		case MTMMHelpAdvancedMenuEnableDeveloperMode: // Developer Mode
		{
			if ([TPCPreferences developerModeEnabled]) {
				menuItem.state = NSControlStateValueOn;
			} else {
				menuItem.state = NSControlStateValueOff;
			}

			return YES;
		}

		case MTMainWindowSegmentedControllerAddChannel: // "Add Channel…"
		{
			return (u != nil);
		}

		default:
		{
			break;
		}
	}

	return YES;
}

- (void)menuWillOpen:(NSMenu *)menu
{
	self.menuIsOpen = YES;

	self.pointedClient = mainWindow().selectedClient;
	self.pointedChannel = mainWindow().selectedChannel;

	self.menuPerformedActionLastOpen = NO;
}

- (void)menuDidClose:(NSMenu *)menu
{
	self.menuIsOpen = NO;

	/* This delegate callback is received before -menuItemPerformedAction:
	 is called. So that our selected items can be reset if the user did 
	 not perform an action, we call -menuClosedTimer the next time the 
	 main queue comes around. The action is performed on the current pass
	 which means this prevents a race. */
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self _menuClosedTimer];
	});
}

- (void)_menuClosedTimer
{
	if (self.menuPerformedActionLastOpen) {
		return;
	}

	[self resetSelectedItems];
}

- (void)menuItemWillPerformedAction:(NSNotification *)aNote
{
	NSMenuItem *menuItem = aNote.userInfo[@"MenuItem"];

	if (menuItem.target != self) {
		return;
	}

	self.menuPerformedActionLastOpen = YES;
}

- (void)menuItemPerformedAction:(NSNotification *)aNote
{
	NSMenuItem *menuItem = aNote.userInfo[@"MenuItem"];

	if (menuItem.target != self) {
		return;
	}

	[self resetSelectedItems];
}

#pragma mark -
#pragma mark Selection

- (void)resetSelectedItems
{
	self.pointedClient = nil;
	self.pointedChannel = nil;
}

- (nullable IRCClient *)selectedClient
{
	IRCClient *pointedClient = self.pointedClient;

	if (pointedClient) {
		return pointedClient;
	}

	return mainWindow().selectedClient;
}

- (nullable IRCChannel *)selectedChannel
{
	IRCChannel *pointedChannel = self.pointedChannel;

	if (pointedChannel) {
		return pointedChannel;
	}

	return mainWindow().selectedChannel;
}

- (nullable TVCLogController *)selectedViewController
{
	IRCChannel *selectedChannel = self.selectedChannel;

	if (selectedChannel) {
		return selectedChannel.viewController;
	}

	return self.selectedClient.viewController;
}

- (nullable TVCLogView *)selectedViewControllerBackingView
{
	TVCLogController *viewController = self.selectedViewController;

	return viewController.backingView;
}

#pragma mark -
#pragma mark File Transfers

- (TDCFileTransferDialog *)fileTransferController
{
	return [TXSharedApplication sharedFileTransferDialog];
}

#pragma mark -
#pragma mark Other Actions

- (void)emptyAction:(id)sender
{
	/* Empty action used to validate submenus */
}

@end

NS_ASSUME_NONNULL_END
