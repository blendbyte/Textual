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

@implementation TVCLogScriptEventSink (Rendering)

#pragma mark -
#pragma mark Private Implementation

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

- (void)finishedLayingOutView:(id)inputData inWebView:(id)webView
{
	[self processInputData:inputData
				 forCaller:@"app.finishedLayingOutView()"
				 inWebView:webView
			  withSelector:@selector(_finishedLayingOutView:)];
}

#pragma mark -
#pragma mark Private Implementation

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

- (void)_finishedLayingOutView:(TVCLogScriptEventSinkContext *)context
{
	[context.webView setViewFinishedLayout];
}

@end

NS_ASSUME_NONNULL_END
