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

#import "IRCChannel.h"
#import "IRCChannelMemberList.h"
#import "IRCChannelUser.h"
#import "IRCClientPrivate.h"
#import "IRCUser.h"
#import "IRCWorld.h"
#import "TLOLocalization.h"
#import "TPCPreferencesUserDefaults.h"
#import "TLONicknameCompletionStatusPrivate.h"
#import "TLOMessageArchivePrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogLine.h"
#import "TVCMainWindowSplitViewPrivate.h"
#import "TVCMainWindowTextView.h"
#import "TVCMemberList.h"
#import "TXMasterController.h"
#import "TVCMainWindowInternal.h"
#import "TVCMainWindowSearchPanelPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* Results asked for at a time; the next page loads near the end of the list */
#define _pageSize					50

/* Typing pauses this long before searching */
#define _searchDelay				0.25

/* Characters of a message shown around the first match */
#define _snippetLength				240

/* Messages shown before and after an older result */
#define _contextCount				30

#define _cellInset					10.0
#define _cellTopPadding				6.0
#define _cellLineSpacing			2.0
#define _cellBottomPadding			7.0
#define _resultBodyLines			4
#define _contextBodyLines			12

#pragma mark -
#pragma mark Cells

/* Who and where (left), when (right); the text below */
@interface TVCMainWindowSearchResultCell : NSTableCellView
@property (nonatomic, strong) NSTextField *headerField;
@property (nonatomic, strong) NSTextField *dateField;
@property (nonatomic, strong) NSTextField *bodyField;
@end

@implementation TVCMainWindowSearchResultCell

+ (NSTextField *)labelWithLines:(NSUInteger)lines
{
	NSTextField *field = [NSTextField labelWithString:@""];

	field.translatesAutoresizingMaskIntoConstraints = NO;

	field.lineBreakMode = ((lines == 1) ? NSLineBreakByTruncatingTail : NSLineBreakByWordWrapping);

	field.maximumNumberOfLines = lines;

	field.cell.truncatesLastVisibleLine = YES;

	return field;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect])) {
		self.headerField = [self.class labelWithLines:1];
		self.dateField = [self.class labelWithLines:1];
		self.bodyField = [self.class labelWithLines:_resultBodyLines];

		self.dateField.font = [NSFont systemFontOfSize:11.0];
		self.dateField.textColor = [NSColor secondaryLabelColor];

		[self.headerField setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
		[self.dateField setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
		[self.dateField setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
		[self.bodyField setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationVertical];

		[self addSubview:self.headerField];
		[self addSubview:self.dateField];
		[self addSubview:self.bodyField];

		[NSLayoutConstraint activateConstraints:@[
			[self.headerField.topAnchor constraintEqualToAnchor:self.topAnchor constant:_cellTopPadding],
			[self.headerField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:_cellInset],
			[self.dateField.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.headerField.trailingAnchor constant:6.0],
			[self.dateField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:(-_cellInset)],
			[self.dateField.firstBaselineAnchor constraintEqualToAnchor:self.headerField.firstBaselineAnchor],
			[self.bodyField.topAnchor constraintEqualToAnchor:self.headerField.bottomAnchor constant:_cellLineSpacing],
			[self.bodyField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:_cellInset],
			[self.bodyField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:(-_cellInset)],
			[self.bodyField.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:(-_cellBottomPadding)],
		]];
	}

	return self;
}

@end

/* Return opens the selected result; Escape goes back to the search field */
@interface TVCMainWindowSearchResultsTable : NSTableView
@property (nonatomic, copy, nullable) void (^openHandler)(void);
@property (nonatomic, copy, nullable) void (^escapeHandler)(void);
@end

@implementation TVCMainWindowSearchResultsTable

- (void)keyDown:(NSEvent *)event
{
	if ((event.keyCode == 36 || event.keyCode == 76) && self.openHandler) { // Return, Enter
		self.openHandler();

		return;
	}

	if (event.keyCode == 53 && self.escapeHandler) { // Escape
		self.escapeHandler();

		return;
	}

	[super keyDown:event];
}

@end

#pragma mark -
#pragma mark Panel

@interface TVCMainWindowSearchPanel () <NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property (readwrite, weak, nullable) TVCMainWindow *mainWindow;
@property (readwrite) BOOL mentionsMode;
@property (nonatomic, copy) NSString *searchedText; // what the field had at the last search
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSButton *closeButton;
@property (nonatomic, strong) NSPopUpButton *scopePopUp;
@property (nonatomic, strong) NSPopUpButton *orderPopUp;
@property (nonatomic, strong) NSTextField *statusField;
@property (nonatomic, strong) NSTextField *hintField;
@property (nonatomic, strong) NSView *resultsBar; // scope, order and status
@property (nonatomic, strong) NSView *contextBar; // back to the results, where and when
@property (nonatomic, strong) NSTextField *contextTitleField;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) TVCMainWindowSearchResultsTable *tableView;
@property (nonatomic, strong) NSLayoutConstraint *topConstraint;
@property (nonatomic, strong) NSLayoutConstraint *resultsTopConstraint; // the list below the results bar
@property (nonatomic, strong) NSLayoutConstraint *contextTopConstraint; // or below the context bar
@property (nonatomic, strong) NSTextField *measuringField; // row heights
@property (nonatomic, strong, nullable) TLOMessageArchiveQuery *query; // of the results shown
@property (nonatomic, copy, nullable) NSString *queryScopeKey; // where it searched
@property (nonatomic, strong) NSMutableArray<TLOMessageArchiveResult *> *results;
@property (nonatomic, assign) BOOL hasMore;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) NSUInteger generation; // answers of an older search are dropped
@property (nonatomic, copy, nullable) NSArray<TLOMessageArchiveResult *> *contextMessages; // shown instead of the results
@property (nonatomic, strong, nullable) TLOMessageArchiveResult *contextResult;
@property (nonatomic, copy) NSString *previousSearchString; // for suggestions while typing
@property (nonatomic, assign) CGFloat measuredWidth;
@property (nonatomic, copy) NSArray<NSString *> *archivedNicknames; // suggested after those around now
@property (nonatomic, copy) NSArray<NSString *> *archivedViewNames;
@end

@implementation TVCMainWindowSearchPanel

- (instancetype)initWithWindow:(TVCMainWindow *)mainWindow
{
	NSParameterAssert(mainWindow != nil);

	return [self _initWithWindow:mainWindow mentionsMode:NO];
}

- (instancetype)initForMentions
{
	return [self _initWithWindow:nil mentionsMode:YES];
}

- (instancetype)_initWithWindow:(nullable TVCMainWindow *)mainWindow mentionsMode:(BOOL)mentionsMode
{
	if ((self = [super initWithNibName:nil bundle:nil])) {
		self.mainWindow = mainWindow;

		self.mentionsMode = mentionsMode;

		/* Mentions are of every network (results say where) */
		if (mentionsMode) {
			_scope = TVCMainWindowSearchScopeEverywhere;
		}

		self.searchedText = @"";

		self.results = [NSMutableArray array];

		self.previousSearchString = @"";

		self.archivedNicknames = @[];
		self.archivedViewNames = @[];

		return self;
	}

	return nil;
}

- (void)dealloc
{
	[RZNotificationCenter() removeObserver:self];

	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

#pragma mark -
#pragma mark Views

- (void)loadView
{
	NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 340, 500)];

	/* Search field and close button */
	NSSearchField *searchField = [NSSearchField new];

	searchField.translatesAutoresizingMaskIntoConstraints = NO;
	searchField.placeholderString = TXTLS(@"TVCMainWindow[src-p1]");
	searchField.accessibilityLabel = TXTLS(@"TVCMainWindow[src-a1]");
	searchField.delegate = self;
	searchField.sendsSearchStringImmediately = NO;
	searchField.sendsWholeSearchString = YES; // its action (Return) is handled by the delegate
	searchField.focusRingType = NSFocusRingTypeExterior;

	self.searchField = searchField;

	NSButton *closeButton = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"xmark" accessibilityDescription:TXTLS(@"TVCMainWindow[src-c1]")]
											   target:self
											   action:@selector(close:)];

	closeButton.translatesAutoresizingMaskIntoConstraints = NO;
	closeButton.bordered = NO;
	closeButton.toolTip = TXTLS(@"TVCMainWindow[src-c1]");
	closeButton.contentTintColor = [NSColor secondaryLabelColor];

	self.closeButton = closeButton;

	/* Scope, order and status */
	NSView *resultsBar = [NSView new];

	resultsBar.translatesAutoresizingMaskIntoConstraints = NO;

	self.resultsBar = resultsBar;

	NSPopUpButton *scopePopUp = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];

	scopePopUp.translatesAutoresizingMaskIntoConstraints = NO;
	scopePopUp.controlSize = NSControlSizeSmall;
	scopePopUp.font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeSmall]];
	scopePopUp.bordered = NO;
	scopePopUp.target = self;
	scopePopUp.action = @selector(scopeChanged:);
	[scopePopUp setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

	[scopePopUp addItemsWithTitles:@[@"", @"", TXTLS(@"TVCMainWindow[src-s2]")]];

	self.scopePopUp = scopePopUp;

	NSPopUpButton *orderPopUp = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];

	orderPopUp.translatesAutoresizingMaskIntoConstraints = NO;
	orderPopUp.controlSize = NSControlSizeSmall;
	orderPopUp.font = scopePopUp.font;
	orderPopUp.bordered = NO;
	orderPopUp.target = self;
	orderPopUp.action = @selector(orderChanged:);

	[orderPopUp addItemsWithTitles:@[TXTLS(@"TVCMainWindow[src-o1]"), TXTLS(@"TVCMainWindow[src-o2]")]];

	self.orderPopUp = orderPopUp;

	NSTextField *statusField = [NSTextField labelWithString:@""];

	statusField.translatesAutoresizingMaskIntoConstraints = NO;
	statusField.font = [NSFont systemFontOfSize:11.0];
	statusField.textColor = [NSColor secondaryLabelColor];

	self.statusField = statusField;

	[resultsBar addSubview:scopePopUp];
	[resultsBar addSubview:orderPopUp];
	[resultsBar addSubview:statusField];

	[NSLayoutConstraint activateConstraints:@[
		[scopePopUp.topAnchor constraintEqualToAnchor:resultsBar.topAnchor],
		[scopePopUp.leadingAnchor constraintEqualToAnchor:resultsBar.leadingAnchor constant:4.0],
		[orderPopUp.leadingAnchor constraintGreaterThanOrEqualToAnchor:scopePopUp.trailingAnchor constant:4.0],
		[orderPopUp.trailingAnchor constraintEqualToAnchor:resultsBar.trailingAnchor constant:(-4.0)],
		[orderPopUp.centerYAnchor constraintEqualToAnchor:scopePopUp.centerYAnchor],
		[statusField.topAnchor constraintEqualToAnchor:scopePopUp.bottomAnchor constant:2.0],
		[statusField.leadingAnchor constraintEqualToAnchor:resultsBar.leadingAnchor constant:_cellInset],
		[statusField.trailingAnchor constraintLessThanOrEqualToAnchor:resultsBar.trailingAnchor constant:(-_cellInset)],
		[statusField.bottomAnchor constraintEqualToAnchor:resultsBar.bottomAnchor],
	]];

	/* An older result's conversation: back, where and when */
	NSView *contextBar = [NSView new];

	contextBar.translatesAutoresizingMaskIntoConstraints = NO;
	contextBar.hidden = YES;

	self.contextBar = contextBar;

	NSButton *backButton = [NSButton buttonWithTitle:TXTLS(@"TVCMainWindow[src-b1]") target:self action:@selector(backToResults:)];

	backButton.translatesAutoresizingMaskIntoConstraints = NO;
	backButton.image = [NSImage imageWithSystemSymbolName:@"chevron.left" accessibilityDescription:nil];
	backButton.imagePosition = NSImageLeading;
	backButton.bordered = NO;
	backButton.controlSize = NSControlSizeSmall;
	backButton.font = scopePopUp.font;
	backButton.contentTintColor = [NSColor controlAccentColor];

	NSTextField *contextTitleField = [NSTextField wrappingLabelWithString:@""];

	contextTitleField.translatesAutoresizingMaskIntoConstraints = NO;
	contextTitleField.font = [NSFont systemFontOfSize:11.0];
	contextTitleField.textColor = [NSColor secondaryLabelColor];

	self.contextTitleField = contextTitleField;

	[contextBar addSubview:backButton];
	[contextBar addSubview:contextTitleField];

	[NSLayoutConstraint activateConstraints:@[
		[backButton.topAnchor constraintEqualToAnchor:contextBar.topAnchor constant:2.0],
		[backButton.leadingAnchor constraintEqualToAnchor:contextBar.leadingAnchor constant:6.0],
		[contextTitleField.topAnchor constraintEqualToAnchor:backButton.bottomAnchor constant:4.0],
		[contextTitleField.leadingAnchor constraintEqualToAnchor:contextBar.leadingAnchor constant:_cellInset],
		[contextTitleField.trailingAnchor constraintEqualToAnchor:contextBar.trailingAnchor constant:(-_cellInset)],
		[contextTitleField.bottomAnchor constraintEqualToAnchor:contextBar.bottomAnchor],
	]];

	/* The results */
	TVCMainWindowSearchResultsTable *tableView = [[TVCMainWindowSearchResultsTable alloc] initWithFrame:NSZeroRect];

	NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"result"];

	column.resizingMask = NSTableColumnAutoresizingMask;

	[tableView addTableColumn:column];

	tableView.headerView = nil;
	tableView.style = NSTableViewStyleFullWidth;
	tableView.backgroundColor = [NSColor clearColor];
	tableView.intercellSpacing = NSMakeSize(0, 0);
	tableView.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;
	tableView.dataSource = self;
	tableView.delegate = self;
	tableView.target = self;
	tableView.action = @selector(resultClicked:);
	tableView.accessibilityLabel = TXTLS(@"TVCMainWindow[src-a2]");

	__weak typeof(self) weakSelf = self;

	tableView.openHandler = ^{
		TVCMainWindowSearchPanel *strongSelf = weakSelf;

		[strongSelf openResultAtRow:strongSelf.tableView.selectedRow];
	};

	tableView.escapeHandler = ^{
		[weakSelf focusSearchField];
	};

	self.tableView = tableView;

	NSScrollView *scrollView = [NSScrollView new];

	scrollView.translatesAutoresizingMaskIntoConstraints = NO;
	scrollView.documentView = tableView;
	scrollView.hasVerticalScroller = YES;
	scrollView.autohidesScrollers = YES;
	scrollView.drawsBackground = NO;
	scrollView.automaticallyAdjustsContentInsets = NO;

	self.scrollView = scrollView;

	scrollView.contentView.postsBoundsChangedNotifications = YES;

	[RZNotificationCenter() addObserver:self selector:@selector(resultsScrolled:) name:NSViewBoundsDidChangeNotification object:scrollView.contentView];

	/* What can be typed, while nothing is */
	NSTextField *hintField = [NSTextField wrappingLabelWithString:TXTLS(@"TVCMainWindow[src-h1]")];

	hintField.translatesAutoresizingMaskIntoConstraints = NO;
	hintField.font = [NSFont systemFontOfSize:11.0];
	hintField.textColor = [NSColor secondaryLabelColor];
	hintField.selectable = NO;

	self.hintField = hintField;

	/* Measures the rows (as the cells' text field draws) */
	self.measuringField = [TVCMainWindowSearchResultCell labelWithLines:0];

	/* Mentions: in a window of its own, of every network */
	if (self.mentionsMode) {
		searchField.placeholderString = TXTLS(@"TVCMainWindow[men-p1]");

		closeButton.hidden = YES;

		scopePopUp.hidden = YES;

		[RZNotificationCenter() addObserver:self selector:@selector(highlightsArchived:) name:TLOMessageArchiveDidArchiveHighlightsNotification object:nil];
	}

	[view addSubview:searchField];
	[view addSubview:closeButton];
	[view addSubview:resultsBar];
	[view addSubview:contextBar];
	[view addSubview:scrollView];
	[view addSubview:hintField];

	self.topConstraint = [searchField.topAnchor constraintEqualToAnchor:view.topAnchor constant:[self titlebarHeight]];

	self.resultsTopConstraint = [scrollView.topAnchor constraintEqualToAnchor:resultsBar.bottomAnchor constant:6.0];
	self.contextTopConstraint = [scrollView.topAnchor constraintEqualToAnchor:contextBar.bottomAnchor constant:6.0];

	[NSLayoutConstraint activateConstraints:@[
		self.topConstraint,
		self.resultsTopConstraint,
		[searchField.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:8.0],
		[closeButton.leadingAnchor constraintEqualToAnchor:searchField.trailingAnchor constant:((self.mentionsMode) ? -20.0 : 4.0)],
		[closeButton.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:((self.mentionsMode) ? -8.0 : -6.0)],
		[closeButton.centerYAnchor constraintEqualToAnchor:searchField.centerYAnchor],
		[closeButton.widthAnchor constraintEqualToConstant:20.0],
		[resultsBar.topAnchor constraintEqualToAnchor:searchField.bottomAnchor constant:6.0],
		[resultsBar.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
		[resultsBar.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
		[contextBar.topAnchor constraintEqualToAnchor:searchField.bottomAnchor constant:6.0],
		[contextBar.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
		[contextBar.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
		[scrollView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
		[scrollView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
		[scrollView.bottomAnchor constraintEqualToAnchor:view.bottomAnchor],
		[hintField.topAnchor constraintEqualToAnchor:resultsBar.bottomAnchor constant:10.0],
		[hintField.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:_cellInset],
		[hintField.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:(-_cellInset)],
	]];

	self.view = view;

	/* The title bar is transparent (10.1): the panel starts below it */
	if (self.mainWindow) {
		for (NSNotificationName name in @[NSWindowDidResizeNotification, NSWindowDidEnterFullScreenNotification, NSWindowDidExitFullScreenNotification]) {
			[RZNotificationCenter() addObserver:self selector:@selector(windowFrameChanged:) name:name object:self.mainWindow];
		}
	}

	[self updateScopeTitles];

	[self updateShownViews];
}

- (CGFloat)titlebarHeight
{
	NSWindow *window = self.mainWindow;

	/* Mentions: an ordinary window, its content below the title bar */
	if (window == nil) {
		return 0.0;
	}

	return MAX(0.0, (NSHeight(window.frame) - NSMaxY(window.contentLayoutRect)));
}

- (void)windowFrameChanged:(NSNotification *)notification
{
	CGFloat height = [self titlebarHeight];

	if (self.topConstraint.constant != height) {
		self.topConstraint.constant = height;
	}

	[self remeasureRowsIfNeeded];
}

- (void)viewDidLayout
{
	[super viewDidLayout];

	[self remeasureRowsIfNeeded];
}

/* The column got wider or narrower: the text wraps differently */
- (void)remeasureRowsIfNeeded
{
	CGFloat width = NSWidth(self.tableView.bounds);

	if (width == self.measuredWidth || width <= 0) {
		return;
	}

	self.measuredWidth = width;

	NSInteger rows = self.tableView.numberOfRows;

	if (rows > 0) {
		[self.tableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, rows)]];
	}
}

/* Names for suggestions: read again each time the panel opens */
- (void)loadArchivedNames
{
	[sharedMessageArchive() namesWithLimit:1000 completionHandler:^(NSArray<NSString *> *nicknames, NSArray<NSString *> *viewNames) {
		self.archivedNicknames = nicknames;
		self.archivedViewNames = viewNames;
	}];
}

- (void)focusSearchField
{
	[self.view.window makeFirstResponder:self.searchField];

	[self.searchField selectText:nil];
}

- (void)close:(nullable id)sender
{
	if (self.mentionsMode) {
		[self.view.window performClose:nil];

		return;
	}

	[self.mainWindow closeSearchPanel];
}

- (int64_t)newestResultRowId
{
	int64_t rowId = 0;

	for (TLOMessageArchiveResult *result in self.results) {
		rowId = MAX(rowId, result.rowId);
	}

	return rowId;
}

/* Mentions: new highlights were written (in batches, two seconds apart) */
- (void)highlightsArchived:(NSNotification *)notification
{
	if (self.isViewLoaded == NO || self.view.window.visible == NO || self.contextMessages) {
		return;
	}

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(search) object:nil];

	[self performSelector:@selector(search) withObject:nil afterDelay:0.5];
}

/* Results, their conversation, or what can be typed */
- (void)updateShownViews
{
	BOOL showingContext = (self.contextMessages != nil);

	BOOL nothingTyped = (self.query == nil);

	self.contextBar.hidden = (showingContext == NO);

	self.resultsTopConstraint.active = (showingContext == NO);
	self.contextTopConstraint.active = showingContext;

	self.resultsBar.hidden = showingContext;

	self.hintField.hidden = (showingContext || nothingTyped == NO);

	self.scrollView.hidden = (showingContext == NO && nothingTyped);
}

#pragma mark -
#pragma mark Scope

- (void)setScope:(TVCMainWindowSearchScope)scope
{
	_scope = scope;

	if (self.isViewLoaded == NO) {
		return;
	}

	[self.scopePopUp selectItemAtIndex:scope];

	[self search];
}

- (void)scopeChanged:(id)sender
{
	self.scope = (TVCMainWindowSearchScope)self.scopePopUp.indexOfSelectedItem;
}

- (void)orderChanged:(id)sender
{
	[self search];
}

- (void)selectedItemChanged
{
	if (self.isViewLoaded == NO) {
		return;
	}

	[self updateScopeTitles];

	/* Only when the search would find other messages */
	if (self.query && self.contextMessages == nil && [[self scopeKey] isEqualToString:self.queryScopeKey] == NO) {
		[self search];
	}
}

- (void)updateScopeTitles
{
	IRCTreeItem *item = self.mainWindow.selectedItem;

	IRCClient *client = item.associatedClient;

	IRCChannel *channel = item.associatedChannel;

	NSString *viewTitle = nil;

	if (channel) {
		viewTitle = TXTLS(@"TVCMainWindow[src-s1]", channel.name);
	} else if (client) {
		viewTitle = TXTLS(@"TVCMainWindow[src-s3]", client.networkNameAlt);
	} else {
		viewTitle = TXTLS(@"TVCMainWindow[src-s4]");
	}

	NSString *serverTitle = ((client) ? TXTLS(@"TVCMainWindow[src-s1]", client.networkNameAlt) : TXTLS(@"TVCMainWindow[src-s4]"));

	[self.scopePopUp itemAtIndex:TVCMainWindowSearchScopeChannel].title = viewTitle;
	[self.scopePopUp itemAtIndex:TVCMainWindowSearchScopeServer].title = serverTitle;

	[self.scopePopUp selectItemAtIndex:self.scope];

	[self.scopePopUp synchronizeTitleAndSelectedItem];
}

/* Where the search looks, as a key to tell whether it moved */
- (NSString *)scopeKey
{
	IRCTreeItem *item = self.mainWindow.selectedItem;

	switch (self.scope) {
		case TVCMainWindowSearchScopeChannel:
		{
			return [@"v:" stringByAppendingString:(item.uniqueIdentifier ?: @"")];
		}
		case TVCMainWindowSearchScopeServer:
		{
			return [@"s:" stringByAppendingString:(item.associatedClient.uniqueIdentifier ?: @"")];
		}
		default:
		{
			return @"*";
		}
	}
}

#pragma mark -
#pragma mark Searching

- (void)controlTextDidChange:(NSNotification *)notification
{
	if (notification.object != self.searchField) {
		return;
	}

	NSString *string = self.searchField.stringValue;

	/* One character typed after from: or in: — suggest names */
	if (string.length == (self.previousSearchString.length + 1)) {
		[self maybeSuggestNames];
	}

	self.previousSearchString = string;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(search) object:nil];

	[self performSelector:@selector(search) withObject:nil afterDelay:_searchDelay];
}

- (void)search
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(search) object:nil];

	self.generation += 1;

	self.contextMessages = nil;
	self.contextResult = nil;

	NSString *text = self.searchField.stringValue;

	self.searchedText = text;

	/* Mentions: highlights of every network, what's typed narrows them down */
	if (self.mentionsMode) {
		text = [@"mentions:me " stringByAppendingString:text];
	}

	TLOMessageArchiveQuery *query = [TLOMessageArchiveQuery queryWithString:text];

	IRCTreeItem *item = self.mainWindow.selectedItem;

	if (self.mentionsMode == NO && self.scope == TVCMainWindowSearchScopeChannel) {
		query.viewId = (item.uniqueIdentifier ?: @"");
	} else if (self.mentionsMode == NO && self.scope == TVCMainWindowSearchScopeServer) {
		query.serverId = (item.associatedClient.uniqueIdentifier ?: @"");
	}

	query.order = ((self.orderPopUp.indexOfSelectedItem == 1) ? TLOMessageArchiveSearchOrderBestMatch : TLOMessageArchiveSearchOrderNewest);

	[self.results removeAllObjects];

	self.hasMore = NO;

	self.loading = NO;

	if (query.empty) {
		self.query = nil;
		self.queryScopeKey = nil;

		self.statusField.stringValue = @"";

		[self.tableView reloadData];

		[self updateShownViews];

		return;
	}

	self.query = query;
	self.queryScopeKey = [self scopeKey];

	self.statusField.stringValue = TXTLS(@"TVCMainWindow[src-r4]");

	[self.tableView reloadData];

	[self updateShownViews];

	[self loadNextPage];

	NSUInteger generation = self.generation;

	[sharedMessageArchive() countResultsOfSearch:query completionHandler:^(NSUInteger count) {
		if (generation != self.generation) {
			return;
		}

		BOOL mentions = self.mentionsMode;

		if (count == 0) {
			self.statusField.stringValue = TXTLS((mentions) ? @"TVCMainWindow[men-r3]" : @"TVCMainWindow[src-r3]");
		} else if (count == 1) {
			self.statusField.stringValue = TXTLS((mentions) ? @"TVCMainWindow[men-r2]" : @"TVCMainWindow[src-r2]");
		} else {
			self.statusField.stringValue = TXTLS((mentions) ? @"TVCMainWindow[men-r1]" : @"TVCMainWindow[src-r1]", count);
		}
	}];
}

- (void)loadNextPage
{
	TLOMessageArchiveQuery *query = self.query;

	if (query == nil || self.loading) {
		return;
	}

	self.loading = YES;

	NSUInteger generation = self.generation;

	[sharedMessageArchive() search:query offset:self.results.count limit:_pageSize completionHandler:^(TLOMessageArchiveSearchPage *page) {
		if (generation != self.generation) {
			return;
		}

		self.loading = NO;

		self.hasMore = page.hasMore;

		NSUInteger firstRow = self.results.count;

		[self.results addObjectsFromArray:page.results];

		[self.tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstRow, page.results.count)] withAnimation:NSTableViewAnimationEffectNone];

		/* A short first page may not fill the list */
		[self loadMoreIfNearEnd];
	}];
}

- (void)resultsScrolled:(NSNotification *)notification
{
	[self loadMoreIfNearEnd];
}

- (void)loadMoreIfNearEnd
{
	if (self.hasMore == NO || self.loading || self.contextMessages) {
		return;
	}

	NSRect visibleRect = self.scrollView.contentView.documentVisibleRect;

	if ((NSHeight(self.tableView.bounds) - NSMaxY(visibleRect)) < 400.0) {
		[self loadNextPage];
	}
}

#pragma mark -
#pragma mark Keys

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
	if (control != self.searchField) {
		return NO;
	}

	if (commandSelector == @selector(insertNewline:)) {
		/* The search waiting for the pause runs now; then the first result opens */
		if (self.query == nil || [self.searchedText isEqualToString:self.searchField.stringValue] == NO) {
			[self search];

			return YES;
		}

		NSInteger row = self.tableView.selectedRow;

		[self openResultAtRow:((row >= 0) ? row : 0)];

		return YES;
	}

	if (commandSelector == @selector(moveDown:)) {
		if (self.tableView.numberOfRows == 0) {
			return YES;
		}

		[self.view.window makeFirstResponder:self.tableView];

		if (self.tableView.selectedRow < 0) {
			[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
		}

		return YES;
	}

	/* Escape: clears the field first, then closes the panel */
	if (commandSelector == @selector(cancelOperation:)) {
		if (self.contextMessages) {
			[self backToResults:nil];
		} else if (self.searchField.stringValue.length > 0) {
			self.searchField.stringValue = @"";

			self.previousSearchString = @"";

			[self search];
		} else {
			[self close:nil];
		}

		return YES;
	}

	return NO;
}

#pragma mark -
#pragma mark Suggestions

/* The filter being typed before the insertion point (from: or in:), or nil */
- (nullable NSString *)filterBeforePartialWordRange:(NSRange)range inString:(NSString *)string
{
	NSString *before = [string substringToIndex:range.location];

	if ([before hasSuffix:@"#"]) {
		before = [before substringToIndex:(before.length - 1)];
	}

	for (NSString *filter in @[@"from:", @"in:"]) {
		if (before.length < filter.length) {
			continue;
		}

		NSString *candidate = [before substringFromIndex:(before.length - filter.length)];

		if ([candidate caseInsensitiveCompare:filter] != NSOrderedSame) {
			continue;
		}

		/* At the start of a word */
		NSUInteger start = (before.length - filter.length);

		if (start == 0 || [[NSCharacterSet whitespaceCharacterSet] characterIsMember:[before characterAtIndex:(start - 1)]]) {
			return filter;
		}
	}

	return nil;
}

- (void)maybeSuggestNames
{
	NSTextView *fieldEditor = (NSTextView *)self.searchField.currentEditor;

	if ([fieldEditor isKindOfClass:[NSTextView class]] == NO) {
		return;
	}

	NSRange range = fieldEditor.rangeForUserCompletion;

	if (range.location == NSNotFound || range.length == 0) {
		return;
	}

	if ([self filterBeforePartialWordRange:range inString:fieldEditor.string] == nil) {
		return;
	}

	[fieldEditor complete:nil];
}

- (NSArray<NSString *> *)control:(NSControl *)control textView:(NSTextView *)textView completions:(NSArray<NSString *> *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index
{
	NSString *string = textView.string;

	NSString *filter = [self filterBeforePartialWordRange:charRange inString:string];

	if (filter == nil) {
		return @[];
	}

	NSString *partial = [string substringWithRange:charRange];

	NSMutableOrderedSet<NSString *> *names = [NSMutableOrderedSet orderedSet];

	IRCTreeItem *selectedItem = self.mainWindow.selectedItem;

	NSArray<IRCClient *> *clients = worldController().clientList;

	IRCClient *selectedClient = selectedItem.associatedClient;

	if (self.scope != TVCMainWindowSearchScopeEverywhere && selectedClient) {
		clients = @[selectedClient];
	}

	if ([filter isEqualToString:@"from:"]) {
		/* The selected channel's members first */
		IRCChannel *selectedChannel = selectedItem.associatedChannel;

		NSMutableArray<IRCChannel *> *channels = [NSMutableArray array];

		if (selectedChannel) {
			[channels addObject:selectedChannel];
		}

		for (IRCClient *client in clients) {
			[names addObject:client.userNickname];

			[channels addObjectsFromArray:client.channelList];
		}

		for (IRCChannel *channel in channels) {
			if (channel.isPrivateMessage) {
				[names addObject:channel.name];

				continue;
			}

			for (IRCChannelUser *member in channel.memberList) {
				[names addObject:member.user.nickname];
			}
		}

		[names addObjectsFromArray:self.archivedNicknames];
	} else {
		for (IRCClient *client in clients) {
			for (IRCChannel *channel in client.channelList) {
				if (channel.isUtility) {
					continue;
				}

				NSString *name = channel.name;

				/* The # is outside the word being completed */
				if ([name hasPrefix:@"#"]) {
					name = [name substringFromIndex:1];
				}

				[names addObject:name];
			}
		}

		for (NSString *viewName in self.archivedViewNames) {
			[names addObject:(([viewName hasPrefix:@"#"]) ? [viewName substringFromIndex:1] : viewName)];
		}
	}

	NSMutableArray<NSString *> *completions = [NSMutableArray array];

	for (NSString *name in names) {
		if (name.length > partial.length && [name rangeOfString:partial options:(NSAnchoredSearch | NSCaseInsensitiveSearch)].location != NSNotFound) {
			[completions addObject:name];
		}

		if (completions.count == 20) {
			break;
		}
	}

	[completions sortUsingSelector:@selector(caseInsensitiveCompare:)];

	/* The first one is put in already (selected): Return takes it, typing on replaces it */
	*index = 0;

	return [completions copy];
}

#pragma mark -
#pragma mark Table

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	if (self.contextMessages) {
		return self.contextMessages.count;
	}

	return self.results.count;
}

- (nullable TLOMessageArchiveResult *)resultAtRow:(NSInteger)row
{
	NSArray *rows = ((self.contextMessages) ?: self.results);

	if (row < 0 || row >= (NSInteger)rows.count) {
		return nil;
	}

	return rows[row];
}

- (NSAttributedString *)headerOfResult:(TLOMessageArchiveResult *)result
{
	NSMutableAttributedString *header = [NSMutableAttributedString new];

	NSString *nickname = result.nickname;

	if (nickname.length == 0) {
		nickname = TXTLS(@"TVCMainWindow[src-t1]");
	}

	/* Mentions: those that came since the window was last closed */
	int64_t markedNewAfterRowId = self.markedNewAfterRowId;

	if (self.contextMessages == nil && markedNewAfterRowId > 0 && result.rowId > markedNewAfterRowId) {
		[header appendAttributedString:[[NSAttributedString alloc] initWithString:TXTLS(@"TVCMainWindow[men-n1]") attributes:@{
			NSFontAttributeName : [NSFont systemFontOfSize:10.0],
			NSForegroundColorAttributeName : [NSColor controlAccentColor]
		}]];
	}

	[header appendAttributedString:[[NSAttributedString alloc] initWithString:nickname attributes:@{
		NSFontAttributeName : [NSFont systemFontOfSize:12.0 weight:NSFontWeightSemibold],
		NSForegroundColorAttributeName : [NSColor labelColor]
	}]];

	/* Where, when the search looked further than one place */
	NSString *place = nil;

	if (self.contextMessages == nil && self.scope != TVCMainWindowSearchScopeChannel) {
		place = ((result.viewName.length > 0) ? result.viewName : result.serverName);

		if (self.scope == TVCMainWindowSearchScopeEverywhere && result.viewName.length > 0) {
			place = [NSString stringWithFormat:@"%@ · %@", place, result.serverName];
		}
	}

	if (place) {
		[header appendAttributedString:[[NSAttributedString alloc] initWithString:[@"  " stringByAppendingString:place] attributes:@{
			NSFontAttributeName : [NSFont systemFontOfSize:11.0],
			NSForegroundColorAttributeName : [NSColor secondaryLabelColor]
		}]];
	}

	return header;
}

- (NSAttributedString *)bodyOfResult:(TLOMessageArchiveResult *)result
{
	BOOL isContext = (self.contextMessages != nil);

	NSArray<NSValue *> *ranges = nil;

	NSString *text = ((isContext) ? result.body : [result snippetWithMaximumLength:_snippetLength matchRanges:&ranges]);

	NSFont *font = [NSFont systemFontOfSize:12.0];

	if (result.lineType == TVCLogLineTypeAction || result.lineType == TVCLogLineTypeActionNoHighlight) {
		font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSItalicFontMask];
	}

	NSMutableAttributedString *body = [[NSMutableAttributedString alloc] initWithString:text attributes:@{
		NSFontAttributeName : font,
		NSForegroundColorAttributeName : [NSColor labelColor]
	}];

	for (NSValue *value in ranges) {
		[body addAttributes:@{
			NSFontAttributeName : [NSFont systemFontOfSize:12.0 weight:NSFontWeightSemibold],
			NSBackgroundColorAttributeName : [NSColor findHighlightColor],
			NSForegroundColorAttributeName : [NSColor blackColor]
		} range:value.rangeValue];
	}

	return body;
}

- (NSString *)shortDateOfResult:(TLOMessageArchiveResult *)result
{
	static NSDateFormatter *timeFormatter = nil;
	static NSDateFormatter *dayFormatter = nil;
	static NSDateFormatter *dayAndYearFormatter = nil;
	static NSDateFormatter *dayAndTimeFormatter = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		timeFormatter = [NSDateFormatter new];
		timeFormatter.timeStyle = NSDateFormatterShortStyle;
		timeFormatter.dateStyle = NSDateFormatterNoStyle;

		dayFormatter = [NSDateFormatter new];
		[dayFormatter setLocalizedDateFormatFromTemplate:@"dMMM"];

		dayAndYearFormatter = [NSDateFormatter new];
		[dayAndYearFormatter setLocalizedDateFormatFromTemplate:@"dMMMy"];

		dayAndTimeFormatter = [NSDateFormatter new];
		[dayAndTimeFormatter setLocalizedDateFormatFromTemplate:@"dMMMjmm"];
	});

	NSDate *date = result.date;

	NSCalendar *calendar = [NSCalendar currentCalendar];

	/* An older result's conversation: the times (its day is above), and the
	 day too for messages of other days */
	if (self.contextMessages) {
		if ([calendar isDate:date inSameDayAsDate:self.contextResult.date]) {
			return [timeFormatter stringFromDate:date];
		}

		return [dayAndTimeFormatter stringFromDate:date];
	}

	if ([calendar isDateInToday:date]) {
		return [timeFormatter stringFromDate:date];
	}

	if ([calendar isDateInYesterday:date]) {
		return TXTLS(@"TVCMainWindow[src-d1]");
	}

	if ([calendar component:NSCalendarUnitYear fromDate:date] == [calendar component:NSCalendarUnitYear fromDate:[NSDate date]]) {
		return [dayFormatter stringFromDate:date];
	}

	return [dayAndYearFormatter stringFromDate:date];
}

- (NSString *)fullDateOfResult:(TLOMessageArchiveResult *)result
{
	return [NSDateFormatter localizedStringFromDate:result.date dateStyle:NSDateFormatterFullStyle timeStyle:NSDateFormatterShortStyle];
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	TLOMessageArchiveResult *result = [self resultAtRow:row];

	if (result == nil) {
		return nil;
	}

	TVCMainWindowSearchResultCell *cell = [tableView makeViewWithIdentifier:@"result" owner:self];

	if (cell == nil) {
		cell = [[TVCMainWindowSearchResultCell alloc] initWithFrame:NSZeroRect];

		cell.identifier = @"result";
	}

	cell.headerField.attributedStringValue = [self headerOfResult:result];

	cell.dateField.stringValue = [self shortDateOfResult:result];

	cell.bodyField.attributedStringValue = [self bodyOfResult:result];

	cell.bodyField.maximumNumberOfLines = ((self.contextMessages) ? _contextBodyLines : _resultBodyLines);

	cell.toolTip = [self fullDateOfResult:result];

	return cell;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
	TLOMessageArchiveResult *result = [self resultAtRow:row];

	if (result == nil) {
		return 20.0;
	}

	CGFloat width = (NSWidth(tableView.bounds) - (_cellInset * 2));

	if (width < 50.0) {
		width = 50.0;
	}

	NSTextField *measuringField = self.measuringField;

	measuringField.attributedStringValue = [self bodyOfResult:result];

	CGFloat bodyHeight = [measuringField.cell cellSizeForBounds:NSMakeRect(0, 0, width, CGFLOAT_MAX)].height;

	NSFont *font = [NSFont systemFontOfSize:12.0];

	CGFloat lineHeight = ceil(font.ascender - font.descender + font.leading);

	NSUInteger lines = ((self.contextMessages) ? _contextBodyLines : _resultBodyLines);

	bodyHeight = MIN(ceil(bodyHeight), ((lineHeight * lines) + 4.0));

	CGFloat headerHeight = ceil([NSFont systemFontOfSize:12.0 weight:NSFontWeightSemibold].ascender - [NSFont systemFontOfSize:12.0].descender) + 1.0;

	return (_cellTopPadding + headerHeight + _cellLineSpacing + bodyHeight + _cellBottomPadding);
}

/* The result an older one opened at stands out */
- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
	TLOMessageArchiveResult *result = [self resultAtRow:row];

	if (self.contextResult && result.rowId == self.contextResult.rowId) {
		rowView.backgroundColor = [[NSColor findHighlightColor] colorWithAlphaComponent:0.25];
	} else {
		rowView.backgroundColor = [NSColor clearColor];
	}
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
	return (self.contextMessages == nil);
}

#pragma mark -
#pragma mark Opening

- (void)resultClicked:(id)sender
{
	NSInteger row = self.tableView.clickedRow;

	if (row < 0) {
		return;
	}

	[self openResultAtRow:row];
}

- (void)openAdjacentResult:(BOOL)forward
{
	if (self.contextMessages || self.results.count == 0) {
		return;
	}

	NSInteger row = self.tableView.selectedRow;

	if (row < 0) {
		row = ((forward) ? 0 : (NSInteger)(self.results.count - 1));
	} else {
		row += ((forward) ? 1 : -1);
	}

	if (row < 0 || row >= (NSInteger)self.results.count) {
		NSBeep();

		return;
	}

	[self openResultAtRow:row];
}

- (void)openResultAtRow:(NSInteger)row
{
	if (self.contextMessages) {
		return;
	}

	TLOMessageArchiveResult *result = [self resultAtRow:row];

	if (result == nil) {
		return;
	}

	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

	[self.tableView scrollRowToVisible:row];

	[self openResult:result];
}

/* In the chat when it's still in its scrollback, else here from the archive */
- (void)openResult:(TLOMessageArchiveResult *)result
{
	IRCTreeItem *item = [worldController() findItemWithId:result.viewId];

	/* Closed or deleted since */
	if (item == nil) {
		[self showContextOfResult:result];

		return;
	}

	/* Selecting a popped-out item brings its window forward */
	[mainWindow() select:item];

	TVCMainWindow *window = ([TVCMainWindow popOutWindowForItem:item] ?: mainWindow());

	if (window != self.mainWindow) {
		[window makeKeyAndOrderFront:nil];
	}

	[self jumpToResult:result inView:item.viewController attemptsLeft:6];
}

- (void)jumpToResult:(TLOMessageArchiveResult *)result inView:(TVCLogController *)viewController attemptsLeft:(NSUInteger)attemptsLeft
{
	NSString *lineId = result.lineId;

	NSUInteger generation = self.generation;

	__weak typeof(self) weakSelf = self;

	[viewController jumpToLine:lineId completionHandler:^(BOOL success) {
		if (success) {
			[viewController evaluateFunction:@"Textual.flashLine" withArguments:@[lineId]];

			return;
		}

		TVCMainWindowSearchPanel *strongSelf = weakSelf;

		/* Closed, or another search started meanwhile */
		if (strongSelf == nil || strongSelf.generation != generation) {
			return;
		}

		/* A view shown for the first time loads its history first: a jump
		 made meanwhile fails, so it's tried again while it loads */
		if (attemptsLeft > 1 && viewController.historyIsShown == NO) {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[weakSelf jumpToResult:result inView:viewController attemptsLeft:(attemptsLeft - 1)];
			});

			return;
		}

		/* Older than the scrollback: the chat goes on into the archive there */
		[strongSelf jumpToArchivedResult:result inView:viewController];
	}];
}

- (void)jumpToArchivedResult:(TLOMessageArchiveResult *)result inView:(TVCLogController *)viewController
{
	NSString *lineNumber = [NSString stringWithFormat:@"archive-%lld", result.rowId];

	__weak typeof(self) weakSelf = self;

	[viewController jumpToLine:lineNumber completionHandler:^(BOOL success) {
		if (success) {
			[viewController evaluateFunction:@"Textual.flashLine" withArguments:@[lineNumber]];

			return;
		}

		/* Not even there: in its conversation, here */
		[weakSelf showContextOfResult:result];
	}];
}

- (void)showContextOfResult:(TLOMessageArchiveResult *)result
{
	NSUInteger generation = self.generation;

	[sharedMessageArchive() messagesAround:result count:_contextCount completionHandler:^(NSArray<TLOMessageArchiveResult *> *messages) {
		if (generation != self.generation || messages.count == 0) {
			return;
		}

		self.contextResult = result;
		self.contextMessages = messages;

		NSString *place = ((result.viewName.length > 0) ? [NSString stringWithFormat:@"%@ · %@", result.viewName, result.serverName] : result.serverName);

		NSString *day = [NSDateFormatter localizedStringFromDate:result.date dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];

		self.contextTitleField.stringValue = TXTLS(@"TVCMainWindow[src-x1]", place, day);

		self.measuredWidth = 0;

		[self.tableView reloadData];

		[self updateShownViews];

		NSUInteger row = [messages indexOfObjectPassingTest:^BOOL(TLOMessageArchiveResult *message, NSUInteger index, BOOL *stop) {
			return (message.rowId == result.rowId);
		}];

		if (row != NSNotFound) {
			[self scrollRowToCenter:row];
		}
	}];
}

- (void)scrollRowToCenter:(NSUInteger)row
{
	NSRect rowRect = [self.tableView rectOfRow:row];

	NSRect visibleRect = self.scrollView.contentView.bounds;

	CGFloat y = (NSMidY(rowRect) - (NSHeight(visibleRect) / 2.0));

	y = MAX(0.0, MIN(y, (NSHeight(self.tableView.bounds) - NSHeight(visibleRect))));

	[self.scrollView.contentView scrollToPoint:NSMakePoint(0, y)];

	[self.scrollView reflectScrolledClipView:self.scrollView.contentView];
}

- (void)backToResults:(nullable id)sender
{
	if (self.contextMessages == nil) {
		return;
	}

	TLOMessageArchiveResult *contextResult = self.contextResult;

	self.contextMessages = nil;
	self.contextResult = nil;

	self.measuredWidth = 0;

	[self.tableView reloadData];

	[self updateShownViews];

	NSUInteger row = [self.results indexOfObjectPassingTest:^BOOL(TLOMessageArchiveResult *result, NSUInteger index, BOOL *stop) {
		return (result.rowId == contextResult.rowId);
	}];

	if (row != NSNotFound) {
		[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

		[self.tableView scrollRowToVisible:row];
	}
}

@end

#pragma mark -
#pragma mark Mentions

static NSString * const _mentionsLastSeenDefaultsKey = @"Mentions -> Last Seen Row";

@interface TVCMentionsWindowController ()
@property (nonatomic, strong) TVCMainWindowSearchPanel *panel;
@end

@implementation TVCMentionsWindowController

+ (void)showMentions
{
	static TVCMentionsWindowController *sharedController = nil;

	if (sharedController == nil) {
		sharedController = [self new];
	}

	[sharedController show];
}

- (instancetype)init
{
	NSWindow *window =
	[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 420, 560)
								styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
								  backing:NSBackingStoreBuffered
									defer:YES];

	if ((self = [super initWithWindow:window])) {
		window.title = TXTLS(@"TVCMainWindow[men-t1]");
		window.releasedWhenClosed = NO;
		window.minSize = NSMakeSize(320, 300);
		window.delegate = self;
		window.tabbingMode = NSWindowTabbingModeDisallowed;

		self.panel = [[TVCMainWindowSearchPanel alloc] initForMentions];

		window.contentViewController = self.panel;

		/* Where it was last time, else in the middle */
		if ([window setFrameUsingName:@"Mentions"] == NO) {
			[window setContentSize:NSMakeSize(420, 560)];

			[window center];
		}

		window.frameAutosaveName = @"Mentions";

		return self;
	}

	return nil;
}

- (void)show
{
	NSWindow *window = self.window;

	/* Those since it was last closed are new */
	if (window.visible == NO) {
		self.panel.markedNewAfterRowId = [RZUserDefaults() integerForKey:_mentionsLastSeenDefaultsKey];

		[self.panel search];
	}

	[window makeKeyAndOrderFront:nil];

	[self.panel focusSearchField];
}

/* What was shown has been seen */
- (void)windowWillClose:(NSNotification *)notification
{
	NSInteger lastSeen = [RZUserDefaults() integerForKey:_mentionsLastSeenDefaultsKey];

	NSInteger newest = (NSInteger)self.panel.newestResultRowId;

	if (newest > lastSeen) {
		[RZUserDefaults() setInteger:newest forKey:_mentionsLastSeenDefaultsKey];
	}
}

@end

#pragma mark -
#pragma mark Window

@implementation TVCMainWindow (SearchPrivate)

- (BOOL)isSearchPanelVisible
{
	TVCMainWindowSearchPanel *panel = self.searchPanel;

	return (panel.isViewLoaded && panel.view.superview != nil);
}

- (void)showSearchPanelWithScope:(TVCMainWindowSearchScope)scope
{
	if (self.searchPanel == nil) {
		self.searchPanel = [[TVCMainWindowSearchPanel alloc] initWithWindow:self];
	}

	TVCMainWindowSearchPanel *panel = self.searchPanel;

	if (self.isSearchPanelVisible == NO) {
		NSScrollView *memberListScrollView = self.memberList.enclosingScrollView;

		/* The member list's column (a sidebar material view) */
		NSView *column = memberListScrollView.superview;

		NSView *panelView = panel.view;

		panelView.translatesAutoresizingMaskIntoConstraints = NO;

		[column addSubview:panelView];

		[NSLayoutConstraint activateConstraints:@[
			[panelView.topAnchor constraintEqualToAnchor:column.topAnchor],
			[panelView.bottomAnchor constraintEqualToAnchor:column.bottomAnchor],
			[panelView.leadingAnchor constraintEqualToAnchor:column.leadingAnchor],
			[panelView.trailingAnchor constraintEqualToAnchor:column.trailingAnchor],
		]];

		memberListScrollView.hidden = YES;

		[self.contentSplitView showSearchColumn];

		[panel loadArchivedNames];

		[panel selectedItemChanged];
	}

	panel.scope = scope;

	[panel focusSearchField];
}

- (void)openAdjacentSearchResult:(BOOL)forward
{
	if (self.isSearchPanelVisible == NO) {
		[self showSearchPanelWithScope:TVCMainWindowSearchScopeChannel];

		return;
	}

	[self.searchPanel openAdjacentResult:forward];
}

- (void)closeSearchPanel
{
	if (self.isSearchPanelVisible == NO) {
		return;
	}

	[self.searchPanel.view removeFromSuperview];

	self.memberList.enclosingScrollView.hidden = NO;

	TVCMainWindowSplitView *splitView = self.contentSplitView;

	[splitView hideSearchColumn];

	if (self.selectedItem.isChannel && self.memberList.isHiddenByUser == NO) {
		[splitView expandMemberList];
	} else {
		[splitView collapseMemberList];
	}

	[self.inputTextField focus];
}

@end

NS_ASSUME_NONNULL_END
