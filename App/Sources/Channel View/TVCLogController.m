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
#import "NSStringHelper.h"
#import "TXGlobalModels.h"
#import "TXMasterController.h"
#import "TXMenuControllerPrivate.h"
#import "ICLPayloadPrivate.h"
#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "IRCChannelUserPrivate.h"
#import "IRCChannel.h"
#import "IRCChannelPrivate.h"
#import "THOPluginDispatcherPrivate.h"
#import "THOPluginManagerPrivate.h"
#import "THOPluginProtocolPrivate.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCThemeController.h"
#import "TPCThemePrivate.h"
#import "TLOLinkParser.h"
#import "TLOLocalization.h"
#import "TVCLogViewPrivate.h"
#import "TVCLogLine.h"
#import "TVCLogLinePrivate.h"
#import "TVCLogRenderer.h"
#import "HLSHistoricLogManagerPrivate.h"
#import "TLOMessageArchivePrivate.h"
#import "TVCLogControllerInlineMediaServicePrivate.h"
#import "TVCLogControllerOperationQueuePrivate.h"
#import "TVCMainWindowPrivate.h"
#import "TVCLogControllerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* Lines past the scrollback, from the message archive */
static NSString * const _archiveLinePrefix = @"archive-";
static NSString * const _archiveBoundaryLineNumber = @"archive-boundary";

#define _enqueueBlock(operationBlock)			\
	[self.printingQueue enqueueMessageBlock:(operationBlock) for:self isStandalone:NO];

#define _enqueueBlockStandalone(operationBlock)			\
	[self.printingQueue enqueueMessageBlock:(operationBlock) for:self isStandalone:YES];

/* In the Chat display, messages a sender posts within this long of each
 other are shown under one name */
static const NSTimeInterval TVCLogControllerMessageGroupingWindow = (5 * 60);

@interface TVCLogControllerPrintOperationContext ()
@property (nonatomic, weak, readwrite) IRCClient *client;
@property (nonatomic, weak, readwrite) IRCChannel *channel;
@property (nonatomic, assign, readwrite, getter=isHighlight) BOOL highlight;
@property (nonatomic, copy, readwrite, nullable) NSString *highlightKeyword;
@property (nonatomic, copy, readwrite) TVCLogLine *logLine;
@property (nonatomic, copy, readwrite) NSString *lineNumber;
@end

@interface TVCLogController ()
@property (nonatomic, assign, readwrite, getter=viewIsLoaded) BOOL loaded; // atomic accessors below: printing operations ask from their threads (isReady)
@property (nonatomic, assign) BOOL terminating;
@property (atomic, assign) BOOL historyLoadedForFirstTime; // atomic (these four): the history reload sets them on a background queue
@property (atomic, assign) BOOL reloadingHistory;
@property (nonatomic, assign) BOOL reloadingTheme; // while the new document is built
@property (nonatomic, assign) BOOL pendingThemeReload; // until that document has loaded
@property (nonatomic, strong, nullable) NSMutableString *pendingAppendHTML; // lines waiting for -flushPendingAppend
@property (nonatomic, strong, nullable) NSMutableArray<NSString *> *pendingAppendLineNumbers;
@property (atomic, assign) BOOL historyLoaded;
@property (nonatomic, assign) NSInteger activeLineCount;
@property (nonatomic, copy, nullable) NSString *lastVisitedHighlight;
@property (atomic, copy, nullable, readwrite) NSString *newestLineNumberFromPreviousSession;
@property (atomic, strong, nullable) NSDate *sessionStartDate; // when that line was found: where "Since 09:41" begins
@property (nonatomic, copy, nullable, readwrite) NSString *oldestLineNumber;
@property (nonatomic, copy, nullable, readwrite) NSString *newestLineNumber;
@property (atomic, strong, nullable) TVCLogLine *lastLine; // atomic: history results set it off the main thread
@property (nonatomic, strong) NSMutableArray<TVCLogLine *> *unsavedLogLines; // printed but not yet in the historic log; guarded by itself
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *pendingLineChanges; // line number → changes for when it is saved; guarded by unsavedLogLines
@property (atomic, assign) NSUInteger historyGeneration; // raised by every clear; history fetches from before it are dropped
@property (nonatomic, strong) NSMutableArray<NSString *> *highlightedLineNumbers;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *messageReferences; // msgid → line number, nickname, excerpt (replies); guarded by itself
@property (nonatomic, strong) NSMutableArray<NSString *> *messageReferenceOrder; // oldest first, to forget beyond the limit
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<NSMutableDictionary *> *> *messageReactions; // msgid → reactions in order; guarded by messageReferences
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *jumpToLineCallbacks; // line number → handlers waiting for it
@property (nonatomic, strong, readwrite, nullable) TVCLogView *backingView; // nil once torn down
@property (weak, readonly) IRCTreeItem *associatedItem;
@property (nonatomic, weak, readwrite) IRCClient *associatedClient;
@property (nonatomic, weak, readwrite) IRCChannel *associatedChannel;
@property (nonatomic, weak, readwrite) TVCMainWindow *attachedWindow;
@property (nonatomic, assign) NSTimeInterval viewLoadedTimestamp;
@property (readonly) TVCLogControllerPrintingOperationQueue *printingQueue;
@property (readonly, copy) NSURL *baseURL;
@property (nonatomic, assign) BOOL documentLoadHoldsSlot;
@property (nonatomic, assign) NSTimeInterval documentLoadStartedAt; // 0 before the first load
@property (nonatomic, assign) NSUInteger stuckDocumentReloadCount; // since the last document that loaded
@end

/* Loading every view's document at once (one web view per server and
 channel) starves WebKit: with about 100 views, some loads never finish.
 Visible views load right away; the others queue and load a few at a time.
 A slot is given back when the view finishes loading or after a timeout. */
#define _maximumConcurrentDeferredDocumentLoads		8
#define _deferredDocumentLoadSlotTimeout			8.0

static NSMutableArray<TVCLogController *> *_deferredDocumentLoads = nil;
static NSUInteger _deferredDocumentLoadsInFlight = 0;

NSString * const TVCLogControllerViewFinishedLoadingNotification = @"TVCLogControllerViewFinishedLoadingNotification";

@implementation TVCLogController

@synthesize loaded = _loaded;

/* Atomic loads and stores (a property's "atomic" doesn't make a scalar one) */
- (BOOL)viewIsLoaded
{
	return __atomic_load_n(&self->_loaded, __ATOMIC_RELAXED);
}

- (void)setLoaded:(BOOL)loaded
{
	__atomic_store_n(&self->_loaded, loaded, __ATOMIC_RELAXED);
}

- (BOOL)historyIsShown
{
	return (self.loaded && self.historyLoaded && self.reloadingHistory == NO);
}

#pragma mark -
#pragma mark Initialization

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithClient:(IRCClient *)client inWindow:(TVCMainWindow *)window
{
	NSParameterAssert(client != nil);
	NSParameterAssert(window != nil);

	if ((self = [super init])) {
		self.associatedClient = client;

		self.attachedWindow = window;

		[self prepareInitialState];

		[self setUp];

		return self;
	}

	return nil;
}

- (instancetype)initWithChannel:(IRCChannel *)channel inWindow:(TVCMainWindow *)window
{
	NSParameterAssert(channel != nil);
	NSParameterAssert(window != nil);

	if ((self = [super init])) {
		self.associatedClient = channel.associatedClient;
		self.associatedChannel = channel;

		self.attachedWindow = window;

		[self prepareInitialState];

		[self setUp];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self.highlightedLineNumbers	= [NSMutableArray new];

	self.jumpToLineCallbacks = [NSMutableDictionary dictionary];

	self.unsavedLogLines = [NSMutableArray array];

	self.pendingLineChanges = [NSMutableDictionary dictionary];

	self.messageReferences = [NSMutableDictionary dictionary];
	self.messageReferenceOrder = [NSMutableArray array];
	self.messageReactions = [NSMutableDictionary dictionary];
}

- (void)prepareForTermination:(BOOL)isTerminatingApplication
{
	self.terminating = YES;

	self.loaded = NO;

	[self cancelDeferredDocumentLoad];

	[self.backingView stopLoading]; // allow view to teardown
	self.backingView = nil;

	self.historyGeneration += 1;

	[self.printingQueue cancelOperationsForViewController:self];

	/* Quitting: lines not drawn yet still belong in the saved scrollback */
	[self saveUnsavedLogLines:isTerminatingApplication];

	[self discardPendingAppend];

	[self failPendingJumps];

	if (isTerminatingApplication) {
		[self closeHistoricLog];
	} else {
		[self historicLogForgetChannel];
	}
}

- (void)prepareForApplicationTermination
{
	LogToConsoleTerminationProgress("Preparing view controller: %{public}@", self.uniqueIdentifier);

	[self prepareForTermination:YES];
}

- (void)prepareForPermanentDestruction
{
	[self prepareForTermination:NO];
}

- (void)dealloc
{
	[self cancelPerformRequests];
}

#pragma mark -
#pragma mark Create View

- (void)setUp
{
	self.backingView = [[TVCLogView alloc] initWithViewController:self];

	[self scheduleInitialDocumentLoad];
}

- (void)loadInitialDocument
{
	[self loadAlternateHTML:[self initialDocument]];
}

#pragma mark -
#pragma mark Deferred Document Loads

- (void)scheduleInitialDocumentLoad
{
	if (self.terminating) {
		return;
	}

	/* A reload gives back the slot of the load it replaces */
	[self releaseDeferredDocumentLoadSlot];

	if (self.visible) {
		[_deferredDocumentLoads removeObjectIdenticalTo:self];

		[self loadInitialDocument];

		return;
	}

	if (_deferredDocumentLoads == nil) {
		_deferredDocumentLoads = [NSMutableArray array];
	}

	if ([_deferredDocumentLoads indexOfObjectIdenticalTo:self] == NSNotFound) {
		[_deferredDocumentLoads addObject:self];
	}

	[self.class dequeueDeferredDocumentLoads];
}

- (void)prioritizeDeferredDocumentLoad
{
	if ([_deferredDocumentLoads indexOfObjectIdenticalTo:self] == NSNotFound) {
		return;
	}

	[_deferredDocumentLoads removeObjectIdenticalTo:self];

	[self loadInitialDocument];
}

- (void)cancelDeferredDocumentLoad
{
	[_deferredDocumentLoads removeObjectIdenticalTo:self];

	[self releaseDeferredDocumentLoadSlot];
}

+ (void)dequeueDeferredDocumentLoads
{
	while (_deferredDocumentLoadsInFlight < _maximumConcurrentDeferredDocumentLoads &&
		   _deferredDocumentLoads.count > 0)
	{
		TVCLogController *viewController = _deferredDocumentLoads[0];

		[_deferredDocumentLoads removeObjectAtIndex:0];

		if (viewController.terminating) {
			continue;
		}

		viewController.documentLoadHoldsSlot = YES;

		_deferredDocumentLoadsInFlight += 1;

		[viewController performSelectorInCommonModes:@selector(releaseDeferredDocumentLoadSlot)
										  afterDelay:_deferredDocumentLoadSlotTimeout];

		[viewController loadInitialDocument];
	}
}

- (void)releaseDeferredDocumentLoadSlot
{
	[self cancelPerformRequestsWithSelector:@selector(releaseDeferredDocumentLoadSlot)];

	if (self.documentLoadHoldsSlot == NO) {
		return;
	}

	self.documentLoadHoldsSlot = NO;

	_deferredDocumentLoadsInFlight -= 1;

	[self.class dequeueDeferredDocumentLoads];
}

- (void)loadAlternateHTML:(NSString *)newHTML
{
	NSParameterAssert(newHTML != nil);

	[self.backingView stopLoading];

	self.documentLoadStartedAt = [NSDate timeIntervalSince1970];

	[self.backingView loadHTMLString:newHTML baseURL:self.baseURL];
}

/* Under load WebKit can fail a document or never finish it; the view then
 stayed blank for the rest of the session. Loaded again, three times at most. */
- (void)reloadStuckDocument
{
	if (self.terminating) {
		return;
	}

	if (self.stuckDocumentReloadCount >= 3) {
		LogToConsoleError("Gave up loading the document of %{public}@", self.description);

		return;
	}

	self.stuckDocumentReloadCount += 1;

	LogToConsoleError("Loading the document of %{public}@ again (%{public}lu of 3)", self.description, self.stuckDocumentReloadCount);

	/* Otherwise the next document would skip setting itself up */
	self.loaded = NO;

	self.historyLoaded = NO;

	[self loadInitialDocument];
}

#pragma mark -
#pragma mark Manage Historic Log

- (void)historicLogForgetChannel
{
	/* Delete any trace of the channel, including context */
	[sharedHistoricLog() forgetItem:self.associatedItem];
}

- (void)historicLogResetChannel
{
	/* Delete log for channel but keep context */
	[sharedHistoricLog() resetDataForItem:self.associatedItem];
}

- (void)closeHistoricLog
{
	/* The historic log file is always open regardless of whether the user asked
	 Textual to remember the history between restarts. It is always open because
	 the reloading of a theme uses it to fill in the backlog after a reload.
	 -closeHistoricLog is the point where we decide to actually save the file
	 or erase it. If the user has Textual configured to remember between restarts,
	 then we call a save before terminating. Or, we just erase the file from the
	 path that it is written to entirely. */

	IRCChannel *channel = self.associatedChannel;

	if (
		/* 1 */ [TPCPreferences reloadScrollbackOnLaunch] == NO ||
		/* 2 */  channel.isUtility ||
		/* 3 */ (channel.isPrivateMessage &&
				 [TPCPreferences rememberServerListQueryStates] == NO))
	{
		[self historicLogResetChannel];
	}
}

#pragma mark -
#pragma mark Properties

- (nullable IRCTreeItem *)associatedItem
{
	if (self.associatedChannel) {
		return self.associatedChannel;
	} else {
		return self.associatedClient;
	}
}

- (NSString *)uniqueIdentifier
{
	return self.associatedItem.uniqueIdentifier;
}

- (NSURL *)baseURL
{
	return themeController().temporaryURL;
}

- (TVCLogControllerPrintingOperationQueue *)printingQueue
{
	return [TXSharedApplication sharedPrintingQueue];
}

- (BOOL)inlineMediaEnabledForView
{
	IRCChannel *channel = self.associatedChannel;

	if (channel == nil) {
		return NO;
	}

	IRCChannelConfig *config = channel.config;

	return (([TPCPreferences showInlineMedia]		&& config.inlineMediaDisabled == NO) ||
			([TPCPreferences showInlineMedia] == NO	&& config.inlineMediaEnabled));
}

- (BOOL)viewIsSelected
{
	return (self.attachedWindow.selectedViewController == self);
}

- (BOOL)viewIsVisible
{
	IRCChannel *channel = self.associatedChannel;

	if (channel) {
		return [self.attachedWindow isItemVisible:channel];
	} else {
		return [self.attachedWindow isItemVisible:self.associatedClient];
	}
}

#pragma mark -
#pragma mark Document Append & JavaScript Controller

- (void)evaluateFunction:(NSString *)function withArguments:(nullable NSArray *)arguments
{
	[self evaluateFunction:function withArguments:arguments onQueue:YES];
}

- (void)evaluateFunction:(NSString *)function withArguments:(nullable NSArray *)arguments onQueue:(BOOL)onQueue
{
	NSParameterAssert(function != nil);

	if (self.terminating) {
		return;
	}

	if (onQueue) {
		TVCLogControllerPrintingBlock scriptBlock = ^(id operation) {
			[self _evaluateFunction:function withArguments:arguments];
		};

		_enqueueBlock(scriptBlock)
	} else {
		[self _evaluateFunction:function withArguments:arguments];
	}
}

- (void)_evaluateFunction:(NSString *)function withArguments:(nullable NSArray *)arguments
{
	NSParameterAssert(function != nil);

	if (self.loaded == NO || self.terminating) {
		return;
	}

	/* Lines waiting to be added belong to the main thread; the script would
	 have gone there anyway (the view evaluates on the main queue) */
	if ([NSThread isMainThread] == NO) {
		XRPerformBlockAsynchronouslyOnMainQueue(^{
			[self _evaluateFunction:function withArguments:arguments];
		});

		return;
	}

	[self flushPendingAppend];

	[self.backingView evaluateFunction:function withArguments:arguments];
}

/* Lines printed in one pass of the main queue go to the view in one call
 (one script evaluation and one layout instead of one per line) */
- (void)appendToDocumentBody:(NSString *)html withLineNumbers:(NSArray<NSString *> *)lineNumbers
{
	NSParameterAssert(html != nil);
	NSParameterAssert(lineNumbers != nil);

	if (self.loaded == NO || self.terminating) {
		return;
	}

	if (self.pendingAppendHTML == nil) {
		self.pendingAppendHTML = [NSMutableString string];
		self.pendingAppendLineNumbers = [NSMutableArray array];

		__weak typeof(self) weakSelf = self;

		XRPerformBlockAsynchronouslyOnMainQueue(^{
			[weakSelf flushPendingAppend];
		});
	}

	[self.pendingAppendHTML appendString:html];

	[self.pendingAppendLineNumbers addObjectsFromArray:lineNumbers];
}

/* Also before any other script, so the view sees everything in order */
- (void)flushPendingAppend
{
	NSString *html = self.pendingAppendHTML;
	NSArray *lineNumbers = self.pendingAppendLineNumbers;

	if (html == nil) {
		return;
	}

	[self discardPendingAppend];

	if (self.loaded == NO || self.terminating) {
		return;
	}

	__weak typeof(self) weakSelf = self;

	[self.backingView evaluateFunction:@"MessageBuffer.bufferElementAppend"
						 withArguments:@[html, lineNumbers]
					 completionHandler:^(id _Nullable result) {
		/* Not added while older lines are shown, but plugins still hear of them */
		if ([result isKindOfClass:[NSNumber class]] && [result boolValue] == NO) {
			[weakSelf notifyPluginsOfLinesPosted:lineNumbers];
		}
	}];
}

/* The document they were meant for is being replaced (they are in the history) */
- (void)discardPendingAppend
{
	self.pendingAppendHTML = nil;
	self.pendingAppendLineNumbers = nil;
}

#pragma mark -
#pragma mark Channel Topic Bar

- (void)setInitialTopic
{
	IRCChannel *channel = self.associatedChannel;

	/* The topic bar of a private message lists the channels you share */
	if ([self.class channelShowsQueryInfoBar:channel]) {
		[self.associatedClient updateQueryInfoBarsForNickname:channel.name];

		return;
	}

	[self setTopic:channel.topic];
}

/* Not for ZNC's own (*status and the like): no one to share channels with */
+ (BOOL)channelShowsQueryInfoBar:(nullable IRCChannel *)channel
{
	return (channel.isPrivateMessage && channel.isPrivateMessageForZNCUser == NO);
}

- (void)setQueryInfoBar:(NSString *)text
{
	NSParameterAssert(text != nil);

	if (self.terminating) {
		return;
	}

	TVCLogControllerPrintingBlock operationBlock = ^(id operation) {
		NSString *template = [TVCLogRenderer renderBody:text
									  forViewController:self
										 withAttributes:@{
											   TVCLogRendererConfigurationRenderLinksAttribute : @YES,
											   TVCLogRendererConfigurationLineTypeAttribute : @(TVCLogLineTypeTopic)
														 }
											 resultInfo:NULL];

		[self _evaluateFunction:@"_Textual.setQueryInfoBar" withArguments:@[template]];
	};

	_enqueueBlockStandalone(operationBlock)
}

- (void)setTopic:(nullable NSString *)topic
{
	if (self.terminating) {
		return;
	}

	TVCLogControllerPrintingBlock operationBlock = ^(id operation) {
		NSString *topicString = nil;

		if (topic == nil || topic.length == 0) {
			topicString = TXTLS(@"TVCMainWindow[vi3-23]");
		} else {
			topicString = topic;
		}

		NSString *topicTemplate = [TVCLogRenderer renderBody:topicString
										   forViewController:self
											  withAttributes:@{
													TVCLogRendererConfigurationRenderLinksAttribute : @YES,
													TVCLogRendererConfigurationLineTypeAttribute : @(TVCLogLineTypeTopic)
															}
												  resultInfo:NULL];

		[self _evaluateFunction:@"Textual.setTopicBarValue" withArguments:@[topicString, topicTemplate]];
	};

	_enqueueBlockStandalone(operationBlock)
}

#pragma mark -
#pragma mark Move to Bottom/Top

- (void)moveToTop
{
	[self _evaluateFunction:@"Textual.scrollToTopOfView" withArguments:@[@(YES)]];
}

- (void)moveToBottom
{
	[self _evaluateFunction:@"Textual.scrollToBottomOfView" withArguments:@[@(YES)]];
}

#pragma mark -
#pragma mark Add/Remove History Mark

- (void)mark
{
	TVCLogControllerPrintingBlock operationBlock = ^(id operation) {
		NSString *markTemplate = [TVCLogRenderer renderTemplateNamed:@"historyIndicator" attributes:@{@"historyIndicatorLabel" : TXTLS(@"TVCMainWindow[mrk-n1]")}];

		[self _evaluateFunction:@"_Textual.historyIndicatorAdd" withArguments:@[markTemplate]];
	};

	_enqueueBlock(operationBlock);
}

- (void)unmark
{
	[self _evaluateFunction:@"_Textual.historyIndicatorRemove" withArguments:nil];
}

- (void)goToMark
{
	[self _evaluateFunction:@"Textual.scrollToHistoryIndicator" withArguments:nil];
}

#pragma mark -
#pragma mark Typing Indicator

/* Shown as the last line of the view (typingIndicator template, an element with id typing-indicator) */
- (void)setTypingIndicatorText:(NSString *)text
{
	NSParameterAssert(text != nil);

	TVCLogControllerPrintingBlock operationBlock = ^(id operation) {
		/* The template escapes the text ({{typingText}}) */
		NSString *indicatorTemplate = [TVCLogRenderer renderTemplateNamed:@"typingIndicator" attributes:@{@"typingText" : text}];

		if (indicatorTemplate == nil) {
			return;
		}

		[self _evaluateFunction:@"_Textual.typingIndicatorSet" withArguments:@[indicatorTemplate]];
	};

	_enqueueBlock(operationBlock);
}

- (void)removeTypingIndicator
{
	[self _evaluateFunction:@"_Textual.typingIndicatorRemove" withArguments:nil];
}

#pragma mark -
#pragma mark Message Actions

- (NSDictionary<NSString *, id> *)messageActionsAvailability
{
	IRCClient *client = self.associatedClient;

	IRCChannel *channel = self.associatedChannel;

	BOOL inConversation = (channel != nil && channel.isUtility == NO && client.isLoggedIn);

	BOOL canDelete = (inConversation && client.canDeleteMessages);

	/* Others' messages: an operator's to try (the server decides; decided 2026-10-16) */
	BOOL canDeleteOthers = NO;

	if (canDelete && channel.isChannel) {
		IRCChannelUser *member = [channel findMember:client.userNickname];

		canDeleteOthers = (member.op || member.halfOp);
	}

	return @{
		@"reply" : @(inConversation && client.canSendReplies),
		@"react" : @(inConversation && client.canSendReactions),
		@"delete" : @(canDelete),
		@"deleteOthers" : @(canDeleteOthers)
	};
}

- (void)performMessageMenuCommand:(NSMenuItem *)sender
{
	NSArray *lineAndCommand = sender.representedObject;

	if ([lineAndCommand isKindOfClass:[NSArray class]] == NO || lineAndCommand.count != 2) {
		return;
	}

	/* The reaction choices are then picked with the keys too */
	if ([lineAndCommand[1] isEqual:@"react"]) {
		NSView *webView = self.backingView.webView;

		if (webView.window && [webView.window makeFirstResponder:webView]) {
			self.messageFocusActive = YES;
		}
	}

	[self evaluateFunction:@"_MessageActions.menuCommand" withArguments:lineAndCommand];
}

- (void)updateMessageActions
{
	[self evaluateFunction:@"_MessageActions.setAvailable" withArguments:@[self.messageActionsAvailability]];
}

#pragma mark -
#pragma mark Reload Scrollback

- (void)appendHistoricMessageFragment:(NSString *)html withLineNumbers:(NSArray<NSString *> *)lineNumbers isReload:(BOOL)isReload
{
	NSParameterAssert(html != nil);

	[self _evaluateFunction:@"_Textual.documentBodyAppendHistoric" withArguments:@[html, lineNumbers, @(isReload)]];
}

/* reloadOldLines: is supposed to be called from inside a queue. */
- (void)reloadOldLines:(NSArray<TVCLogLine *> *)oldLines isReload:(BOOL)isReload
{
	NSParameterAssert(oldLines != nil);

	NSMutableArray<NSString *> *lineNumbers = [NSMutableArray array];

	NSMutableString *patchedAppend = [NSMutableString string];

	NSMutableArray<THOPluginDidPostNewMessageConcreteObject *> *pluginObjects = nil;

	TVCLogLine *previousLine = nil;

	for (TVCLogLine *logLine in oldLines) {
		/* Render result info HTML */
		NSDictionary<NSString *, id> *resultInfo = nil;

		NSString *html = [self renderLogLine:logLine previousLine:previousLine resultInfo:&resultInfo];

		if (html == nil) {
			LogToConsoleError("Failed to render log line %{public}@", logLine.description);

			continue;
		}

		previousLine = logLine;

		[patchedAppend appendString:html];

		/* Record information about rendering */
		NSString *lineNumber = logLine.uniqueIdentifier;

		[lineNumbers addObject:lineNumber];

		/* Add reference to plugin concrete object */
		THOPluginDidPostNewMessageConcreteObject *pluginObject = resultInfo[@"pluginConcreteObject"];

		if (pluginObject) {
			if (pluginObjects == nil) {
				pluginObjects = [NSMutableArray array];
			}

			[pluginObjects addObject:pluginObject];
		}

		/* Record highlights */
		BOOL highlighted = [resultInfo boolForKey:TVCLogRendererResultsKeywordMatchFoundAttribute];

		if (highlighted) {
			@synchronized(self.highlightedLineNumbers) {
				if ([self.highlightedLineNumbers containsObject:lineNumber] == NO) {
					[self.highlightedLineNumbers addObject:lineNumber];
				}
			}
		}
	}

	/* Render the result in WebKit */
	[self appendHistoricMessageFragment:patchedAppend withLineNumbers:lineNumbers isReload:isReload];

	/* Inform plugins of new content */
	for (THOPluginDidPostNewMessageConcreteObject *pluginObject in pluginObjects) {
		pluginObject.isProcessedInBulk = YES;

		[THOPluginDispatcher enqueueDidPostNewMessage:pluginObject];
	}
}

- (void)maybeReloadHistory
{
	if (self.loaded == NO) {
		return;
	}

	if (self.historyLoaded) {
		return;
	}

	[self reloadHistory];
}

- (void)reloadHistory
{
	if (self.terminating) {
		return;
	}

	BOOL firstTimeLoadingHistory = (self.historyLoadedForFirstTime == NO);

	IRCChannel *channel = self.associatedChannel;

	if (
		/* 1 */ (firstTimeLoadingHistory &&
				 [TPCPreferences reloadScrollbackOnLaunch] == NO) ||
		/* 2 */  channel.isUtility ||
		/* 3 */ (firstTimeLoadingHistory &&
				 channel.isPrivateMessage &&
				 [TPCPreferences rememberServerListQueryStates] == NO))
	{
		self.historyLoadedForFirstTime = YES;

		self.historyLoaded = YES;

		[self notifyViewFinishedLoadingHistory];

		return;
	} else if (self.visible == NO) {
		/* Loaded when the view is first shown */
		return;
	}

	self.reloadingHistory = YES;

	void (^reloadBlock)(NSArray *) = ^(NSArray<TVCLogLine *> *objects) {
		TVCLogLine *lastLine = objects.lastObject;

		/* Only assign lastLine to self if there is none because
		 if we do it when there is some, then there will be a big
		 cluster fuck of incorrect date changes. */
		if (self.lastLine == nil) {
			self.lastLine = lastLine;
		}

		if (firstTimeLoadingHistory) {
			NSString *newestLineNumber = lastLine.uniqueIdentifier;

			self.newestLineNumberFromPreviousSession = newestLineNumber;

			self.sessionStartDate = [NSDate date];
		}

		[self reloadOldLines:objects isReload:(firstTimeLoadingHistory == NO)];

		self.reloadingHistory = NO;

		self.historyLoaded = YES;
		self.historyLoadedForFirstTime = YES;

		[self notifyViewFinishedLoadingHistory];
	};

	/* The operation finishes when the fetch starts, so cancelling it doesn't
	 reach the fetch: a clear raises historyGeneration instead */
	NSUInteger historyGeneration = self.historyGeneration;

	TVCLogControllerPrintingBlock operationBlock = ^(id operation) {
		NSDate *limitToDate = [NSDate dateWithTimeIntervalSince1970:self.viewLoadedTimestamp];

		[sharedHistoricLog()
		 fetchEntriesForItem:self.associatedItem
				   ascending:NO
				  fetchLimit:100
				 limitToDate:limitToDate
		 withCompletionBlock:^(NSArray<TVCLogLine *> *objects) {
				if ([operation isCancelled] || self.historyGeneration != historyGeneration) {
					return;
				}

				reloadBlock(objects.reverseObjectEnumerator.allObjects);
		 }];
	};

	_enqueueBlockStandalone(operationBlock)
}

- (void)reloadTheme
{
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self _reloadTheme];
	});
}

- (void)_reloadTheme
{
	if (self.terminating) {
		return;
	}

	if (self.reloadingTheme) {
		return;
	}

	/* Even if the user has never loaded their history, we force this
	 flag to YES when reloading theme. We do not want history to be
	 displayed as historic when playing it back after a reload. */
	self.historyLoadedForFirstTime = YES;

	self.reloadingTheme = YES;
	self.pendingThemeReload = YES;

	[self clearWithReset:NO];

	self.reloadingTheme = NO;
}

- (NSString *)dateIndicatorWithDate:(NSDate *)date
{
	NSParameterAssert(date != nil);

	NSString *dateString = TXFormatDate(date, NSDateFormatterLongStyle, NSDateFormatterNoStyle, NO);

	return dateString;
}

/* The date line's day as year-month-day, for the view to tell how long ago it was */
/* The note shown while nothing has been said: none for a server console */
- (NSString *)emptyViewText
{
	IRCChannel *channel = self.associatedChannel;

	if (channel.isChannel) {
		return TXTLS(@"TVCMainWindow[emp-c1]");
	} else if (channel.isPrivateMessage) {
		return TXTLS(@"TVCMainWindow[emp-q1]", channel.name);
	}

	return @"";
}

- (NSString *)dateIndicatorDayWithDate:(NSDate *)date
{
	NSParameterAssert(date != nil);

	NSDateComponents *components = [[NSCalendar currentCalendar] components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:date];

	return [NSString stringWithFormat:@"%04ld-%02ld-%02ld", (long)components.year, (long)components.month, (long)components.day];
}

/* "Sunday, October 12"; the year only when it isn't this year */
- (NSString *)dateIndicatorDayLabelWithDate:(NSDate *)date
{
	NSParameterAssert(date != nil);

	BOOL thisYear = [[NSCalendar currentCalendar] isDate:date equalToDate:[NSDate date] toUnitGranularity:NSCalendarUnitYear];

	NSDateFormatter *dateFormatter = [NSDateFormatter new];

	[dateFormatter setLocalizedDateFormatFromTemplate:((thisYear) ? @"EEEEMMMMd" : @"EEEEMMMMdy")];

	return [dateFormatter stringFromDate:date];
}

/* "Today", "Yesterday", or the weekday and date */
- (NSString *)dateIndicatorLabelWithDate:(NSDate *)date
{
	NSParameterAssert(date != nil);

	NSCalendar *calendar = [NSCalendar currentCalendar];

	if ([calendar isDateInToday:date] || [calendar isDateInYesterday:date]) {
		return TXFormatDate(date, NSDateFormatterLongStyle, NSDateFormatterNoStyle, YES);
	}

	return [self dateIndicatorDayLabelWithDate:date];
}

#pragma mark -
#pragma mark Utilities

- (void)jumpToCurrentSession
{
	NSString *lineNumber = self.newestLineNumberFromPreviousSession;

	if (lineNumber == nil) {
		lineNumber = self.oldestLineNumber;
	}

	if (lineNumber == nil) {
		return;
	}

	[self jumpToLine:lineNumber];
}

- (void)jumpToPresent
{
	NSString *lineNumber = self.newestLineNumber;

	if (lineNumber == nil) {
		lineNumber = self.newestLineNumberFromPreviousSession;
	}

	if (lineNumber == nil) {
		return;
	}

	/* There, the view is at the present again: new lines are added and followed */
	[self jumpToLine:lineNumber completionHandler:^(BOOL result) {
		if (result) {
			[self _evaluateFunction:@"_MessageBuffer.reachedPresent" withArguments:nil];
		}
	}];
}

- (void)jumpToLine:(NSString *)lineNumber
{
	[self jumpToLine:lineNumber completionHandler:nil];
}

- (void)jumpToLine:(NSString *)lineNumber completionHandler:(void (^ _Nullable)(BOOL result))completionHandler
{
	NSParameterAssert(lineNumber != nil);

	/* No line (a message imported from a text log): the page would never answer */
	if (lineNumber.length == 0) {
		if (completionHandler) {
			completionHandler(NO);
		}

		return;
	}

	/* Jumping to line chains callback functions which may take time to load.
	 We do not want invoke the completion handler until we know for certain
	 whether the line was jumped to. We therefore change the completion
	 handler and call it from a bridged function when we are finished. */
	/* A dictionary, not a cache: a handler that is evicted is never called */
	if (completionHandler) {
		NSMutableArray *handlers = self.jumpToLineCallbacks[lineNumber];

		if (handlers == nil) {
			handlers = [NSMutableArray array];

			self.jumpToLineCallbacks[lineNumber] = handlers;
		}

		[handlers addObject:[completionHandler copy]];
	}

	/* The line may still be waiting to be added */
	[self flushPendingAppend];

	[self.backingView evaluateFunction:@"Textual.jumpToLine" withArguments:@[lineNumber]];
}

- (void)notifyDidBecomeVisible /* When the view is switched to */
{
	[self prioritizeDeferredDocumentLoad];

	/* A document that started loading in the background may never finish */
	if (self.loaded == NO && self.documentLoadStartedAt > 0 &&
		([NSDate timeIntervalSince1970] - self.documentLoadStartedAt) > 3.0)
	{
		[self reloadStuckDocument];
	}

	[self _evaluateFunction:@"_Textual.notifyDidBecomeVisible" withArguments:nil];

	[self maybeReloadHistory];
}

- (void)notifySelectionChanged
{
	[self _evaluateFunction:@"_Textual.notifySelectionChanged" withArguments:@[@(self.selected)]];
}

- (void)notifyDidBecomeHidden
{
	[self _evaluateFunction:@"_Textual.notifyDidBecomeHidden" withArguments:nil];
}

- (void)notifyViewFinishedLoadingHistory
{
	[self _evaluateFunction:@"_Textual.viewFinishedLoadingHistory" withArguments:nil];
}

- (void)changeTextSize:(BOOL)bigger
{
	double sizeMultiplier = self.attachedWindow.textSizeMultiplier;

	[self _evaluateFunction:@"Textual.changeTextSizeMultiplier" withArguments:@[@(sizeMultiplier)]];

	[self _evaluateFunction:@"Textual.viewFontSizeChanged" withArguments:@[@(bigger)]];
}

- (void)changeScrollbackLimit
{
	NSUInteger scrollbackLimit = [TPCPreferences scrollbackVisibleLimit];

	[self _evaluateFunction:@"_MessageBuffer.setBufferLimit" withArguments:@[@(scrollbackLimit)]];
}

#pragma mark -
#pragma mark Plugins

/* The document that would answer them is being replaced */
- (void)failPendingJumps
{
	NSDictionary *pendingJumps = [self.jumpToLineCallbacks copy];

	[self.jumpToLineCallbacks removeAllObjects];

	[pendingJumps enumerateKeysAndObjectsUsingBlock:^(NSString *lineNumber, NSArray *handlers, BOOL *stop) {
		for (void (^callbackHandler)(BOOL) in handlers) {
			callbackHandler(NO);
		}
	}];
}

- (void)notifyJumpToLine:(NSString *)lineNumber successful:(BOOL)successful scrolledToBottom:(BOOL)scrolledToBottom
{
	NSParameterAssert(lineNumber != nil);

	NSArray *handlers = self.jumpToLineCallbacks[lineNumber];

	if (handlers == nil) {
		return;
	}

	/* Remove callback handler first incase the callback handler
	 tries to jump to same line number again for some reason. */
	[self.jumpToLineCallbacks removeObjectForKey:lineNumber];

	for (void (^callbackHandler)(BOOL) in handlers) {
		callbackHandler(successful);
	}
}

- (void)notifyLinesAddedToView:(NSArray<NSString *> *)lineNumbers
{
	NSParameterAssert(lineNumbers != nil);

	if (self.loaded == NO || self.terminating) {
		return;
	}

	self.activeLineCount += lineNumbers.count;

	[self notifyPluginsOfLinesPosted:lineNumbers];
}

- (void)notifyPluginsOfLinesPosted:(NSArray<NSString *> *)lineNumbers
{
	NSParameterAssert(lineNumbers != nil);

	if (self.loaded == NO || self.terminating) {
		return;
	}

	if ([sharedPluginManager() supportsFeature:THOPluginItemSupportedFeatureNewMessagePostedEvent] == NO) {
		return;
	}

	for (NSString *lineNumber in lineNumbers) {
		[THOPluginDispatcher dequeueDidPostNewMessageWithLineNumber:lineNumber forViewController:self];
	}
}

- (void)notifyLinesRemovedFromView:(NSArray<NSString *> *)lineNumbers
{
	NSParameterAssert(lineNumbers != nil);

	if (self.loaded == NO || self.terminating) {
		return;
	}

	self.activeLineCount -= lineNumbers.count;
}

- (void)notifyHistoricLogWillDeleteLines:(NSArray<NSString *> *)lineNumbers
{
	NSParameterAssert(lineNumbers != nil);

	/* It is possible for this method to be invoked before loaded is YES
	 such as when performing a clear. */
	if (/* self.loaded == NO || */ self.terminating) {
		return;
	}

	@synchronized(self.highlightedLineNumbers) {
		[self.highlightedLineNumbers removeObjectsInArray:lineNumbers];
	}
}

#pragma mark -
#pragma mark Inline Media

- (void)processingInlineMediaPayloadSucceeded:(ICLPayload *)payload
{
	[self _evaluateFunction:@"_InlineMediaLoader.processPayload" withArguments:@[payload.javaScriptObject]];
}

- (void)processingInlineMediaPayload:(ICLPayload *)payload failedWithError:(NSError *)error
{
	LogToConsoleError("Processing request for '%{public}@' at '%{public}@' failed with error: %{public}@",
		payload.uniqueIdentifier, payload.lineNumber, error.localizedDescription);
}

- (void)processInlineMedia:(NSArray<AHHyperlinkScannerResult *> *)mediaLinks atLineNumber:(NSString *)lineNumber
{
	NSParameterAssert(mediaLinks != nil);
	NSParameterAssert(lineNumber != nil);

	if (mediaLinks.count == 0) {
		return;
	}

	/* Unique list */
	NSMutableArray<NSString *> *linksMatched = [NSMutableArray array];

	NSMutableArray<AHHyperlinkScannerResult *> *linksToProcess = [NSMutableArray array];

	for (AHHyperlinkScannerResult *link in mediaLinks) {
		if ([linksMatched containsObject:link.stringValue]) {
			continue;
		}

		[linksMatched addObject:link.stringValue];

		[linksToProcess addObject:link];
	}

	[linksToProcess enumerateObjectsUsingBlock:^(AHHyperlinkScannerResult *link, NSUInteger index, BOOL *stop) {
		[self processInlineMediaAtAddress:link.stringValue
					 withUniqueIdentifier:link.uniqueIdentifier
							 atLineNumber:lineNumber
									index:index
						 addressHasScheme:link.strictMatch];
	}];
}

- (void)processInlineMediaAtAddress:(NSString *)address withUniqueIdentifier:(NSString *)uniqueIdentifier atLineNumber:(NSString *)lineNumber index:(NSUInteger)index addressHasScheme:(BOOL)addressHasScheme
{
	NSParameterAssert(address != nil);
	NSParameterAssert(uniqueIdentifier != nil);
	NSParameterAssert(lineNumber != nil);

	IRCTreeItem *associatedItem = self.associatedItem;

	[TVCLogControllerInlineMediaSharedInstance()
			 processAddress:address
	   withUniqueIdentifier:uniqueIdentifier
			   atLineNumber:lineNumber
					  index:index
		   addressHasScheme:addressHasScheme
					forItem:associatedItem];
}

- (void)processRequestedInlineMediaAtAddress:(NSString *)address withUniqueIdentifier:(NSString *)uniqueIdentifier atLineNumber:(NSString *)lineNumber index:(NSUInteger)index
{
	NSParameterAssert(address != nil);
	NSParameterAssert(uniqueIdentifier != nil);
	NSParameterAssert(lineNumber != nil);

	/* Main thread: the address book is read there */
	void (^processForLine)(TVCLogLine * _Nullable) = ^(TVCLogLine * _Nullable logLine) {
		NSString *nickname = logLine.nickname;

		if (nickname.length > 0 &&
			logLine.memberType != TVCLogLineMemberTypeLocalUser &&
			[self.associatedClient ignoresInlineMediaFromNickname:nickname])
		{
			return;
		}

		/* Asked for: as if typed in full */
		[self processInlineMediaAtAddress:address withUniqueIdentifier:uniqueIdentifier atLineNumber:lineNumber index:index addressHasScheme:YES];
	};

	/* Not saved yet: still in memory */
	TVCLogLine *unsavedLine = nil;

	@synchronized (self.unsavedLogLines) {
		for (TVCLogLine *logLine in self.unsavedLogLines) {
			if ([logLine.uniqueIdentifier isEqualToString:lineNumber]) {
				unsavedLine = logLine;

				break;
			}
		}
	}

	if (unsavedLine) {
		processForLine(unsavedLine);

		return;
	}

	[sharedHistoricLog()
	 fetchEntriesForItem:self.associatedItem
	withUniqueIdentifier:lineNumber
		beforeFetchLimit:0
		 afterFetchLimit:0
			 limitToDate:nil
	 withCompletionBlock:^(NSArray<TVCLogLine *> *entries) {
		 TVCLogLine *savedLine = nil;

		 for (TVCLogLine *logLine in entries) {
			 if ([logLine.uniqueIdentifier isEqualToString:lineNumber]) {
				 savedLine = logLine;

				 break;
			 }
		 }

		 dispatch_async(dispatch_get_main_queue(), ^{
			 processForLine(savedLine);
		 });
	 }];
}

#pragma mark -
#pragma mark Manage Highlights

- (NSUInteger)numberOfLines
{
	return self.activeLineCount;
}

- (BOOL)highlightAvailable:(BOOL)previous
{
	if (self.loaded == NO || self.terminating) {
		return NO;
	}

	@synchronized(self.highlightedLineNumbers) {
		return (self.highlightedLineNumbers.count > 0);
	}
}

- (void)nextHighlight
{
	if (self.loaded == NO || self.terminating) {
		return;
	}

	@synchronized(self.highlightedLineNumbers) {
		if (self.highlightedLineNumbers.count == 0) {
			return;
		}

		if ([self.highlightedLineNumbers containsObject:self.lastVisitedHighlight]) {
			NSUInteger hli_ci = [self.highlightedLineNumbers indexOfObject:self.lastVisitedHighlight];

			if (hli_ci == (self.highlightedLineNumbers.count - 1)) {
				/* Circle around back to the beginning of the list. */
				self.lastVisitedHighlight = self.highlightedLineNumbers[0];
			} else {
				self.lastVisitedHighlight = self.highlightedLineNumbers[(hli_ci + 1)];
			}
		} else {
			self.lastVisitedHighlight = self.highlightedLineNumbers[0];
		}

		[self jumpToLine:self.lastVisitedHighlight];
	}
}

- (void)previousHighlight
{
	if (self.loaded == NO || self.terminating) {
		return;
	}

	@synchronized(self.highlightedLineNumbers) {
		if (self.highlightedLineNumbers.count == 0) {
			return;
		}

		if ([self.highlightedLineNumbers containsObject:self.lastVisitedHighlight]) {
			NSInteger hli_ci = [self.highlightedLineNumbers indexOfObject:self.lastVisitedHighlight];

			if (hli_ci == 0) {
				/* Circle around back to the end of the list. */
				self.lastVisitedHighlight = self.highlightedLineNumbers[(self.highlightedLineNumbers.count - 1)];
			} else {
				self.lastVisitedHighlight = self.highlightedLineNumbers[(hli_ci - 1)];
			}
		} else {
			self.lastVisitedHighlight = self.highlightedLineNumbers[0];
		}

		[self jumpToLine:self.lastVisitedHighlight];
	}
}

- (void)clearWithReset:(BOOL)clearWithReset
{
	if (self.terminating) {
		return;
	}

	self.historyGeneration += 1;

	[self.printingQueue cancelOperationsForViewController:self];

	/* Lines still waiting to be drawn would be lost with their operations:
	 a theme reload saves them, so the reloaded history shows them */
	[self saveUnsavedLogLines:(clearWithReset == NO)];

	[self discardPendingAppend];

	[self failPendingJumps];

	if (clearWithReset) {
		[self historicLogResetChannel];
	}

	@synchronized(self.highlightedLineNumbers) {
		[self.highlightedLineNumbers removeAllObjects];
	}

	self.activeLineCount = 0;

	self.lastVisitedHighlight = nil;

	self.oldestLineNumber = nil;
	self.newestLineNumber = nil;

	self.lastLine = nil;

	self.loaded = NO;

	self.reloadingHistory = NO;

	self.historyLoaded = NO;

	[self scheduleInitialDocumentLoad];
}

- (void)clear
{
	if (self.terminating) {
		return;
	}

	[self clearWithReset:YES];
}

#pragma mark -
#pragma mark History

- (void)renderLogLinesBeforeLineNumber:(NSString *)lineNumber maximumNumberOfLines:(NSUInteger)maximumNumberOfLines completionBlock:(void (^)(NSArray<NSDictionary<NSString *, id> *> *))completionBlock
{
	[self _renderLogLinesAfter:NO lineNumber:lineNumber maximumNumberOfLines:maximumNumberOfLines completionBlock:completionBlock];
}

- (void)renderLogLinesAfterLineNumber:(NSString *)lineNumber maximumNumberOfLines:(NSUInteger)maximumNumberOfLines completionBlock:(void (^)(NSArray<NSDictionary<NSString *, id> *> *))completionBlock
{
	[self _renderLogLinesAfter:YES lineNumber:lineNumber maximumNumberOfLines:maximumNumberOfLines completionBlock:completionBlock];
}

- (void)_renderLogLinesAfter:(BOOL)after lineNumber:(NSString *)lineNumber maximumNumberOfLines:(NSUInteger)maximumNumberOfLines completionBlock:(void (^)(NSArray<NSDictionary<NSString *, id> *> *))completionBlock
{
	NSParameterAssert(lineNumber != nil);
	NSParameterAssert(maximumNumberOfLines > 0);
	NSParameterAssert(completionBlock != nil);

	/* Past the scrollback: lines from the message archive */
	if ([lineNumber hasPrefix:_archiveLinePrefix]) {
		[self _renderArchiveLinesAfter:after lineNumber:lineNumber maximumNumberOfLines:maximumNumberOfLines completionBlock:completionBlock];

		return;
	}

	NSUInteger historyGeneration = self.historyGeneration;

	NSString *archiveViewId = [self _archiveViewId];

	TVCLogControllerPrintingBlock operationBlock = ^(id operation) {
		void (^historicLogCompletionBlock)(NSArray *) = ^(NSArray<TVCLogLine *> *entries) {
			if ([operation isCancelled] || self.historyGeneration != historyGeneration) {
				return;
			}

			/* The scrollback may end here: older lines come from the archive */
			if (after == NO && entries.count < maximumNumberOfLines && archiveViewId) {
				[self _continueLines:entries
						 beforeLineNumber:lineNumber
					  intoArchiveOfView:archiveViewId
					 maximumNumberOfLines:maximumNumberOfLines
						historyGeneration:historyGeneration
						  completionBlock:completionBlock];

				return;
			}

			[self _renderLogLinesAfterLineNumberPostFlight:entries completionBlock:completionBlock];
		};

		if (after == NO) {
			[sharedHistoricLog()
			 fetchEntriesForItem:self.associatedItem
		  beforeUniqueIdentifier:lineNumber
					  fetchLimit:maximumNumberOfLines
					 limitToDate:nil
			 withCompletionBlock:historicLogCompletionBlock];
		} else {
			[sharedHistoricLog()
			 fetchEntriesForItem:self.associatedItem
		   afterUniqueIdentifier:lineNumber
					  fetchLimit:maximumNumberOfLines
					 limitToDate:nil
			 withCompletionBlock:historicLogCompletionBlock];
		}
	};

	_enqueueBlockStandalone(operationBlock)
}

- (void)renderLogLineAtLineNumber:(NSString *)lineNumber numberOfLinesBefore:(NSUInteger)numberOfLinesBefore numberOfLinesAfter:(NSUInteger)numberOfLinesAfter completionBlock:(void (^)(NSArray<NSDictionary<NSString *,id> *> * _Nonnull))completionBlock
{
	NSParameterAssert(lineNumber != nil);
	NSParameterAssert(completionBlock != nil);

	/* A message older than the scrollback (a search result) */
	if ([lineNumber hasPrefix:_archiveLinePrefix]) {
		[self _renderArchiveLine:lineNumber numberOfLinesBefore:numberOfLinesBefore numberOfLinesAfter:numberOfLinesAfter completionBlock:completionBlock];

		return;
	}

	NSUInteger historyGeneration = self.historyGeneration;

	TVCLogControllerPrintingBlock operationBlock = ^(id operation) {
		void (^historicLogCompletionBlock)(NSArray *) = ^(NSArray<TVCLogLine *> *entries) {
			if ([operation isCancelled] || self.historyGeneration != historyGeneration) {
				return;
			}

			[self _renderLogLinesAfterLineNumberPostFlight:entries completionBlock:completionBlock];
		};

		[sharedHistoricLog()
			 fetchEntriesForItem:self.associatedItem
			withUniqueIdentifier:lineNumber
				beforeFetchLimit:numberOfLinesBefore
				 afterFetchLimit:numberOfLinesAfter
					 limitToDate:nil
			 withCompletionBlock:historicLogCompletionBlock];
	};

	_enqueueBlockStandalone(operationBlock)
}

#pragma mark -
#pragma mark Past the Scrollback (10.9 D)

/* When the scrollback ends, the chat goes on with the message archive:
 messages, actions, notices and topic changes, without formatting. A line
 says where the scrollback ends ("archive-boundary"); the archive's lines are
 "archive-<row>". The page keeps only so many lines (its buffer limits), so
 scrolling back as far as the archive goes doesn't pile up. */

/* The archive's view for this item, or nil (utility channels aren't kept) */
- (nullable NSString *)_archiveViewId
{
	IRCTreeItem *item = self.associatedItem;

	if (item == nil || [TLOMessageArchiveView viewForItem:item] == nil) {
		return nil;
	}

	return item.uniqueIdentifier;
}

+ (int64_t)_archiveRowIdForLineNumber:(NSString *)lineNumber
{
	if ([lineNumber hasPrefix:_archiveLinePrefix] == NO || [lineNumber isEqualToString:_archiveBoundaryLineNumber]) {
		return 0;
	}

	return [lineNumber substringFromIndex:_archiveLinePrefix.length].longLongValue;
}

/* The oldest line of the scrollback (nil when it's empty): the archive's
 lines are those before it */
- (void)_fetchOldestScrollbackLine:(void (^)(TVCLogLine * _Nullable logLine))completionBlock
{
	[sharedHistoricLog() fetchEntriesForItem:self.associatedItem
								   ascending:YES
								  fetchLimit:1
								 limitToDate:nil
						 withCompletionBlock:^(NSArray<TVCLogLine *> *entries) {
		completionBlock(entries.firstObject);
	}];
}

- (void)_fetchFirstScrollbackLines:(NSUInteger)count completionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock
{
	if (count == 0) {
		completionBlock(@[]);

		return;
	}

	[sharedHistoricLog() fetchEntriesForItem:self.associatedItem
								   ascending:YES
								  fetchLimit:count
								 limitToDate:nil
						 withCompletionBlock:completionBlock];
}

/* Lines for the archive's messages; previous is the message before the first
 (for the day it starts), if known */
- (NSArray<TVCLogLine *> *)_logLinesForArchiveMessages:(NSArray<TLOMessageArchiveResult *> *)messages previous:(nullable TLOMessageArchiveResult *)previous
{
	NSCalendar *calendar = [NSCalendar currentCalendar];

	NSMutableArray<TVCLogLine *> *logLines = [NSMutableArray arrayWithCapacity:messages.count];

	for (TLOMessageArchiveResult *message in messages) {
		TVCLogLineMutable *logLine = [TVCLogLineMutable new];

		logLine.lineType = message.lineType;
		logLine.memberType = ((message.isSelf) ? TVCLogLineMemberTypeLocalUser : TVCLogLineMemberTypeNormal);
		logLine.nickname = message.nickname;
		logLine.messageBody = message.body;
		logLine.receivedAt = message.date;
		logLine.msgid = message.msgid;

		if (message.lineType == TVCLogLineTypeNotice) {
			logLine.command = @"NOTICE";
		} else if (message.lineType == TVCLogLineTypeTopic) {
			logLine.command = @"TOPIC";
		} else {
			logLine.command = @"PRIVMSG";
		}

		logLine.isFirstForDay = (previous == nil || [calendar isDate:message.date inSameDayAsDate:previous.date] == NO);

		NSString *lineNumber = [_archiveLinePrefix stringByAppendingFormat:@"%lld", message.rowId];

		[logLines addObject:[logLine copyAsArchivedLineWithUniqueIdentifier:lineNumber]];

		previous = message;
	}

	return [logLines copy];
}

/* "The scrollback ends here; older messages come from the archive" */
- (TVCLogLine *)_archiveBoundaryLineAt:(NSDate *)date
{
	TVCLogLineMutable *logLine = [TVCLogLineMutable new];

	logLine.lineType = TVCLogLineTypeDebug;
	logLine.messageBody = TXTLS(@"TVCMainWindow[arc-b1]");
	logLine.receivedAt = date;

	return [logLine copyAsArchivedLineWithUniqueIdentifier:_archiveBoundaryLineNumber];
}

/* The archive's messages next to a point, without those the scrollback has
 (a server's history replayed on joining has times before the scrollback's
 first line, and is in the scrollback too): up to count, oldest first. From
 the message rowId, or with 0 from where the scrollback starts. Older ones:
 also the message before them (for the day they start), if any. Newer ones:
 also the message at rowId. */
- (void)_collectArchiveMessagesInView:(NSString *)viewId
								rowId:(int64_t)rowId
								older:(BOOL)older
								count:(NSUInteger)count
						   oldestLine:(nullable TVCLogLine *)oldestLine
					  completionBlock:(void (^)(NSArray<TLOMessageArchiveResult *> *messages, TLOMessageArchiveResult * _Nullable previous))completionBlock
{
	[self _collectArchiveMessagesInView:viewId
								  rowId:rowId
								  older:older
								  count:count
							 oldestLine:oldestLine
							  collected:@[]
								 anchor:nil
						   attemptsLeft:5
						completionBlock:completionBlock];
}

- (void)_collectArchiveMessagesInView:(NSString *)viewId
								rowId:(int64_t)rowId
								older:(BOOL)older
								count:(NSUInteger)count
						   oldestLine:(nullable TVCLogLine *)oldestLine
							collected:(NSArray<TLOMessageArchiveResult *> *)collected
							   anchor:(nullable TLOMessageArchiveResult *)anchor
						 attemptsLeft:(NSUInteger)attemptsLeft
					  completionBlock:(void (^)(NSArray<TLOMessageArchiveResult *> *messages, TLOMessageArchiveResult * _Nullable previous))completionBlock
{
	/* Older: one more, for the day */
	NSUInteger wanted = (count + ((older) ? 1 : 0));

	void (^finishBlock)(NSArray<TLOMessageArchiveResult *> *, TLOMessageArchiveResult *) = ^(NSArray<TLOMessageArchiveResult *> *messages, TLOMessageArchiveResult *anchorMessage) {
		if (older == NO) {
			if (messages.count > count) {
				messages = [messages subarrayWithRange:NSMakeRange(0, count)];
			}

			completionBlock(messages, anchorMessage);

			return;
		}

		if (messages.count > wanted) {
			messages = [messages subarrayWithRange:NSMakeRange((messages.count - wanted), wanted)];
		}

		TLOMessageArchiveResult *previous = nil;

		if (messages.count > count) {
			previous = messages.firstObject;

			messages = [messages subarrayWithRange:NSMakeRange(1, (messages.count - 1))];
		}

		completionBlock(messages, previous);
	};

	/* A few more than wanted: some may be in the scrollback */
	NSUInteger fetchCount = ((wanted - MIN(wanted, collected.count)) + 20);

	NSTimeInterval scrollbackTime = ((oldestLine) ? oldestLine.receivedAt.timeIntervalSince1970 : DBL_MAX);

	[sharedMessageArchive() messagesInView:viewId
									 rowId:rowId
									before:((older) ? fetchCount : 0)
									 after:((older) ? 0 : fetchCount)
						  scrollbackLineId:oldestLine.uniqueIdentifier
							scrollbackTime:scrollbackTime
						 completionHandler:^(NSArray<TLOMessageArchiveResult *> *messages, NSUInteger anchorIndex) {
		/* From a message that's gone (or the scrollback has it) */
		if (rowId != 0 && anchorIndex == NSNotFound) {
			finishBlock(collected, anchor);

			return;
		}

		NSMutableArray<TLOMessageArchiveResult *> *candidates = [messages mutableCopy];

		TLOMessageArchiveResult *anchorMessage = anchor;

		if (anchorIndex != NSNotFound) {
			if (anchorMessage == nil) {
				anchorMessage = candidates[anchorIndex];
			}

			[candidates removeObjectAtIndex:anchorIndex];
		}

		if (candidates.count == 0) {
			finishBlock(collected, anchorMessage);

			return;
		}

		BOOL exhausted = (candidates.count < fetchCount);

		[sharedHistoricLog() fetchUniqueIdentifiers:[candidates valueForKey:@"lineId"] forItem:self.associatedItem completionBlock:^(NSSet<NSString *> *present) {
			NSMutableArray<TLOMessageArchiveResult *> *kept = [NSMutableArray arrayWithCapacity:candidates.count];

			for (TLOMessageArchiveResult *candidate in candidates) {
				if ([present containsObject:candidate.lineId] == NO) {
					[kept addObject:candidate];
				}
			}

			NSArray *all = ((older) ? [kept arrayByAddingObjectsFromArray:collected] : [collected arrayByAddingObjectsFromArray:kept]);

			if (all.count >= wanted || exhausted || attemptsLeft <= 1) {
				finishBlock(all, anchorMessage);

				return;
			}

			/* All in the scrollback so far: on past them */
			int64_t nextRowId = ((older) ? candidates.firstObject.rowId : candidates.lastObject.rowId);

			[self _collectArchiveMessagesInView:viewId
										  rowId:nextRowId
										  older:older
										  count:count
									 oldestLine:oldestLine
									  collected:all
										 anchor:anchorMessage
								   attemptsLeft:(attemptsLeft - 1)
								completionBlock:completionBlock];
		}];
	}];
}

/* Lines of the scrollback came back short: if that's because it ends, the
 archive's older messages come before them, with the boundary line */
- (void)_continueLines:(NSArray<TVCLogLine *> *)entries
	  beforeLineNumber:(NSString *)lineNumber
	 intoArchiveOfView:(NSString *)viewId
  maximumNumberOfLines:(NSUInteger)maximumNumberOfLines
	 historyGeneration:(NSUInteger)historyGeneration
	   completionBlock:(void (^)(NSArray<NSDictionary<NSString *, id> *> *))completionBlock
{
	[self _fetchOldestScrollbackLine:^(TVCLogLine *oldestLine) {
		NSString *firstLineNumber = ((entries.count > 0) ? entries.firstObject.uniqueIdentifier : lineNumber);

		/* Not the end (lines missing in between): as it was */
		if (oldestLine == nil || [oldestLine.uniqueIdentifier isEqualToString:firstLineNumber] == NO) {
			[self _renderLogLinesAfterLineNumberPostFlight:entries completionBlock:completionBlock];

			return;
		}

		[self _collectArchiveMessagesInView:viewId rowId:0 older:YES count:(maximumNumberOfLines - entries.count) oldestLine:oldestLine completionBlock:^(NSArray<TLOMessageArchiveResult *> *messages, TLOMessageArchiveResult *previous) {
			if (self.historyGeneration != historyGeneration) {
				return;
			}

			if (messages.count == 0) {
				[self _renderLogLinesAfterLineNumberPostFlight:entries completionBlock:completionBlock];

				return;
			}

			NSMutableArray<TVCLogLine *> *logLines = [NSMutableArray array];

			[logLines addObjectsFromArray:[self _logLinesForArchiveMessages:messages previous:previous]];
			[logLines addObject:[self _archiveBoundaryLineAt:oldestLine.receivedAt]];
			[logLines addObjectsFromArray:entries];

			[self _renderLogLinesAfterLineNumberPostFlight:logLines completionBlock:completionBlock];
		}];
	}];
}

/* Before or after an archive line or the boundary line */
- (void)_renderArchiveLinesAfter:(BOOL)after lineNumber:(NSString *)lineNumber maximumNumberOfLines:(NSUInteger)maximumNumberOfLines completionBlock:(void (^)(NSArray<NSDictionary<NSString *, id> *> *))completionBlock
{
	NSString *viewId = [self _archiveViewId];

	if (viewId == nil) {
		completionBlock(@[]);

		return;
	}

	NSUInteger historyGeneration = self.historyGeneration;

	int64_t rowId = [self.class _archiveRowIdForLineNumber:lineNumber];

	void (^renderBlock)(NSArray<TVCLogLine *> *) = ^(NSArray<TVCLogLine *> *logLines) {
		if (self.historyGeneration != historyGeneration) {
			return;
		}

		[self _renderLogLinesAfterLineNumberPostFlight:logLines completionBlock:completionBlock];
	};

	[self _fetchOldestScrollbackLine:^(TVCLogLine *oldestLine) {
		/* Older: from the archive */
		if (after == NO) {
			[self _collectArchiveMessagesInView:viewId rowId:rowId older:YES count:maximumNumberOfLines oldestLine:oldestLine completionBlock:^(NSArray<TLOMessageArchiveResult *> *messages, TLOMessageArchiveResult *previous) {
				renderBlock([self _logLinesForArchiveMessages:messages previous:previous]);
			}];

			return;
		}

		/* Newer than the boundary line: the scrollback from its start */
		if (rowId == 0) {
			[self _fetchFirstScrollbackLines:maximumNumberOfLines completionBlock:renderBlock];

			return;
		}

		/* Newer than an archive line: the archive up to the boundary, then the scrollback */
		[self _collectArchiveMessagesInView:viewId rowId:rowId older:NO count:maximumNumberOfLines oldestLine:oldestLine completionBlock:^(NSArray<TLOMessageArchiveResult *> *newer, TLOMessageArchiveResult *anchor) {
			NSArray<TVCLogLine *> *archiveLines = [self _logLinesForArchiveMessages:newer previous:anchor];

			if (newer.count >= maximumNumberOfLines || oldestLine == nil) {
				renderBlock(archiveLines);

				return;
			}

			[self _fetchFirstScrollbackLines:(maximumNumberOfLines - newer.count - 1) completionBlock:^(NSArray<TVCLogLine *> *entries) {
				NSMutableArray<TVCLogLine *> *logLines = [archiveLines mutableCopy];

				[logLines addObject:[self _archiveBoundaryLineAt:oldestLine.receivedAt]];
				[logLines addObjectsFromArray:entries];

				renderBlock(logLines);
			}];
		}];
	}];
}

/* A jump to an archive line: it with lines around it */
- (void)_renderArchiveLine:(NSString *)lineNumber numberOfLinesBefore:(NSUInteger)numberOfLinesBefore numberOfLinesAfter:(NSUInteger)numberOfLinesAfter completionBlock:(void (^)(NSArray<NSDictionary<NSString *, id> *> *))completionBlock
{
	NSString *viewId = [self _archiveViewId];

	int64_t rowId = [self.class _archiveRowIdForLineNumber:lineNumber];

	if (viewId == nil || rowId == 0) {
		completionBlock(@[]);

		return;
	}

	NSUInteger historyGeneration = self.historyGeneration;

	void (^renderBlock)(NSArray<TVCLogLine *> *) = ^(NSArray<TVCLogLine *> *logLines) {
		if (self.historyGeneration != historyGeneration) {
			return;
		}

		[self _renderLogLinesAfterLineNumberPostFlight:logLines completionBlock:completionBlock];
	};

	[self _fetchOldestScrollbackLine:^(TVCLogLine *oldestLine) {
		[self _collectArchiveMessagesInView:viewId rowId:rowId older:NO count:numberOfLinesAfter oldestLine:oldestLine completionBlock:^(NSArray<TLOMessageArchiveResult *> *newer, TLOMessageArchiveResult *anchor) {
			/* Gone, or not past the scrollback */
			if (anchor == nil) {
				renderBlock(@[]);

				return;
			}

			[sharedHistoricLog() fetchUniqueIdentifiers:@[anchor.lineId] forItem:self.associatedItem completionBlock:^(NSSet<NSString *> *present) {
				/* The scrollback has it */
				if (present.count > 0) {
					renderBlock(@[]);

					return;
				}

				[self _collectArchiveMessagesInView:viewId rowId:rowId older:YES count:numberOfLinesBefore oldestLine:oldestLine completionBlock:^(NSArray<TLOMessageArchiveResult *> *older, TLOMessageArchiveResult *previous) {
					NSMutableArray<TLOMessageArchiveResult *> *shown = [older mutableCopy];

					[shown addObject:anchor];
					[shown addObjectsFromArray:newer];

					NSArray<TVCLogLine *> *archiveLines = [self _logLinesForArchiveMessages:shown previous:previous];

					if (newer.count >= numberOfLinesAfter || oldestLine == nil) {
						renderBlock(archiveLines);

						return;
					}

					[self _fetchFirstScrollbackLines:(numberOfLinesAfter - newer.count) completionBlock:^(NSArray<TVCLogLine *> *entries) {
						NSMutableArray<TVCLogLine *> *logLines = [archiveLines mutableCopy];

						[logLines addObject:[self _archiveBoundaryLineAt:oldestLine.receivedAt]];
						[logLines addObjectsFromArray:entries];

						renderBlock(logLines);
					}];
				}];
			}];
		}];
	}];
}

- (void)_renderLogLinesAfterLineNumberPostFlight:(NSArray<TVCLogLine *> *)logLines completionBlock:(void (^)(NSArray<NSDictionary<NSString *, id> *> *))completionBlock
{
	NSParameterAssert(logLines != nil);
	NSParameterAssert(completionBlock != nil);

	NSMutableArray<NSDictionary<NSString *, id> *> *renderedLogLines = [NSMutableArray arrayWithCapacity:logLines.count];

	NSMutableArray<THOPluginDidPostNewMessageConcreteObject *> *pluginObjects = nil;

	/* The first line has no neighbour on screen yet, so it shows its sender */
	TVCLogLine *previousLine = nil;

	for (TVCLogLine *logLine in logLines) {
		/* Render result info HTML */
		NSDictionary<NSString *, id> *resultInfo = nil;

		NSString *html = [self renderLogLine:logLine previousLine:previousLine resultInfo:&resultInfo];

		if (html == nil) {
			LogToConsoleError("Failed to render log line %{public}@", logLine.description);

			continue;
		}

		previousLine = logLine;

		/* Record information about rendering */
		NSString *lineNumber = logLine.uniqueIdentifier;

		[renderedLogLines addObject:@{
			@"lineNumber" : lineNumber,
			@"html" : html,
			@"timestamp" : @(logLine.receivedAt.timeIntervalSince1970)
		}];

		/* Add reference to plugin concrete object */
		THOPluginDidPostNewMessageConcreteObject *pluginObject = resultInfo[@"pluginConcreteObject"];

		if (pluginObject) {
			if (pluginObjects == nil) {
				pluginObjects = [NSMutableArray array];
			}

			[pluginObjects addObject:pluginObject];
		}
	}

	/* Inform plugins of new content */
	for (THOPluginDidPostNewMessageConcreteObject *pluginObject in pluginObjects) {
		pluginObject.isProcessedInBulk = YES;

		[THOPluginDispatcher enqueueDidPostNewMessage:pluginObject];
	}

	/* Finish */
	completionBlock([renderedLogLines copy]);
}

#pragma mark -
#pragma mark Print

- (void)print:(TVCLogLine *)logLine
{
	[self print:logLine completionBlock:NULL];
}

- (void)print:(TVCLogLine *)logLine completionBlock:(nullable TVCLogControllerPrintOperationCompletionBlock)completionBlock
{
	NSParameterAssert(logLine != nil);

	if (self.terminating) {
		return;
	}

	if ([logLine isKindOfClass:[TVCLogLineMutable class]]) {
		logLine = [logLine copy];
	}

	/* Lines render in the order they are printed: this is the one above it */
	TVCLogLine *previousLine = self.lastLine;

	self.lastLine = logLine;

	@synchronized (self.unsavedLogLines) {
		[self.unsavedLogLines addObject:logLine];
	}

	/* Known by its ID right away: a reaction or a deletion can come before the line is drawn */
	TVCLogLineType printedLineType = logLine.lineType;

	if (printedLineType == TVCLogLineTypePrivateMessage || printedLineType == TVCLogLineTypeAction || printedLineType == TVCLogLineTypeNotice) {
		[self rememberMessageReferenceForLine:logLine];
	}

	/* Unread counts, highlights and notifications don't wait for the document:
	 views in the background load a few at a time, which held them back for
	 tens of seconds. The line itself still waits, so it is shown once. */
	BOOL notifiedEarly = (self.loaded == NO && completionBlock != nil);

	if (notifiedEarly) {
		[self notifyEarlyOfLogLine:logLine completionBlock:completionBlock];
	}

	/* Decided here: the address book is read on the main thread only */
	BOOL ignoreInlineMedia = NO;

	NSString *senderNickname = logLine.nickname;

	if (senderNickname.length > 0 && logLine.memberType != TVCLogLineMemberTypeLocalUser && [NSThread isMainThread]) {
		ignoreInlineMedia = [self.associatedClient ignoresInlineMediaFromNickname:senderNickname];
	}

	/* Where it was said, for the message archive, read here and not
	 on the printing queue; nil for utility channels, which aren't kept, and
	 when the archive is off or leaves this server or channel out */
	TLOMessageArchiveView *archiveView = nil;

	IRCTreeItem *archiveItem = self.associatedItem;

	if (archiveItem && [TLOMessageArchive archivesLineType:logLine.lineType] && [TLOMessageArchive keepsMessagesOfItem:archiveItem]) {
		archiveView = [TLOMessageArchiveView viewForItem:archiveItem];
	}

	TVCLogControllerPrintingBlock printBlock = ^(id operation) {
		NSDictionary<NSString *, id> *resultInfo = nil;

		NSString *html = [self renderLogLine:logLine previousLine:previousLine resultInfo:&resultInfo];

		if (html == nil) {
			LogToConsoleError("Failed to render log line %{public}@", logLine.description);

			/* Never shown, so not saved later either */
			[self takeUnsavedLogLine:logLine];

			(void)[self logLineApplyingPendingChanges:logLine];

			return;
		}

		NSString *lineNumber = logLine.uniqueIdentifier;

		NSSet<IRCChannelUser *> *listOfUsers = resultInfo[TVCLogRendererResultsListOfUsersFoundAttribute];

		BOOL processInlineMedia = [resultInfo boolForKey:@"processInlineMedia"];

		BOOL highlighted = [resultInfo boolForKey:TVCLogRendererResultsKeywordMatchFoundAttribute];

		NSString *highlightKeyword = resultInfo[TVCLogRendererResultsMatchedKeywordAttribute];

		THOPluginDidPostNewMessageConcreteObject *pluginObject = resultInfo[@"pluginConcreteObject"];

		/* Kept even when a clear drops it from the view */
		if (archiveView) {
			NSArray *listOfLinks = resultInfo[TVCLogRendererResultsListOfLinksInBodyAttribute];

			[sharedMessageArchive() archiveLogLine:logLine highlighted:highlighted hasLink:(listOfLinks.count > 0) inView:archiveView];
		}

		XRPerformBlockAsynchronouslyOnMainQueue(^{
			if (self.terminating) {
				return;
			}

			/* A clear since rendering began saved or dropped this line already: it isn't
			 appended again, but its highlight, unread count and notification still happen */
			if ([self takeUnsavedLogLine:logLine] == NO) {
				if (notifiedEarly == NO) {
					[self finishPrintingLogLine:logLine highlighted:highlighted highlightKeyword:highlightKeyword listOfUsers:listOfUsers completionBlock:completionBlock];
				}

				return;
			}

			if (self.oldestLineNumber == nil) {
				self.oldestLineNumber = lineNumber;
			}

			self.newestLineNumber = lineNumber;

			if (highlighted) {
				[self recordHighlightOfLogLine:logLine];
			}

			if (pluginObject) {
				[THOPluginDispatcher enqueueDidPostNewMessage:resultInfo[@"pluginConcreteObject"]];
			}

			[self appendToDocumentBody:html withLineNumbers:@[lineNumber]];

			/* TODO: Modify logic of inline media to only truly
			 process images if the line is in fact on the WebView. */
			/* Begin processing inline media */
			/* We go through the inline media list here and pass to the loader now so
			 that we know the links have hit the WebView before we even try loading them. */
			if (processInlineMedia && ignoreInlineMedia == NO) {
				NSArray<AHHyperlinkScannerResult *> *listOfLinks = resultInfo[TVCLogRendererResultsListOfLinksInBodyAttribute];

				[self processInlineMedia:listOfLinks atLineNumber:lineNumber];
			}

			/* Log this log line, with what changed since it was printed */
			[sharedHistoricLog() writeNewEntryWithLogLine:[self logLineApplyingPendingChanges:logLine] forItem:self.associatedItem];

			if (notifiedEarly) {
				return;
			}

			[self finishPrintingLogLine:logLine highlighted:highlighted highlightKeyword:highlightKeyword listOfUsers:listOfUsers completionBlock:completionBlock];
		});
	};

	_enqueueBlock(printBlock)
}

/* YES when the line was still waiting to be saved (and now isn't) */
- (BOOL)takeUnsavedLogLine:(TVCLogLine *)logLine
{
	@synchronized (self.unsavedLogLines) {
		NSUInteger index = [self.unsavedLogLines indexOfObjectIdenticalTo:logLine];

		if (index == NSNotFound) {
			return NO;
		}

		[self.unsavedLogLines removeObjectAtIndex:index];
	}

	return YES;
}

- (void)saveUnsavedLogLines:(BOOL)save
{
	NSArray<TVCLogLine *> *logLines = nil;

	@synchronized (self.unsavedLogLines) {
		logLines = [self.unsavedLogLines copy];

		[self.unsavedLogLines removeAllObjects];
	}

	if (save == NO) {
		for (TVCLogLine *logLine in logLines) {
			(void)[self logLineApplyingPendingChanges:logLine];
		}

		return;
	}

	for (TVCLogLine *logLine in logLines) {
		[sharedHistoricLog() writeNewEntryWithLogLine:[self logLineApplyingPendingChanges:logLine] forItem:self.associatedItem];
	}
}

/* The line with the changes made while it waited to be saved (reactions, deleting) */
/* The line with what changed since it was printed, leaving the changes for its saving */
- (TVCLogLine *)logLineWithPendingChanges:(TVCLogLine *)logLine
{
	NSParameterAssert(logLine != nil);

	NSArray *changes = nil;

	@synchronized (self.unsavedLogLines) {
		changes = [self.pendingLineChanges[logLine.uniqueIdentifier] copy];
	}

	for (TVCLogLine * _Nullable (^change)(TVCLogLine *) in changes) {
		TVCLogLine *changedLine = change(logLine);

		if (changedLine) {
			logLine = changedLine;
		}
	}

	return logLine;
}

- (TVCLogLine *)logLineApplyingPendingChanges:(TVCLogLine *)logLine
{
	NSParameterAssert(logLine != nil);

	NSArray *changes = nil;

	@synchronized (self.unsavedLogLines) {
		changes = self.pendingLineChanges[logLine.uniqueIdentifier];

		[self.pendingLineChanges removeObjectForKey:logLine.uniqueIdentifier];
	}

	for (TVCLogLine * _Nullable (^change)(TVCLogLine *) in changes) {
		TVCLogLine *changedLine = change(logLine);

		if (changedLine) {
			logLine = changedLine;
		}
	}

	return logLine;
}

/* Renders only the message body (for its highlight and nicknames) on a serial
 queue, so the notifications keep the order the lines were printed in */
- (void)notifyEarlyOfLogLine:(TVCLogLine *)logLine completionBlock:(TVCLogControllerPrintOperationCompletionBlock)completionBlock
{
	NSParameterAssert(logLine != nil);
	NSParameterAssert(completionBlock != nil);

	static dispatch_queue_t earlyNotificationQueue = NULL;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		earlyNotificationQueue = dispatch_queue_create("TVCLogController.earlyNotificationQueue", DISPATCH_QUEUE_SERIAL);
	});

	dispatch_async(earlyNotificationQueue, ^{
		NSDictionary<NSString *, id> *rendererResults = nil;

		(void)[TVCLogRenderer renderBody:logLine.messageBody
					   forViewController:self
						  withAttributes:[self rendererAttributesForLogLine:logLine]
							  resultInfo:&rendererResults];

		BOOL highlighted = [rendererResults boolForKey:TVCLogRendererResultsKeywordMatchFoundAttribute];

		NSString *highlightKeyword = rendererResults[TVCLogRendererResultsMatchedKeywordAttribute];

		NSSet<IRCChannelUser *> *listOfUsers = rendererResults[TVCLogRendererResultsListOfUsersFoundAttribute];

		XRPerformBlockAsynchronouslyOnMainQueue(^{
			if (self.terminating) {
				return;
			}

			if (highlighted) {
				[self recordHighlightOfLogLine:logLine];
			}

			[self finishPrintingLogLine:logLine highlighted:highlighted highlightKeyword:highlightKeyword listOfUsers:listOfUsers completionBlock:completionBlock];
		});
	});
}

/* Once per line: the early notification and the printed line both get here */
- (void)recordHighlightOfLogLine:(TVCLogLine *)logLine
{
	NSParameterAssert(logLine != nil);

	NSString *lineNumber = logLine.uniqueIdentifier;

	@synchronized(self.highlightedLineNumbers) {
		if ([self.highlightedLineNumbers containsObject:lineNumber]) {
			return;
		}

		[self.highlightedLineNumbers addObject:lineNumber];
	}

	[self.associatedClient cacheHighlightInChannel:self.associatedChannel withLogLine:logLine];
}

- (void)finishPrintingLogLine:(TVCLogLine *)logLine highlighted:(BOOL)highlighted highlightKeyword:(nullable NSString *)highlightKeyword listOfUsers:(nullable NSSet<IRCChannelUser *> *)listOfUsers completionBlock:(nullable TVCLogControllerPrintOperationCompletionBlock)completionBlock
{
	NSParameterAssert(logLine != nil);

	/* Using information provided by conversation tracking we can update
	 our internal array of favored nicknames for nick completion. */
	if (logLine.memberType == TVCLogLineMemberTypeLocalUser) {
		[listOfUsers.allObjects makeObjectsPerformSelector:@selector(outgoingConversation)];
	} else {
		[listOfUsers.allObjects makeObjectsPerformSelector:@selector(conversation)];
	}

	if (completionBlock == nil) {
		return;
	}

	TVCLogControllerPrintOperationContext *contextObject =
	[TVCLogControllerPrintOperationContext new];

	contextObject.client = self.associatedClient;
	contextObject.channel = self.associatedChannel;
	contextObject.highlight = highlighted;
	contextObject.highlightKeyword = highlightKeyword;
	contextObject.logLine = logLine;
	contextObject.lineNumber = logLine.uniqueIdentifier;

	completionBlock(contextObject);
}

- (NSDictionary<NSString *, id> *)rendererAttributesForLogLine:(TVCLogLine *)logLine
{
	NSParameterAssert(logLine != nil);

	BOOL renderLinks = ([[TLOLinkParser bannedLineTypes] containsObject:logLine.lineTypeString] == NO);

	NSMutableDictionary<NSString *, id> *rendererAttributes = [NSMutableDictionary dictionary];

	if (logLine.rendererAttributes != nil) {
		[rendererAttributes addEntriesFromDictionary:logLine.rendererAttributes];
	}

	[rendererAttributes maybeSetObject:logLine.excludeKeywords forKey:TVCLogRendererConfigurationExcludedKeywordsAttribute];
	[rendererAttributes maybeSetObject:logLine.highlightKeywords forKey:TVCLogRendererConfigurationHighlightKeywordsAttribute];

	[rendererAttributes setBool:renderLinks forKey:TVCLogRendererConfigurationRenderLinksAttribute];

	[rendererAttributes setUnsignedInteger:logLine.lineType forKey:TVCLogRendererConfigurationLineTypeAttribute];
	[rendererAttributes setUnsignedInteger:logLine.memberType forKey:TVCLogRendererConfigurationMemberTypeAttribute];

	return [rendererAttributes copy];
}

/* The Chat display, unless the style's own message template predates it */
- (BOOL)groupedDisplayEnabled
{
	return ([TPCPreferences messageGroupingStyle] == TVCLogLineGroupingStyleGrouped &&
			theme().supportsGroupedDisplay);
}

NS_INLINE BOOL _lineTypeIsGroupable(TVCLogLineType lineType)
{
	return (lineType == TVCLogLineTypePrivateMessage ||
			lineType == TVCLogLineTypePrivateMessageNoHighlight ||
			lineType == TVCLogLineTypeAction ||
			lineType == TVCLogLineTypeActionNoHighlight);
}

/* A date line where the day differs from the line drawn above it. The first
 line of a batch has none above: it gets one, so a chat shortened to its
 newest lines still starts with its day (the chat hides a repeated day).
 The flag saved when printing was wrong for the first line after a launch,
 before the saved lines were loaded. */
- (BOOL)logLine:(TVCLogLine *)logLine isFirstForDayAfterLine:(nullable TVCLogLine *)previousLine
{
	NSParameterAssert(logLine != nil);

	if (previousLine == nil) {
		return YES;
	}

	return ([logLine.receivedAt isInSameDayAsDate:previousLine.receivedAt] == NO);
}

/* Shown under the sender's name of the line above it */
- (BOOL)logLine:(TVCLogLine *)logLine isGroupedWithPreviousLine:(nullable TVCLogLine *)previousLine highlighted:(BOOL)highlighted
{
	NSParameterAssert(logLine != nil);

	if (previousLine == nil || highlighted || [self logLine:logLine isFirstForDayAfterLine:previousLine]) {
		return NO;
	}

	if (_lineTypeIsGroupable(logLine.lineType) == NO || _lineTypeIsGroupable(previousLine.lineType) == NO) {
		return NO;
	}

	NSString *nickname = logLine.nickname;

	if (nickname.length == 0 || [nickname isEqualToString:previousLine.nickname] == NO) {
		return NO;
	}

	/* The session indicator is drawn after that line */
	NSString *previousLineNumber = previousLine.uniqueIdentifier;

	if ([previousLineNumber isEqualToString:self.newestLineNumberFromPreviousSession]) {
		return NO;
	}

	NSTimeInterval timeBetween = [logLine.receivedAt timeIntervalSinceDate:previousLine.receivedAt];

	return (timeBetween >= 0 && timeBetween < TVCLogControllerMessageGroupingWindow);
}

#pragma mark -
#pragma mark Message References

#define _messageReferenceLimit		2000
#define _messageReferenceExcerptLength		120

/* The messages shown in this view by ID, for showing what a reply answers */
- (void)rememberMessageReferenceForLine:(TVCLogLine *)logLine
{
	NSParameterAssert(logLine != nil);

	NSString *msgid = logLine.msgid;

	if (msgid == nil) {
		return;
	}

	NSString *excerpt = logLine.messageBody.stripIRCEffects.trim;

	if (excerpt.length > _messageReferenceExcerptLength) {
		excerpt = [[excerpt substringToIndex:_messageReferenceExcerptLength] stringByAppendingString:@"…"];
	}

	NSDictionary *reference = @{
		@"lineNumber" : logLine.uniqueIdentifier,
		@"nickname" : (logLine.nickname ?: @""),
		@"excerpt" : (excerpt ?: @""),
		@"receivedAt" : logLine.receivedAt
	};

	@synchronized (self.messageReferences) {
		NSDictionary *existing = self.messageReferences[msgid];

		if (existing == nil) {
			[self.messageReferenceOrder addObject:msgid];
		} else if ([existing[@"receivedAt"] compare:logLine.receivedAt] == NSOrderedDescending) {
			/* Older history loaded later (scrolling up) doesn't take the place
			 of the newer message with the same ID */
			return;
		}

		self.messageReferences[msgid] = reference;

		while (self.messageReferenceOrder.count > _messageReferenceLimit) {
			NSString *oldest = self.messageReferenceOrder.firstObject;

			[self.messageReferences removeObjectForKey:oldest];
			[self.messageReactions removeObjectForKey:oldest];

			[self.messageReferenceOrder removeObjectAtIndex:0];
		}
	}
}

- (nullable NSDictionary *)messageReferenceForMsgid:(NSString *)msgid
{
	NSParameterAssert(msgid != nil);

	@synchronized (self.messageReferences) {
		return self.messageReferences[msgid];
	}
}

#pragma mark -
#pragma mark Deleting

- (void)deleteMessage:(NSString *)msgid byNickname:(NSString *)nickname reason:(nullable NSString *)reason
{
	NSParameterAssert(msgid != nil);
	NSParameterAssert(nickname != nil);

	NSDictionary *reference = [self messageReferenceForMsgid:msgid];

	/* "by …" only when someone else deleted it */
	NSString *sender = reference[@"nickname"];

	BOOL bySender = (sender.length == 0 || [sender caseInsensitiveCompare:nickname] == NSOrderedSame);

	NSString *note = nil;

	if (bySender) {
		note = ((reason) ? TXTLS(@"TVCMainWindow[del-n3]", reason) : TXTLS(@"TVCMainWindow[del-n1]"));
	} else {
		note = ((reason) ? TXTLS(@"TVCMainWindow[del-n4]", nickname, reason) : TXTLS(@"TVCMainWindow[del-n2]", nickname));
	}

	@synchronized (self.messageReferences) {
		[self.messageReactions removeObjectForKey:msgid];

		if (reference) {
			NSMutableDictionary *changedReference = [reference mutableCopy];

			changedReference[@"excerpt"] = note;

			self.messageReferences[msgid] = [changedReference copy];
		}
	}

	[self evaluateFunction:@"_MessageActions.deleteMessage" withArguments:@[msgid, note]];

	/* Out of the archive, also when the line is no longer in the view */
	[sharedMessageArchive() removeMessageWithMsgid:msgid inView:self.associatedItem.uniqueIdentifier];

	/* Out of what is saved too: the text is gone, the line says why */
	[self updateSavedLineForMessage:msgid usingBlock:^TVCLogLine *(TVCLogLine *logLine) {
		TVCLogLineMutable *changedLine = [logLine mutableCopy];

		changedLine.messageBody = note;

		changedLine.isRedacted = YES;

		changedLine.reactions = nil;

		changedLine.highlightKeywords = nil;

		return [changedLine copy];
	}];
}

#pragma mark -
#pragma mark Reactions

/* The reactions as saved with the line: @[@{@"emoji" : …, @"nicknames" : @[…]}, …] */
+ (NSArray<NSDictionary *> *)reactionsSnapshot:(NSArray<NSMutableDictionary *> *)reactions
{
	NSMutableArray *snapshot = [NSMutableArray arrayWithCapacity:reactions.count];

	for (NSDictionary *reaction in reactions) {
		[snapshot addObject:@{
			@"emoji" : reaction[@"emoji"],
			@"nicknames" : [reaction[@"nicknames"] copy]
		}];
	}

	return [snapshot copy];
}

/* What the view shows: each reaction with its count, who, and whether ours */
- (NSArray<NSDictionary *> *)reactionsForView:(NSArray<NSDictionary *> *)reactions
{
	NSString *localNickname = self.associatedClient.userNickname;

	NSMutableArray *forView = [NSMutableArray arrayWithCapacity:reactions.count];

	for (NSDictionary *reaction in reactions) {
		NSArray<NSString *> *nicknames = reaction[@"nicknames"];

		BOOL mine = (localNickname && [nicknames containsObjectIgnoringCase:localNickname]);

		[forView addObject:@{
			@"emoji" : reaction[@"emoji"],
			@"count" : @(nicknames.count),
			@"nicknames" : [nicknames componentsJoinedByString:@", "],
			@"mine" : @(mine)
		}];
	}

	return [forView copy];
}

/* A line's reactions as the view should show them: those received this
 session, else the ones saved with it */
- (nullable NSArray<NSDictionary *> *)reactionsForLine:(TVCLogLine *)logLine
{
	NSString *msgid = logLine.msgid;

	if (msgid == nil) {
		return nil;
	}

	NSArray *snapshot = nil;

	@synchronized (self.messageReferences) {
		NSMutableArray<NSMutableDictionary *> *reactions = self.messageReactions[msgid];

		if (reactions == nil && logLine.reactions.count > 0) {
			reactions = [NSMutableArray array];

			for (NSDictionary *saved in logLine.reactions) {
				NSString *emoji = saved[@"emoji"];

				NSArray *nicknames = saved[@"nicknames"];

				if ([emoji isKindOfClass:[NSString class]] == NO || [nicknames isKindOfClass:[NSArray class]] == NO) {
					continue;
				}

				[reactions addObject:[@{@"emoji" : emoji, @"nicknames" : [nicknames mutableCopy]} mutableCopy]];
			}

			self.messageReactions[msgid] = reactions;
		}

		if (reactions.count == 0) {
			return nil;
		}

		snapshot = [self.class reactionsSnapshot:reactions];
	}

	return [self reactionsForView:snapshot];
}

- (void)setReaction:(NSString *)reaction byNickname:(NSString *)nickname onMessage:(NSString *)msgid added:(BOOL)added
{
	NSParameterAssert(reaction != nil);
	NSParameterAssert(nickname != nil);
	NSParameterAssert(msgid != nil);

	NSArray *snapshot = nil;

	@synchronized (self.messageReferences) {
		NSMutableArray<NSMutableDictionary *> *reactions = self.messageReactions[msgid];

		if (reactions == nil) {
			if (added == NO) {
				return;
			}

			reactions = [NSMutableArray array];

			self.messageReactions[msgid] = reactions;
		}

		NSMutableDictionary *entry = nil;

		for (NSMutableDictionary *candidate in reactions) {
			if ([candidate[@"emoji"] isEqualToString:reaction]) {
				entry = candidate;

				break;
			}
		}

		NSMutableArray<NSString *> *nicknames = entry[@"nicknames"];

		NSUInteger index = [nicknames indexOfObjectPassingTest:^BOOL(NSString *object, NSUInteger objectIndex, BOOL *stop) {
			return ([object caseInsensitiveCompare:nickname] == NSOrderedSame);
		}];

		if (added) {
			if (entry == nil) {
				entry = [@{@"emoji" : reaction, @"nicknames" : [NSMutableArray array]} mutableCopy];

				[reactions addObject:entry];

				nicknames = entry[@"nicknames"];
			} else if (index != NSNotFound) {
				return;
			}

			[nicknames addObject:nickname];
		} else {
			if (entry == nil || index == NSNotFound) {
				return;
			}

			[nicknames removeObjectAtIndex:index];

			if (nicknames.count == 0) {
				[reactions removeObject:entry];
			}
		}

		snapshot = [self.class reactionsSnapshot:reactions];
	}

	[self evaluateFunction:@"_MessageActions.setReactions" withArguments:@[msgid, [self reactionsForView:snapshot]]];

	/* Saved with the line, so they are there after a restart */
	NSArray *savedReactions = ((snapshot.count > 0) ? snapshot : nil);

	[self updateSavedLineForMessage:msgid usingBlock:^TVCLogLine *(TVCLogLine *logLine) {
		TVCLogLineMutable *changedLine = [logLine mutableCopy];

		changedLine.reactions = savedReactions;

		return [changedLine copy];
	}];
}

/* A message printed a moment ago may not be saved yet (it is, once drawn):
 the change then waits and is saved with it; otherwise the saved line changes */
- (void)updateSavedLineForMessage:(NSString *)msgid usingBlock:(TVCLogLine * _Nullable (^)(TVCLogLine *logLine))block
{
	NSParameterAssert(msgid != nil);
	NSParameterAssert(block != nil);

	NSString *lineNumber = [self messageReferenceForMsgid:msgid][@"lineNumber"];

	if (lineNumber == nil) {
		return;
	}

	[self updateSavedLineWithNumber:lineNumber usingBlock:block];
}

/* The line as saved, or as it will be when it is (still being drawn) */
- (void)updateSavedLineWithNumber:(NSString *)lineNumber usingBlock:(TVCLogLine * _Nullable (^)(TVCLogLine *logLine))block
{
	NSParameterAssert(lineNumber != nil);
	NSParameterAssert(block != nil);

	IRCTreeItem *item = self.associatedItem;

	if (item == nil) {
		return;
	}

	@synchronized (self.unsavedLogLines) {
		NSUInteger index = [self.unsavedLogLines indexOfObjectPassingTest:^BOOL(TVCLogLine *object, NSUInteger objectIndex, BOOL *stop) {
			return [object.uniqueIdentifier isEqualToString:lineNumber];
		}];

		if (index != NSNotFound) {
			NSMutableArray *changes = self.pendingLineChanges[lineNumber];

			if (changes == nil) {
				changes = [NSMutableArray array];

				self.pendingLineChanges[lineNumber] = changes;
			}

			[changes addObject:[block copy]];

			return;
		}
	}

	[sharedHistoricLog() updateEntryWithUniqueIdentifier:lineNumber forItem:item usingBlock:block];
}

#pragma mark -
#pragma mark Failed Sends

- (void)markLine:(NSString *)lineNumber asSendFailed:(NSString *)reason
{
	NSParameterAssert(lineNumber != nil);
	NSParameterAssert(reason != nil);

	[self evaluateFunction:@"_MessageActions.markFailed" withArguments:@[lineNumber, reason]];

	[self updateSavedLineWithNumber:lineNumber usingBlock:^TVCLogLine *(TVCLogLine *logLine) {
		TVCLogLineMutable *changedLine = [logLine mutableCopy];

		changedLine.sendFailedReason = reason;

		return [changedLine copy];
	}];
}

/* Out of the view and what is saved */
- (void)removeLineWithNumber:(NSString *)lineNumber
{
	NSParameterAssert(lineNumber != nil);

	[self evaluateFunction:@"_MessageActions.removeLine" withArguments:@[lineNumber]];

	@synchronized (self.unsavedLogLines) {
		NSUInteger index = [self.unsavedLogLines indexOfObjectPassingTest:^BOOL(TVCLogLine *object, NSUInteger objectIndex, BOOL *stop) {
			return [object.uniqueIdentifier isEqualToString:lineNumber];
		}];

		if (index != NSNotFound) {
			[self.unsavedLogLines removeObjectAtIndex:index];

			[self.pendingLineChanges removeObjectForKey:lineNumber];

			return;
		}
	}

	IRCTreeItem *item = self.associatedItem;

	if (item) {
		[sharedHistoricLog() removeEntryWithUniqueIdentifier:lineNumber forItem:item];
	}
}

/* Resend or Delete on a message the server refused */
- (void)performFailedSendAction:(NSString *)action onLine:(NSString *)lineNumber
{
	NSParameterAssert(action != nil);
	NSParameterAssert(lineNumber != nil);

	BOOL resend = [action isEqualToString:@"resend"];

	if (resend == NO && [action isEqualToString:@"delete"] == NO) {
		return;
	}

	IRCChannel *channel = self.associatedChannel;

	if (channel == nil) {
		return;
	}

	void (^performAction)(TVCLogLine *) = ^(TVCLogLine *logLine) {
		if (logLine.sendFailedReason == nil) {
			return;
		}

		if (resend && [channel.associatedClient resendFailedLine:logLine inChannel:channel] == NO) {
			NSBeep();

			return;
		}

		[self removeLineWithNumber:lineNumber];
	};

	/* Still being drawn, or as saved */
	TVCLogLine *unsavedLine = nil;

	@synchronized (self.unsavedLogLines) {
		for (TVCLogLine *logLine in self.unsavedLogLines) {
			if ([logLine.uniqueIdentifier isEqualToString:lineNumber]) {
				unsavedLine = [self logLineWithPendingChanges:logLine];

				break;
			}
		}
	}

	if (unsavedLine) {
		performAction(unsavedLine);

		return;
	}

	IRCTreeItem *item = self.associatedItem;

	if (item == nil) {
		return;
	}

	[sharedHistoricLog() updateEntryWithUniqueIdentifier:lineNumber forItem:item usingBlock:^TVCLogLine *(TVCLogLine *logLine) {
		XRPerformBlockAsynchronouslyOnMainQueue(^{
			performAction(logLine);
		});

		return nil; // only read
	}];
}

- (nullable NSString *)renderLogLine:(TVCLogLine *)logLine previousLine:(nullable TVCLogLine *)previousLine resultInfo:(NSDictionary<NSString *, id> ** _Nullable)resultInfo
{
	NSParameterAssert(logLine != nil);

	// ************************************************************************** /

	TVCLogLineType lineType = logLine.lineType;

	NSDictionary<NSString *, id> *rendererResults = nil;

	NSString *renderedBody =
	[TVCLogRenderer renderBody:logLine.messageBody
			 forViewController:self
				withAttributes:[self rendererAttributesForLogLine:logLine]
					resultInfo:&rendererResults];

	if (renderedBody == nil) {
		return nil;
	}

	NSMutableDictionary<NSString *, id> *resultInfoTemp = nil;

	if (resultInfo) {
		resultInfoTemp = [rendererResults mutableCopy];
	}

	BOOL highlighted = [rendererResults boolForKey:TVCLogRendererResultsKeywordMatchFoundAttribute];

	BOOL inlineMedia =
		(self.inlineMediaEnabledForView &&
		 (lineType == TVCLogLineTypePrivateMessage || lineType == TVCLogLineTypeAction));

	NSString *lineNumber = logLine.uniqueIdentifier;

	NSDate *receivedAt = logLine.receivedAt;

	// ************************************************************************** /

	NSMutableDictionary<NSString *, id> *pathAttributes = [NSMutableDictionary new];

	pathAttributes[@"activeStyleAbsolutePath"] = self.baseURL.path;

	pathAttributes[@"applicationResourcePath"] = [TPCPathInfo applicationResources];

	NSMutableDictionary<NSString *, id> *templateAttributes = [pathAttributes mutableCopy];

	// ---- //

	templateAttributes[@"timestamp"] = @(receivedAt.timeIntervalSince1970);

	templateAttributes[@"formattedTimestamp"] = logLine.formattedTimestamp;

	templateAttributes[@"localizedTimestamp"] = TXFormatDateLongStyle(receivedAt, NO);

	// ---- //

	NSString *nickname = [logLine formattedNicknameInChannel:self.associatedChannel];

	if (nickname.length == 0) {
		templateAttributes[@"isNicknameAvailable"] = @(NO);
	} else {
		templateAttributes[@"isNicknameAvailable"] = @(YES);

		templateAttributes[@"nicknameColorStyle"] = logLine.nicknameColorStyle;
		templateAttributes[@"nicknameColorStyleOverride"] = @(logLine.nicknameColorStyleOverride);

		templateAttributes[@"nicknameColorHashingEnabled"] = @([TPCPreferences disableNicknameColorHashing] == NO);

		templateAttributes[@"formattedNickname"] = nickname.trim;

		templateAttributes[@"nickname"]	= logLine.nickname;
		templateAttributes[@"nicknameType"]	= logLine.memberTypeString;
	}

	// ---- //

	templateAttributes[@"lineType"] = logLine.lineTypeString;

	templateAttributes[@"command"] = logLine.command;
	templateAttributes[@"rawCommand"] = logLine.command; // Legacy key

	// ---- //

	NSString *classAttribute = nil;

	if (lineType == TVCLogLineTypePrivateMessage || lineType == TVCLogLineTypeAction || lineType == TVCLogLineTypeNotice) {
		classAttribute = @"text";
	} else {
		classAttribute = @"event";
	}

	/* Labelled "bot" and "only you" by the view (eventGroups.js) */
	if (logLine.senderIsBot) {
		classAttribute = [classAttribute stringByAppendingString:@" bot"];
	}

	if (logLine.isPrivateInChannel) {
		classAttribute = [classAttribute stringByAppendingString:@" private"];
	}

	/* Deleted: messageBody already says so */
	if (logLine.isRedacted) {
		classAttribute = [classAttribute stringByAppendingString:@" redacted"];
	}

	/* Refused by the server: dimmed, with why and Resend, Delete */
	NSString *sendFailedReason = logLine.sendFailedReason;

	if (sendFailedReason) {
		classAttribute = [classAttribute stringByAppendingString:@" failed"];

		templateAttributes[@"sendFailedReason"] = sendFailedReason;
	}

	templateAttributes[@"lineClassAttribute"] = classAttribute;

	/* Replies, reactions and deleting: a message's ID, and for a reply
	 who and what it answers when that message was shown in this view
	 (otherwise the view looks for it, or says it's an earlier one) */
	BOOL isTextLine = (lineType == TVCLogLineTypePrivateMessage || lineType == TVCLogLineTypeAction || lineType == TVCLogLineTypeNotice);

	if (isTextLine) {
		NSString *msgid = logLine.msgid;

		if (msgid) {
			templateAttributes[@"msgid"] = msgid;

			[self rememberMessageReferenceForLine:logLine];

			NSArray *reactions = ((logLine.isRedacted) ? nil : [self reactionsForLine:logLine]);

			if (reactions) {
				NSData *reactionsData = [NSJSONSerialization dataWithJSONObject:reactions options:0 error:NULL];

				if (reactionsData) {
					templateAttributes[@"reactionsJSON"] = [[NSString alloc] initWithData:reactionsData encoding:NSUTF8StringEncoding];
				}
			}
		}

		NSString *replyToMsgid = logLine.replyToMsgid;

		if (replyToMsgid) {
			templateAttributes[@"replyToMsgid"] = replyToMsgid;

			NSDictionary *parent = [self messageReferenceForMsgid:replyToMsgid];

			if (parent) {
				templateAttributes[@"replyToLineNumber"] = parent[@"lineNumber"];
				templateAttributes[@"replyToNickname"] = parent[@"nickname"];
				templateAttributes[@"replyToExcerpt"] = parent[@"excerpt"];
			}
		}
	}

	// ---- //

	if (highlighted) {
		templateAttributes[@"highlightAttribute"] = @"true";
	} else {
		templateAttributes[@"highlightAttribute"] = @"false";
	}

	// ---- //

	templateAttributes[@"message"] = logLine.messageBody;

	templateAttributes[@"formattedMessage"]	= renderedBody;

	templateAttributes[@"isHighlight"] = @(highlighted);

	templateAttributes[@"isRemoteMessage"] = @(logLine.memberType == TVCLogLineMemberTypeNormal);

	// ---- //

	if (logLine.isEncrypted) {
		templateAttributes[@"isEncrypted"] = @(YES);
	}

	// ---- //

	NSString *serverName = self.associatedClient.networkNameAlt;

	if (serverName) {
		templateAttributes[@"configuredServerName"] = serverName;
	}

	// ---- //

	templateAttributes[@"inlineMediaEnabled"] = @(inlineMedia);

	templateAttributes[@"lineNumber"] = lineNumber;

	templateAttributes[@"lineRenderTime"] = @([NSDate timeIntervalSince1970]);

	// ---- //

	/* Who a join, part, quit or nickname change is about (collapsed runs name them) */
	NSArray<NSString *> *eventNicknames = logLine.eventNicknames;

	if (eventNicknames.count > 0) {
		templateAttributes[@"eventNickname"] = eventNicknames[0];
	}

	if (eventNicknames.count > 1) {
		templateAttributes[@"eventNewNickname"] = eventNicknames[1];
	}

	// ---- //

	if ([self groupedDisplayEnabled]) {
		templateAttributes[@"groupedDisplayEnabled"] = @(YES);

		templateAttributes[@"isGroupedWithPrevious"] = @([self logLine:logLine isGroupedWithPreviousLine:previousLine highlighted:highlighted]);
	}

	// ---- //

	if ([self logLine:logLine isFirstForDayAfterLine:previousLine] && [TPCPreferences showDateChanges]) {
		templateAttributes[@"showDateIndicator"] = @(YES);

		templateAttributes[@"dateIndicatorMessage"] = [self dateIndicatorWithDate:receivedAt];

		templateAttributes[@"dateIndicatorLabel"] = [self dateIndicatorLabelWithDate:receivedAt];

		templateAttributes[@"dateIndicatorDay"] = [self dateIndicatorDayWithDate:receivedAt];

		templateAttributes[@"dateIndicatorDayLabel"] = [self dateIndicatorDayLabelWithDate:receivedAt];
	}

	if ([lineNumber isEqualToString:self.newestLineNumberFromPreviousSession]) {
		NSString *sessionStart = TXFormatDate((self.sessionStartDate ?: [NSDate date]), NSDateFormatterNoStyle, NSDateFormatterShortStyle, NO);

		templateAttributes[@"showSessionIndicator"] = @(YES);

		templateAttributes[@"sessionIndicatorMessage"] = TXTLS(@"TVCMainWindow[4yo-mk]", sessionStart);

		templateAttributes[@"sessionIndicatorSince"] = TXTLS(@"TVCMainWindow[4yo-s1]", sessionStart);

		templateAttributes[@"sessionIndicatorDescription"] = TXTLS(@"TVCMainWindow[4yo-d1]", sessionStart);
	}

	// ************************************************************************** /

	if (resultInfoTemp) {
		resultInfoTemp[@"processInlineMedia"] = @(inlineMedia);

		if ([sharedPluginManager() supportsFeature:THOPluginItemSupportedFeatureNewMessagePostedEvent]) {
			NSArray<AHHyperlinkScannerResult *> *listOfLinks = rendererResults[TVCLogRendererResultsListOfLinksInBodyAttribute];

			 THOPluginDidPostNewMessageConcreteObject *pluginConcreteObject =
			[THOPluginDidPostNewMessageConcreteObject new];

			pluginConcreteObject.keywordMatchFound = highlighted;

			pluginConcreteObject.lineType = lineType;
			pluginConcreteObject.memberType = logLine.memberType;

			pluginConcreteObject.senderNickname = logLine.nickname;

			pluginConcreteObject.receivedAt = receivedAt;

			pluginConcreteObject.lineNumber = lineNumber;

			pluginConcreteObject.messageContents = rendererResults[TVCLogRendererResultsOriginalBodyWithoutEffectsAttribute];

			pluginConcreteObject.listOfHyperlinks = listOfLinks;

			pluginConcreteObject.listOfUsers = rendererResults[TVCLogRendererResultsListOfUsersFoundAttribute];

			resultInfoTemp[@"pluginConcreteObject"] = pluginConcreteObject;
		}
	}

	// ************************************************************************** /

	if ( resultInfo) {
		*resultInfo = [resultInfoTemp copy];
	}

	// ************************************************************************** /

	GRMustacheTemplate *template = [theme() templateWithLineType:lineType];

	NSString *html = [TVCLogRenderer renderTemplate:template attributes:templateAttributes];

	return html;
}

#pragma mark -
#pragma mark Initial Document

- (BOOL)usesCustomScrollers
{
	NSScrollerStyle preferredScrollerStyle = [NSScroller preferredScrollerStyle];

	BOOL onlyShowDuringScrolling = (preferredScrollerStyle == NSScrollerStyleOverlay);

	return (onlyShowDuringScrolling == NO);
}

- (NSString *)initialDocument
{
	NSMutableDictionary *templateTokens = [self generateOverrideStyle];

	templateTokens[@"applicationResourcePath"] = [TPCPathInfo applicationResources];

	templateTokens[@"applicationTemplatesPath"] = theme().applicationTemplateRepositoryPath;

	templateTokens[@"activeStyleAbsolutePath"] = self.baseURL.path;

	templateTokens[@"activeStyleCSSFiles"] = theme().temporaryCSSFilePaths;
	templateTokens[@"activeStyleJSFiles"] = theme().temporaryJSFilePaths;

	templateTokens[@"cacheToken"] = themeController().cacheToken;

	templateTokens[@"configuredServerName"] = self.associatedClient.networkNameAlt;

	templateTokens[@"isReloadingStyle"] = @(self.reloadingTheme);

	templateTokens[@"operatingSystemVersion"] = [XRSystemInformation systemStandardVersion];

	TVCMainWindowAppearance *appearance = self.attachedWindow.userInterfaceObjects;

	templateTokens[@"appearanceDescription"] = appearance.shortAppearanceDescription;
	templateTokens[@"sidebarInversionIsEnabled"] = @(appearance.isDarkAppearance);

	templateTokens[@"userConfiguredTextEncoding"] = [NSString charsetRepFromStringEncoding:self.associatedClient.config.primaryEncoding];

	templateTokens[@"userStyleSheetRules"] = [TPCPreferences themeUserStyleSheetRules];

	templateTokens[@"usesCustomScrollers"] = @([self usesCustomScrollers]);

	IRCChannel *channel = self.associatedChannel;

	if (channel) {
		templateTokens[@"isChannelView"] = @(channel.isChannel);
		templateTokens[@"isPrivateMessageView"] = @(channel.isPrivateMessage);
		templateTokens[@"isUtilityView"] = @(channel.isUtility);

		templateTokens[@"channelName"] = channel.name;

		templateTokens[@"viewTypeToken"] = channel.channelTypeString;

		/* A private message's topic bar lists the channels you share */
		templateTokens[@"showQueryInfoBar"] = @([self.class channelShowsQueryInfoBar:channel]);
	} else {
		templateTokens[@"viewTypeToken"] = @"server";
	}

	if ([TPCPreferences rightToLeftFormatting]) {
		templateTokens[@"textDirectionToken"] = @"rtl";
	} else {
		templateTokens[@"textDirectionToken"] = @"ltr";
	}

	if ([themeSettings() underlyingWindowColorIsDark]) {
		templateTokens[@"appearanceToken"] = @"dark";
	} else {
		templateTokens[@"appearanceToken"] = @"light";
	}

	/* Only for styles that support it: one that doesn't keeps its own spacing */
	if (themeSettings().supportsMessageSpacing) {
		templateTokens[@"messageSpacingToken"] = @[@"compact", @"standard", @"roomy"][[TPCPreferences messageSpacing]];
	}

	return [TVCLogRenderer renderTemplateNamed:@"baseLayout" attributes:templateTokens];
}

- (NSMutableDictionary<NSString *, id> *)generateOverrideStyle
{
	NSMutableDictionary<NSString *, id> *templateTokens = [NSMutableDictionary dictionary];

	// ---- //

	NSFont *channelFont = themeSettings().themeChannelViewFont;

	/* The system font is a CSS keyword, not a name in quotes */
	BOOL usesSystemFont = NO;

	if (channelFont == nil) {
		channelFont = [TPCPreferences themeChannelViewFont];

		usesSystemFont = [TPCPreferences themeChannelViewFontIsSystemFont];
	}

	/* A missing font (removed since) falls back to the system font, as the page would */
	if (channelFont == nil) {
		channelFont = [NSFont systemFontOfSize:[TPCPreferences themeChannelViewFontSize]];

		usesSystemFont = YES;
	}

	if (usesSystemFont) {
		templateTokens[@"userConfiguredFontFamily"] = @"-apple-system, system-ui";
	} else {
		NSString *fontName = channelFont.fontName;

		fontName = [fontName stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
		fontName = [fontName stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];

		templateTokens[@"userConfiguredFontFamily"] = [NSString stringWithFormat:@"'%@'", fontName];
	}

	/* For templates of styles made before userConfiguredFontFamily */
	templateTokens[@"userConfiguredFontName"] = ((usesSystemFont) ? TPCPreferencesThemeFontNameSystemFont : channelFont.fontName);
	templateTokens[@"userConfiguredFontSize"] = @(channelFont.pointSize * (72.0 / 96.0));

	// ---- //

	double indentOffset = themeSettings().indentationOffset;

	BOOL groupedDisplayEnabled = [self groupedDisplayEnabled];

	templateTokens[@"groupedDisplayEnabled"] = @(groupedDisplayEnabled);

	/* Chat puts names above messages: nothing to line up */
	if (round(indentOffset) < 0.0 || [TPCPreferences rightToLeftFormatting] || groupedDisplayEnabled) {
		templateTokens[@"nicknameIndentationAvailable"] = @(NO);
	} else {
		templateTokens[@"nicknameIndentationAvailable"] = @(YES);

		NSString *timeFormat = themeSettings().themeTimestampFormat;

		if (timeFormat == nil) {
			timeFormat = [TPCPreferences themeTimestampFormat];
		}

		NSString *time = TXFormattedTimestamp([NSDate date], timeFormat);

		/* With digits of one width, as the chat view shows times (baseLayout.css) */
		NSFontDescriptor *timeDescriptor =
		[channelFont.fontDescriptor fontDescriptorByAddingAttributes:@{
			NSFontFeatureSettingsAttribute : @[@{
				NSFontFeatureTypeIdentifierKey : @(kNumberSpacingType),
				NSFontFeatureSelectorIdentifierKey : @(kMonospacedNumbersSelector)
			}]
		}];

		NSFont *timeFont = [NSFont fontWithDescriptor:timeDescriptor size:channelFont.pointSize];

		NSSize textSize = [time sizeWithAttributes:@{NSFontAttributeName : (timeFont ?: channelFont)}];

		templateTokens[@"predefinedTimestampWidth"] = @(textSize.width + indentOffset);
	}

	// ---- //

	return templateTokens;
}

#pragma mark -
#pragma mark LogView Delegate

- (void)logViewWebViewFinishedLoading
{
	if (self.loaded == NO) {
		self.loaded = YES;
	} else {
		return;
	}

	self.stuckDocumentReloadCount = 0;

	[self.backingView scheduleLayoutWatchdog];

	self.viewLoadedTimestamp = [NSDate timeIntervalSince1970];

	IRCChannel *channel = self.associatedChannel;

	NSString *viewType = nil;

	if (channel) {
		viewType = channel.channelTypeString;
	} else {
		viewType = @"server";
	}

	[self _evaluateFunction:@"Textual.viewInitiated" withArguments:@[
		 NSDictionaryNilValue(viewType),
		 NSDictionaryNilValue(self.associatedClient.uniqueIdentifier),
		 NSDictionaryNilValue(channel.uniqueIdentifier),
		 NSDictionaryNilValue(channel.name)
	]];

	double textSizeMultiplier = self.attachedWindow.textSizeMultiplier;

	NSUInteger scrollbackLimit = [TPCPreferences scrollbackVisibleLimit];

	[self _evaluateFunction:@"_Textual.viewFinishedLoading"
			  withArguments:
	 @[
		  @{
			  @"selected" : @(self.selected),
			  @"visible" : @(self.visible),
			  @"reloadingTheme" : @(self.pendingThemeReload),
			  @"textSizeMultiplier" : @(textSizeMultiplier),
			  @"scrollbackLimit" : @(scrollbackLimit),
			  @"collapseGeneralEvents" : @([TPCPreferences collapseEvents]),
			  @"eventDisplay" : [TPCPreferences eventDisplayByLineType],
			  @"messageActions" : self.messageActionsAvailability,
			  @"chatElementStrings" : @{
				  @"today" : TXFormatDate([NSDate date], NSDateFormatterLongStyle, NSDateFormatterNoStyle, YES),
				  @"yesterday" : TXFormatDate([NSDate dateWithTimeIntervalSinceNow:(-86400.0)], NSDateFormatterLongStyle, NSDateFormatterNoStyle, YES),
				  @"loadingEarlier" : TXTLS(@"TVCMainWindow[ldg-e1]"),
				  @"emptyTitle" : (channel.name ?: @""),
				  @"emptyText" : [self emptyViewText]
			  },
			  @"messageActionStrings" : @{
				  @"jumpToPresent" : TXTLS(@"TVCMainWindow[jtp-b1]"),
				  @"reply" : TXTLS(@"TVCMainWindow[rpl-b1]"),
				  @"react" : TXTLS(@"TVCMainWindow[rct-b1]"),
				  @"moreReactions" : TXTLS(@"TVCMainWindow[rct-b2]"),
				  @"delete" : TXTLS(@"TVCMainWindow[del-b1]"),
				  @"earlierMessage" : TXTLS(@"TVCMainWindow[rpl-e1]"),
				  /* "%@" stays for the reason, which the view fills in */
				  @"notSent" : TXTLS(@"TVCMainWindow[fsd-n1]", @"%@"),
				  @"notSentNoReason" : TXTLS(@"TVCMainWindow[fsd-n2]"),
				  @"resend" : TXTLS(@"TVCMainWindow[fsd-b1]"),
				  @"deleteFailed" : TXTLS(@"TVCMainWindow[fsd-b2]")
			  },
			  /* "%@" stays for the count, which the view fills in */
			  @"generalEventStrings" : @{
				  @"joined" : TXTLS(@"TVCMainWindow[e7g-j1]", @"%@"),
				  @"left" : TXTLS(@"TVCMainWindow[e7g-p1]", @"%@"),
				  @"quit" : TXTLS(@"TVCMainWindow[e7g-q1]", @"%@"),
				  @"nickname" : TXTLS(@"TVCMainWindow[e7g-n1]", @"%@"),
				  @"away" : TXTLS(@"TVCMainWindow[e7g-w1]", @"%@"),
				  @"back" : TXTLS(@"TVCMainWindow[e7g-b1]", @"%@"),
				  @"botLabel" : TXTLS(@"TVCMainWindow[bot-l1]"),
				  @"privateLabel" : TXTLS(@"TVCMainWindow[prv-l1]"),
				  @"nicknameChange" : TXTLS(@"TVCMainWindow[e7g-n2]", @"%1$@", @"%2$@"),
				  @"listPair" : TXTLS(@"TVCMainWindow[e7g-a1]", @"%1$@", @"%2$@"),
				  @"listMore" : TXTLS(@"TVCMainWindow[e7g-a2]", @"%1$@", @"%2$@"),
				  @"separator" : TXTLS(@"TVCMainWindow[e7g-s1]")
			  }
		  }
	  ]];

	self.pendingThemeReload = NO;

	[self setInitialTopic];

	[self reloadHistory];

	[self releaseDeferredDocumentLoadSlot];

	[RZNotificationCenter() postNotificationName:TVCLogControllerViewFinishedLoadingNotification object:self];

	[self.printingQueue updateReadinessState:self];
}

- (void)logViewWebViewFailedLoading
{
	/* Not from inside WebKit's delegate call */
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self reloadStuckDocument];
	});
}

- (void)logViewWebViewClosedUnexpectedly
{
	/* Reload and replay the scrollback: the saved history is kept */
	[self clearWithReset:NO];
}

- (void)logViewWebViewKeyDown:(NSEvent *)e
{
	[self.attachedWindow redirectKeyDown:e];
}

- (void)logViewWebViewReceivedDropWithFiles:(NSArray<NSString *> *)files
{
	[menuController() answerDroppedFiles:files];
}

@end

#pragma mark -

@implementation TVCLogControllerPrintOperationContext
@end

NS_ASSUME_NONNULL_END
