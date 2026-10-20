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

#import "TVCBasicTableView.h"
#import "TVCValidatedTextField.h"
#import "TDCServerPropertiesPanePrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _tableDragToken		@"com.textualapp.server-properties.row" // A UTI: drags of NSPasteboardItems need one

@implementation TDCServerPropertiesPane

- (void)prepareInitialState
{

}

- (void)loadFromConfig:(IRCClientConfig *)config
{

}

- (void)saveToConfig:(IRCClientConfigMutable *)config
{

}

- (nullable NSControl *)firstInvalidField
{
	return nil;
}

- (BOOL)hasInvalidField
{
	return (self.firstInvalidField != nil);
}

- (void)showInvalidField
{
	id field = self.firstInvalidField;

	if (field == nil) {
		return;
	}

	/* Give navigation time to settle before trying to attach popover */
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[field showValidationErrorPopover];
	});
}

- (void)closeChildSheets
{

}

- (void)tearDown
{

}

@end

#pragma mark -

@implementation TDCServerPropertiesListPane

- (void)prepareInitialState
{
	self.table.doubleAction = @selector(tableViewDoubleClicked:);
	self.table.target = self;

	[self.table registerForDraggedTypes:@[_tableDragToken]];
}

- (void)loadFromConfig:(IRCClientConfig *)config
{
	[self updateButtons];
}

- (NSArray *)items
{
	return self.arrayController.arrangedObjects;
}

- (void)updateButtons
{
	BOOL rowSelected = (self.table.selectedRow >= 0);

	self.editButton.enabled = rowSelected;
	self.deleteButton.enabled = rowSelected;
}

#pragma mark -
#pragma mark Actions

- (void)addItem:(nullable id)sender
{
	[self showSheetForItem:nil];
}

- (void)editItem:(nullable id)sender
{
	NSInteger selectedRow = self.table.selectedRow;

	if (selectedRow < 0) {
		return;
	}

	[self showSheetForItem:self.items[selectedRow]];
}

- (void)deleteItem:(nullable id)sender
{
	NSInteger selectedRow = self.table.selectedRow;

	if (selectedRow < 0) {
		return;
	}

	[self removeItem:self.items[selectedRow]];

	NSUInteger listCount = self.items.count;

	if (listCount > 0) {
		if (listCount <= selectedRow) {
			[self.table selectItemAtIndex:(listCount - 1)];
		} else {
			[self.table selectItemAtIndex:selectedRow];
		}
	}
}

- (void)tableViewDoubleClicked:(nullable id)sender
{
	[self editItem:sender];
}

#pragma mark -
#pragma mark Items

- (void)showSheetForItem:(nullable id)item
{
	[self doesNotRecognizeSelector:_cmd];
}

- (nullable id)valueForColumn:(NSString *)columnId ofItem:(id)item
{
	return nil;
}

- (void)setValue:(nullable id)value forColumn:(NSString *)columnId ofItem:(id)item
{

}

- (void)addOrReplaceItem:(id)item
{
	NSParameterAssert(item != nil);

	NSString *uniqueIdentifier = [item uniqueIdentifier];

	NSUInteger itemIndex =
	[self.items indexOfObjectPassingTest:^BOOL(id object, NSUInteger index, BOOL *stop) {
		return [[object uniqueIdentifier] isEqualToString:uniqueIdentifier];
	}];

	if (itemIndex == NSNotFound) {
		[self.arrayController addObject:item];
	} else {
		[self.arrayController replaceObjectAtArrangedObjectIndex:itemIndex withObject:item];
	}
}

- (void)removeItem:(id)item
{
	NSParameterAssert(item != nil);

	NSUInteger itemIndex = [self.items indexOfObjectIdenticalTo:item];

	if (itemIndex == NSNotFound) {
		return;
	}

	[self.arrayController removeObjectAtArrangedObjectIndex:itemIndex];
}

- (BOOL)moveItemAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
	[self.arrayController moveObjectAtArrangedObjectIndex:fromIndex toIndex:toIndex];

	return YES;
}

#pragma mark -
#pragma mark Child Sheet

- (void)closeChildSheets
{
	[self.childSheet close];
}

#pragma mark -
#pragma mark Table

- (nullable id)tableView:(NSTableView *)tableView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	return [self valueForColumn:tableColumn.identifier ofItem:self.items[row]];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(nullable id)object forTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	[self setValue:object forColumn:tableColumn.identifier ofItem:self.items[row]];
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
	return YES;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[self updateButtons];
}

/* The dragged row's index, read back on drop */
- (nullable id <NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row
{
	NSPasteboardItem *item = [NSPasteboardItem new];

	[item setString:@(row).stringValue forType:_tableDragToken];

	return item;
}

/* Rows move within their own table only: a row dragged from one of the
 three tables was moved by its number in another */
- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
	if (info.draggingSource != tableView) {
		return NSDragOperationNone;
	}

	if (dropOperation == NSTableViewDropOn) {
		[tableView setDropRow:row dropOperation:NSTableViewDropAbove];
	}

	return NSDragOperationGeneric;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation
{
	if (info.draggingSource != tableView) {
		return NO;
	}

	NSString *draggedRow = [info.draggingPasteboard stringForType:_tableDragToken];

	NSUInteger draggedRowIndex = ((draggedRow.length > 0) ? (NSUInteger)draggedRow.integerValue : NSNotFound);

	NSInteger numberOfRows = tableView.numberOfRows;

	if (draggedRowIndex == NSNotFound || draggedRowIndex >= numberOfRows || row < 0 || row > numberOfRows) {
		return NO;
	}

	return [self moveItemAtIndex:draggedRowIndex toIndex:row];
}

#pragma mark -

- (void)tearDown
{
	self.table.delegate = nil;
	self.table.dataSource = nil;

	[self.table unregisterDraggedTypes];
}

@end

NS_ASSUME_NONNULL_END
