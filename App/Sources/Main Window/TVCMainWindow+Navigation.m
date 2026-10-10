/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
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
#import "NSStringHelper.h"
#import "IRCChannelPrivate.h"
#import "IRCChannelMode.h"
#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "IRCTreeItemPrivate.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCWorldPrivate.h"
#import "TVCDockIconPrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogViewPrivate.h"
#import "TVCMainWindowAppearancePrivate.h"
#import "TVCMainWindowChannelViewPrivate.h"
#import "TVCMainWindowLoadingScreenPrivate.h"
#import "TVCMainWindowSplitViewPrivate.h"
#import "TVCMainWindowTextViewPrivate.h"
#import "TVCMainWindowTitlebarAccessoryViewPrivate.h"
#import "TVCServerListPrivate.h"
#import "TVCServerListAppearancePrivate.h"
#import "TVCServerListCellPrivate.h"
#import "TVCMemberListPrivate.h"
#import "TVCTextViewIRCFormattingMenuPrivate.h"
#import "TVCTextViewWithIRCFormatterPrivate.h"
#import "TPCApplicationInfo.h"
#import "TPCPreferencesLocal.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCThemeControllerPrivate.h"
#import "TPCTheme.h"
#import "TXGlobalModels.h"
#import "TXMasterControllerPrivate.h"
#import "TXMenuControllerPrivate.h"
#import "THOPluginDispatcherPrivate.h"
#import "TLOKeyEventHandler.h"
#import "TLOInputHistoryPrivate.h"
#import "TLOLocalization.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLONicknameCompletionStatusPrivate.h"
#import "TLONotificationControllerPrivate.h"
#import "TLOSpeechSynthesizerPrivate.h"
#import "TDCLicenseManagerDialogPrivate.h"
#import "TVCMainWindowInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TVCMainWindow (Navigation)

#pragma mark -
#pragma mark Navigation

- (void)navigateServerListEntries:(nullable NSArray<IRCTreeItem *> *)scannedRows
					   entryCount:(NSInteger)entryCount
					startingPoint:(NSInteger)startingPoint
					 isMovingDown:(BOOL)isMovingDown
				   navigationType:(TVCServerListNavigationMovementType)navigationType
					selectionType:(TVCServerListNavigationSelectionType)selectionType
{
	if (entryCount <= 0) {
		return;
	}

	/* Nothing selected, or the selection isn't in these rows (no row or
	 NSNotFound): start from the end the movement comes from */
	if (startingPoint < 0 || startingPoint >= entryCount) {
		startingPoint = ((isMovingDown) ? -1 : entryCount);
	}

	NSInteger currentPosition = startingPoint;

	/* One pass over every row at most */
	for (NSInteger step = 0; step < entryCount; step++) {
		/* Move to next selection */
		if (isMovingDown) {
			currentPosition += 1;
		} else {
			currentPosition -= 1;
		}

		/* Make sure selection is within our bounds */
		if (currentPosition >= entryCount || currentPosition < 0) {
			if (isMovingDown == NO && currentPosition < 0) {
				currentPosition = (entryCount - 1);
			} else {
				currentPosition = 0;
			}
		}

		if (currentPosition == startingPoint) {
			break;
		}

		/* Get next selection depending on data source */
		id item;

		if (scannedRows) {
			item = scannedRows[currentPosition];
		} else {
			item = [self.serverList itemAtRow:currentPosition];
		}

		/* Skip entries depending on navigation type */
		if (selectionType == TVCServerListNavigationSelectionTypeChannel)
		{
			if ([item isChannel] == NO && [item isPrivateMessage] == NO) {
				continue;
			}
		}
		else if (selectionType == TVCServerListNavigationSelectionTypeServer)
		{
			if ([item isClient] == NO) {
				continue;
			}
		}

		/* Select current item if it is matched by our condition */
		if (navigationType == TVCServerListNavigationMovementTypeAll)
		{
			[self select:item];

			break;
		}
		else if (navigationType == TVCServerListNavigationMovementTypeActive)
		{
			if ([item isActive]) {
				[self select:item];

				break;
			}
		}
		else if (navigationType == TVCServerListNavigationMovementTypeUnread)
		{
			if ([item isUnread]) {
				[self select:item];

				break;
			}
		}
	}
}

- (void)navigateChannelEntries:(BOOL)isMovingDown withNavigationType:(TVCServerListNavigationMovementType)navigationType
{
	if ([TPCPreferences channelNavigationIsServerSpecific]) {
		[self navigateChannelEntriesWithinServerScope:isMovingDown withNavigationType:navigationType];
	} else {
		[self navigateChannelEntriesOutsideServerScope:isMovingDown withNavigationType:navigationType];
	}
}

- (void)navigateChannelEntriesOutsideServerScope:(BOOL)isMovingDown withNavigationType:(TVCServerListNavigationMovementType)navigationType
{
	NSInteger entryCount = self.serverList.numberOfRows;

	NSInteger startingPoint = [self.serverList rowForItem:self.selectedItem];

	[self navigateServerListEntries:nil
						 entryCount:entryCount
					  startingPoint:startingPoint
					   isMovingDown:isMovingDown
					 navigationType:navigationType
					  selectionType:TVCServerListNavigationSelectionTypeChannel];
}

- (void)navigateChannelEntriesWithinServerScope:(BOOL)isMovingDown withNavigationType:(TVCServerListNavigationMovementType)navigationType
{
	IRCClient *selectedClient = self.selectedClient;

	if (selectedClient == nil) {
		return;
	}

	NSArray *scannedRows = [self.serverList itemsFromParentGroup:self.selectedItem];

	/* We add selected server so navigation falls within its scope if its the selected item */
	scannedRows = [(scannedRows ?: @[]) arrayByAddingObject:selectedClient];

	[self navigateServerListEntries:scannedRows
						 entryCount:scannedRows.count
					  startingPoint:[scannedRows indexOfObject:self.selectedItem]
					   isMovingDown:isMovingDown
					 navigationType:navigationType
					  selectionType:TVCServerListNavigationSelectionTypeChannel];
}

- (void)navigateServerEntries:(BOOL)isMovingDown withNavigationType:(TVCServerListNavigationMovementType)navigationType
{
	NSArray *scannedRows = self.serverList.groupItems;

	[self navigateServerListEntries:scannedRows
						 entryCount:scannedRows.count
					  startingPoint:[scannedRows indexOfObject:self.selectedClient]
					   isMovingDown:isMovingDown
					 navigationType:navigationType
					  selectionType:TVCServerListNavigationSelectionTypeServer];
}

- (void)navigateToNextEntry:(BOOL)isMovingDown
{
	NSInteger entryCount = self.serverList.numberOfRows;

	NSInteger startingPoint = [self.serverList rowForItem:self.selectedItem];

	[self navigateServerListEntries:nil
						 entryCount:entryCount
					  startingPoint:startingPoint
					   isMovingDown:isMovingDown
					 navigationType:TVCServerListNavigationMovementTypeAll
					  selectionType:TVCServerListNavigationSelectionTypeAny];
}

- (void)selectPreviousChannel:(NSEvent *)e
{
	[self navigateChannelEntries:NO withNavigationType:TVCServerListNavigationMovementTypeAll];
}

- (void)selectNextChannel:(NSEvent *)e
{
	[self navigateChannelEntries:YES withNavigationType:TVCServerListNavigationMovementTypeAll];
}

- (void)selectPreviousUnreadChannel:(NSEvent *)e
{
	[self navigateChannelEntries:NO withNavigationType:TVCServerListNavigationMovementTypeUnread];
}

- (void)selectNextUnreadChannel:(NSEvent *)e
{
	[self navigateChannelEntries:YES withNavigationType:TVCServerListNavigationMovementTypeUnread];
}

- (void)selectPreviousActiveChannel:(NSEvent *)e
{
	[self navigateChannelEntries:NO withNavigationType:TVCServerListNavigationMovementTypeActive];
}

- (void)selectNextActiveChannel:(NSEvent *)e
{
	[self navigateChannelEntries:YES withNavigationType:TVCServerListNavigationMovementTypeActive];
}

- (void)selectPreviousServer:(NSEvent *)e
{
	[self navigateServerEntries:NO withNavigationType:TVCServerListNavigationMovementTypeAll];
}

- (void)selectNextServer:(NSEvent *)e
{
	[self navigateServerEntries:YES withNavigationType:TVCServerListNavigationMovementTypeAll];
}

- (void)selectPreviousActiveServer:(NSEvent *)e
{
	[self navigateServerEntries:NO withNavigationType:TVCServerListNavigationMovementTypeActive];
}

- (void)selectNextActiveServer:(NSEvent *)e
{
	[self navigateServerEntries:YES withNavigationType:TVCServerListNavigationMovementTypeActive];
}

- (void)selectPreviousSelection:(NSEvent *)e
{
	[self selectPreviousItem];
}

- (void)selectNextWindow:(nullable NSEvent *)e
{
	[self navigateToNextEntry:YES];
}

- (void)selectPreviousWindow:(nullable NSEvent *)e
{
	[self navigateToNextEntry:NO];
}

#pragma mark -
#pragma mark Swipe Events

/* Three Finger Swipe Event
	This event will only work if 
		System Settings -> Trackpad -> More Gestures -> Swipe between full-screen apps
	is not set to "Swipe left or right with three fingers"
 */
- (void)swipeWithEvent:(NSEvent *)event
{
	CGFloat x = event.deltaX;

	BOOL invertedScrollingDirection = [RZUserDefaults() boolForKey:@"com.apple.swipescrolldirection"];

	if (invertedScrollingDirection) {
		x = (x * (-1));
	}

	if (x > 0) {
		[self selectNextWindow:nil];
	} else if (x < 0) {
		[self selectPreviousWindow:nil];
	}
}

- (void)beginGestureWithEvent:(NSEvent *)event
{
	CGFloat swipeMinimumLength = [TPCPreferences swipeMinimumLength];

	if (swipeMinimumLength < 1.0) {
		return;
	}

	NSSet *touches = [event touchesMatchingPhase:NSTouchPhaseTouching inView:nil];

	if (touches.count != 2) {
		return;
	}

	NSArray *touchArray = touches.allObjects;

	self.cachedSwipeOriginPoint = [self touchesToPoint:touchArray[0] fingerB:touchArray[1]];
}

- (NSValue *)touchesToPoint:(NSTouch *)fingerA fingerB:(NSTouch *)fingerB
{
	NSParameterAssert(fingerA != nil);
	NSParameterAssert(fingerB != nil);

	NSSize deviceSize = fingerA.deviceSize;

	CGFloat x = ((fingerA.normalizedPosition.x + fingerB.normalizedPosition.x) / 2.0 * deviceSize.width);
	CGFloat y = ((fingerA.normalizedPosition.y + fingerB.normalizedPosition.y) / 2.0 * deviceSize.height);

	return [NSValue valueWithPoint:NSMakePoint(x, y)];
}

- (void)endGestureWithEvent:(NSEvent *)event
{
	CGFloat swipeMinimumLength = [TPCPreferences swipeMinimumLength];

	if (swipeMinimumLength < 1.0) {
		return;
	}

	NSSet *touches = [event touchesMatchingPhase:NSTouchPhaseAny inView:nil];

	if (self.cachedSwipeOriginPoint == nil || touches.count != 2) {
		self.cachedSwipeOriginPoint = nil;

		return;
	}

	NSArray *touchArray = touches.allObjects;

	NSPoint origin = self.cachedSwipeOriginPoint.pointValue;

	NSPoint destination = [self touchesToPoint:touchArray[0] fingerB:touchArray[1]].pointValue;

	self.cachedSwipeOriginPoint = nil;

	NSPoint delta = NSMakePoint((origin.x - destination.x),
								(origin.y - destination.y));

	if (fabs(delta.y) > fabs(delta.x)) {
		return;
	}

	if (fabs(delta.x) < swipeMinimumLength) {
		return;
	}

	CGFloat x = delta.x;

	BOOL invertedScrollingDirection = [RZUserDefaults() boolForKey:@"com.apple.swipescrolldirection"];

	if (invertedScrollingDirection) {
		x = (x * (-1));
	}

	if (x > 0) {
		[self selectPreviousWindow:nil];
	} else {
		[self selectNextWindow:nil];
	}
}

@end

NS_ASSUME_NONNULL_END
