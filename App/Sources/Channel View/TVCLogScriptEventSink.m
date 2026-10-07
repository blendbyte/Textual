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

@implementation TVCLogScriptEventSink

+ (BOOL)isSelectorExcludedFromScripts:(SEL)selector
{
	if (selector == @selector(init) ||
		selector == @selector(webViewPolicy) ||
		selector == @selector(associatedClient) ||
		selector == @selector(associatedChannel) ||
		selector == @selector(objectValueToCommon:) ||
		selector == @selector(userContentController:didReceiveScriptMessage:) ||
		selector == @selector(processInputData:forCaller:inWebView:withSelector:) ||
		selector == @selector(processInputData:forCaller:inWebView:withSelector:minimumArgumentCount:withValidation:))
	{
		return YES;
	}

	if ([NSStringFromSelector(selector) hasPrefix:@"_"]) {
		return NO;
	}

	return NO;
}

+ (nullable id)objectValueToCommon:(id)object
{
	if ([object isKindOfClass:[NSNull class]]) {
		return nil;
	}

	if ([object isKindOfClass:[NSString class]]) {
		return [object gtm_stringByUnescapingFromHTML];
	}

	return object;
}

+ (NSString *)standardizeLineNumber:(NSString *)lineNumber
{
	NSParameterAssert(lineNumber != nil);

	if ([lineNumber hasPrefix:@"line-"]) {
		return [lineNumber substringFromIndex:5];
	}

	return lineNumber;
}

+ (NSArray<NSString *> *)standardizeLineNumbers:(NSArray<NSString *> *)lineNumbers
{
	NSParameterAssert(lineNumbers != nil);

	NSMutableArray<NSString *> *lineNumbersOut = [NSMutableArray arrayWithCapacity:lineNumbers.count];

	for (NSString *lineNumber in lineNumbers) {
		[lineNumbersOut addObject:
		 [self standardizeLineNumber:lineNumber]];
	}

	return [lineNumbersOut copy];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
	/* Only the style's own page may use the bridge: not inline media and
	 other subframes, and nothing loaded from elsewhere. */
	WKFrameInfo *frameInfo = message.frameInfo;

	if (frameInfo.isMainFrame == NO || [frameInfo.securityOrigin.protocol isEqualToString:@"file"] == NO) {
		LogToConsoleDebug("Ignored '%{public}@' from a subframe or a page that isn't the style's", message.name);

		return;
	}

	NSString *handlerName = message.name;

	SEL handlerSelector = NSSelectorFromString([handlerName stringByAppendingString:@":inWebView:"]);

	if ([self respondsToSelector:handlerSelector] == NO) {
		return;
	}

	if ([self.class isSelectorExcludedFromScripts:handlerSelector]) {
		return;
	}

	NSMethodSignature *signature = [self methodSignatureForSelector:handlerSelector];

	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setTarget:self];
	[invocation setSelector:handlerSelector];

	id body = message.body;
	[invocation setArgument:&body atIndex:2];

	WKWebView *webView = message.webView;
	[invocation setArgument:&webView atIndex:3];

	[invocation invoke];
}

- (void)processInputData:(id)inputData
			   forCaller:(NSString *)caller
			   inWebView:(id)webView
			withSelector:(SEL)selector
{
	[self processInputData:inputData
				 forCaller:caller
				 inWebView:webView
			  withSelector:selector
	  minimumArgumentCount:0
			withValidation:nil];
}

- (void)processInputData:(id)inputData
			   forCaller:(NSString *)caller
			   inWebView:(id)webView
			withSelector:(SEL)selector
	minimumArgumentCount:(NSUInteger)minimumArgumentCount
		  withValidation:(BOOL (NS_NOESCAPE ^ _Nullable)(NSUInteger argumentIndex, id argument))validateArgumentBlock
{
	TVCLogView *intWebView = nil;

	if ([webView isKindOfClass:[TVCLogView class]]) {
		intWebView = webView;
	} else if ([webView isKindOfClass:[TVCLogViewInternalWK2 class]]) {
		intWebView = [webView t_parentView];
	} else {
		return;
	}

	/* -t_parentView in TVCLogViewInternalWK2 is maintained
	 as a weak reference. That means that a race condition for
	 WebKit2 is possible. A script event is received, is invoked
	 on this function, and while it is waiting to be invoked,
	 another thread deconstructs the parent view. */
	if (intWebView == nil) {
		LogToConsoleFault("(intWebView == nil) condition faulted. \
						  Possible race condition. \
						  Invoking '%{public}@'", NSStringFromSelector(selector));

		return;
	}

	NSInteger promiseIndex = (-1);

	NSArray *values = nil;

	/* Extract relevant information from inputData */
	if ([inputData isKindOfClass:[NSDictionary class]]) {
		/* Check that the object exists in the dictionary before
		 setting the value. If the object does not exist and we
		 do not do this, then -integerValue will return 0 which
		 is considered a valid promiseIndex value. */
		id promiseIndexObj = [inputData valueForKey:@"promiseIndex"];

		if (promiseIndexObj) {
			if ([promiseIndexObj isKindOfClass:[NSNumber class]] == NO) {
				[self.class throwJavaScriptException:@"'promiseIndex' must be a number"
										   forCaller:caller
										   inWebView:intWebView];

				return;
			}

			promiseIndex = [promiseIndexObj integerValue];
		}

		/* Values should always be in an array */
		if (minimumArgumentCount > 0) {
			id valuesObj = [inputData valueForKey:@"values"];

			if (valuesObj == nil || [valuesObj isKindOfClass:[NSArray class]] == NO) {
				[self.class throwJavaScriptException:@"'values' must be an array"
										   forCaller:caller
										   inWebView:intWebView];

				return;
			} else {
				values = valuesObj;
			}
		}
	}
	else if ([inputData isKindOfClass:[NSString class]] ||
			 [inputData isKindOfClass:[NSNumber class]])
	{
		if (minimumArgumentCount > 0) {
			values = @[inputData];
		}
	}
	else if ([inputData isKindOfClass:[NSArray class]])
	{
		if (minimumArgumentCount > 0) {
			values = inputData;
		}
	}
	else if ([inputData isKindOfClass:[NSNull class]])
	{
		if (minimumArgumentCount > 0) {
			values = @[[NSNull null]];
		}
	}

	/* Perform validation if needed */
	if (minimumArgumentCount > 0 && values.count < minimumArgumentCount) {
		[self.class throwJavaScriptException:@"Minimum number of arguments (%lu) condition not met"
								   forCaller:caller
								   inWebView:intWebView, minimumArgumentCount];

		return;
	}

	if (validateArgumentBlock) {
		__block BOOL validationPassed = YES;

		[values enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
			if (validateArgumentBlock(index, object) == NO) {
				validationPassed = NO;

				*stop = YES;
			}
		}];

		if (validationPassed == NO) {
			[self.class throwJavaScriptException:@"Invalid argument type(s)"
									   forCaller:caller
									   inWebView:intWebView];

			return;
		}
	}

	/* Pass validated data to selector */
	TVCLogScriptEventSinkContext *context = [TVCLogScriptEventSinkContext new];

	context.webView = intWebView;

	context.caller = caller;

	context.arguments = values;

	/* Handlers call the completion block unconditionally */
	void (^completionBlock)(id) = ^(id _Nullable returnValue) {};

	if (promiseIndex >= 0) {
		__weak typeof(intWebView) intWebViewWeak = intWebView;

		completionBlock = ^(id _Nullable returnValue) {
			if (returnValue == nil) {
				returnValue = [NSNull null];
			}

			[intWebViewWeak evaluateFunction:@"appInternal.promiseKept"
							   withArguments:@[@(promiseIndex), returnValue]];
		};
	}

	context.completionBlock = completionBlock;

	NSMethodSignature *signature = [self methodSignatureForSelector:selector];

	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setTarget:self];
	[invocation setSelector:selector];

	[invocation setArgument:&context atIndex:2];

	[invocation invoke];
}

+ (void)logToJavaScriptConsole:(NSString *)message inWebView:(TVCLogView *)webView, ...
{
	NSParameterAssert(message != nil);
	NSParameterAssert(webView != nil);
	
	va_list arguments;
	va_start(arguments, webView);

	[self logToJavaScriptConsole:message inWebView:webView withArguments:arguments];
	
	va_end(arguments);
}

+ (void)logToJavaScriptConsole:(NSString *)message inWebView:(TVCLogView *)webView withArguments:(va_list)arguments
{
	NSParameterAssert(message != nil);
	NSParameterAssert(webView != nil);
	NSParameterAssert(arguments != NULL);

	NSString *messageFormatted = [[NSString alloc] initWithFormat:message arguments:arguments];

	[webView evaluateFunction:@"console.log" withArguments:@[messageFormatted]];
}

+ (void)throwJavaScriptException:(NSString *)message inWebView:(TVCLogView *)webView, ...
{
	NSParameterAssert(message != nil);
	NSParameterAssert(webView != nil);

	va_list arguments;
	va_start(arguments, webView);
	
	[self throwJavaScriptException:message
						 forCaller:nil
						 inWebView:webView
					 withArguments:arguments];
	
	va_end(arguments);
}

+ (void)throwJavaScriptException:(NSString *)message forCaller:(nullable NSString *)caller inWebView:(TVCLogView *)webView, ...
{
	NSParameterAssert(message != nil);
	NSParameterAssert(webView != nil);

	va_list arguments;
	va_start(arguments, webView);
	
	[self throwJavaScriptException:message
						 forCaller:caller
						 inWebView:webView
					 withArguments:arguments];
	
	va_end(arguments);
}

+ (void)throwJavaScriptException:(NSString *)message forCaller:(nullable NSString *)caller inWebView:(TVCLogView *)webView withArguments:(va_list)arguments
{
	NSParameterAssert(message != nil);
	NSParameterAssert(webView != nil);
	NSParameterAssert(arguments != NULL);

	NSString *messageFormatted = [[NSString alloc] initWithFormat:message arguments:arguments];

	if (caller) {
		messageFormatted = [NSString stringWithFormat:@"Bridged function %@ returned error: %@", caller, messageFormatted];
	}

	[webView evaluateFunction:@"console.error" withArguments:@[messageFormatted]];
}

/* The preferences styles may read with app.retrievePreferencesWithMethodName().
 Keep in sync with the list in scriptSink.js. Anything else is refused: the
 method used to call any class method of TPCPreferences. */

@end

NS_ASSUME_NONNULL_END
