/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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

#import "BuildConfig.h"
#import "NSStringHelper.h"
#import "TXMasterController.h"
#import "TXMenuControllerPrivate.h"
#import "TXSharedApplicationPrivate.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCAlert.h"
#import "TPCApplicationInfo.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesUserDefaults.h"
#import "TLOLocalization.h"
#import "TLOpenLink.h"
#import "TVCMainWindow.h"
#import "TVCLogController.h"
#import "TVCLogView.h"
#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "IRCChannelConfig.h"
#import "IRCChannel.h"
#import "IRCServer.h"
#import "IRCWorldPrivate.h"
#import "IRCExtrasPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCExtras

+ (void)performSpecialActionForTextualScheme:(NSString *)action source:(NSString *)sourceLocation
{
/*
	Syntax: textual://<token>

	Reserved tokens:

	acknowledgements					— Open acknowledgements file
	activate-license					— Activate a license key
	application-support-folder			— Open the Application Support folder
	contributors						— Open contributors file
	custom-scripts-folder				– Open the custom scripts storage location folder
	custom-style-folder					— Open the custom style storage location folder
	custom-styles-folder				— Open the custom style storage location folder
	diagnostic-reports-folder			— System diagnostic reports folder
	goto 								— Navigate to an item
	knowledge-base						— Open the homepage of our knowledge base
	newsletter							— Open the subscription page for the newsletter
	support-channel						— Connect to the #textual channel
	testing-channel						— Connect to the #textual-testing channel
	unsupervised-script-folder			— Open the custom scripts storage location folder
	unsupervised-scripts-folder			— Open the custom scripts storage location folder
*/

	if ([action isEqualToString:@"acknowledgements"])
	{
		[menuController() openAcknowledgements:nil];
	}

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
	else if ([action isEqualToString:@"activate-license"])
	{
		NSURL *licenseKeyURL = [NSURL URLWithString:sourceLocation];

		[menuController() manageLicense:nil activateLicenseKeyWithURL:licenseKeyURL];
	}
#endif

	else if ([action isEqualToString:@"application-support-folder"])
	{
		[RZWorkspace() openURL:[TPCPathInfo groupContainerApplicationSupportURL]];
	}
	else if ([action isEqualToString:@"contributors"])
	{
		[menuController() openAcknowledgements:nil];
	}
	else if ([action isEqualToString:@"custom-scripts-folder"] ||
			 [action isEqualToString:@"unsupervised-script-folder"] ||
			 [action isEqualToString:@"unsupervised-scripts-folder"])
	{
		[RZWorkspace() openURL:[TPCPathInfo customScriptsURL]];
	}
	else if ([action isEqualToString:@"custom-style-folder"] ||
			 [action isEqualToString:@"custom-styles-folder"])
	{
		[RZWorkspace() openURL:[TPCPathInfo customThemesURL]];
	}
	else if ([action isEqualToString:@"diagnostic-reports-folder"])
	{
		[RZWorkspace() openURL:[TPCPathInfo userDiagnosticReportsURL]];
		[RZWorkspace() openURL:[TPCPathInfo systemDiagnosticReportsURL]];
	}
	else if ([action isEqualToString:@"goto"])
	{
		NSURL *url = [NSURL URLWithString:sourceLocation];

		[menuController() navigateToTreeItemAtURL:url];
	}
	else if ([action isEqualToString:@"knowledge-base"])
	{
		[TLOpenLink openWithString:@"https://help.codeux.com/textual/" inBackground:NO];
	}
	else if ([action isEqualToString:@"newsletter"])
	{
		[TLOpenLink openWithString:@"https://www.codeux.com/textual/newsletter/" inBackground:NO];
	}
	else if ([action isEqualToString:@"support-channel"])
	{
		[menuController() connectToTextualHelpChannel:nil];
	}
	else if ([action isEqualToString:@"testing-channel"])
	{
		[menuController() connectToTextualTestingChannel:nil];
	}
}

+ (void)parseIRCProtocolURI:(NSString *)location
{
	[self parseIRCProtocolURI:location withDescriptor:nil];
}

+ (void)parseIRCProtocolURI:(NSString *)location withDescriptor:(nullable NSAppleEventDescriptor *)event
{
	NSParameterAssert(location != nil);

#ifdef DEBUG
	/* Textual Dev only (Development/dev connect, input, config, send, eval,
	 reset): never from a link clicked in a message, and only with the token
	 Development/dev passed at launch, so other apps and web pages can't. */
	if ([location hasPrefix:@"textual://dev-"]) {
		if (event == nil || [self developmentURLCarriesToken:location] == NO) {
			LogToConsoleError("Ignored a Textual Dev action without the launch token");

			return;
		}
	}

	if ([location hasPrefix:@"textual://dev-connect?"]) {
		[self performDevelopmentConnectWithURL:location];

		return;
	} else if ([location hasPrefix:@"textual://dev-eval?"]) {
		[self performDevelopmentEvaluationWithURL:location];

		return;
	} else if ([location hasPrefix:@"textual://dev-send?"]) {
		[self performDevelopmentSendWithURL:location];

		return;
	} else if ([location hasPrefix:@"textual://dev-reset?"]) {
		[self performDevelopmentReset];

		return;
	} else if ([location hasPrefix:@"textual://dev-input?"]) {
		[self performDevelopmentInputWithURL:location];

		return;
	} else if ([location hasPrefix:@"textual://dev-config?"]) {
		[self performDevelopmentConfigurationWithURL:location];

		return;
	}
#endif

	/* Basic input clean up. */
	NSString *locationValue = location;

	locationValue = locationValue.percentDecodedString;
	locationValue = locationValue.trim;

	/* This method extracts the path component of the URL from the input
	 string before turning the remaining pieces into an NSURL. */
	/* The URL may contain multiple sections proceeded by the pound sign (#),
	 which this method treats as channel, but NSURL aren't too friendly about. */
	NSUInteger totalSlashCount = [locationValue occurrencesOfCharacter:'/'];

	if (totalSlashCount < 2 || totalSlashCount > 3) {
		return;
	}

	NSString *serverInfo = locationValue;

	NSString *channelInfo = nil;

	if (totalSlashCount == 3) { // Only cut if we do have an extra slash.
		NSRange backwardRange = [locationValue rangeOfString:@"/" options:NSBackwardsSearch];

		if (backwardRange.location != NSNotFound) {
			serverInfo = [locationValue substringToIndex:backwardRange.location];

			channelInfo = [locationValue substringAfterIndex:backwardRange.location];
		}
	}

	/* Now that channel information is no longer present in the URL, 
	 we can pass it to NSURL to extract all other information. */
	NSURL *baseURL = [NSURL URLWithString:serverInfo];

	NSString *addressScheme = baseURL.scheme;

	NSString *serverAddress = baseURL.host;

	if (addressScheme == nil || serverAddress == nil) {
		return;
	}

	if ([addressScheme isEqualToString:@"textual"]) {
		[self performSpecialActionForTextualScheme:serverAddress source:locationValue];

		return;
	}

	/* Continue normal parsing... */
	NSNumber *serverPort = baseURL.port;

	if (serverPort == nil) {
		serverPort = @(IRCConnectionDefaultServerPort);
	}

	__block BOOL connectSecurely = NO;

	if ([addressScheme isEqualToString:@"ircs"]) {
		connectSecurely = YES;
	}

	/* If we have made it to this point without this method returning,
	 then everything is going smooth so far. We have established our
	 server address, the URL scheme, and associated channel information. */
	/* We will now parse the actual channel information. */
	/* This method does not actually create the connection. It only formats 
	 the input so that another can. Therefore, we do not have to take much 
	 care with the channel information. Just a basic parse to establish if 
	 the "needssl" token is present as well as the channel name having a 
	 pound (#) sign in front of it. */
	NSMutableString *channelList = [NSMutableString string];

	if (channelInfo) {
		NSArray *dataSections = [channelInfo split:@","];

		NSUInteger dataSectionsCount = dataSections.count;

		[dataSections enumerateObjectsUsingBlock:^(NSString *section, NSUInteger index, BOOL *stop) {
			if (section.length == 0) {
				return;
			}

			if (index > 4) {
				*stop = YES;

				return;
			}

			BOOL isLastObject = ((index + 1) == dataSectionsCount);

			if (isLastObject && [section isEqualToStringIgnoringCase:@"needssl"]) {
				connectSecurely = YES;

				return;
			}

			NSString *sectionCopy = section;

			if ([sectionCopy hasPrefix:@"#"] == NO) {
				sectionCopy = [@"#" stringByAppendingString:sectionCopy];
			}

			[channelList appendString:sectionCopy];
			[channelList appendString:@","];
		}];

		/* Erase end commas */
		if (channelList.length > 1) {
			[channelList deleteCharactersInRange:NSMakeRange((channelList.length - 1), 1)];
		}
	}

	/* We have parsed every part of our URL. Build the final result and
	 pass it along. We are done here. */
	NSString *resultValue = nil;

	if (connectSecurely) {
		resultValue = [NSString stringWithFormat:@"-SSL %@:%hu", serverAddress, serverPort.unsignedShortValue];
	} else {
		resultValue = [NSString stringWithFormat:@"%@:%hu", serverAddress, serverPort.unsignedShortValue];
	}

#ifdef DEBUG
	/* Development/dev connect: test servers on this Mac are connected to
	 straight away, as a new server each time (they differ only by port) */
	if (_developmentConnectRequested && [self isDevelopmentTestServerAddress:serverAddress]) {
		[self createConnectionToServer:resultValue channelList:channelList connectWhenCreated:YES mergeConnectionIfPossible:NO selectFirstChannelAdded:NO];

		return;
	}
#endif

	/* A URL is consider untrusted and will not auto connect */
	[self createConnectionToServer:resultValue channelList:channelList connectWhenCreated:NO mergeConnectionIfPossible:YES selectFirstChannelAdded:NO];
}

#ifdef DEBUG
static BOOL _developmentConnectRequested = NO;

/* This Mac, or a name under the reserved .test domain (RFC 2606, never
 resolved on the internet), which the test proxy maps to a local server */
+ (BOOL)isDevelopmentTestServerAddress:(NSString *)serverAddress
{
	if ([@[@"127.0.0.1", @"localhost"] containsObject:serverAddress]) {
		return YES;
	}

	return [serverAddress.lowercaseString hasSuffix:@".test"];
}

/* Development/dev passes a fresh token as a launch argument ("-TextualDevToken");
 it is read from the arguments only, never from saved preferences */
+ (BOOL)developmentURLCarriesToken:(NSString *)location
{
	NSString *launchToken = [[NSUserDefaults standardUserDefaults] volatileDomainForName:NSArgumentDomain][@"TextualDevToken"];

	if ([launchToken isKindOfClass:[NSString class]] == NO || launchToken.length < 16) {
		return NO;
	}

	for (NSURLQueryItem *item in [NSURLComponents componentsWithString:location].queryItems) {
		if ([item.name isEqualToString:@"token"]) {
			return [item.value isEqualToString:launchToken];
		}
	}

	return NO;
}

/* textual://dev-connect?url=<irc or ircs URL to a test server on this Mac> */
+ (void)performDevelopmentConnectWithURL:(NSString *)location
{
	NSString *serverURL = nil;

	for (NSURLQueryItem *item in [NSURLComponents componentsWithString:location].queryItems) {
		if ([item.name isEqualToString:@"url"]) {
			serverURL = item.value;
		}
	}

	if (serverURL.length == 0) {
		return;
	}

	_developmentConnectRequested = YES;

	[self parseIRCProtocolURI:serverURL withDescriptor:nil];

	_developmentConnectRequested = NO;
}

/* textual://dev-input?text=<text>[&channel=<channel>] selects the newest server's
 console, or one of its channels, and runs the text as if it was typed there.
 Without text, it only selects. */
+ (void)performDevelopmentInputWithURL:(NSString *)location
{
	NSURLComponents *components = [NSURLComponents componentsWithString:location];

	NSString *text = nil;
	NSString *channelName = nil;

	for (NSURLQueryItem *item in components.queryItems) {
		if ([item.name isEqualToString:@"text"]) {
			text = item.value;
		} else if ([item.name isEqualToString:@"channel"]) {
			channelName = item.value;
		}
	}

	IRCClient *client = worldController().clientList.lastObject;

	if (client == nil) {
		return;
	}

	IRCTreeItem *destination = client;

	if (channelName.length > 0) {
		IRCChannel *channel = [client findChannel:channelName];

		if (channel == nil) {
			return;
		}

		destination = channel;
	}

	[mainWindow() select:destination];

	if (text.length == 0) {
		return;
	}

	[client inputText:text destination:destination];
}

/* textual://dev-config?<key>=<value>[&…] changes the newest server's configuration
 as Server Properties would. Keys are IRCClientConfig property names; switches
 take 1 or 0. connect=1 then (re)connects the server with the new settings. */
+ (void)performDevelopmentConfigurationWithURL:(NSString *)location
{
	IRCClient *client = worldController().clientList.lastObject;

	if (client == nil) {
		return;
	}

	IRCClientConfigMutable *config = [client.config mutableCopy];

	NSURLComponents *components = [NSURLComponents componentsWithString:location];

	BOOL connect = NO;

	for (NSURLQueryItem *item in components.queryItems) {
		if ([item.name isEqualToString:@"connect"]) {
			connect = [item.value isEqualToString:@"1"];

			continue;
		}

		NSString *setterName = [NSString stringWithFormat:@"set%@%@:", [item.name substringToIndex:1].uppercaseString, [item.name substringFromIndex:1]];

		if ([config respondsToSelector:NSSelectorFromString(setterName)] == NO) {
			LogToConsoleError("dev-config: unknown key '%{public}@'", item.name);

			continue;
		}

		/* Numbers as NSNumber: KVC can't set integer properties from strings */
		id value = item.value;

		if (value && [value rangeOfString:@"^[0-9]+$" options:NSRegularExpressionSearch].location != NSNotFound) {
			value = @([value longLongValue]);
		}

		[config setValue:value forKey:item.name];
	}

	[client updateConfig:config];

	if (connect == NO) {
		return;
	}

	if (client.isConnected || client.isConnecting) {
		[client quit];

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[client connect];
		});
	} else {
		[client connect];
	}
}

/* textual://dev-send?nickname=<nickname>&path=<path> offers a file to a user
 on the newest server, as dropping it on them would. The path must be one
 the sandbox can read, such as the Downloads folder. */
+ (void)performDevelopmentSendWithURL:(NSString *)location
{
	NSURLComponents *components = [NSURLComponents componentsWithString:location];

	NSString *nickname = nil;
	NSString *path = nil;

	for (NSURLQueryItem *item in components.queryItems) {
		if ([item.name isEqualToString:@"nickname"]) {
			nickname = item.value;
		} else if ([item.name isEqualToString:@"path"]) {
			path = item.value;
		}
	}

	IRCClient *client = worldController().clientList.lastObject;

	if (client == nil || nickname.length == 0 || path.length == 0) {
		return;
	}

	[[TXSharedApplication sharedFileTransferDialog] addSenderForClient:client nickname:nickname path:path autoOpen:YES];
}

/* textual://dev-eval?script=<JavaScript> runs the script in the selected view
 and logs the result ("dev-eval: …", see Development/dev logs). */
+ (void)performDevelopmentEvaluationWithURL:(NSString *)location
{
	NSURLComponents *components = [NSURLComponents componentsWithString:location];

	NSString *script = nil;

	for (NSURLQueryItem *item in components.queryItems) {
		if ([item.name isEqualToString:@"script"]) {
			script = item.value;
		}
	}

	TVCLogController *viewController = mainWindow().selectedViewController;

	if (viewController == nil || script.length == 0) {
		return;
	}

	[viewController.backingView evaluateJavaScript:script completionHandler:^(id _Nullable result) {
		LogToConsole("dev-eval: %{public}@", ((result) ? [result description] : @"(no result)"));
	}];
}

/* textual://dev-reset deletes Textual Dev's own preferences (including the
 server list), scrollback, caches and logs, then quits without saving. Only
 the app itself may remove the contents of its containers. The container
 holds links to the user's folders, so only these folders are removed.
 Keychain items are kept. */
+ (void)performDevelopmentReset
{
	NSString *bundleIdentifier = [TPCApplicationInfo applicationBundleIdentifier];

	if ([bundleIdentifier isEqualToString:@"com.textualapp.app.dev"] == NO) {
		return;
	}

	/* Only inside Textual Dev's own sandbox container: unsandboxed (e.g. an
	 unsigned build), these folders would be the user's own Library folders */
	if ([NSHomeDirectory() hasSuffix:@"/Library/Containers/com.textualapp.app.dev/Data"] == NO) {
		LogToConsoleError("dev-reset refused: not running in Textual Dev's sandbox container");

		return;
	}

	[RZUserDefaults() removePersistentDomainForName:TXBundleBuildGroupContainerIdentifier];

	[[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];

	NSURL *containerLibraryURL = [[NSURL fileURLWithPath:NSHomeDirectory()] URLByAppendingPathComponent:@"Library"];

	NSURL *groupContainerLibraryURL = [[TPCPathInfo groupContainerURL] URLByAppendingPathComponent:@"Library"];

	NSArray *folders = @[
		[containerLibraryURL URLByAppendingPathComponent:@"Application Support"],
		[containerLibraryURL URLByAppendingPathComponent:@"Caches"],
		[containerLibraryURL URLByAppendingPathComponent:@"Logs"]
	];

	if (groupContainerLibraryURL) {
		folders = [folders arrayByAddingObjectsFromArray:@[
			[groupContainerLibraryURL URLByAppendingPathComponent:@"Application Support"],
			[groupContainerLibraryURL URLByAppendingPathComponent:@"Caches"]
		]];
	}

	for (NSURL *folder in folders) {
		[RZFileManager() removeItemAtURL:folder error:NULL];
	}

	/* Not -terminate:, which would save the server list again */
	exit(0);
}
#endif

+ (void)createConnectionToServer:(NSString *)serverInfo channelList:(nullable NSString *)channelList connectWhenCreated:(BOOL)connectWhenCreated
{
	[self createConnectionToServer:serverInfo channelList:channelList connectWhenCreated:connectWhenCreated mergeConnectionIfPossible:NO selectFirstChannelAdded:NO];
}

+ (void)createConnectionToServer:(NSString *)serverInfo
					 channelList:(nullable NSString *)channelList
			  connectWhenCreated:(BOOL)connectWhenCreated
	   mergeConnectionIfPossible:(BOOL)mergeConnectionIfPossible
		 selectFirstChannelAdded:(BOOL)selectFirstChannelAdded
{
	NSParameterAssert(serverInfo != nil);

	/* Establish our variables */
	NSString *serverAddress = nil;

	uint16_t serverPort = IRCConnectionDefaultServerPort;

	NSString *serverPassword = nil;

	BOOL connectSecurely = NO;

	/* Begin parsing */
	NSMutableString *serverInfoMutable = [serverInfo mutableCopy];

	/* Get our first token. A token is everything before the first 
	 occurrence of a space character. getToken will get everything 
	 before a space in a string, then erase the remaining content 
	 of that string so that each call to getToken gives us the next 
	 section of our string. */
	NSString *tempStore = serverInfoMutable.token;

	/* Secure Socket Layer? */
	if ([tempStore isEqualToStringIgnoringCase:@"-SSL"] ||
		[tempStore isEqualToStringIgnoringCase:@"-TLS"])
	{
		connectSecurely = YES;

		/* If the SSL define was our first token, we
		 go to our next token. */
		tempStore = serverInfoMutable.token;
	}

	/* Server Address */
	NSInteger openingBracketPosition = ([tempStore stringPosition:@"["] + 1);
	NSInteger closingBracketPosition =  [tempStore stringPosition:@"]"];

	BOOL hasOpeningBracket = (openingBracketPosition == 1 && openingBracketPosition < closingBracketPosition);
	BOOL hasClosingBracket = (closingBracketPosition > 0 && openingBracketPosition < closingBracketPosition);

	if (hasOpeningBracket && hasClosingBracket) {
		NSRange serverAddressRange = NSMakeRange(openingBracketPosition, (closingBracketPosition - openingBracketPosition));

		NSString *tempServerAddress = [tempStore substringWithRange:serverAddressRange];

		if (tempServerAddress.IPv6Address == NO) {
			LogToConsoleError("Server address was surrounded by square brackets but the enclosed value was not an IPv6 address");

			return;
		}

		serverAddress = tempServerAddress;

		tempStore = [tempStore substringAfterIndex:closingBracketPosition];
	} else if (hasOpeningBracket == NO && hasClosingBracket == NO) {
		/* Our server address did not contain brackets. Does it
		 contain a colon (:) which means a port is included? */
		NSInteger colonPosition = [tempStore stringPosition:@":"];

		if (colonPosition > (-1)) {
			serverAddress = [tempStore substringToIndex:colonPosition];

			/* We cut the server address out of our temporary store,
			 but left the colon and everything after it, in it. */
			tempStore = [tempStore substringFromIndex:colonPosition];
		} else {
			serverAddress = tempStore;
		}
	} else {
		/* If we have a opening bracket but no closing or any
		 combination of the two, then return this method as our
		 server address is already invalid. If there were not
		 brackets either, then we are not treating the server
		 as an IPv4 address so any colon will be considered
		 for port use only. */

		return;
	}

	if (serverAddress.validInternetAddress == NO) {
		LogToConsoleError("Invalid internet address");

		return;
	}

	serverAddress = serverAddress.lowercaseString;

	/* Server Port */
	NSString *tempServerPort = nil;

	if ([tempStore hasPrefix:@":"]) {
		tempServerPort = [tempStore substringFromIndex:1];
	} else if (serverInfoMutable.length > 0) {
		tempServerPort = serverInfoMutable.token;
	}

	if (tempServerPort) {
		if ([tempServerPort hasPrefix:@"+"]) {
			tempServerPort = [tempServerPort substringFromIndex:1];

			connectSecurely = YES;
		}

		if (tempServerPort.validInternetPort == NO) {
			LogToConsoleError("Invalid internet port");

			return;
		}

		serverPort = tempServerPort.integerValue;
	}

	/* Server Password */
	/* If our base is still not empty after taking out the token for the
	 server address and port, then we are going to treat that as the server
	 password. Anything after this token will be ignored completely. */
	if (serverInfoMutable.length > 0) {
		tempStore = serverInfoMutable.token;

		serverPassword = tempStore;
	}

	/* Convert channel list string into array of configurations */
	NSMutableArray<NSString *> *channelListArray = nil;

	if (channelList.length > 0) {
		channelListArray = [NSMutableArray array];

		NSArray *dataSections = [channelList split:@","];

		for (NSString *section in dataSections) {
			NSString *channelName = section.trim;

			if (channelName.isChannelName == NO) {
				continue;
			}

			if ([channelListArray containsObjectIgnoringCase:channelName]) {
				continue;
			}

			[channelListArray addObject:channelName];
		}
	}

	/* Create connection */
	[self createConnectionToServer:serverAddress
						serverPort:serverPort
					serverPassword:serverPassword
				   connectSecurely:connectSecurely
					   channelList:[channelListArray copy]
				connectWhenCreated:connectWhenCreated
		 mergeConnectionIfPossible:mergeConnectionIfPossible
		   selectFirstChannelAdded:selectFirstChannelAdded];
}

+ (void)createConnectionToServer:(NSString *)serverAddress
					  serverPort:(uint16_t)serverPort
				  serverPassword:(nullable NSString *)serverPassword
				 connectSecurely:(BOOL)connectSecurely
					 channelList:(nullable NSArray<NSString *> *)channelList
			  connectWhenCreated:(BOOL)connectWhenCreated
	   mergeConnectionIfPossible:(BOOL)mergeConnectionIfPossible
		 selectFirstChannelAdded:(BOOL)selectFirstChannelAdded
{
	NSParameterAssert(serverAddress != nil);
	NSParameterAssert(serverPort > 0);

	NSUInteger channelListCount = channelList.count;

	/* If merging is enabled, try to find first possible client
	 by comparing server address values. */
	/* Merging is only performed if a channel is being joined. */
	IRCClient *existingClient = nil;

	if (mergeConnectionIfPossible && channelListCount > 0) {
		existingClient = [worldController() findClientWithServerAddress:serverAddress];
	}

	if (existingClient != nil) {
		BOOL mergeConnection = NO;

		if (channelListCount > 1) {
			NSString *channelListFormatted = [channelList componentsJoinedByString:@", "];

			mergeConnection = [TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[a9z-9f]", existingClient.name)
														title:TXTLS(@"Prompts[pnc-ew]", serverAddress, channelListFormatted)
												defaultButton:TXTLS(@"Prompts[0hh-sl]")
											  alternateButton:TXTLS(@"Prompts[sv9-8s]")];
		} else {
			mergeConnection = [TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[mx1-qz]", existingClient.name)
														title:TXTLS(@"Prompts[3l6-3z]", serverAddress, channelList.firstObject)
												defaultButton:TXTLS(@"Prompts[sl5-rf]")
											  alternateButton:TXTLS(@"Prompts[xca-5h]")];
		}

		// YES = default button (create new connection)
		if (mergeConnection == NO) {
			existingClient = nil;
		}
	}

	/* Create new connection or merge into existing */
	if (existingClient)
	{
		IRCChannel *firstChannelAdded = nil;

		for (NSString *channelName in channelList) {
			IRCChannel *channel = [existingClient findChannelOrCreate:channelName isPrivateMessage:NO];

			if (firstChannelAdded == nil) {
				firstChannelAdded = channel;
			}

			if (connectWhenCreated) {
				[existingClient joinChannel:channel];
			}
		}

		[worldController() save];

		if (selectFirstChannelAdded && firstChannelAdded) {
			[mainWindow() select:firstChannelAdded];
		}
	}
	else // existingClient
	{
		IRCClientConfigMutable *baseConfig = [IRCClientConfigMutable new];

		baseConfig.connectionName = serverAddress;

		IRCServerMutable *server = [IRCServerMutable new];

		server.serverAddress = serverAddress;
		server.serverPort = serverPort;

		server.prefersSecuredConnection = connectSecurely;

		if (serverPassword != nil) {
			server.serverPassword = serverPassword;
		}

#ifdef DEBUG
		/* Development/dev connect: the test servers on this Mac use self-signed certificates */
		if (_developmentConnectRequested && [self isDevelopmentTestServerAddress:serverAddress]) {
			baseConfig.validateServerCertificateChain = NO;
		}
#endif

		baseConfig.serverList = @[[server copy]];

		NSMutableArray<IRCChannelConfig *> *channelListConfigs = [NSMutableArray arrayWithCapacity:channelListCount];

		for (NSString *channelName in channelList) {
			IRCChannelConfig *channelConfig = [IRCChannelConfig seedWithName:channelName];

			[channelListConfigs addObject:channelConfig];
		}

		baseConfig.channelList = channelListConfigs;

		IRCClient *client = [worldController() createClientWithConfig:baseConfig reload:YES];

		[worldController() save];

		if (connectWhenCreated) {
			[client connect];
		}

		if (selectFirstChannelAdded) {
			[client selectFirstChannelInChannelList];
		}
	}
}

@end

NS_ASSUME_NONNULL_END
