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

#import "NSObjectHelperPrivate.h"
#import "NSViewHelper.h"
#import "TVCContentNavigationOutlineViewPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCContentNavigationOutlineView () <NSOutlineViewDelegate, NSOutlineViewDataSource>
@property (nonatomic, strong) IBOutlet NSView *contentView;
@property (nonatomic, weak, nullable, readwrite) TVCContentNavigationOutlineViewItem *selectedItem;
@property (nonatomic, weak, nullable) TVCContentNavigationOutlineViewItem *lastSelection;
@property (readonly, nullable) TVCContentNavigationOutlineViewItem *parentOfLastSelection;
@end

@implementation TVCContentNavigationOutlineView

#pragma mark -
#pragma mark Basic Class

- (void)awakeFromNib
{
	[super awakeFromNib];

	self.dataSource = (id)self;
	self.delegate = (id)self;

	self.doubleAction = @selector(outlineViewDoubleClicked:);
}

- (void)setNavigationTreeMatrix:(NSArray<TVCContentNavigationOutlineViewItem *> *)navigationTreeMatrix
{
	NSParameterAssert(navigationTreeMatrix != nil);

	if (self->_navigationTreeMatrix != navigationTreeMatrix) {
		self->_navigationTreeMatrix = navigationTreeMatrix;

		[self resetOutlineView];
	}
}

- (void)resetOutlineView
{
	self.lastSelection = nil;

	self.selectedItem = nil;

	[self reloadData];
}

- (void)navigateToItemWithIdentifier:(NSUInteger)identifier
{
	for (TVCContentNavigationOutlineViewItem *groupItem in self.groupItems) {
		if (groupItem.identifier == identifier) {
			[self selectItemAtIndex:[self rowForItem:groupItem]];

			return;
		}

		for (TVCContentNavigationOutlineViewItem *childItem in groupItem.children) {
			if (childItem.identifier == identifier) {
				[self selectItemAtIndex:[self rowForItem:childItem]];

				return;
			}
		} // children
	} // parents
}

- (nullable TVCContentNavigationOutlineViewItem *)parentOfLastSelection
{
	TVCContentNavigationOutlineViewItem *selectedItem = self.lastSelection;

	if (selectedItem == nil) {
		return nil;
	}

	return [self parentForItem:selectedItem];
}

#pragma mark -
#pragma mark Collapse/Expand Logic

- (void)outlineViewDoubleClicked:(id)sender
{
	if (self.expandParentOnDoubleClick == NO) {
		return;
	}

	NSInteger clickedRow = self.clickedRow;

	if (clickedRow < 0) {
		return;
	}

	TVCContentNavigationOutlineViewItem *itemAtRow = [self itemAtRow:clickedRow];

	if (itemAtRow.isGroupItem == NO) {
		return;
	}

	[self expandItem:itemAtRow];
}

#pragma mark -
#pragma mark NSOutlineViewDelegate Delegates

- (NSInteger)outlineView:(NSOutlineView *)sender numberOfChildrenOfItem:(nullable TVCContentNavigationOutlineViewItem *)item
{
	if (item.isGroupItem) {
		return item.children.count;
	}

	return self.navigationTreeMatrix.count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable TVCContentNavigationOutlineViewItem *)item
{
	if (item.isGroupItem) {
		return item.children[index];
	}

	return self.navigationTreeMatrix[index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(TVCContentNavigationOutlineViewItem *)item
{
	return YES;
}

- (BOOL)outlineView:(NSOutlineView *)sender isItemExpandable:(TVCContentNavigationOutlineViewItem *)item
{
	return item.isGroupItem;
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
	TVCContentNavigationOutlineViewItem *parentItem = self.parentOfLastSelection;

	TVCContentNavigationOutlineViewItem *itemExpanded = notification.userInfo[@"NSObject"];

	if (parentItem == nil || parentItem != itemExpanded) {
		return;
	}

	NSInteger childIndex = [self rowForItem:self.lastSelection];

	if (childIndex >= 0) {
		[self selectItemAtIndex:childIndex];
	}
}

- (nullable id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn byItem:(nullable TVCContentNavigationOutlineViewItem *)item
{
	return item.label;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(TVCContentNavigationOutlineViewItem *)item
{
	return (item.view != nil);
}

- (nullable id)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(nullable NSTableColumn *)tableColumn item:(id)item
{
	NSTableCellView *newView = [outlineView makeViewWithIdentifier:@"navEntry" owner:self];

	return newView;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	NSInteger selectedRow = self.selectedRow;

	if (selectedRow < 0) {
		/* We do not reset -lastSelection because that is used
		 to restore selection to item when the group item that
		 was collapsed is expanded. */
		self.selectedItem = nil;

		return;
	}

	TVCContentNavigationOutlineViewItem *item = [self itemAtRow:selectedRow];

	self.selectedItem = item;

	self.lastSelection = item;

	[self presentView:item.view];

	id firstResponder = item.firstResponder;

	if (firstResponder) {
		[self.window makeFirstResponder:firstResponder];
	}
}

- (void)presentView:(NSView *)newView
{
	[self.contentView replaceFirstSubview:newView];
}

@end

#pragma mark -
#pragma mark Item Parent

@interface TVCContentNavigationOutlineViewItem ()
@property (nonatomic, copy, readwrite) NSString *label;
@property (nonatomic, assign, readwrite) NSUInteger identifier;
@property (nonatomic, weak, nullable, readwrite) NSView *view;
@property (nonatomic, weak, nullable, readwrite) NSControl *firstResponder;
@property (nonatomic, copy, nullable, readwrite) NSArray<TVCContentNavigationOutlineViewItem *> *children;
@end

@implementation TVCContentNavigationOutlineViewItem

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithLabel:(NSString *)label identifier:(NSUInteger)identifier view:(NSView *)view firstResponder:(nullable NSControl *)firstResponder
{
	NSParameterAssert(label != nil);
	NSParameterAssert(view != nil);

	return [self initWithLabel:label identifier:identifier view:view firstResponder:firstResponder children:nil];
}

- (instancetype)initWithLabel:(NSString *)label identifier:(NSUInteger)identifier view:(nullable NSView *)view firstResponder:(nullable NSControl *)firstResponder children:(nullable NSArray<TVCContentNavigationOutlineViewItem *> *)children
{
	NSParameterAssert(label != nil);
	NSParameterAssert(view != nil || children != nil);

	if ((self = [super init])) {
		self.label = label;
		self.identifier = identifier;
		self.view = view;
		self.firstResponder = firstResponder;
		self.children = children;

		return self;
	}

	return nil;
}

- (BOOL)isGroupItem
{
	return (self.children != nil);
}

@end

NS_ASSUME_NONNULL_END
