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

#include <objc/message.h>

#import "GTMEncodeHTML.h"
#import "NSObjectHelperPrivate.h"
#import "TXMasterController.h"
#import "TPCPreferencesLocal.h"
#import "TPCThemeController.h"
#import "TPCTheme.h"
#import "THOPluginDispatcherPrivate.h"
#import "THOPluginManagerPrivate.h"
#import "THOPluginProtocolPrivate.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "IRCUserNicknameColorStyleGeneratorPrivate.h"
#import "IRCWorld.h"
#import "TVCMainWindow.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogPolicyPrivate.h"
#import "TVCLogRenderer.h"
#import "TVCLogViewPrivate.h"
#import "TVCLogViewInternalWK2.h"
#import "TVCLogScriptEventSinkInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TVCLogScriptEventSink (Queries)

#pragma mark -
#pragma mark Private Implementation

- (void)channelIsActive:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.channelIsActive()"
				 inWebView:webView
			  withSelector:@selector(_channelIsActive:)];
}

- (void)channelMemberCount:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.channelMemberCount()"
				 inWebView:webView
			  withSelector:@selector(_channelMemberCount:)];
}

- (void)channelName:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.channelName()"
				 inWebView:webView
			  withSelector:@selector(_channelName:)];
}

- (void)inlineMediaEnabledForView:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.inlineMediaEnabledForView()"
				 inWebView:webView
			  withSelector:@selector(_inlineMediaEnabledForView:)];
}

- (void)localUserHostmask:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.localUserHostmask()"
				 inWebView:webView
			  withSelector:@selector(_localUserHostmask:)];
}

- (void)localUserNickname:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.localUserNickname()"
				 inWebView:webView
			  withSelector:@selector(_localUserNickname:)];
}

- (void)networkName:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.networkName()"
				 inWebView:webView
			  withSelector:@selector(_networkName:)];
}

- (void)nicknameColorStyleHash:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.nicknameColorStyleHash()"
				 inWebView:webView
			  withSelector:@selector(_nicknameColorStyleHash:)
	  minimumArgumentCount:2
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				return [argument isKindOfClass:[NSString class]];
			}];
}

- (void)serverAddress:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.serverAddress()"
				 inWebView:webView
			  withSelector:@selector(_serverAddress:)];
}

- (void)serverChannelCount:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.serverChannelCount()"
				 inWebView:webView
			  withSelector:@selector(_serverChannelCount:)];
}

- (void)serverIsConnected:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.serverIsConnected()"
				 inWebView:webView
			  withSelector:@selector(_serverIsConnected:)];
}

- (void)sidebarInversionIsEnabled:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.sidebarInversionIsEnabled()"
				 inWebView:webView
			  withSelector:@selector(_sidebarInversionIsEnabled:)];
}

- (void)appearance:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.appearance()"
				 inWebView:webView
			  withSelector:@selector(_appearance:)];
}

#pragma mark -
#pragma mark Private Implementation

- (void)_channelIsActive:(TVCLogScriptEventSinkContext *)context
{
	context.completionBlock( @(context.associatedChannel.isActive) );
}

- (void)_channelMemberCount:(TVCLogScriptEventSinkContext *)context
{
	IRCChannel *channel = context.associatedChannel;

	if (channel == nil || channel.isChannel == NO) {
		[self.class throwJavaScriptException:@"View is not a channel"
								   forCaller:context.caller
								   inWebView:context.webView];

		return;
	}

	context.completionBlock( @(channel.numberOfMembers) );
}

- (void)_channelName:(TVCLogScriptEventSinkContext *)context
{
	context.completionBlock( context.associatedChannel.name );
}

- (void)_inlineMediaEnabledForView:(TVCLogScriptEventSinkContext *)context
{
	context.completionBlock( @(context.viewController.inlineMediaEnabledForView) );
}

- (void)_localUserHostmask:(TVCLogScriptEventSinkContext *)context
{
	context.completionBlock( context.associatedClient.userHostmask );
}

- (void)_localUserNickname:(TVCLogScriptEventSinkContext *)context
{
	context.completionBlock( context.associatedClient.userNickname );
}

- (void)_networkName:(TVCLogScriptEventSinkContext *)context
{
	context.completionBlock( context.associatedClient.networkName );
}

- (void)_nicknameColorStyleHash:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	NSString *inputString = [self.class objectValueToCommon:arguments[0]];

	NSString *colorStyle = [self.class objectValueToCommon:arguments[1]];

	TPCThemeSettingsNicknameColorStyle colorStyleEnum;

	if ([colorStyle isEqualToString:@"HSL-dark"]) {
		colorStyleEnum = TPCThemeSettingsNicknameColorStyleDark;
	} else if ([colorStyle isEqualToString:@"HSL-light"]) {
		colorStyleEnum = TPCThemeSettingsNicknameColorStyleLight;
	} else {
		[self.class throwJavaScriptException:@"Invalid style"
								   forCaller:context.caller
								   inWebView:context.webView];

		return;
	}

	context.completionBlock( [IRCUserNicknameColorStyleGenerator hashForString:inputString colorStyle:colorStyleEnum] );
}

- (void)_serverAddress:(TVCLogScriptEventSinkContext *)context
{
	context.completionBlock( context.associatedClient.serverAddress );
}

- (void)_serverChannelCount:(TVCLogScriptEventSinkContext *)context
{
	context.completionBlock( @(context.associatedClient.channelCount) );
}

- (void)_serverIsConnected:(TVCLogScriptEventSinkContext *)context
{
	context.completionBlock( @(context.associatedClient.isLoggedIn) );
}

- (void)_sidebarInversionIsEnabled:(TVCLogScriptEventSinkContext *)context
{
	TVCMainWindowAppearance *appearance = context.viewController.attachedWindow.userInterfaceObjects;

	context.completionBlock( @(appearance.isDarkAppearance) );
}

- (void)_appearance:(TVCLogScriptEventSinkContext *)context
{
	TVCMainWindowAppearance *appearance = context.viewController.attachedWindow.userInterfaceObjects;

	context.completionBlock( appearance.shortAppearanceDescription );
}

@end

NS_ASSUME_NONNULL_END
