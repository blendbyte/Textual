/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
 *      Please see Acknowledgements.pdf for additional information.
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

#import <objc/message.h>
#import "NSObjectHelperPrivate.h"
#import "NSStringHelper.h"
#import "TPCApplicationInfo.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCResourceManager.h"
#import "TPCThemeController.h"
#import "TPCTheme.h"
#import "THOPluginDispatcherPrivate.h"
#import "THOPluginManagerPrivate.h"
#import "THOPluginProtocol.h"
#import "TLOFileLoggerPrivate.h"
#import "TLOInputHistoryPrivate.h"
#import "TLOLocalization.h"
#import "TLONotificationControllerPrivate.h"
#import "TLOpenLink.h"
#import "TLOSoundPlayer.h"
#import "TLOSpeechSynthesizerPrivate.h"
#import "TLOSpokenNotificationPrivate.h"
#import "TLOTimer.h"
#import "TXGlobalModelsPrivate.h"
#import "TXMasterControllerPrivate.h"
#import "TXMenuControllerPrivate.h"
#import "TXWindowControllerPrivate.h"
#import "TVCDockIconPrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogControllerInlineMediaServicePrivate.h"
#import "TVCLogControllerOperationQueuePrivate.h"
#import "TVCLogRenderer.h"
#import "TVCLogViewPrivate.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowTextViewPrivate.h"
#import "TVCServerListPrivate.h"
#import "TDCAlert.h"
#import "TDCChannelBanListSheetPrivate.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCFileTransferDialogTransferControllerPrivate.h"
#import "TDCServerChannelListDialogPrivate.h"
#import "TDCServerHighlightListSheetPrivate.h"
#import "IRC.h"
#import "IRCAddressBook.h"
#import "IRCAddressBookMatchCachePrivate.h"
#import "IRCAddressBookUserTrackingPrivate.h"
#import "IRCChannelConfig.h"
#import "IRCChannelModePrivate.h"
#import "IRCChannelUserPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCClientConfigPrivate.h"
#import "IRCClientRequestedCommandsPrivate.h"
#import "IRCColorFormatPrivate.h"
#import "IRCConnectionPrivate.h"
#import "IRCConnectionConfig.h"
#import "IRCConnectionErrors.h"
#import "IRCExtrasPrivate.h"
#import "IRCHighlightLogEntryPrivate.h"
#import "IRCHighlightMatchCondition.h"
#import "IRCISupportInfoPrivate.h"
#import "IRCMessagePrivate.h"
#import "IRCMessageBatchPrivate.h"
#import "IRCModeInfo.h"
#import "IRCPrefix.h"
#import "IRCNumerics.h"
#import "IRCSendingMessage.h"
#import "IRCServerPrivate.h"
#import "IRCTimedCommandPrivate.h"
#import "IRCTreeItemPrivate.h"
#import "IRCUserPrivate.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCWorldPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

/* The input of a local command, handed to its handler */
@interface IRCLocalCommandContext : NSObject
@property (nonatomic, strong) NSMutableAttributedString *stringIn;
@property (nonatomic, copy) NSString *command;
@property (nonatomic, copy) NSString *lowercaseCommand;
@property (nonatomic, copy) NSString *uppercaseCommand;
@property (nonatomic, assign) NSInteger commandNumeric;
@property (nonatomic, weak, nullable) IRCClient *selectedClient;
@property (nonatomic, weak, nullable) IRCChannel *selectedChannel;
@property (nonatomic, weak, nullable) IRCChannel *targetChannel;
@end

@implementation IRCLocalCommandContext
@end

@implementation IRCClient (LocalCommands)

#pragma mark -
#pragma mark Send Command

- (void)sendCommand:(id)string
{
	[self sendCommand:string completeTarget:YES target:nil];
}

- (void)sendCommand:(id)string completeTarget:(BOOL)completeTarget target:(nullable NSString *)targetChannelName
{
	NSParameterAssert(string != nil);

	BOOL inputIsNSString = [string isKindOfClass:[NSString class]];

	if (inputIsNSString == NO && [string isKindOfClass:[NSAttributedString class]] == NO) {
		NSAssert(NO, @"'string' must be NSString or NSAttributedString");
	}

	if ([string length] == 0) {
		return;
	}

	NSMutableAttributedString *stringIn = nil;

	if (inputIsNSString) {
		stringIn = [[NSMutableAttributedString alloc] initWithString:string];
	} else {
		stringIn = [string mutableCopy];
	}

	if ([stringIn.string hasPrefix:@"/"]) {
		[stringIn deleteCharactersInRange:NSMakeRange(0, 1)];
	}

	NSString *command = stringIn.tokenAsString;

	NSString *lowercaseCommand = command.lowercaseString;
	NSString *uppercaseCommand = command.uppercaseString;

	IRCClient *selectedClient = mainWindow().selectedClient;
	IRCChannel *selectedChannel = mainWindow().selectedChannel;

	IRCChannel *targetChannel = nil;

	NSInteger commandNumeric = [IRCCommandIndex indexOfLocalCommand:command];

	if (completeTarget && targetChannelName != nil) {
		targetChannel = [self findChannel:targetChannelName];
	} else if (completeTarget && selectedClient == self && selectedChannel) {
		targetChannel = selectedChannel;
	}

	IRCLocalCommandContext *context = [IRCLocalCommandContext new];

	context.stringIn = stringIn;
	context.command = command;
	context.lowercaseCommand = lowercaseCommand;
	context.uppercaseCommand = uppercaseCommand;
	context.commandNumeric = commandNumeric;
	context.selectedClient = selectedClient;
	context.selectedChannel = selectedChannel;
	context.targetChannel = targetChannel;

	SEL handler = [self.class _handlerForLocalCommand:commandNumeric];

	void (*performHandler)(id, SEL, IRCLocalCommandContext *) = (void *)[self methodForSelector:handler];

	performHandler(self, handler, context);
}

/* The handler of every local command; commands not listed go to
 -_handleUnknownLocalCommand: (a plugin, a script or the server) */
+ (SEL)_handlerForLocalCommand:(NSInteger)command
{
	static NSDictionary<NSNumber *, NSString *> *handlers = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		handlers = @{
			@(IRCLocalCommandAme) : NSStringFromSelector(@selector(_handleLocalCommandAmsg:)),
			@(IRCLocalCommandAmsg) : NSStringFromSelector(@selector(_handleLocalCommandAmsg:)),
			@(IRCLocalCommandAquote) : NSStringFromSelector(@selector(_handleLocalCommandAraw:)),
			@(IRCLocalCommandAraw) : NSStringFromSelector(@selector(_handleLocalCommandAraw:)),
			@(IRCLocalCommandAutojoin) : NSStringFromSelector(@selector(_handleLocalCommandAutojoin:)),
			@(IRCLocalCommandAway) : NSStringFromSelector(@selector(_handleLocalCommandAway:)),
			@(IRCLocalCommandBack) : NSStringFromSelector(@selector(_handleLocalCommandBack:)),
			@(IRCLocalCommandBan) : NSStringFromSelector(@selector(_handleLocalCommandKickBan:)),
			@(IRCLocalCommandCap) : NSStringFromSelector(@selector(_handleLocalCommandCaps:)),
			@(IRCLocalCommandCaps) : NSStringFromSelector(@selector(_handleLocalCommandCaps:)),
			@(IRCLocalCommandClear) : NSStringFromSelector(@selector(_handleLocalCommandClear:)),
			@(IRCLocalCommandClearall) : NSStringFromSelector(@selector(_handleLocalCommandClearall:)),
			@(IRCLocalCommandClose) : NSStringFromSelector(@selector(_handleLocalCommandClose:)),
			@(IRCLocalCommandConn) : NSStringFromSelector(@selector(_handleLocalCommandConn:)),
			@(IRCLocalCommandCtcp) : NSStringFromSelector(@selector(_handleLocalCommandCtcp:)),
			@(IRCLocalCommandCtcpreply) : NSStringFromSelector(@selector(_handleLocalCommandCtcp:)),
			@(IRCLocalCommandCycle) : NSStringFromSelector(@selector(_handleLocalCommandCycle:)),
			@(IRCLocalCommandDebug) : NSStringFromSelector(@selector(_handleLocalCommandEcho:)),
			@(IRCLocalCommandDefaults) : NSStringFromSelector(@selector(_handleLocalCommandDefaults:)),
			@(IRCLocalCommandDehalfop) : NSStringFromSelector(@selector(_handleLocalCommandOp:)),
			@(IRCLocalCommandDeop) : NSStringFromSelector(@selector(_handleLocalCommandOp:)),
			@(IRCLocalCommandDevoice) : NSStringFromSelector(@selector(_handleLocalCommandOp:)),
			@(IRCLocalCommandEcho) : NSStringFromSelector(@selector(_handleLocalCommandEcho:)),
			@(IRCLocalCommandGline) : NSStringFromSelector(@selector(_handleLocalCommandGline:)),
			@(IRCLocalCommandGoto) : NSStringFromSelector(@selector(_handleLocalCommandGoto:)),
			@(IRCLocalCommandGzline) : NSStringFromSelector(@selector(_handleLocalCommandGline:)),
			@(IRCLocalCommandHalfop) : NSStringFromSelector(@selector(_handleLocalCommandOp:)),
			@(IRCLocalCommandHop) : NSStringFromSelector(@selector(_handleLocalCommandCycle:)),
			@(IRCLocalCommandIgnore) : NSStringFromSelector(@selector(_handleLocalCommandIgnore:)),
			@(IRCLocalCommandInvite) : NSStringFromSelector(@selector(_handleLocalCommandInvite:)),
			@(IRCLocalCommandIson) : NSStringFromSelector(@selector(_handleLocalCommandIson:)),
			@(IRCLocalCommandJ) : NSStringFromSelector(@selector(_handleLocalCommandJoin:)),
			@(IRCLocalCommandJoin) : NSStringFromSelector(@selector(_handleLocalCommandJoin:)),
			@(IRCLocalCommandJoinRandom) : NSStringFromSelector(@selector(_handleLocalCommandJoinRandom:)),
			@(IRCLocalCommandKb) : NSStringFromSelector(@selector(_handleLocalCommandKickBan:)),
			@(IRCLocalCommandKick) : NSStringFromSelector(@selector(_handleLocalCommandKickBan:)),
			@(IRCLocalCommandKickban) : NSStringFromSelector(@selector(_handleLocalCommandKickBan:)),
			@(IRCLocalCommandKill) : NSStringFromSelector(@selector(_handleLocalCommandKill:)),
			@(IRCLocalCommandLagcheck) : NSStringFromSelector(@selector(_handleLocalCommandLagcheck:)),
			@(IRCLocalCommandLeave) : NSStringFromSelector(@selector(_handleLocalCommandPart:)),
			@(IRCLocalCommandList) : NSStringFromSelector(@selector(_handleLocalCommandList:)),
			@(IRCLocalCommandM) : NSStringFromSelector(@selector(_handleLocalCommandMode:)),
			@(IRCLocalCommandMe) : NSStringFromSelector(@selector(_handleLocalCommandMessage:)),
			@(IRCLocalCommandMode) : NSStringFromSelector(@selector(_handleLocalCommandMode:)),
			@(IRCLocalCommandMonitor) : NSStringFromSelector(@selector(_handleLocalCommandWatch:)),
			@(IRCLocalCommandMsg) : NSStringFromSelector(@selector(_handleLocalCommandMessage:)),
			@(IRCLocalCommandMute) : NSStringFromSelector(@selector(_handleLocalCommandMute:)),
			@(IRCLocalCommandMylag) : NSStringFromSelector(@selector(_handleLocalCommandLagcheck:)),
			@(IRCLocalCommandMyversion) : NSStringFromSelector(@selector(_handleLocalCommandMyversion:)),
			@(IRCLocalCommandNames) : NSStringFromSelector(@selector(_handleLocalCommandNames:)),
			@(IRCLocalCommandNick) : NSStringFromSelector(@selector(_handleLocalCommandNick:)),
			@(IRCLocalCommandNotice) : NSStringFromSelector(@selector(_handleLocalCommandMessage:)),
			@(IRCLocalCommandNotifybubble) : NSStringFromSelector(@selector(_handleLocalCommandNotifybubble:)),
			@(IRCLocalCommandNotifysound) : NSStringFromSelector(@selector(_handleLocalCommandNotifysound:)),
			@(IRCLocalCommandNotifyspeak) : NSStringFromSelector(@selector(_handleLocalCommandNotifyspeak:)),
			@(IRCLocalCommandOmsg) : NSStringFromSelector(@selector(_handleLocalCommandMessage:)),
			@(IRCLocalCommandOnotice) : NSStringFromSelector(@selector(_handleLocalCommandMessage:)),
			@(IRCLocalCommandOp) : NSStringFromSelector(@selector(_handleLocalCommandOp:)),
			@(IRCLocalCommandPart) : NSStringFromSelector(@selector(_handleLocalCommandPart:)),
			@(IRCLocalCommandQuery) : NSStringFromSelector(@selector(_handleLocalCommandQuery:)),
			@(IRCLocalCommandQuiet) : NSStringFromSelector(@selector(_handleLocalCommandKickBan:)),
			@(IRCLocalCommandQuit) : NSStringFromSelector(@selector(_handleLocalCommandQuit:)),
			@(IRCLocalCommandQuote) : NSStringFromSelector(@selector(_handleLocalCommandRaw:)),
			@(IRCLocalCommandRaw) : NSStringFromSelector(@selector(_handleLocalCommandRaw:)),
			@(IRCLocalCommandRecv) : NSStringFromSelector(@selector(_handleLocalCommandRecv:)),
			@(IRCLocalCommandRejoin) : NSStringFromSelector(@selector(_handleLocalCommandCycle:)),
			@(IRCLocalCommandRemove) : NSStringFromSelector(@selector(_handleLocalCommandClose:)),
			@(IRCLocalCommandServer) : NSStringFromSelector(@selector(_handleLocalCommandServer:)),
			@(IRCLocalCommandSetcolor) : NSStringFromSelector(@selector(_handleLocalCommandSetcolor:)),
			@(IRCLocalCommandSetqueryname) : NSStringFromSelector(@selector(_handleLocalCommandSetqueryname:)),
			@(IRCLocalCommandShun) : NSStringFromSelector(@selector(_handleLocalCommandGline:)),
			@(IRCLocalCommandSme) : NSStringFromSelector(@selector(_handleLocalCommandMessage:)),
			@(IRCLocalCommandSmsg) : NSStringFromSelector(@selector(_handleLocalCommandMessage:)),
			@(IRCLocalCommandSslcontext) : NSStringFromSelector(@selector(_handleLocalCommandSslcontext:)),
			@(IRCLocalCommandT) : NSStringFromSelector(@selector(_handleLocalCommandTopic:)),
			@(IRCLocalCommandTage) : NSStringFromSelector(@selector(_handleLocalCommandTage:)),
			@(IRCLocalCommandTempshun) : NSStringFromSelector(@selector(_handleLocalCommandGline:)),
			@(IRCLocalCommandTimer) : NSStringFromSelector(@selector(_handleLocalCommandTimer:)),
			@(IRCLocalCommandTopic) : NSStringFromSelector(@selector(_handleLocalCommandTopic:)),
			@(IRCLocalCommandUmode) : NSStringFromSelector(@selector(_handleLocalCommandUmode:)),
			@(IRCLocalCommandUnban) : NSStringFromSelector(@selector(_handleLocalCommandKickBan:)),
			@(IRCLocalCommandUnignore) : NSStringFromSelector(@selector(_handleLocalCommandIgnore:)),
			@(IRCLocalCommandUnmute) : NSStringFromSelector(@selector(_handleLocalCommandUnmute:)),
			@(IRCLocalCommandUnquiet) : NSStringFromSelector(@selector(_handleLocalCommandKickBan:)),
			@(IRCLocalCommandVoice) : NSStringFromSelector(@selector(_handleLocalCommandOp:)),
			@(IRCLocalCommandWallops) : NSStringFromSelector(@selector(_handleLocalCommandWallops:)),
			@(IRCLocalCommandWatch) : NSStringFromSelector(@selector(_handleLocalCommandWatch:)),
			@(IRCLocalCommandWeights) : NSStringFromSelector(@selector(_handleLocalCommandWeights:)),
			@(IRCLocalCommandWho) : NSStringFromSelector(@selector(_handleLocalCommandWho:)),
			@(IRCLocalCommandWhois) : NSStringFromSelector(@selector(_handleLocalCommandWhois:)),
			@(IRCLocalCommandZline) : NSStringFromSelector(@selector(_handleLocalCommandGline:))
		};
	});

	NSString *handler = handlers[@(command)];

	if (handler == nil) {
		return @selector(_handleUnknownLocalCommand:);
	}

	return NSSelectorFromString(handler);
}

#pragma mark -
#pragma mark Local Command Handlers

/* AME / AMSG */
- (void)_handleLocalCommandAmsg:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;
	NSInteger commandNumeric = context.commandNumeric;

	NSAssertReturn(self.isLoggedIn);

	if (stringIn.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	IRCRemoteCommand sendAsCommand = 0;

	if (commandNumeric == IRCLocalCommandAmsg) {
		sendAsCommand = IRCRemoteCommandPrivmsg;
	} else {
		sendAsCommand = IRCRemoteCommandPrivmsgAction;
	}

	for (IRCClient *client in worldController().clientList) {
		if (client != self && [TPCPreferences amsgAllConnections] == NO) {
			continue;
		}

		for (IRCChannel *channel in client.channelList) {
			if (channel.isActive == NO || channel.isChannel == NO) {
				continue;
			}

			[client sendText:stringIn asCommand:sendAsCommand toChannel:channel];
		}
	}
}

/* AQUOTE / ARAW */
- (void)_handleLocalCommandAraw:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;

	NSAssertReturn(self.isConnected);

	if (stringIn.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	for (IRCClient *client in worldController().clientList) {
		[client sendLine:stringIn.string];
	}
}

/* AUTOJOIN */
- (void)_handleLocalCommandAutojoin:(IRCLocalCommandContext *)context
{
	NSAssertReturn(self.isLoggedIn);

	[self performAutoJoinInitiatedByUser:YES];
}

/* AWAY */
- (void)_handleLocalCommandAway:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;

	NSAssertReturn(self.isLoggedIn);

	for (IRCClient *client in worldController().clientList) {
		if (client != self && [TPCPreferences awayAllConnections] == NO) {
			continue;
		}

		NSString *comment = stringIn.string;

		/* We enforce the maximum away length here instead of
		 -toggleAwayStatusWithComment: so that we have an easier
		 way to know when it is truncated so the user can be informed. */
		NSUInteger commentMaximumLength = client.supportInfo.maximumAwayLength;

		if (commentMaximumLength > 0 && comment.length > commentMaximumLength) {
			[client printDebugInformation:TXTLS(@"IRC[41y-p2]", client.networkNameAlt, commentMaximumLength)];
		}

		[client toggleAwayStatusWithComment:comment];
	}
}

/* BACK */
- (void)_handleLocalCommandBack:(IRCLocalCommandContext *)context
{
	NSAssertReturn(self.isLoggedIn);

	for (IRCClient *client in worldController().clientList) {
		if (client != self && [TPCPreferences awayAllConnections] == NO) {
			continue;
		}

		[client toggleAwayStatus:NO withComment:nil];
	}
}

/* CAP / CAPS */
- (void)_handleLocalCommandCaps:(IRCLocalCommandContext *)context
{
	NSString *capabilities = self.enabledCapabilitiesStringValue;

	if (capabilities.length == 0) {
		[self printDebugInformation:TXTLS(@"IRC[5wa-lb]")];
	} else {
		[self printDebugInformation:TXTLS(@"IRC[7p9-rs]", capabilities)];
	}
}

/* CLEAR */
- (void)_handleLocalCommandClear:(IRCLocalCommandContext *)context
{
	IRCChannel *targetChannel = context.targetChannel;

	if (targetChannel) {
		[mainWindow() clearContentsOfChannel:targetChannel];
	} else {
		[mainWindow() clearContentsOfClient:self];
	}
}

/* CLEARALL */
- (void)_handleLocalCommandClearall:(IRCLocalCommandContext *)context
{
	for (IRCClient *client in worldController().clientList) {
		if (client != self && [TPCPreferences clearAllConnections] == NO) {
			continue;
		}

		[mainWindow() clearContentsOfClient:client];

		for (IRCChannel *channel in client.channelList) {
			[mainWindow() clearContentsOfChannel:channel];
		}
	}
}

/* CLOSE / REMOVE */
- (void)_handleLocalCommandClose:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	IRCChannel *targetChannel = context.targetChannel;

	NSString *channelName = stringIn.tokenAsString;
	
	if (channelName.length == 0) {
		if (targetChannel) {
			[worldController() destroyChannel:targetChannel];
		}

		return;
	}

	IRCChannel *channel = [self findChannel:channelName];

	if (channel == nil) {
		[self printDebugInformation:TXTLS(@"IRC[pxa-ox]", channelName)];
		
		return;
	}
	
	[worldController() destroyChannel:channel];
}

/* CONN */
- (void)_handleLocalCommandConn:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;

	NSString *serverAddress = stringIn.lowercaseGetToken;

	if (serverAddress.length > 0) {
		if (serverAddress.isValidInternetAddress == NO) {
			[self printDebugInformation:TXTLS(@"IRC[zef-q9]")];
			
			return;
		}

		/* Another host on the same port and with the same TLS setting as the
		 configured server; never plaintext if the current connection is secured. */
		IRCServer *currentServer = self.server;

		if (currentServer == nil) {
			currentServer = self.config.serverList.firstObject;
		}

		self.temporaryServerAddressOverride = serverAddress;
		self.temporaryServerPortOverride = currentServer.serverPort;
		self.temporaryServerPrefersSecuredConnection = (currentServer.prefersSecuredConnection || self.socket.isSecured);
	}

	if (self.isConnecting || self.isConnected) {
		__weak IRCClient *weakSelf = self;

		self.disconnectCallback = ^{
			[weakSelf connect];
		};

		[self quit];

		return;
	}

	[self connect];
}

/* CTCP / CTCPREPLY */
- (void)_handleLocalCommandCtcp:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;
	NSInteger commandNumeric = context.commandNumeric;
	IRCChannel *selectedChannel = context.selectedChannel;
	IRCChannel *targetChannel = context.targetChannel;
	NSString *targetChannelName = nil;

	NSAssertReturn(self.isLoggedIn);

	if (targetChannel && targetChannel != selectedChannel) {
		if (targetChannel.isUtility) {
			[self printDebugInformation:TXTLS(@"IRC[sxf-qx]")];

			return;
		}

		targetChannelName = targetChannel.name;
	} else {
		targetChannelName = stringIn.tokenAsString;
	}

	NSString *subCommand = stringIn.uppercaseGetToken;

	if (subCommand.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	if (commandNumeric == IRCLocalCommandCtcp) {
		if ([subCommand isEqualToString:@"PING"]) {
			[self sendCTCPPing:targetChannelName];
		} else {
			[self sendCTCPQuery:targetChannelName command:subCommand text:stringIn.string];
		}
	} else {
		[self sendCTCPReply:targetChannelName command:subCommand text:stringIn.string];
	}
}

/* CYCLE / HOP / REJOIN */
- (void)_handleLocalCommandCycle:(IRCLocalCommandContext *)context
{
	IRCChannel *targetChannel = context.targetChannel;

	NSAssertReturn(self.isLoggedIn);

	if (targetChannel == nil || targetChannel.isChannel == NO) {
		[self printDebugInformation:TXTLS(@"IRC[g01-qn]")];
		
		return;
	}

	[self partChannel:targetChannel];

	[self forceJoinChannel:targetChannel.name password:targetChannel.secretKey];
}

/* DEHALFOP / DEOP / DEVOICE / HALFOP / OP / VOICE */
- (void)_handleLocalCommandOp:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;
	NSInteger commandNumeric = context.commandNumeric;
	IRCChannel *targetChannel = context.targetChannel;
	NSString *targetChannelName = nil;

	NSAssertReturn(self.isLoggedIn);
	
	BOOL modeIsSet = (commandNumeric == IRCLocalCommandOp ||
					  commandNumeric == IRCLocalCommandHalfop ||
					  commandNumeric == IRCLocalCommandVoice);

	NSString *modeSymbol = nil;

	if (commandNumeric == IRCLocalCommandOp || commandNumeric == IRCLocalCommandDeop) {
		modeSymbol = @"o";
	} else if (commandNumeric == IRCLocalCommandHalfop || commandNumeric == IRCLocalCommandDehalfop) {
		modeSymbol = @"h";
	} else { // VOICE, DEVOICE
		modeSymbol = @"v";
	}

	if ([self.supportInfo modeSymbolIsUserPrefix:modeSymbol] == NO) {
		[self printDebugInformation:TXTLS(@"IRC[dwi-d1]", modeSymbol)];

		return;
	}

	if ([self stringIsChannelName:stringIn.string] == NO) {
		if (targetChannel && targetChannel.isChannel) {
			targetChannelName = targetChannel.name;
		} else {
			[self printDebugInformation:TXTLS(@"IRC[g01-qn]")];
			
			return;
		}
	} else {
		targetChannelName = stringIn.tokenAsString;
	}
	
	NSString *nicknamesString = stringIn.string;

	if (nicknamesString.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	NSArray *modeChanges =
	[self compileListOfModeChangesForModeSymbol:modeSymbol
									  modeIsSet:modeIsSet
								parameterString:nicknamesString];

	for (NSString *modeChange in modeChanges) {
		[self send:@"MODE", targetChannelName, modeChange, nil];
	}
}

/* DEBUG / ECHO */
- (void)_handleLocalCommandEcho:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;

	if (stringIn.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}
	
	NSString *stringInString = stringIn.string;

	if ([stringInString isEqualToStringIgnoringCase:@"raw on"])
	{
		[self createRawDataLogQuery];
	}
	else if ([stringInString isEqualToStringIgnoringCase:@"raw off"])
	{
		[self destroyRawDataLogQuery];
	}
	else
	{
		[self printDebugInformation:stringInString];
	}
}

/* DEFAULTS */
- (void)_handleLocalCommandDefaults:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;

	if (stringIn.length == 0) {
		[self printDebugInformation:TXTLS(@"IRC[1dz-jb]")];

		return;
	}

	NSString *action = stringIn.tokenAsString;

	/* Present help */
	if ([action isEqualToString:@"help"])
	{
		NSString *help = TXTLS(@"IRC[bkk-lo]");

		[self printDebugInformationMultiline:help];

		return;
	}

	/* Present list of features */
	else if ([action isEqualToString:@"features"])
	{
		[TLOpenLink openWithString:@"https://help.codeux.com/textual/Command-Reference.kb#cr=defaults" inBackground:NO];

		return;
	}

	/* Prepare to toggle feature */
	NSString *feature = stringIn.tokenInsideQuotes.string;

	BOOL applyToAll = [feature isEqualToString:@"-a"];

	if (applyToAll) {
		feature = stringIn.tokenInsideQuotes.string;
	}

	NSDictionary *features = @{
		@"Ignore Notifications by Private ZNC Users"		: @"setZncIgnoreUserNotifications:",
		@"Send Authentication Requests to UserServ"			: @"setSendAuthenticationRequestsToUserServ:",
		@"Disable Automatic SASL EXTERNAL Response"			: @"setSaslAuthenticationDisableExternalMechanism:",
		@"Send WHO Command Requests to Channels"			: @"setSendWhoCommandRequestsToChannels:",
	};

	BOOL enableFeature = [action isEqualToString:@"enable"];

	/* Cannot toggle feature if the user doesn't tell us which */
	if (feature.length == 0) {
		[self printDebugInformation:TXTLS(@"IRC[1dz-jb]")];

		return;
	}

	/* Make sure the feature exists */
	if ([features containsKey:feature] == NO) {
		if (enableFeature) {
			[self printDebugInformation:TXTLS(@"IRC[pc4-67]", feature)];
		} else {
			[self printDebugInformation:TXTLS(@"IRC[d7y-pv]", feature)];
		}

		return;
	}

	/* Toggle the feature by mutating the client's configuration,
	 invoking the appropriate method, then saving it. */
	void (^toggleFeature)(IRCClient *, NSString *, BOOL) = ^(IRCClient *client, NSString *featureKey, BOOL featureValue) {
		NSString *selectorString = features[featureKey];

		SEL selector = NSSelectorFromString(selectorString);

		IRCClientConfigMutable *mutableClientConfig = [client.config mutableCopy];

		NSMethodSignature *signature = [mutableClientConfig methodSignatureForSelector:selector];

		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

		[invocation setTarget:mutableClientConfig];
		[invocation setSelector:selector];

		[invocation setArgument:&featureValue atIndex:2];

		[invocation invoke];

		client.config = mutableClientConfig;
	};

	/* Toggle feature */
	for (IRCClient *client in worldController().clientList) {
		if (client != self && applyToAll == NO) {
			continue;
		}

		toggleFeature(client, feature, enableFeature);

		if (enableFeature) {
			[client printDebugInformation:TXTLS(@"IRC[5ke-18]", feature)];
		} else {
			[client printDebugInformation:TXTLS(@"IRC[0gn-cb]", feature)];
		}
	}

	/* Save modified client */
	[worldController() save];
}

/* GLINE / GZLINE / SHUN / TEMPSHUN / ZLINE */
- (void)_handleLocalCommandGline:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *uppercaseCommand = context.uppercaseCommand;

	NSAssertReturn(self.isLoggedIn);

	NSString *segment1 = stringIn.getTokenAsString;
	NSString *segment2 = stringIn.getTokenAsString;

	[self send:uppercaseCommand, segment1, segment2, stringIn.string, nil];
}

/* GOTO */
- (void)_handleLocalCommandGoto:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;

	if (stringIn.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	NSString *needle = stringIn.tokenAsString;

	IRCTreeItem *bestMatch = mainWindow().selectedItem;

	CGFloat bestScore = 0.0;

	for (IRCClient *client in worldController().clientList) {
		for (IRCChannel *channel in client.channelList) {
			CGFloat currentScore = [channel.name compareWithWord:needle lengthPenaltyWeight:0.1];

			if (currentScore > bestScore) {
				bestMatch = channel;

				bestScore = currentScore;
			}
		}
	}

	[mainWindow() select:bestMatch];
}

/* IGNORE / UNIGNORE */
- (void)_handleLocalCommandIgnore:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSInteger commandNumeric = context.commandNumeric;
	IRCChannel *targetChannel = context.targetChannel;

	BOOL isIgnoreCommand = (commandNumeric == IRCLocalCommandIgnore);

	if (stringIn.length == 0 || targetChannel == nil) {
		if (isIgnoreCommand) {
			[menuController() showServerPropertiesSheetForClient:self withSelection:TDCServerPropertiesSheetSelectionNewIgnoreEntry context:@""];
		} else {
			[menuController() showServerPropertiesSheetForClient:self withSelection:TDCServerPropertiesSheetSelectionAddressBook context:nil];
		}

		return;
	}

	NSString *nickname = stringIn.tokenAsString;

	IRCUser *member = [self findUser:nickname];

	if (member == nil) {
		if (isIgnoreCommand) {
			[menuController() showServerPropertiesSheetForClient:self withSelection:TDCServerPropertiesSheetSelectionNewIgnoreEntry context:nickname];
		} else {
			[menuController() showServerPropertiesSheetForClient:self withSelection:TDCServerPropertiesSheetSelectionAddressBook context:nil];
		}

		return;
	}

	/* Build list of ignores that already match the user's host */
	NSString *hostmask = member.hostmask;

	if (hostmask == nil) {
		hostmask = [NSString stringWithFormat:@"%@!*@*", nickname];
	}

	NSMutableArray *matchedIgnores = [NSMutableArray array];

	for (IRCAddressBookEntry *ignore in self.config.ignoreList) {
		if (ignore.entryType != IRCAddressBookEntryTypeIgnore) {
			continue;
		}

		if ([ignore checkMatch:hostmask]) {
			[matchedIgnores addObject:ignore];
		}
	}

	/* Cancel if there is nothing to change */
	if (isIgnoreCommand) {
		if (matchedIgnores.count > 0) {
			[self printDebugInformation:TXTLS(@"IRC[5ix-zn]", member.nickname)];

			return;
		}
	} else {
		if (matchedIgnores.count == 0) {
			[self printDebugInformation:TXTLS(@"IRC[wu0-jp]", member.nickname)];

			return;
		} else if (matchedIgnores.count > 1) {
			[self printDebugInformation:TXTLS(@"IRC[vrx-1f]", member.nickname)];
			
			return;
		}
	}

	/* Modify ignore list and inform user of change */
	NSMutableArray *mutableIgnoreList = [self.config.ignoreList mutableCopy];

	if (isIgnoreCommand) {
		IRCAddressBookEntry *ignore =
		[IRCAddressBookEntry newIgnoreEntryForHostmask:member.banMask];

		[self printDebugInformation:TXTLS(@"IRC[ret-20]", member.nickname, ignore.hostmask)];

		[mutableIgnoreList addObject:ignore];
	} else{
		IRCAddressBookEntry *ignore = matchedIgnores[0];
		
		[self printDebugInformation:TXTLS(@"IRC[jzg-g8]", member.nickname, ignore.hostmask)];

		[mutableIgnoreList removeObjectIdenticalTo:ignore];
	}

	/* Save modified ignore list */
	IRCClientConfigMutable *mutableClientConfig = [self.config mutableCopy];

	mutableClientConfig.ignoreList = mutableIgnoreList;

	self.config = mutableClientConfig;
	
	/* Clear cache */
	/* If we have a host, then it's easy to clear only that.
	 If we don't have a host, then we have to clear everything. */
	if (hostmask) {
		[self clearAddressBookCacheForHostmask:hostmask];
	} else {
		[self clearAddressBookCache];
	}
}

/* INVITE */
- (void)_handleLocalCommandInvite:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;
	IRCChannel *targetChannel = context.targetChannel;
	NSString *targetChannelName = nil;

	NSAssertReturn(self.isLoggedIn);

	if (stringIn.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	NSArray *nicknames = [stringIn.string componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

	if ([self stringIsChannelName:nicknames.lastObject] == NO) {
		if (targetChannel && targetChannel.isChannel) {
			targetChannelName = targetChannel.name;
		} else {
			[self printDebugInformation:TXTLS(@"IRC[g01-qn]")];
			
			return;
		}
	} else {
		targetChannelName = nicknames.lastObject;
		
		nicknames = [nicknames subarrayWithRange:NSMakeRange(0, (nicknames.count - 1))];
	}

	for (NSString *nickname in nicknames) {
		if ([self stringIsNickname:nickname] == NO) {
			continue;
		}

		[self send:@"INVITE", nickname, targetChannelName, nil];
	}
}

/* ISON */
- (void)_handleLocalCommandIson:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;

	NSAssertReturn(self.isLoggedIn);

	if (stringIn.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	[self createHiddenCommandResponses];

	[self.requestedCommands recordIsonRequestOpenedAsVisible];

	[self send:@"ISON", stringIn.string, nil];
}

/* J / JOIN */
- (void)_handleLocalCommandJoin:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;
	IRCChannel *targetChannel = context.targetChannel;
	NSString *targetChannelName = nil;

	NSAssertReturn(self.isLoggedIn);

	if (stringIn.length == 0) {
		if (targetChannel && targetChannel.isChannel) {
			targetChannelName = targetChannel.name;
		} else {
			[self printDebugInformation:TXTLS(@"IRC[g01-qn]")];
			
			return;
		}
	} else {
		targetChannelName = stringIn.tokenAsString;

		if (targetChannelName.length == 0) {
			[self printInvalidSyntaxMessageForCommand:command];

			return;
		}

		if ([self stringIsChannelNameOrZero:targetChannelName] == NO) {
			targetChannelName = [@"#" stringByAppendingString:targetChannelName];
		}
	}

	[self joinUnlistedChannelsWithStringAndSelectBestMatch:targetChannelName passwords:stringIn.string];
}

/* JOIN_RANDOM */
- (void)_handleLocalCommandJoinRandom:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;

	NSAssertReturn(self.isLoggedIn);

	NSInteger numberOfChannelsToJoin = 0;

	NSString *numberOfChannelsToken = stringIn.tokenAsString;

	if (numberOfChannelsToken.isNumericOnly) {
		numberOfChannelsToJoin = numberOfChannelsToken.integerValue;
	}

	if (numberOfChannelsToJoin <= 0) {
		numberOfChannelsToJoin = 1;
	}

	for (NSUInteger i = 0; i < numberOfChannelsToJoin; i++) {
		NSString *channelName = [NSString stringWithFormat:@"#debug-channel-%lu", TXRandomNumber(9999999)];

		[self send:@"JOIN", channelName, nil];
	}
}

/* BAN / KB / KICK / KICKBAN / UNBAN / UNQUIET / QUIET */
- (void)_handleLocalCommandKickBan:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;
	NSInteger commandNumeric = context.commandNumeric;
	IRCChannel *targetChannel = context.targetChannel;
	NSString *targetChannelName = nil;

	NSAssertReturn(self.isLoggedIn);

	NSString *nickname = stringIn.tokenAsString;

	if ([self stringIsChannelName:nickname] == NO) {
		if (targetChannel && targetChannel.isChannel) {
			targetChannelName = targetChannel.name;
		} else {
			[self printDebugInformation:TXTLS(@"IRC[g01-qn]")];
			
			return;
		}
	} else {
		targetChannelName = nickname;

		targetChannel = [self findChannel:targetChannelName];
		
		nickname = stringIn.tokenAsString;
	}

	if (nickname.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
			
		return;
	}

	if (commandNumeric == IRCLocalCommandKickban ||
		commandNumeric == IRCLocalCommandKb ||
		commandNumeric == IRCLocalCommandBan ||
		commandNumeric == IRCLocalCommandUnban ||
		commandNumeric == IRCLocalCommandQuiet ||
		commandNumeric == IRCLocalCommandUnquiet)
	{
		IRCChannelUser *member = [targetChannel findMember:nickname];

		NSString *banMask = member.user.banMask;

		if (banMask == nil) {
			banMask = nickname;
		}

		NSString *modeSymbol = nil;

		if (commandNumeric == IRCLocalCommandQuiet ||
			commandNumeric == IRCLocalCommandUnquiet)
		{
			modeSymbol = @"q";
		} else {
			modeSymbol = @"b";
		}

		if ([self.supportInfo modeSymbolIsUserPrefix:modeSymbol]) {
			[self printDebugInformation:TXTLS(@"IRC[dwi-d1]", modeSymbol)];

			return;
		}

		if (commandNumeric == IRCLocalCommandUnban ||
			commandNumeric == IRCLocalCommandUnquiet)
		{
			[self send:@"MODE", targetChannelName, [@"-" stringByAppendingString:modeSymbol], banMask, nil];
		} else {
			[self send:@"MODE", targetChannelName, [@"+" stringByAppendingString:modeSymbol], banMask, nil];
		}
	}

	if (commandNumeric == IRCLocalCommandKb ||
		commandNumeric == IRCLocalCommandKick ||
		commandNumeric == IRCLocalCommandKickban)
	{
		NSString *reason = stringIn.string;

		if (reason.length == 0) {
			reason = [TPCPreferences defaultKickMessage];
		}

		NSUInteger reasonMaximumLength = self.supportInfo.maximumKickLength;

		if (reasonMaximumLength > 0 && reason.length > reasonMaximumLength) {
			[self printDebugInformation:TXTLS(@"IRC[59a-ir]", self.networkNameAlt, reasonMaximumLength)];
		}

		[self send:@"KICK", targetChannelName, nickname, reason, nil];
	}
}

/* KILL */
- (void)_handleLocalCommandKill:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;

	NSAssertReturn(self.isLoggedIn);

	NSString *nickname = stringIn.getTokenAsString;

	if (nickname.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	NSString *reason = stringIn.string;

	if (reason.length == 0) {
		reason = [TPCPreferences IRCopDefaultKillMessage];
	}

	[self send:@"KILL", nickname, reason, nil];
}

/* LAGCHECK / MYLAG */
- (void)_handleLocalCommandLagcheck:(IRCLocalCommandContext *)context
{
	NSInteger commandNumeric = context.commandNumeric;

	NSAssertReturn(self.isLoggedIn);

	/* We only accept LAGCHECK CTCP responses from ourselves which
	 means it is relatively safe to pack some data on the end of
	 the CTCP so that we can provide ourselves some context. */
	NSMutableDictionary *lagCheckContext = [NSMutableDictionary dictionaryWithCapacity:3];

	lagCheckContext[@"connection"] = self.socket.uniqueIdentifier;
	
	lagCheckContext[@"time"] = @([NSDate timeIntervalSince1970]);

	if (commandNumeric == IRCLocalCommandMylag) {
		IRCChannel *selectedChannel = [mainWindow() selectedChannelOn:self];
		
		if (selectedChannel) {
			lagCheckContext[@"channel"] = selectedChannel.name;
		}
	}
	
	NSString *ctcpContext = [lagCheckContext formDataUsingSeparator:@"&"];

	[self sendCTCPQuery:self.userNickname
				command:@"LAGCHECK"
				   text:ctcpContext];

	[self printDebugInformation:TXTLS(@"IRC[qoh-kt]")];
}

/* LEAVE / PART */
- (void)_handleLocalCommandPart:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	IRCChannel *targetChannel = context.targetChannel;
	NSString *targetChannelName = nil;

	NSAssertReturn(self.isLoggedIn);

	if ([self stringIsChannelName:stringIn.string] == NO) {
		if (targetChannel && targetChannel.isChannel) {
			targetChannelName = targetChannel.name;
		} else if (targetChannel) {
			[worldController() destroyChannel:targetChannel];

			return;
		} else {
			return;
		}
	} else {
		targetChannelName = stringIn.tokenAsString;
	}
	
	NSString *reason = stringIn.string;

	if (reason.length == 0) {
		reason = self.config.normalLeavingComment;
	}

	[self send:@"PART", targetChannelName, reason, nil];
}

/* LIST */
- (void)_handleLocalCommandList:(IRCLocalCommandContext *)context
{
	NSAssertReturn(self.isLoggedIn);

	TDCServerChannelListDialog *channelListDialog = [self channelListDialog];

	if (channelListDialog == nil) {
		[self createChannelListDialog];
	}

	[self requestChannelList];
}

/* M / MODE */
- (void)_handleLocalCommandMode:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;
	IRCChannel *targetChannel = context.targetChannel;
	NSString *targetChannelName = nil;

	NSAssertReturn(self.isLoggedIn);

	NSString *modeString = stringIn.string;

	if (  modeString.length == 0 ||
		([modeString hasPrefix:@"+"] ||
		 [modeString hasPrefix:@"-"]))
	{
		if (targetChannel && targetChannel.isChannel) {
			targetChannelName = targetChannel.name;
		} else {
			[self printInvalidSyntaxMessageForCommand:command];
			
			return;
		}
	} else {
		targetChannelName = stringIn.tokenAsString;
	}

	if (modeString.length == 0) {
		[self send:@"MODE", targetChannelName, nil];
	} else {
		[self send:@"MODE", targetChannelName, modeString, nil];
	}
}

/* MUTE */
- (void)_handleLocalCommandMute:(IRCLocalCommandContext *)context
{
	if ([TPCPreferences soundIsMuted]) {
		[self printDebugInformation:TXTLS(@"IRC[sdn-yr]")];
	} else {
		[self printDebugInformation:TXTLS(@"IRC[u48-aa]")];

		[menuController() toggleMuteOnNotificationSoundsShortcutOn:YES];
	}
}

/* MYVERSION */
- (void)_handleLocalCommandMyversion:(IRCLocalCommandContext *)context
{
	IRCChannel *targetChannel = context.targetChannel;

	NSString *applicationName = [TPCApplicationInfo applicationNameWithoutVersion];
	NSString *versionLong = [TPCApplicationInfo applicationVersion];
	NSString *versionShort = [TPCApplicationInfo applicationVersionShort];
//			NSString *buildScheme = [TPCApplicationInfo applicationBuildScheme];

	NSString *downloadSource = @""; // Assume standalone by default
	NSString *buildType = @""; // Assume universal binary by default

#if TEXTUAL_BUILT_AS_UNIVERSAL_BINARY == 0
	NSString *hostType = nil;

#if TARGET_CPU_ARM64
	hostType = TXTLS(@"IRC[g1u-os]");
#elif TARGET_CPU_X86_64
	hostType = TXTLS(@"IRC[swz-uj]");
#endif

	buildType = TXTLS(@"IRC[b8p-44]", hostType);
#endif // Universal

	NSString *message = TXTLS(@"IRC[ccb-ur]", applicationName, versionShort, versionLong, downloadSource, buildType);

	if (targetChannel) {
		message = TXTLS(@"IRC[pqj-1y]", message);

		[self sendPrivmsg:message toChannel:targetChannel];
	} else {
		[self printDebugInformationToConsole:message];
	}
}

/* NICK */
- (void)_handleLocalCommandNick:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;

	/* Use -isConnected instead of -isLoggedIn so that
	 user can change their nickname during registration
	 phase before the 001 numeric is received. */
	NSAssertReturn(self.isConnected);
	
	NSString *newNickname = stringIn.tokenAsString;
	
	if (newNickname.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	for (IRCClient *client in worldController().clientList) {
		if (client != self && [TPCPreferences nickAllConnections] == NO) {
			continue;
		}

		[client changeNickname:newNickname];
	}
}

/* NOTIFYBUBBLE */
- (void)_handleLocalCommandNotifybubble:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;
	IRCChannel *targetChannel = nil;

	if ([self stringIsChannelName:stringIn.string]) {
		targetChannel = [self findChannel:stringIn.tokenAsString];
	} else {
		targetChannel = nil;
	}
	
	if (stringIn.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	NSString *title = [TPCApplicationInfo applicationNameWithoutVersion];

	NSString *message = stringIn.string;

	[sharedNotificationController() scheduleNotificationWithTitle:title
														  message:message
													   forChannel:targetChannel
														 onClient:self];
}

/* NOTIFYSOUND */
- (void)_handleLocalCommandNotifysound:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;

	NSString *soundName = stringIn.tokenAsString;
	
	if (soundName.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	[TLOSoundPlayer playAlertSound:soundName];
}

/* NOTIFYSPEAK */
- (void)_handleLocalCommandNotifyspeak:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;

	if (stringIn.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}
	
	[[TXSharedApplication sharedSpeechSynthesizer] speak:stringIn.string];
}

/* QUERY */
- (void)_handleLocalCommandQuery:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;

	NSString *nickname = stringIn.tokenAsString;
	
	if (nickname.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	if ([self stringIsNickname:nickname] == NO) {
		[self printDebugInformation:TXTLS(@"IRC[zef-q9]")];
		
		return;
	}

	IRCChannel *query = [self findChannelOrCreate:nickname isPrivateMessage:YES];

	[mainWindow() select:query];

	if (stringIn.length > 0) {
		[self sendText:stringIn asCommand:IRCRemoteCommandPrivmsg toChannel:query];
	}
}

/* QUOTE / RAW */
- (void)_handleLocalCommandRaw:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;

	NSAssertReturn(self.isConnected);
	
	if (stringIn.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}
	
	[self sendLine:stringIn.string];
}

/* QUIT */
- (void)_handleLocalCommandQuit:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;

	NSAssertReturn(self.isConnected);

	if (stringIn.length == 0) {
		[self quit];
	} else {
		[self quitWithComment:stringIn.string];
	}
}

/* NAMES */
- (void)_handleLocalCommandNames:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;

	NSAssertReturn(self.isLoggedIn);

	if (stringIn.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	[self createHiddenCommandResponses];

	[self send:@"NAMES", stringIn.string, nil];
}

/* RECV */
- (void)_handleLocalCommandRecv:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;

	if (stringIn.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];

		return;
	}

	[self ircConnection:self.socket didReceiveData:stringIn.string];
}

/* SETCOLOR */
- (void)_handleLocalCommandSetcolor:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;

	if ([TPCPreferences disableNicknameColorHashing]) {
		[self printDebugInformation:TXTLS(@"IRC[026-qv]")];

		return;
	}

	NSString *nickname = stringIn.lowercaseGetToken;

	if (nickname.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	if ([self stringIsNickname:nickname] == NO) {
		[self printDebugInformation:TXTLS(@"IRC[8dy-6f]", nickname)];

		return;
	}

	[menuController() memberChangeColor:nickname];
}

/* SETQUERYNAME */
- (void)_handleLocalCommandSetqueryname:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;
	IRCChannel *targetChannel = context.targetChannel;

	if (targetChannel == nil || targetChannel.isPrivateMessage == NO) {
		[self printDebugInformation:TXTLS(@"IRC[m6o-z1]")];

		return;
	}

	NSString *nickname = stringIn.getTokenAsString;

	if (nickname.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];

		return;
	}

	if ([self stringIsNickname:nickname] == NO) {
		[self printDebugInformation:TXTLS(@"IRC[zef-q9]")];

		return;
	}

	IRCChannel *oldQuery = [self findChannel:nickname];

	if (oldQuery) {
		BOOL deleteOldQuery =
		[TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[61s-jc]")
								  title:TXTLS(@"Prompts[d22-76]", oldQuery.name)
						  defaultButton:TXTLS(@"Prompts[mvh-ms]")
						alternateButton:TXTLS(@"Prompts[99q-gg]")];

		if (deleteOldQuery) {
			[worldController() destroyChannel:oldQuery];
		} else {
			return;
		}
	}

	targetChannel.name = nickname;

	[mainWindow() reloadTreeItem:targetChannel];

	[mainWindow() updateTitleFor:targetChannel];
}

/* SERVER */
- (void)_handleLocalCommandServer:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;

	if (stringIn.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	[IRCExtras createConnectionToServer:stringIn.string channelList:nil connectWhenCreated:YES];
}

/* SSLCONTEXT */
- (void)_handleLocalCommandSslcontext:(IRCLocalCommandContext *)context
{
	[self presentCertificateTrustInformation];
}

/* TAGE */
- (void)_handleLocalCommandTage:(IRCLocalCommandContext *)context
{
	IRCChannel *targetChannel = context.targetChannel;

	NSTimeInterval timePassed = [NSDate timeIntervalSinceNow:[TPCApplicationInfo applicationBirthday]];

	NSString *message = TXTLS(@"IRC[v9x-18]", TXHumanReadableTimeInterval(timePassed, NO, 0));

	if (targetChannel) {
		[self sendPrivmsg:message toChannel:targetChannel];
	} else {
		[self printDebugInformationToConsole:message];
	}
}

/* TIMER */
- (void)_handleLocalCommandTimer:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	IRCChannel *targetChannel = context.targetChannel;

	if (stringIn.length == 0) {
		[self printDebugInformation:TXTLS(@"IRC[jj9-94]")];

		return;
	}

	NSString *action = stringIn.tokenAsString;

	/* Present help */
	if ([action isEqualToString:@"help"])
	{
		NSString *topic = stringIn.tokenAsString;

		[self printDebugInformation:TXTLS(@"IRC[aox-zz]")]; // divider

		if ([topic isEqualToStringIgnoringCase:@"add"])
		{
			[self printDebugInformationMultiline:TXTLS(@"IRC[6r0-il]")];
		}
		else if ([topic isEqualToStringIgnoringCase:@"remove"])
		{
			[self printDebugInformationMultiline:TXTLS(@"IRC[i2d-x5]")];
		}
		else if ([topic isEqualToStringIgnoringCase:@"list"])
		{
			[self printDebugInformationMultiline:TXTLS(@"IRC[x1n-ve]")];
		}
		else if ([topic isEqualToStringIgnoringCase:@"stop"])
		{
			[self printDebugInformationMultiline:TXTLS(@"IRC[bx2-n1]")];
		}
		else if ([topic isEqualToStringIgnoringCase:@"restart"])
		{
			[self printDebugInformationMultiline:TXTLS(@"IRC[r27-tv]")];
		}
		else
		{
			[self printDebugInformationMultiline:TXTLS(@"IRC[xkq-rt]")];
		}

		return;
	}

	/* Stop timer */
	if ([action isEqualToString:@"stop"])
	{
		NSString *identifier = stringIn.tokenAsString;

		if (identifier.length == 0) {
			[self printDebugInformation:TXTLS(@"IRC[p6l-o4]")];

			return;
		}

		IRCTimedCommand *timedCommand = [self timedCommandWithIdentifier:identifier];

		if (timedCommand == nil) {
			[self printDebugInformation:TXTLS(@"IRC[vzu-xh]", identifier)];

			return;
		}

		if (timedCommand.timerIsActive == NO) {
			[self printDebugInformation:TXTLS(@"IRC[ax6-n9]", identifier)];

			return;
		}

		[self stopTimedCommand:timedCommand];

		[self printDebugInformation:TXTLS(@"IRC[hs0-up]", identifier)];

		return;
	}

	/* Restart timer */
	if ([action isEqualToString:@"restart"])
	{
		NSString *identifier = stringIn.tokenAsString;

		if (identifier.length == 0) {
			[self printDebugInformation:TXTLS(@"IRC[p6l-o4]")];

			return;
		}

		IRCTimedCommand *timedCommand = [self timedCommandWithIdentifier:identifier];

		if (timedCommand == nil) {
			[self printDebugInformation:TXTLS(@"IRC[vzu-xh]", identifier)];

			return;
		}

		if ([self restartTimedCommand:timedCommand]) {
			[self printDebugInformation:TXTLS(@"IRC[qb7-mi]", identifier)];
		} else {
			[self printDebugInformation:TXTLS(@"IRC[dgp-d4]", identifier)];
		}

		return;
	}

	/* Remove timer */
	if ([action isEqualToString:@"remove"])
	{
		NSString *identifier = stringIn.tokenAsString;

		if (identifier.length == 0) {
			[self printDebugInformation:TXTLS(@"IRC[p6l-o4]")];

			return;
		}

		if ([identifier isEqualToStringIgnoringCase:@"all"]) {
			[self removeTimedCommands];

			[self printDebugInformation:TXTLS(@"IRC[808-bs]")];

			return;
		}

		IRCTimedCommand *timedCommand = [self timedCommandWithIdentifier:identifier];

		if (timedCommand == nil) {
			[self printDebugInformation:TXTLS(@"IRC[vzu-xh]", identifier)];

			return;
		}

		[self removeTimedCommand:timedCommand];

		[self printDebugInformation:TXTLS(@"IRC[p7s-is]", identifier)];

		return;
	}

	/* List timers */
	if ([action isEqualToString:@"list"])
	{
		NSArray *timedCommands = [self listOfTimedCommands];

		NSUInteger numberOfTimers = timedCommands.count;

		if (numberOfTimers == 0) {
			[self printDebugInformation:TXTLS(@"IRC[pqk-5k]")];

			return;
		} else if (numberOfTimers == 1) {
			[self printDebugInformation:TXTLS(@"IRC[6ts-oi]", numberOfTimers)];
		} else {
			[self printDebugInformation:TXTLS(@"IRC[q1m-1e]", numberOfTimers)];
		}

		for (IRCTimedCommand *timedCommand in timedCommands) {
			NSString *description = [self descriptionForTimedCommand:timedCommand];

			[self printDebugInformation:description];
		}

		return;
	}

	/* Add timer */
	/*
	 This command is designed to be backwards compatible.

	 Old syntax:
	 "/timer <seconds> <command>"

	 New syntax:
	 "/timer <seconds> <repeat> <command>"

	 We check the value of the second argument. If it's a number,
	 then we treat it as the new syntax which means that number
	 is the repeat count for the timer.
	 */

	/* Parse interval */
	NSString *intervalString = action;

	if (intervalString.length == 0) {
		[self printDebugInformation:TXTLS(@"IRC[jj9-94]")];

		return;
	}

	NSInteger interval = intervalString.integerValue;

	if (interval <= 0) {
		[self printDebugInformation:TXTLS(@"IRC[327-pv]")];

		return;
	}

	/* Parse repeat count and/or command */
	/*
	 Repeat argument is treated as such:
	   == 0 — repeat and never stop
	   == 1 - perform timer once, do not repeat
	   > 1 — repeat number of times
	 */
	NSString *repeatString = stringIn.tokenAsString;

	NSInteger repeat = NSNotFound;

	NSString *command = stringIn.trimmedString;

	if ([repeatString contentsIsOfType:CSStringTypeAnyNumber])
	{
		/* Contents of second argument is a number,
		 which means we want to treat it as the repeat count. */
		repeat = repeatString.integerValue;
	}
	else
	{
		/* Contents of second argument is NOT a number,
		 which means we need to merge that back with the
		 remainder of the command value. */
		if (command.length == 0) {
			command = repeatString;
		} else {
			command = [repeatString stringByAppendingFormat:@" %@", command];
		}
	}

	/* Perform additional validation */
	if (repeat < 0) {
		[self printDebugInformation:TXTLS(@"IRC[eud-kc]")];

		return;
	}

	if (command.length == 0) {
		[self printDebugInformation:TXTLS(@"IRC[jj9-94]")];

		return;
	}

	/* If we have no repeat value, then treat is one pass. */
	if (repeat == NSNotFound) {
		repeat = 1;
	}

	/* Add timer */
	IRCTimedCommand *timedCommand = nil;

	if (targetChannel == nil) {
		timedCommand = [[IRCTimedCommand alloc] initWithCommand:command onClient:self];
	} else {
		timedCommand = [[IRCTimedCommand alloc] initWithCommand:command onClient:self inChannel:targetChannel];
	}

	[self addTimedCommand:timedCommand];

	[self startTimedCommand:timedCommand interval:interval onRepeat:(repeat != 1) iterations:repeat];
}

/* T / TOPIC */
- (void)_handleLocalCommandTopic:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	IRCChannel *targetChannel = context.targetChannel;
	NSString *targetChannelName = nil;

	NSAssertReturn(self.isLoggedIn);

	if ([self stringIsChannelName:stringIn.string] == NO) {
		if (targetChannel && targetChannel.isChannel) {
			targetChannelName = targetChannel.name;
		} else {
			return;
		}
	} else {
		targetChannelName = stringIn.tokenAsString;
	}

	NSString *topic = stringIn.stringFormattedForIRC;

	NSUInteger topicLength = topic.length;

	if (topicLength == 0) {
		[self send:@"TOPIC", targetChannelName, nil];

		return;
	}

	NSUInteger topicLengthMaximum = self.supportInfo.maximumTopicLength;

	if (topicLengthMaximum > 0 && topicLength > topicLengthMaximum) {
		[self printDebugInformation:TXTLS(@"IRC[1oo-3b]", self.networkNameAlt, topicLengthMaximum)];
	}

	[self send:@"TOPIC", targetChannelName, topic, nil];
}

/* UMODE */
- (void)_handleLocalCommandUmode:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;

	NSAssertReturn(self.isLoggedIn);

	if (stringIn.length == 0) {
		[self send:@"MODE", self.userNickname, nil];
	} else {
		[self send:@"MODE", self.userNickname, stringIn.string, nil];
	}
}

/* UNMUTE */
- (void)_handleLocalCommandUnmute:(IRCLocalCommandContext *)context
{
	if ([TPCPreferences soundIsMuted] == NO) {
		[self printDebugInformation:TXTLS(@"IRC[5rf-mj]")];
	} else {
		[self printDebugInformation:TXTLS(@"IRC[190-f2]")];

		[menuController() toggleMuteOnNotificationSoundsShortcutOn:NO];
	}
}

/* WALLOPS */
- (void)_handleLocalCommandWallops:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;

	NSAssertReturn(self.isLoggedIn);

	if (stringIn.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	[self send:@"WALLOPS", stringIn.string, nil];
}

/* MONITOR / WATCH */
- (void)_handleLocalCommandWatch:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;
	NSString *uppercaseCommand = context.uppercaseCommand;

	NSAssertReturn(self.isLoggedIn);

	if (stringIn.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	BOOL isClearCommand = NO;
	BOOL isModifierCommand = NO;

	/* UnrealIRCd splits arguments using space and loops through all of them
	 which means a modifier or clear command can appear at the same time. */
	NSArray *arguments = [stringIn.string componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

	for (NSString *argument in arguments) {
		if ([argument hasPrefix:@"-"] || [argument hasPrefix:@"+"]) {
			isModifierCommand = YES;

			break;
		} else if ([argument isEqualIgnoringCase:@"c"]) {
			isClearCommand = YES;
		}
	}

	if (isModifierCommand) {
		[self printDebugInformation:TXTLS(@"IRC[khw-4y]")];

		return;
	}

	/* The clear command doesn't produce a result */
	if (isClearCommand == NO) {
		[self createHiddenCommandResponses];
	}

	[self sendCommand:uppercaseCommand withData:stringIn.string];
}

/* WHO */
- (void)_handleLocalCommandWho:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;

	NSAssertReturn(self.isLoggedIn);

	if (stringIn.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];
		
		return;
	}

	[self createHiddenCommandResponses];

	[self.requestedCommands recordWhoRequestOpenedAsVisible];

	[self send:@"WHO", stringIn.string, nil];
}

/* WEIGHTS */
- (void)_handleLocalCommandWeights:(IRCLocalCommandContext *)context
{
	IRCChannel *targetChannel = context.targetChannel;

	if (targetChannel == nil || targetChannel.isChannel == NO) {
		[self printDebugInformation:TXTLS(@"IRC[g01-qn]")];

		return;
	}

	[self printDebugInformation:TXTLS(@"IRC[zud-u3]", targetChannel.name)];

	BOOL haveWeights = NO;

	for (IRCChannelUser *member in targetChannel.memberList) {
		double incomingWeight = member.incomingWeight;
		double outgoingWeight = member.outgoingWeight;

		CGFloat weight = (incomingWeight + outgoingWeight);

		if (weight > 0) {
			haveWeights = YES;

			[self printDebugInformation:TXTLS(@"IRC[24r-8c]",
					member.user.nickname, outgoingWeight, incomingWeight, weight)];
		}
	}

	if (haveWeights == NO) {
		[self printDebugInformation:TXTLS(@"IRC[dje-41]")];
	}
}

/* WHOIS */
- (void)_handleLocalCommandWhois:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;
	IRCChannel *targetChannel = context.targetChannel;

	NSAssertReturn(self.isLoggedIn);

	NSString *nickname1 = stringIn.tokenAsString;

	if (nickname1.length == 0) {
		if (targetChannel && targetChannel.isPrivateMessage) {
			nickname1 = targetChannel.name;
		} else {
			[self printInvalidSyntaxMessageForCommand:command];
			
			return;
		}
	}

	NSString *nickname2 = stringIn.tokenAsString;

	if (nickname2.length == 0) {
		[self send:@"WHOIS", nickname1, nickname1, nil];
	} else {
		[self send:@"WHOIS", nickname1, nickname2, nil];
	}
}

/* ME / MSG / NOTICE / OMSG / ONOTICE / SME / SMSG */
- (void)_handleLocalCommandMessage:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *command = context.command;
	NSInteger commandNumeric = context.commandNumeric;
	IRCChannel *targetChannel = context.targetChannel;
	NSString *targetChannelName = nil;

	/* Where would se send data to? */
	if (self.isLoggedIn == NO) {
		[self printDebugInformationToConsole:TXTLS(@"IRC[6rj-2r]")];

		return;
	}

	/* Establish context for comand */
	NSString *channelNamePrefix = nil;

	BOOL isOperatorMessage = NO;
	BOOL isSecretMessage = NO;

	NSString *commandToSend = nil;

	TVCLogLineType lineType = TVCLogLineTypeUndefined;

	if (commandNumeric == IRCLocalCommandMsg ||
		commandNumeric == IRCLocalCommandOmsg ||
		commandNumeric == IRCLocalCommandSmsg)
	{
		commandToSend = @"PRIVMSG";

		lineType = TVCLogLineTypePrivateMessage;

		isOperatorMessage = (commandNumeric == IRCLocalCommandOmsg);
		isSecretMessage = (commandNumeric == IRCLocalCommandSmsg);
	}
	else if (commandNumeric == IRCLocalCommandMe ||
			 commandNumeric == IRCLocalCommandSme)
	{
		commandToSend = @"PRIVMSG";

		lineType = TVCLogLineTypeAction;

		isSecretMessage = (commandNumeric == IRCLocalCommandSme);
	}
	else // NOTICE, ONOTICE
	{
		commandToSend = @"NOTICE";

		lineType = TVCLogLineTypeNotice;

		isOperatorMessage = (commandNumeric == IRCLocalCommandOnotice);
	}

	if (isOperatorMessage) {
		channelNamePrefix = [self.supportInfo statusMessagePrefixForModeSymbol:@"o"];

		/* If the user is sending an operator message and the user mode +o does 
		 not exist, then fail here. The user may be trying to send something 
		 secret with an expectation for privacy and we cannot deliver that. */
		if (channelNamePrefix == nil) {
			[self printDebugInformation:TXTLS(@"IRC[54l-h7]", @"o")];

			return;
		}
	}

	/* Pick the best target */
	/* All actions except (SME) should use the target channel */
	/* Operator messages should use the target channel unless the
	 string in is a channel name */
	/* All other scenarios use the string in (token) */
	if (isSecretMessage == NO && lineType == TVCLogLineTypeAction && targetChannel) {
		if (targetChannel.isUtility) {
			[self printDebugInformation:TXTLS(@"IRC[sxf-qx]")];

			return;
		}

		targetChannelName = targetChannel.name;
	} else if (isOperatorMessage && [self stringIsChannelName:stringIn.string] == NO && targetChannel.isChannel) {
		targetChannelName = targetChannel.name;
	} else {
		targetChannelName = stringIn.tokenAsString;
	}

	if (targetChannelName.length == 0) {
		[self printInvalidSyntaxMessageForCommand:command];

		return;
	}

	/* Actions are allowed to have an empty message but all other
	 types are not. Empty actions use a whitespace. */
	if (stringIn.length == 0) {
		if (lineType == TVCLogLineTypeAction) {
			[stringIn replaceCharactersInRange:NSMakeRange(0, 0)
									withString:@" "];
		} else {
			return;
		}
	}

	/* At this point, the following will occur:
	 1. Each destination is looped over
		1. Prefix characters are removed from the destination name
		2. Try to find channel that already exists which matches
		   the destination. If a channel does not exist, then we 
		   create one depending on whether this is a secret message.
		3. The message is then sent off.
	 */
	NSArray *destinations = [targetChannelName componentsSeparatedByString:@","];

	IRCChannel *destinationToSelect = nil;

	for (__strong NSString *destinationName in destinations) {
		/* If the user prefixed the target with a mode (e.g. +#channel)
		 to indicate that they want the message only seen by that group
		 of users, then we first have to remove that prefix to perform
		 our own processing of the target. When it comes time to send 
		 the message, then the prefix is added back to the target name. */
		NSString *destinationNamePrefix = [self.supportInfo extractStatusMessagePrefixFromChannelNamed:destinationName];

		if (destinationNamePrefix.length == 0) {
			destinationNamePrefix = channelNamePrefix;
		} else {
			destinationName = [destinationName substringFromIndex:1];
		}

		/* Locate object that matches destination */
		IRCChannel *destination = [self findChannel:destinationName];

		if (isSecretMessage == NO) {
			/* If the destination does not exist and this isn't a secret
			 message, then create a private message if the destination 
			 is believed to be a user. */
			if (destination == nil && [self stringIsNickname:destinationName]) {
				destination = [worldController() createPrivateMessage:destinationName onClient:self];
			}

			/* Define the channel that will be selected */
			if ([TPCPreferences giveFocusOnMessageCommand]) {
				if (destinationToSelect == nil) {
					destinationToSelect = destination;
				}
			}
		}

		/* Add prefix back if the destination is a channel */
		BOOL destinationIsChannel =
		(destination.isChannel || (destination == nil && [self stringIsChannelName:destinationName]));

		if (destinationNamePrefix && destinationIsChannel) {
			destinationName = [destinationNamePrefix stringByAppendingString:destinationName];
		}

		/* Break text up into substrings which can then be sent. */
		[self sendTextLine:stringIn
			 asCommand:commandToSend
			  lineType:lineType
		 toDestination:destinationName
			   printIn:destination
		printAsCommand:command];
	} // destination for()

	/* Focus destination */
	if (destinationToSelect) {
		[mainWindow() select:destinationToSelect];
	}
}

/* Commands without a handler: a plugin, a script or the server */
- (void)_handleUnknownLocalCommand:(IRCLocalCommandContext *)context
{
	NSMutableAttributedString *stringIn = context.stringIn;
	NSString *lowercaseCommand = context.lowercaseCommand;
	NSString *uppercaseCommand = context.uppercaseCommand;
	IRCChannel *targetChannel = context.targetChannel;

	/* Find an addon responsible for this command. */
	NSString *addonPath = nil;

	BOOL pluginFound = NO;
	BOOL scriptFound = NO;

	[sharedPluginManager() findHandlerForOutgoingCommand:lowercaseCommand path:&addonPath isScript:&scriptFound isExtension:&pluginFound];

	/* Perform script or plugin. */
	if (pluginFound && scriptFound)
	{
		[self printDebugInformation:TXTLS(@"IRC[d3c-9b]", uppercaseCommand)];
		
		return;
	}
	else if (pluginFound && scriptFound == NO)
	{
		[self processBundlesUserMessage:stringIn.string command:lowercaseCommand];

		return;
	}
	else if (pluginFound == NO && scriptFound)
	{
		NSMutableDictionary<NSString *, NSString *> *context = [NSMutableDictionary dictionaryWithCapacity:3];

		[context maybeSetObject:stringIn.string forKey:@"inputString"];

		[context maybeSetObject:addonPath forKey:@"path"];

		[context maybeSetObject:targetChannel.name forKey:@"targetChannel"];

		[self executeTextualCmdScriptInContext:context];

		return;
	}

	/* Send input to server */
	[self sendCommand:uppercaseCommand withData:stringIn.string];
}

#pragma mark -

- (void)sendCommand:(NSString *)command withData:(NSString *)data
{
	NSParameterAssert(command != nil);
	NSParameterAssert(data != nil);

	NSString *stringToSend = [NSString stringWithFormat:@"%@ %@", command, data];

	[self sendLine:stringToSend];
}

- (void)printInvalidSyntaxMessageForCommand:(NSString *)command
{
	NSParameterAssert(command != nil);
	
	NSString *syntax = [IRCCommandIndex syntaxForLocalCommand:command];
	
	if (syntax == nil) {
		return;
	}
	
	[self printDebugInformation:TXTLS(@"IRC[atq-93]", syntax)];
}

@end

NS_ASSUME_NONNULL_END
