/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

#import "NSViewHelper.h"
#import "TXMasterController.h"
#import "TXMenuController.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesReload.h"
#import "TVCMainWindowPrivate.h"
#import "TLOLocalization.h"
#import "TPCPreferencesUserDefaults.h"
#import "IRCAliasPrivate.h"
#import "IRCClientPrivate.h"
#import "IRCWorld.h"
#import "IRCCommandIndex.h"
#import "TPCSecurityScopedFolderPrivate.h"
#import "TDCPreferencesPanePrivate.h"

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
#import <Sparkle/Sparkle.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface TDCPreferencesPane ()
@property (nonatomic, assign, readwrite) BOOL reloadingTheme;
@end

@implementation TDCPreferencesPane

- (instancetype)initWithNibName:(NSString *)nibName
{
	NSParameterAssert(nibName != nil);

	if ((self = [super initWithNibName:nibName bundle:[NSBundle mainBundle]])) {
		[RZNotificationCenter() addObserver:self
								   selector:@selector(themeWillReload:)
									   name:TVCMainWindowWillReloadThemeNotification
									 object:nil];

		[RZNotificationCenter() addObserver:self
								   selector:@selector(themeDidReload:)
									   name:TVCMainWindowDidReloadThemeNotification
									 object:nil];

		return self;
	}

	return nil;
}

- (void)dealloc
{
	[RZNotificationCenter() removeObserver:self];
}

- (void)themeWillReload:(NSNotification *)notification
{
	self.reloadingTheme = YES;
}

- (void)themeDidReload:(NSNotification *)notification
{
	self.reloadingTheme = NO;
}

- (void)deactivateColorWells
{
	if (self.viewLoaded) {
		[self deactivateColorWellsInView:self.view];
	}
}

- (void)deactivateColorWellsInView:(NSView *)view
{
	if ([view isKindOfClass:[NSColorWell class]]) {
		[(NSColorWell *)view deactivate];

		return;
	}

	for (NSView *subview in view.subviews) {
		[self deactivateColorWellsInView:subview];
	}
}

/* TDCPreferencesGeneralPane → TDCPreferencesGeneral */
- (instancetype)init
{
	NSString *className = NSStringFromClass([self class]);

	NSParameterAssert([className hasSuffix:@"Pane"]);

	return [self initWithNibName:[className substringToIndex:(className.length - 4)]];
}

- (void)paneWillClose
{

}

- (void)showFolder:(nullable NSURL *)folderURL inPopUpButton:(NSPopUpButton *)popUpButton placeholder:(NSString *)placeholder
{
	NSParameterAssert(popUpButton != nil);
	NSParameterAssert(placeholder != nil);

	NSMenuItem *item = [popUpButton itemAtIndex:0];

	if (folderURL == nil) {
		item.image = nil;

		item.title = placeholder;

		return;
	}

	NSImage *icon = [RZWorkspace() iconForFile:folderURL.path];

	icon.size = NSMakeSize(16, 16);

	item.image = icon;

	item.title = folderURL.lastPathComponent;
}

- (void)chooseFolderFromPopUpButton:(NSPopUpButton *)popUpButton completionBlock:(void (^)(NSData * _Nullable bookmark))completionBlock
{
	NSParameterAssert(popUpButton != nil);
	NSParameterAssert(completionBlock != nil);

	NSInteger selectedTag = popUpButton.selectedTag;

	/* Item 0 shows the folder: it stays selected */
	[popUpButton selectItemAtIndex:0];

	if (selectedTag == 3) {
		completionBlock(nil);

		return;
	} else if (selectedTag != 2) {
		return;
	}

	NSOpenPanel *panel = [NSOpenPanel openPanel];

	panel.allowsMultipleSelection = NO;
	panel.canChooseDirectories = YES;
	panel.canChooseFiles = NO;
	panel.canCreateDirectories = YES;
	panel.resolvesAliases = YES;

	panel.prompt = TXTLS(@"Prompts[xne-79]");

	[panel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger returnCode) {
		if (returnCode != NSModalResponseOK) {
			return;
		}

		/* Keep the folder that was set when there is no bookmark */
		NSData *bookmark = [TPCSecurityScopedFolder bookmarkForURL:panel.URLs[0]];

		if (bookmark) {
			completionBlock(bookmark);
		}
	}];
}

- (void)onChangedTheme:(nullable id)sender
{
	[TPCPreferences performReloadAction:(TPCPreferencesReloadActionStyle | TPCPreferencesReloadActionTextDirection)];
}

@end

#pragma mark -
#pragma mark General

@interface TDCPreferencesGeneralPane ()
@property (nonatomic, weak) IBOutlet NSStackView *stackView;
@property (nonatomic, weak) IBOutlet NSView *checkForUpdatesView;
@property (nonatomic, weak) IBOutlet NSButton *checkForUpdatesDontCheck;
@property (nonatomic, weak) IBOutlet NSButton *checkForUpdatesAutomaticallyCheck;
@property (nonatomic, weak) IBOutlet NSButton *checkForUpdatesAutomaticallyDownload;

/* Bound in the nib */
@property (nonatomic, assign) BOOL preventSleepWhileConnected;

- (IBAction)onChangedCheckForUpdates:(nullable id)sender;
- (IBAction)onChangedCheckForBetaUpdates:(nullable id)sender;
@end

@implementation TDCPreferencesGeneralPane

- (void)viewDidLoad
{
	[super viewDidLoad];

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	[self updateCheckForUpdatesMatrix];
#else
	/* Hide preferences for updates when support is not enabled. */
	[self.stackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible
								  forView:self.checkForUpdatesView];
#endif

	[self.view layoutSubtreeIfNeeded];
}

- (BOOL)preventSleepWhileConnected
{
	return [TPCPreferences preventSleepWhileConnected];
}

- (void)setPreventSleepWhileConnected:(BOOL)preventSleepWhileConnected
{
	[TPCPreferences setPreventSleepWhileConnected:preventSleepWhileConnected];
}

/* One choice over two settings: download implies checking */
- (void)updateCheckForUpdatesMatrix
{
#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	SPUUpdater *updater = masterController().updateController.updater;

	BOOL checks = updater.automaticallyChecksForUpdates;
	BOOL downloads = (checks && updater.automaticallyDownloadsUpdates);

	self.checkForUpdatesAutomaticallyDownload.state = downloads;
	self.checkForUpdatesAutomaticallyCheck.state = (checks && downloads == NO);
	self.checkForUpdatesDontCheck.state = (checks == NO);
#endif
}

- (void)onChangedCheckForUpdates:(nullable id)sender
{
#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	SPUUpdater *updater = masterController().updateController.updater;

	BOOL downloads = (sender == self.checkForUpdatesAutomaticallyDownload);
	BOOL checks = (downloads || sender == self.checkForUpdatesAutomaticallyCheck);

	updater.automaticallyChecksForUpdates = checks;
	updater.automaticallyDownloadsUpdates = downloads;

	[self updateCheckForUpdatesMatrix];
#endif
}

- (void)onChangedCheckForBetaUpdates:(nullable id)sender
{
#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionSparkleFrameworkFeedURL];

	if ([TPCPreferences receiveBetaUpdates]) {
		[menuController() checkForUpdates:nil];
	}
#endif
}

@end

#pragma mark -
#pragma mark Controls

@interface TDCPreferencesControlsPane () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) NSTableView *aliasTable;
@property (nonatomic, strong) NSSegmentedControl *aliasButtons;
@property (nonatomic, strong) NSMutableArray<NSMutableArray<NSString *> *> *aliasRows; // [name, commands]
- (IBAction)onChangedInputHistoryScheme:(nullable id)sender;
- (IBAction)onChangedMainInputTextViewFontSize:(nullable id)sender;
- (IBAction)onChangedMainWindowSegmentedController:(nullable id)sender;
@end

@implementation TDCPreferencesControlsPane

- (void)viewDidLoad
{
	[super viewDidLoad];

	NSTabView *tabView = nil;

	for (NSView *subview in self.view.subviews) {
		if ([subview isKindOfClass:[NSTabView class]]) {
			tabView = (NSTabView *)subview;

			break;
		}
	}

	[tabView addTabViewItem:[self _suggestionsTabViewItem]];

	[tabView addTabViewItem:[self _aliasesTabViewItem]];
}

#pragma mark -
#pragma mark Aliases

/* Your own commands: a name and what it runs; /alias does the same */
- (NSTabViewItem *)_aliasesTabViewItem
{
	self.aliasRows = [NSMutableArray array];

	NSDictionary<NSString *, NSString *> *aliases = IRCAlias.aliases;

	for (NSString *name in [aliases.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
		[self.aliasRows addObject:[@[name, aliases[name]] mutableCopy]];
	}

	NSTextField *heading = [NSTextField wrappingLabelWithString:TXTLS(@"TDCPreferencesController[als-h1]")];

	NSTableView *table = [NSTableView new];

	NSTableColumn *nameColumn = [[NSTableColumn alloc] initWithIdentifier:@"name"];

	nameColumn.title = TXTLS(@"TDCPreferencesController[als-c1]");
	nameColumn.width = 110;

	NSTableColumn *commandsColumn = [[NSTableColumn alloc] initWithIdentifier:@"commands"];

	commandsColumn.title = TXTLS(@"TDCPreferencesController[als-c2]");
	commandsColumn.width = 400;

	[table addTableColumn:nameColumn];
	[table addTableColumn:commandsColumn];

	table.usesAlternatingRowBackgroundColors = YES;
	table.style = NSTableViewStyleFullWidth;
	table.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;
	table.dataSource = self;
	table.delegate = self;

	self.aliasTable = table;

	NSScrollView *scrollView = [NSScrollView new];

	scrollView.documentView = table;
	scrollView.hasVerticalScroller = YES;
	scrollView.borderType = NSBezelBorder;

	[scrollView.widthAnchor constraintEqualToConstant:540].active = YES;
	[scrollView.heightAnchor constraintEqualToConstant:200].active = YES;

	NSImage *addImage = [NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:TXTLS(@"TDCPreferencesController[als-ad]")];
	NSImage *removeImage = [NSImage imageWithSystemSymbolName:@"minus" accessibilityDescription:TXTLS(@"TDCPreferencesController[als-rm]")];

	NSSegmentedControl *buttons = [NSSegmentedControl segmentedControlWithImages:@[addImage, removeImage] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(onAliasButton:)];

	buttons.segmentStyle = NSSegmentStyleSmallSquare;

	[buttons setEnabled:NO forSegment:1];

	self.aliasButtons = buttons;

	NSTextField *note = [NSTextField wrappingLabelWithString:TXTLS(@"TDCPreferencesController[als-n1]")];

	note.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	note.textColor = [NSColor secondaryLabelColor];

	NSStackView *column = [NSStackView stackViewWithViews:@[heading, scrollView, buttons, note]];

	column.orientation = NSUserInterfaceLayoutOrientationVertical;
	column.alignment = NSLayoutAttributeLeading;
	column.spacing = 0;
	column.translatesAutoresizingMaskIntoConstraints = NO;

	[column setCustomSpacing:10 afterView:heading];
	[column setCustomSpacing:12 afterView:buttons];

	[heading.widthAnchor constraintLessThanOrEqualToConstant:540].active = YES;
	[note.widthAnchor constraintLessThanOrEqualToConstant:540].active = YES;

	NSView *itemView = [NSView new];

	[itemView addSubview:column];

	[NSLayoutConstraint activateConstraints:@[
		[column.leadingAnchor constraintEqualToAnchor:itemView.leadingAnchor constant:40],
		[column.topAnchor constraintEqualToAnchor:itemView.topAnchor constant:24]
	]];

	NSTabViewItem *item = [NSTabViewItem new];

	item.label = TXTLS(@"TDCPreferencesController[als-t1]");
	item.view = itemView;

	return item;
}

- (void)_saveAliases
{
	NSMutableDictionary<NSString *, NSString *> *aliases = [NSMutableDictionary dictionary];

	for (NSArray<NSString *> *row in self.aliasRows) {
		NSString *name = row[0].lowercaseString;
		NSString *commands = [row[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

		if ([IRCAlias isValidAliasName:name] == NO || commands.length == 0 || [IRCCommandIndex indexOfLocalCommand:name] != NSNotFound) {
			continue;
		}

		aliases[name] = commands;
	}

	[RZUserDefaults() setObject:[aliases copy] forKey:@"Input -> Aliases"];
}

- (void)onAliasButton:(NSSegmentedControl *)sender
{
	NSTableView *table = self.aliasTable;

	if (sender.selectedSegment == 0) {
		[self.aliasRows addObject:[@[@"", @""] mutableCopy]];

		NSInteger row = (self.aliasRows.count - 1);

		[table reloadData];

		[table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

		[table editColumn:0 row:row withEvent:nil select:YES];

		return;
	}

	NSInteger row = table.selectedRow;

	if (row < 0) {
		return;
	}

	[self.aliasRows removeObjectAtIndex:row];

	[table reloadData];

	[self _saveAliases];

	[self.aliasButtons setEnabled:NO forSegment:1];
}

- (void)onAliasEdited:(NSTextField *)sender
{
	NSTableView *table = self.aliasTable;

	NSInteger row = [table rowForView:sender];
	NSInteger column = [table columnForView:sender];

	if (row < 0 || row >= (NSInteger)self.aliasRows.count || column < 0) {
		return;
	}

	NSString *value = [sender.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

	if (column == 0) {
		if ([value hasPrefix:@"/"]) {
			value = [value substringFromIndex:1];
		}

		value = value.lowercaseString;
	}

	self.aliasRows[row][column] = value;

	[self _saveAliases];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.aliasRows.count;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSString *identifier = tableColumn.identifier;

	NSTextField *field = [tableView makeViewWithIdentifier:identifier owner:self];

	if (field == nil) {
		field = [NSTextField textFieldWithString:@""];

		field.identifier = identifier;
		field.bordered = NO;
		field.drawsBackground = NO;
		field.editable = YES;
		field.target = self;
		field.action = @selector(onAliasEdited:);
		field.cell.sendsActionOnEndEditing = YES;
		/* Examples of what is typed, not words to translate */
		field.placeholderString = TXLocalizationNotNeeded(([identifier isEqualToString:@"name"]) ? @"o" : @"/mode $channel +o $1");
	}

	NSArray<NSString *> *values = self.aliasRows[row];

	field.stringValue = (([identifier isEqualToString:@"name"]) ? values[0] : values[1]);

	return field;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[self.aliasButtons setEnabled:(self.aliasTable.selectedRow >= 0) forSegment:1];
}

/* Typing: a suggestion switch per kind and Markdown, built in code */
- (NSTabViewItem *)_suggestionsTabViewItem
{
	NSTextField *heading = [NSTextField labelWithString:TXTLS(@"TDCPreferencesController[icp-h1]")];

	NSArray<NSString *> *titles = @[TXTLS(@"TDCPreferencesController[icp-k0]"),
									TXTLS(@"TDCPreferencesController[icp-k1]"),
									TXTLS(@"TDCPreferencesController[icp-k2]"),
									TXTLS(@"TDCPreferencesController[icp-k3]")];

	NSMutableArray<NSView *> *rows = [NSMutableArray arrayWithObject:heading];

	[titles enumerateObjectsUsingBlock:^(NSString *title, NSUInteger kind, BOOL *stop) {
		NSButton *checkbox = [NSButton checkboxWithTitle:title target:self action:@selector(onChangedInputCompletion:)];

		checkbox.tag = kind;

		checkbox.state = [TPCPreferences inputCompletionEnabledForKind:kind];

		[rows addObject:checkbox];
	}];

	NSTextField *note = [NSTextField wrappingLabelWithString:TXTLS(@"TDCPreferencesController[icp-n1]")];

	note.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	note.textColor = [NSColor secondaryLabelColor];

	[rows addObject:note];

	/* Markdown when sending */
	NSButton *markdownButton = [NSButton checkboxWithTitle:TXTLS(@"TDCPreferencesController[imd-c1]") target:self action:@selector(onChangedInputMarkdown:)];

	markdownButton.state = [TPCPreferences inputMarkdownEnabled];

	NSTextField *markdownNote = [NSTextField wrappingLabelWithString:TXTLS(@"TDCPreferencesController[imd-n1]")];

	markdownNote.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	markdownNote.textColor = [NSColor secondaryLabelColor];

	NSBox *separator = [NSBox new];

	separator.boxType = NSBoxSeparator;

	[rows addObject:separator];
	[rows addObject:markdownButton];
	[rows addObject:markdownNote];

	/* Typing notifications */
	NSButton *typingButton = [NSButton checkboxWithTitle:TXTLS(@"TDCPreferencesController[typ-c1]") target:self action:@selector(onChangedSendTypingNotifications:)];

	typingButton.state = [TPCPreferences sendTypingNotifications];

	NSTextField *typingNote = [NSTextField wrappingLabelWithString:TXTLS(@"TDCPreferencesController[typ-n1]")];

	typingNote.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	typingNote.textColor = [NSColor secondaryLabelColor];

	[rows addObject:typingButton];
	[rows addObject:typingNote];

	NSStackView *column = [NSStackView stackViewWithViews:rows];

	column.orientation = NSUserInterfaceLayoutOrientationVertical;
	column.alignment = NSLayoutAttributeLeading;
	column.spacing = 8;
	column.translatesAutoresizingMaskIntoConstraints = NO;

	[column setCustomSpacing:12 afterView:heading];
	[column setCustomSpacing:16 afterView:rows[4]];
	[column setCustomSpacing:18 afterView:note];
	[column setCustomSpacing:18 afterView:separator];

	[note.widthAnchor constraintLessThanOrEqualToConstant:520].active = YES;
	[markdownNote.widthAnchor constraintLessThanOrEqualToConstant:520].active = YES;
	[typingNote.widthAnchor constraintLessThanOrEqualToConstant:520].active = YES;

	[column setCustomSpacing:18 afterView:markdownNote];
	[separator.widthAnchor constraintEqualToConstant:520].active = YES;

	NSView *itemView = [NSView new];

	[itemView addSubview:column];

	[NSLayoutConstraint activateConstraints:@[
		[column.leadingAnchor constraintEqualToAnchor:itemView.leadingAnchor constant:40],
		[column.trailingAnchor constraintLessThanOrEqualToAnchor:itemView.trailingAnchor constant:-40],
		[column.topAnchor constraintEqualToAnchor:itemView.topAnchor constant:28]
	]];

	NSTabViewItem *item = [NSTabViewItem new];

	item.label = TXTLS(@"TDCPreferencesController[icp-t1]");
	item.view = itemView;

	return item;
}

/* Turned off while typing somewhere: "done" goes out first, instead of the
 others seeing it until their timeout */
- (void)onChangedSendTypingNotifications:(NSButton *)sender
{
	BOOL send = (sender.state == NSControlStateValueOn);

	if (send == NO) {
		for (IRCClient *client in worldController().clientList) {
			for (IRCChannel *channel in client.channelList) {
				[client sendTypingDoneToChannel:channel];
			}
		}
	}

	[TPCPreferences setSendTypingNotifications:send];
}

- (void)onChangedInputMarkdown:(NSButton *)sender
{
	TPCPreferences.inputMarkdownEnabled = (sender.state == NSControlStateValueOn);
}

- (void)onChangedInputCompletion:(NSButton *)sender
{
	[TPCPreferences setInputCompletion:(sender.state == NSControlStateValueOn) forKind:sender.tag];
}

- (void)onChangedInputHistoryScheme:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionInputHistoryScope];
}

- (void)onChangedMainInputTextViewFontSize:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionTextFieldFontSize];
}

- (void)onChangedMainWindowSegmentedController:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionTextFieldSegmentedControllerOrigin];
}

@end

#pragma mark -
#pragma mark Command Scope

@interface TDCPreferencesCommandScopePane ()
@property (nonatomic, weak) IBOutlet NSButton *forwardNoticeToServerConsoleButton;
@property (nonatomic, weak) IBOutlet NSButton *forwardNoticeToSelectedChannelButton;
@property (nonatomic, weak) IBOutlet NSButton *forwardNoticeToQueryButton;

- (IBAction)onChangedForwardNoticeTo:(nullable id)sender;
@end

@implementation TDCPreferencesCommandScopePane

- (void)viewDidLoad
{
	[super viewDidLoad];

	TXNoticeSendLocation location = [TPCPreferences locationToSendNotices];

	self.forwardNoticeToServerConsoleButton.state = (location == TXNoticeSendLocationServerConsole);
	self.forwardNoticeToSelectedChannelButton.state = (location == TXNoticeSendLocationSelectedChannel);
	self.forwardNoticeToQueryButton.state = (location == TXNoticeSendLocationQuery);
}

- (void)onChangedForwardNoticeTo:(nullable id)sender
{
	[TPCPreferences setLocationToSendNotices:[sender tag]];
}

@end

NS_ASSUME_NONNULL_END
