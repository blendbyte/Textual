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

#import "TXAppearance.h"
#import "NSViewHelperPrivate.h"
#import "TPCPreferencesLocal.h"
#import "TPCThemeController.h"
#import "TPCTheme.h"
#import "IRCTreeItem.h"
#import "TVCLogController.h"
#import "TVCLogView.h"
#import "TVCMainWindowAppearance.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowSplitViewPrivate.h"
#import "TVCMainWindowChannelViewInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TVCMainWindowChannelView

NSComparisonResult sortSubviews(TVCMainWindowChannelViewSubview *firstView,
								TVCMainWindowChannelViewSubview *secondView,
								void *context)
{
	NSUInteger itemIndex1 = firstView.itemIndex;
	NSUInteger itemIndex2 = secondView.itemIndex;

	if (itemIndex1 < itemIndex2) {
		return NSOrderedAscending;
	} else if (itemIndex1 > itemIndex2) {
		return NSOrderedDescending;
	}

	return NSOrderedSame;
}

- (void)awakeFromNib
{
	[super awakeFromNib];

	self.delegate = (id)self;
}

- (void)viewDidMoveToWindow
{
	if (self.window == nil) {
		[RZNotificationCenter() removeObserver:self];

		return;
	}

	[RZNotificationCenter() addObserver:self
							   selector:@selector(themeAppearanceChanged:)
								   name:TPCThemeAppearanceChangedNotification
								 object:nil];
}

- (void)resetSubviews
{
	NSArray *subviews = [self.subviews copy];

	for (NSView *subview in subviews) {
		[subview removeFromSuperview];
	}
}

- (void)populateSubviews
{
	/* Get list of views selected by the user */
	TVCMainWindow *mainWindow = self.mainWindow;

	NSArray *selectedItems = mainWindow.selectedItems;

	NSUInteger selectedItemsCount = selectedItems.count;

	if (selectedItemsCount == 0) {
		[self resetSubviews];

		self.itemIndexSelected = NSNotFound;

		return;
	}

	/* Make a list of subviews that already exist to compare when adding
	 or removing views so that we do not have to destroy entire backing. */
	NSMutableDictionary *subviews = nil;

	for (TVCMainWindowChannelViewSubview *subview in self.subviews) {
		NSString *uniqueIdentifier = subview.uniqueIdentifier;

		if (subviews == nil) {
			subviews = [NSMutableDictionary dictionary];
		}

		subviews[uniqueIdentifier] = subview;
	}

	/* Once selectedItems is processed, the value of subviewsUnclaimed will
	 be subviews that are no longer selected */
	NSMutableDictionary *subviewsUnclaimed = nil;

	if (subviews) {
		subviewsUnclaimed = [subviews mutableCopy];
	}

	/* Enumerate views that the user has selected */
	IRCTreeItem *itemSelected = mainWindow.selectedItem;

	__block NSUInteger itemSelectedIndex = NSNotFound;

	[selectedItems enumerateObjectsUsingBlock:^(IRCTreeItem *item, NSUInteger index, BOOL *stop) {
		NSString *uniqueIdentifier = item.uniqueIdentifier;

		TVCMainWindowChannelViewSubview *subview = nil;

		BOOL subviewIsNew = YES;

		if (subviews) {
			subview = subviews[uniqueIdentifier];

			if (subview) {
				subviewIsNew = NO;

				[subviewsUnclaimed removeObjectForKey:uniqueIdentifier];
			}
		}

		if (subview == nil) {
			subview = [self subviewForItem:item];
		}

		TVCLogView *backingView = [self backingViewForItem:item];

		subview.backingView = backingView;

		subview.itemIndex = index;

		if (itemSelected == item) {
			itemSelectedIndex = index;

			subview.isSelected = YES;
		} else {
			subview.isSelected = NO;

			/* -isSelected is defaulted to NO which means for new views,
			 -toggleOverlayView must be manually invoked because the
			 setter wont change the value if they are same (NO == NO) */
			if (subviewIsNew) {
				[subview toggleOverlayView];
			}
		}

		subview.uniqueIdentifier = uniqueIdentifier;

		if (subviewIsNew) {
			[self addSubview:subview];
		}
	}];

	self.itemIndexSelected = itemSelectedIndex;

	/* Remove subviews that are no longer selected */
	if (subviewsUnclaimed) {
		for (NSString *itemIdentifier in subviewsUnclaimed) {
			TVCMainWindowChannelViewSubview *subview = subviewsUnclaimed[itemIdentifier];

			[subview removeFromSuperview];
		}

		subviewsUnclaimed = nil;
	}

	/* Sort views */
	if (subviews) {
		[self sortSubviewsUsingFunction:sortSubviews context:nil];

		subviews = nil;
	}

	/* Size views */
	[self adjustSubviews];
}

- (void)selectionChangeTo:(NSUInteger)itemIndex
{
	TVCMainWindow *mainWindow = self.mainWindow;

	NSArray *selectedItems = mainWindow.selectedItems;

	NSArray *subviews = self.subviews;

	NSUInteger itemIndexSelected = self.itemIndexSelected;

	if (itemIndexSelected != NSNotFound) {
		TVCMainWindowChannelViewSubview *oldItemView = subviews[itemIndexSelected];

		oldItemView.isSelected = NO;
		[oldItemView toggleOverlayView];
	}

	TVCMainWindowChannelViewSubview *newItemView = subviews[itemIndex];

	newItemView.isSelected = YES;
	[newItemView toggleOverlayView];

	self.itemIndexSelected = itemIndex;

	IRCTreeItem *newItem = selectedItems[itemIndex];

	[mainWindow channelViewSelectionChangeTo:newItem];
}

- (TVCLogView *)backingViewForItem:(IRCTreeItem *)item
{
	return item.viewController.backingView;
}

- (TVCMainWindowChannelViewSubview *)subviewForItem:(IRCTreeItem *)item
{
	NSRect splitViewFrame = self.frame;

	splitViewFrame.origin.x = 0.0;
	splitViewFrame.origin.y = 0.0;

	  TVCMainWindowChannelViewSubview *overlayView =
	[[TVCMainWindowChannelViewSubview alloc] initWithFrame:splitViewFrame];

	overlayView.parentView = self;

	return overlayView;
}

- (NSLayoutPriority)holdingPriorityForSubviewAtIndex:(NSInteger)subviewIndex
{
	return 350.0;
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview
{
	return NO;
}

- (CGFloat)dividerThickness
{
	return 2.0;
}

- (NSColor *)dividerColor
{
	return self.mainWindow.contentSplitView.dividerColor;
}

- (void)updateArrangement
{
	TXChannelViewArrangement arrangement = [TPCPreferences channelViewArrangement];

	self.vertical = (arrangement == TXChannelViewArrangedVertically);
}

- (void)themeAppearanceChanged:(NSNotification *)notification
{
	[self updateVibrancy];
}

- (void)updateVibrancy
{
	if (theme().appearance == TPCThemeAppearanceTypeDark || themeSettings().underlyingWindowColorIsDark) {
		self.appearance = [TXAppearancePropertyCollection appKitDarkAppearance];
	} else {
		self.appearance = [TXAppearancePropertyCollection appKitLightAppearance];
	}
}

- (BOOL)needsDisplayWhenApplicationAppearanceChanges
{
	return YES;
}

@end

NS_ASSUME_NONNULL_END
