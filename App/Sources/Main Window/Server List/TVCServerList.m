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

#import "NSViewHelperPrivate.h"
#import "TXMasterController.h"
#import "TXMenuControllerPrivate.h"
#import "TVCMainWindowPrivate.h"
#import "TPCPreferencesLocal.h"
#import "TVCServerListAppearancePrivate.h"
#import "TVCServerListCellPrivate.h"
#import "TVCServerListPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const TVCServerListDragType = @"TVCServerListDragType";

@interface TVCServerList ()
@property (nonatomic, strong, readwrite) TVCServerListAppearance *userInterfaceObjects;
@property (nonatomic, weak, readwrite) IBOutlet NSVisualEffectView *visualEffectView;
@property (nonatomic, assign, readwrite) BOOL leftMouseIsDownInView;
@end

@implementation TVCServerList

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];

	TVCMainWindow *mainWindow = self.mainWindow;

	if (mainWindow == nil) {
		[RZNotificationCenter() removeObserver:self];

		return;
	}

	[RZNotificationCenter() addObserver:self
							   selector:@selector(windowDidBecomeKey:)
								   name:NSWindowDidBecomeKeyNotification
								 object:mainWindow];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(windowDidResignKey:)
								   name:NSWindowDidResignKeyNotification
								 object:mainWindow];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(mainWindowRequiresRedraw:)
								   name:TVCMainWindowRedrawSubviewsNotification
								 object:mainWindow];
}

#pragma mark -
#pragma mark Additions/Removal

- (void)addItemToList:(NSUInteger)rowIndex inParent:(nullable id)parent
{
	[self insertItemsAtIndexes:[NSIndexSet indexSetWithIndex:rowIndex]
					  inParent:parent
				 withAnimation:(NSTableViewAnimationEffectFade | NSTableViewAnimationSlideRight)];

	if (parent) {
		[self reloadItem:parent];
	}
}

- (void)removeItemFromList:(id)object
{
	NSParameterAssert(object != nil);

	NSInteger rowIndex = [self rowForItem:object];

	NSAssert((rowIndex >= 0),
		@"Object does not exist on outline view");

	id parentItem = [self parentForItem:object];

	if (parentItem) {
		NSArray *childrenItems = [self itemsFromParentGroup:parentItem];

		rowIndex = [childrenItems indexOfObject:object];
	} else {
		NSArray *groupItems = self.groupItems;

		rowIndex = [groupItems indexOfObject:object];
	}

	NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:rowIndex];

	[self removeItemsAtIndexes:indexSet
					  inParent:parentItem
				 withAnimation:(NSTableViewAnimationEffectFade | NSTableViewAnimationSlideLeft)];

	if (parentItem) {
		[self reloadItem:parentItem];
	}
}

- (void)moveItemAtIndex:(NSInteger)fromIndex inParent:(nullable id)oldParent toIndex:(NSInteger)toIndex inParent:(nullable id)newParent
{
	if (fromIndex < toIndex) {
		[super moveItemAtIndex:fromIndex inParent:oldParent toIndex:(toIndex - 1) inParent:newParent];
	} else {
		[super moveItemAtIndex:fromIndex inParent:oldParent toIndex:toIndex inParent:newParent];
	}
}

#pragma mark -
#pragma mark Drawing Updates

- (void)refreshAllDrawings
{
	[self refreshAllDrawings:NO];
}

- (void)refreshAllDrawings:(BOOL)skipOcclusionCheck
{
	for (NSUInteger i = 0; i < self.numberOfRows; i++) {
		[self refreshDrawingForRow:i skipOcclusionCheck:skipOcclusionCheck];
	}
}

- (void)refreshDrawingForRows:(NSIndexSet *)rowIndexes
{
	[self refreshDrawingForRows:rowIndexes skipOcclusionCheck:NO];
}

- (void)refreshDrawingForRows:(NSIndexSet *)rowIndexes skipOcclusionCheck:(BOOL)skipOcclusionCheck
{
	NSParameterAssert(rowIndexes != nil);

	[rowIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		[self refreshDrawingForRow:index skipOcclusionCheck:skipOcclusionCheck];
	}];
}

- (void)refreshDrawingForRow:(NSInteger)rowIndex
{
	[self refreshDrawingForRow:rowIndex skipOcclusionCheck:NO];
}

- (void)refreshDrawingForRow:(NSInteger)rowIndex skipOcclusionCheck:(BOOL)skipOcclusionCheck
{
	if (rowIndex < 0) {
		return;
	}

	if (skipOcclusionCheck == NO && self.mainWindow.occluded) {
		return;
	}

	__kindof TVCServerListCell *rowView = [self viewAtColumn:0 row:rowIndex makeIfNecessary:NO];

	rowView.needsDisplay = YES;
}

- (void)refreshDrawingForItem:(IRCTreeItem *)cellItem
{
	[self refreshDrawingForItem:cellItem skipOcclusionCheck:NO];
}

- (void)refreshDrawingForItem:(IRCTreeItem *)cellItem skipOcclusionCheck:(BOOL)skipOcclusionCheck
{
	NSParameterAssert(cellItem != nil);

	NSInteger rowIndex = [self rowForItem:cellItem];

	[self refreshDrawingForRow:rowIndex skipOcclusionCheck:skipOcclusionCheck];
}

- (void)refreshMessageCountForItem:(IRCTreeItem *)cellItem
{
	[self refreshMessageCountForItem:cellItem skipOcclusionCheck:NO];
}

- (void)refreshMessageCountForItem:(IRCTreeItem *)cellItem skipOcclusionCheck:(BOOL)skipOcclusionCheck
{
	NSParameterAssert(cellItem != nil);

	NSInteger rowIndex = [self rowForItem:cellItem];

	[self refreshMessageCountForRow:rowIndex skipOcclusionCheck:skipOcclusionCheck];
}

- (void)refreshAllUnreadMessageCountBadges
{
	[self refreshAllUnreadMessageCountBadges:NO];
}

- (void)refreshAllUnreadMessageCountBadges:(BOOL)skipOcclusionCheck
{
	for (NSUInteger i = 0; i < self.numberOfRows; i++) {
		[self refreshMessageCountForRow:i skipOcclusionCheck:skipOcclusionCheck];
	}
}

- (void)refreshMessageCountForRows:(NSIndexSet *)rowIndexes
{
	[self refreshMessageCountForRows:rowIndexes skipOcclusionCheck:NO];
}

- (void)refreshMessageCountForRows:(NSIndexSet *)rowIndexes skipOcclusionCheck:(BOOL)skipOcclusionCheck
{
	NSParameterAssert(rowIndexes != nil);

	[rowIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		[self refreshMessageCountForRow:index skipOcclusionCheck:skipOcclusionCheck];
	}];
}

- (void)refreshMessageCountForRow:(NSInteger)rowIndex
{
	[self refreshMessageCountForRow:rowIndex skipOcclusionCheck:NO];
}

- (void)refreshMessageCountForRow:(NSInteger)rowIndex skipOcclusionCheck:(BOOL)skipOcclusionCheck
{
	if (rowIndex < 0) {
		return;
	}

	if (skipOcclusionCheck == NO && self.mainWindow.occluded) {
		return;
	}

	__kindof TVCServerListCell *rowView = [self viewAtColumn:0 row:rowIndex makeIfNecessary:NO];

	BOOL isChildItem = [rowView isKindOfClass:[TVCServerListCellChildItem class]];

	if (isChildItem) {
		[rowView populateMessageCountBadge];
	}
}

- (BOOL)allowsVibrancy
{
	return YES;
}

- (void)updateVibrancyWithAppearance:(TVCServerListAppearance *)appearance
{
	NSParameterAssert(appearance != nil);

	NSVisualEffectView *visualEffectView = self.visualEffectView;

	if ([TPCPreferences disableSidebarTranslucency]) {
		visualEffectView.state = NSVisualEffectStateInactive;
	} else {
		visualEffectView.state = NSVisualEffectStateFollowsWindowActiveState;
	}

	visualEffectView.material = NSVisualEffectMaterialSidebar;
}

- (void)applicationAppearanceChanged
{
	TVCServerListAppearance *appearance = self.mainWindow.userInterfaceObjects.serverList;

	[self _updateAppearance:appearance];

	[self invalidateBackgroundForSelection];

	[self refreshAllDrawings:YES];
}

- (void)systemAppearanceChanged
{
//	[self invalidateBackgroundForSelection];
}

- (void)_updateAppearance:(TVCServerListAppearance *)appearance
{
	NSParameterAssert(appearance != nil);

	/* We assign a strong reference to these instead of returning the original
	 value every time so that there are no race conditions for when it changes. */
	self.userInterfaceObjects = appearance;

	[self updateVibrancyWithAppearance:appearance];

	if (appearance.isDarkAppearance) {
		self.enclosingScrollView.scrollerKnobStyle = NSScrollerKnobStyleLight;
	} else {
		self.enclosingScrollView.scrollerKnobStyle = NSScrollerKnobStyleDark;
	}

	self.needsDisplay = YES;
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	[self windowKeyStateChanged:notification];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
	[self windowKeyStateChanged:notification];
}

- (void)windowKeyStateChanged:(NSNotification *)notification
{
	[self respondToRequiresRedraw];
}

- (void)mainWindowRequiresRedraw:(NSNotification *)notification
{
	[self respondToRequiresRedraw];
}

- (void)respondToRequiresRedraw
{
	[self refreshAllDrawings:YES];
}

#pragma mark -
#pragma mark Events

- (nullable NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	NSInteger rowBeneathMouse = self.rowBeneathMouse;

	if (rowBeneathMouse >= 0) {
		if (rowBeneathMouse != self.selectedRow || self.numberOfSelectedRows > 1) {
			[self selectItemAtIndex:rowBeneathMouse];
		}
	} else {
		return menuController().serverListNoSelectionMenu;
	}

	return self.menu;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	self.leftMouseIsDownInView = YES;

	[super mouseDown:theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent
{
	self.leftMouseIsDownInView = NO;

	[super mouseUp:theEvent];
}

- (void)keyDown:(NSEvent *)e
{
	if (self.keyDelegate == nil) {
		return;
	}

	switch (e.keyCode) {
		case 125: // down arrow
		case 126: // up arrow
		case 123: // left arrow
		case 124: // right arrow
		case 116: // page up
		case 121: // page down
		{
			break;
		}
		default:
		{
			[self.keyDelegate serverListKeyDown:e];

			break;
		}
	}
}

@end

NS_ASSUME_NONNULL_END
