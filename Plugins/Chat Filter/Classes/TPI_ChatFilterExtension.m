/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2015 - 2018 Codeux Software, LLC & respective contributors.
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

#import "TPI_ChatFilterExtension.h"
#import "TPI_ChatFilterEditFilterSheet.h"
#import "TPI_ChatFilterLogic.h"

#import "THOPluginProtocolPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _filterTableDragToken			@"filterTableDragToken"

#define _filterListUserDefaultsKey		@"Textual Chat Filter Extension -> Filters"

@interface TPI_ChatFilterExtension () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) IBOutlet NSView *preferencesPaneView;
@property (nonatomic, strong) IBOutlet NSMenu *filterAddMenu;
@property (nonatomic, weak) IBOutlet NSButton *filterAddButton;
@property (nonatomic, weak) IBOutlet NSButton *filterRemoveButton;
@property (nonatomic, weak) IBOutlet NSButton *filterEditButton;
@property (nonatomic, weak) IBOutlet TVCBasicTableView *filterTable;
@property (nonatomic, strong, readwrite) IBOutlet NSArrayController *filterArrayController;
@property (nonatomic, assign) BOOL atleastOneFilterExists;
@property (nonatomic, assign) NSInteger activeChatFilterIndex;
@property (nonatomic, strong) TPI_ChatFilterEditFilterSheet *activeChatFilterEditSheet;
@property (nonatomic, strong) TPI_ChatFilterLogic *filterLogicController;
@property (nonatomic, assign) BOOL savingFilters;

- (IBAction)filterTableDoubleClicked:(id)sender;

- (IBAction)presentFilterAddMenu:(id)sender;

- (IBAction)filterAdd:(id)sender;
- (IBAction)filterRemove:(id)sender;
- (IBAction)filterEdit:(id)sender;
- (IBAction)filterDuplicate:(id)sender;
- (IBAction)filterExport:(id)sender;
- (IBAction)filterImport:(id)sender;
@end

@implementation TPI_ChatFilterExtension

#pragma mark -
#pragma mark Filter Logic

- (BOOL)receivedCommand:(NSString *)command withText:(nullable NSString *)text authoredBy:(IRCPrefix *)textAuthor destinedFor:(nullable IRCChannel *)textDestination onClient:(IRCClient *)client receivedAt:(NSDate *)receivedAt referenceMessage:(nullable IRCMessage *)referenceMessage
{
	return [self.filterLogicController receivedCommand:command withText:text authoredBy:textAuthor destinedFor:textDestination onClient:client receivedAt:receivedAt referenceMessage:referenceMessage];
}

- (BOOL)receivedText:(NSString *)text authoredBy:(IRCPrefix *)textAuthor destinedFor:(nullable IRCChannel *)textDestination asLineType:(TVCLogLineType)lineType onClient:(IRCClient *)client receivedAt:(NSDate *)receivedAt wasEncrypted:(BOOL)wasEncrypted
{
	return [self.filterLogicController receivedText:text authoredBy:textAuthor destinedFor:textDestination asLineType:lineType onClient:client receivedAt:receivedAt wasEncrypted:wasEncrypted];
}

#pragma mark -
#pragma mark Internal Filter List Storage

- (void)reloadFilters
{
	[self.filterArrayController removeAllArrangedObjects];

	[self loadFilters];

	[self.filterLogicController reloadFilterActionPerforms];
}

- (void)loadFilters
{
	NSArray *filterConfigurations = [RZUserDefaults() arrayForKey:_filterListUserDefaultsKey];

	for (id filterConfiguration in filterConfigurations) {
		if ([filterConfiguration isKindOfClass:[NSDictionary class]] == NO) {
			continue;
		}

		TPI_ChatFilter *filter = [[TPI_ChatFilter alloc] initWithDictionary:filterConfiguration];

		[self.filterArrayController addObject:filter];
	}

	[self reloadFilterCount];
}

- (void)saveFilters
{
	self.savingFilters = YES;

	NSArray *filters = self.filterArrayController.arrangedObjects;

	NSMutableArray *filterConfigurations = [NSMutableArray arrayWithCapacity:filters.count];

	for (TPI_ChatFilter *filter in filters) {
		[filterConfigurations addObject:filter.dictionaryValue];
	}

	[RZUserDefaults() setObject:[filterConfigurations copy] forKey:_filterListUserDefaultsKey];

	[self reloadFilterCount];
}

- (void)reloadFilterCount
{
	NSArray *arrangedObjects = self.filterArrayController.arrangedObjects;

	self.atleastOneFilterExists = (arrangedObjects.count > 0);
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSString *, id> *)change context:(nullable void *)context
{
	if ([keyPath isEqualToString:_filterListUserDefaultsKey]) {
		if (self.savingFilters) {
			self.savingFilters = NO;

			return;
		}

		[self reloadFilters];
	}
}

#pragma mark -
#pragma mark Preference Pane

- (void)pluginLoadedIntoMemory
{
	XRPerformBlockSynchronouslyOnMainQueue(^{
		NSAssert([TPIBundleFromClass() loadNibNamed:@"TPI_ChatFilterExtension" owner:self topLevelObjects:nil],
			@"Failed to load user interface");
	});

	self.activeChatFilterIndex = (-1);

	self.atleastOneFilterExists = NO;

	self.filterLogicController = [[TPI_ChatFilterLogic alloc] initWithParentObject:self];

	[self loadFilters];

	[RZUserDefaults() addObserver:self forKeyPath:_filterListUserDefaultsKey options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)pluginWillBeUnloadedFromMemory
{
	self.filterLogicController = nil;

	[RZUserDefaults() removeObserver:self forKeyPath:_filterListUserDefaultsKey];
}

- (NSView *)pluginPreferencesPaneView
{
	return self.preferencesPaneView;
}

- (NSString *)pluginPreferencesPaneMenuItemName
{
	return TPILocalizedString(@"TPI_ChatFilterExtension[jq1-6r]");
}

- (void)awakeFromNib
{
	[self.filterTable registerForDraggedTypes:@[_filterTableDragToken]];
}

- (void)filterTableDoubleClicked:(id)sender
{
	[self filterEdit:sender];
}

- (void)filterAdd:(id)sender
{
	[self editFilter:nil];
}

- (void)filterRemove:(id)sender
{
	BOOL performRemove = [TDCAlert modalAlertWithMessage:TPILocalizedString(@"TPI_ChatFilterExtension[dj6-fn]")
												   title:TPILocalizedString(@"TPI_ChatFilterExtension[c0k-xj]")
										   defaultButton:TPILocalizedString(@"TPI_ChatFilterExtension[jvu-m7]")
										 alternateButton:TPILocalizedString(@"TPI_ChatFilterExtension[p5s-ff]")];

	if (performRemove == NO) {
		return;
	}

	NSInteger selectedRow = self.filterTable.selectedRow;

	if (selectedRow < 0) {
		return;
	}

	[self.filterArrayController removeObjectAtArrangedObjectIndex:selectedRow];

	[self saveFilters];
}

- (void)filterEdit:(id)sender
{
	NSInteger selectedRow = self.filterTable.selectedRow;

	if (selectedRow < 0) {
		return;
	}

	TPI_ChatFilter *filter = self.filterArrayController.arrangedObjects[selectedRow];

	[self editFilter:filter atIndex:selectedRow];
}

- (void)editFilter:(id)filter
{
	[self editFilter:filter atIndex:(-1)];
}

- (void)editFilter:(id)filter atIndex:(NSInteger)filterIndex
{
	self.activeChatFilterIndex = filterIndex;

	TPI_ChatFilterEditFilterSheet *sheet =
	[[TPI_ChatFilterEditFilterSheet alloc] initWithFilter:filter];

	sheet.delegate = self;

	sheet.window = [NSApp keyWindow];

	[sheet start];

	self.activeChatFilterEditSheet = sheet;
}

- (void)chatFilterEditFilterSheet:(TPI_ChatFilterEditFilterSheet *)sender onOk:(TPI_ChatFilter *)filter
{
	if ([filter isKindOfClass:[TPI_ChatFilterMutable class]]) {
		filter = [filter copy];
	}

	if (self.activeChatFilterIndex < 0) {
		[self.filterArrayController addObject:filter];
	} else {
		[self.filterArrayController replaceObjectAtArrangedObjectIndex:self.activeChatFilterIndex withObject:filter];
	}

	[self saveFilters];

	[self.filterLogicController reloadFilterActionPerforms];
}

- (void)chatFilterEditFilterSheetWillClose:(TPI_ChatFilterEditFilterSheet *)sender
{
	self.activeChatFilterIndex = (-1);

	self.activeChatFilterEditSheet = nil;
}

- (void)filterDuplicate:(id)sender
{
	NSInteger selectedRow = self.filterTable.selectedRow;

	TPI_ChatFilter *filter = self.filterArrayController.arrangedObjects[selectedRow];

	TPI_ChatFilterMutable *filterNew = [filter mutableCopy];

	filterNew.filterTitle = [filterNew.filterTitle stringByAppendingString:@" (Duplicate)"];

	[self editFilter:[filterNew copy] atIndex:(-1)];
}

- (void)filterExport:(id)sender
{
	NSInteger selectedRow = self.filterTable.selectedRow;

	TPI_ChatFilter *filter = self.filterArrayController.arrangedObjects[selectedRow];

	NSSavePanel *saveDialog = [NSSavePanel savePanel];

	saveDialog.canCreateDirectories = YES;

	saveDialog.nameFieldStringValue = TXLocalizationNotNeeded(@"filter.plist");

	[saveDialog beginSheetModalForWindow:[NSApp keyWindow] completionHandler:^(NSInteger returnCode) {
		if (returnCode != NSModalResponseOK) {
			return;
		}

		NSURL *pathURL = saveDialog.URL;

		[filter writeToURL:pathURL];
	}];
}

- (void)filterImport:(id)sender
{
	NSOpenPanel *openDialog = [NSOpenPanel openPanel];

	openDialog.allowsMultipleSelection = NO;
	openDialog.canChooseDirectories = NO;
	openDialog.canChooseFiles = YES;
	openDialog.canCreateDirectories = NO;
	openDialog.resolvesAliases = YES;

	openDialog.message = TPILocalizedString(@"TPI_ChatFilterExtension[i9c-s3]");

	openDialog.prompt = TPILocalizedString(@"TPI_ChatFilterExtension[2tc-m7]");

	[openDialog beginSheetModalForWindow:[NSApp keyWindow] completionHandler:^(NSInteger returnCode) {
		if (returnCode != NSModalResponseOK) {
			return;
		}

		[openDialog orderOut:nil];

		NSURL *pathURL = openDialog.URL;

		TPI_ChatFilter *filter = [[TPI_ChatFilter alloc] initWithContentsOfURL:pathURL];

		if (filter == nil) {
			[TDCAlert modalAlertWithMessage:@""
									  title:TPILocalizedString(@"TPI_ChatFilterExtension[eqr-7t]")
							  defaultButton:TPILocalizedString(@"TPI_ChatFilterExtension[ybz-7i]")
							alternateButton:nil];

			return;
		}

		[self editFilter:filter];
	}];
}

- (void)presentFilterAddMenu:(id)sender
{
	[self.filterAddMenu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, 0) inView:sender];
}

#pragma mark -
#pragma mark Table View Delegate

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pasteboard
{
	NSData *draggedData = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];

	[pasteboard declareTypes:@[_filterTableDragToken] owner:self];

	[pasteboard setData:draggedData forType:_filterTableDragToken];

	return YES;
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
	return NSDragOperationGeneric;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation
{
	NSPasteboard *pasteboard = [info draggingPasteboard];

	NSData *draggedData = [pasteboard dataForType:_filterTableDragToken];

	NSIndexSet *draggedRowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:draggedData];

	NSUInteger draggedRowIndex = draggedRowIndexes.firstIndex;

	[self.filterArrayController moveObjectAtArrangedObjectIndex:draggedRowIndex toIndex:row];

	[self saveFilters];

	return YES;
}

@end

NS_ASSUME_NONNULL_END
