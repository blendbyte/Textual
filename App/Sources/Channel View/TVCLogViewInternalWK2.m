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


#import "IRCChannel.h"
#import "IRCClient.h"
#import "IRCConnectionProxyPrivate.h"
#import "TXAppearance.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesLocal.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCTheme.h"
#import "TPCThemeController.h"
#import "TVCLogController.h"
#import "TVCLogPolicyPrivate.h"
#import "TVCLogScriptEventSinkPrivate.h"
#import "TVCLogViewPrivate.h"
#import "TVCLogViewInternalWK2.h"
#import "TDCFileTransferDialogPrivate.h"
#import "ICLMediaSchemeHandlerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCLogViewInternalWK2 ()
@property (nonatomic, assign) BOOL t_observingLoadingProperty;
@end

@implementation TVCLogViewInternalWK2

static WKUserContentController *_sharedUserContentController = nil;
static WKWebViewConfiguration *_sharedWebViewConfiguration = nil;
static TVCLogPolicy *_sharedWebPolicy = nil;
static TVCLogScriptEventSink *_sharedWebViewScriptSink = nil;

/* Server identifier → that server's configuration. Each server has its own
 website data store so its views load inline media through its proxy. */
static NSMutableDictionary<NSString *, WKWebViewConfiguration *> *_clientWebViewConfigurations = nil;

/* Nothing in the chat view loads from the internet itself: media
 comes through textual-media: (ICLMediaSchemeHandler), everything else from
 the style and the app bundle. Pages wait until the rule list is in place. */
static NSString * const _remoteLoadsRuleListIdentifier = @"TextualChatViewRemoteLoads-1";

static BOOL _contentRulesReady = NO;
static NSMutableArray<dispatch_block_t> *_loadsWaitingForContentRules = nil;

#pragma mark -
#pragma mark Factory

+ (void)_t_initialize
{
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		/* Only public settings: the page reads its style's files through the
		 read access granted by -loadFileURL:allowingReadAccessToURL: (TVCLogView) */
		_sharedWebViewConfiguration = [WKWebViewConfiguration new];

		_sharedWebViewScriptSink = [TVCLogScriptEventSink new];

		_sharedUserContentController = [WKUserContentController new];

		for (NSString *name in [TVCLogScriptEventSink scriptHandlerNames]) {
			[_sharedUserContentController addScriptMessageHandler:(id)_sharedWebViewScriptSink name:name];
		}

		[self _t_addCoreScriptsToUserContentController:_sharedUserContentController];

		_sharedWebViewConfiguration.userContentController = _sharedUserContentController;

		_sharedWebPolicy = [TVCLogPolicy new];

		_clientWebViewConfigurations = [NSMutableDictionary dictionary];

		_loadsWaitingForContentRules = [NSMutableArray array];

		[self _t_addRemoteLoadsRuleList];
	});
}

/* Every http(s) and ws(s) load is blocked: scripts, frames, images, media,
 fonts, style sheets and requests. Content rule regular expressions have no
 alternation, hence two rules. */
+ (void)_t_addRemoteLoadsRuleList
{
	NSString *rules =
	@"["
	@"{\"trigger\":{\"url-filter\":\"^https?://\"},\"action\":{\"type\":\"block\"}},"
	@"{\"trigger\":{\"url-filter\":\"^wss?://\"},\"action\":{\"type\":\"block\"}}"
	@"]";

	[[WKContentRuleListStore defaultStore]
	 compileContentRuleListForIdentifier:_remoteLoadsRuleListIdentifier
				  encodedContentRuleList:rules
					   completionHandler:^(WKContentRuleList *ruleList, NSError *error) {
		 /* Called on the main thread */
		 if (ruleList) {
			 [_sharedUserContentController addContentRuleList:ruleList];
		 } else {
			 LogToConsoleError("Failed to compile the chat view's content rules: %{public}@", error.localizedDescription);
		 }

		 _contentRulesReady = YES;

		 NSArray<dispatch_block_t> *loads = [_loadsWaitingForContentRules copy];

		 [_loadsWaitingForContentRules removeAllObjects];

		 for (dispatch_block_t load in loads) {
			 load();
		 }
	 }];
}

+ (WKWebViewConfiguration *)_t_configurationForClient:(nullable IRCClient *)client
{
	if (client == nil) {
		return _sharedWebViewConfiguration;
	}

	NSString *clientIdentifier = client.uniqueIdentifier;

	WKWebViewConfiguration *configuration = _clientWebViewConfigurations[clientIdentifier];

	if (configuration == nil) {
		configuration = [_sharedWebViewConfiguration copy];

		configuration.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];

		/* Inline media of a server's views: fetched by Textual through its previews' session */
		[configuration setURLSchemeHandler:[ICLMediaSchemeHandler sharedHandler] forURLScheme:ICLMediaSchemeHandlerScheme];

		[IRCConnectionProxy applyClientConfig:client.config toWebsiteDataStore:configuration.websiteDataStore];

		_clientWebViewConfigurations[clientIdentifier] = configuration;
	}

	return configuration;
}

+ (void)applyProxyOfClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	WKWebViewConfiguration *configuration = _clientWebViewConfigurations[client.uniqueIdentifier];

	if (configuration == nil) {
		return;
	}

	[IRCConnectionProxy applyClientConfig:client.config toWebsiteDataStore:configuration.websiteDataStore];
}

+ (void)forgetClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	[_clientWebViewConfigurations removeObjectForKey:client.uniqueIdentifier];
}

/* The core JavaScript every view needs, in order, before the template's own scripts
 run (styles' scripts use it right away). Templates that still load core.js and
 call Textual.initializeCore() keep working: both are safe to run again. */
+ (void)_t_addCoreScriptsToUserContentController:(WKUserContentController *)userContentController
{
	NSParameterAssert(userContentController != nil);

	NSString *scriptsPath = [[TPCPathInfo applicationResources] stringByAppendingPathComponent:@"JavaScript/API"];

	NSArray<NSString *> *scripts = @[
		@"core.js",
		@"corePrivate.js",
		@"private/core/clickMenuSelection.js",
		@"private/core/documentBody.js",
		@"private/core/events.js",
		@"private/core/eventGroups.js",
		@"private/core/messageActions.js",
		@"private/core/inlineMedia.js",
		@"private/core/messageBuffer.js",
		@"private/core/scrollTo.js",
		@"private/scroller/state.js",
		@"private/scroller/automatic.js",
		@"private/conversationTracking.js",
		@"private/scriptSink.js"
	];

	for (NSString *script in scripts) {
		NSString *path = [scriptsPath stringByAppendingPathComponent:script];

		NSError *readError = nil;

		NSString *source = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&readError];

		if (source == nil) {
			LogToConsoleError("Failed to read core script %{public}@: %{public}@", script, readError.localizedDescription);

			continue;
		}

		WKUserScript *userScript =
		[[WKUserScript alloc] initWithSource:source
							   injectionTime:WKUserScriptInjectionTimeAtDocumentStart
							forMainFrameOnly:YES];

		[userContentController addUserScript:userScript];
	}
}

- (instancetype)initWithHostView:(TVCLogView *)hostView
{
	[self.class _t_initialize];

	WKWebViewConfiguration *configuration = [self.class _t_configurationForClient:hostView.viewController.associatedClient];

	if ((self = [self initWithFrame:NSZeroRect configuration:configuration])) {
		[self constructWebViewWithHostView:hostView];

		return self;
	}

	return nil;
}

- (void)constructWebViewWithHostView:(TVCLogView *)hostView
{
	NSParameterAssert(hostView != nil);

	self.t_parentView = hostView;

	self.allowsBackForwardNavigationGestures = NO;
	self.allowsMagnification = NO;

	self.translatesAutoresizingMaskIntoConstraints = NO;

	self.allowsLinkPreview = NO;

	self.customUserAgent = TVCLogViewCommonUserAgentString;

	self.navigationDelegate = (id)self;

	self.UIDelegate = (id)self;

	/* WebKit registers the old file name type only; added to its types */
	if ([self.registeredDraggedTypes containsObject:NSPasteboardTypeFileURL] == NO) {
		[self registerForDraggedTypes:[self.registeredDraggedTypes arrayByAddingObject:NSPasteboardTypeFileURL]];
	}

	[self applyThemeBackgroundColor];

	[self applyDeveloperMode];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(preferencesChanged:)
								   name:TPCPreferencesUserDefaultsDidChangeNotification
								 object:nil];
}

/* Web Inspector ("Inspect Element" in the context menu) only in Developer Mode */
- (void)applyDeveloperMode
{
	BOOL inspectable = [TPCPreferences developerModeEnabled];

	if (self.inspectable != inspectable) {
		self.inspectable = inspectable;
	}
}

- (void)preferencesChanged:(NSNotification *)notification
{
	if ([notification.userInfo[@"changedKey"] isEqualToString:@"TextualDeveloperEnvironment"] == NO) {
		return;
	}

	[self applyDeveloperMode];
}

- (void)applyThemeBackgroundColor
{
	BOOL dark = (theme().appearance == TPCThemeAppearanceTypeDark || themeSettings().underlyingWindowColorIsDark);

	NSColor *backgroundColor = themeSettings().underlyingWindowColor;

	if (backgroundColor == nil) {
		backgroundColor = ((dark) ? [NSColor blackColor] : [NSColor whiteColor]);
	}

	self.appearance = ((dark) ? [TXAppearancePropertyCollection appKitDarkAppearance] : [TXAppearancePropertyCollection appKitLightAppearance]);

	self.underPageBackgroundColor = backgroundColor;
}

- (void)dealloc
{
	/* A view released while loading never got its stopLoading */
	[self stopObservingLoadingProperty];

	[RZNotificationCenter() removeObserver:self name:TPCPreferencesUserDefaultsDidChangeNotification object:nil];

	self.navigationDelegate = nil;

	self.UIDelegate = nil;
}

- (TVCLogPolicy *)webViewPolicy
{
	return _sharedWebPolicy;
}

#pragma mark -
#pragma mark Load Overrides

- (nullable WKNavigation *)loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL
{
	[self startObservingLoadingProperty];

	if (_contentRulesReady == NO) {
		__weak typeof(self) weakSelf = self;

		[_loadsWaitingForContentRules addObject:^{
			[weakSelf _t_loadFileURL:URL allowingReadAccessToURL:readAccessURL];
		}];

		return nil;
	}

	return [super loadFileURL:URL allowingReadAccessToURL:readAccessURL];
}

- (void)_t_loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL
{
	(void)[super loadFileURL:URL allowingReadAccessToURL:readAccessURL];
}

- (nullable WKNavigation *)loadHTMLString:(NSString *)string baseURL:(nullable NSURL *)baseURL
{
	[self startObservingLoadingProperty];

	if (_contentRulesReady == NO) {
		__weak typeof(self) weakSelf = self;

		[_loadsWaitingForContentRules addObject:^{
			[weakSelf _t_loadHTMLString:string baseURL:baseURL];
		}];

		return nil;
	}

	return [super loadHTMLString:string baseURL:baseURL];
}

- (void)_t_loadHTMLString:(NSString *)string baseURL:(nullable NSURL *)baseURL
{
	(void)[super loadHTMLString:string baseURL:baseURL];
}

- (void)stopLoading
{
	[self stopObservingLoadingProperty];

	[super stopLoading];
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

/* Files dragged in from elsewhere are Textual's (the dropped files sheet):
 WebKit refuses them unless the page takes drops, so it never sees them.
 Drags that start in the view itself stay WebKit's. */
- (BOOL)isFileDragFromElsewhere:(nullable id <NSDraggingInfo>)sender
{
	if (sender == nil || sender.draggingSource == self) {
		return NO;
	}

	return ([TDCFileTransferDialog filePathsOnPasteboard:[sender draggingPasteboard]].count > 0);
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	if ([self isFileDragFromElsewhere:sender]) {
		return NSDragOperationCopy;
	}

	return [super draggingEntered:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	if ([self isFileDragFromElsewhere:sender]) {
		return NSDragOperationCopy;
	}

	return [super draggingUpdated:sender];
}

- (void)draggingExited:(nullable id <NSDraggingInfo>)sender
{
	if ([self isFileDragFromElsewhere:sender]) {
		return;
	}

	[super draggingExited:sender];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	if ([self isFileDragFromElsewhere:sender]) {
		return YES;
	}

	return [super prepareForDragOperation:sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	if ([self isFileDragFromElsewhere:sender]) {
		return [self.t_parentView performDragOperation:sender];
	}

	return [super performDragOperation:sender];
}

- (void)concludeDragOperation:(nullable id <NSDraggingInfo>)sender
{
	if ([self isFileDragFromElsewhere:sender]) {
		return;
	}

	[super concludeDragOperation:sender];
}

#pragma mark -
#pragma mark Utilities

+ (void)emptyCaches
{
	NSMutableArray<WKWebsiteDataStore *> *dataStores = [NSMutableArray array];

	if (_sharedWebViewConfiguration.websiteDataStore) {
		[dataStores addObject:_sharedWebViewConfiguration.websiteDataStore];
	}

	for (WKWebViewConfiguration *configuration in _clientWebViewConfigurations.allValues) {
		[dataStores addObject:configuration.websiteDataStore];
	}

	NSSet *itemsToRemove = [NSSet setWithArray:@[
		WKWebsiteDataTypeDiskCache,
		WKWebsiteDataTypeMemoryCache
	]];

	for (WKWebsiteDataStore *dataStore in dataStores) {
		[dataStore removeDataOfTypes:itemsToRemove
					   modifiedSince:[NSDate distantPast]
				   completionHandler:^{
			LogToConsoleDebug("WebKit2 cache cleared");
		}];
	}
}

- (void)startObservingLoadingProperty
{
	if (self.t_observingLoadingProperty) {
		return;
	}

	[self addObserver:self forKeyPath:@"loading" options:NSKeyValueObservingOptionNew context:NULL];

	self.t_observingLoadingProperty = YES;
}

- (void)stopObservingLoadingProperty
{
	if (self.t_observingLoadingProperty == NO) {
		return;
	}

	[self removeObserver:self forKeyPath:@"loading"];

	self.t_observingLoadingProperty = NO;
}

- (void)maybeInformDelegateWebViewFinishedLoading
{
	if (self.t_viewIsLoading == NO && self.t_viewIsNavigating == NO) {
		[self stopObservingLoadingProperty];

		[self.t_parentView performSelectorInCommonModes:@selector(informDelegateWebViewFinishedLoading) withObject:nil afterDelay:1.2];
	}
}

- (void)webViewClosedUnexpectedly
{
	[self.t_parentView informDelegateWebViewClosedUnexpectedly];
}

#pragma mark -
#pragma mark View Configuration

- (BOOL)maintainsInactiveSelection
{
	return YES;
}

#pragma mark -
#pragma mark JavaScript

- (void)logEvaluateJavaScriptError:(NSError *)error
{
	NSParameterAssert(error != nil);

	NSNumber *lineNumber = error.userInfo[@"WKJavaScriptExceptionLineNumber"];
	NSString *errorMessage = error.userInfo[@"WKJavaScriptExceptionMessage"];
	NSURL *sourceURL = error.userInfo[@"WKJavaScriptExceptionSourceURL"];

	NSString *channelName = self.t_parentView.viewController.associatedChannel.name;

	if (channelName == nil) {
		channelName = @"Server Console";
	}

	if (lineNumber == nil || errorMessage == nil || sourceURL == nil) {
		LogToConsoleError("JavaScript Error in %{private}@: %{public}@", channelName, error.localizedDescription);

		return;
	}

	LogToConsoleError("A JavaScript error occurred in %{public}@ on line %{public}ld of %{public}@: %{public}@",
		channelName, lineNumber.unsignedIntegerValue, sourceURL.standardizedTildePath, errorMessage);
}

- (void)_t_evaluateJavaScript:(NSString *)code completionHandler:(void (^ _Nullable)(id _Nullable))completionHandler
{
	NSParameterAssert(code != nil);

	[self evaluateJavaScript:code completionHandler:^(id _Nullable result, NSError * _Nullable error) {
		if (error) {
			[self logEvaluateJavaScriptError:error];
		}

		if (completionHandler) {
			completionHandler([result isKindOfClass:[NSNull class]] ? nil : result);
		}
	}];
}

#pragma mark -
#pragma mark Web View Delegate

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView
{
	NSParameterAssert(webView == self);

	LogToConsoleError("WebView [%{public}@] content process terminated; reloading", self.description);

	self.t_viewIsLoading = NO;
	self.t_viewIsNavigating = NO;

	[self stopObservingLoadingProperty];

	[self webViewClosedUnexpectedly];
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSString *, id> *)change context:(nullable void *)context
{
	NSParameterAssert(object == self);

	if ([keyPath isEqualToString:@"loading"]) {
		self.t_viewIsLoading = self.loading;

		[self maybeInformDelegateWebViewFinishedLoading];
	}
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
	NSParameterAssert(webView == self);

	[_sharedWebPolicy webView2:webView logView:self.t_parentView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
}

- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
	NSParameterAssert(webView == self);

	[_sharedWebPolicy webView2:webView logView:self.t_parentView didReceiveAuthenticationChallenge:challenge completionHandler:completionHandler];
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
	NSParameterAssert(webView == self);

	self.t_viewIsNavigating = YES;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
	NSParameterAssert(webView == self);

	self.t_viewIsNavigating = NO;

	[self maybeInformDelegateWebViewFinishedLoading];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
	NSParameterAssert(webView == self);

	[self navigationFailedWithError:error];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
	NSParameterAssert(webView == self);

	[self navigationFailedWithError:error];
}

/* Without this the view waited for the end of a navigation that had already
 failed and stayed blank. A failed page isn't loaded: it is loaded again. */
- (void)navigationFailedWithError:(NSError *)error
{
	NSParameterAssert(error != nil);

	/* A load replaced by the next one */
	if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
		return;
	}

	LogToConsoleError("WebView [%{public}@] failed to load: %{public}@", self.description, error.localizedDescription);

	self.t_viewIsLoading = NO;
	self.t_viewIsNavigating = NO;

	[self stopObservingLoadingProperty];

	[self.t_parentView informDelegateWebViewFailedLoading];
}

/* WebKit's own items (copy, look up, Inspect Element…) arrive in menu;
 Textual's menu, built from them, replaces its contents */
- (void)willOpenMenu:(NSMenu *)menu withEvent:(NSEvent *)event
{
	[super willOpenMenu:menu withEvent:event];

	NSMenu *contextMenu = [_sharedWebPolicy webView2:self logView:self.t_parentView contextMenuWithDefaultMenu:menu];

	NSArray<NSMenuItem *> *items = contextMenu.itemArray;

	[contextMenu removeAllItems];

	[menu removeAllItems];

	for (NSMenuItem *item in items) {
		[menu addItem:item];
	}
}

@end

NS_ASSUME_NONNULL_END
