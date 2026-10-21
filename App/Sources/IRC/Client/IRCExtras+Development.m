/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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
#import "TVCMainWindowPrivate.h"
#import "TVCLogController.h"
#import "TVCLogView.h"
#import "IRCBouncerAccountPrivate.h"
#import "IRCClientConfigPrivate.h"
#import "IRCClientPrivate.h"
#import "IRCChannelConfig.h"
#import "IRCChannel.h"
#import "IRCServer.h"
#import "IRCWorldPrivate.h"
#import "IRCExtrasPrivate.h"
#import "TXWebsiteLinks.h"

NS_ASSUME_NONNULL_BEGIN

#ifdef DEBUG

/* Textual Dev only: what Development/dev asks for through textual://dev-… links */
@implementation IRCExtras (Development)

static BOOL _developmentConnectRequested = NO;

/* Textual Dev's own textual://dev-… actions: YES when the location was one
 (performed, or refused without the launch token) */
+ (BOOL)performDevelopmentActionForLocation:(NSString *)location event:(nullable NSAppleEventDescriptor *)event
{
	/* Textual Dev only (Development/dev connect, input, config, send, eval,
	 reset): never from a link clicked in a message, and only with the token
	 Development/dev passed at launch, so other apps and web pages can't. */
	if ([location hasPrefix:@"textual://dev-"]) {
		if (event == nil || [self developmentURLCarriesToken:location] == NO) {
			LogToConsoleError("Ignored a Textual Dev action without the launch token");

			return YES;
		}
	}

	if ([location hasPrefix:@"textual://dev-connect?"]) {
		[self performDevelopmentConnectWithURL:location];

		return YES;
	} else if ([location hasPrefix:@"textual://dev-eval?"]) {
		[self performDevelopmentEvaluationWithURL:location];

		return YES;
	} else if ([location hasPrefix:@"textual://dev-send?"]) {
		[self performDevelopmentSendWithURL:location];

		return YES;
	} else if ([location hasPrefix:@"textual://dev-reset?"]) {
		[self performDevelopmentReset];

		return YES;
	} else if ([location hasPrefix:@"textual://dev-input?"]) {
		[self performDevelopmentInputWithURL:location];

		return YES;
	} else if ([location hasPrefix:@"textual://dev-config?"]) {
		[self performDevelopmentConfigurationWithURL:location];

		return YES;
	} else if ([location hasPrefix:@"textual://dev-bouncer?"]) {
		[self performDevelopmentBouncerWithURL:location];

		return YES;
	}

	return NO;
}

/* Development/dev connect: a test server on this Mac, connected to straight away */
+ (BOOL)isConnectingToDevelopmentServer:(NSString *)serverAddress
{
	return (_developmentConnectRequested && [self isDevelopmentTestServerAddress:serverAddress]);
}

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

/* textual://dev-bouncer?kind=znc|soju&host=…&port=…&tls=0|1&user=…&password=…&networks=a,b&connect=1
 adds a bouncer account and one server per network linked to it (named after
 the network), until the Add Bouncer sheet exists. */
+ (void)performDevelopmentBouncerWithURL:(NSString *)location
{
	NSURLComponents *components = [NSURLComponents componentsWithString:location];

	NSMutableDictionary<NSString *, NSString *> *values = [NSMutableDictionary dictionary];

	for (NSURLQueryItem *item in components.queryItems) {
		if (item.value) {
			values[item.name] = item.value;
		}
	}

	IRCBouncerAccountMutable *account = [IRCBouncerAccountMutable new];

	account.kind = ([values[@"kind"] isEqualToString:@"soju"] ? IRCBouncerKindSoju : IRCBouncerKindZNC);
	account.serverAddress = (values[@"host"] ?: @"127.0.0.1");
	account.serverPort = (uint16_t)(values[@"port"] ?: @"6672").integerValue;
	account.prefersSecuredConnection = [values[@"tls"] isEqualToString:@"1"];
	account.username = (values[@"user"] ?: @"dan");
	account.password = values[@"password"];
	account.name = values[@"name"];

	[worldController() addBouncerAccount:account];

	BOOL connect = [values[@"connect"] isEqualToString:@"1"];

	for (NSString *network in [values[@"networks"] componentsSeparatedByString:@","]) {
		if (network.length == 0) {
			continue;
		}

		IRCClientConfigMutable *config = [IRCClientConfigMutable new];

		config.connectionName = network;
		config.bouncerAccountIdentifier = account.uniqueIdentifier;
		config.bouncerNetwork = network;
		config.zncIgnoreConfiguredAutojoin = YES;

		IRCClient *client = [worldController() createClientWithConfig:config reload:YES];

		if (connect) {
			[client connect];
		}
	}

	[worldController() save];
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

	TVCLogController *viewController = TVCMainWindow.currentWindow.selectedViewController;

	if (viewController == nil || script.length == 0) {
		return;
	}

	[viewController.backingView evaluateJavaScript:script completionHandler:^(id _Nullable result) {
		LogToConsole("dev-eval: %{public}@", ((result) ? [result description] : @"(no result)"));
	}];
}

/* textual://dev-reset deletes Textual Dev's own preferences (including the
 server list), scrollback, caches and logs, then quits without saving. Only
 the app itself may remove the contents of its container. The container
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

	[RZUserDefaults() removePersistentDomainForName:bundleIdentifier];

	NSURL *containerLibraryURL = [[NSURL fileURLWithPath:NSHomeDirectory()] URLByAppendingPathComponent:@"Library"];

	NSArray *folders = @[
		[containerLibraryURL URLByAppendingPathComponent:@"Application Support"],
		[containerLibraryURL URLByAppendingPathComponent:@"Caches"],
		[containerLibraryURL URLByAppendingPathComponent:@"Logs"]
	];

	for (NSURL *folder in folders) {
		[RZFileManager() removeItemAtURL:folder error:NULL];
	}

	/* Not -terminate:, which would save the server list again */
	exit(0);
}

@end

#endif

NS_ASSUME_NONNULL_END
