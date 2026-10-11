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
#import "TDCFileTransferDialogPrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogScriptEventSinkPrivate.h"
#import "TVCLogViewPrivate.h"
#import "TVCLogViewInternalWK2.h"
#import "TVCMainWindowPrivate.h"
#import "TXWebsiteLinks.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCLogView ()
@property (nonatomic, strong) TVCLogViewInternalWK2 *webViewBacking;
@property (nonatomic, getter=isLayingOutView, readwrite) BOOL layingOutView;
@property (nonatomic, copy, nullable) NSString *documentFileName; // one per view, rewritten for every load
@property (nonatomic, copy, nullable) NSURL *documentFileURL; // where it was last written

- (void)removeDocumentFile;
@end

@implementation TVCLogView

NSString * const TVCLogViewCommonUserAgentString = @"Textual/1.0 (+" TXWebsiteLinkPreviews @")";

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
	[self removeDocumentFile];
}

- (void)removeDocumentFile
{
	NSURL *documentFileURL = self.documentFileURL;

	if (documentFileURL == nil) {
		return;
	}

	self.documentFileURL = nil;

	[RZFileManager() removeItemAtURL:documentFileURL error:NULL];
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

	NSArray *files = [TDCFileTransferDialog filePathsOnPasteboard:[sender draggingPasteboard]];

	if (files.count == 0) {
		return NO;
	}

	[self.viewController logViewWebViewReceivedDropWithFiles:files];

	return YES;
}

- (void)informDelegateWebViewFinishedLoading
{
	[self.viewController logViewWebViewFinishedLoading];
}

- (void)informDelegateWebViewFailedLoading
{
	[self.viewController logViewWebViewFailedLoading];
}

- (void)informDelegateWebViewClosedUnexpectedly
{
	[self.viewController logViewWebViewClosedUnexpectedly];
}

- (void)setViewFinishedLayout
{
	[self cancelPerformRequestsWithSelector:@selector(layoutWatchdogFired)];

	self.layingOutView = NO;
}

/* The page finishes layout about a second after it loads at the latest
 (events.js), and the document counts as loaded 1.2 seconds after that,
 so a healthy page is long done when this fires. It never fires before
 the document has loaded: an unloaded view stays covered. */
- (void)scheduleLayoutWatchdog
{
	[self cs_reschedulePerformSelectorInCommonModes:@selector(layoutWatchdogFired) withObject:nil afterDelay:1.5];
}

- (void)layoutWatchdogFired
{
	TVCLogController *viewController = self.viewController;

	if (self.layingOutView == NO || viewController.viewIsLoaded == NO) {
		return;
	}

	LogToConsoleError("Finishing layout of a channel view whose page didn't: %{public}@", viewController.description);

	self.layingOutView = NO;

	/* Bundled styles start the body hidden and show it from their own
	 Textual.viewBodyDidLoad(), which didn't run either */
	[self evaluateJavaScript:
	 @"try {"
	  "  if (window.Textual && Textual.fadeOutLoadingScreen) {"
	  "    Textual.fadeOutLoadingScreen(1.00, 0.95);"
	  "  } else {"
	  "    var body = document.getElementById('body');"
	  "    var loadingScreen = document.getElementById('loadingScreen');"
	  "    if (body) { body.style.opacity = 1; }"
	  "    if (loadingScreen) { loadingScreen.style.display = 'none'; }"
	  "  }"
	  "} catch (error) {}"];
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

+ (void)applyProxyOfClient:(IRCClient *)client
{
	[TVCLogViewInternalWK2 applyProxyOfClient:client];
}

+ (void)forgetClient:(IRCClient *)client
{
	[TVCLogViewInternalWK2 forgetClient:client];
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

	/* The previous document's callbacks are for a page that is going */
	[self cancelPerformRequestsWithSelector:@selector(informDelegateWebViewFinishedLoading)];
	[self cancelPerformRequestsWithSelector:@selector(layoutWatchdogFired)];

	/* The style may have changed */
	[self.webViewBacking applyThemeBackgroundColor];

	[self _loadHTMLString:string baseURL:baseURL];
}

- (void)_loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL
{
	NSParameterAssert(string != nil);
	NSParameterAssert(baseURL != nil);

	[self recreateTemporaryCopyOfThemeIfNecessary];

	WKWebView *webView = self.webViewBacking;

	if (self.documentFileName == nil) {
		self.documentFileName = [NSString stringWithFormat:@"%@.html", [NSString stringWithUUID]];
	}

	NSURL *filePath = [baseURL URLByAppendingPathComponent:self.documentFileName];

	/* Another style folder: the old file would stay behind */
	if (self.documentFileURL && [self.documentFileURL isEqual:filePath] == NO) {
		[self removeDocumentFile];
	}

	NSError *fileWriteError = nil;

	if ([string writeToURL:filePath atomically:YES encoding:NSUTF8StringEncoding error:&fileWriteError] == NO) {
		LogToConsoleError("Failed to write temporary file: %{public}@", fileWriteError.localizedDescription);

		/* Load it from memory instead of staying on the loading screen */
		[webView loadHTMLString:string baseURL:baseURL];

		return;
	}

	self.documentFileURL = filePath;

	/* The page reads its style, inline media resources in the app bundle and
	 custom styles; the sandbox, not this URL, limits what can be read */
	[webView loadFileURL:filePath
 allowingReadAccessToURL:[NSURL fileURLWithPath:@"/" isDirectory:YES]];
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

- (NSString *)compiledFunctionCall:(NSString *)function withArguments:(nullable NSArray *)arguments
{
	return [self.class compiledFunctionCall:function withArguments:arguments];
}

/* The arguments go in as JSON, which is valid JavaScript for any string (quotes,
 backslashes, line breaks, U+2028) and any nesting */
+ (NSString *)compiledFunctionCall:(NSString *)function withArguments:(nullable NSArray *)arguments
{
	NSParameterAssert(function != nil);

	NSString *argumentList = @"";

	if (arguments.count > 0) {
		NSData *data = [NSJSONSerialization dataWithJSONObject:[self JSONObjectForArgument:arguments] options:0 error:NULL];

		NSString *array = ((data) ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil);

		/* "[a,b]" becomes "a,b" */
		if (array.length >= 2) {
			argumentList = [array substringWithRange:NSMakeRange(1, (array.length - 2))];
		}
	}

	return [NSString stringWithFormat:@"%@(%@);\n", function, argumentList];
}

/* URLs as strings; what JSON can't hold (other objects, NaN) becomes null */
+ (id)JSONObjectForArgument:(id)object
{
	NSParameterAssert(object != nil);

	if ([object isKindOfClass:[NSURL class]]) {
		return [object absoluteString];
	}

	if ([object isKindOfClass:[NSString class]] || [object isKindOfClass:[NSNull class]]) {
		return object;
	}

	if ([object isKindOfClass:[NSNumber class]]) {
		return ((isfinite([object doubleValue])) ? object : [NSNull null]);
	}

	if ([object isKindOfClass:[NSArray class]]) {
		NSMutableArray *array = [NSMutableArray arrayWithCapacity:[object count]];

		for (id element in object) {
			[array addObject:[self JSONObjectForArgument:element]];
		}

		return array;
	}

	if ([object isKindOfClass:[NSDictionary class]]) {
		NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:[object count]];

		[object enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
			if ([key isKindOfClass:[NSString class]]) {
				dictionary[key] = [self JSONObjectForArgument:value];
			}
		}];

		return dictionary;
	}

	return [NSNull null];
}

@end

NS_ASSUME_NONNULL_END
