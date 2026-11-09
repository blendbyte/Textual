/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2026 Codeux Software, LLC & respective contributors.
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
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 *********************************************************************** */

#import <WebKit/WebKit.h>

#import "GTMEncodeHTML.h"
#import "TXGlobalModels.h"
#import "TLOLocalization.h"
#import "TPCNicknameColorStyleGeneratorPrivate.h"
#import "TPCPathInfo.h"
#import "TPCPathInfoPrivate.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCThemeControllerPrivate.h"
#import "TPCThemePrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogRenderer.h"
#import "TVCLogViewInternalWK2.h"
#import "TVCMainWindowPrivate.h"
#import "TXAppearance.h"
#import "TDCSettingsBridgePrivate.h"
#import "TDCStylePreviewRendererPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* About as much chat as a card shows, at a size that stays sharp when scaled to it */
static CGFloat const _previewWidth = 460.0;
static CGFloat const _previewHeight = 380.0;
static CGFloat const _previewPixelWidth = 690.0;

/* A style that never finishes loading must not hold up the others */
static NSTimeInterval const _previewRenderTimeout = 8.0;

@interface TDCStylePreviewRenderer () <WKNavigationDelegate>
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSImage *> *images;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *requestedGenerations;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *queue;
@property (nonatomic, assign) NSUInteger generation;
@property (nonatomic, copy, nullable) NSString *renderingFilename;
@property (nonatomic, assign) NSUInteger renderingToken;
@property (nonatomic, strong, nullable) WKNavigation *renderingNavigation;
@property (nonatomic, copy, nullable) NSString *renderingBuffer;
@property (nonatomic, copy, nullable) NSString *renderingStylePath;
@property (nonatomic, strong, nullable) WKWebView *webView;
@property (nonatomic, assign) BOOL preparingWebView;
@end

@implementation TDCStylePreviewRenderer

+ (TDCStylePreviewRenderer *)sharedRenderer
{
	static TDCStylePreviewRenderer *sharedRenderer = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedRenderer = [self new];
	});

	return sharedRenderer;
}

- (instancetype)init
{
	if ((self = [super init])) {
		self.images = [NSMutableDictionary dictionary];
		self.requestedGenerations = [NSMutableDictionary dictionary];
		self.queue = [NSMutableArray array];

		self.generation = 1;

		[RZNotificationCenter() addObserver:self selector:@selector(_themeDidReload:) name:TVCMainWindowDidReloadThemeNotification object:nil];

		[self _removePicturesOfRealChats];

		return self;
	}

	return nil;
}

/* Earlier builds kept pictures of the chat on screen here */
- (void)_removePicturesOfRealChats
{
	NSString *folder = [TPCPathInfo applicationSupport];

	if (folder == nil) {
		return;
	}

	[RZFileManager() removeItemAtPath:[folder stringByAppendingPathComponent:@"Style Previews"] error:NULL];
}

/* Chat or Classic, the font, the spacing and light or dark all reload the style */
- (void)_themeDidReload:(NSNotification *)notification
{
	self.generation += 1;

	[self.queue removeAllObjects];

	[RZNotificationCenter() postNotificationName:TDCSettingsBridgeStylePreviewsDidChangeNotification object:nil];
}

- (nullable NSImage *)previewForStyleNamed:(NSString *)name location:(NSInteger)location
{
	NSParameterAssert(name != nil);

	NSString *filename = [TPCThemeController buildFilename:name forStorageLocation:location];

	if (filename == nil) {
		return nil;
	}

	if (self.requestedGenerations[filename].unsignedIntegerValue != self.generation) {
		self.requestedGenerations[filename] = @(self.generation);

		[self.queue addObject:@{@"filename" : filename, @"location" : @(location)}];

		[self _renderNext];
	}

	return self.images[filename];
}

#pragma mark -
#pragma mark Rendering

- (void)_renderNext
{
	if (self.renderingFilename != nil || self.preparingWebView) {
		return;
	}

	NSDictionary<NSString *, id> *next = self.queue.firstObject;

	if (next == nil) {
		/* Its web content process is only worth keeping while there is work */
		self.webView = nil;

		[RZFileManager() removeItemAtURL:[self _workingFolderURL] error:NULL];

		return;
	}

	if (self.webView == nil) {
		[self _prepareWebView];

		return;
	}

	[self.queue removeObjectAtIndex:0];

	NSString *filename = next[@"filename"];

	NSString *path = [TPCThemeController pathOfThemeWithName:filename];

	if (path == nil) {
		[self _renderNext];

		return;
	}

	TPCTheme *style = [[TPCTheme alloc] initWithURL:[NSURL fileURLWithPath:path] inStorageLocation:[next[@"location"] integerValue]];

	NSString *document = nil;

	if (style.usable && [self _prepareFilesOfStyle:style location:[next[@"location"] integerValue]]) {
		document = [self _documentForStyle:style];
	}

	NSError *writeError = nil;

	if (document == nil || [document writeToURL:[self _documentURL] atomically:YES encoding:NSUTF8StringEncoding error:&writeError] == NO) {
		LogToConsoleError("Failed to prepare the preview of style '%{public}@': %{public}@", filename, writeError.localizedDescription);

		[self _renderNext];

		return;
	}

	self.renderingFilename = filename;

	self.renderingBuffer = [self _messagesForStyle:style];

	self.renderingToken += 1;

	[self _applyBackgroundOfStyle:style];

	[self performSelector:@selector(_renderTimedOut) withObject:nil afterDelay:_previewRenderTimeout];

	/* As the chat view: the sandbox, not this URL, limits what can be read */
	self.renderingNavigation =
	[self.webView loadFileURL:[self _documentURL] allowingReadAccessToURL:[NSURL fileURLWithPath:@"/" isDirectory:YES]];
}

- (void)_prepareWebView
{
	self.preparingWebView = YES;

	/* A style of one's own can ask for anything: nothing leaves this Mac */
	[TVCLogViewInternalWK2 compileRemoteLoadsRuleListWithCompletionHandler:^(WKContentRuleList * _Nullable ruleList) {
		self.preparingWebView = NO;

		if (ruleList == nil) {
			[self.queue removeAllObjects];

			return;
		}

		WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];

		configuration.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];

		[configuration.userContentController addContentRuleList:ruleList];

		WKWebView *webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, _previewWidth, _previewHeight) configuration:configuration];

		webView.navigationDelegate = self;

		self.webView = webView;

		[self _renderNext];
	}];
}

- (NSURL *)_workingFolderURL
{
	return [[TPCPathInfo applicationCachesURL] URLByAppendingPathComponent:@"Style Preview"];
}

- (NSURL *)_documentURL
{
	return [[self _workingFolderURL] URLByAppendingPathComponent:@"Preview.html"];
}

/* As for the chat view: the page can't read a style of one's own where it is kept */
- (BOOL)_prepareFilesOfStyle:(TPCTheme *)style location:(NSInteger)location
{
	NSURL *workingFolderURL = [self _workingFolderURL];

	if ([RZFileManager() createDirectoryAtURL:workingFolderURL withIntermediateDirectories:YES attributes:nil error:NULL] == NO) {
		return NO;
	}

	NSURL *copyURL = [workingFolderURL URLByAppendingPathComponent:@"Style"];

	[RZFileManager() removeItemAtURL:copyURL error:NULL];

	if (location == TPCThemeStorageLocationBundle) {
		self.renderingStylePath = style.originalURL.path;

		return YES;
	}

	if ([RZFileManager() copyItemAtURL:style.originalURL toURL:copyURL error:NULL] == NO) {
		return NO;
	}

	self.renderingStylePath = copyURL.path;

	return YES;
}

- (NSArray<NSString *> *)_cssFilesOfStyle:(TPCTheme *)style
{
	NSString *originalPath = style.originalURL.path;

	NSString *copyPath = self.renderingStylePath;

	NSMutableArray<NSString *> *files = [NSMutableArray array];

	for (NSString *path in style.cssFilePaths) {
		[files addObject:((copyPath && [path hasPrefix:originalPath]) ? [copyPath stringByAppendingString:[path substringFromIndex:originalPath.length]] : path)];
	}

	return [files copy];
}

- (void)_applyBackgroundOfStyle:(TPCTheme *)style
{
	BOOL dark = (style.appearance == TPCThemeAppearanceTypeDark || style.settings.underlyingWindowColorIsDark);

	NSColor *backgroundColor = style.settings.underlyingWindowColor;

	if (backgroundColor == nil) {
		backgroundColor = ((dark) ? [NSColor blackColor] : [NSColor whiteColor]);
	}

	self.webView.appearance = ((dark) ? [TXAppearancePropertyCollection appKitDarkAppearance] : [TXAppearancePropertyCollection appKitLightAppearance]);

	self.webView.underPageBackgroundColor = backgroundColor;
}

- (BOOL)_groupedDisplayInStyle:(TPCTheme *)style
{
	return ([TPCPreferences messageGroupingStyle] == TVCLogLineGroupingStyleGrouped && style.supportsGroupedDisplay);
}

/* The page of the chat view, without its scripts: they talk to a real view */
- (nullable NSString *)_documentForStyle:(TPCTheme *)style
{
	GRMustacheTemplate *template = [style templateWithName:@"baseLayout"];

	if (template == nil) {
		return nil;
	}

	TPCThemeSettings *settings = style.settings;

	NSMutableDictionary<NSString *, id> *tokens = [TVCLogController overrideStyleTokensForSettings:settings groupedDisplay:[self _groupedDisplayInStyle:style]];

	tokens[@"applicationResourcePath"] = [TPCPathInfo applicationResources];
	tokens[@"applicationTemplatesPath"] = style.applicationTemplateRepositoryPath;
	tokens[@"activeStyleAbsolutePath"] = self.renderingStylePath;
	tokens[@"activeStyleCSSFiles"] = [self _cssFilesOfStyle:style];
	tokens[@"cacheToken"] = [NSString stringWithUUID];
	tokens[@"userConfiguredTextEncoding"] = @"UTF-8";
	tokens[@"operatingSystemVersion"] = [XRSystemInformation systemStandardVersion];
	tokens[@"textDirectionToken"] = (([TPCPreferences rightToLeftFormatting]) ? @"rtl" : @"ltr");
	tokens[@"appearanceToken"] = ((settings.underlyingWindowColorIsDark) ? @"dark" : @"light");

	/* A private conversation: the one kind of view with no topic bar */
	tokens[@"isPrivateMessageView"] = @(YES);
	tokens[@"channelName"] = @"alice";
	tokens[@"viewTypeToken"] = @"query";

	if (settings.supportsMessageSpacing) {
		tokens[@"messageSpacingToken"] = @[@"compact", @"standard", @"roomy"][[TPCPreferences messageSpacing]];
	}

	/* What the chat's scripts would show, and from the top: the cards show the top */
	tokens[@"userStyleSheetRules"] = [([TPCPreferences themeUserStyleSheetRulesForStyleElement] ?: @"") stringByAppendingString:@"\n#loadingScreen { display: none !important; }\n#body { opacity: 1 !important; top: 0 !important; bottom: auto !important; }"];

	return [TVCLogRenderer renderTemplate:template attributes:tokens];
}

- (NSString *)_formattedNickname:(NSString *)nickname lineType:(TVCLogLineType)lineType style:(TPCTheme *)style
{
	if (lineType == TVCLogLineTypeAction) {
		return nickname;
	} else if (lineType == TVCLogLineTypeNotice) {
		return (([self _groupedDisplayInStyle:style]) ? nickname : [NSString stringWithFormat:TVCLogLineNoticeNicknameFormat, nickname]);
	}

	NSString *format = style.settings.themeNicknameFormat;

	if (format.length == 0) {
		format = [TPCPreferences themeNicknameFormat];
	}

	if (format.length == 0) {
		format = [TPCPreferences themeNicknameFormatDefault];
	}

	format = [format stringByReplacingOccurrencesOfString:@"%-?[0-9]*@" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, format.length)];

	format = [format stringByReplacingOccurrencesOfString:@"%-?[0-9]*n" withString:nickname options:NSRegularExpressionSearch range:NSMakeRange(0, format.length)];

	return format.trim;
}

- (NSString *)_formattedTimeWithMinute:(NSInteger)minute style:(TPCTheme *)style
{
	NSString *format = style.settings.themeTimestampFormat;

	if (format.length == 0) {
		format = [TPCPreferences themeTimestampFormat];
	}

	if (format.length == 0) {
		format = [TPCPreferences themeTimestampFormatDefault];
	}

	NSDate *date = [[NSCalendar currentCalendar] dateBySettingHour:19 minute:minute second:0 ofDate:[NSDate date] options:0];

	return TXFormattedTimestamp(date, format);
}

- (nullable NSString *)_lineWithNickname:(NSString *)nickname
								lineType:(TVCLogLineType)lineType
								  minute:(NSInteger)minute
									body:(NSString *)body
							 highlighted:(BOOL)highlighted
								 grouped:(BOOL)grouped
							  lineNumber:(NSUInteger)lineNumber
								   style:(TPCTheme *)style
{
	GRMustacheTemplate *template = [style templateWithLineType:lineType];

	if (template == nil) {
		return nil;
	}

	TPCThemeSettingsNicknameColorStyle colorStyle = style.settings.nicknameColorStyle;

	NSNumber *colorHash = [TPCNicknameColorStyleGenerator hashForString:nickname.lowercaseString colorStyle:colorStyle];

	NSMutableDictionary<NSString *, id> *attributes = [NSMutableDictionary dictionary];

	attributes[@"activeStyleAbsolutePath"] = self.renderingStylePath;
	attributes[@"applicationResourcePath"] = [TPCPathInfo applicationResources];
	attributes[@"formattedTimestamp"] = [self _formattedTimeWithMinute:minute style:style];
	attributes[@"isNicknameAvailable"] = @(YES);
	attributes[@"nicknameColorStyle"] = [TPCNicknameColorStyleGenerator nicknameColorStyleForHash:colorHash colorStyle:colorStyle];
	attributes[@"nicknameColorStyleOverride"] = @(NO);
	attributes[@"nicknameColorHashingEnabled"] = @([TPCPreferences disableNicknameColorHashing] == NO);
	attributes[@"formattedNickname"] = [self _formattedNickname:nickname lineType:lineType style:style];
	attributes[@"nickname"] = nickname;
	attributes[@"nicknameType"] = @"normal";
	attributes[@"lineType"] = [TVCLogLine stringForLineType:lineType];
	attributes[@"command"] = @"privmsg";
	attributes[@"rawCommand"] = @"privmsg";
	attributes[@"lineClassAttribute"] = @"text";
	attributes[@"highlightAttribute"] = ((highlighted) ? @"true" : @"false");
	attributes[@"message"] = body;
	attributes[@"formattedMessage"] = body;
	attributes[@"isHighlight"] = @(highlighted);
	attributes[@"isRemoteMessage"] = @(YES);
	attributes[@"lineNumber"] = [NSString stringWithFormat:@"%lu", lineNumber];

	if ([self _groupedDisplayInStyle:style]) {
		attributes[@"groupedDisplayEnabled"] = @(YES);
		attributes[@"isGroupedWithPrevious"] = @(grouped);
	}

	return [TVCLogRenderer renderTemplate:template attributes:attributes];
}

- (NSString *)_messagesForStyle:(TPCTheme *)style
{
	NSString *(^text)(NSString *) = ^NSString *(NSString *key) {
		return [TXTLS([@"TDCPreferencesController" stringByAppendingFormat:@"[%@]", key]) gtm_stringByEscapingForHTML];
	};

	NSString *formatting = [NSString stringWithFormat:@"<b>%@</b> <i>%@</i> <u>%@</u> <tt>%@</tt>", text(@"set-sam-fb"), text(@"set-sam-fi"), text(@"set-sam-fu"), text(@"set-sam-fm")];

	GRMustacheTemplate *linkTemplate = [style templateWithName:@"renderedStandardAnchorLinkResource"];

	NSString *link = nil;

	if (linkTemplate) {
		link = [TVCLogRenderer renderTemplate:linkTemplate attributes:@{@"anchorLocation" : @"https://www.textualapp.com", @"anchorTitle" : @"https://www.textualapp.com"}];
	}

	NSArray<NSArray *> *sample = @[
		@[@"alice", @(TVCLogLineTypePrivateMessage), @2, text(@"set-sam-1"), @NO, @NO],
		@[@"alice", @(TVCLogLineTypePrivateMessage), @2, text(@"set-sam-2"), @NO, @YES],
		@[@"bob", @(TVCLogLineTypePrivateMessage), @4, text(@"set-sam-3"), @NO, @NO],
		@[@"carl", @(TVCLogLineTypePrivateMessage), @5, text(@"set-sam-4"), @YES, @NO],
		@[@"dave", @(TVCLogLineTypePrivateMessage), @6, formatting, @NO, @NO],
		@[@"eve", @(TVCLogLineTypeAction), @8, text(@"set-sam-5"), @NO, @NO],
		@[@"ChanServ", @(TVCLogLineTypeNotice), @9, text(@"set-sam-6"), @NO, @NO],
		@[@"robert", @(TVCLogLineTypePrivateMessage), @12, (link ?: text(@"set-sam-3")), @NO, @NO]
	];

	NSMutableString *messages = [NSMutableString string];

	[sample enumerateObjectsUsingBlock:^(NSArray *line, NSUInteger index, BOOL *stop) {
		NSString *html =
		[self _lineWithNickname:line[0]
					   lineType:[line[1] unsignedIntegerValue]
						 minute:[line[2] integerValue]
						   body:line[3]
					highlighted:[line[4] boolValue]
						grouped:[line[5] boolValue]
					 lineNumber:index
						  style:style];

		if (html) {
			[messages appendString:html];
		}
	}];

	return [messages copy];
}

#pragma mark -
#pragma mark Finishing

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation
{
	if (navigation != self.renderingNavigation || self.renderingBuffer == nil) {
		return;
	}

	NSUInteger token = self.renderingToken;

	[webView callAsyncJavaScript:@"var buffer = document.getElementById('messageBuffer'); if (buffer) { buffer.innerHTML = messages; }"
					   arguments:@{@"messages" : self.renderingBuffer}
						 inFrame:nil
				  inContentWorld:WKContentWorld.pageWorld
			   completionHandler:^(id _Nullable result, NSError * _Nullable error) {
		if (token != self.renderingToken) {
			return;
		}

		[self _takeSnapshot];
	}];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
	if (navigation == self.renderingNavigation) {
		[self _finishRenderingWithImage:nil];
	}
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
	if (navigation == self.renderingNavigation) {
		[self _finishRenderingWithImage:nil];
	}
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView
{
	if (self.renderingFilename != nil) {
		[self _finishRenderingWithImage:nil];
	}
}

- (void)_takeSnapshot
{
	NSUInteger token = self.renderingToken;

	WKSnapshotConfiguration *configuration = [WKSnapshotConfiguration new];

	configuration.rect = NSMakeRect(0, 0, _previewWidth, _previewHeight);

	configuration.snapshotWidth = @(_previewPixelWidth);

	/* It is in no window: there will be no screen update to wait for */
	configuration.afterScreenUpdates = NO;

	[self.webView takeSnapshotWithConfiguration:configuration completionHandler:^(NSImage * _Nullable image, NSError * _Nullable error) {
		if (token == self.renderingToken) {
			[self _finishRenderingWithImage:image];
		}
	}];
}

- (void)_renderTimedOut
{
	LogToConsoleError("The preview of style '%{public}@' timed out", self.renderingFilename);

	[self _finishRenderingWithImage:nil];
}

- (void)_finishRenderingWithImage:(nullable NSImage *)image
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_renderTimedOut) object:nil];

	NSString *filename = self.renderingFilename;

	self.renderingFilename = nil;
	self.renderingBuffer = nil;
	self.renderingStylePath = nil;
	self.renderingNavigation = nil;

	/* What is still on its way belongs to this picture */
	self.renderingToken += 1;

	if (image != nil && filename != nil) {
		self.images[filename] = image;

		[RZNotificationCenter() postNotificationName:TDCSettingsBridgeStylePreviewsDidChangeNotification object:nil];
	}

	[self _renderNext];
}

@end

NS_ASSUME_NONNULL_END
