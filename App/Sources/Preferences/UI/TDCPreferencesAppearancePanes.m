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
#import "TPCPathInfoPrivate.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesReload.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCThemeControllerPrivate.h"
#import "TPCThemePrivate.h"
#import "TLOLocalization.h"
#import "TXGlobalModels.h"
#import "TVCMainWindowPrivate.h"
#import "TVCNotificationConfigurationViewControllerPrivate.h"
#import "TDCAlert.h"
#import "TDCPreferencesNotificationConfigurationPrivate.h"
#import "TDCPreferencesUserStyleSheetPrivate.h"
#import "TDCPreferencesControllerPrivate.h"
#import "TDCPreferencesPanePrivate.h"
#import "TDCHighlightKeywordSheetPrivate.h"
#import "IRCHighlightKeywordPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _scrollbackSaveLinesMin		100
#define _scrollbackSaveLinesMax		50000

#pragma mark Highlights

@interface TDCPreferencesHighlightsPane ()
@property (nonatomic, strong) IBOutlet NSArrayController *highlightKeywordsArrayController;
@property (nonatomic, strong) IBOutlet NSArrayController *excludeKeywordsArrayController;
@property (nonatomic, weak) IBOutlet NSTableView *highlightKeywordsTable;
@property (nonatomic, weak) IBOutlet NSTableView *excludeKeywordsTable;
@property (nonatomic, weak) IBOutlet NSButton *highlightNicknameButton;
@property (nonatomic, strong, nullable) TDCHighlightKeywordSheet *keywordSheet;
@property (nonatomic, strong, nullable) NSUserDefaultsController *defaultsController; // the mass highlight row's bindings

/* Bound in the nib; off while keywords are regular expressions */
@property (nonatomic, assign) BOOL highlightCurrentNickname;

- (IBAction)onAddHighlightKeyword:(nullable id)sender;
- (IBAction)onAddExcludeKeyword:(nullable id)sender;
- (IBAction)onChangedHighlightType:(nullable id)sender;
- (IBAction)onChangedHighlightLogging:(nullable id)sender;
@end

@implementation TDCPreferencesHighlightsPane

- (void)viewDidLoad
{
	[super viewDidLoad];

	[self updateHighlightNicknameButton];

	/* A keyword's settings open in a sheet (E3, D-E3.8) */
	[self setUpKeywordTable:self.highlightKeywordsTable arrayController:self.highlightKeywordsArrayController action:@selector(onEditHighlightKeyword:)];
	[self setUpKeywordTable:self.excludeKeywordsTable arrayController:self.excludeKeywordsArrayController action:@selector(onEditExcludeKeyword:)];

	[self addMassHighlightRow];
}

/* Mass highlights (E3, 10.14, D-E3.9): "Not when a message names [5] or
 more people", under the other two checkboxes (moved from Incoming Data) */
- (void)addMassHighlightRow
{
	NSStackView *checkboxes = (NSStackView *)self.highlightNicknameButton.superview;

	if ([checkboxes isKindOfClass:[NSStackView class]] == NO) {
		return;
	}

	NSUserDefaultsController *defaultsController = [TPCPreferencesUserDefaultsController new];

	self.defaultsController = defaultsController;

	NSButton *checkbox = [NSButton checkboxWithTitle:TXTLS(@"TDCPreferencesController[msh-c1]") target:nil action:nil];

	[checkbox bind:NSValueBinding toObject:defaultsController withKeyPath:@"values.AutomaticallyDetectHighlightSpam" options:nil];

	NSNumberFormatter *formatter = [NSNumberFormatter new];

	formatter.allowsFloats = NO;
	formatter.minimum = @(2);
	formatter.maximum = @(99);

	NSTextField *thresholdField = [NSTextField textFieldWithString:@""];

	thresholdField.formatter = formatter;
	thresholdField.alignment = NSTextAlignmentRight;

	[thresholdField.widthAnchor constraintEqualToConstant:34].active = YES;

	[thresholdField bind:NSValueBinding toObject:defaultsController withKeyPath:@"values.Highlights -> Mass Highlight Threshold" options:@{NSContinuouslyUpdatesValueBindingOption : @(YES)}];
	[thresholdField bind:NSEnabledBinding toObject:defaultsController withKeyPath:@"values.AutomaticallyDetectHighlightSpam" options:nil];

	NSTextField *label = [NSTextField labelWithString:TXTLS(@"TDCPreferencesController[msh-c2]")];

	NSStackView *row = [NSStackView stackViewWithViews:@[checkbox, thresholdField, label]];

	row.spacing = 4;
	row.alignment = NSLayoutAttributeFirstBaseline;

	[checkboxes addArrangedSubview:row];
}

/* Rows open the sheet instead of being edited in place, and an Edit button
 joins + and − */
- (void)setUpKeywordTable:(NSTableView *)table arrayController:(NSArrayController *)arrayController action:(SEL)action
{
	NSParameterAssert(table != nil);
	NSParameterAssert(arrayController != nil);

	table.tableColumns.firstObject.editable = NO;

	table.target = self;
	table.doubleAction = action;

	NSButton *removeButton = [self _removeButtonForArrayController:arrayController inView:self.view];

	if (removeButton == nil) {
		return;
	}

	NSButton *editButton = [NSButton buttonWithTitle:TXTLS(@"TDCPreferencesController[hkw-e1]") target:self action:action];

	editButton.bezelStyle = NSBezelStyleSmallSquare;
	editButton.controlSize = removeButton.controlSize;
	editButton.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	editButton.translatesAutoresizingMaskIntoConstraints = NO;

	[editButton bind:NSEnabledBinding toObject:arrayController withKeyPath:@"canRemove" options:nil];

	[removeButton.superview addSubview:editButton];

	[NSLayoutConstraint activateConstraints:@[
		[editButton.leadingAnchor constraintEqualToAnchor:removeButton.trailingAnchor constant:(-1)],
		[editButton.topAnchor constraintEqualToAnchor:removeButton.topAnchor],
		[editButton.heightAnchor constraintEqualToAnchor:removeButton.heightAnchor]
	]];
}

- (nullable NSButton *)_removeButtonForArrayController:(NSArrayController *)arrayController inView:(NSView *)view
{
	for (NSView *subview in view.subviews) {
		if ([subview isKindOfClass:[NSButton class]]) {
			NSButton *button = (NSButton *)subview;

			if (button.action == @selector(remove:) && button.target == arrayController) {
				return button;
			}
		}

		NSButton *button = [self _removeButtonForArrayController:arrayController inView:subview];

		if (button) {
			return button;
		}
	}

	return nil;
}

/* A new keyword when entry is nil */
- (void)editKeyword:(nullable NSDictionary *)entry inArrayController:(NSArrayController *)arrayController excluded:(BOOL)excluded
{
	NSParameterAssert(arrayController != nil);

	NSWindow *window = self.view.window;

	if (window == nil || self.keywordSheet != nil) {
		return;
	}

	TDCHighlightKeywordSheet *sheet = [[TDCHighlightKeywordSheet alloc] initWithEntry:entry excluded:excluded];

	self.keywordSheet = sheet;

	[sheet beginSheetForWindow:window completionHandler:^(NSDictionary<NSString *, id> * _Nullable entryOut) {
		self.keywordSheet = nil;

		if (entryOut == nil) {
			return;
		}

		if (entry) {
			[arrayController removeObject:entry];
		}

		NSMutableDictionary *entryMutable = [entryOut mutableCopy];

		[arrayController addObject:entryMutable];

		[arrayController setSelectedObjects:@[entryMutable]];
	}];
}

- (nullable NSDictionary *)_selectedEntryInArrayController:(NSArrayController *)arrayController
{
	NSDictionary *entry = arrayController.selectedObjects.firstObject;

	if ([entry isKindOfClass:[NSDictionary class]] == NO) {
		return nil;
	}

	return entry;
}

- (void)onEditHighlightKeyword:(nullable id)sender
{
	NSDictionary *entry = [self _selectedEntryInArrayController:self.highlightKeywordsArrayController];

	if (entry == nil) {
		return;
	}

	[self editKeyword:entry inArrayController:self.highlightKeywordsArrayController excluded:NO];
}

- (void)onEditExcludeKeyword:(nullable id)sender
{
	NSDictionary *entry = [self _selectedEntryInArrayController:self.excludeKeywordsArrayController];

	if (entry == nil) {
		return;
	}

	[self editKeyword:entry inArrayController:self.excludeKeywordsArrayController excluded:YES];
}

/* The keyword, then where, who and which sound in grey */
- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSArrayController *arrayController = nil;

	if (tableView == self.highlightKeywordsTable) {
		arrayController = self.highlightKeywordsArrayController;
	} else if (tableView == self.excludeKeywordsTable) {
		arrayController = self.excludeKeywordsArrayController;
	} else {
		return;
	}

	NSArray *entries = arrayController.arrangedObjects;

	if (row < 0 || row >= entries.count || [cell isKindOfClass:[NSTextFieldCell class]] == NO) {
		return;
	}

	NSDictionary *entry = entries[row];

	NSString *keyword = entry[IRCHighlightKeywordStringKey];

	if ([keyword isKindOfClass:[NSString class]] == NO) {
		return;
	}

	NSString *summary = [TDCHighlightKeywordSheet summaryOfEntry:entry];

	if (summary == nil) {
		return;
	}

	NSTextFieldCell *textCell = cell;

	NSFont *font = textCell.font;

	NSMutableAttributedString *value = [[NSMutableAttributedString alloc] initWithString:keyword attributes:@{NSFontAttributeName : font}];

	[value appendAttributedString:[[NSAttributedString alloc] initWithString:[@"   " stringByAppendingString:summary] attributes:@{
		NSFontAttributeName : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]],
		NSForegroundColorAttributeName : [NSColor secondaryLabelColor]
	}]];

	textCell.attributedStringValue = value;
}

- (BOOL)highlightCurrentNickname
{
	if ([TPCPreferences highlightMatchingMethod] == TXNicknameHighlightMatchTypeRegularExpression) {
		return NO;
	}

	return [TPCPreferences highlightCurrentNickname];
}

- (void)setHighlightCurrentNickname:(BOOL)value
{
	[TPCPreferences setHighlightCurrentNickname:value];
}

- (void)updateHighlightNicknameButton
{
	[self willChangeValueForKey:@"highlightCurrentNickname"];
	[self didChangeValueForKey:@"highlightCurrentNickname"];

	self.highlightNicknameButton.enabled =
	([TPCPreferences highlightMatchingMethod] != TXNicknameHighlightMatchTypeRegularExpression);
}

- (void)onChangedHighlightType:(nullable id)sender
{
	[self updateHighlightNicknameButton];

	if ([TPCPreferences highlightMatchingMethod] == TXNicknameHighlightMatchTypeRegularExpression) {
		[self warnAboutInvalidRegularExpressionKeywords];
	}
}

- (void)onChangedHighlightLogging:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionHighlightLogging];
}

/* Keywords saved before switching to regular expressions may not compile:
 they would never match, so say which */
- (void)warnAboutInvalidRegularExpressionKeywords
{
	NSMutableArray<NSString *> *invalidKeywords = [NSMutableArray array];

	for (NSString *keyword in [TPCPreferences highlightMatchKeywords]) {
		if ([XRRegularExpression isValidRegex:keyword] == NO) {
			[invalidKeywords addObject:keyword];
		}
	}

	if (invalidKeywords.count == 0) {
		return;
	}

	[TDCAlert alertWithMessage:TXTLS(@"TDCPreferencesController[r7x-q3]", [invalidKeywords componentsJoinedByString:@"\n"])
						 title:TXTLS(@"TDCPreferencesController[r7x-q1]")
				 defaultButton:TXTLS(@"Prompts[c7s-dq]")
			   alternateButton:nil];
}

- (void)onAddHighlightKeyword:(nullable id)sender
{
	[self editKeyword:nil inArrayController:self.highlightKeywordsArrayController excluded:NO];
}

- (void)onAddExcludeKeyword:(nullable id)sender
{
	[self editKeyword:nil inArrayController:self.excludeKeywordsArrayController excluded:YES];
}

@end

#pragma mark -
#pragma mark Notifications

@interface TDCPreferencesNotificationsPane ()
@property (nonatomic, weak) IBOutlet NSView *notificationControllerHostView;
@property (nonatomic, strong) IBOutlet TVCNotificationConfigurationViewController *notificationController;

/* Bound in the nib */
@property (nonatomic, assign) BOOL onlySpeakEventsForSelection;
@property (nonatomic, assign) BOOL channelMessageSpeakChannelName;
@property (nonatomic, assign) BOOL channelMessageSpeakNickname;

- (IBAction)onChangedDockIconBadges:(nullable id)sender;
@end

@implementation TDCPreferencesNotificationsPane

- (void)viewDidLoad
{
	[super viewDidLoad];

	NSMutableArray *notifications = [NSMutableArray array];

#define _event(_type_)	[notifications addObject:[TDCPreferencesNotificationConfiguration objectWithEventType:TXNotificationType ##_type_]]
#define _spacer			[notifications addObject:@" "]

	_event(AddressBookMatch);
	_spacer;
	_event(Connect);
	_event(Disconnect);
	_spacer;
	_event(Highlight);
	_spacer;
	_event(Invite);
	_event(Kick);
	_spacer;
	_event(ChannelMessage);
	_event(ChannelNotice);
	_spacer;
	_event(NewPrivateMessage);
	_event(PrivateMessage);
	_event(PrivateNotice);
	_spacer;
	_event(UserJoined);
	_event(UserParted);
	_event(UserDisconnected);
	_spacer;
	_event(FileTransferReceiveRequested);
	_spacer;
	_event(FileTransferSendSuccessful);
	_event(FileTransferReceiveSuccessful);
	_spacer;
	_event(FileTransferSendFailed);
	_event(FileTransferReceiveFailed);

#undef _event
#undef _spacer

	self.notificationController.notifications = notifications;

	[self.notificationController attachToView:self.notificationControllerHostView];
}

- (BOOL)onlySpeakEventsForSelection
{
	return [TPCPreferences onlySpeakEventsForSelection];
}

- (void)setOnlySpeakEventsForSelection:(BOOL)onlySpeakEventsForSelection
{
	[TPCPreferences setOnlySpeakEventsForSelection:onlySpeakEventsForSelection];

	[self willChangeValueForKey:@"channelMessageSpeakChannelName"];
	[self didChangeValueForKey:@"channelMessageSpeakChannelName"];
}

- (BOOL)channelMessageSpeakChannelName
{
	if ([TPCPreferences onlySpeakEventsForSelection]) {
		return NO;
	}

	return [TPCPreferences channelMessageSpeakChannelName];
}

- (void)setChannelMessageSpeakChannelName:(BOOL)channelMessageSpeakChannelName
{
	[TPCPreferences setChannelMessageSpeakChannelName:channelMessageSpeakChannelName];
}

- (BOOL)channelMessageSpeakNickname
{
	return [TPCPreferences channelMessageSpeakNickname];
}

- (void)setChannelMessageSpeakNickname:(BOOL)channelMessageSpeakNickname
{
	[TPCPreferences setChannelMessageSpeakNickname:channelMessageSpeakNickname];
}

- (void)onChangedDockIconBadges:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionDockIconBadges];
}

@end

#pragma mark -
#pragma mark Interface

@interface TDCPreferencesInterfacePane ()
/* Bound in the nib (clear: the appearance's own colour) */
@property (nonatomic, copy) NSColor *serverListUnreadCountBadgeHighlightColor;

@property (nonatomic, weak) IBOutlet NSStackView *generalOptionsStack;

- (IBAction)onChangedAppearance:(nullable id)sender;
- (IBAction)onChangedTransparency:(nullable id)sender;
- (IBAction)onChangedChannelViewArrangement:(nullable id)sender;
- (IBAction)onChangedServerListUnreadBadgeColor:(nullable id)sender;
- (IBAction)onResetServerListUnreadBadgeColorsToDefault:(nullable id)sender;
- (IBAction)onChangedUserListModeColor:(nullable id)sender;
- (IBAction)onChangedUserListModeSortOrder:(nullable id)sender;
- (IBAction)onResetUserListModeColorsToDefaults:(nullable id)sender;
@end

@implementation TDCPreferencesInterfacePane

- (void)viewDidLoad
{
	[super viewDidLoad];

	[self addKeepChannelListSortedCheck];
}

/* First of the General tab's options (10.10) */
- (void)addKeepChannelListSortedCheck
{
	NSButton *check = [NSButton checkboxWithTitle:TXTLS(@"TDCPreferencesController[srt-c1]") target:self action:@selector(onChangedKeepChannelListSorted:)];

	check.state = (([TPCPreferences keepChannelListSorted]) ? NSControlStateValueOn : NSControlStateValueOff);

	check.toolTip = TXTLS(@"TDCPreferencesController[srt-t1]");

	[self.generalOptionsStack insertView:check atIndex:0 inGravity:NSStackViewGravityTop];
}

- (void)onChangedKeepChannelListSorted:(NSButton *)sender
{
	BOOL keepSorted = (sender.state == NSControlStateValueOn);

	[TPCPreferences setKeepChannelListSorted:keepSorted];

	/* Sorted at once, not only from the next change */
	if (keepSorted) {
		[menuController() sortChannelListNames:nil];
	}
}

- (NSColor *)serverListUnreadCountBadgeHighlightColor
{
	NSColor *value = [RZUserDefaults() colorForKey:@"Server List Unread Message Count Badge Colors -> Highlight"];

	if (value == nil) {
		value = [NSColor clearColor];
	}

	return value;
}

- (void)setServerListUnreadCountBadgeHighlightColor:(NSColor *)serverListUnreadCountBadgeHighlightColor
{
	NSColor *newValue = serverListUnreadCountBadgeHighlightColor;

	if ([newValue isEqual:[NSColor clearColor]]) {
		newValue = nil;
	}

	[RZUserDefaults() setColor:newValue
						forKey:@"Server List Unread Message Count Badge Colors -> Highlight"];
}

- (void)onChangedAppearance:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionAppearance];
}

- (void)onChangedTransparency:(nullable id)sender
{
	[mainWindow() updateAlphaValueToReflectPreferences];
}

- (void)onChangedChannelViewArrangement:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionChannelViewArrangement];
}

- (void)onChangedServerListUnreadBadgeColor:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionServerListUnreadBadges];
}

- (void)onResetServerListUnreadBadgeColorsToDefault:(nullable id)sender
{
	[self deactivateColorWells];

	[self willChangeValueForKey:@"serverListUnreadCountBadgeHighlightColor"];

	[RZUserDefaults() setObject:nil forKey:@"Server List Unread Message Count Badge Colors -> Highlight"];

	[self didChangeValueForKey:@"serverListUnreadCountBadgeHighlightColor"];

	[self onChangedServerListUnreadBadgeColor:sender];
}

- (void)onChangedUserListModeColor:(nullable id)sender
{
	static NSDictionary<NSNumber *, NSString *> *preferenceMap = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		preferenceMap = @{
			@(10) 	: @"User List Mode Badge Colors -> +y",
			@(9) 	: @"User List Mode Badge Colors -> +q",
			@(8) 	: @"User List Mode Badge Colors -> +a",
			@(7) 	: @"User List Mode Badge Colors -> +o",
			@(6) 	: @"User List Mode Badge Colors -> +h",
			@(5) 	: @"User List Mode Badge Colors -> +v"
		};
	});

	NSString *preferenceKey = preferenceMap[@([sender tag])];

	/* The no-mode checkbox, and resets */
	if (preferenceKey == nil) {
		[TPCPreferences performReloadAction:(TPCPreferencesReloadActionMemberListUserBadges | TPCPreferencesReloadActionMemberList)];
	} else {
		[TPCPreferences performReloadAction:TPCPreferencesReloadActionMemberListUserBadges forKey:preferenceKey];
	}
}

- (void)onChangedUserListModeSortOrder:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionMemberListSortOrder];
}

/* Also resets the no-mode colour (in Hidden Preferences, which follows the default) */
- (void)onResetUserListModeColorsToDefaults:(nullable id)sender
{
	/* Hidden Preferences' well too: an active one would set the colour again */
	TDCPreferencesController *controller = self.view.window.windowController;

	if ([controller isKindOfClass:[TDCPreferencesController class]]) {
		[controller deactivateColorWellsInAllPanes];
	} else {
		[self deactivateColorWells];
	}

	[RZUserDefaults() setObject:nil forKey:@"User List Mode Badge Colors -> +y"];
	[RZUserDefaults() setObject:nil forKey:@"User List Mode Badge Colors -> +q"];
	[RZUserDefaults() setObject:nil forKey:@"User List Mode Badge Colors -> +a"];
	[RZUserDefaults() setObject:nil forKey:@"User List Mode Badge Colors -> +o"];
	[RZUserDefaults() setObject:nil forKey:@"User List Mode Badge Colors -> +h"];
	[RZUserDefaults() setObject:nil forKey:@"User List Mode Badge Colors -> +v"];
	[RZUserDefaults() setObject:nil forKey:@"User List Mode Badge Colors -> no mode"];

	[self onChangedUserListModeColor:nil];
}

@end

#pragma mark -
#pragma mark Style

@interface TDCPreferencesStylePane () <TDCPreferencesUserStyleSheetDelegate>
@property (nonatomic, weak) IBOutlet NSPopUpButton *themeSelectionButton;
@property (nonatomic, assign) BOOL reloadingThemeBySelection;
@property (nonatomic, strong, nullable) TDCPreferencesUserStyleSheet *userStyleSheet;

/* Bound in the nib */
@property (nonatomic, copy) NSString *themeChannelViewFontName;
@property (nonatomic, assign) CGFloat themeChannelViewFontSize;
@property (readonly) BOOL themeChannelViewFontIsSystemFont; // hides "Use System Font"
@property (nonatomic, copy) NSString *scrollbackSaveLimit;
@property (nonatomic, assign) NSUInteger messageGroupingStyle; // the Display pop-up's selected tag
@property (readonly) BOOL groupedDisplayUnsupported; // shows "This style shows Classic"

- (IBAction)onChangedThemeSelection:(nullable id)sender;
- (IBAction)onOpenPathToTheme:(nullable id)sender;
- (IBAction)onSelectNewFont:(nullable id)sender;
- (IBAction)onUseSystemFont:(nullable id)sender;
- (IBAction)onModifyUserStyleSheetRules:(nullable id)sender;
- (IBAction)onChangedScrollbackSaveLimit:(nullable id)sender;
- (IBAction)onChangedDisableNicknameColorHashing:(nullable id)sender;
@end

@implementation TDCPreferencesStylePane

- (void)viewDidLoad
{
	[super viewDidLoad];

	[self updateThemeSelection];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(themeListDidChange:)
								   name:TPCThemeControllerThemeListDidChangeNotification
								 object:nil];
}

- (void)paneWillClose
{
	[self.userStyleSheet close];

	/* The font panel is shared: give it back its normal target and action */
	if (RZFontManager().target == self) {
		RZFontManager().target = nil;
		RZFontManager().action = @selector(changeFont:);
	}
}

- (void)themeListDidChange:(NSNotification *)notification
{
	[self updateThemeSelection];
}

- (void)themeDidReload:(NSNotification *)notification
{
	[super themeDidReload:notification];

	/* A style can force its own font */
	[self willChangeFontValues];
	[self didChangeFontValues];

	[self willChangeValueForKey:@"groupedDisplayUnsupported"];
	[self didChangeValueForKey:@"groupedDisplayUnsupported"];

	if (self.reloadingThemeBySelection) {
		self.reloadingThemeBySelection = NO;

		[self showForcedStyleValues];
	}
}

#pragma mark -
#pragma mark Bound Values

- (void)willChangeFontValues
{
	[self willChangeValueForKey:@"themeChannelViewFontName"];
	[self willChangeValueForKey:@"themeChannelViewFontSize"];
	[self willChangeValueForKey:@"themeChannelViewFontIsSystemFont"];
}

- (void)didChangeFontValues
{
	[self didChangeValueForKey:@"themeChannelViewFontName"];
	[self didChangeValueForKey:@"themeChannelViewFontSize"];
	[self didChangeValueForKey:@"themeChannelViewFontIsSystemFont"];
}

- (NSString *)themeChannelViewFontName
{
	/* Its display name is a private one (".AppleSystemUIFont") */
	if ([TPCPreferences themeChannelViewFontIsSystemFont]) {
		return TXTLS(@"TDCPreferencesController[s7f-n1]");
	}

	return [TPCPreferences themeChannelViewFont].displayName;
}

- (BOOL)themeChannelViewFontIsSystemFont
{
	return [TPCPreferences themeChannelViewFontIsSystemFont];
}

- (void)setThemeChannelViewFontName:(NSString *)value
{
	; // Display only (the font panel sets the font)
}

- (CGFloat)themeChannelViewFontSize
{
	return [TPCPreferences themeChannelViewFontSize];
}

- (void)setThemeChannelViewFontSize:(CGFloat)value
{
	; // Display only (the font panel sets the font)
}

- (NSString *)scrollbackSaveLimit
{
	return [NSString stringWithUnsignedInteger:[TPCPreferences scrollbackSaveLimit]];
}

- (void)setScrollbackSaveLimit:(NSString *)value
{
	[TPCPreferences setScrollbackSaveLimit:value.integerValue];
}

- (BOOL)validateValue:(inout id *)value forKey:(NSString *)key error:(out NSError **)outError
{
	if ([key isEqualToString:@"scrollbackSaveLimit"]) {
		NSInteger valueInteger = [*value integerValue];

		if (valueInteger < _scrollbackSaveLinesMin) {
			*value = [NSString stringWithUnsignedInteger:_scrollbackSaveLinesMin];
		} else if (valueInteger > _scrollbackSaveLinesMax) {
			*value = [NSString stringWithUnsignedInteger:_scrollbackSaveLinesMax];
		}
	}

	return YES;
}

#pragma mark -
#pragma mark Display

/* The time and nickname formats each display is made for */
static NSString * const _chatNicknameFormat = @"%@%n";
static NSString * const _chatTimestampFormat = @"%H:%M";

+ (NSString *)nicknameFormatForGroupingStyle:(TVCLogLineGroupingStyle)groupingStyle
{
	if (groupingStyle == TVCLogLineGroupingStyleGrouped) {
		return _chatNicknameFormat;
	}

	return [TPCPreferences themeNicknameFormatDefault];
}

+ (NSString *)timestampFormatForGroupingStyle:(TVCLogLineGroupingStyle)groupingStyle
{
	if (groupingStyle == TVCLogLineGroupingStyleGrouped) {
		return _chatTimestampFormat;
	}

	return [TPCPreferences themeTimestampFormatDefault];
}

+ (NSString *)displayNameForGroupingStyle:(TVCLogLineGroupingStyle)groupingStyle
{
	if (groupingStyle == TVCLogLineGroupingStyleGrouped) {
		return TXTLS(@"TDCPreferencesController[g7d-n1]");
	}

	return TXTLS(@"TDCPreferencesController[g7d-n2]");
}

- (NSUInteger)messageGroupingStyle
{
	return [TPCPreferences messageGroupingStyle];
}

- (void)setMessageGroupingStyle:(NSUInteger)messageGroupingStyle
{
	TVCLogLineGroupingStyle previousStyle = [TPCPreferences messageGroupingStyle];

	if (previousStyle == messageGroupingStyle) {
		return;
	}

	[self willChangeValueForKey:@"groupedDisplayUnsupported"];

	[TPCPreferences setMessageGroupingStyle:messageGroupingStyle];

	[self didChangeValueForKey:@"groupedDisplayUnsupported"];

	[self changeFormatsFromGroupingStyle:previousStyle toGroupingStyle:messageGroupingStyle];
}

- (BOOL)groupedDisplayUnsupported
{
	return ([TPCPreferences messageGroupingStyle] == TVCLogLineGroupingStyleGrouped &&
			theme().supportsGroupedDisplay == NO);
}

/* Formats still at the previous display's change silently; formats someone
 chose themselves only after asking */
- (void)changeFormatsFromGroupingStyle:(TVCLogLineGroupingStyle)previousStyle toGroupingStyle:(TVCLogLineGroupingStyle)newStyle
{
	NSString *nicknameFormat = [self.class nicknameFormatForGroupingStyle:newStyle];
	NSString *timestampFormat = [self.class timestampFormatForGroupingStyle:newStyle];

	BOOL formatsAreDefaults =
	([[TPCPreferences themeNicknameFormat] isEqualToString:[self.class nicknameFormatForGroupingStyle:previousStyle]] &&
	 [[TPCPreferences themeTimestampFormat] isEqualToString:[self.class timestampFormatForGroupingStyle:previousStyle]]);

	BOOL formatsAlreadyMatch =
	([[TPCPreferences themeNicknameFormat] isEqualToString:nicknameFormat] &&
	 [[TPCPreferences themeTimestampFormat] isEqualToString:timestampFormat]);

	void (^changeFormats)(void) = ^{
		[TPCPreferences setThemeNicknameFormat:nicknameFormat];
		[TPCPreferences setThemeTimestampFormat:timestampFormat];
	};

	NSWindow *window = self.view.window;

	if (formatsAlreadyMatch || window == nil) {
		[self onChangedTheme:nil];

		return;
	}

	if (formatsAreDefaults) {
		changeFormats();

		[self onChangedTheme:nil];

		return;
	}

	/* Examples read better than format symbols */
	NSString *timestampExample = TXFormattedTimestamp([NSDate date], timestampFormat);

	if (timestampExample == nil) {
		timestampExample = timestampFormat;
	}

	NSString *nicknameExample = [nicknameFormat stringByReplacingOccurrencesOfString:@"%@" withString:@"@"];

	nicknameExample = [nicknameExample stringByReplacingOccurrencesOfString:@"%n" withString:@"alice"];

	[TDCAlert alertSheetWithWindow:window
							  body:TXTLS(@"TDCPreferencesController[g7d-b1]", [self.class displayNameForGroupingStyle:newStyle], timestampExample, nicknameExample)
							 title:TXTLS(@"TDCPreferencesController[g7d-t1]")
					 defaultButton:TXTLS(@"TDCPreferencesController[g7d-y1]")
				   alternateButton:TXTLS(@"TDCPreferencesController[g7d-k1]")
					   otherButton:nil
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
		if (buttonClicked == TDCAlertResponseDefault) {
			changeFormats();
		}

		[self onChangedTheme:nil];
	}];
}

- (void)onChangedScrollbackSaveLimit:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionScrollbackSaveLimit];
}

- (void)onChangedDisableNicknameColorHashing:(nullable id)sender
{
	[self onChangedTheme:nil];
}

#pragma mark -
#pragma mark Style Selection

- (void)updateThemeSelection
{
	[self.themeSelectionButton removeAllItems];

	NSString *currentThemeName = themeController().name;

	TPCThemeStorageLocation currentStorageLocation = themeController().storageLocation;

	[themeController() enumerateAvailableThemesWithBlock:^(NSString *themeName, TPCThemeStorageLocation storageLocation, BOOL multipleVariants, BOOL *stop) {
		NSString *displayName = themeName;

		if (multipleVariants) {
			displayName = [NSString stringWithFormat:@"%@ (%@)",
				themeName, [TPCThemeController descriptionForStorageLocation:storageLocation]];
		}

		NSMenuItem *item = [NSMenuItem menuItemWithTitle:displayName target:nil action:nil];

		item.representedObject =
		@{
		  @"themeName" : themeName,
		  @"storageLocation" : @(storageLocation)
		};

		if ([currentThemeName isEqualToString:themeName] &&
			currentStorageLocation == storageLocation)
		{
			item.tag = 100; // Tag for item to select
		}

		[self.themeSelectionButton.menu addItem:item];
	}];

	[self.themeSelectionButton selectItemWithTag:100];
}

- (void)onChangedThemeSelection:(nullable id)sender
{
	NSMenuItem *selectedItem = self.themeSelectionButton.selectedItem;

	NSDictionary *context = selectedItem.representedObject;

	NSString *newThemeName = context[@"themeName"];

	TPCThemeStorageLocation newStorageLocation = [context unsignedIntegerForKey:@"storageLocation"];

	NSString *newTheme = [TPCThemeController buildFilename:newThemeName forStorageLocation:newStorageLocation];

	NSString *currentTheme = [TPCPreferences themeName];

	if ([currentTheme isEqualToString:newTheme]) {
		return;
	}

	[TPCPreferences setThemeName:newTheme];

	self.reloadingThemeBySelection = YES;

	[self onChangedTheme:nil];
}

/* After a style chosen here loaded: say which preferences it overrides */
- (void)showForcedStyleValues
{
	NSMutableString *forcedValuesMutable = [NSMutableString string];

	if ([TPCPreferences themeNicknameFormatPreferenceUserConfigurable] == NO) {
		[forcedValuesMutable appendString:TXTLS(@"TDCPreferencesController[77t-de]")];

		[forcedValuesMutable appendString:@"\n"];
	}

	if ([TPCPreferences themeTimestampFormatPreferenceUserConfigurable] == NO) {
		[forcedValuesMutable appendString:TXTLS(@"TDCPreferencesController[ddh-hr]")];

		[forcedValuesMutable appendString:@"\n"];
	}

	if ([TPCPreferences themeChannelViewFontPreferenceUserConfigurable] == NO) {
		[forcedValuesMutable appendString:TXTLS(@"TDCPreferencesController[we8-i8]")];

		[forcedValuesMutable appendString:@"\n"];
	}

	NSString *forcedValues = forcedValuesMutable.trim;

	if (forcedValues.length == 0) {
		return;
	}

	/* The section may have left the window (closed) before the style loaded */
	NSWindow *window = self.view.window;

	if (window == nil) {
		return;
	}

	NSString *currentTheme = [TPCPreferences themeName];

	NSString *themeName = [TPCThemeController extractThemeName:currentTheme];

	[TDCAlert alertSheetWithWindow:window
							  body:TXTLS(@"TDCPreferencesController[q4o-2f]", themeName, forcedValues)
							 title:TXTLS(@"TDCPreferencesController[uc0-z7]")
					 defaultButton:TXTLS(@"Prompts[c7s-dq]")
				   alternateButton:nil
					   otherButton:nil
					suppressionKey:@"theme_override_info"
				   suppressionText:nil
				   completionBlock:nil];
}

- (void)onOpenPathToTheme:(nullable id)sender
{
	if (themeController().bundledTheme == NO) {
		[RZWorkspace() openURL:themeController().originalURL];

		return;
	}

	[TDCAlert alertSheetWithWindow:self.view.window
							  body:TXTLS(@"TDCPreferencesController[ojj-ap]")
							 title:TXTLS(@"TDCPreferencesController[5jv-aw]")
					 defaultButton:TXTLS(@"TDCPreferencesController[6ws-av]")
				   alternateButton:TXTLS(@"TDCPreferencesController[aib-iy]")
					   otherButton:TXTLS(@"TDCPreferencesController[dj8-1t]")
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
		if (buttonClicked == TDCAlertResponseDefault) {
			[RZWorkspace() openURL:themeController().originalURL];
		} else if (buttonClicked == TDCAlertResponseAlternate) {
			[self onModifyUserStyleSheetRules:nil];
		} else if (buttonClicked == TDCAlertResponseOther) {
			[[underlyingAlert window] orderOut:nil];

			[themeController() copyActiveThemeToDestinationLocation:TPCThemeStorageLocationCustom reloadOnCopy:YES openOnCopy:YES];
		}
	}];
}

#pragma mark -
#pragma mark Font

- (void)onSelectNewFont:(nullable id)sender
{
	NSFont *currentFont = [TPCPreferences themeChannelViewFont];

	[RZFontManager() setSelectedFont:currentFont isMultiple:NO];

	[RZFontManager() orderFrontFontPanel:self];

	RZFontManager().target = self;
	RZFontManager().action = @selector(onChangedChannelViewFont:);
}

- (void)onChangedChannelViewFont:(NSFontManager *)sender
{
	NSFont *currentFont = [TPCPreferences themeChannelViewFont];

	NSFont *newFont = [sender convertFont:currentFont];

	[self willChangeFontValues];

	[TPCPreferences setThemeChannelViewFontName:newFont.fontName];
	[TPCPreferences setThemeChannelViewFontSize:newFont.pointSize];

	[self didChangeFontValues];

	[self onChangedTheme:nil];
}

/* The font panel doesn't list the system font: the way back to it */
- (void)onUseSystemFont:(nullable id)sender
{
	[self willChangeFontValues];

	[TPCPreferences setThemeChannelViewFontName:TPCPreferencesThemeFontNameSystemFont];

	[self didChangeFontValues];

	[self onChangedTheme:nil];
}

#pragma mark -
#pragma mark User Style Sheet Rules

- (void)onModifyUserStyleSheetRules:(nullable id)sender
{
	TDCPreferencesUserStyleSheet *sheet = [[TDCPreferencesUserStyleSheet alloc] initWithWindow:self.view.window];

	sheet.delegate = self;

	[sheet start];

	self.userStyleSheet = sheet;
}

- (void)userStyleSheetRulesChanged:(TDCPreferencesUserStyleSheet *)sender
{
	[self onChangedTheme:nil];
}

- (void)userStyleSheetWillClose:(TDCPreferencesUserStyleSheet *)sender
{
	self.userStyleSheet = nil;
}

@end

NS_ASSUME_NONNULL_END
