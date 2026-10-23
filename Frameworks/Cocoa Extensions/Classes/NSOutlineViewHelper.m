/* *********************************************************************
 *
 *         Copyright (c) 2015 - 2020 Codeux Software, LLC
 *     Please see ACKNOWLEDGEMENT for additional information.
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
 *  * Neither the name of "Codeux Software, LLC", nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
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

#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@implementation NSTableView (CSTableViewHelper)

- (void)selectItemAtIndex:(NSUInteger)index
{
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
	
	[self scrollRowToVisible:index];
}

- (void)enumerateSelectedRowViewsUsingBlock:(void (NS_NOESCAPE ^)(__kindof NSTableRowView *rowView, NSInteger row, BOOL * _Nullable stop))handler
{
	NSIndexSet *selectedRows = self.selectedRowIndexes;

	[selectedRows enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		NSTableRowView *rowView = [self rowViewAtRow:index makeIfNecessary:NO];

		handler(rowView, index, stop);
	}];
}

- (void)invalidateBackgroundForSelection
{
	[self setInvalidatingBackgroundForSelection:YES];

	NSIndexSet *selectedRows = self.selectedRowIndexes;

	BOOL allowsEmptySelection = self.allowsEmptySelection;

	self.allowsEmptySelection = YES;

	[self deselectAll:nil];

	[self selectRowIndexes:selectedRows byExtendingSelection:NO];

	self.allowsEmptySelection = allowsEmptySelection;

	[self setInvalidatingBackgroundForSelection:NO];
}

- (BOOL)invalidatingBackgroundForSelection
{
	NSNumber *customPositioning = objc_getAssociatedObject(self, @selector(invalidatingBackgroundForSelection));

	if (customPositioning) {
		return customPositioning.boolValue;
	}

	return NO;
}

- (void)setInvalidatingBackgroundForSelection:(BOOL)invalidatingBackgroundForSelection
{
	NSNumber *valueToAssign = ((invalidatingBackgroundForSelection) ? @(YES) : nil);

	objc_setAssociatedObject(self, @selector(invalidatingBackgroundForSelection), valueToAssign, OBJC_ASSOCIATION_COPY);
}

- (NSInteger)rowBeneathMouse
{
	NSPoint ml = self.window.mouseLocationOutsideOfEventStream;

	NSPoint pt = [self convertPoint:ml fromView:nil];

	return [self rowAtPoint:pt];
}

- (NSIndexSet *)selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes maximumNumberOfSelections:(NSUInteger)maximumNumberOfSelections
{
	NSParameterAssert(proposedSelectionIndexes != nil);
	NSParameterAssert(maximumNumberOfSelections > 0);

	if (proposedSelectionIndexes.count <= maximumNumberOfSelections) {
		return proposedSelectionIndexes;
	}

	/* If the user has already selected the maximum, then return the current index set.
	 This prevents the user clicking one item up and having the entire selection shift
	 because the following logic works from highest to lowest. */
	if (self.numberOfSelectedRows == maximumNumberOfSelections) {
		return self.selectedRowIndexes;
	}

	return [proposedSelectionIndexes subsetWithMaximumIndexes:maximumNumberOfSelections];
}

- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend scrollToSelection:(BOOL)scroll
{
	NSParameterAssert(indexes != nil);

	[self selectRowIndexes:indexes byExtendingSelection:extend];

	if (scroll && indexes.count > 0) {
		[self scrollRowToVisible:indexes.firstIndex];
	}
}

@end

#pragma mark -

@implementation NSTableRowView (CSTableRowViewHelper)

- (__kindof NSTableView * _Nullable)parentTableView
{
	NSView *superview = self.superview;

	if ([superview isKindOfClass:[NSTableView class]] == NO) {
		return nil;
	}

	return (NSTableView *)superview;
}

- (BOOL)invalidatingBackgroundForSelection
{
	return self.parentTableView.invalidatingBackgroundForSelection;
}

@end

#pragma mark -

@implementation NSOutlineView (CSOutlineViewHelper)

- (NSArray *)selectedObjects
{
	NSIndexSet *selectedRows = self.selectedRowIndexes;

	NSMutableArray *objects = [NSMutableArray arrayWithCapacity:selectedRows.count];

	[selectedRows enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		id object = [self itemAtRow:index];

		[objects addObject:object];
	}];

	return [objects copy];
}

- (BOOL)isGroupItem:(id)item
{
	NSParameterAssert(item != nil);

	return ([self levelForItem:item] == 0);
}

- (NSArray *)groupItems
{
	NSMutableArray *groups = [NSMutableArray array];
	
	for (NSUInteger i = 0; i < self.numberOfRows; i++) {
		if ([self levelForRow:i] == 0) {
			id curRow = [self itemAtRow:i];

			[groups addObject:curRow];
		}
	}
	
	return groups;
}

- (nullable NSArray *)itemsFromParentGroup:(id)item
{
	return [self itemsInGroup:item];
}

- (nullable NSArray *)itemsInGroup:(id)groupItem
{
	NSParameterAssert(groupItem != nil);

	if ([self isGroupItem:groupItem] == NO) {
		NSArray *parentItem = [self parentForItem:groupItem];

		if (parentItem) {
			groupItem = parentItem;
		} else {
			return nil;
		}
	}

	NSMutableArray *allRows = [NSMutableArray array];
	
	for (NSUInteger i = 0; i < self.numberOfRows; i++) {
		id itemAtRow = [self itemAtRow:i];

		id parentItem = [self parentForItem:itemAtRow];

		if (parentItem == groupItem) {
			[allRows addObject:itemAtRow];
		}
	}
	
	return allRows;
}

- (nullable NSIndexSet *)indexesOfItemsInGroup:(id)groupItem
{
	NSArray *itemsInGroup = [self itemsInGroup:groupItem];

	if (itemsInGroup == nil) {
		return nil;
	}

	id itemFirst = itemsInGroup.firstObject;
	id itemLast = itemsInGroup.lastObject;

	if (itemFirst == nil) {
		return nil;
	}

	NSInteger itemFirstIndex = [self rowForItem:itemFirst];
	NSInteger itemLastIndex = [self rowForItem:itemLast];

	return [NSIndexSet indexSetWithIndexesInRange:
			NSMakeRange(itemFirstIndex, (itemLastIndex - itemFirstIndex + 1))];
}

- (nullable id)parentForItemAtRow:(NSUInteger)row
{
	id itemAtRow = [self itemAtRow:row];

	return [self parentForItem:itemAtRow];
}

@end

NS_ASSUME_NONNULL_END
