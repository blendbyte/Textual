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

#import "TXMasterController.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "IRCHighlightLogEntryPrivate.h"
#import "TVCBasicTableView.h"
#import "TVCMainWindow.h"
#import "TDCServerHighlightListSheetPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _renderedMessageTextFieldLeftRightPadding		2.0

@interface TDCServerHighlightListSheet ()
@property (nonatomic, strong, readwrite) IRCClient *client;
@property (nonatomic, copy, readwrite) NSString *clientId;
@property (nonatomic, weak) IBOutlet NSTextField *headerTitleTextField;
@property (nonatomic, weak) IBOutlet TVCBasicTableView *highlightListTable;
@property (nonatomic, strong) IBOutlet NSArrayController *highlightListController;

- (IBAction)onClearList:(id)sender;
@end

@implementation TDCServerHighlightListSheet

- (instancetype)initWithClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if ((self = [super initWithWindow:nil])) {
		self.client = client;
		self.clientId = client.uniqueIdentifier;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCServerHighlightListSheet" owner:self topLevelObjects:nil];

	self.highlightListTable.doubleAction = @selector(highlightDoubleClicked:);

	self.highlightListTable.pasteboardDelegate = self;

	self.highlightListTable.sortDescriptors = @[
		[NSSortDescriptor sortDescriptorWithKey:@"timeLogged" ascending:NO selector:@selector(compare:)],
		[NSSortDescriptor sortDescriptorWithKey:@"channelName" ascending:NO selector:@selector(caseInsensitiveCompare:)]
	];

	NSString *headerTitle = [NSString stringWithFormat:self.headerTitleTextField.stringValue, self.client.networkNameAlt];

	self.headerTitleTextField.stringValue = headerTitle;

	NSArray *cachedHighlights = self.client.cachedHighlights;

	if (cachedHighlights) {
		[self addEntry:cachedHighlights];
	}
}

- (void)start
{
	[self startSheet];
}

- (void)addEntry:(id)newEntry
{
	NSParameterAssert(newEntry != nil);

	if ([newEntry isKindOfClass:[NSArray class]])
	{
		for (id entry in newEntry) {
			[self addEntry:entry];
		}
	}
	else if ([newEntry isKindOfClass:[IRCHighlightLogEntry class]])
	{
		if ([newEntry isKindOfClass:[IRCHighlightLogEntryMutable class]]) {
			newEntry = [newEntry copy];
		}

		[self.highlightListController addObject:newEntry];
	}
}

- (void)onClearList:(id)sender
{
	self.highlightListController.content = nil;

	[self.client clearCachedHighlights];
}

- (void)highlightDoubleClicked:(id)sender
{
	NSInteger row = self.highlightListTable.clickedRow;

	if (row < 0) {
		return;
	}

	IRCHighlightLogEntry *entryItem = self.highlightListController.arrangedObjects[row];

	IRCChannel *channel = entryItem.channel;

	if (channel == nil) {
		return;
	}

	TVCLogController *viewController = channel.viewController;

	[viewController jumpToLine:entryItem.lineNumber completionHandler:^(BOOL result) {
		if (result) {
			[mainWindow() select:channel];

			[self cancel:nil];
		}
	}];
}

- (void)copy:(id)sender
{
	NSIndexSet *selectedRows = self.highlightListTable.selectedRowIndexes;

	if (selectedRows.count == 0) {
		return;
	}

	NSMutableString *stringToCopy = [NSMutableString string];

	[selectedRows enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		IRCHighlightLogEntry *entryItem = self.highlightListController.arrangedObjects[index];

		[stringToCopy appendString:entryItem.description];

		if (index != selectedRows.lastIndex) {
			[stringToCopy appendString:@"\n"];
		}
	}];

	[RZPasteboard() setStringContent:stringToCopy];
}

#pragma mark -
#pragma mark NSTableView Delegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSTableCellView *result = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];

	return result;
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	self.highlightListTable.dataSource = nil;
	self.highlightListTable.delegate = nil;

	if ([self.delegate respondsToSelector:@selector(serverHighlightListSheetWillClose:)]) {
		[self.delegate serverHighlightListSheetWillClose:self];
	}
}

@end

NS_ASSUME_NONNULL_END
