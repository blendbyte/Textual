/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
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

TEXTUAL_IGNORE_WEBKIT_DEPRECATIONS_BEGIN

#include <objc/message.h>

#import "TPCThemeController.h"
#import "TPCTheme.h"
#import "TVCLogController.h"
#import "TVCLogPolicyPrivate.h"
#import "TVCLogScriptEventSinkPrivate.h"
#import "TVCLogViewPrivate.h"
#import "TVCWK1AutoScrollerPrivate.h"
#import "TVCLogViewInternalWK1.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCLogViewInternalWK1 ()
@property (nonatomic, strong) TVCWK1AutoScroller *autoScroller;
@property (nonatomic, readwrite, strong) TVCLogScriptEventSink *webViewScriptSink;
@end

static WebPreferences *_sharedWebViewPreferences = nil;
static TVCLogPolicy *_sharedWebPolicy = nil;

@implementation TVCLogViewInternalWK1

#pragma mark -
#pragma mark Factory

+ (void)_t_initialize
{
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		_sharedWebViewPreferences = [[WebPreferences alloc] initWithIdentifier:@"TVCLogViewInternalWK1SharedWebPreferencesObject"];

		_sharedWebViewPreferences.cacheModel = WebCacheModelDocumentViewer;
		_sharedWebViewPreferences.usesPageCache = NO;

		SEL selector = @selector(setShouldRespectImageOrientation:);

		if ([_sharedWebViewPreferences respondsToSelector:selector]) {
			NSMethodSignature *signature = [_sharedWebViewPreferences methodSignatureForSelector:selector];

			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

			[invocation setTarget:_sharedWebViewPreferences];
			[invocation setSelector:selector];

			BOOL yes = YES;
			[invocation setArgument:&yes atIndex:2];

			[invocation invoke];
		}

		_sharedWebPolicy = [TVCLogPolicy new];
	});
}

- (instancetype)initWithHostView:(TVCLogView *)hostView
{
	[self.class _t_initialize];

	if ((self = [self initWithFrame:NSZeroRect])) {
		[self constructWebViewWithHostView:hostView];

		return self;
	}

	return nil;
}

- (void)constructWebViewWithHostView:(TVCLogView *)hostView
{
	NSParameterAssert(hostView != nil);

	self.t_parentView = hostView;

	TVCLogScriptEventSink *webViewScriptSink =
	[[TVCLogScriptEventSink alloc] initWithWebView:hostView];

	self.webViewScriptSink = webViewScriptSink;

	self.preferences = _sharedWebViewPreferences;

	self.translatesAutoresizingMaskIntoConstraints = NO;

	self.customUserAgent = TVCLogViewCommonUserAgentString;

	self.frameLoadDelegate = (id)self;
	self.policyDelegate = (id)self;
	self.resourceLoadDelegate = (id)self;
	self.UIDelegate = (id)self;

	self.shouldUpdateWhileOffscreen = NO;

	[self updateBackgroundColor];
}

- (void)dealloc
{
	self.frameLoadDelegate = nil;
	self.policyDelegate = nil;
	self.resourceLoadDelegate = nil;
	self.UIDelegate = nil;
}

- (TVCLogPolicy *)webViewPolicy
{
	return _sharedWebPolicy;
}

#pragma mark -
#pragma mark View Events

- (void)keyDown:(NSEvent *)e
{
	if ([self.t_parentView keyDown:e inView:self]) {
		return;
	}

	[super keyDown:e];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return [self.t_parentView performDragOperation:sender];
}

#pragma mark -
#pragma mark Utilities

+ (void)emptyCaches
{
	LogToConsoleDebug("WebKit cache cleared");
}

- (void)updateBackgroundColor
{
	NSColor *windowColor = themeSettings().underlyingWindowColor;

	if (windowColor == nil) {
		windowColor = [NSColor blackColor];
	}

	[(id)self setBackgroundColor:windowColor];
}

- (void)maybeInformDelegateWebViewFinishedLoading
{
	if (self.t_viewHasLoaded == NO || self.t_viewHasScriptObject == NO) {
		return;
	}

	[self.t_parentView performSelectorInCommonModes:@selector(informDelegateWebViewFinishedLoading) withObject:nil afterDelay:1.2];

	[self constructAutoScroller];
}

- (void)findString:(NSString *)searchString movingForward:(BOOL)movingForward
{
	NSParameterAssert(searchString != nil);

	[self searchFor:searchString direction:movingForward caseSensitive:NO wrap:YES];
}

#pragma mark -
#pragma mark View Configuration

- (BOOL)maintainsInactiveSelection
{
	return YES;
}

#pragma mark -
#pragma mark JavaScript

- (void)_t_evaluateJavaScript:(NSString *)code completionHandler:(void (^ _Nullable)(id _Nullable))completionHandler
{
	NSParameterAssert(code != nil);

	WebScriptObject *scriptObject = self.windowScriptObject;

	if (scriptObject == nil || [scriptObject isKindOfClass:[WebUndefined class]]) {
		if (completionHandler) {
			completionHandler(nil);

			return;
		}
	}

	id scriptResult = [scriptObject evaluateWebScript:code];

	if (scriptResult) {
		if ([scriptResult isKindOfClass:[NSNull class]] ||
			[scriptResult isKindOfClass:[WebUndefined class]])
		{
			if (completionHandler) {
				completionHandler(nil);

				return;
			}
		}
		else if ([scriptResult isKindOfClass:[WebScriptObject class]])
		{
			scriptResult = [self.t_parentView webScriptObjectToCommon:scriptResult];
		}
	}

	if (completionHandler) {
		completionHandler(scriptResult);
	}
}

#pragma mark -
#pragma mark Scroll View

- (void)enableOffScreenUpdates
{
	self.shouldUpdateWhileOffscreen = YES;
}

- (void)disableOffScreenUpdates
{
	self.shouldUpdateWhileOffscreen = NO;
}

- (void)redrawViewIfNeeded
{
	/* The WebView is layer backed which means it is not redrawn unless it is told to do so.
	 TVCWK1AutoScroller automatically tells it to do so if it scrolled programmatically or
	 by the end user. When there is not enough content to scroll, the WebView is not redrawn
	 because there is never a scroll event triggered. Therefore, this call exists to tell
	 TVCWK1AutoScroller that we are interested in a redraw and it will then take appropriate
	 actions depending on whether one is necessary or not. */
	if (self.t_parentView.viewController.visible == NO) {
		return;
	}

	if (self.autoScroller.canScroll == NO) {
		[self.autoScroller redrawFrame];
	}
}

- (void)redrawView
{
	if (self.t_parentView.viewController.visible == NO) {
		return;
	}

	[self.autoScroller redrawFrame];
}

- (void)resetScrollerPosition
{
	[self.autoScroller restoreScrollerPosition];
}

- (void)resetScrollerPositionTo:(BOOL)scrolledToBottom
{
	[self.autoScroller resetScrollerPositionTo:scrolledToBottom];
}

- (void)saveScrollerPosition
{
	[self.autoScroller saveScrollerPosition];
}

- (void)restoreScrollerPosition
{
	[self.autoScroller restoreScrollerPosition];
}

- (void)constructAutoScroller
{
	WebFrameView *frameView = self.mainFrame.frameView;

	self.autoScroller = [[TVCWK1AutoScroller alloc] initWitFrameView:frameView];
}

- (void)setAutomaticScrollingEnabled:(BOOL)automaticScrollingEnabled
{
	self.autoScroller.automaticScrollingEnabled = automaticScrollingEnabled;
}

#pragma mark -
#pragma mark Web View Delegate

- (NSArray *)webView:(WebView *)webView contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	NSParameterAssert(webView == self);

	return [_sharedWebPolicy webView1:webView logView:self.t_parentView contextMenuWithDefaultMenuItems:defaultMenuItems];
}

- (NSUInteger)webView:(WebView *)webView dragDestinationActionMaskForDraggingInfo:(id<NSDraggingInfo>)draggingInfo
{
	NSParameterAssert(webView == self);

	return [_sharedWebPolicy webView1:webView logView:self.t_parentView dragDestinationActionMaskForDraggingInfo:draggingInfo];
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener
{
	NSParameterAssert(webView == self);

	[_sharedWebPolicy webView1:webView logView:self.t_parentView decidePolicyForNavigationAction:actionInformation request:request frame:frame decisionListener:listener];
}

- (void)webView:(WebView *)webView resource:(id)identifier didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge fromDataSource:(WebDataSource *)dataSource
{
	NSParameterAssert(webView == self);

	[_sharedWebPolicy webView1:webView logView:self.t_parentView resource:identifier didReceiveAuthenticationChallenge:challenge fromDataSource:dataSource];
}

- (void)webView:(WebView *)webView didClearWindowObject:(WebScriptObject *)windowObject forFrame:(WebFrame *)frame
{
	NSParameterAssert(webView == self);

	/* Only the style's own page gets the bridge: not inline media and other
	 subframes, and nothing loaded from elsewhere. */
	if (frame != self.mainFrame) {
		return;
	}

	NSURL *frameURL = frame.dataSource.request.URL;

	if ([_sharedWebPolicy isStylePageURL:frameURL] == NO) {
		LogToConsoleDebug("Not giving the bridge to a page that isn't the style's: %{private}@", frameURL.absoluteString);

		return;
	}

	self.t_viewHasScriptObject = YES;

	[windowObject setValue:self.webViewScriptSink forKey:@"TextualScriptSink"];

	[self maybeInformDelegateWebViewFinishedLoading];
}

- (void)webView:(WebView *)webView didFinishLoadForFrame:(WebFrame *)frame
{
	NSParameterAssert(webView == self);

	self.t_viewHasLoaded = YES;

	[self maybeInformDelegateWebViewFinishedLoading];

	[self updateBackgroundColor];
}

@end

NS_ASSUME_NONNULL_END

TEXTUAL_IGNORE_WEBKIT_DEPRECATIONS_END
