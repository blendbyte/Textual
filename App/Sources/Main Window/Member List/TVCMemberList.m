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
#import "TVCMainWindowPrivate.h"
#import "IRCChannelUser.h"
#import "IRCChannelPrivate.h"
#import "IRCChannelMemberListPrivate.h"
#import "NSViewHelperPrivate.h"
#import "TXMasterController.h"
#import "TXMenuControllerPrivate.h"
#import "TVCMainWindow.h"
#import "TLOLocalization.h"
#import "TPCPreferencesLocal.h"
#import "TVCMemberListCellPrivate.h"
#import "TVCMemberListAppearancePrivate.h"
#import "TVCMemberListUserInfoPopoverPrivate.h"
#import "TVCMemberListPrivate.h"
#import "TVCMemberListControllerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const TVCMemberListDragType = @"TVCMemberListDragType";

@interface TVCMemberList ()
@property (nonatomic, strong) id userPopoverTrackingArea;
@property (nonatomic, assign) BOOL userPopoverMouseIsInView;
@property (nonatomic, assign) BOOL userPopoverTimerIsActive;
@property (nonatomic, assign) NSInteger lastRowShownUserInfoPopover;
@property (nonatomic, strong, readwrite) TVCMemberListAppearance *userInterfaceObjects;
@property (nonatomic, weak, readwrite) IBOutlet NSVisualEffectView *visualEffectView;
@property (nonatomic, strong, readwrite) IBOutlet TVCMemberListUserInfoPopover *memberListUserInfoPopover;
@property (nonatomic, strong, readonly) TVCMemberListController *controller;
@property (nonatomic, strong, nullable) NSTextField *notJoinedHint;
@end

@implementation TVCMemberList

@synthesize controller = _controller;

- (void)awakeFromNib
{
	[super awakeFromNib];

	(void)self.controller;

	/* 0 was the first row: hovering it first showed nothing */
	self.lastRowShownUserInfoPopover = (-1);

	[self updateTrackingAreas];

	[self registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
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

/* The table's rows come from the channel it shows. Made when first needed:
 the window can select a channel at launch before this list's awakeFromNib
 (nib objects wake in no set order), and that channel would be lost */
- (TVCMemberListController *)controller
{
	if (self->_controller == nil) {
		TVCMemberListController *controller = [[TVCMemberListController alloc] initWithMemberList:self];

		self->_controller = controller;

		self.dataSource = controller;
		self.delegate = controller;
	}

	return self->_controller;
}

#pragma mark -
#pragma mark Not Joined

- (void)setShowsNotJoinedHint:(BOOL)showsHint
{
	NSScrollView *scrollView = self.enclosingScrollView;

	if (scrollView == nil) {
		return;
	}

	if (self.notJoinedHint == nil) {
		if (showsHint == NO) {
			return;
		}

		NSTextField *hint = [NSTextField wrappingLabelWithString:TXTLS(@"TVCMainWindow[mbl-h1]")];

		hint.translatesAutoresizingMaskIntoConstraints = NO;

		hint.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
		hint.textColor = [NSColor secondaryLabelColor];
		hint.alignment = NSTextAlignmentCenter;

		[scrollView addSubview:hint];

		[NSLayoutConstraint activateConstraints:@[
			[hint.topAnchor constraintEqualToAnchor:scrollView.topAnchor constant:14.0],
			[hint.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor constant:10.0],
			[hint.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor constant:(-10.0)]
		]];

		self.notJoinedHint = hint;
	}

	self.notJoinedHint.hidden = (showsHint == NO);
}

#pragma mark -
#pragma mark Utilities

- (void)assignToChannel:(nullable IRCChannel *)channel
{
	/* Its row belongs to the previous channel's list */
	[self destroyUserInfoPopover];

	[self.controller showChannel:channel];
}

- (nullable id)itemAtRow:(NSInteger)row
{
	NSParameterAssert(row >= 0);

	return [self.controller.memberListShown memberAtIndex:row];
}

- (NSInteger)rowForItem:(nullable id)item
{
	if (item == nil) {
		return (-1);
	}

	return [self.controller.memberListShown indexOfMember:item];
}

#pragma mark -
#pragma mark Member List Changes

- (void)memberListContentChanged
{
	/* The row under the mouse may hold someone else now */
	self.lastRowShownUserInfoPopover = (-1);
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

	/* Where the mouse is now: the last move event may be from before it
	 entered (a click or a window opening under it moves no mouse), and
	 its zero point was the first row, showing that person's details */
	if (self.userPopoverMouseIsInView) {
		[self popUserInfoExpansionFrameAtPoint:[self _localMouseLocation] ignoreTimerCheck:YES];
	}

	self.userPopoverTimerIsActive = NO;
}

- (NSPoint)_localMouseLocation
{
	NSPoint mouseLocation = [NSEvent mouseLocation];

	NSRect mouseLocationFaked = NSMakeRect(mouseLocation.x, mouseLocation.y, 1.0, 1.0);

	NSRect remotePoint = [self.window convertRectFromScreen:mouseLocationFaked];

	return [self convertPoint:remotePoint.origin fromView:nil];
}

#pragma mark -
#pragma mark Scroll View

- (void)scrollViewBoundsDidChangeNotification:(NSNotification *)notification
{
	if (notification.object != [self scrollViewContentView]) {
		return;
	}

	[self popUserInfoExpansionFrameAtPoint:[self _localMouseLocation] ignoreTimerCheck:YES];
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

/* Paths of the files dragged here (one pasteboard item per file) */
- (NSArray<NSString *> *)draggedFiles:(id <NSDraggingInfo>)sender
{
	NSArray<NSURL *> *fileURLs =
	[[sender draggingPasteboard] readObjectsForClasses:@[[NSURL class]]
											   options:@{NSPasteboardURLReadingFileURLsOnlyKey : @(YES)}];

	NSMutableArray<NSString *> *paths = [NSMutableArray arrayWithCapacity:fileURLs.count];

	for (NSURL *fileURL in fileURLs) {
		[paths addObject:fileURL.path];
	}

	return [paths copy];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	return [self draggingUpdated:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	NSArray *files = [self draggedFiles:sender];

	if (files.count > 0) {
		return NSDragOperationCopy;
	} else {
		return NSDragOperationNone;
	}
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	NSArray *files = [self draggedFiles:sender];

	return (files.count > 0);
}

/* On someone: offered to them. Below the names: the channel's answer
 (it accepted nothing there, which looked like a broken drop). */
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSArray *files = [self draggedFiles:sender];

	if (files.count == 0) {
		return NO;
	}

	NSInteger row = [self draggedRow:sender];

	if (row >= 0) {
		[menuController() memberSendDroppedFiles:files row:row];
	} else {
		[menuController() answerDroppedFiles:files];
	}

	return YES;
}

#pragma mark -
#pragma mark Drawing Updates

- (void)refreshAllDrawings
{
	[self refreshAllDrawings:NO];
}

/* Rows out of sight are drawn when they scroll into view */
- (void)refreshAllDrawings:(BOOL)skipOcclusionCheck
{
	NSRange visibleRows = [self rowsInRect:self.visibleRect];

	for (NSUInteger i = visibleRows.location; i < NSMaxRange(visibleRows); i++) {
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
	/* The list can hold someone before the table has their row (a WHO reply
	 while joining), and AppKit throws for a row it doesn't have */
	if (rowIndex < 0 || rowIndex >= self.numberOfRows) {
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

	NSArray *rows = (self.controller.memberListShown.memberList ?: @[]);

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

	[TVCMainWindow applySidebarTranslucencyToView:visualEffectView];
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
	/* Remembered badges are drawn for one window state (active or not) */
	[self.userInterfaceObjects invalidateUserMarkBadgeCaches];

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
		case 116: // page up
		case 121: // page down
		case 115: // home
		case 119: // end
		{
			[super keyDown:e];

			break;
		}
		case 48: // tab
		{
			/* Next or previous control, instead of typing into the input field */
			if ((e.modifierFlags & NSEventModifierFlagShift) == NSEventModifierFlagShift) {
				[self.window selectPreviousKeyView:self];
			} else {
				[self.window selectNextKeyView:self];
			}

			break;
		}
		case 123: // left arrow
		case 124: // right arrow
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
