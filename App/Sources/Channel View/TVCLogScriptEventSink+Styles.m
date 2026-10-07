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

@implementation TVCLogScriptEventSink (Styles)

#pragma mark -
#pragma mark Private Implementation

- (void)logToConsole:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.logToConsole()"
				 inWebView:webView
			  withSelector:@selector(_logToConsole:)
	  minimumArgumentCount:1
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				return [argument isKindOfClass:[NSString class]];
			}];
}

- (void)printDebugInformation:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.printDebugInformation()"
				 inWebView:webView
			  withSelector:@selector(_printDebugInformation:)
	  minimumArgumentCount:1
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				return [argument isKindOfClass:[NSString class]];
			}];
}

- (void)printDebugInformationToConsole:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.printDebugInformationToConsole()"
				 inWebView:webView
			  withSelector:@selector(_printDebugInformationToConsole:)
	  minimumArgumentCount:1
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				return [argument isKindOfClass:[NSString class]];
			}];
}

- (void)retrievePreferencesWithMethodName:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.retrievePreferencesWithMethodName()"
				 inWebView:webView
			  withSelector:@selector(_retrievePreferencesWithMethodName:)
	  minimumArgumentCount:1
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				return [argument isKindOfClass:[NSString class]];
			}];
}

- (void)styleSettingsRetrieveValue:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.styleSettingsRetrieveValue()"
				 inWebView:webView
			  withSelector:@selector(_styleSettingsRetrieveValue:)
	  minimumArgumentCount:1
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				return [argument isKindOfClass:[NSString class]];
			}];
}

- (void)styleSettingsSetValue:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.styleSettingsSetValue()"
				 inWebView:webView
			  withSelector:@selector(_styleSettingsSetValue:)
	  minimumArgumentCount:2
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				if (argumentIndex == 0) {
					return [argument isKindOfClass:[NSString class]];
				} else {
					return ([argument isKindOfClass:[NSArray class]] ||
							[argument isKindOfClass:[NSDictionary class]] ||
							[argument isKindOfClass:[NSNull class]] ||
							[argument isKindOfClass:[NSNumber class]] ||
							[argument isKindOfClass:[NSString class]]);
				}
			}];
}

#pragma mark -
#pragma mark Private Implementation

- (void)_logToConsole:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	NSString *message = [self.class objectValueToCommon:arguments[0]];

	LogToConsole("JavaScript: %{public}@", message);
}

- (void)_printDebugInformation:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	NSString *message = [self.class objectValueToCommon:arguments[0]];

	[context.associatedClient printDebugInformation:message inChannel:context.associatedChannel];
}

- (void)_printDebugInformationToConsole:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	NSString *message = [self.class objectValueToCommon:arguments[0]];

	[context.associatedClient printDebugInformationToConsole:message];
}

+ (NSArray<NSString *> *)preferencesReadableByStyles
{
	static NSArray<NSString *> *names = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		names = @[
			@"appearance",
			@"autoAddScrollbackMark",
			@"channelViewArrangement",
			@"conversationTrackingIncludesUserModeSymbol",
			@"copyOnSelect",
			@"developerModeEnabled",
			@"disableNicknameColorHashing",
			@"displayServerMOTD",
			@"highlightCurrentNickname",
			@"mainWindowTransparency",
			@"memberListDisplayNoModeSymbol",
			@"removeAllFormatting",
			@"rightToLeftFormatting",
			@"scrollbackVisibleLimit",
			@"showDateChanges",
			@"showInlineMedia",
			@"showJoinLeave",
			@"themeChannelViewFontName",
			@"themeChannelViewFontPreferenceUserConfigurable",
			@"themeChannelViewFontSize",
			@"themeChannelViewUsesCustomScrollers",
			@"themeName",
			@"themeNicknameFormat",
			@"themeNicknameFormatPreferenceUserConfigurable",
			@"themeTimestampFormat",
			@"themeTimestampFormatPreferenceUserConfigurable"
		];
	});

	return names;
}

+ (nullable id)valueOfPreferenceReadableByStyles:(NSString *)name
{
	NSParameterAssert(name != nil);

	if ([[self preferencesReadableByStyles] containsObject:name] == NO) {
		return nil;
	}

	/* Each name is an argument-less getter returning an object or a scalar,
	 which key-value coding boxes */
	return [[TPCPreferences class] valueForKey:name];
}

- (void)_retrievePreferencesWithMethodName:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	NSString *methodName = [self.class objectValueToCommon:arguments[0]];

	if ([methodName isKindOfClass:[NSString class]] == NO ||
		[[self.class preferencesReadableByStyles] containsObject:methodName] == NO)
	{
		[self.class throwJavaScriptException:@"Preference '%@' cannot be read by styles"
								   forCaller:context.caller
								   inWebView:context.webView, [methodName description]];

		context.completionBlock(nil);

		return;
	}

	context.completionBlock([self.class valueOfPreferenceReadableByStyles:methodName]);
}

- (void)_styleSettingsRetrieveValue:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	NSString *keyName = [self.class objectValueToCommon:arguments[0]];

	NSString *errorValue = nil;

	id result = [themeSettings() styleSettingsRetrieveValueForKey:keyName error:&errorValue];

	if (errorValue) {
		[self.class throwJavaScriptException:errorValue
								   forCaller:context.caller
								   inWebView:context.webView];
	}

	context.completionBlock( result );
}

- (void)_styleSettingsSetValue:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	NSString *keyName = [self.class objectValueToCommon:arguments[0]];

	id keyValue = [self.class objectValueToCommon:arguments[1]];

	NSString *errorValue = nil;
	
	BOOL result = [themeSettings() styleSettingsSetValue:keyValue forKey:keyName error:&errorValue];

	if (errorValue) {
		[self.class throwJavaScriptException:errorValue
								   forCaller:context.caller
								   inWebView:context.webView];
	}

	if (result) {
		[worldController() evaluateFunctionOnAllViews:@"Textual.styleSettingDidChange" arguments:@[keyName]];
	}

	context.completionBlock( @(result) );
}

@end

NS_ASSUME_NONNULL_END
