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

#import "IRCUser.h"
#import "IRCChannelUser.h"
#import "IRCChannelMemberListControllerPrivate.h"
#import "NSViewHelperPrivate.h"
#import "TXMasterController.h"
#import "TXMenuControllerPrivate.h"
#import "TVCMainWindow.h"
#import "TPCPreferencesLocal.h"
#import "TVCMemberListCellPrivate.h"
#import "TVCMemberListAppearancePrivate.h"
#import "TVCMemberListUserInfoPopoverPrivate.h"
#import "TVCMemberListPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const TVCMemberListDragType = @"TVCMemberListDragType";

@interface TVCMemberList ()
@property (nonatomic, strong) id userPopoverTrackingArea;
@property (nonatomic, assign) BOOL userPopoverMouseIsInView;
@property (nonatomic, assign) BOOL userPopoverTimerIsActive;
@property (nonatomic, assign) NSPoint userPopoverLastKnownLocalPoint;
@property (nonatomic, assign) NSInteger lastRowShownUserInfoPopover;
@property (nonatomic, strong, readwrite) TVCMemberListAppearance *userInterfaceObjects;
@property (nonatomic, weak, readwrite) IBOutlet NSVisualEffectView *visualEffectView;
@property (nonatomic, strong, readwrite) IBOutlet TVCMemberListUserInfoPopover *memberListUserInfoPopover;
@property (nonatomic, strong, readwrite) IBOutlet IRCChannelMemberListController *contentController;
@end

@implementation TVCMemberList

- (void)awakeFromNib
{
	[super awakeFromNib];

	[self updateTrackingAreas];

	[self registerForDraggedTypes:@[NSFilenamesPboardType]];
}

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

	[RZNotificationCenter() addObserver:self
							   selector:@selector(scrollViewBoundsDidChangeNotification:)
								   name:NSViewBoundsDidChangeNotification
								 object:[self scrollViewContentView]];
}

#pragma mark -
#pragma mark Utilities

- (void)assignToChannel:(nullable IRCChannel *)channel
{
	[self.contentController assignToChannel:channel];
}

- (nullable id)itemAtRow:(NSInteger)row
{
	NSParameterAssert(row >= 0);

	NSArray *rows = self.contentController.arrangedObjects;

	if (row >= rows.count) {
		return nil;
	}

	return rows[row];
}

- (NSInteger)rowForItem:(nullable id)item
{
	if (item == nil) {
		return (-1);
	}

	NSArray *rows = self.contentController.arrangedObjects;

	NSInteger index = [rows indexOfObjectIdenticalTo:item];

	if (index == NSNotFound) {
		return (-1);
	}

	return index;
}

#pragma mark -
#pragma mark Mouse Tracking

- (void)updateTrackingAreas
{
	[super updateTrackingAreas];

	if (self.userPopoverTrackingArea) {
		[self removeTrackingArea:self.userPopoverTrackingArea];
	}

	self.userPopoverTrackingArea =
	[[NSTrackingArea alloc] initWithRect:self.frame
								 options:(NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInActiveApp)
								   owner:self
								userInfo:nil];

	[self addTrackingArea:self.userPopoverTrackingArea];
}

- (void)destroyUserInfoPopoverOnWindowKeyChange
{
	[self destroyUserInfoPopover]; // Destroy anything shown
}

- (void)destroyUserInfoPopover
{
	[self cancelPerformRequestsWithSelector:@selector(popDelayedUserInfoExpansionFrame) object:nil];

	self.lastRowShownUserInfoPopover = (-1);

	self.userPopoverMouseIsInView = NO;
	self.userPopoverTimerIsActive = NO;

	self.userPopoverLastKnownLocalPoint = NSZeroPoint;

	if (self.memberListUserInfoPopover.shown) {
		[self.memberListUserInfoPopover close];
	}
}

- (void)mouseEntered:(NSEvent *)theEvent
{
	self.userPopoverMouseIsInView = YES;

	if (self.userPopoverTimerIsActive == NO) {
		self.userPopoverTimerIsActive = YES;

		[self performSelector:@selector(popDelayedUserInfoExpansionFrame) withObject:nil afterDelay:1.0];
	}
}

- (void)mouseExited:(NSEvent *)theEvent
{
	[self destroyUserInfoPopover];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
	NSPoint localPoint = [self convertPoint:theEvent.locationInWindow fromView:nil];

	[self popUserInfoExpansionFrameAtPoint:localPoint ignoreTimerCheck:NO];
}

- (void)popUserInfoExpansionFrameAtPoint:(NSPoint)localPoint ignoreTimerCheck:(BOOL)ignoreTimer
{
	self.userPopoverLastKnownLocalPoint = localPoint;

	if ([XRAccessibility isVoiceOverEnabled]) {
		return;
	}

	if (self.userPopoverTimerIsActive && ignoreTimer == NO) {
		return; // Only allow the timer to pop it
	}

	if (self.window.keyWindow == NO) {
		return;
	}

	NSInteger row = [self rowAtPoint:localPoint];

	if (row < 0) {
		return;
	}

	if (self.lastRowShownUserInfoPopover != row) {
		self.lastRowShownUserInfoPopover = row;

		id rowView = [self viewAtColumn:0 row:row makeIfNecessary:NO];

		[rowView drawWithExpansionFrame];
	}
}

- (void)popDelayedUserInfoExpansionFrame
{
	/* Basically we delay the expansion frame (also known as the popover)
	 by one second from the time the user enters the frame so that if they
	 are just moving the mouse through it to another portion of the window
	 we do not try to show a popover. We only want to show a popover if the
	 user has some intention of being in the list. */

	if (self.userPopoverMouseIsInView) {
		[self popUserInfoExpansionFrameAtPoint:self.userPopoverLastKnownLocalPoint ignoreTimerCheck:YES];
	}

	self.userPopoverTimerIsActive = NO;
}

#pragma mark -
#pragma mark Scroll View

- (void)scrollViewBoundsDidChangeNotification:(NSNotification *)notification
{
	if ([TPCPreferences memberListUpdatesUserInfoPopoverOnScroll] == NO) {
		return;
	}

	if (notification.object != [self scrollViewContentView]) {
		return;
	}

	NSPoint mouseLocation = [NSEvent mouseLocation];

	NSRect mouseLocationFaked = NSMakeRect(mouseLocation.x, mouseLocation.y, 1.0, 1.0);

	NSRect remotePoint = [self.window convertRectFromScreen:mouseLocationFaked];

	NSPoint localPoint = [self convertPoint:remotePoint.origin fromView:nil];

	[self popUserInfoExpansionFrameAtPoint:localPoint ignoreTimerCheck:YES];
}

- (id)scrollViewContentView
{
	return self.enclosingScrollView.contentView;
}

#pragma mark -
#pragma mark Drag and Drop

- (NSInteger)draggedRow:(id <NSDraggingInfo>)sender
{
	NSPoint p = [self convertPoint:[sender draggingLocation] fromView:nil];

	return [self rowAtPoint:p];
}

- (NSArray *)draggedFiles:(id <NSDraggingInfo>)sender
{
	return [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	return [self draggingUpdated:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	NSArray *files = [self draggedFiles:sender];

	if (files.count > 0 && [self draggedRow:sender] >= 0) {
		return NSDragOperationCopy;
	} else {
		return NSDragOperationNone;
	}
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	NSArray *files = [self draggedFiles:sender];

	return (files.count > 0 && [self draggedRow:sender] >= 0);
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSArray *files = [self draggedFiles:sender];

	if (files.count > 0) {
		NSInteger row = [self draggedRow:sender];

		if (row >= 0) {
			[menuController() memberSendDroppedFiles:files row:row];

			return YES;
		}
	}

	return NO;
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

	TVCMemberListCell *rowView = [self viewAtColumn:0 row:rowIndex makeIfNecessary:NO];

	rowView.needsDisplay = YES;
}

- (void)refreshDrawingForMember:(IRCChannelUser *)cellItem
{
	NSParameterAssert(cellItem != nil);

	NSInteger rowIndex = [self rowForItem:cellItem];

	[self refreshDrawingForRow:rowIndex];
}

- (void)refreshDrawingForChangesToPreference:(NSString *)preferenceKey
{
	static NSDictionary<NSString *, NSNumber *> *preferenceMap = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		preferenceMap = @{
			@"User List Mode Badge Colors -> +y" : @(IRCUserRankIRCopByMode),
			@"User List Mode Badge Colors -> +q" : @(IRCUserRankChannelOwner),
			@"User List Mode Badge Colors -> +a" : @(IRCUserRankSuperOperator),
			@"User List Mode Badge Colors -> +o" : @(IRCUserRankNormalOperator),
			@"User List Mode Badge Colors -> +h" : @(IRCUserRankHalfOperator),
			@"User List Mode Badge Colors -> +v" : @(IRCUserRankVoiced),
			@"User List Mode Badge Colors -> no mode" : @(IRCUserRankNone)
		};
	});

	NSNumber *rank = preferenceMap[preferenceKey];

	if (rank == nil) {
		return;
	}

	IRCUserRank rankEnum = rank.unsignedIntegerValue;

	[self refreshDrawingForMembersWithRank:rankEnum isIRCop:(rankEnum == IRCUserRankIRCopByMode)];
}

- (void)refreshDrawingForMembersWithRank:(IRCUserRank)rank isIRCop:(BOOL)isIRCop
{
	TVCMemberListAppearance *appearance = self.userInterfaceObjects;

	NSArray *rows = self.contentController.arrangedObjects;

	[rows enumerateObjectsUsingBlock:^(IRCChannelUser *member, NSUInteger index, BOOL *stop) {
		if ((member.ranks & rank) == 0 && (isIRCop && isIRCop != member.user.isIRCop)) {
			return;
		}

		[appearance invalidateUserMarkBadgeCacheForSymbol:member.mark rank:rank];

		[self refreshDrawingForRow:index];
	}];
}

- (void)drawContextMenuHighlightForRow:(int)row
{
	// Do not draw focus ring ...
}

- (BOOL)allowsVibrancy
{
	return YES;
}

- (void)updateVibrancyWithAppearance:(TVCMemberListAppearance *)appearance
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
	TVCMemberListAppearance *appearance = self.mainWindow.userInterfaceObjects.memberList;

	[self _updateAppearance:appearance];

	[self invalidateBackgroundForSelection];

	[self refreshAllDrawings:YES];
}

- (void)systemAppearanceChanged
{
//	[self invalidateBackgroundForSelection];
}

- (void)_updateAppearance:(TVCMemberListAppearance *)appearance
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
	[self destroyUserInfoPopoverOnWindowKeyChange];

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
		if ([self.selectedRowIndexes containsIndex:rowBeneathMouse] == NO) {
			[self selectItemAtIndex:rowBeneathMouse];
		}

		return menuController().userControlMenu;
	}

	return nil;
}

- (void)keyDown:(NSEvent *)e
{
	if (self.keyDelegate == nil) {
		return;
	}

	switch (e.keyCode) {
		case 125: // down arrow
		case 126: // up arrow
		{
			[super keyDown:e];

			break;
		}
		case 123: // left arrow
		case 124: // right arrow
		case 116: // page up
		case 121: // page down
		{
			break;
		}
		default:
		{
			[self.keyDelegate memberListKeyDown:e];

			break;
		}
	}
}

@end

NS_ASSUME_NONNULL_END
