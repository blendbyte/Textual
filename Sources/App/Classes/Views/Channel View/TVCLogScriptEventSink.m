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
#import "WebScriptObjectHelperPrivate.h"
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
#import "TVCLogViewInternalWK1.h"
#import "TVCLogViewInternalWK2.h"
#import "TVCLogScriptEventSinkPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCLogScriptEventSink ()
@property (nonatomic, weak) TVCLogView *webView;
@end

@interface TVCLogScriptEventSinkContext : NSObject
@property (nonatomic, weak) TVCLogView *webView;
@property (readonly) TVCLogPolicy *webViewPolicy;
@property (readonly) TVCLogController *viewController;
@property (readonly) IRCClient *associatedClient;
@property (readonly, nullable) IRCChannel *associatedChannel;
@property (nonatomic, copy) NSString *caller;
@property (nonatomic, copy, nullable) NSArray *arguments;
@property (nonatomic, copy, nullable) void (^completionBlock)(id _Nullable returnValue);
@end

@implementation TVCLogScriptEventSink

- (instancetype)init
{
	return [self initWithWebView:nil];
}

- (instancetype)initWithWebView:(nullable TVCLogView *)webView
{
	if ((self = [super init])) {
		self.webView = webView;

		return self;
	}

	return nil;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector
{
	if (selector == @selector(init) ||
		selector == @selector(initWithWebView:) ||
		selector == @selector(webView) ||
		selector == @selector(webViewPolicy) ||
		selector == @selector(associatedClient) ||
		selector == @selector(associatedChannel) ||
		selector == @selector(objectValueToCommon:) ||
		selector == @selector(userContentController:didReceiveScriptMessage:) ||
		selector == @selector(processInputData:inWebView:withSelector:) ||
		selector == @selector(processInputData:inWebView:withSelector:minimumArgumentCount:withValidation:))
	{
		return YES;
	}

	if ([NSStringFromSelector(selector) hasPrefix:@"_"]) {
		return NO;
	}

	return NO;
}

+ (nullable NSString *)webScriptNameForSelector:(SEL)sel
{
	return nil;
}

- (id)invokeUndefinedMethodFromWebScript:(NSString *)name withArguments:(NSArray *)arguments
{
	SEL handlerSelector = NSSelectorFromString([name stringByAppendingString:@":inWebView:"]);

	if ([self respondsToSelector:handlerSelector] == NO) {
		return @(NO);
	}

	id argument = nil;

	if (arguments && arguments.count > 0) {
		argument = arguments[0];

TEXTUAL_IGNORE_WEBKIT_DEPRECATIONS_BEGIN
		if ([argument isKindOfClass:[WebScriptObject class]]) {
			argument = [self.webView webScriptObjectToCommon:argument];
		}
TEXTUAL_IGNORE_WEBKIT_DEPRECATIONS_END
	}

	NSMethodSignature *signature = [self methodSignatureForSelector:handlerSelector];

	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setTarget:self];

	[invocation setSelector:handlerSelector];
	[invocation setArgument:&argument atIndex:2];

	TVCLogView *webView = self.webView;
	[invocation setArgument:&webView atIndex:3];

	[invocation invoke];

	return @(YES);
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name
{
	return YES;
}

+ (nullable NSString *)webScriptNameForKey:(const char *)name
{
	return nil;
}

+ (nullable id)objectValueToCommon:(id)object
{
	if ([object isKindOfClass:[NSNull class]] ||
TEXTUAL_IGNORE_WEBKIT_DEPRECATIONS_BEGIN
		[object isKindOfClass:[WebUndefined class]])
TEXTUAL_IGNORE_WEBKIT_DEPRECATIONS_END
	{
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

	if ([self.class isSelectorExcludedFromWebScript:handlerSelector]) {
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
	} else if ([webView isKindOfClass:[TVCLogViewInternalWK1 class]] ||
			   [webView isKindOfClass:[TVCLogViewInternalWK2 class]])
	{
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
	else if ([inputData isKindOfClass:[NSNull class]] ||
TEXTUAL_IGNORE_WEBKIT_DEPRECATIONS_BEGIN
			 [inputData isKindOfClass:[WebUndefined class]])
TEXTUAL_IGNORE_WEBKIT_DEPRECATIONS_END
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

- (void)encryptionAuthenticateUser:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.encryptionAuthenticateUser()"
				 inWebView:webView
			  withSelector:@selector(_encryptionAuthenticateUser:)];
}

- (void)inlineMediaEnabledForView:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.inlineMediaEnabledForView()"
				 inWebView:webView
			  withSelector:@selector(_inlineMediaEnabledForView:)];
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

- (void)nicknameDoubleClicked:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.nicknameDoubleClicked()"
				 inWebView:webView
			  withSelector:@selector(_nicknameDoubleClicked:)];
}

- (void)notifyJumpToLineCallback:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.notifyJumpToLineCallback()"
				 inWebView:webView
			  withSelector:@selector(_notifyJumpToLineCallback:)
	  minimumArgumentCount:2
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				if (argumentIndex == 0) {
					return [argument isKindOfClass:[NSString class]];
				} else if (argumentIndex == 1 ||
						   argumentIndex == 2)
				{
					return [argument isKindOfClass:[NSNumber class]];
				}

				return NO;
			}];
}

- (void)notifyLinesAddedToView:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.notifyLinesAddedToView()"
				 inWebView:webView
			  withSelector:@selector(_notifyLinesAddedToView:)
	  minimumArgumentCount:1
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				return ([argument isKindOfClass:[NSArray class]] ||
						[argument isKindOfClass:[NSString class]]);
			}];
}

- (void)notifyLinesRemovedFromView:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.notifyLinesRemovedFromView()"
				 inWebView:webView
			  withSelector:@selector(_notifyLinesRemovedFromView:)
	  minimumArgumentCount:1
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				return ([argument isKindOfClass:[NSArray class]] ||
						[argument isKindOfClass:[NSString class]]);
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

- (void)renderMessagesBefore:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.renderMessagesBefore()"
				 inWebView:webView
			  withSelector:@selector(_renderMessagesBefore:)
	  minimumArgumentCount:2
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				if (argumentIndex == 0) {
					return [argument isKindOfClass:[NSString class]];
				} else if (argumentIndex == 1) {
					return [argument isKindOfClass:[NSNumber class]];
				}

				return NO;
			}];
}

- (void)renderMessagesAfter:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.renderMessagesAfter()"
				 inWebView:webView
			  withSelector:@selector(_renderMessagesAfter:)
	  minimumArgumentCount:2
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				if (argumentIndex == 0) {
					return [argument isKindOfClass:[NSString class]];
				} else if (argumentIndex == 1) {
					return [argument isKindOfClass:[NSNumber class]];
				}

				return NO;
			}];
}

- (void)renderMessagesInRange:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.renderMessagesInRange()"
				 inWebView:webView
			  withSelector:@selector(_renderMessagesInRange:)
	  minimumArgumentCount:3
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				if (argumentIndex == 0 ||
					argumentIndex == 1)
				{
					return [argument isKindOfClass:[NSString class]];
				} else if (argumentIndex == 2) {
					return [argument isKindOfClass:[NSNumber class]];
				}

				return NO;
			}];
}

- (void)renderMessageWithSiblings:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.renderMessageWithSiblings()"
				 inWebView:webView
			  withSelector:@selector(_renderMessageWithSiblings:)
	  minimumArgumentCount:3
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				if (argumentIndex == 0) {
					return [argument isKindOfClass:[NSString class]];
				} else if (argumentIndex == 1 ||
						   argumentIndex == 2)
				{
					return [argument isKindOfClass:[NSNumber class]];
				}

				return NO;
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

- (void)renderTemplate:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.renderTemplate()"
				 inWebView:webView
			  withSelector:@selector(_renderTemplate:)
	  minimumArgumentCount:1
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				if (argumentIndex == 0) {
					return [argument isKindOfClass:[NSString class]];
				} else if (argumentIndex == 1) {
					return ([argument isKindOfClass:[NSNull class]] ||
							[argument isKindOfClass:[NSDictionary class]]);
				}

				return NO;
			}];
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

- (void)setAutomaticScrollingEnabled:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.setAutomaticScrollingEnabled()"
				 inWebView:webView
			  withSelector:@selector(_setAutomaticScrollingEnabled:)
	  minimumArgumentCount:1
			withValidation:^BOOL(NSUInteger argumentIndex, id argument) {
				return ([argument isKindOfClass:[NSNumber class]]);
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

- (void)topicBarDoubleClicked:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.topicBarDoubleClicked()"
				 inWebView:webView
			  withSelector:@selector(_topicBarDoubleClicked:)];
}

- (void)finishedLayingOutView:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.finishedLayingOutView()"
				 inWebView:webView
			  withSelector:@selector(_finishedLayingOutView:)];
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

- (void)_encryptionAuthenticateUser:(TVCLogScriptEventSinkContext *)context
{
#if TEXTUAL_BUILT_WITH_ADVANCED_ENCRYPTION == 1
	IRCClient *client = context.associatedClient;

	if (client.isLoggedIn == NO) {
		return;
	}

	IRCChannel *channel = context.associatedChannel;

	if (channel == nil || channel.isPrivateMessage == NO) {
		[self.class throwJavaScriptException:@"View is not a private message"
								   forCaller:context.caller
								   inWebView:context.webView];

		return;
	}

	[client encryptionAuthenticateUser:channel.name];
#endif
}

- (void)_inlineMediaEnabledForView:(TVCLogScriptEventSinkContext *)context
{
	context.completionBlock( @(context.viewController.inlineMediaEnabledForView) );
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

- (void)_localUserHostmask:(TVCLogScriptEventSinkContext *)context
{
	context.completionBlock( context.associatedClient.userHostmask );
}

- (void)_localUserNickname:(TVCLogScriptEventSinkContext *)context
{
	context.completionBlock( context.associatedClient.userNickname );
}

- (void)_logToConsole:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	NSString *message = [self.class objectValueToCommon:arguments[0]];

	LogToConsole("JavaScript: %{public}@", message);
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

- (void)_nicknameDoubleClicked:(TVCLogScriptEventSinkContext *)context
{
	[context.webViewPolicy nicknameDoubleClicked];
}

- (void)_notifyJumpToLineCallback:(TVCLogScriptEventSinkContext *)context
{
	void (^contextCompletionBlock)(id _Nullable) = context.completionBlock;

	NSArray *arguments = context.arguments;

	NSString *lineNumber = [self.class objectValueToCommon:arguments[0]];

	lineNumber = [self.class standardizeLineNumber:lineNumber];

	if (lineNumber.length == 0) {
		[self.class throwJavaScriptException:@"Length of line number is 0"
								   forCaller:context.caller
								   inWebView:context.webView];

		contextCompletionBlock(nil);

		return;
	}

	BOOL successful = [[self.class objectValueToCommon:arguments[1]] boolValue];

	BOOL scrolledToBottom = [[self.class objectValueToCommon:arguments[2]] boolValue];

	[context.viewController notifyJumpToLine:lineNumber successful:successful scrolledToBottom:scrolledToBottom];
}

- (void)_notifyLinesAddedToView:(TVCLogScriptEventSinkContext *)context
{
	[self _notifyLinesAdded:YES context:context];
}

- (void)_notifyLinesRemovedFromView:(TVCLogScriptEventSinkContext *)context
{
	[self _notifyLinesAdded:NO context:context];
}

- (void)_notifyLinesAdded:(BOOL)added context:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	id lineNumbersUncut = [self.class objectValueToCommon:arguments[0]];

	if ([lineNumbersUncut isKindOfClass:[NSString class]]) {
		lineNumbersUncut = @[lineNumbersUncut];
	}

	NSArray *lineNumbers = [self.class standardizeLineNumbers:lineNumbersUncut];

	if (added) {
		[context.viewController notifyLinesAddedToView:[lineNumbers copy]];
	} else {
		[context.viewController notifyLinesRemovedFromView:[lineNumbers copy]];
	}
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

- (void)_renderMessagesBefore:(TVCLogScriptEventSinkContext *)context
{
	[self _renderMessagesAfter:NO context:context];
}

- (void)_renderMessagesAfter:(TVCLogScriptEventSinkContext *)context
{
	[self _renderMessagesAfter:YES context:context];
}

- (void)_renderMessagesAfter:(BOOL)after context:(TVCLogScriptEventSinkContext *)context
{
	void (^contextCompletionBlock)(id _Nullable) = context.completionBlock;

	NSArray *arguments = context.arguments;

	NSString *lineNumber = [self.class objectValueToCommon:arguments[0]];

	lineNumber = [self.class standardizeLineNumber:lineNumber];

	if (lineNumber.length == 0) {
		[self.class throwJavaScriptException:@"Length of line number is 0"
								   forCaller:context.caller
								   inWebView:context.webView];

		contextCompletionBlock(nil);

		return;
	}

	NSInteger maximumNumberOfLines = [[self.class objectValueToCommon:arguments[1]] integerValue];

	if (maximumNumberOfLines <= 0) {
		[self.class throwJavaScriptException:@"Maximum number of lines must be equal to 1 or greater"
								   forCaller:context.caller
								   inWebView:context.webView];

		contextCompletionBlock(nil);

		return;
	}

	void (^renderCompletionBlock)(NSArray *) = ^(NSArray<NSDictionary<NSString *, id> *> *renderedLogLines) {
		contextCompletionBlock(renderedLogLines);
	};

	if (after == NO) {
		[context.viewController renderLogLinesBeforeLineNumber:lineNumber
										  maximumNumberOfLines:maximumNumberOfLines
											   completionBlock:renderCompletionBlock];
	} else {
		[context.viewController renderLogLinesAfterLineNumber:lineNumber
										 maximumNumberOfLines:maximumNumberOfLines
											  completionBlock:renderCompletionBlock];
	}
}

- (void)_renderMessagesInRange:(TVCLogScriptEventSinkContext *)context
{
	void (^contextCompletionBlock)(id _Nullable) = context.completionBlock;

	NSArray *arguments = context.arguments;

	NSString *lineNumberAfter = [self.class objectValueToCommon:arguments[0]];
	NSString *lineNumberBefore = [self.class objectValueToCommon:arguments[1]];

	lineNumberAfter = [self.class standardizeLineNumber:lineNumberAfter];
	lineNumberBefore = [self.class standardizeLineNumber:lineNumberBefore];

	if (lineNumberAfter.length == 0 ||
		lineNumberBefore.length == 0)
	{
		[self.class throwJavaScriptException:@"Length of line number is 0"
								   forCaller:context.caller
								   inWebView:context.webView];

		contextCompletionBlock(nil);

		return;
	}

	NSInteger maximumNumberOfLines = [[self.class objectValueToCommon:arguments[2]] integerValue];

	if (maximumNumberOfLines < 0) {
		[self.class throwJavaScriptException:@"Maximum number of lines must be equal to 0 or greater"
								   forCaller:context.caller
								   inWebView:context.webView];

		contextCompletionBlock(nil);

		return;
	}

	void (^renderCompletionBlock)(NSArray *) = ^(NSArray<NSDictionary<NSString *, id> *> *renderedLogLines) {
		contextCompletionBlock(renderedLogLines);
	};

	[context.viewController renderLogLinesAfterLineNumber:lineNumberAfter
										 beforeLineNumber:lineNumberBefore
									 maximumNumberOfLines:maximumNumberOfLines
										  completionBlock:renderCompletionBlock];
}

- (void)_renderMessageWithSiblings:(TVCLogScriptEventSinkContext *)context
{
	void (^contextCompletionBlock)(id _Nullable) = context.completionBlock;

	NSArray *arguments = context.arguments;

	NSString *lineNumber = [self.class objectValueToCommon:arguments[0]];

	lineNumber = [self.class standardizeLineNumber:lineNumber];

	if (lineNumber.length == 0) {
		[self.class throwJavaScriptException:@"Length of line number is 0"
								   forCaller:context.caller
								   inWebView:context.webView];

		contextCompletionBlock(nil);

		return;
	}

	NSInteger numberOfLinesBefore = [[self.class objectValueToCommon:arguments[1]] integerValue];
	NSInteger numberOfLinesAfter = [[self.class objectValueToCommon:arguments[2]] integerValue];

	if (numberOfLinesBefore < 0 ||
		numberOfLinesAfter < 0)
	{
		[self.class throwJavaScriptException:@"Number of lines must be equal to 0 or greater"
								   forCaller:context.caller
								   inWebView:context.webView];

		contextCompletionBlock(nil);

		return;
	}

	void (^renderCompletionBlock)(NSArray *) = ^(NSArray<NSDictionary<NSString *, id> *> *renderedLogLines) {
		contextCompletionBlock(renderedLogLines);
	};

	[context.viewController renderLogLineAtLineNumber:lineNumber
								  numberOfLinesBefore:numberOfLinesBefore
								   numberOfLinesAfter:numberOfLinesAfter
									  completionBlock:renderCompletionBlock];
}

- (void)_renderTemplate:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	NSString *templateName = [self.class objectValueToCommon:arguments[0]];

	if (templateName.length == 0) {
		[self.class throwJavaScriptException:@"Length of template name is 0"
								   forCaller:context.caller
								   inWebView:context.webView];

		context.completionBlock(nil);

		return;
	}

	NSDictionary *templateAttributes = [self.class objectValueToCommon:arguments[1]];

	NSString *renderedTemplate = [TVCLogRenderer renderTemplateNamed:templateName attributes:templateAttributes];

	context.completionBlock( renderedTemplate );
}

/* The preferences styles may read with app.retrievePreferencesWithMethodName().
 Keep in sync with the list in scriptSink.js. Anything else is refused: the
 method used to call any class method of TPCPreferences. */
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

- (void)_setAutomaticScrollingEnabled:(TVCLogScriptEventSinkContext *)context
{
	NSArray *arguments = context.arguments;

	BOOL enabled = [[self.class objectValueToCommon:arguments[0]] boolValue];

	[context.webView setAutomaticScrollingEnabled:enabled];
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

- (void)_topicBarDoubleClicked:(TVCLogScriptEventSinkContext *)context
{
	[context.webViewPolicy topicBarDoubleClicked];
}

- (void)_finishedLayingOutView:(TVCLogScriptEventSinkContext *)context
{
	[context.webView setViewFinishedLayout];
}

@end

#pragma mark -

@implementation TVCLogScriptEventSinkContext

- (TVCLogController *)viewController
{
	return self.webView.viewController;
}

- (TVCLogPolicy *)webViewPolicy
{
	return self.webView.webViewPolicy;
}

- (IRCClient *)associatedClient
{
	return self.viewController.associatedClient;
}

- (nullable IRCChannel *)associatedChannel
{
	return self.viewController.associatedChannel;
}

@end

NS_ASSUME_NONNULL_END
