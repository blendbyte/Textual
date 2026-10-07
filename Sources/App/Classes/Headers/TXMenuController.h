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

NS_ASSUME_NONNULL_BEGIN

@class IRCClient, IRCChannel, IRCChannelUser;

/* MT = Menu Tags.
 Each enum holds integers for different menu items so
 that they can be referenced programatically. */
/* For submenu tags, we take the tag of the parent,
 add four zeros to the end, then start from there. */
enum
{
	/* Main menu */
	MTMainMenuApp = 1,
	MTMainMenuFile = 2,
	MTMainMenuEdit = 3,
	MTMainMenuView = 4,
	MTMainMenuServer = 5,
	MTMainMenuChannel = 6,
	MTMainMenuQuery = 7,
	MTMainMenuNavigate = 8,
	MTMainMenuWindow = 9,
	MTMainMenuHelp = 10,

	/* Main menu - App menu */
	MTMMAppAboutApp = 100, // "About Textual"
	MTMMAppAboutAppSeparator = 101, // "-"
	MTMMAppPreferences = 102, // "Preferences…"
	MTMMAppManageLicense = 103, // "Manage license…"
//	MTMMAppInAppPurchase = 104, // "In-app Purchase…"
	MTMMAppCheckForUpdates = 105, // "Check for updates…"
	MTMMAppCheckForUpdatesSeparator = 106, // "-"
	MTMMAppServices = 107, // "Services"
	MTMMAppServicesSeparator = 108, // "-"
	MTMMAppHideApp = 109, // "Hide Textual"
	MTMMAppHideOthers = 110, // "Hide Others"
	MTMMAppShowAll = 111, // "Show All"
	MTMMAppShowAllSeparator = 112, // "-"
	MTMMAppQuitApp = 113, // "Quit Textual & IRC"

	/* Main menu - File menu */
	MTMMFileDisableAllNotifications = 200, // "Disable All Notifications"
	MTMMFileDisableAllNotificationSounds = 201, // "Disable All Notification Sounds"
	MTMMFileDisableAllNotificationSoundsSeparator = 202, // "-"
	MTMMFilePrint = 203, // "Print"
	MTMMFilePrintSeparator = 204, // "-"
	MTMMFileCloseWindow = 205, // "Close Window"

	/* Main menu - Edit menu */
	MTMMEditUndo = 300, // "Undo"
	MTMMEditRedo = 301, // "Redo"
	MTMMEditRedoSeparator = 302, // "-"
	MTMMEditCut = 303, // "Cut"
	MTMMEditCopy = 304, // "Copy"
	MTMMEditPaste = 305, // "Paste"
	MTMMEditDelete = 306, // "Delete"
	MTMMEditSelectAll = 307, // "Select All"
	MTMMEditSelectAllSeparator = 308, // "-"
	MTMMEditFindMenu = 309, // "Find"
	MTMMEditFindMenuFind = 3090000, // "Find…"
	MTMMEditFindMenuFindNext = 3090001, // "Find Next"
	MTMMEditFindMenuFindPrevious = 3090002, // "Find Previous"

	/* Main menu - View menu */
	MTMMViewMarkScrollback = 400, // "Mark Scrollback"
	MTMMViewScrollbackMarker = 401, // "Scrollback Marker"
	MTMMViewScrollbackMarkerSeparator = 402, // "-"
	MTMMViewMarkAllAsRead = 403, // "Mark All as Read"
	MTMMViewClearScrollback = 404, // "Clear Scrollback"
	MTMMViewClearScrollbackSeparator = 405, // "-"
	MTMMViewIncreaseFontSize = 406, // "Increase Font Size"
	MTMMViewDecreaseFontSize = 407, // "Decrease Font Size"
	MTMMViewDecreaseFontSizeSeparator = 408, // "-"
	MTMMViewToggleFullscreen = 409, // "Toggle Fullscreen"

	/* Main menu - Server menu */
	MTMMServerConnect = 500, // "Connect"
	MTMMServerConnectWithoutProxy = 501, // "Connect Without Proxy"
	MTMMServerDisconnect = 502, // "Disconnect"
	MTMMServerCancelReconnect = 503, // "Cancel Reconnect"
	MTMMServerCancelReconnectSeparator = 504, // "-"
	MTMMServerChannelList = 505, // "Channel List…"
	MTMMServerChangeNickname = 506, // "Change Nickname…"
	MTMMServerChangeNicknameSeparator = 507, // "-"
	MTMMServerAddServer = 508, // "Add Server…"
	MTMMServerDuplicateServer = 509, // "Duplicate Server"
	MTMMServerDeleteServer = 510, // "Delete Server…"
	MTMMServerDeleteServerSeparator = 511, // "-"
	MTMMServerAddChannel = 512, // "Add Channel…"
	MTMMServerAddChannelSeparator = 513, // "-"
	MTMMServerServerProperties = 514, // "Server Properties…"

	/* Main menu - Channel menu */
	MTMMChannelJoinChannel = 600, // "Join Channel"
	MTMMChannelLeaveChannel = 601, // "Leave Channel"
	MTMMChannelLeaveChannelSeparator = 602, // "-"
	MTMMChannelAddChannel = 603, // "Add Channel…"
	MTMMChannelDeleteChannel = 604, // "Delete Channel"
	MTMMChannelDeleteChannelSeparator = 605, // "-"
	MTMMChannelViewLogs = 606, // "View Logs"
	MTMMChannelViewLogsSeparator = 607, // "-"
	MTMMChannelModifyTopic = 608, // "Modify Topic"
	MTMMChannelModesMenu = 609, // "Modes"
	MTMMChannelModesMenuAddModerated = 6090000, // "Moderated (+m)"
	MTMMChannelModesMenuRemoveModerated = 6090001, // "Unmoderated (-m)"
	MTMMChannelModesMenuAddInviteOnly = 6090002, // "Invite Only (+i)"
	MTMMChannelModesMenuRemoveInviteOnly = 6090003, // "Anyone Can Join (-i)"
	MTMMChannelModesMenuManageAllModes = 6090004, // "Manage All Modes"
	MTMMChannelModesMenuSeparator = 610, // "-"
	MTMMChannelListOfBans = 611, // "List of Bans"
	MTMMChannelListOfBanExceptions = 612, // "List of Ban Exceptions"
	MTMMChannelListOfInviteExceptions = 613, // "List of Invite Exceptions"
	MTMMChannelListOfQuiets = 614, // "List of Quiets"
	MTMMChannelListOfQuietsSeparator = 615, // "-"
	MTMMChannelChannelProperties = 616, // "Channel Properties…"
	MTMMChannelChannelPropertiesSeparator = 617, // "-"
	MTMMChannelCopyUniqueIdentifier = 618, //

	/* Main menu - Query menu */
	MTMMQueryCloseQuery = 1800, // "Close Query"
	MTMMQueryCloseQuerySeparator = 1801, // "-"
	MTMMQueryQueryLogs = 1802, // "Query Logs"

	/* Main menu - Navigation menu */
	MTMMNavigationServersMenu = 700, // "Servers"
	MTMMNavigationServersMenuNextServer = 7000000, // "Next Server"
	MTMMNavigationServersMenuPreviousServer = 7000001, // "Previous Server"
	MTMMNavigationServersMenuPreviousServerSeparator = 7000002, // "-"
	MTMMNavigationServersMenuNextActiveServer = 7000003, // "Next Active Server"
	MTMMNavigationServersMenuPreviousActiveServer = 7000004, // "Previous Active Server"
	MTMMNavigationChannelsMenu = 701, // "Channels"
	MTMMNavigationChannelsMenuNextChannel = 7010000, // "Next Channel"
	MTMMNavigationChannelsMenuPreviousChannel = 7010001, // "Previous Channel"
	MTMMNavigationChannelsMenuPreviousChannelSeparator = 7010002, // "-"
	MTMMNavigationChannelsMenuNextActiveChannel = 7010003, // "Next Active Channel"
	MTMMNavigationChannelsMenuPreviousActiveChannel = 7010004, // "Previous Active Channel"
	MTMMNavigationChannelsMenuPreviousActiveChannelSeparator = 7010005, // "-"
	MTMMNavigationChannelsMenuNextUnreadChannel = 7010006, // "Next Unread Channel"
	MTMMNavigationChannelsMenuPreviousUnreadChannel = 7010007, // "Previous Unread Channel"
	MTMMNavigationChannelsMenuSeparator = 702, // "-"
	MTMMNavigationMoveBackward = 703, // "Move Backward"
	MTMMNavigationMoveForward = 704, // "Move Forward"
	MTMMNavigationMoveForwardSeparator = 705, // "-"
	MTMMNavigationPreviousSelection = 706, // "Previous Selection"
	MTMMNavigationPreviousSelectionSeparator = 707, // "-"
	MTMMNavigationNextHighlight = 708, // "Next Highlight"
	MTMMNavigationPreviousHighlight = 709, // "Previous Highlight"
	MTMMNavigationPreviousHighlightSeparator = 710, // "-"
	MTMMNavigationJumpToCurrentSession = 711, // "Jump to Current Session"
	MTMMNavigationJumpToPresent = 712, // "Jump to Present"
	MTMMNavigationJumpToPresentSeparator = 713, // "-"
	MTMMNavigationChannelList = 714, // "Channel List…"
	MTMMNavigationChannelListSeparator = 715, // "-"
	MTMMNavigationSearchChannels = 716, // "Search channels…"

	/* Main menu - Window menu */
	MTMMWindowMinimize = 800, // "Minimize"
	MTMMWindowZoom = 801, // "Zoom"
	MTMMWindowZoomSeparator = 802, // "-"
	MTMMWindowToggleVisibilityOfMemberList = 803, // "Toggle Visibility of Member List"
	MTMMWindowToggleVisibilityOfServerList = 804, // "Toggle Visibility of Server List"
	MTMMWindowToggleWindowAppearance = 805, // "Toggle Window Appearance"
	MTMMWindowToggleWindowAppearanceSeparator = 806, // "-"
	MTMMWindowSortChannelList = 807, // "Sort Channel List"
	MTMMWindowSortChannelListSeparator = 808, // "-"
	MTMMWindowCenterWindow = 809, // "Center Window"
	MTMMWindowResetWindowToDefaultSize = 810, // "Reset Window to Default Size"
	MTMMWindowResetWindowToDefaultSizeSeparator = 811, // "-"
	MTMMWindowMainWindow = 812, // "Main Window"
	MTMMWindowAddressBook = 813, // "Address Book"
	MTMMWindowIgnoreList = 814, // "Ignore List"
	MTMMWindowViewLogs = 815, // "View Logs"
	MTMMWindowHighlightList = 816, // "Highlight List"
	MTMMWindowFileTransfers = 817, // "File Transfers"
	MTMMWindowFileTransfersSeparator = 818, // "-"
	MTMMWindowBrightAllToFront = 819, // "Bring All to Front"

	/* Main menu - Help menu */
	MTMMHelpAcknowledgements = 900, // "Acknowledgements"
	MTMMHelpLicenseAgreement = 901, // "License Agreement"
	MTMMHelpPrivacyPolicy = 902, // "Privacy Policy"
	MTMMHelpPrivacyPolicySeparator = 903, // "-"
	MTMMHelpFrequentlyAskedQuestions = 904, // "Frequently Asked Questions"
	MTMMHelpKnowledgeBaseMenu = 905, // "Knowledge Base"
	/* Highest: 9050016 */
	MTMMHelpKBMenuKnowledgeBaseHome = 9050000, // "Knowledge Base Home"
	MTMMHelpKBMenuKnowledgeBaseHomeSeparator = 9050001, // "-"
	MTMMHelpKBMenuCommandReference = 9050005, // "Command Reference"
	MTMMHelpKBMenuFeatureRequests = 9050006, // "Feature Requests"
	MTMMHelpKBMenuKeyboardShortcuts = 9050007, // "Keyboard Shortcuts"
	MTMMHelpKBMenuMemoryManagement = 9050008, // "Memory Management"
	MTMMHelpKBMenuNetworkTimeouts = 9050016, // "Network Timeouts"
	MTMMHelpKBMenuTextFormatting = 9050009, // "Text Formatting"
	MTMMHelpKBMenuStylingInformation = 9050010, // "Styling Information"
	MTMMHelpKBMenuStylingInformationSeparator = 9050011, // "-"
	MTMMHelpKBMenuConnectingWithCertificate = 9050012, // "Connecting with Certificate"
	MTMMHelpKBMenuConnectingToBouncer = 9050013, // "Connecting to a ZNC Bouncer"
	MTMMHelpKBMenuConnectingToBouncerSeparator = 9050014, // "-"
	MTMMHelpKBMenuDCCFileTransferInformation = 9050015, // "DCC File Transfer Information"
	MTMMHelpKnowledgeBaseMenuSeparator = 906, // "-"
	MTMMHelpConnectToHelpChannel = 907, // "Connect to Help Channel"
	MTMMHelpConnectToTestingChannel = 908, // "Connect to Testing Channel"
	MTMMHelpConnectToTestingChannelSeparator = 909, // "-"
	MTMMHelpAdvancedMenu = 910, // "Advanced"
	MTMMHelpAdvancedMenuEnableDeveloperMode = 9100000, // "Enable Developer Mode"
	MTMMHelpAdvancedMenuEnableDeveloperModeSeparator = 9100001, // "-"
	MTMMHelpAdvancedMenuHiddenPreferences = 9100002, // "Hidden Preferences…"
	MTMMHelpAdvancedMenuHiddenPreferencesSeparator = 9100003, // "-"
	MTMMHelpAdvancedMenuExportPreferences = 9100004, // "Export Preferences"
	MTMMHelpAdvancedMenuImportPreferences = 9100005, // "Import Preferences"
	MTMMHelpAdvancedMenuImportPreferencesSeparator = 9100006, // "-"
	MTMMHelpAdvancedMenuResetDontAskMeWarnings = 9100007, // "Reset 'Don't Ask Me' Warnings"

	/* WebKit channel name menu */
	MTWKChannelNameJoinChannel = 1000, // "Join Channel"

	/* WebKit URL menu */
	MTWKURLCopyURL = 1100, // "Copy URL"

	/* WebKit general menu */
	MTWKGeneralChangeNickname = 1200, // "Change Nickname…"
	MTWKGeneralChangeNicknameSeparator = 1201, // "-"
	MTWKGeneralSearchWithGoogle = 1202, // "Search With Google"
	MTWKGeneralLookUpInDictionary = 1203, // "Look Up In Dictionary"
	MTWKGeneralLookUpInDictionarySeparator = 1204, // "-"
	MTWKGeneralCopy = 1205, // "Copy"
	MTWKGeneralPaste = 1206, // "Paste"
	MTWKGeneralPasteSeparator = 1207, // "-"
	MTWKGeneralQueryLogs = 1208, // "Query Logs"
	MTWKGeneralChannelMenu = 1209, // "Channel"

	/* Main window segmented controller */
	MTMainWindowSegmentedControllerAddServer = 1300, // "Add Server…"
	MTMainWindowSegmentedControllerAddServerSeparator = 1301, // "-"
	MTMainWindowSegmentedControllerAddChannel = 1302, // "Add Channel…"

	/* Empty server list menu */
	MTMainWindowServerListAddServer = 1400, // "Add Server…"

	/* User context menu */
	MTUserControlsLowestTag = 1600,
	MTUserControlsHighestTag = 1699,

	MTUserControlsAddIgnore = 1600, // "Add Ignore"
	MTUserControlsModifyIgnore = 1601, // "Modify Ignore"
	MTUserControlsRemoveIgnore = 1602, // "Remove Ignore"
	MTUserControlsRemoveIgnoreSeparator = 1603, // "-"
	MTUserControlsInviteTo = 1604, // "Invite to…"
	MTUserControlsInviteToSeparator = 1605, // "-"
	MTUserControlsGetInfo = 1606, // "Get Info (Whois)"
	MTUserControlsPrivateMessage = 1607, // "Private Message (Query)"
	MTUserControlsPrivateMessageSeparator = 1608, // "-"
	MTUserControlsGiveOp = 1609, // "Give Op (+o)"
	MTUserControlsGiveHalfop = 1610, // "Give Halfop (+h)"
	MTUserControlsGiveVoice = 1611, // "Give Voice (+v)"
	MTUserControlsAllModesGiven = 1612, // "All Modes Given"
	MTUserControlsAllModesGivenSeparator = 1613, // "-"
	MTUserControlsTakeOp = 1614, // "Take Op (-o)"
	MTUserControlsTakeHalfop = 1615, // "Take Halfop (-h)"
	MTUserControlsTakeVoice = 1616, // "Take Voice (-v)"
	MTUserControlsAllModesTaken = 1617, // "All Modes Taken"
	MTUserControlsAllModesTakenSeparator = 1618, // "-"
	MTUserControlsBan = 1619, // "Ban"
	MTUserControlsKick = 1620, // "Kick"
	MTUserControlsBanAndKick = 1621, // "Ban and Kick"
	MTUserControlsBanAndKickSeparator = 1622, // "-"
	MTUserControlsClientToClientMenu = 1623, // "Client-to-Client"
	MTUserControlsClientToClientMenuSendFile = 16230000, // "Send file…"
	MTUserControlsClientToClientMenuSendFileSeparator = 16230001, // "-"
	MTUserControlsClientToClientMenuLag = 16230002, // "Lag (PING)"
	MTUserControlsClientToClientMenuLocalTime = 16230003, // "Local Time (TIME)"
	MTUserControlsClientToClientMenuLocalTimeSeparator = 16230004, // "-"
	MTUserControlsClientToClientMenuClientInformation = 16230005, // "Client Information (CLIENTINFO)"
	MTUserControlsClientToClientMenuClientVersion = 16230006, // "Client Version (VERSION)"
	MTUserControlsClientToClientMenuClientVersionSeparator = 16230007, // "-"
	MTUserControlsClientToClientMenuUserInformationFinger = 16230008, // "User Information (FINGER)"
	MTUserControlsClientToClientMenuUserInformationUserinfo = 16230009, // "User Information (USERINFO)"
	MTUserControlsIRCOperatorMenu = 1624, // "IRC Operator"
	MTUserControlsIRCOperatorMenuSetVirtualHost = 16240000, // "Set Virtual Host (vHost)"
	MTUserControlsIRCOperatorMenuSetVirtualHostSeparator = 16240001, // "-"
	MTUserControlsIRCOperatorMenuKillFromServer = 16240002, // "Kill from Server"
	MTUserControlsIRCOperatorMenuShunOnServer = 16240003, // "Shun on Server"
	MTUserControlsIRCOperatorMenuBanFromServer = 16240004, // "Ban from Server (G:Line)"

	/* Dock menu */
	MTDockMenuDisableAllNotifications = 1700, // "Disable All Notifications"
	MTDockMenuDisableAllNotificationSounds = 1701, // "Disable All Notification Sounds"
};

@interface TXMenuController : NSObject
@property (readonly, strong) NSMenu *channelViewChannelNameMenu;
@property (readonly, strong) NSMenu *channelViewGeneralMenu;
@property (readonly, strong) NSMenu *channelViewURLMenu;

@property (readonly, strong) NSMenu *dockMenu;

@property (readonly, weak) NSMenu *mainMenuNavigationChannelListMenu;
@property (readonly, weak) NSMenu *mainMenuChannelMenu;
@property (readonly, weak) NSMenu *mainMenuQueryMenu;
@property (readonly, weak) NSMenuItem *mainMenuChannelMenuItem;
@property (readonly, weak) NSMenuItem *mainMenuQueryMenuItem;
@property (readonly, weak) NSMenuItem *mainMenuServerMenuItem;

@property (readonly, strong) NSMenu *mainWindowSegmentedControllerCellMenu;

@property (readonly, strong) NSMenu *serverListNoSelectionMenu;

@property (readonly, strong) NSMenu *userControlMenu;

@property (readonly, weak) IRCClient *selectedClient;
@property (readonly, weak) IRCChannel *selectedChannel;

- (NSArray<IRCChannelUser *> *)selectedMembers:(id)sender;
- (NSArray<NSString *> *)selectedMembersNicknames:(id)sender;
- (void)deselectMembers:(id)sender;

- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;

- (IBAction)print:(id)sender;

- (IBAction)closeWindow:(id)sender;

- (IBAction)contactSupport:(id)sender;

- (IBAction)addChannel:(id)sender;
- (IBAction)deleteChannel:(id)sender;

- (IBAction)addServer:(id)sender;
- (IBAction)duplicateServer:(id)sender;
- (IBAction)deleteServer:(id)sender;

- (IBAction)joinChannel:(id)sender;
- (IBAction)leaveChannel:(id)sender;

- (IBAction)connect:(id)sender;
- (IBAction)connectBypassingProxy:(id)sender;

- (IBAction)connectToTextualHelpChannel:(id)sender;
- (IBAction)connectToTextualTestingChannel:(id)sender;

- (IBAction)disconnect:(id)sender;
- (IBAction)cancelReconnection:(id)sender;

- (IBAction)clearScrollback:(id)sender;

- (IBAction)markAllAsRead:(id)sender;

- (IBAction)decreaseLogFontSize:(id)sender;
- (IBAction)increaseLogFontSize:(id)sender;

- (IBAction)jumpToCurrentSession:(id)sender;
- (IBAction)jumpToPresent:(id)sender;

- (IBAction)gotoScrollbackMarker:(id)sender;
- (IBAction)markScrollback:(id)sender;

- (IBAction)exportPreferences:(id)sender;
- (IBAction)importPreferences:(id)sender;

- (IBAction)memberAddIgnore:(id)sender;
- (IBAction)memberModifyIgnore:(id)sender;
- (IBAction)memberRemoveIgnore:(id)sender;

- (IBAction)memberBanFromChannel:(id)sender;
- (IBAction)memberKickFromChannel:(id)sender;
- (IBAction)memberKickbanFromChannel:(id)sender;

- (IBAction)memberModeGiveHalfop:(id)sender;
- (IBAction)memberModeGiveOp:(id)sender;
- (IBAction)memberModeGiveVoice:(id)sender;
- (IBAction)memberModeTakeHalfop:(id)sender;
- (IBAction)memberModeTakeOp:(id)sender;
- (IBAction)memberModeTakeVoice:(id)sender;

- (IBAction)memberSendCTCPClientInfo:(id)sender;
- (IBAction)memberSendCTCPFinger:(id)sender;
- (IBAction)memberSendCTCPPing:(id)sender;
- (IBAction)memberSendCTCPTime:(id)sender;
- (IBAction)memberSendCTCPUserinfo:(id)sender;
- (IBAction)memberSendCTCPVersion:(id)sender;

- (IBAction)memberSendFileRequest:(id)sender;

- (IBAction)memberSendInvite:(id)sender;
- (IBAction)memberSendWhois:(id)sender;

- (IBAction)memberBanFromServer:(id)sender;
- (IBAction)memberKillFromServer:(id)sender;
- (IBAction)memberShunOnServer:(id)sender;

- (IBAction)memberStartPrivateMessage:(id)sender;

- (IBAction)onNextHighlight:(id)sender;
- (IBAction)onPreviousHighlight:(id)sender;

- (IBAction)openStandaloneStoreWebpage:(id)sender;;

- (IBAction)openChannelLogs:(id)sender;
- (IBAction)openLogLocation:(id)sender;

- (IBAction)centerMainWindow:(id)sender;
- (IBAction)resetMainWindowFrame:(id)sender;

- (IBAction)openAcknowledgements:(id)sender;

- (IBAction)showAboutWindow:(id)sender;
- (IBAction)showAddressBook:(id)sender;
- (IBAction)showChannelBanExceptionList:(id)sender;
- (IBAction)showChannelBanList:(id)sender;
- (IBAction)showChannelInviteExceptionList:(id)sender;
- (IBAction)showChannelQuietList:(id)sender;
- (IBAction)showChannelModifyModesSheet:(id)sender;
- (IBAction)showChannelModifyTopicSheet:(id)sender;
- (IBAction)showChannelPropertiesSheet:(id)sender;
- (IBAction)showChannelSpotlightWindow:(id)sender;
- (IBAction)showFileTransfersWindow:(id)sender;
- (IBAction)showFindPrompt:(id)sender;
- (IBAction)showHiddenPreferences:(id)sender;
- (IBAction)showIgnoreList:(id)sender;
- (IBAction)showMainWindow:(id)sender;
- (IBAction)showNotificationPreferences:(id)sender;
- (IBAction)showPreferencesWindow:(id)sender;
- (IBAction)showServerChangeNicknameSheet:(id)sender;
- (IBAction)showServerChannelList:(id)sender;
- (IBAction)showServerHighlightList:(id)sender;
- (IBAction)showServerPropertiesSheet:(id)sender;
- (IBAction)showSetVhostPrompt:(id)sender;
- (IBAction)showStylePreferences:(id)sender;
- (IBAction)showWelcomeSheet:(id)sender;

- (IBAction)sortChannelListNames:(id)sender;

- (IBAction)toggleChannelInviteMode:(id)sender;
- (IBAction)toggleChannelModerationMode:(id)sender;

- (IBAction)toggleFullscreen:(id)sender;

- (IBAction)toggleMainWindowAppearance:(id)sender;
- (IBAction)resetMainWindowAppearance:(id)sender;

- (IBAction)toggleDeveloperMode:(id)sender;

- (IBAction)toggleServerListVisibility:(id)sender;
- (IBAction)toggleMemberListVisibility:(id)sender;

- (IBAction)toggleMuteOnNotifications:(id)sender;
- (IBAction)toggleMuteOnNotificationSounds:(id)sender;

- (IBAction)manageLicense:(id)sender;

- (IBAction)copyUniqueIdentifier:(id)sender;

- (IBAction)copyUrl:(id)sender;

- (IBAction)lookUpInDictionary:(id)sender;
- (IBAction)searchGoogle:(id)sender;
- (IBAction)copyLogAsHtml:(id)sender;
- (IBAction)forceReloadTheme:(id)sender;
- (IBAction)openWebInspector:(id)sender TEXTUAL_DEPRECATED("Does nothing. Use Inspect Element in the chat view's context menu");

- (IBAction)checkForUpdates:(id)sender;

- (IBAction)resetDoNotAskMePopupWarnings:(id)sender;
@end

NS_ASSUME_NONNULL_END
