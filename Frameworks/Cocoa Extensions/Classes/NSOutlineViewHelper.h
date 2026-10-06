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

NS_ASSUME_NONNULL_BEGIN

@interface NSOutlineView ()
@property (nonatomic, assign) BOOL enableCustomReloadItemLogic;
@end

@interface NSOutlineView (CSOutlineViewHelper)
@property (readonly) NSArray *selectedObjects;

@property (readonly, copy) NSArray *groupItems;
- (BOOL)isGroupItem:(id)item;

- (nullable NSArray *)itemsInGroup:(id)groupItem;
- (nullable NSArray *)itemsFromParentGroup:(id)item;

- (nullable NSIndexSet *)indexesOfItemsInGroup:(id)groupItem;

- (nullable id)parentForItemAtRow:(NSUInteger)row;
@end

@interface NSTableView (CSTableViewHelper)
@property (readonly) NSInteger rowBeneathMouse;

- (void)enumerateSelectedRowViewsUsingBlock:(void (NS_NOESCAPE ^)(__kindof NSTableRowView *rowView, NSInteger row, BOOL * _Nullable stop))handler;

- (void)invalidateBackgroundForSelection; // See -[NSTableRowView invalidateSelectionBackground]
@property (readonly) BOOL invalidatingBackgroundForSelection;

- (void)selectItemAtIndex:(NSUInteger)index;

- (NSIndexSet *)selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes
						   maximumNumberOfSelections:(NSUInteger)maximumNumberOfSelections;

- (void)selectRowIndexes:(NSIndexSet *)indexes
	byExtendingSelection:(BOOL)extend
	   scrollToSelection:(BOOL)scroll;
@end

@interface NSTableRowView (CSTableRowViewHelper)
@property (readonly, nullable) __kindof NSTableView *parentTableView;

@property (readonly) BOOL invalidatingBackgroundForSelection;
@end

NS_ASSUME_NONNULL_END
