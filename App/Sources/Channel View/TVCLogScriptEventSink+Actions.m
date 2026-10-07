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

@implementation TVCLogScriptEventSink (Actions)

#pragma mark -
#pragma mark Private Implementation

- (void)channelNameDoubleClicked:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.channelNameDoubleClicked()"
				 inWebView:webView
			  withSelector:@selector(_channelNameDoubleClicked:)];
}

- (void)displayContextMenu:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.displayContextMenu()"
				 inWebView:webView
			  withSelector:@selector(_displayContextMenu:)];
}

- (void)copySelectionWhenPermitted:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.copySelectionWhenPermitted()"
				 inWebView:webView
			  withSelector:@selector(_copySelectionWhenPermitted:)];
}

- (void)loadInlineMedia:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.loadInlineMedia()"
				 inWebView:webView
			  withSelector:@selector(_loadInlineMedia:)
	  minimumArgumentCount:4
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				if (argumentIndex <= 2) {
					return [argument isKindOfClass:[NSString class]];
				} else {
					return [argument isKindOfClass:[NSNumber class]];
				}
			}];
}

- (void)nicknameDoubleClicked:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.nicknameDoubleClicked()"
				 inWebView:webView
			  withSelector:@selector(_nicknameDoubleClicked:)];
}

- (void)sendPluginPayload:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.sendPluginPayload()"
				 inWebView:webView
			  withSelector:@selector(_sendPluginPayload:)
	  minimumArgumentCount:2
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				if (argumentIndex == 0) {
					return [argument isKindOfClass:[NSString class]];
				} else {
					return YES;
				}
			}];
}

- (void)setChannelName:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.setChannelName()"
				 inWebView:webView
			  withSelector:@selector(_setChannelName:)
	  minimumArgumentCount:1
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				return ([argument isKindOfClass:[NSNull class]] ||
						[argument isKindOfClass:[NSString class]]);
			}];
}

- (void)setNickname:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.setNickname()"
				 inWebView:webView
			  withSelector:@selector(_setNickname:)
	  minimumArgumentCount:1
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				return ([argument isKindOfClass:[NSNull class]] ||
						[argument isKindOfClass:[NSString class]]);
			}];
}

- (void)setSelection:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.setSelection()"
				 inWebView:webView
			  withSelector:@selector(_setSelection:)
	  minimumArgumentCount:1
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				return ([argument isKindOfClass:[NSNull class]] ||
						[argument isKindOfClass:[NSString class]]);
			}];
}

- (void)setURLAddress:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.setURLAddress()"
				 inWebView:webView
			  withSelector:@selector(_setURLAddress:)
	  minimumArgumentCount:1
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				return ([argument isKindOfClass:[NSNull class]] ||
						[argument isKindOfClass:[NSString class]]);
			}];
}

- (void)topicBarDoubleClicked:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.topicBarDoubleClicked()"
				 inWebView:webView
			  withSelector:@selector(_topicBarDoubleClicked:)];
}

#pragma mark -
#pragma mark Private Implementation

- (void)_channelNameDoubleClicked:(TVCLogScriptEventSinkContext *)context
{
	[context.webViewPolicy channelNameDoubleClicked];
}

- (void)_displayContextMenu:(TVCLogScriptEventSinkContext *)context
{
	[context.webViewPolicy displayContextMenuInWebView:context.webView];
}

- (void)_copySelectionWhenPermitted:(TVCLogScriptEventSinkContext *)context
{
	if ([TPCPreferences copyOnSelect]) {
		NSString *selection = context.webView.selection;

		if (selection) {
			RZPasteboard().stringContent = selection;

			context.completionBlock( @(YES) );
		}
	}

	context.completionBlock( @(NO) );
}

- (void)_loadInlineMedia:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	NSString *address = [self.class objectValueToCommon:arguments[0]];

	if (address.length == 0) {
		[self.class throwJavaScriptException:@"Length of address is 0"
								   forCaller:context.caller
								   inWebView:context.webView];

		return;
	}

	NSString *uniqueIdentifier = [self.class objectValueToCommon:arguments[1]];

	if (uniqueIdentifier.length == 0) {
		[self.class throwJavaScriptException:@"Length of unique identifier is 0"
								   forCaller:context.caller
								   inWebView:context.webView];

		return;
	}

	NSString *lineNumber = [self.class objectValueToCommon:arguments[2]];

	lineNumber = [self.class standardizeLineNumber:lineNumber];

	if (lineNumber.length == 0) {
		[self.class throwJavaScriptException:@"Length of line number is 0"
								   forCaller:context.caller
								   inWebView:context.webView];

		return;
	}

	NSNumber *index = [self.class objectValueToCommon:arguments[3]];

	[context.viewController processInlineMediaAtAddress:address
								   withUniqueIdentifier:uniqueIdentifier
										   atLineNumber:lineNumber
												  index:index.unsignedIntegerValue];
}

- (void)_nicknameDoubleClicked:(TVCLogScriptEventSinkContext *)context
{
	[context.webViewPolicy nicknameDoubleClicked];
}

- (void)_sendPluginPayload:(TVCLogScriptEventSinkContext *)context
{
	if ([sharedPluginManager() supportsFeature:THOPluginItemSupportedFeatureWebViewJavaScriptPayloads] == NO) {
		[self.class throwJavaScriptException:@"There are no plugins loaded that support JavaScript payloads"
								   forCaller:context.caller
								   inWebView:context.webView];

		return;
	}

	NSArray *arguments = context.arguments;

	NSString *payloadLabel = [self.class objectValueToCommon:arguments[0]];

	if (payloadLabel.length == 0) {
		[self.class throwJavaScriptException:@"Length of payload label is 0"
								   forCaller:context.caller
								   inWebView:context.webView];

		return;
	}

	id payloadContents = [self.class objectValueToCommon:arguments[1]];

	THOPluginWebViewJavaScriptPayloadConcreteObject *payloadObject =
	[THOPluginWebViewJavaScriptPayloadConcreteObject new];

	payloadObject.payloadLabel = payloadLabel;
	payloadObject.payloadContents = payloadContents;

	[THOPluginDispatcher didReceiveJavaScriptPayload:payloadObject fromViewController:context.viewController];
}

- (void)_setChannelName:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	NSString *value = [self.class objectValueToCommon:arguments[0]];

	context.webViewPolicy.channelName = value;
}

- (void)_setNickname:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	NSString *value = [self.class objectValueToCommon:arguments[0]];

	context.webViewPolicy.nickname = value;
}

- (void)_setSelection:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	NSString *selection = [self.class objectValueToCommon:arguments[0]];

	if (selection && selection.length == 0) {
		selection = nil;
	}

	context.webView.selection = selection;
}

- (void)_setURLAddress:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	NSString *value = [self.class objectValueToCommon:arguments[0]];

	context.webViewPolicy.anchorURL = value;
}

- (void)_topicBarDoubleClicked:(TVCLogScriptEventSinkContext *)context
{
	[context.webViewPolicy topicBarDoubleClicked];
}

@end

NS_ASSUME_NONNULL_END
