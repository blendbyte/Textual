/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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

#import "IRCServer.h"
#import "TVCBasicTableView.h"
#import "TDCServerEndpointListSheetPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _endpointEntryTableDragToken		@"TDCServerEndpointListSheetEntryTableDragToken"

@interface TDCServerEndpointListSheet ()
@property (nonatomic, strong) IBOutlet NSArrayController *entryTableController;
@property (nonatomic, weak) IBOutlet TVCBasicTableView *entryTable;
@property (nonatomic, weak) IBOutlet NSSegmentedControl *entryActionsSegmentedControl;

- (IBAction)entryActionsSegmentedControlClicked:(id)sender;
@end

@implementation TDCServerEndpointListSheet

- (instancetype)initWithWindow:(nullable NSWindow *)window
{
	if ((self = [super initWithWindow:window])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCServerEndpointListSheet" owner:self topLevelObjects:nil];

	[self.entryTable registerForDraggedTypes:@[_endpointEntryTableDragToken]];

	[self.entryTableController addObserver:self
								forKeyPath:@"canRemove"
								   options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
								   context:NULL];
}

- (void)startWithServerList:(NSArray<IRCServer *> *)serverList
{
	NSParameterAssert(serverList != nil);

	for (IRCServer *server in serverList) {
		[self.entryTableController addObject:[server mutableCopy]];
	}

	[self startSheet];
}

- (void)ok:(id)sender
{
	NSArray *serverListIn = self.entryTableController.arrangedObjects;

	NSMutableArray<IRCServer *> *serverListOut =
	[[NSMutableArray alloc] initWithCapacity:serverListIn.count];

	for (IRCServerMutable *server in serverListIn) {
		/* New entries that are blank do not perform validation
		 because nothing technically has changed. Instead of 
		 doing some complex workaround, let's just ditch 
		 objects with an empty server address. */
		if (server.serverAddress.length == 0) {
			continue;
		}

		[serverListOut addObject:[server copy]];
	}

	if ([self.delegate respondsToSelector:@selector(serverEndpointListSheet:onOk:)]) {
		[self.delegate serverEndpointListSheet:self onOk:[serverListOut copy]];
	}

	[super ok:sender];
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSString *, id> *)change context:(nullable void *)context
{
	if ([keyPath isEqualToString:@"canRemove"]) {
		[self updateEntryActionsSegmentedControlEnabledState];
	}
}

#pragma mark -
#pragma mark Entry Management

- (void)updateEntryActionsSegmentedControlEnabledState
{
	[self.entryActionsSegmentedControl setEnabled:self.entryTableController.canRemove forSegment:1];
}

- (void)entryActionsSegmentedControlClicked:(id)sender
{
	NSInteger selectedSegment = [sender selectedSegment];

	if (selectedSegment == 0) {
		[self addEntry];
	} else if (selectedSegment == 1) {
		[self removeSelectedEntry];
	}
}

- (void)addEntry
{
	IRCServerMutable *newEntry = [IRCServerMutable new];

	[self.entryTableController addObject:newEntry];

	/* Edit column next pass on the main thread to allow the
	 -addObject to register properly. */
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		NSTableView *tableView = self.entryTable;

		NSInteger rowSelection = (tableView.numberOfRows - 1);

		[tableView scrollRowToVisible:rowSelection];

		[tableView editColumn:0 row:rowSelection withEvent:nil select:YES];
	});
}

- (void)removeSelectedEntry
{
	NSIndexSet *selectedRows = self.entryTable.selectedRowIndexes;

	[self.entryTableController removeObjectsAtArrangedObjectIndexes:selectedRows];
}

#pragma mark -
#pragma mark Table View Delegate

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pasteboard
{
	NSData *draggedData = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];

	[pasteboard declareTypes:@[_endpointEntryTableDragToken] owner:self];

	[pasteboard setData:draggedData forType:_endpointEntryTableDragToken];

	return YES;
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
	return NSDragOperationGeneric;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation
{
	NSPasteboard *pasteboard = [info draggingPasteboard];

	NSData *draggedData = [pasteboard dataForType:_endpointEntryTableDragToken];

	NSIndexSet *draggedRowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:draggedData];

	NSUInteger draggedRowIndex = draggedRowIndexes.firstIndex;

	[self.entryTableController moveObjectAtArrangedObjectIndex:draggedRowIndex toIndex:row];

	return YES;
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	[self.entryTableController removeObserver:self forKeyPath:@"canRemove"];

	if ([self.delegate respondsToSelector:@selector(serverEndpointListSheetWillClose:)]) {
		[self.delegate serverEndpointListSheetWillClose:self];
	}
}

@end

NS_ASSUME_NONNULL_END
