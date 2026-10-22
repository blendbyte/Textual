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
#import "TVCLogPolicyPrivate.h"
#import "TVCLogViewPrivate.h"
#import "TVCLogViewInternalWK2.h"
#import "TVCMemberList.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowSplitView.h"
#import "TVCMainWindowTextView.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLOLocalization.h"
#import "TLOpenLink.h"
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
#import "TDCServerChangeNicknameSheetPrivate.h"
#import "TDCServerPropertiesSheetPrivate.h"
#import "TXWebsiteLinks.h"
#import "TDCAddBouncerSheetPrivate.h"
#import "TDCEditBouncerSheetPrivate.h"
#import "IRCBouncerAccountPrivate.h"
#import "IRCClientConfigPrivate.h"
#import "IRCServerPrivate.h"
#import "TDCWelcomeSheetPrivate.h"
#import "TPCPathInfoPrivate.h"
#import "TPCPreferencesImportExport.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesReload.h"
#import "TPCPreferencesUserDefaults.h"
#import "TXMasterControllerPrivate.h"
#import "TXWindowControllerPrivate.h"

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
#import <Sparkle/Sparkle.h>
#endif
#import "TXMenuControllerInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TXMenuController (ServerChannel)

#pragma mark -
#pragma mark Server

- (void)connect:(nullable id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil || u.isConnecting || u.isConnected || u.isQuitting) {
		return;
	}

	[u connect];

	[mainWindow() expandClient:u];
}

- (void)connectBypassingProxy:(nullable id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil || u.isConnecting || u.isConnected || u.isQuitting) {
		return;
	}

	[u connect:IRCClientConnectModeNormal bypassProxy:YES];

	[mainWindow() expandClient:u];
}

- (void)disconnect:(nullable id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil || (u.isConnecting == NO && u.isConnected == NO) || u.isQuitting) {
		return;
	}

	[u quit];
}

- (void)cancelReconnection:(nullable id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	[u cancelReconnect];
}

- (void)showServerChannelList:(nullable id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil || u.isLoggedIn == NO) {
		return;
	}

	[u showChannelList];
}

- (void)addServer:(nullable id)sender
{
	[self addServerFilledInWith:nil];
}

- (void)addServerFilledInWith:(nullable IRCClientConfig *)config
{
	[windowController() popMainWindowSheetIfExists];

	TDCServerPropertiesSheet *sheet =
	[[TDCServerPropertiesSheet alloc] initWithClient:nil];

	if (config) {
		[sheet fillInNewServer:config];
	}

	sheet.delegate = self;

	sheet.window = TVCMainWindow.currentWindow;

	[sheet startWithSelection:TDCServerPropertiesSheetSelectionDefault context:nil];

	[windowController() addWindowToWindowList:sheet];
}

/* The Add Bouncer sheet: the account and a server per network it adds here */
- (void)addBouncer:(nullable id)sender
{
	[self openAddBouncerSheetFillingIn:nil];
}

- (void)addBouncerFilledInWith:(nullable IRCClient *)client
{
	/* Its address and login, the network left out */
	IRCClientConfig *config = client.config;

	IRCServer *server = config.serverList.firstObject;

	NSArray<NSString *> *login = ((config) ? [IRCBouncerAccount bouncerLoginsOfServerAddedByHand:config].firstObject : nil);

	if (config == nil || server == nil || login == nil) {
		[self openAddBouncerSheetFillingIn:nil];

		return;
	}

	NSString *password = [IRCBouncerAccount bouncerPasswordOfServerAddedByHand:config];

	[self openAddBouncerSheetFillingIn:^(TDCAddBouncerSheet *sheet) {
		[sheet fillInAddress:server.serverAddress
						port:server.serverPort
					 secured:server.prefersSecuredConnection
					username:login[0]
					password:password];

		sheet.linksServersAddedByHand = YES;
	}];
}

- (void)addBouncerWithSetupLink:(NSString *)location
{
	NSParameterAssert(location != nil);

	NSURLComponents *components = [NSURLComponents componentsWithString:location];

	NSMutableDictionary<NSString *, NSString *> *values = [NSMutableDictionary dictionary];

	for (NSURLQueryItem *item in components.queryItems) {
		if (item.value) {
			values[item.name.lowercaseString] = item.value;
		}
	}

	NSString *address = [values[@"host"] trim];

	/* A link never carries a password: one in it is left out */
	if (address.length == 0) {
		[self openAddBouncerSheetFillingIn:nil];

		return;
	}

	NSString *tls = values[@"tls"].lowercaseString;

	BOOL secured = (tls == nil || [tls isEqualToString:@"1"] || [tls isEqualToString:@"true"] || [tls isEqualToString:@"yes"]);

	NSInteger portValue = values[@"port"].integerValue;

	uint16_t port = (((portValue > 0 && portValue <= UINT16_MAX)) ? (uint16_t)portValue : ((secured) ? 6697 : 6667));

	NSString *username = ([values[@"user"] trim] ?: @"");

	[self openAddBouncerSheetFillingIn:^(TDCAddBouncerSheet *sheet) {
		[sheet fillInAddress:address port:port secured:secured username:username password:nil];
	}];
}

- (void)openAddBouncerSheetFillingIn:(nullable void (^)(TDCAddBouncerSheet *sheet))fillIn
{
	[windowController() popMainWindowSheetIfExists];

	__weak TXMenuController *weakSelf = self;

	TDCAddBouncerSheet *sheet =
	[[TDCAddBouncerSheet alloc] initWithExistingClient:^IRCClient *(IRCBouncerNetwork *network, IRCBouncerAccount *account) {
		return [worldController() clientAddedByHandForNetwork:network ofAccount:account];
	} add:^(IRCBouncerAccount *account, NSArray<IRCBouncerNetwork *> *networks, NSDictionary<NSString *, IRCClient *> *linkedClients, BOOL connect) {
		NSArray *clients = [worldController() addBouncerAccount:account withNetworks:networks linkedClients:linkedClients connect:connect];

		IRCClient *firstClient = clients.firstObject;

		if (firstClient) {
			[mainWindow() select:firstClient];
		}
	} addAsServer:^(NSString *address, uint16_t port, BOOL secured) {
		IRCServerMutable *server = [IRCServerMutable new];

		server.serverAddress = address;
		server.serverPort = port;
		server.prefersSecuredConnection = secured;

		IRCClientConfigMutable *config = [IRCClientConfigMutable new];

		config.connectionName = address;
		config.serverList = @[[server copy]];

		[weakSelf addServerFilledInWith:config];
	}];

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
	/* "No bouncer yet?" (not in the App Store build) */
	sheet.hostingOfferURL = [NSURL URLWithString:TXWebsiteZNCHost];
#endif

	if (fillIn) {
		fillIn(sheet);
	}

	[sheet beginInWindow:TVCMainWindow.currentWindow];
}

- (void)editBouncer:(nullable id)sender
{
	IRCBouncerAccount *account = self.selectedClient.bouncerAccount;

	if (account == nil) {
		return;
	}

	[self editBouncerAccount:account];
}

- (void)editBouncerAccount:(IRCBouncerAccount *)account
{
	[self editBouncerAccount:account inWindow:nil];
}

- (void)editBouncerAccount:(IRCBouncerAccount *)account inWindow:(nullable NSWindow *)window
{
	[self editBouncerAccount:account inWindow:window showingNetworks:NO];
}

- (void)editBouncerAccount:(IRCBouncerAccount *)account inWindow:(nullable NSWindow *)window showingNetworks:(BOOL)showingNetworks
{
	NSParameterAssert(account != nil);

	if (window == nil) {
		[windowController() popMainWindowSheetIfExists];

		window = TVCMainWindow.currentWindow;
	}

	/* The networks as a connected network of the bouncer knows them */
	IRCBouncerNetworkList *networks = nil;

	for (IRCClient *client in [worldController() clientsOfBouncerAccount:account]) {
		if (client.bouncerNetworks) {
			networks = client.bouncerNetworks;

			break;
		}
	}

	NSString *accountIdentifier = account.uniqueIdentifier;

	TDCEditBouncerSheet *sheet =
	[[TDCEditBouncerSheet alloc] initWithAccount:account
										networks:networks
								  existingClient:^IRCClient *(IRCBouncerNetwork *network, IRCBouncerAccount *anAccount) {
		return [worldController() clientAddedByHandForNetwork:network ofAccount:anAccount];
	} save:^(IRCBouncerAccount *updatedAccount) {
		IRCBouncerAccount *previousAccount = [worldController() findBouncerAccountWithId:accountIdentifier];

		/* Connected networks reconnect with a changed login */
		BOOL loginChanged =
		(previousAccount == nil ||
		 [previousAccount.serverAddress isEqualToString:updatedAccount.serverAddress] == NO ||
		 previousAccount.serverPort != updatedAccount.serverPort ||
		 previousAccount.prefersSecuredConnection != updatedAccount.prefersSecuredConnection ||
		 [previousAccount.username isEqualToString:updatedAccount.username] == NO ||
		 NSObjectsAreEqual(previousAccount.identityClientSideCertificate, updatedAccount.identityClientSideCertificate) == NO ||
		 NSObjectsAreEqual(previousAccount.password, updatedAccount.password) == NO);

		[worldController() addBouncerAccount:updatedAccount];

		if (loginChanged == NO) {
			return;
		}

		for (IRCClient *client in [worldController() clientsOfBouncerAccount:updatedAccount]) {
			if (client.isConnecting || client.isConnected) {
				[client quitThen:^(IRCClient *disconnectedClient) {
					[disconnectedClient connect];
				}];
			}
		}
	} addNetwork:^(IRCBouncerNetwork *network) {
		IRCBouncerAccount *currentAccount = [worldController() findBouncerAccountWithId:accountIdentifier];

		if (currentAccount == nil) {
			return;
		}

		[worldController() addBouncerAccount:currentAccount withNetworks:@[network] linkedClients:@{} connect:YES];
	} remove:^(BOOL keepServers) {
		IRCBouncerAccount *currentAccount = [worldController() findBouncerAccountWithId:accountIdentifier];

		if (currentAccount == nil) {
			return;
		}

		[worldController() removeBouncerAccount:currentAccount keepServers:keepServers];
	}];

	sheet.showsNetworksFirst = showingNetworks;

	[sheet beginInWindow:window];
}

- (void)duplicateServer:(nullable id)sender
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

- (void)deleteServer:(nullable id)sender
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

- (void)joinChannel:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO || c.isActive) {
		return;
	}

	[u joinChannel:c];

	[mainWindow() select:c];
}

- (void)leaveChannel:(nullable id)sender
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

- (void)addChannel:(nullable id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	[windowController() popMainWindowSheetIfExists];

	TDCChannelPropertiesSheet *sheet =
	[[TDCChannelPropertiesSheet alloc] initWithClient:u];

	sheet.delegate = self;

	sheet.window = TVCMainWindow.currentWindow;

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)deleteChannel:(nullable id)sender
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

- (void)copyUniqueIdentifier:(nullable id)sender
{
	IRCChannel *c = self.selectedChannel;

	if (c == nil) {
		return;
	}

	[RZPasteboard() setStringContent:c.uniqueIdentifier];
}

#pragma mark -
#pragma mark Other Actions

- (void)openUrl:(nullable id)sender
{
	NSString *pointedUrl = ((NSMenuItem *)sender).userInfo;

	if (pointedUrl.length == 0) {
		return;
	}

	NSURL *url = [NSURL URLWithString:pointedUrl];

	if (url == nil) {
		return;
	}

	[self.selectedViewControllerBackingView.webViewPolicy openWebpage:url];
}

- (void)copyUrl:(nullable id)sender
{
	NSString *pointedUrl = ((NSMenuItem *)sender).userInfo;

	if (pointedUrl.length == 0) {
		return;
	}

	RZPasteboard().stringContent = pointedUrl;
}

- (void)joinChannelClicked:(nullable id)sender
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

#pragma mark -
#pragma mark Logging

- (void)openLogLocation:(nullable id)sender
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

- (void)openChannelLogs:(nullable id)sender
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
#pragma mark IRC

- (void)showChannelBanList:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	[u createChannelBanListSheet];

	[u sendModes:@"+b" withParameters:nil inChannel:c];
}

- (void)showChannelBanExceptionList:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	[u createChannelBanExceptionListSheet];

	[u sendModes:@"+e" withParameters:nil inChannel:c];
}

- (void)showChannelInviteExceptionList:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	[u createChannelInviteExceptionListSheet];

	[u sendModes:@"+I" withParameters:nil inChannel:c];
}

- (void)showChannelQuietList:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	[u createChannelQuietListSheet];

	[u sendModes:@"+q" withParameters:nil inChannel:c];
}

- (void)toggleChannelModerationMode:(nullable id)sender
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

- (void)toggleChannelInviteMode:(nullable id)sender
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
#pragma mark Mute

- (nullable IRCTreeItem *)_treeItemToMuteForMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.tag == MTMMServerMuteNetwork) {
		return self.selectedClient;
	}

	IRCChannel *channel = self.selectedChannel;

	if (channel.isUtility) {
		return nil;
	}

	return channel;
}

#pragma mark -
#pragma mark Pop-out Windows

/* The server's menu pops out its console; the others the channel or private
 message, or the server console when that is what's selected */
- (nullable IRCTreeItem *)_treeItemToPopOutForMenuItem:(NSMenuItem *)menuItem
{
	IRCClient *client = self.selectedClient;

	if (menuItem.tag == MTMMServerOpenInNewWindow) {
		return client;
	}

	IRCChannel *channel = self.selectedChannel;

	if (channel) {
		return channel;
	}

	if (menuItem.tag == MTMMWindowOpenInNewWindow) {
		return client;
	}

	return nil;
}

- (void)openInNewWindow:(nullable id)sender
{
	if ([sender isKindOfClass:[NSMenuItem class]] == NO) {
		return;
	}

	IRCTreeItem *item = [self _treeItemToPopOutForMenuItem:sender];

	if (item == nil) {
		return;
	}

	[TVCMainWindow popOutItem:item];
}

- (void)toggleMute:(nullable id)sender
{
	if ([sender isKindOfClass:[NSMenuItem class]] == NO) {
		return;
	}

	IRCTreeItem *item = [self _treeItemToMuteForMenuItem:sender];

	if (item == nil) {
		return;
	}

	IRCClient *client = item.associatedClient;

	[client setMuted:([client isTreeItemMuted:item] == NO) forTreeItem:item];
}

@end

NS_ASSUME_NONNULL_END
