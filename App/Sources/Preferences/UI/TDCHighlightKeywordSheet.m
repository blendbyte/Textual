/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

#import "TXMasterController.h"
#import "TXGlobalModels.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TLOLocalization.h"
#import "TLOSoundPlayer.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "IRCWorld.h"
#import "IRCHighlightKeywordPrivate.h"
#import "TDCAlert.h"
#import "TDCHighlightKeywordSheetPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _placesEverywhere		0
#define _placesOnlyThese		1

#define _peopleAnyone			0
#define _peopleOnlyThese		1

@interface TDCHighlightKeywordSheet () <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>
@property (nonatomic, copy) NSDictionary<NSString *, id> *entry;
@property (nonatomic, assign) BOOL excluded;
@property (nonatomic, strong) NSWindow *sheetWindow;
@property (nonatomic, weak) NSWindow *parentWindow;
@property (nonatomic, strong) NSGridView *grid;
@property (nonatomic, strong) NSTextField *keywordField;
@property (nonatomic, strong) NSPopUpButton *placesPopup;
@property (nonatomic, strong) NSTableView *placesTable;
@property (nonatomic, strong) NSPopUpButton *peoplePopup;
@property (nonatomic, strong) NSTextField *peopleField;
@property (nonatomic, strong, nullable) NSPopUpButton *soundPopup;
@property (nonatomic, strong) NSButton *saveButton;
@property (nonatomic, copy) NSArray<IRCTreeItem *> *places; // each server, then its channels
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedPlaces;
@property (nonatomic, copy) NSArray<NSString *> *unknownPlaces; // deleted servers or channels: kept as they were
@property (nonatomic, strong, nullable) NSButton *removedPlacesCheckbox; // whether they stay
@property (nonatomic, copy, nullable) void (^completionHandler)(NSDictionary<NSString *, id> * _Nullable entry);
@end

@implementation TDCHighlightKeywordSheet

- (instancetype)initWithEntry:(nullable NSDictionary<NSString *, id> *)entry excluded:(BOOL)excluded
{
	if ((self = [super init])) {
		self.entry = ((entry) ?: @{});

		self.excluded = excluded;

		return self;
	}

	return nil;
}

+ (NSArray<NSString *> *)_stringsForKey:(NSString *)key inEntry:(NSDictionary<NSString *, id> *)entry
{
	NSArray *strings = entry[key];

	if ([strings isKindOfClass:[NSArray class]] == NO) {
		return @[];
	}

	return strings;
}

#pragma mark -
#pragma mark Summary

+ (nullable NSString *)summaryOfEntry:(NSDictionary<NSString *, id> *)entry
{
	NSParameterAssert(entry != nil);

	NSMutableArray<NSString *> *parts = [NSMutableArray array];

	NSMutableArray<NSString *> *placeNames = [NSMutableArray array];

	NSUInteger removedPlaces = 0;

	for (NSString *placeId in [self _stringsForKey:IRCHighlightKeywordLimitedToKey inEntry:entry]) {
		IRCTreeItem *item = [worldController() findItemWithId:placeId];

		if (item == nil) {
			removedPlaces += 1;

			continue;
		}

		if (item.isClient) {
			[placeNames addObject:((IRCClient *)item).networkNameAlt];
		} else {
			[placeNames addObject:item.name];
		}
	}

	if (placeNames.count > 0) {
		[parts addObject:[placeNames componentsJoinedByString:@", "]];
	} else if (removedPlaces > 0) {
		/* It doesn't match anywhere: not a word without a limit */
		[parts addObject:TXTLS(@"TDCPreferencesController[hkw-m3]")];
	}

	NSArray *nicknames = [self _stringsForKey:IRCHighlightKeywordNicknamesKey inEntry:entry];

	if (nicknames.count > 0) {
		[parts addObject:TXTLS(@"TDCPreferencesController[hkw-m2]", [nicknames componentsJoinedByString:@", "])];
	}

	NSString *sound = entry[IRCHighlightKeywordSoundKey];

	if ([sound isKindOfClass:[NSString class]] && sound.length > 0) {
		[parts addObject:TXTLS(@"TDCPreferencesController[hkw-m1]", sound)];
	}

	if (parts.count == 0) {
		return nil;
	}

	return [parts componentsJoinedByString:@" · "];
}

#pragma mark -
#pragma mark Sheet

- (NSTextField *)_labelWithString:(NSString *)string
{
	NSTextField *label = [NSTextField labelWithString:string];

	label.alignment = NSTextAlignmentRight;

	return label;
}

- (void)_buildPlaces
{
	NSMutableArray<IRCTreeItem *> *places = [NSMutableArray array];

	NSMutableSet<NSString *> *knownPlaces = [NSMutableSet set];

	for (IRCClient *client in worldController().clientList) {
		[places addObject:client];

		[knownPlaces addObject:client.uniqueIdentifier];

		for (IRCChannel *channel in client.channelList) {
			if (channel.isChannel == NO) {
				continue;
			}

			[places addObject:channel];

			[knownPlaces addObject:channel.uniqueIdentifier];
		}
	}

	self.places = places;

	NSArray *limitedTo = [self.class _stringsForKey:IRCHighlightKeywordLimitedToKey inEntry:self.entry];

	self.selectedPlaces = [NSMutableSet setWithArray:limitedTo];

	NSMutableArray<NSString *> *unknownPlaces = [NSMutableArray array];

	for (NSString *placeId in limitedTo) {
		if ([knownPlaces containsObject:placeId] == NO) {
			[unknownPlaces addObject:placeId];
		}
	}

	self.unknownPlaces = unknownPlaces;
}

- (void)_buildWindow
{
	NSDictionary *entry = self.entry;

	/* Keyword */
	NSTextField *keywordField = [NSTextField textFieldWithString:@""];

	NSString *keyword = entry[IRCHighlightKeywordStringKey];

	if ([keyword isKindOfClass:[NSString class]]) {
		keywordField.stringValue = keyword;
	}

	keywordField.delegate = self;

	[keywordField.widthAnchor constraintEqualToConstant:300].active = YES;

	self.keywordField = keywordField;

	/* Where */
	[self _buildPlaces];

	NSPopUpButton *placesPopup = [NSPopUpButton new];

	[placesPopup addItemWithTitle:TXTLS(@"TDCPreferencesController[hkw-p2]")];
	[placesPopup addItemWithTitle:TXTLS(@"TDCPreferencesController[hkw-p3]")];

	[placesPopup selectItemAtIndex:((self.selectedPlaces.count > 0) ? _placesOnlyThese : _placesEverywhere)];

	placesPopup.target = self;
	placesPopup.action = @selector(onChangedPopup:);

	self.placesPopup = placesPopup;

	NSTableView *placesTable = [NSTableView new];

	NSTableColumn *placesColumn = [[NSTableColumn alloc] initWithIdentifier:@"place"];

	[placesTable addTableColumn:placesColumn];

	placesTable.headerView = nil;
	placesTable.style = NSTableViewStyleFullWidth;
	placesTable.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
	placesTable.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;
	placesTable.rowHeight = 22;
	placesTable.dataSource = self;
	placesTable.delegate = self;

	self.placesTable = placesTable;

	NSScrollView *placesScrollView = [NSScrollView new];

	placesScrollView.documentView = placesTable;
	placesScrollView.hasVerticalScroller = YES;
	placesScrollView.borderType = NSBezelBorder;

	[placesScrollView.widthAnchor constraintEqualToConstant:300].active = YES;
	[placesScrollView.heightAnchor constraintEqualToConstant:110].active = YES;

	/* Channels it was limited to that were removed since: shown, and can be let go */
	NSView *placesView = placesScrollView;

	if (self.unknownPlaces.count > 0) {
		NSString *countString = [NSNumberFormatter localizedStringFromNumber:@(self.unknownPlaces.count) numberStyle:NSNumberFormatterDecimalStyle];

		NSButton *removedPlacesCheckbox = [NSButton checkboxWithTitle:TXTLS(@"TDCPreferencesController[hkw-r1]", countString) target:self action:@selector(onToggledRemovedPlaces:)];

		removedPlacesCheckbox.state = NSControlStateValueOn;

		self.removedPlacesCheckbox = removedPlacesCheckbox;

		NSStackView *placesStack = [NSStackView stackViewWithViews:@[placesScrollView, removedPlacesCheckbox]];

		placesStack.orientation = NSUserInterfaceLayoutOrientationVertical;
		placesStack.alignment = NSLayoutAttributeLeading;
		placesStack.spacing = 6;

		placesView = placesStack;
	}

	/* Who */
	NSArray *nicknames = [self.class _stringsForKey:IRCHighlightKeywordNicknamesKey inEntry:entry];

	NSPopUpButton *peoplePopup = [NSPopUpButton new];

	[peoplePopup addItemWithTitle:TXTLS(@"TDCPreferencesController[hkw-f2]")];
	[peoplePopup addItemWithTitle:TXTLS(@"TDCPreferencesController[hkw-f3]")];

	[peoplePopup selectItemAtIndex:((nicknames.count > 0) ? _peopleOnlyThese : _peopleAnyone)];

	peoplePopup.target = self;
	peoplePopup.action = @selector(onChangedPopup:);

	self.peoplePopup = peoplePopup;

	NSTextField *peopleField = [NSTextField textFieldWithString:[nicknames componentsJoinedByString:@" "]];

	peopleField.placeholderString = TXTLS(@"TDCPreferencesController[hkw-f4]");
	peopleField.delegate = self;

	[peopleField.widthAnchor constraintEqualToConstant:300].active = YES;

	self.peopleField = peopleField;

	/* Layout */
	NSMutableArray *rows = [NSMutableArray array];

	[rows addObject:@[[self _labelWithString:TXTLS(@"TDCPreferencesController[hkw-t1]")], keywordField]];
	[rows addObject:@[[self _labelWithString:TXTLS(@"TDCPreferencesController[hkw-p1]")], placesPopup]];
	[rows addObject:@[[NSGridCell emptyContentView], placesView]];
	[rows addObject:@[[self _labelWithString:TXTLS(@"TDCPreferencesController[hkw-f1]")], peoplePopup]];
	[rows addObject:@[[NSGridCell emptyContentView], peopleField]];

	/* A sound for highlight words only */
	if (self.excluded == NO) {
		NSPopUpButton *soundPopup = [NSPopUpButton new];

		[soundPopup addItemWithTitle:TXTLS(@"TDCPreferencesController[hkw-s2]")];

		[soundPopup.menu addItem:[NSMenuItem separatorItem]];

		for (NSString *sound in [TLOSoundPlayer uniqueListOfSounds]) {
			[soundPopup addItemWithTitle:sound];

			soundPopup.lastItem.representedObject = sound;
		}

		NSString *sound = entry[IRCHighlightKeywordSoundKey];

		if ([sound isKindOfClass:[NSString class]] && sound.length > 0) {
			NSInteger soundIndex = [soundPopup indexOfItemWithRepresentedObject:sound];

			if (soundIndex == (-1)) {
				[soundPopup addItemWithTitle:sound];

				soundPopup.lastItem.representedObject = sound;

				soundIndex = (soundPopup.numberOfItems - 1);
			}

			[soundPopup selectItemAtIndex:soundIndex];
		}

		soundPopup.target = self;
		soundPopup.action = @selector(onChangedSound:);

		self.soundPopup = soundPopup;

		[rows addObject:@[[self _labelWithString:TXTLS(@"TDCPreferencesController[hkw-s1]")], soundPopup]];
	}

	NSGridView *grid = [NSGridView gridViewWithViews:rows];

	grid.rowSpacing = 10;
	grid.columnSpacing = 8;
	grid.rowAlignment = NSGridRowAlignmentFirstBaseline;

	[grid columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;

	self.grid = grid;

	/* Buttons */
	NSButton *cancelButton = [NSButton buttonWithTitle:TXTLS(@"Prompts[qso-2g]") target:self action:@selector(onCancel:)];

	cancelButton.keyEquivalent = @"\e";

	NSButton *saveButton = [NSButton buttonWithTitle:TXTLS(@"Prompts[6hx-ni]") target:self action:@selector(onSave:)];

	saveButton.keyEquivalent = @"\r";

	self.saveButton = saveButton;

	NSStackView *buttons = [NSStackView stackViewWithViews:@[cancelButton, saveButton]];

	buttons.spacing = 12;

	/* Heading */
	NSTextField *heading = [NSTextField labelWithString:TXTLS((self.excluded) ? @"TDCPreferencesController[hkw-h2]" : @"TDCPreferencesController[hkw-h1]")];

	heading.font = [NSFont boldSystemFontOfSize:[NSFont systemFontSize]];

	NSView *contentView = [NSView new];

	for (NSView *view in @[heading, grid, buttons]) {
		view.translatesAutoresizingMaskIntoConstraints = NO;

		[contentView addSubview:view];
	}

	[NSLayoutConstraint activateConstraints:@[
		[heading.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20],
		[heading.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],

		[grid.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:16],
		[grid.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
		[grid.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:(-20)],

		[buttons.topAnchor constraintEqualToAnchor:grid.bottomAnchor constant:20],
		[buttons.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:(-20)],
		[buttons.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:(-20)]
	]];

	NSWindow *sheetWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 420, 300) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];

	sheetWindow.contentView = contentView;

	sheetWindow.initialFirstResponder = keywordField;

	self.sheetWindow = sheetWindow;

	[self updateVisibleRows];
}

- (void)beginSheetForWindow:(NSWindow *)window completionHandler:(void (^)(NSDictionary<NSString *, id> * _Nullable entry))completionHandler
{
	NSParameterAssert(window != nil);
	NSParameterAssert(completionHandler != nil);

	self.completionHandler = completionHandler;

	self.parentWindow = window;

	[self _buildWindow];

	[window beginSheet:self.sheetWindow completionHandler:nil];
}

/* The channel list and the nickname field show only when they're used */
- (void)updateVisibleRows
{
	[self.grid rowAtIndex:2].hidden = (self.placesPopup.indexOfSelectedItem != _placesOnlyThese);
	[self.grid rowAtIndex:4].hidden = (self.peoplePopup.indexOfSelectedItem != _peopleOnlyThese);

	NSWindow *sheetWindow = self.sheetWindow;

	[sheetWindow.contentView layoutSubtreeIfNeeded];

	[sheetWindow setContentSize:sheetWindow.contentView.fittingSize];

	[self updateSaveButton];
}

- (NSArray<NSString *> *)_nicknamesInField
{
	NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@" ,;\t"];

	NSMutableArray<NSString *> *nicknames = [NSMutableArray array];

	for (NSString *nickname in [self.peopleField.stringValue componentsSeparatedByCharactersInSet:separators]) {
		if (nickname.length > 0 && [nicknames containsObject:nickname] == NO) {
			[nicknames addObject:nickname];
		}
	}

	return [nicknames copy];
}

/* "Only in" and "Only these" need at least one channel or person */
- (void)updateSaveButton
{
	BOOL enabled = (self.keywordField.stringValue.trim.length > 0);

	if (self.placesPopup.indexOfSelectedItem == _placesOnlyThese) {
		NSMutableSet<NSString *> *chosenPlaces = [self.selectedPlaces mutableCopy];

		if ([self _keepsRemovedPlaces] == NO) {
			[chosenPlaces minusSet:[NSSet setWithArray:self.unknownPlaces]];
		}

		if (chosenPlaces.count == 0) {
			enabled = NO;
		}
	}

	if (self.peoplePopup.indexOfSelectedItem == _peopleOnlyThese && [self _nicknamesInField].count == 0) {
		enabled = NO;
	}

	self.saveButton.enabled = enabled;
}

- (void)controlTextDidChange:(NSNotification *)notification
{
	[self updateSaveButton];
}

- (BOOL)_keepsRemovedPlaces
{
	return (self.removedPlacesCheckbox == nil || self.removedPlacesCheckbox.state == NSControlStateValueOn);
}

- (void)onToggledRemovedPlaces:(id)sender
{
	[self updateSaveButton];
}

- (void)onChangedPopup:(id)sender
{
	[self updateVisibleRows];
}

- (void)onChangedSound:(NSPopUpButton *)sender
{
	NSString *sound = sender.selectedItem.representedObject;

	if (sound) {
		[TLOSoundPlayer playAlertSound:sound];
	}
}

- (void)_endWithEntry:(nullable NSDictionary<NSString *, id> *)entry
{
	[self.parentWindow endSheet:self.sheetWindow];

	[self.sheetWindow orderOut:nil];

	void (^completionHandler)(NSDictionary<NSString *, id> * _Nullable) = self.completionHandler;

	self.completionHandler = nil;

	if (completionHandler) {
		completionHandler(entry);
	}
}

- (void)onCancel:(id)sender
{
	[self _endWithEntry:nil];
}

- (void)onSave:(id)sender
{
	NSString *keyword = self.keywordField.stringValue.trim;

	if (keyword.length == 0) {
		return;
	}

	/* With regular expression matching, a keyword that doesn't compile would never match */
	if (self.excluded == NO &&
		[TPCPreferences highlightMatchingMethod] == TXNicknameHighlightMatchTypeRegularExpression &&
		[XRRegularExpression isValidRegex:keyword] == NO)
	{
		[TDCAlert alertWithMessage:TXTLS(@"TDCPreferencesController[r7x-q2]", keyword)
							 title:TXTLS(@"TDCPreferencesController[r7x-q1]")
					 defaultButton:TXTLS(@"Prompts[c7s-dq]")
				   alternateButton:nil];

		return;
	}

	NSMutableDictionary<NSString *, id> *entry = [self.entry mutableCopy];

	entry[IRCHighlightKeywordStringKey] = keyword;

	/* Where: a whole server covers its channels */
	[entry removeObjectForKey:IRCHighlightKeywordLimitedToKey];

	if (self.placesPopup.indexOfSelectedItem == _placesOnlyThese) {
		NSMutableArray<NSString *> *limitedTo = [NSMutableArray array];

		for (IRCTreeItem *place in self.places) {
			NSString *placeId = place.uniqueIdentifier;

			if ([self.selectedPlaces containsObject:placeId] == NO) {
				continue;
			}

			if (place.isClient == NO && [self.selectedPlaces containsObject:place.associatedClient.uniqueIdentifier]) {
				continue;
			}

			[limitedTo addObject:placeId];
		}

		if ([self _keepsRemovedPlaces]) {
			[limitedTo addObjectsFromArray:self.unknownPlaces];
		}

		if (limitedTo.count > 0) {
			entry[IRCHighlightKeywordLimitedToKey] = [limitedTo copy];
		}
	}

	/* Who */
	[entry removeObjectForKey:IRCHighlightKeywordNicknamesKey];

	if (self.peoplePopup.indexOfSelectedItem == _peopleOnlyThese) {
		NSArray *nicknames = [self _nicknamesInField];

		if (nicknames.count > 0) {
			entry[IRCHighlightKeywordNicknamesKey] = nicknames;
		}
	}

	/* Sound */
	[entry removeObjectForKey:IRCHighlightKeywordSoundKey];

	NSString *sound = self.soundPopup.selectedItem.representedObject;

	if (sound) {
		entry[IRCHighlightKeywordSoundKey] = sound;
	}

	[self _endWithEntry:entry];
}

#pragma mark -
#pragma mark Channel List

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.places.count;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	IRCTreeItem *place = self.places[row];

	NSString *identifier = ((place.isClient) ? @"server" : @"channel");

	NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];

	NSButton *checkbox = nil;

	if (cellView == nil) {
		cellView = [NSTableCellView new];

		cellView.identifier = identifier;

		checkbox = [NSButton checkboxWithTitle:@"" target:self action:@selector(onToggledPlace:)];

		checkbox.translatesAutoresizingMaskIntoConstraints = NO;

		[cellView addSubview:checkbox];

		[NSLayoutConstraint activateConstraints:@[
			[checkbox.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:((place.isClient) ? 4 : 24)],
			[checkbox.trailingAnchor constraintLessThanOrEqualToAnchor:cellView.trailingAnchor constant:(-4)],
			[checkbox.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
		]];
	} else {
		checkbox = cellView.subviews.firstObject;
	}

	checkbox.tag = row;

	if (place.isClient) {
		checkbox.title = TXTLS(@"TDCPreferencesController[hkw-a1]", ((IRCClient *)place).networkNameAlt);

		checkbox.state = [self.selectedPlaces containsObject:place.uniqueIdentifier];

		checkbox.enabled = YES;
	} else {
		checkbox.title = place.name;

		/* Covered by its server */
		BOOL serverSelected = [self.selectedPlaces containsObject:place.associatedClient.uniqueIdentifier];

		checkbox.state = (serverSelected || [self.selectedPlaces containsObject:place.uniqueIdentifier]);

		checkbox.enabled = (serverSelected == NO);
	}

	return cellView;
}

- (void)onToggledPlace:(NSButton *)sender
{
	NSInteger row = sender.tag;

	if (row < 0 || row >= self.places.count) {
		return;
	}

	NSString *placeId = self.places[row].uniqueIdentifier;

	if (sender.state == NSControlStateValueOn) {
		[self.selectedPlaces addObject:placeId];
	} else {
		[self.selectedPlaces removeObject:placeId];
	}

	[self.placesTable reloadData];

	[self updateSaveButton];
}

@end

NS_ASSUME_NONNULL_END
