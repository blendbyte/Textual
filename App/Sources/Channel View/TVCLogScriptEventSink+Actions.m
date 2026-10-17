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
#import "IRCClientPrivate.h"
#import "TPCNicknameColorStyleGeneratorPrivate.h"
#import "IRCWorld.h"
#import "TVCMainWindowPrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogPolicyPrivate.h"
#import "TVCLogRenderer.h"
#import "TVCLogViewPrivate.h"
#import "TVCLogViewInternalWK2.h"
#import "TVCLogScriptEventSinkInternal.h"
#import "ICLHelpers.h"
#import "ICLImageViewer.h"
#import "ICLYouTubePlayer.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TVCLogScriptEventSink (Actions)

#pragma mark -
#pragma mark Private Implementation

- (void)_channelNameDoubleClicked:(TVCLogScriptEventSinkContext *)context
{
	[context.webViewPolicy channelNameDoubleClicked];
}

- (void)_copySelectionWhenPermitted:(TVCLogScriptEventSinkContext *)context
{
	if ([TPCPreferences copyOnSelect]) {
		NSString *selection = context.webView.selection;

		if (selection) {
			RZPasteboard().stringContent = selection;

			context.completionBlock( @(YES) );

			return;
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

	[context.viewController processRequestedInlineMediaAtAddress:address
								   withUniqueIdentifier:uniqueIdentifier
										   atLineNumber:lineNumber
												  index:index.unsignedIntegerValue];
}

- (void)_nicknameDoubleClicked:(TVCLogScriptEventSinkContext *)context
{
	[context.webViewPolicy nicknameDoubleClicked];
}

/* Clicking an inline image (E2.5): its textual-media: address, the link it
 came from and its size. Only an image Textual fetched can be opened. */
- (void)_openImageViewer:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	NSURL *mediaURL = [NSURL URLWithString:arguments[0]];

	NSURL *linkURL = [ICLHelpers URLWithString:arguments[1]];

	if (mediaURL == nil || linkURL == nil) {
		[self.class throwJavaScriptException:@"Not an image address and a link"
								   forCaller:context.caller
								   inWebView:context.webView];

		return;
	}

	NSSize imageSize = NSMakeSize([arguments[2] doubleValue], [arguments[3] doubleValue]);

	[ICLImageViewer showImageAtMediaURL:mediaURL linkURL:linkURL imageSize:imageSize];
}

/* A YouTube card's picture (E2.7): the video, where to start, the link and
 the card's title */
- (void)_openVideoPlayer:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	NSString *videoIdentifier = arguments[0];

	NSURL *linkURL = [ICLHelpers URLWithString:arguments[2]];

	if ([ICLYouTubePlayer isValidVideoIdentifier:videoIdentifier] == NO || linkURL == nil) {
		[self.class throwJavaScriptException:@"Not a YouTube video and a link"
								   forCaller:context.caller
								   inWebView:context.webView];

		return;
	}

	NSTimeInterval startTime = MAX(0, [arguments[1] doubleValue]);

	NSString *title = arguments[3];

	if (title.length > 200) {
		title = [title substringToIndex:200];
	}

	[ICLYouTubePlayer playVideo:videoIdentifier startTime:startTime title:title linkURL:linkURL client:context.associatedClient];
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

/* Reactions (9.15 B): add or take back ours on a message */
- (void)_toggleReaction:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	IRCChannel *channel = context.associatedChannel;

	if (channel == nil) {
		return;
	}

	[channel.associatedClient sendReaction:arguments[1] toMessage:arguments[0] inChannel:channel removing:[arguments[2] boolValue]];
}

/* The window showing the view the event came from (7.13) */
+ (TVCMainWindow *)windowOfContext:(TVCLogScriptEventSinkContext *)context
{
	TVCMainWindow *window = context.viewController.attachedWindow;

	return ((window) ?: mainWindow());
}

/* The Jump to Present button (10.9): the newest lines aren't loaded */
- (void)_jumpToPresent:(TVCLogScriptEventSinkContext *)context
{
	[context.viewController jumpToPresent];
}

/* Keyboard focus on messages (9.15 D): Escape went back to the input field */
- (void)_leaveMessageFocus:(TVCLogScriptEventSinkContext *)context
{
	[[self.class windowOfContext:context] leaveMessageFocusInViewController:context.viewController];
}

/* The context menu opens on a message: which, and what can be done */
- (void)_setMessageMenu:(TVCLogScriptEventSinkContext *)context
{
	/* An array arrives spread over the arguments */
	NSArray *values = context.arguments;

	if (values.count < 2) {
		context.webViewPolicy.messageMenu = nil;

		return;
	}

	for (id value in values) {
		if ([value isKindOfClass:[NSString class]] == NO) {
			context.webViewPolicy.messageMenu = nil;

			return;
		}
	}

	context.webViewPolicy.messageMenu = values;
}

/* Failed sends: Resend or Delete on a message the server refused */
- (void)_failedSendAction:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	[context.viewController performFailedSendAction:arguments[1] onLine:arguments[0]];
}

/* Delete (9.15 C): after asking */
- (void)_deleteMessage:(TVCLogScriptEventSinkContext *)context
{
	IRCChannel *channel = context.associatedChannel;

	if (channel == nil) {
		return;
	}

	[[self.class windowOfContext:context] confirmDeletingMessage:context.arguments[0] inChannel:channel];
}

/* More…: any emoji, from the macOS picker */
- (void)_pickReaction:(TVCLogScriptEventSinkContext *)context
{
	IRCChannel *channel = context.associatedChannel;

	if (channel == nil) {
		return;
	}

	[[self.class windowOfContext:context] showReactionPickerForMessage:context.arguments[0] inChannel:channel];
}

/* Reply (9.15): the message's ID, sender and the start of its text */
- (void)_replyToMessage:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	IRCChannel *channel = context.associatedChannel;

	if (channel == nil) {
		return;
	}

	[[self.class windowOfContext:context] replyToMessage:arguments[0] from:arguments[1] excerpt:arguments[2] inChannel:channel];
}

@end

NS_ASSUME_NONNULL_END
