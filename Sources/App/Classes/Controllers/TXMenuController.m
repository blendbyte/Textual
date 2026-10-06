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
#import "TLOEncryptionManagerPrivate.h"
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
#import "TXMenuControllerPrivate.h"

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
#import <Sparkle/Sparkle.h>
#endif

NS_ASSUME_NONNULL_BEGIN

#define	_popWindowViewIfExists(c)	if ([windowController() maybeBringWindowForward:(c)]) {		\
										return;													\
									}

@interface TXMenuController () <NSMenuItemValidation>
@property (nonatomic, assign) BOOL menuIsOpen;
@property (nonatomic, assign) BOOL menuPerformedActionLastOpen;
@property (nonatomic, weak) IRCClient *pointedClient;
@property (nonatomic, weak) IRCChannel *pointedChannel;
@property (nonatomic, copy) NSString *currentSearchPhrase;
@property (readonly, nullable) TVCLogController *selectedViewController;
@property (readonly, nullable) TVCLogView *selectedViewControllerBackingView;
@property (readonly) TDCFileTransferDialog *fileTransferController;
@property (nonatomic, strong, readwrite) IBOutlet NSMenu *channelViewChannelNameMenu;
@property (nonatomic, strong, readwrite) IBOutlet NSMenu *channelViewGeneralMenu;
@property (nonatomic, strong, readwrite) IBOutlet NSMenu *channelViewURLMenu;
@property (nonatomic, strong, readwrite) IBOutlet NSMenu *dockMenu;

#if TEXTUAL_BUILT_WITH_ADVANCED_ENCRYPTION == 1
@property (nonatomic, strong, readwrite) IBOutlet NSMenu *encryptionManagerStatusMenu;
#endif

@property (nonatomic, weak, readwrite) IBOutlet NSMenu *mainMenuNavigationChannelListMenu;
@property (nonatomic, weak, readwrite) IBOutlet NSMenu *mainMenuChannelMenu;
@property (nonatomic, weak, readwrite) IBOutlet NSMenu *mainMenuQueryMenu;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *mainMenuChannelMenuItem;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *mainMenuQueryMenuItem;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *mainMenuServerMenuItem;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *mainMenuWindowMenuItem;
@property (nonatomic, strong, readwrite) IBOutlet NSMenu *mainWindowSegmentedControllerCellMenu;
@property (nonatomic, strong, readwrite) IBOutlet NSMenu *serverListNoSelectionMenu;
@property (nonatomic, strong, readwrite) IBOutlet NSMenu *userControlMenu;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *muteNotificationsDockMenuItem;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *muteNotificationsFileMenuItem;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *muteNotificationsSoundsDockMenuItem;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *muteNotificationsSoundsFileMenuItem;
@end

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

		/* Disable everything by default except "Manage license…" */
		validationResult = (tag == MTMMAppManageLicense);
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

#if TEXTUAL_BUILT_WITH_ADVANCED_ENCRYPTION == 1
		case MTOTRStatusButtonStartPrivateConversation:
		case MTOTRStatusButtonRefreshPrivateConversation:
		case MTOTRStatusButtonEndPrivateConversation:
		case MTOTRStatusButtonAuthenticateChatPartner:
		case MTOTRStatusButtonViewListOfFingerprints:
		{
			/* Even if we are not logged in, we still ask the encryption manager
			 to validate the menu item first so that it can hide specific menu items.
			 After it has done that, then we can disable if not logged in. */
			if ([TPCPreferences textEncryptionIsEnabled] == NO) {
				return NO;
			}

			if (u.isLoggedIn == NO) {
				return NO;
			}

			BOOL valid = [sharedEncryptionManager()
						  validateMenuItem:menuItem
						  withStateOf:[u encryptionAccountNameForUser:c.name]
						  from:[u encryptionAccountNameForLocalUser]];

			return valid;
		}
#endif

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
#pragma mark Selected User(s)

- (BOOL)checkSelectedMembers:(id)sender
{
	return ([self selectedMembers:sender].count > 0);
}

- (NSArray<IRCChannelUser *> *)selectedMembers:(id)sender
{
	return [self selectedMembers:sender returnStrings:NO];
}

- (NSArray<NSString *> *)selectedMembersNicknames:(id)sender
{
	return [self selectedMembers:sender returnStrings:YES];
}

- (NSArray *)selectedMembers:(id)sender returnStrings:(BOOL)returnStrings
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isActive == NO) {
		return @[];
	}

	/* Return a specific nickname for WebView events */
	NSString *pointedNickname = nil;

	if ([sender isKindOfClass:[NSMenuItem class]]) {
		pointedNickname = ((NSMenuItem *)sender).userInfo;
	} else {
		pointedNickname = self.pointedNickname;
	}

	if (pointedNickname) {
		if (returnStrings) {
			return @[pointedNickname];
		}

		IRCChannelUser *user = [c findMember:pointedNickname];

		if (user) {
			return @[user];
		}

		return @[];
	}

	/* If we did not have a specific nickname, then query
	 the user list for selected rows. */
	NSMutableArray *userArray = [NSMutableArray array];

	NSIndexSet *selectedRows = mainWindowMemberList().selectedRowIndexes;

	[selectedRows enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		IRCChannelUser *user = [mainWindowMemberList() itemAtRow:index];

		if (returnStrings) {
			[userArray addObject:user.user.nickname];
		} else {
			[userArray addObject:user];
		}
	}];

	return [userArray copy];
}

- (void)deselectMembers:(id)sender
{
	if ([sender isKindOfClass:[NSMenuItem class]]) {
		if (((NSMenuItem *)sender).userInfo.length > 0) {
			return; // Nothing to deselect when our sender used userInfo
		}
	}

	if (self.pointedNickname) {
		self.pointedNickname = nil;

		return;
	}

	[mainWindowMemberList() deselectAll:sender];
}

#pragma mark -
#pragma mark Find Panel

- (void)_showFindPromptOpenDialog:(id)sender
{
	void (^promptCompletionBlock)(NSString *) = ^(NSString *resultString)
	{
		if ([self.currentSearchPhrase isEqualToString:resultString]) {
			return;
		}

		self.currentSearchPhrase = resultString;

		TVCLogView *webView = self.selectedViewControllerBackingView;

		[webView findString:resultString movingForward:YES];
	};

	NSString *resultString = nil;

	TVCAlertResponseButton response =
	[TDCInputPrompt promptWithMessage:TXTLS(@"Prompts[d2w-4o]")
								title:TXTLS(@"Prompts[akr-eh]")
						defaultButton:TXTLS(@"Prompts[q5h-xx]")
					  alternateButton:TXTLS(@"Prompts[qso-2g]")
						prefillString:self.currentSearchPhrase
						 resultString:&resultString];

	if (response == TVCAlertResponseButtonFirst) {
		promptCompletionBlock(resultString);
	}
}

- (void)showFindPrompt:(id)sender
{
	NSParameterAssert(sender != nil);

	if (mainWindow().keyWindow == NO) {
		return;
	}

	if ([sender tag] == MTMMEditFindMenuFind || self.currentSearchPhrase.length == 0) {
		[self _showFindPromptOpenDialog:sender];

		return;
	}

	TVCLogView *webView = self.selectedViewControllerBackingView;

	if ([sender tag] == MTMMEditFindMenuFindNext) {
		[webView findString:self.currentSearchPhrase movingForward:YES];
	} else {
		[webView findString:self.currentSearchPhrase movingForward:NO];
	}
}


#pragma mark -
#pragma mark Edit

- (void)copy:(id)sender
{
	id firstResponder = [NSApp keyWindow].firstResponder;

	if ([firstResponder respondsToSelector:@selector(copy:)]) {
		[firstResponder performSelector:@selector(copy:) withObject:sender];
	}
}

- (void)paste:(id)sender
{
	if (mainWindow().keyWindow) {
		[mainWindowTextField() focus];

		[mainWindowTextField() paste:sender];

		return;
	}

	id firstResponder = [NSApp keyWindow].firstResponder;

	if ([firstResponder respondsToSelector:@selector(paste:)]) {
		[firstResponder performSelector:@selector(paste:) withObject:sender];
	}
}

- (void)print:(id)sender
{
	if (mainWindow().keyWindow) {
		TVCLogView *webView = self.selectedViewControllerBackingView;

		if (webView == nil) {
			return;
		}

		[webView print];

		return;
	}

	id firstResponder = [NSApp keyWindow].firstResponder;

	if ([firstResponder respondsToSelector:@selector(print:)]) {
		[firstResponder performSelector:@selector(print:) withObject:sender];
	}
}

#pragma mark -
#pragma mark Backing View

- (void)copyLogAsHtml:(id)sender
{
	TVCLogView *webView = self.selectedViewControllerBackingView;

	if (webView == nil) {
		return;
	}

	[webView copyContentString];
}

- (void)openWebInspector:(id)sender
{
	/*
	 When WebKit2 first announced, there was no way for an
	 app to take an NSMenu, modify it, and return the result
	 when a context menu is presented.

	 WebKit1 had a delegate method for that named:
	 -webView:contextMenuItemsForElement:defaultMenuItems:

	 WebKit2 added this delegate method, in private, but it
	 was not available until the next update of macOS.

	 'Til then, we had to fake "Inspect Element" because we
	 did not have access to the default implementation that
	 is available through the delegate method.

	 Apple now flags the function names that were used to do that.

	 This will break "Inspect Element" on one version of macOS.
	 Which one I don't even recall.
	 But it is worth it to make the review process smoother.

	 Sorry.
*/

	(void)
	[TDCAlert alertWithMessage:TXTLS(@"Prompts[kig-m1]")
						 title:TXTLS(@"Prompts[ujw-64]")
				 defaultButton:TXTLS(@"Prompts[c7s-dq]")
			   alternateButton:nil];
}

- (void)markScrollback:(id)sender
{
	TVCLogController *viewController = self.selectedViewController;

	if (viewController == nil) {
		return;
	}

	[viewController mark];
}

- (void)gotoScrollbackMarker:(id)sender
{
	TVCLogController *viewController = self.selectedViewController;

	if (viewController == nil) {
		return;
	}

	[viewController goToMark];
}

- (void)clearScrollback:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil) {
		return;
	}

	if (c) {
		[mainWindow() clearContentsOfChannel:c];
	} else {
		[mainWindow() clearContentsOfClient:u];
	}
}

- (void)increaseLogFontSize:(id)sender
{
	[mainWindow() changeTextSize:YES];
}

- (void)decreaseLogFontSize:(id)sender
{
	[mainWindow() changeTextSize:NO];
}

- (NSString *)searchProviderName
{
	NSDictionary *preferredWebServices =
	[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"NSPreferredWebServices"];

	NSDictionary *defaultSearchProvider = [preferredWebServices dictionaryForKey:@"NSWebServicesProviderWebSearch"];

	NSString *searchProviderName = [defaultSearchProvider stringForKey:@"NSDefaultDisplayName"];

	if (searchProviderName == nil) {
		return @"Google";
	}

	return searchProviderName;
}

- (void)searchGoogle:(id)sender
{
	TVCLogView *webView = self.selectedViewControllerBackingView;

	if (webView == nil) {
		return;
	}

	NSString *selection = webView.selection;

	if (selection.length == 0) {
		return;
	}

	NSPasteboard *searchPasteboard = [NSPasteboard pasteboardWithUniqueName];

	searchPasteboard.stringContent = selection;

	NSPerformService(@"Search With %WebSearchProvider@", searchPasteboard);
}

- (void)lookUpInDictionary:(id)sender
{
	TVCLogView *webView = self.selectedViewControllerBackingView;

	if (webView == nil) {
		return;
	}

	NSString *selection = webView.selection;

	if (selection.length == 0) {
		return;
	}

	NSString *urlString = [NSString stringWithFormat:@"dict://%@", selection.percentEncodedString];

	[TLOpenLink openWithString:urlString];
}

#pragma mark -
#pragma mark Server

- (void)connect:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil || u.isConnecting || u.isConnected || u.isQuitting) {
		return;
	}

	[u connect];

	[mainWindow() expandClient:u];
}

- (void)connectBypassingProxy:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil || u.isConnecting || u.isConnected || u.isQuitting) {
		return;
	}

	[u connect:IRCClientConnectModeNormal bypassProxy:YES];

	[mainWindow() expandClient:u];
}

- (void)disconnect:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil || (u.isConnecting == NO && u.isConnected == NO) || u.isQuitting) {
		return;
	}

	[u quit];
}

- (void)cancelReconnection:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	[u cancelReconnect];
}

- (void)showServerChannelList:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil || u.isLoggedIn == NO) {
		return;
	}

	[u createChannelListDialog];

	[u requestChannelList];
}

- (void)addServer:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	TDCServerPropertiesSheet *sheet =
	[[TDCServerPropertiesSheet alloc] initWithClient:nil];

	sheet.delegate = self;

	sheet.window = mainWindow();

	[sheet startWithSelection:TDCServerPropertiesSheetSelectionDefault context:nil];

	[windowController() addWindowToWindowList:sheet];
}

- (void)duplicateServer:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	IRCClientConfigMutable *config = [u.config uniqueCopyMutable];

	config.connectionName = [config.connectionName stringByAppendingString:@"_"];

	IRCClient *newClient = [worldController() createClientWithConfig:config reload:YES];

	if (newClient.config.sidebarItemExpanded) { // Only expand new client if old was expanded already.
		[mainWindow() expandClient:newClient];
	}

	[worldController() save];
}

- (void)deleteServer:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil || u.isConnecting || u.isConnected) {
		return;
	}

	BOOL result = [TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[etl-ss]")
											title:TXTLS(@"Prompts[0kz-wd]")
									defaultButton:TXTLS(@"Prompts[mvh-ms]")
								  alternateButton:TXTLS(@"Prompts[99q-gg]")];

	if (result == NO) {
		return;
	}

	[worldController() destroyClient:u];

	[worldController() save];
}

#pragma mark -
#pragma mark Channel

- (void)joinChannel:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO || c.isActive) {
		return;
	}

	[u joinChannel:c];

	[mainWindow() select:c];
}

- (void)leaveChannel:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	/* Second boxed in condition is because this is used for queries too */
	if (u == nil || c == nil || (c.isChannel && (u.isLoggedIn == NO || c.isActive == NO))) {
		return;
	}

	if (c.isChannel) {
		[u partChannel:c];

		return;
	}

	[worldController() destroyChannel:c];
}

- (void)addChannel:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	TDCChannelPropertiesSheet *sheet =
	[[TDCChannelPropertiesSheet alloc] initWithClient:u];

	sheet.delegate = self;

	sheet.window = mainWindow();

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)deleteChannel:(id)sender
{
	IRCChannel *c = self.selectedChannel;

	if (c == nil) {
		return;
	}

	if (c.isChannel) {
		BOOL result = [TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[516-ms]")
												title:TXTLS(@"Prompts[i8o-7z]")
										defaultButton:TXTLS(@"Prompts[mvh-ms]")
									  alternateButton:TXTLS(@"Prompts[99q-gg]")
									   suppressionKey:@"delete_channel"
									  suppressionText:nil];

		if (result == NO) {
			return;
		}
	}

	[worldController() destroyChannel:c];

	[worldController() save];
}

- (void)copyUniqueIdentifier:(id)sender
{
	IRCChannel *c = self.selectedChannel;

	if (c == nil) {
		return;
	}

	[RZPasteboard() setStringContent:c.uniqueIdentifier];
}

#pragma mark -
#pragma mark Other Actions

- (void)copyUrl:(id)sender
{
	NSString *pointedUrl = ((NSMenuItem *)sender).userInfo;

	if (pointedUrl.length == 0) {
		return;
	}

	RZPasteboard().stringContent = pointedUrl;
}

- (void)joinChannelClicked:(id)sender
{
	NSParameterAssert(sender != nil);

	IRCClient *u = self.selectedClient;

	if (u == nil || u.isLoggedIn == NO) {
		return;
	}

	NSString *pointedChannelName = nil;

	if ([sender isKindOfClass:[NSMenuItem class]]) {
		pointedChannelName = ((NSMenuItem *)sender).userInfo;
	} else if ([sender isKindOfClass:[NSString class]]) {
		pointedChannelName = sender;
	} else {
		return;
	}

	if ([u stringIsChannelName:pointedChannelName] == NO) {
		return;
	}

	IRCChannel *c = [u findChannelOrCreate:pointedChannelName];

	[u joinChannel:c];

	[mainWindow() select:c];
}

- (void)emptyAction:(id)sender
{
	/* Empty action used to validate submenus */
}

#pragma mark -
#pragma mark Ignores

- (void)memberAddIgnore:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	NSString *command = [NSString stringWithFormat:@"ignore %@", nicknames[0]];

	[u sendCommand:command completeTarget:YES target:c.name];
}

- (void)memberRemoveIgnore:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	NSString *command = [NSString stringWithFormat:@"unignore %@", nicknames[0]];

	[u sendCommand:command completeTarget:YES target:c.name];
}

- (void)memberModifyIgnore:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	NSArray<IRCChannelUser *> *nicknames = [self selectedMembers:sender];

	[self deselectMembers:sender];

	/* User's hostmask and other information can change between the point
	 the menu item is opened and the point the action is performed.
	 We therefore perform a new query for ignores when performing action. */
	NSString *hostmask = nicknames.firstObject.user.hostmask;

	if (nicknames.count != 1 || hostmask == nil) {
		return;
	}

	NSArray *userIgnores = [u findIgnoresForHostmask:hostmask];

	/* If we have more than one user ignore, then open
	 the address book instead of a specific ignore. */
	if (userIgnores.count == 1) {
		[self showServerPropertiesSheetForClient:u
								   withSelection:TDCServerPropertiesSheetSelectionNewIgnoreEntry
										 context:userIgnores[0]];
	} else {
		[self showServerPropertiesSheetForClient:u
								   withSelection:TDCServerPropertiesSheetSelectionAddressBook
										 context:nil];
	}
}

#pragma mark -
#pragma mark Members

- (void)memberInMemberListDoubleClicked:(id)sender
{
	NSInteger rowBeneathMouse = mainWindowMemberList().rowBeneathMouse;

	if (rowBeneathMouse < 0) {
		return;
	}

	TXUserDoubleClickAction action = [TPCPreferences userDoubleClickOption];

	if (action == TXUserDoubleClickActionWhois) {
		[self whoisSelectedMembers:sender];
	} else if (action == TXUserDoubleClickActionPrivateMessage) {
		[self memberStartPrivateMessage:sender];
	} else if (action == TXUserDoubleClickActionInsertTextField) {
		[self memberInsertNameIntoTextField:sender];
	}
}

- (void)memberInChannelViewDoubleClicked:(id)sender
{
	TXUserDoubleClickAction action = [TPCPreferences userDoubleClickOption];

	if (action == TXUserDoubleClickActionWhois) {
		[self whoisSelectedMembers:sender];
	} else if (action == TXUserDoubleClickActionPrivateMessage) {
		[self memberStartPrivateMessage:sender];
	} else if (action == TXUserDoubleClickActionInsertTextField) {
		[self memberInsertNameIntoTextField:sender];
	}
}

- (void)memberInsertNameIntoTextField:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	TVCMainWindowTextView *textView = mainWindowTextField();

	NSRange selectedRange = textView.selectedRange;

	NSMutableString *stringToInsert = [NSMutableString string];

	if (selectedRange.location > 0) {
		UniChar previousCharacter = [textView.stringValue characterAtIndex:(selectedRange.location - 1)];

		if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:previousCharacter] == NO) {
			[stringToInsert appendString:@" "];
		}
	}

	NSString *nicknamesString = [nicknames componentsJoinedByString:@", "];

	[stringToInsert appendString:nicknamesString];

	NSString *completionSuffix = [TPCPreferences tabCompletionSuffix];

	if (completionSuffix != nil) {
		[stringToInsert appendString:completionSuffix];
	}

	[textView replaceCharactersInRange:selectedRange withString:stringToInsert];

	[textView resetFontColorInRange:selectedRange];

	[textView focus];
}

- (void)memberSendWhois:(id)sender
{
	[self whoisSelectedMembers:sender];
}

- (void)whoisSelectedMembers:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendWhois:nickname];
	}

	[self deselectMembers:sender];
}

- (void)memberStartPrivateMessage:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		IRCChannel *query = [u findChannelOrCreate:nickname isPrivateMessage:YES];

		[mainWindow() select:query];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPPing:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPPing:nickname];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPFinger:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPQuery:nickname command:@"FINGER" text:nil];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPTime:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPQuery:nickname command:@"TIME" text:nil];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPVersion:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPQuery:nickname command:@"VERSION" text:nil];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPUserinfo:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPQuery:nickname command:@"USERINFO" text:nil];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPClientInfo:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPQuery:nickname command:@"CLIENTINFO" text:nil];
	}

	[self deselectMembers:sender];
}

- (void)_processModeChange:(id)sender usingCommand:(NSString *)modeCommand
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	[self deselectMembers:sender];

	NSString *nicknamesString = [nicknames componentsJoinedByString:@" "];

	NSString *command = [NSString stringWithFormat:@"%@ %@", modeCommand, nicknamesString];

	[u sendCommand:command completeTarget:YES target:c.name];
}

- (void)memberModeGiveOp:(id)sender
{
	[self _processModeChange:sender usingCommand:@"OP"];
}

- (void)memberModeTakeOp:(id)sender
{ 
	[self _processModeChange:sender usingCommand:@"DEOP"];
}

- (void)memberModeGiveHalfop:(id)sender
{ 
	[self _processModeChange:sender usingCommand:@"HALFOP"];
}

- (void)memberModeTakeHalfop:(id)sender
{ 
	[self _processModeChange:sender usingCommand:@"DEHALFOP"];
}

- (void)memberModeGiveVoice:(id)sender
{ 
	[self _processModeChange:sender usingCommand:@"VOICE"];
}

- (void)memberModeTakeVoice:(id)sender
{ 
	[self _processModeChange:sender usingCommand:@"DEVOICE"];
}

- (void)memberKickFromChannel:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u kick:nickname inChannel:c];
	}

	[self deselectMembers:sender];
}

- (void)memberBanFromChannel:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		NSString *command = [NSString stringWithFormat:@"BAN %@", nickname];

		[u sendCommand:command completeTarget:YES target:c.name];
	}

	[self deselectMembers:sender];
}

- (void)memberKickbanFromChannel:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		NSString *command = [NSString stringWithFormat:@"KICKBAN %@ %@", nickname, [TPCPreferences defaultKickMessage]];

		[u sendCommand:command completeTarget:YES target:c.name];
	}

	[self deselectMembers:sender];
}

- (void)memberKillFromServer:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		NSString *command = [NSString stringWithFormat:@"KILL %@ %@", nickname, [TPCPreferences IRCopDefaultKillMessage]];

		[u sendCommand:command];
	}

	[self deselectMembers:sender];
}

- (void)memberBanFromServer:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		if ([u nicknameIsMyself:nickname]) {
			[u printDebugInformation:TXTLS(@"IRC[0r1-5l]", u.serverAddress) inChannel:c];

			continue;
		}

		NSString *command = [NSString stringWithFormat:@"GLINE %@ %@", nickname, [TPCPreferences IRCopDefaultGlineMessage]];

		[u sendCommand:command];
	}

	[self deselectMembers:sender];
}

- (void)memberShunOnServer:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		NSString *command = [NSString stringWithFormat:@"SHUN %@ %@", nickname, [TPCPreferences IRCopDefaultShunMessage]];

		[u sendCommand:command];
	}

	[self deselectMembers:sender];
}

- (void)_showSetVhostPromptOpenDialog:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	void (^promptCompletionBlock)(NSString *) = ^(NSString *resultString)
	{
		NSString *vhost = resultString.trimAndGetFirstToken;

		if (vhost.length == 0) {
			return;
		}

		for (NSString *nickname in nicknames) {
			NSString *command = [NSString stringWithFormat:@"hs setall %@ %@", nickname, vhost];

			[u sendCommand:command completeTarget:NO target:nil];
		}
	};

	NSString *vhost = nil;

	TVCAlertResponseButton response =
	[TDCInputPrompt promptWithMessage:TXTLS(@"Prompts[2mx-jf]")
								title:TXTLS(@"Prompts[7gr-e4]")
						defaultButton:TXTLS(@"Prompts[c7s-dq]")
					  alternateButton:TXTLS(@"Prompts[qso-2g]")
						prefillString:nil
						 resultString:&vhost];

	if (response == TVCAlertResponseButtonFirst) {
		promptCompletionBlock(vhost);
	}
}

- (void)showSetVhostPrompt:(id)sender
{
	[self _showSetVhostPromptOpenDialog:sender];
}

#pragma mark -
#pragma mark File Transfers

- (TDCFileTransferDialog *)fileTransferController
{
	return [TXSharedApplication sharedFileTransferDialog];
}

- (void)showFileTransfersWindow:(id)sender
{
	[self.fileTransferController show:YES restorePosition:YES];
}

- (void)memberSendFileRequest:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	NSOpenPanel *openPanel = [NSOpenPanel openPanel];

	openPanel.allowsMultipleSelection = YES;
	openPanel.canChooseDirectories = NO;
	openPanel.canChooseFiles = YES;
	openPanel.canCreateDirectories = NO;
	openPanel.resolvesAliases = YES;

	[openPanel beginSheetModalForWindow:mainWindow() completionHandler:^(NSInteger returnCode) {
		if (returnCode != NSModalResponseOK) {
			return;
		}

		[self.fileTransferController.fileTransferTable beginUpdates];

		for (NSString *nickname in nicknames) {
			for (NSURL *path in openPanel.URLs) {
				[self.fileTransferController addSenderForClient:u nickname:nickname path:path.path autoOpen:YES];
			}
		}

		[self.fileTransferController.fileTransferTable endUpdates];
	}];
}

- (void)memberSendDroppedFilesToSelectedChannel:(NSArray<NSString *> *)files
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isPrivateMessage == NO) {
		return;
	}

	[self memberSendDroppedFiles:files to:c.name];
}

- (void)memberSendDroppedFiles:(NSArray<NSString *> *)files row:(NSUInteger)row
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isPrivateMessage == NO) {
		return;
	}

	IRCChannelUser *member = [mainWindowMemberList() itemAtRow:row];

	[self memberSendDroppedFiles:files to:member.user.nickname];
}

- (void)memberSendDroppedFiles:(NSArray<NSString *> *)files to:(NSString *)nickname
{
	NSParameterAssert(files != nil);
	NSParameterAssert(nickname != nil);

	IRCClient *u = self.selectedClient;

	if (u == nil || u.isLoggedIn == NO) {
		return;
	}

	[self.fileTransferController.fileTransferTable beginUpdates];

	for (NSString *file in files) {
		BOOL isDirectory = NO;

		if ([RZFileManager() fileExistsAtPath:file isDirectory:&isDirectory] == NO) {
			continue;
		} else if (isDirectory) {
			continue;
		}

		[self.fileTransferController addSenderForClient:u nickname:nickname path:file autoOpen:YES];
	}

	[self.fileTransferController.fileTransferTable endUpdates];
}

#pragma mark -
#pragma mark Logging

- (void)openLogLocation:(id)sender
{	
	NSURL *path = [TPCPathInfo transcriptFolderURL];

	if (path == nil) {
		return;
	}

	if ([RZFileManager() fileExistsAtURL:path]) {
		[RZWorkspace() openURL:path];

		return;
	}

	[TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[f05-hu]")
							  title:TXTLS(@"Prompts[k55-19]")
					  defaultButton:TXTLS(@"Prompts[c7s-dq]")
					alternateButton:nil];
}

- (void)openChannelLogs:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	NSURL *path = c.logFilePath;

	if (path == nil) {
		return;
	}

	if ([RZFileManager() fileExistsAtURL:path]) {
		[RZWorkspace() openURL:path];

		return;
	}

	[TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[f05-hu]")
							  title:TXTLS(@"Prompts[k55-19]")
					  defaultButton:TXTLS(@"Prompts[c7s-dq]")
					alternateButton:nil];
}

#pragma mark -
#pragma mark Help

- (void)openAcknowledgements:(id)sender
{
	NSURL *Acknowledgements = [RZMainBundle() URLForResource:@"Acknowledgements" withExtension:@"pdf" subdirectory:@"Documentation"];

	[RZWorkspace() openURL:Acknowledgements];
}

- (void)openHelpMenuItem:(id)sender
{
	NSParameterAssert(sender != nil);

	NSDictionary *_helpMenuLinks = @{
	   @(MTMMHelpLicenseAgreement) 					: @"https://help.codeux.com/textual/End-User-License-Agreement.kb",
	   @(MTMMHelpPrivacyPolicy) 					: @"https://help.codeux.com/textual/Privacy-Policy.kb",
	   @(MTMMHelpFrequentlyAskedQuestions) 			: @"https://help.codeux.com/textual/Frequently-Asked-Questions.kb",
	   @(MTMMHelpKBMenuKnowledgeBaseHome) 			: @"https://help.codeux.com/textual/home.kb",
	   @(MTMMHelpKBMenuChatEncryption) 				: @"https://help.codeux.com/textual/Off-the-Record-Messaging.kb",
	   @(MTMMHelpKBMenuCommandReference) 			: @"https://help.codeux.com/textual/Command-Reference.kb",
	   @(MTMMHelpKBMenuFeatureRequests) 			: @"https://help.codeux.com/textual/Support.kb",
	   @(MTMMHelpKBMenuKeyboardShortcuts) 			: @"https://help.codeux.com/textual/Keyboard-Shortcuts.kb",
	   @(MTMMHelpKBMenuMemoryManagement) 			: @"https://help.codeux.com/textual/Memory-Management.kb",
	   @(MTMMHelpKBMenuNetworkTimeouts)				: @"https://help.codeux.com/textual/Network-Timeouts.kb",
	   @(MTMMHelpKBMenuTextFormatting) 				: @"https://help.codeux.com/textual/Text-Formatting.kb",
	   @(MTMMHelpKBMenuStylingInformation) 			: @"https://help.codeux.com/textual/Styles.kb",
	   @(MTMMHelpKBMenuConnectingWithCertificate) 	: @"https://help.codeux.com/textual/Using-CertFP.kb",
	   @(MTMMHelpKBMenuConnectingToBouncer)			: @"https://help.codeux.com/textual/Connecting-to-ZNC-Bouncer.kb",
	   @(MTMMHelpKBMenuDCCFileTransferInformation) 	: @"https://help.codeux.com/textual/DCC-File-Transfer-Information.kb"
	};

	NSString *link = _helpMenuLinks[@([sender tag])];

	[TLOpenLink openWithString:link inBackground:NO];
}

- (void)openStandaloneStoreWebpage:(id)sender
{
	[TLOpenLink openWithString:@"https://www.textualapp.com/standalone-store" inBackground:NO];
}

- (void)contactSupport:(id)sender
{
	[TLOpenLink openWithString:@"https://contact.codeux.com/" inBackground:NO];
}

- (void)connectToTextualHelpChannel:(id)sender
{
	[IRCExtras createConnectionToServer:@"irc.libera.chat +6697" channelList:@"#textual" connectWhenCreated:YES mergeConnectionIfPossible:YES selectFirstChannelAdded:YES];
}

- (void)connectToTextualTestingChannel:(id)sender
{
	[IRCExtras createConnectionToServer:@"irc.libera.chat +6697" channelList:@"#textual-testing" connectWhenCreated:YES mergeConnectionIfPossible:YES selectFirstChannelAdded:YES];
}

#pragma mark -
#pragma mark IRC

- (void)showChannelBanList:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	[u createChannelBanListSheet];

	[u sendModes:@"+b" withParameters:nil inChannel:c];
}

- (void)showChannelBanExceptionList:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	[u createChannelBanExceptionListSheet];

	[u sendModes:@"+e" withParameters:nil inChannel:c];
}

- (void)showChannelInviteExceptionList:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	[u createChannelInviteExceptionListSheet];

	[u sendModes:@"+I" withParameters:nil inChannel:c];
}

- (void)showChannelQuietList:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	[u createChannelQuietListSheet];

	[u sendModes:@"+q" withParameters:nil inChannel:c];
}

- (void)toggleChannelModerationMode:(id)sender
{
	NSParameterAssert(sender != nil);

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	NSString *modeSymbol = nil;

	if ([sender tag] == MTMMChannelModesMenuRemoveModerated) {
		modeSymbol = @"-m";
	} else {
		modeSymbol = @"+m";
	}

	[u sendModes:modeSymbol withParameters:nil inChannel:c];
}

- (void)toggleChannelInviteMode:(id)sender
{
	NSParameterAssert(sender != nil);

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	NSString *modeSymbol = nil;

	if ([sender tag] == MTMMChannelModesMenuRemoveInviteOnly) {
		modeSymbol = @"-i";
	} else {
		modeSymbol = @"+i";
	}

	[u sendModes:modeSymbol withParameters:nil inChannel:c];
}

#pragma mark -
#pragma mark Window

- (void)closeWindow:(id)sender
{
	TXCommandWKeyAction keyAction = [TPCPreferences commandWKeyAction];

	if (keyAction == TXCommandWKeyActionCloseWindow || mainWindow().keyWindow == NO) {
		NSWindow *windowToClose = [NSApp keyWindow];

		if (windowToClose == nil) {
			windowToClose = [NSApp mainWindow];
		}

		if (windowToClose) {
			[windowToClose performClose:sender];
		}

		return;
	}

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil) {
		return;
	}

	switch (keyAction) {
		case TXCommandWKeyActionPartChannel:
		{
			if (c == nil) {
				return;
			}

			if (c.isChannel) {
				if (c.isActive == NO) {
					return;
				}

				[u partChannel:c];
			} else {
				[worldController() destroyChannel:c];
			}

			break;
		}
		case TXCommandWKeyActionDisconnect:
		{
			if (u.isConnecting == NO && u.isConnected == NO) {
				return;
			}

			[u quit];

			break;
		}
		case TXCommandWKeyActionTerminate:
		{
			[NSApp terminate:sender];

			break;
		}
		default:
		{
			break;
		}
	}
}

- (void)showMainWindow:(id)sender
{
	[mainWindow() makeKeyAndOrderFront:sender];
}

- (void)centerMainWindow:(id)sender
{
	[mainWindow() exactlyCenterWindow];
}

- (void)toggleFullscreen:(id)sender
{
	[[NSApp keyWindow] toggleFullScreen:sender];
}

- (void)resetMainWindowFrame:(id)sender
{
	if (mainWindow().inFullscreenMode) {
		[mainWindow() toggleFullScreen:sender];
	}

	[mainWindow() setFrame:[mainWindow() defaultWindowFrame] display:YES animate:YES];

	[mainWindow() exactlyCenterWindow];
}

- (void)sortChannelListNames:(id)sender
{
	for (IRCClient *u in worldController().clientList) {
		NSMutableArray *channelList = [u.channelList mutableCopy];

		[channelList sortUsingComparator:^NSComparisonResult(IRCChannel *channel1, IRCChannel *channel2) {
			if (channel1.isChannel && channel2.isChannel == NO) {
				return NSOrderedAscending;
			}

			NSString *name1 = channel1.name.lowercaseString;
			NSString *name2 = channel2.name.lowercaseString;

			return [name1 compare:name2];
		}];

		if ([channelList isEqualToArray:u.channelList]) {
			continue;
		}

		u.channelList = channelList;

		[u reloadServerListItems];
	}

	[worldController() save];
}

- (void)markAllAsRead:(id)sender
{
	[mainWindow() markAllAsRead];
}

#pragma mark -
#pragma mark Preferences

- (void)importPreferences:(id)sender
{
	[TPCPreferencesImportExport importInWindow:mainWindow()];
}

- (void)exportPreferences:(id)sender
{
	[TPCPreferencesImportExport exportInWindow:mainWindow()];
}

#pragma mark -
#pragma mark Off-the-Record Messaging

#if TEXTUAL_BUILT_WITH_ADVANCED_ENCRYPTION == 1
#define _encryptionNotEnabled		([TPCPreferences textEncryptionIsEnabled] == NO)

- (void)encryptionStartPrivateConversation:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (_encryptionNotEnabled || u == nil || c == nil || u.isLoggedIn == NO || c.isPrivateMessage == NO) {
		return;
	}

	[sharedEncryptionManager() beginConversationWith:[u encryptionAccountNameForUser:c.name]
												from:[u encryptionAccountNameForLocalUser]];
}

- (void)encryptionRefreshPrivateConversation:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (_encryptionNotEnabled || u == nil || c == nil || u.isLoggedIn == NO || c.isPrivateMessage == NO) {
		return;
	}

	[sharedEncryptionManager() refreshConversationWith:[u encryptionAccountNameForUser:c.name]
												  from:[u encryptionAccountNameForLocalUser]];
}

- (void)encryptionEndPrivateConversation:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (_encryptionNotEnabled || u == nil || c == nil || u.isLoggedIn == NO || c.isPrivateMessage == NO) {
		return;
	}

	[sharedEncryptionManager() endConversationWith:[u encryptionAccountNameForUser:c.name]
											  from:[u encryptionAccountNameForLocalUser]];
}

- (void)encryptionAuthenticateChatPartner:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (_encryptionNotEnabled || u == nil || c == nil || u.isLoggedIn == NO || c.isPrivateMessage == NO) {
		return;
	}

	[sharedEncryptionManager() authenticateUser:[u encryptionAccountNameForUser:c.name]
										   from:[u encryptionAccountNameForLocalUser]];
}

- (void)encryptionListFingerprints:(id)sender
{
	[sharedEncryptionManager() presentListOfFingerprints];
}

- (void)encryptionWhatIsThisInformation:(id)sender
{
	[TLOpenLink openWithString:@"https://help.codeux.com/textual/Off-the-Record-Messaging.kb" inBackground:NO];
}

#undef _encryptionNotEnabled
#endif

#pragma mark -
#pragma mark Notifications

- (void)toggleMuteOnNotificationsShortcutOn:(BOOL)toggleOn
{
	sharedNotificationController().areNotificationsDisabled = toggleOn;

	NSControlStateValue state = ((toggleOn) ? NSControlStateValueOn : NSControlStateValueOff);

	self.muteNotificationsFileMenuItem.state = state;

	self.muteNotificationsDockMenuItem.state = state;
}

- (void)toggleMuteOnNotificationSoundsShortcutOn:(BOOL)toggleOn
{
	[TPCPreferences setSoundIsMuted:toggleOn];

	NSControlStateValue state = ((toggleOn) ? NSControlStateValueOn : NSControlStateValueOff);

	self.muteNotificationsSoundsDockMenuItem.state = state;

	self.muteNotificationsSoundsFileMenuItem.state = state;
}

- (void)toggleMuteOnNotificationSounds:(id)sender
{
	if ([TPCPreferences soundIsMuted]) {
		[self toggleMuteOnNotificationSoundsShortcutOn:NO];
	} else {
		[self toggleMuteOnNotificationSoundsShortcutOn:YES];
	}
}

- (void)toggleMuteOnNotifications:(id)sender
{
	if (sharedNotificationController().areNotificationsDisabled) {
		[self toggleMuteOnNotificationsShortcutOn:NO];
	} else {
		[self toggleMuteOnNotificationsShortcutOn:YES];
	}
}

#pragma mark -
#pragma mark Appearance

- (void)resetMainWindowAppearance:(id)sender
{
	[TPCPreferences setAppearance:TXPreferredAppearanceInherited];

	[TPCPreferences performReloadAction:TPCPreferencesReloadActionAppearance];
}

- (void)toggleMainWindowAppearance:(id)sender
{
	TXPreferredAppearance appearance = [TPCPreferences appearance];

	switch (appearance) {
		case TXPreferredAppearanceInherited:
		{
			TXAppearance *appAppearance = [TXSharedApplication sharedAppearance];

			if (appAppearance.properties.isDarkAppearance == NO) {
				appearance = TXPreferredAppearanceDark;
			} else {
				appearance = TXPreferredAppearanceLight;
			}

			break;
		}
		case TXPreferredAppearanceLight:
		{
			appearance = TXPreferredAppearanceDark;

			break;
		}
		case TXPreferredAppearanceDark:
		{
			appearance = TXPreferredAppearanceLight;

			break;
		}
	} // switch()

	[TPCPreferences setAppearance:appearance];

	[TPCPreferences performReloadAction:TPCPreferencesReloadActionAppearance];
}

- (void)toggleServerListVisibility:(id)sender
{
	[mainWindow().contentSplitView toggleServerListVisibility];
}

- (void)toggleMemberListVisibility:(id)sender
{
	mainWindowMemberList().isHiddenByUser = (mainWindowMemberList().isHiddenByUser == NO);

	[mainWindow().contentSplitView toggleMemberListVisibility];
}

- (void)forceReloadTheme:(id)sender
{
	[mainWindow() reloadTheme];
}

#pragma mark -
#pragma mark License Manager

- (void)manageLicense:(id)sender
{
#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
	[self manageLicense:sender activateLicenseKey:nil licenseKeyPassedByArgument:NO];
#endif
}

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
- (void)manageLicense:(id)sender activateLicenseKey:(nullable NSString *)licenseKey
{
	[self manageLicense:sender activateLicenseKey:licenseKey licenseKeyPassedByArgument:NO];
}

- (void)manageLicense:(id)sender activateLicenseKeyWithURL:(NSURL *)licenseKeyURL
{
	NSParameterAssert(licenseKeyURL != nil);

	NSString *path = licenseKeyURL.path;

	if (path == nil) {
		return;
	}

	NSCharacterSet *slashCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"/"];

	NSString *licenseKey = [path stringByTrimmingCharactersInSet:slashCharacterSet];

	if (licenseKey.length == 0) {
		return;
	}

	/* A link can come from anywhere, so activation is always confirmed */
	NSString *currentLicenseOwner = TLOLicenseManagerLicenseOwnerName();

	NSString *message = nil;

	if (currentLicenseOwner.length > 0) {
		message = TXTLS(@"TLOLicenseManager[q7w-k2]", licenseKey, currentLicenseOwner);
	} else {
		message = TXTLS(@"TLOLicenseManager[q7w-k1]", licenseKey);
	}

	BOOL activateLicense = [TDCAlert modalAlertWithMessage:message
													 title:TXTLS(@"TLOLicenseManager[q7w-k0]")
											 defaultButton:TXTLS(@"TLOLicenseManager[q7w-k3]")
										   alternateButton:TXTLS(@"Prompts[qso-2g]")];

	if (activateLicense == NO) {
		return;
	}

	[self manageLicense:sender activateLicenseKey:licenseKey licenseKeyPassedByArgument:NO];
}

- (void)manageLicense:(id)sender activateLicenseKey:(nullable NSString *)licenseKey licenseKeyPassedByArgument:(BOOL)licenseKeyPassedByArgument
{
	TDCLicenseManagerDialog *licenseDialog = [TXSharedApplication sharedLicenseManagerDialog];

	[licenseDialog show];

	if (licenseKey) {
		[licenseDialog activateLicenseKey:licenseKey silently:licenseKeyPassedByArgument];
	}
}
#endif

#pragma mark -
#pragma mark Developer

- (void)toggleDeveloperMode:(id)sender
{
	[TPCPreferences setDeveloperModeEnabled:([TPCPreferences developerModeEnabled] == NO)];

	[TPCPreferences performReloadAction:TPCPreferencesReloadActionIRCCommandCache];
}

- (void)resetDoNotAskMePopupWarnings:(id)sender
{
	NSDictionary *settings = [RZUserDefaults() dictionaryRepresentation];

	for (NSString *key in settings) {
		if ([key hasPrefix:TDCAlertSuppressionPrefix] == NO) {
			continue;
		}

		[RZUserDefaults() setBool:NO forKey:key];
	}
}

#pragma mark -
#pragma mark Sparkle Framework

- (void)checkForUpdates:(id)sender
{
#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	SPUStandardUpdaterController *controller = masterController().updateController;

	[controller checkForUpdates:sender];
#endif
}

#pragma mark -
#pragma mark Navigation

- (void)navigateToTreeItemAtURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSString *path = url.path;
	
	if (path == nil) {
		return;
	}
	
	NSCharacterSet *slashCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"/"];
	
	NSString *identifier = [path stringByTrimmingCharactersInSet:slashCharacterSet];
	
	if (identifier.length == 0) {
		return;
	}
	
	[self navigateToTreeItemWithIdentifier:identifier];
}

- (void)navigateToTreeItemWithIdentifier:(NSString *)identifier
{
	NSParameterAssert(identifier != nil);
	
	/* Do not use assert for this condition so we
	 don't crash user when we open a malformed URL. */
	if (identifier.length != 36) {
		return;
	}
	
	IRCTreeItem *item = [worldController() findItemWithId:identifier];
	
	if (item == nil) {
		return;
	}
	
	[self navigateToTreeItem:item];
}

- (void)navigateToTreeItem:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);
	
	[mainWindow() select:item];
}

- (void)populateNavigationChannelList
{
	[self.mainMenuNavigationChannelListMenu removeAllItems];

	NSUInteger channelCount = 0;

	for (IRCClient *u in worldController().clientList) {
		NSMenu *channelSubmenu = [NSMenu new];

		NSMenuItem *clientMenuItem = [NSMenuItem new];

		clientMenuItem.title = u.name;

		clientMenuItem.submenu = channelSubmenu;

		for (IRCChannel *c in u.channelList) {
			NSMenuItem *channelMenuItem = nil;

			if (channelCount >= 10) {
				channelMenuItem = [NSMenuItem menuItemWithTitle:c.name
														 target:self
														 action:@selector(_navigateToChannelInNavigationList:)];
			} else {
				NSUInteger keyboardIndex = (channelCount + 1);

				if (keyboardIndex == 10) {
					keyboardIndex = 0; // Have 0 as the last item.
				}

				channelMenuItem = [NSMenuItem menuItemWithTitle:c.name
														 target:self
														 action:@selector(_navigateToChannelInNavigationList:)
												  keyEquivalent:[NSString stringWithUniChar:('0' + keyboardIndex)]
											  keyEquivalentMask:NSEventModifierFlagCommand];
			}

			channelMenuItem.userInfo = [worldController() pasteboardStringForItem:c];

			[channelSubmenu addItem:channelMenuItem];

			channelCount += 1;
		}

		[self.mainMenuNavigationChannelListMenu addItem:clientMenuItem];
	}
}

- (void)_navigateToChannelInNavigationList:(NSMenuItem *)sender
{
	IRCTreeItem *treeItem = [worldController() findItemWithPasteboardString:sender.userInfo];

	if (treeItem == nil) {
		return;
	}

	[mainWindow() select:treeItem];
}

- (void)performNavigationAction:(id)sender
{
	NSParameterAssert(sender != nil);

	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	switch ([sender tag]) {
		case MTMMNavigationServersMenuNextServer:
		{
			[mainWindow() selectNextServer:sender];

			break;
		}
		case MTMMNavigationServersMenuPreviousServer:
		{
			[mainWindow() selectPreviousServer:sender];

			break;
		}
		case MTMMNavigationServersMenuNextActiveServer:
		{
			[mainWindow() selectNextActiveServer:sender];

			break;
		}
		case MTMMNavigationServersMenuPreviousActiveServer:
		{
			[mainWindow() selectPreviousActiveServer:sender];

			break;
		}
		case MTMMNavigationChannelsMenuNextChannel:
		{
			[mainWindow() selectNextChannel:sender];

			break;
		}
		case MTMMNavigationChannelsMenuPreviousChannel:
		{
			[mainWindow() selectPreviousChannel:sender];

			break;
		}
		case MTMMNavigationChannelsMenuNextActiveChannel:
		{
			[mainWindow() selectNextActiveChannel:sender];

			break;
		}
		case MTMMNavigationChannelsMenuPreviousActiveChannel:
		{
			[mainWindow() selectPreviousActiveChannel:sender];

			break;
		}
		case MTMMNavigationChannelsMenuNextUnreadChannel:
		{
			[mainWindow() selectNextUnreadChannel:sender];

			break;
		}
		case MTMMNavigationChannelsMenuPreviousUnreadChannel:
		{
			[mainWindow() selectPreviousUnreadChannel:sender];

			break;
		}
		case MTMMNavigationMoveBackward:
		{
			[mainWindow() selectPreviousWindow:sender];

			break;
		}
		case MTMMNavigationMoveForward:
		{
			[mainWindow() selectNextWindow:sender];

			break;
		}
		case MTMMNavigationPreviousSelection:
		{
			[mainWindow() selectPreviousSelection:sender];

			break;
		}
	} // switch()
}

- (void)onNextHighlight:(id)sender
{
	TVCLogController *viewController = self.selectedViewController;

	if (viewController == nil) {
		return;
	}

	[viewController nextHighlight];
}

- (void)onPreviousHighlight:(id)sender
{
	TVCLogController *viewController = self.selectedViewController;

	if (viewController == nil) {
		return;
	}

	[viewController previousHighlight];
}

- (void)jumpToCurrentSession:(id)sender
{
	TVCLogController *viewController = self.selectedViewController;

	if (viewController == nil) {
		return;
	}

	[viewController jumpToCurrentSession];
}

- (void)jumpToPresent:(id)sender
{
	TVCLogController *viewController = self.selectedViewController;

	if (viewController == nil) {
		return;
	}

	[viewController jumpToPresent];
}

#pragma mark -
#pragma mark Channel Properties Sheet

- (void)showChannelPropertiesSheet:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || c.isChannel == NO) {
		return;
	}

	TDCChannelPropertiesSheet *sheet =
	[[TDCChannelPropertiesSheet alloc] initWithChannel:c];

	sheet.delegate = self;

	sheet.window = mainWindow();

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)channelPropertiesSheet:(TDCChannelPropertiesSheet *)sender onOk:(IRCChannelConfig *)config
{
	IRCClient *u = sender.client;

	if (u == nil) {
		return;
	}

	IRCChannel *c = sender.channel;

	if (c == nil) {
		[worldController() createChannelWithConfig:config onClient:u];

		[mainWindow() expandClient:u];

		return;
	}

	[c updateConfig:config];

	[worldController() save];
}

- (void)channelPropertiesSheetWillClose:(TDCChannelPropertiesSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Channel Invite Sheet

- (void)memberSendInvite:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO || c.isActive == NO) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	NSMutableArray<NSString *> *channels = [NSMutableArray array];

	for (IRCChannel *e in u.channelList) {
		if (c != e && e.isChannel) {
			[channels addObject:e.name];
		}
	}

	if (channels.count == 0) {
		return;
	}

	TDCChannelInviteSheet *sheet =
	[[TDCChannelInviteSheet alloc] initWithNicknames:nicknames onClient:u];

	sheet.delegate = (id)self;

	sheet.window = mainWindow();

	[sheet startWithChannels:channels];

	[windowController() addWindowToWindowList:sheet];
}

- (void)channelInviteSheet:(TDCChannelInviteSheet *)sender onSelectChannel:(NSString *)channelName
{
	IRCClient *u = sender.client;

	if (u == nil || u.isLoggedIn == NO) {
		return;
	}

	for (NSString *nickname in sender.nicknames) {
		[u sendInviteTo:nickname toJoinChannelNamed:channelName];
	}
}

- (void)channelInviteSheetWillClose:(TDCChannelInviteSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Address Book Sheet

- (void)showAddressBook:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	[self showServerPropertiesSheetForClient:u
							   withSelection:TDCServerPropertiesSheetSelectionAddressBook
									 context:nil];
}

- (void)showIgnoreList:(id)sender
{
	[self showAddressBook:sender];
}

#pragma mark -
#pragma mark Welcome Sheet

- (void)showWelcomeSheet:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	TDCWelcomeSheet *sheet =
	[[TDCWelcomeSheet alloc] initWithWindow:mainWindow()];

	sheet.delegate = (id)self;

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)welcomeSheet:(TDCWelcomeSheet *)sender onOk:(IRCClientConfig *)config
{
	IRCClient *u = [worldController() createClientWithConfig:config reload:YES];

	[mainWindow() expandClient:u];

	[worldController() save];

	[u connect];

	[u selectFirstChannelInChannelList];
}

- (void)welcomeSheetWillClose:(TDCWelcomeSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark About Window

- (void)showAboutWindow:(id)sender
{
	_popWindowViewIfExists(@"TDCAboutDialog");

	TDCAboutDialog *dialog = [TDCAboutDialog new];

	dialog.delegate = (id)self;

	[dialog show];

	[windowController() addWindowToWindowList:dialog];
}

- (void)aboutDialogWillClose:(TDCAboutDialog *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Server Properties Sheet

- (void)showServerPropertiesSheetForClient:(IRCClient *)client withSelection:(TDCServerPropertiesSheetSelection)selection context:(nullable id)context
{
	NSParameterAssert(client != nil);

	[windowController() popMainWindowSheetIfExists];

	TDCServerPropertiesSheet *sheet = [[TDCServerPropertiesSheet alloc] initWithClient:client];

	sheet.delegate = self;

	sheet.window = mainWindow();

	[sheet startWithSelection:selection context:context];

	[windowController() addWindowToWindowList:sheet];
}

- (void)showServerPropertiesSheet:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	[self showServerPropertiesSheetForClient:u
							   withSelection:TDCServerPropertiesSheetSelectionDefault
									 context:nil];
}

- (void)serverPropertiesSheet:(TDCServerPropertiesSheet *)sender onOk:(IRCClientConfig *)config
{
	IRCClient *u = sender.client;

	if (u == nil) {
		u = [worldController() createClientWithConfig:config reload:YES];

		[mainWindow() expandClient:u];

		[worldController() save];

		return;
	}

	BOOL sameEncoding = (config.primaryEncoding == u.config.primaryEncoding);

	[u updateConfig:config];

	if (sameEncoding == NO) {
		[mainWindow() reloadTheme];
	}

	[mainWindow() reloadTreeGroup:u];

	[worldController() save];
}

- (void)serverPropertiesSheetWillClose:(TDCServerPropertiesSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Highlight List Sheet

- (void)showServerHighlightList:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	TDCServerHighlightListSheet *sheet =
	[[TDCServerHighlightListSheet alloc] initWithClient:u];

	sheet.delegate = (id)self;

	sheet.window = mainWindow();

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)serverHighlightListSheetWillClose:(TDCServerHighlightListSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Nickname Color Sheet

- (void)memberChangeColor:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	[windowController() popMainWindowSheetIfExists];

	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	TDCNicknameColorSheet *sheet =
	[[TDCNicknameColorSheet alloc] initWithNickname:nickname];

	sheet.delegate = (id)self;

	sheet.window = mainWindow();

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)nicknameColorSheetOnOk:(TDCNicknameColorSheet *)sender
{
	[mainWindow() reloadTheme];
}

- (void)nicknameColorSheetWillClose:(TDCNicknameColorSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Channel Topic Sheet

- (void)showChannelModifyTopicSheet:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || c.isChannel == NO) {
		return;
	}

	TDCChannelModifyTopicSheet *sheet =
	[[TDCChannelModifyTopicSheet alloc] initWithChannel:c];

	sheet.delegate = (id)self;

	sheet.window = mainWindow();

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)channelModifyTopicSheet:(TDCChannelModifyTopicSheet *)sender onOk:(NSString *)topic
{
	IRCClient *u = sender.client;
	IRCChannel *c = sender.channel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	[u sendTopicTo:topic inChannel:c];
}

- (void)channelModifyTopicSheetWillClose:(TDCChannelModifyTopicSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Channel Mode Sheet

- (void)showChannelModifyModesSheet:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || c.isChannel == NO) {
		return;
	}

	TDCChannelModifyModesSheet *sheet =
	[[TDCChannelModifyModesSheet alloc] initWithChannel:c];

	sheet.delegate = (id)self;

	sheet.window = mainWindow();

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)channelModifyModesSheet:(TDCChannelModifyModesSheet *)sender onOk:(IRCChannelModeContainer *)modes
{
	IRCClient *u = sender.client;
	IRCChannel *c = sender.channel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	NSString *changeString = [c.modeInfo getChangeCommand:modes];

	if (changeString.length == 0) {
		return;
	}

	[u sendModes:changeString withParameters:nil inChannel:c];
}

- (void)channelModifyModesSheetWillClose:(TDCChannelModifyModesSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Channel Spotlight Window

- (void)showChannelSpotlightWindow:(id)sender
{
	_popWindowViewIfExists(@"TDCChannelSpotlightController");

	TDCChannelSpotlightController *dialog = [TDCChannelSpotlightController new];

	dialog.delegate = (id)self;

	[dialog show];

	[windowController() addWindowToWindowList:dialog];
}

- (void)channelSpotlightController:(TDCChannelSpotlightController *)sender selectChannel:(IRCChannel *)channel
{
	[mainWindow() select:channel];
}

- (void)channelSpotlightControllerWillClose:(TDCChannelSpotlightController *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Change Nickname Sheet

- (void)showServerChangeNicknameSheet:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	IRCClient *u = self.selectedClient;

	if (u == nil || u.isLoggedIn == NO) {
		return;
	}

	TDCServerChangeNicknameSheet *sheet =
	[[TDCServerChangeNicknameSheet alloc] initWithClient:u];

	sheet.delegate = (id)self;

	sheet.window = mainWindow();

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)serverChangeNicknameSheet:(TDCServerChangeNicknameSheet *)sender didInputNickname:(NSString *)nickname
{
	IRCClient *u = sender.client;

	if (u == nil || u.isConnected == NO) {
		return;
	}

	[u changeNickname:nickname];
}

- (void)serverChangeNicknameSheetWillClose:(TDCServerChangeNicknameSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Preferences Dialog

- (void)showPreferencesWindow:(id)sender
{
	[self showPreferencesWindowWithSelection:TDCPreferencesControllerSelectionDefault];
}

- (void)showNotificationPreferences:(id)sender
{
	[self showPreferencesWindowWithSelection:TDCPreferencesControllerSelectionNotifications];
}

- (void)showStylePreferences:(id)sender
{
	[self showPreferencesWindowWithSelection:TDCPreferencesControllerSelectionStyle];
}

- (void)showHiddenPreferences:(id)sender
{
	[self showPreferencesWindowWithSelection:TDCPreferencesControllerSelectionHiddenPreferences];
}

- (void)showPreferencesWindowWithSelection:(TDCPreferencesControllerSelection)selection
{
	TDCPreferencesController *openWindow = [windowController() windowFromWindowList:@"TDCPreferencesController"];

	if (openWindow) {
		[openWindow show:selection];

		return;
	}

	TDCPreferencesController *controller =
	[TDCPreferencesController new];

	controller.delegate = (id)self;

	[controller show:selection];

	[windowController() addWindowToWindowList:controller];
}

- (void)preferencesDialogWillClose:(TDCPreferencesController *)sender
{
	[TPCPreferences performReloadAction:(TPCPreferencesReloadActionHighlightKeywords |
										 TPCPreferencesReloadActionPreferencesChanged)];

	[windowController() removeWindowFromWindowList:sender];
}

@end

#pragma mark -
#pragma mark Main Window Proxy

@implementation TXMenuControllerMainWindowProxy

- (void)openStandaloneStoreWebpage:(id)sender
{
	[menuController() openStandaloneStoreWebpage:sender];
}

- (void)manageLicense:(id)sender
{
	[menuController() manageLicense:sender];
}

- (void)showWelcomeSheet:(id)sender
{
	[menuController() showWelcomeSheet:sender];
}

@end

NS_ASSUME_NONNULL_END
