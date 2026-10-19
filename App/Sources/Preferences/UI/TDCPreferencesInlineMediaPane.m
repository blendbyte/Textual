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

#import "TLOLocalization.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "ICPCoreMediaPrivate.h"
#import "TDCPreferencesPanePrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _inlineMediaWidthMin		40
#define _inlineMediaWidthMax		2000
#define _inlineMediaHeightMin		0
#define _inlineMediaHeightMax		6000

#define _paneWidth			670
#define _paneHeight			400

/* Preferences → Inline Media: General (previews on, image limits),
 Services (web page cards, audio, each service) and Rules (which sites'
 links are previewed). Built in code; the old nib's Images & Video and
 Limitations tabs are gone with Textual 7's limits. */
@interface TDCPreferencesInlineMediaPane () <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>
@property (nonatomic, strong) NSButton *showButton;
@property (nonatomic, strong) NSPopUpButton *fileSizeButton;
@property (nonatomic, strong) NSTextField *widthField;
@property (nonatomic, strong) NSTextField *heightField;
@property (nonatomic, strong) NSButton *webPageCardsButton;
@property (nonatomic, strong) NSButton *audioButton;
@property (nonatomic, copy) NSArray<NSButton *> *serviceButtons;
@property (nonatomic, strong) NSPopUpButton *domainModeButton;
@property (nonatomic, strong) NSTableView *domainTable;
@property (nonatomic, strong) NSSegmentedControl *domainButtons;
@property (nonatomic, strong) NSMutableArray<NSString *> *domains;
@end

@implementation TDCPreferencesInlineMediaPane

- (void)loadView
{
	NSTabView *tabView = [NSTabView new];

	tabView.translatesAutoresizingMaskIntoConstraints = NO;

	[tabView addTabViewItem:[self _tabViewItemWithLabel:TXTLS(@"TDCPreferencesController[imp-t1]") view:[self _generalView]]];
	[tabView addTabViewItem:[self _tabViewItemWithLabel:TXTLS(@"TDCPreferencesController[imp-t2]") view:[self _servicesView]]];
	[tabView addTabViewItem:[self _tabViewItemWithLabel:TXTLS(@"TDCPreferencesController[imp-t3]") view:[self _rulesView]]];

	NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, _paneWidth, _paneHeight)];

	[view addSubview:tabView];

	[NSLayoutConstraint activateConstraints:@[
		[tabView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
		[tabView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-20],
		[tabView.topAnchor constraintEqualToAnchor:view.topAnchor constant:14],
		[tabView.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-20]
	]];

	self.view = view;

	[self _updateControls];
}

- (NSTabViewItem *)_tabViewItemWithLabel:(NSString *)label view:(NSView *)contentView
{
	NSTabViewItem *item = [NSTabViewItem new];

	item.label = label;

	NSView *itemView = [NSView new];

	contentView.translatesAutoresizingMaskIntoConstraints = NO;

	[itemView addSubview:contentView];

	[NSLayoutConstraint activateConstraints:@[
		[contentView.leadingAnchor constraintEqualToAnchor:itemView.leadingAnchor constant:20],
		[contentView.trailingAnchor constraintEqualToAnchor:itemView.trailingAnchor constant:-20],
		[contentView.topAnchor constraintEqualToAnchor:itemView.topAnchor constant:16],
		[contentView.bottomAnchor constraintLessThanOrEqualToAnchor:itemView.bottomAnchor constant:-16]
	]];

	item.view = itemView;

	return item;
}

#pragma mark -
#pragma mark Building

- (NSTextField *)_noteWithString:(NSString *)string
{
	NSTextField *note = [NSTextField wrappingLabelWithString:string];

	note.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	note.textColor = [NSColor secondaryLabelColor];
	note.selectable = NO;

	[note setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

	return note;
}

- (NSButton *)_checkboxWithTitle:(NSString *)title action:(SEL)action
{
	NSButton *checkbox = [NSButton checkboxWithTitle:title target:self action:action];

	return checkbox;
}

- (NSTextField *)_numberFieldWithAction:(SEL)action
{
	NSTextField *field = [NSTextField textFieldWithString:@""];

	field.alignment = NSTextAlignmentRight;
	field.target = self;
	field.action = action;
	field.delegate = self;

	[field.widthAnchor constraintEqualToConstant:64].active = YES;

	return field;
}

- (NSStackView *)_rowWithViews:(NSArray<NSView *> *)views
{
	NSStackView *row = [NSStackView stackViewWithViews:views];

	row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
	row.alignment = NSLayoutAttributeFirstBaseline;
	row.spacing = 6;

	return row;
}

- (NSStackView *)_columnWithViews:(NSArray<NSView *> *)views
{
	NSStackView *column = [NSStackView stackViewWithViews:views];

	column.orientation = NSUserInterfaceLayoutOrientationVertical;
	column.alignment = NSLayoutAttributeLeading;
	column.spacing = 8;

	return column;
}

- (NSView *)_generalView
{
	self.showButton = [self _checkboxWithTitle:TXTLS(@"TDCPreferencesController[imp-s1]") action:@selector(onChangedShowInlineMedia:)];

	NSTextField *showNote = [self _noteWithString:TXTLS(@"TDCPreferencesController[imp-s2]")];

	/* Tags as stored in "InlineMediaMaximumFilesize" (+[TPCPreferences inlineImagesMaxFilesize]) */
	NSPopUpButton *fileSizeButton = [NSPopUpButton new];

	NSArray<NSNumber *> *megabytes = @[@1, @2, @3, @4, @5, @10, @15, @20, @50, @100];

	[megabytes enumerateObjectsUsingBlock:^(NSNumber *size, NSUInteger index, BOOL *stop) {
		[fileSizeButton addItemWithTitle:TXTLS(@"TDCPreferencesController[imp-mb]", size.unsignedIntegerValue)];

		fileSizeButton.lastItem.tag = (index + 1);
	}];

	fileSizeButton.target = self;
	fileSizeButton.action = @selector(onChangedFileSize:);

	self.fileSizeButton = fileSizeButton;

	self.widthField = [self _numberFieldWithAction:@selector(onChangedImageWidth:)];
	self.heightField = [self _numberFieldWithAction:@selector(onChangedImageHeight:)];

	NSStackView *fileSizeRow = [self _rowWithViews:@[[NSTextField labelWithString:TXTLS(@"TDCPreferencesController[imp-l1]")], fileSizeButton]];
	NSStackView *widthRow = [self _rowWithViews:@[[NSTextField labelWithString:TXTLS(@"TDCPreferencesController[imp-l2]")], self.widthField, [NSTextField labelWithString:TXTLS(@"TDCPreferencesController[imp-u1]")]]];
	NSStackView *heightRow = [self _rowWithViews:@[[NSTextField labelWithString:TXTLS(@"TDCPreferencesController[imp-l3]")], self.heightField, [NSTextField labelWithString:TXTLS(@"TDCPreferencesController[imp-u2]")]]];

	NSStackView *column = [self _columnWithViews:@[self.showButton, showNote, fileSizeRow, widthRow, heightRow]];

	[column setCustomSpacing:18 afterView:showNote];

	[showNote.widthAnchor constraintLessThanOrEqualToConstant:540].active = YES;

	return column;
}

- (NSView *)_servicesView
{
	self.webPageCardsButton = [self _checkboxWithTitle:TXTLS(@"TDCPreferencesController[imp-w1]") action:@selector(onChangedWebPageCards:)];

	NSTextField *webPageCardsNote = [self _noteWithString:TXTLS(@"TDCPreferencesController[imp-w2]")];

	self.audioButton = [self _checkboxWithTitle:TXTLS(@"TDCPreferencesController[imp-a1]") action:@selector(onChangedAudio:)];

	NSTextField *servicesLabel = [NSTextField labelWithString:TXTLS(@"TDCPreferencesController[imp-v1]")];

	/* Three columns, filled down */
	NSArray<NSString *> *serviceNames = [ICPCoreMedia serviceNames];

	NSMutableArray<NSButton *> *serviceButtons = [NSMutableArray array];

	for (NSString *serviceName in serviceNames) {
		NSButton *button = [self _checkboxWithTitle:serviceName action:@selector(onChangedService:)];

		button.identifier = serviceName;

		[serviceButtons addObject:button];
	}

	self.serviceButtons = serviceButtons;

	NSUInteger rowCount = ((serviceButtons.count + 2) / 3);

	NSMutableArray<NSStackView *> *columns = [NSMutableArray array];

	for (NSUInteger columnIndex = 0; columnIndex < 3; columnIndex++) {
		NSRange range = NSMakeRange((columnIndex * rowCount), 0);

		if (range.location >= serviceButtons.count) {
			break;
		}

		range.length = MIN(rowCount, (serviceButtons.count - range.location));

		NSStackView *column = [self _columnWithViews:[serviceButtons subarrayWithRange:range]];

		column.spacing = 6;

		[column.widthAnchor constraintEqualToConstant:150].active = YES;

		[columns addObject:column];
	}

	NSStackView *servicesGrid = [NSStackView stackViewWithViews:columns];

	servicesGrid.orientation = NSUserInterfaceLayoutOrientationHorizontal;
	servicesGrid.alignment = NSLayoutAttributeTop;
	servicesGrid.spacing = 12;

	NSStackView *column = [self _columnWithViews:@[self.webPageCardsButton, webPageCardsNote, self.audioButton, servicesLabel, servicesGrid]];

	[column setCustomSpacing:12 afterView:webPageCardsNote];
	[column setCustomSpacing:18 afterView:self.audioButton];

	[webPageCardsNote.widthAnchor constraintLessThanOrEqualToConstant:540].active = YES;

	return column;
}

- (NSView *)_rulesView
{
	NSPopUpButton *domainModeButton = [NSPopUpButton new];

	[domainModeButton addItemWithTitle:TXTLS(@"TDCPreferencesController[imp-r2]")];
	domainModeButton.lastItem.tag = TXInlineMediaDomainRuleModeExcept;

	[domainModeButton addItemWithTitle:TXTLS(@"TDCPreferencesController[imp-r3]")];
	domainModeButton.lastItem.tag = TXInlineMediaDomainRuleModeOnly;

	domainModeButton.target = self;
	domainModeButton.action = @selector(onChangedDomainMode:);

	self.domainModeButton = domainModeButton;

	NSStackView *modeRow = [self _rowWithViews:@[[NSTextField labelWithString:TXTLS(@"TDCPreferencesController[imp-r1]")], domainModeButton]];

	/* The sites: one editable column */
	NSTableView *domainTable = [NSTableView new];

	NSTableColumn *domainColumn = [[NSTableColumn alloc] initWithIdentifier:@"domain"];

	domainColumn.resizingMask = NSTableColumnAutoresizingMask;

	[domainTable addTableColumn:domainColumn];

	domainTable.headerView = nil;
	domainTable.allowsMultipleSelection = YES;
	domainTable.usesAlternatingRowBackgroundColors = YES;
	domainTable.style = NSTableViewStyleFullWidth;
	domainTable.dataSource = self;
	domainTable.delegate = self;
	domainTable.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;

	self.domainTable = domainTable;

	NSScrollView *scrollView = [NSScrollView new];

	scrollView.documentView = domainTable;
	scrollView.hasVerticalScroller = YES;
	scrollView.borderType = NSBezelBorder;

	[scrollView.widthAnchor constraintEqualToConstant:360].active = YES;
	[scrollView.heightAnchor constraintEqualToConstant:150].active = YES;

	NSImage *addImage = [NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:TXTLS(@"TDCPreferencesController[imp-ra]")];
	NSImage *removeImage = [NSImage imageWithSystemSymbolName:@"minus" accessibilityDescription:TXTLS(@"TDCPreferencesController[imp-rr]")];

	NSSegmentedControl *domainButtons = [NSSegmentedControl segmentedControlWithImages:@[addImage, removeImage] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(onDomainButton:)];

	domainButtons.segmentStyle = NSSegmentStyleSmallSquare;

	self.domainButtons = domainButtons;

	NSTextField *rulesNote = [self _noteWithString:TXTLS(@"TDCPreferencesController[imp-rn]")];

	NSStackView *column = [self _columnWithViews:@[modeRow, scrollView, domainButtons, rulesNote]];

	column.spacing = 0;

	[column setCustomSpacing:10 afterView:modeRow];
	[column setCustomSpacing:12 afterView:domainButtons];

	[rulesNote.widthAnchor constraintLessThanOrEqualToConstant:540].active = YES;

	return column;
}

#pragma mark -
#pragma mark State

- (void)_updateControls
{
	self.showButton.state = [TPCPreferences showInlineMedia];

	[self.fileSizeButton selectItemWithTag:[RZUserDefaults() integerForKey:@"InlineMediaMaximumFilesize"]];

	self.widthField.stringValue = [NSString stringWithUnsignedInteger:[TPCPreferences inlineMediaMaxWidth]];
	self.heightField.stringValue = [NSString stringWithUnsignedInteger:[TPCPreferences inlineMediaMaxHeight]];

	self.webPageCardsButton.state = [TPCPreferences inlineMediaWebPageCards];
	self.audioButton.state = [TPCPreferences inlineMediaAudio];

	for (NSButton *button in self.serviceButtons) {
		button.state = [TPCPreferences inlineMediaServiceIsEnabled:button.identifier];
	}

	[self.domainModeButton selectItemWithTag:[TPCPreferences inlineMediaDomainRuleMode]];

	self.domains = [[TPCPreferences inlineMediaDomains] mutableCopy];

	[self.domainTable reloadData];

	[self _updateDomainButtons];
}

- (void)_updateDomainButtons
{
	[self.domainButtons setEnabled:(self.domainTable.selectedRowIndexes.count > 0) forSegment:1];
}

- (void)_saveDomains
{
	[TPCPreferences setInlineMediaDomains:[self.domains copy]];
}

#pragma mark -
#pragma mark Actions

- (void)onChangedShowInlineMedia:(id)sender
{
	[TPCPreferences setShowInlineMedia:(self.showButton.state == NSControlStateValueOn)];

	[self onChangedTheme:nil];
}

- (void)onChangedFileSize:(id)sender
{
	[RZUserDefaults() setInteger:self.fileSizeButton.selectedTag forKey:@"InlineMediaMaximumFilesize"];
}

- (void)onChangedImageWidth:(id)sender
{
	NSString *value = TDCPreferencesInlineMediaClampedValue(self.widthField.stringValue, _inlineMediaWidthMin, _inlineMediaWidthMax);

	self.widthField.stringValue = value;

	[TPCPreferences setInlineMediaMaxWidth:value.integerValue];
}

- (void)onChangedImageHeight:(id)sender
{
	NSString *value = TDCPreferencesInlineMediaClampedValue(self.heightField.stringValue, _inlineMediaHeightMin, _inlineMediaHeightMax);

	self.heightField.stringValue = value;

	[TPCPreferences setInlineMediaMaxHeight:value.integerValue];
}

/* A field left by Tab or a click saves too */
- (void)controlTextDidEndEditing:(NSNotification *)notification
{
	id field = notification.object;

	if (field == self.widthField) {
		[self onChangedImageWidth:field];
	} else if (field == self.heightField) {
		[self onChangedImageHeight:field];
	}
}

static NSString *TDCPreferencesInlineMediaClampedValue(NSString *value, NSInteger minimum, NSInteger maximum)
{
	NSInteger valueInteger = value.integerValue;

	valueInteger = MAX(minimum, MIN(maximum, valueInteger));

	return [NSString stringWithInteger:valueInteger];
}

- (void)onChangedWebPageCards:(id)sender
{
	[TPCPreferences setInlineMediaWebPageCards:(self.webPageCardsButton.state == NSControlStateValueOn)];
}

- (void)onChangedAudio:(id)sender
{
	TPCPreferences.inlineMediaAudio = (self.audioButton.state == NSControlStateValueOn);
}

- (void)onChangedService:(NSButton *)sender
{
	[TPCPreferences setInlineMediaService:sender.identifier enabled:(sender.state == NSControlStateValueOn)];
}

- (void)onChangedDomainMode:(id)sender
{
	TPCPreferences.inlineMediaDomainRuleMode = (TXInlineMediaDomainRuleMode)self.domainModeButton.selectedTag;
}

- (void)onDomainButton:(NSSegmentedControl *)sender
{
	NSTableView *domainTable = self.domainTable;

	if (sender.selectedSegment == 0) {
		/* An empty row to type into; left empty, it goes */
		[self.domains addObject:@""];

		NSUInteger row = (self.domains.count - 1);

		[domainTable reloadData];

		[domainTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

		[domainTable editColumn:0 row:row withEvent:nil select:YES];

		return;
	}

	NSIndexSet *selectedRows = domainTable.selectedRowIndexes;

	if (selectedRows.count == 0) {
		return;
	}

	[self.domains removeObjectsAtIndexes:selectedRows];

	[domainTable reloadData];

	[self _saveDomains];

	[self _updateDomainButtons];
}

- (void)onDomainEdited:(NSTextField *)sender
{
	NSInteger row = [self.domainTable rowForView:sender];

	if (row < 0 || row >= (NSInteger)self.domains.count) {
		return;
	}

	NSString *domain = [TPCPreferences normalizedInlineMediaDomain:sender.stringValue];

	if (domain == nil || ([self.domains containsObject:domain] && [self.domains indexOfObject:domain] != (NSUInteger)row)) {
		[self.domains removeObjectAtIndex:row];
	} else {
		self.domains[row] = domain;
	}

	[self.domainTable reloadData];

	[self _saveDomains];

	[self _updateDomainButtons];
}

#pragma mark -
#pragma mark Table View

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.domains.count;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSTextField *field = [tableView makeViewWithIdentifier:@"domain" owner:self];

	if (field == nil) {
		field = [NSTextField textFieldWithString:@""];

		field.identifier = @"domain";
		field.bordered = NO;
		field.drawsBackground = NO;
		field.editable = YES;
		field.placeholderString = TXTLS(@"TDCPreferencesController[imp-rp]");
		field.target = self;
		field.action = @selector(onDomainEdited:);

		/* Clicking away counts: an empty new row goes */
		field.cell.sendsActionOnEndEditing = YES;
	}

	field.stringValue = self.domains[row];

	return field;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[self _updateDomainButtons];
}

@end

NS_ASSUME_NONNULL_END
