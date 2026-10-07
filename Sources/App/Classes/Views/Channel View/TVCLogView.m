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

#import "NSObjectHelperPrivate.h"
#import "TXMasterController.h"
#import "TPCApplicationInfo.h"
#import "TPCThemeControllerPrivate.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesLocal.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogScriptEventSinkPrivate.h"
#import "TVCLogViewPrivate.h"
#import "TVCLogViewInternalWK2.h"
#import "TVCMainWindowPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCLogView ()
@property (nonatomic, strong) TVCLogViewInternalWK2 *webViewBacking;
@property (nonatomic, getter=isLayingOutView, readwrite) BOOL layingOutView;
@end

@implementation TVCLogView

NSString * const TVCLogViewCommonUserAgentString = @"Textual/1.0 (+https://help.codeux.com/textual/Inline-Media-Scanner-User-Agent.kb)";

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithViewController:(TVCLogController *)viewController
{
	NSParameterAssert(viewController != nil);

	if ((self = [super init])) {
		self.viewController = viewController;

		[self constructWebView];

		return self;
	}

	return nil;
}

- (void)dealloc
{
	self.webViewBacking = nil;
}

+ (BOOL)webKit2Enabled
{
	return YES;
}

- (BOOL)isUsingWebKit2
{
	return YES;
}

- (void)constructWebView
{
	self.webViewBacking = [[TVCLogViewInternalWK2 alloc] initWithHostView:self];

	/* Nothing to show until the document has loaded and laid out,
	 which may wait until the view becomes visible (deferred loads) */
	self.layingOutView = YES;
}

- (void)copyContentString
{
	[self stringByEvaluatingFunction:@"Textual.documentHTML" completionHandler:^(NSString *result) {
		RZPasteboard().stringContent = result;
	}];
}

- (BOOL)hasSelection
{
	NSString *selection = self.selection;

	return (selection.length > 0);
}

- (void)clearSelection
{
	[self evaluateFunction:@"Textual.clearSelection"];
}

- (void)print
{
	// Printing is probably broken: <http://www.openradar.me/20217859>

	[self.webView print:nil];
}

- (BOOL)keyDown:(NSEvent *)e inView:(NSView *)view
{
	NSParameterAssert(e != nil);
	NSParameterAssert(view != nil);

	NSUInteger m = e.modifierFlags;

	BOOL cmd = ((m & NSEventModifierFlagCommand) == NSEventModifierFlagCommand);
	BOOL alt = ((m & NSEventModifierFlagOption) == NSEventModifierFlagOption);
	BOOL ctrl = ((m & NSEventModifierFlagControl) == NSEventModifierFlagControl);

	if (ctrl == NO && alt == NO && cmd == NO) {
		[self.viewController logViewWebViewKeyDown:e];

		return YES;
	}

	return NO;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSParameterAssert(sender != nil);

	NSURL *fileURL = [NSURL URLFromPasteboard:[sender draggingPasteboard]];

	if (fileURL) {
		NSString *filename = fileURL.path;

		[self.viewController logViewWebViewReceivedDropWithFile:filename];
	}

	return NO;
}

- (void)informDelegateWebViewFinishedLoading
{
	[self.viewController logViewWebViewFinishedLoading];
}

- (void)informDelegateWebViewClosedUnexpectedly
{
	[self.viewController logViewWebViewClosedUnexpectedly];
}

- (void)setViewFinishedLayout
{
	self.layingOutView = NO;
}

- (TVCLogPolicy *)webViewPolicy
{
	return [self.webViewBacking webViewPolicy];
}

- (NSView *)webView
{
	return self.webViewBacking;
}

@end

#pragma mark -

@implementation TVCLogView (TVCLogViewBackingProxy)

+ (void)emptyCaches
{
	[TVCLogViewInternalWK2 emptyCaches];
}

- (void)recreateTemporaryCopyOfThemeIfNecessary
{
	if (mainWindow().reloadingTheme) {
		return;
	}

	if ([TPCApplicationInfo timeIntervalSinceApplicationLaunch] < (2 * 60)) {
		return;
	}

	[themeController() recreateTemporaryCopyOfThemeIfNecessary];
}

- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL
{
	NSParameterAssert(string != nil);
	NSParameterAssert(baseURL != nil);

	self.layingOutView = YES;

	[self _loadHTMLString:string baseURL:baseURL];
}

- (void)_loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL
{
	NSParameterAssert(string != nil);
	NSParameterAssert(baseURL != nil);

	[self recreateTemporaryCopyOfThemeIfNecessary];

	WKWebView *webView = self.webViewBacking;

	NSString *filename = [NSString stringWithFormat:@"%@.html", [NSString stringWithUUID]];

	NSURL *filePath = [baseURL URLByAppendingPathComponent:filename];

	NSError *fileWriteError = nil;

	if ([string writeToURL:filePath atomically:NO encoding:NSUTF8StringEncoding error:&fileWriteError] == NO) {
		LogToConsoleError("Failed to write temporary file: %{public}@", fileWriteError.localizedDescription);

		return;
	}

	[webView loadFileURL:filePath
 allowingReadAccessToURL:themeController().temporaryURL];
}

- (void)stopLoading
{
	[self.webViewBacking stopLoading];
}

- (void)findString:(NSString *)searchString movingForward:(BOOL)movingForward
{
	NSParameterAssert(searchString != nil);

	[self.webViewBacking findString:searchString movingForward:movingForward];
}

@end

#pragma mark -

@implementation TVCLogView (TVCLogViewJavaScriptHandler)

- (void)evaluateJavaScript:(NSString *)code
{
	[self evaluateJavaScript:code completionHandler:nil];
}

- (void)evaluateJavaScript:(NSString *)code completionHandler:(void (^ _Nullable)(id _Nullable result))completionHandler
{
	NSParameterAssert(code != nil);

	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self.webViewBacking _t_evaluateJavaScript:code completionHandler:completionHandler];
	});
}

+ (NSString *)descriptionOfJavaScriptResult:(id)scriptResult
{
	NSParameterAssert(scriptResult != nil);

	if ([scriptResult isKindOfClass:[NSString class]])
	{
		return scriptResult;
	}
	else if ([scriptResult isKindOfClass:[NSArray class]] ||
			 [scriptResult isKindOfClass:[NSDictionary class]])
	{
		return [scriptResult description];
	}
	else if ([scriptResult isKindOfClass:[NSNumber class]])
	{
		if ([scriptResult isBooleanValue]) {
			if ([scriptResult boolValue]) {
				return @"true";
			} else {
				return @"false";
			}
		} else {
			return [scriptResult stringValue];
		}
	}
	else if ([scriptResult isKindOfClass:[NSNull class]])
	{
		return @"null";
	}
	else
	{
		return @"undefined";
	}
}

+ (NSString *)escapeJavaScriptString:(NSString *)string
{
	NSParameterAssert(string != nil);

	NSString *escapedString = string;

	escapedString = [escapedString stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
	escapedString = [escapedString stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
	escapedString = [escapedString stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
	escapedString = [escapedString stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];

	return escapedString;
}

- (void)evaluateFunction:(NSString *)function
{
	[self evaluateFunction:function withArguments:nil completionHandler:nil];
}

- (void)evaluateFunction:(NSString *)function withArguments:(nullable NSArray *)arguments
{
	[self evaluateFunction:function withArguments:arguments completionHandler:nil];
}

- (void)evaluateFunction:(NSString *)function withArguments:(nullable NSArray *)arguments completionHandler:(void (^ _Nullable)(id _Nullable result))completionHandler
{
	NSParameterAssert(function != nil);

	NSString *compiledScript = [self compiledFunctionCall:function withArguments:arguments];

	[self evaluateJavaScript:compiledScript completionHandler:completionHandler];
}

- (void)booleanByEvaluatingFunction:(NSString *)function completionHandler:(void (^ _Nullable)(BOOL result))completionHandler
{
	[self booleanByEvaluatingFunction:function withArguments:nil completionHandler:completionHandler];
}

- (void)booleanByEvaluatingFunction:(NSString *)function withArguments:(nullable NSArray *)arguments completionHandler:(void (^ _Nullable)(BOOL result))completionHandler
{
	[self evaluateFunction:function withArguments:arguments completionHandler:^(id result) {
		BOOL resultBool = NO;

		if (result && [result isKindOfClass:[NSNumber class]]) {
			resultBool = [result boolValue];
		}

		if (completionHandler) {
			completionHandler(resultBool);
		}
	}];
}

- (void)stringByEvaluatingFunction:(NSString *)function completionHandler:(void (^ _Nullable)(NSString * _Nullable result))completionHandler
{
	[self stringByEvaluatingFunction:function withArguments:nil completionHandler:completionHandler];
}

- (void)stringByEvaluatingFunction:(NSString *)function withArguments:(nullable NSArray *)arguments completionHandler:(void (^ _Nullable)(NSString * _Nullable result))completionHandler
{
	[self evaluateFunction:function withArguments:arguments completionHandler:^(id result) {
		NSString *resultString = nil;

		if (result && [result isKindOfClass:[NSString class]]) {
			resultString = result;
		}

		if (completionHandler) {
			completionHandler(resultString);
		}
	}];
}

- (void)arrayByEvaluatingFunction:(NSString *)function completionHandler:(void (^ _Nullable)(NSArray * _Nullable result))completionHandler
{
	[self arrayByEvaluatingFunction:function withArguments:nil completionHandler:completionHandler];
}

- (void)arrayByEvaluatingFunction:(NSString *)function withArguments:(nullable NSArray *)arguments completionHandler:(void (^ _Nullable)(NSArray * _Nullable result))completionHandler
{
	[self evaluateFunction:function withArguments:arguments completionHandler:^(id result) {
		NSArray *resultArray = nil;

		if (result && [result isKindOfClass:[NSArray class]]) {
			resultArray = result;
		}

		if (completionHandler) {
			completionHandler(resultArray);
		}
	}];
}

- (void)dictionaryByEvaluatingFunction:(NSString *)function completionHandler:(void (^ _Nullable)(NSDictionary<NSString *, id> * _Nullable result))completionHandler
{
	[self dictionaryByEvaluatingFunction:function withArguments:nil completionHandler:completionHandler];
}

- (void)dictionaryByEvaluatingFunction:(NSString *)function withArguments:(nullable NSArray *)arguments completionHandler:(void (^ _Nullable)(NSDictionary<NSString *, id> * _Nullable result))completionHandler
{
	[self evaluateFunction:function withArguments:arguments completionHandler:^(id result) {
		NSDictionary *resultDictionary = nil;

		if (result && [result isKindOfClass:[NSDictionary class]]) {
			resultDictionary = result;
		}

		if (completionHandler) {
			completionHandler(resultDictionary);
		}
	}];
}

- (void)logToJavaScriptConsole:(NSString *)message, ...
{
	NSParameterAssert(message != nil);
	
	va_list arguments;
	va_start(arguments, message);
	
	[TVCLogScriptEventSink logToJavaScriptConsole:message inWebView:self withArguments:arguments];
	
	va_end(arguments);
}

@end

#pragma mark -

@implementation TVCLogView (TVCLogViewJavaScriptHandlerPrivate)

- (NSString *)compileJavaScriptDictionaryArgument:(NSDictionary<NSString *, id> *)objects
{
	NSParameterAssert(objects != nil);

	NSMutableString *compiledScript = [NSMutableString string];

	[compiledScript appendString:@"{"];

	NSInteger lastIndex = (objects.count - 1);

	__block NSInteger currentIndex = 0;

	[objects enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
		/* Perform check to make sure the key we are using is actually a string. */
		if ([key isKindOfClass:[NSString class]] == NO) {
			LogToConsoleDebug("Silently ignoring non-string key: %{public}@", NSStringFromClass([key class]));

			return;
		}

		/* Add key and value to new object. */
		NSString *keyString = [self.class escapeJavaScriptString:key];

		NSString *objectString = [self compileJavaScriptGenericArgument:object];

		if (currentIndex == lastIndex) {
			[compiledScript appendFormat:@"\"%@\":%@", keyString, objectString];
		} else {
			[compiledScript appendFormat:@"\"%@\":%@, ", keyString, objectString];
		}

		currentIndex += 1;
	}];

	[compiledScript appendString:@"}"];

	return [compiledScript copy];
}

- (NSString *)compileJavaScriptArrayArgument:(NSArray *)objects
{
	NSParameterAssert(objects != nil);

	NSMutableString *compiledScript = [NSMutableString string];

	[compiledScript appendString:@"["];

	NSInteger lastIndex = (objects.count - 1);

	[objects enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
		NSString *objectString = [self compileJavaScriptGenericArgument:object];

		if (index == lastIndex) {
			[compiledScript appendString:objectString];
		} else {
			[compiledScript appendFormat:@"%@,", objectString];
		}
	}];

	[compiledScript appendString:@"]"];

	return [compiledScript copy];
}

- (NSString *)compileJavaScriptGenericArgument:(id)object
{
	NSParameterAssert(object != nil);

	if ([object isKindOfClass:[NSURL class]])
	{
		object = [object absoluteString];
	}

	if ([object isKindOfClass:[NSString class]])
	{
		NSString *objectEscaped = [self.class escapeJavaScriptString:object];

		return [NSString stringWithFormat:@"\"%@\"", objectEscaped];
	}
	else if ([object isKindOfClass:[NSNumber class]])
	{
		if ([object isBooleanValue]) {
			if ([object boolValue]) {
				return @"true";
			} else {
				return @"false";
			}
		} else {
			return [object stringValue];
		}
	}
	else if ([object isKindOfClass:[NSArray class]])
	{
		return [self compileJavaScriptArrayArgument:object];
	}
	else if ([object isKindOfClass:[NSDictionary class]])
	{
		return [self compileJavaScriptDictionaryArgument:object];
	}
	else if ([object isKindOfClass:[NSNull class]])
	{
		return @"null";
	}
	else
	{
		return @"undefined";
	}
}

- (NSString *)compiledFunctionCall:(NSString *)function withArguments:(nullable NSArray *)arguments
{
	NSParameterAssert(function != nil);

	NSMutableString *compiledScript = [NSMutableString string];

	[compiledScript appendFormat:@"%@(", function];

	if ( arguments) {
		NSUInteger argumentCount = arguments.count;

		for (NSUInteger i = 0; i < argumentCount; i++) {
			NSString *argument = [self compileJavaScriptGenericArgument:arguments[i]];

			[compiledScript appendString:argument];

			if (i < (argumentCount - 1)) {
				[compiledScript appendString:@","];
			}
		}
	}

	[compiledScript appendString:@");\n"];

	return [compiledScript copy];
}

@end

NS_ASSUME_NONNULL_END
