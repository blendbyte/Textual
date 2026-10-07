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
#import "TVCMainWindowChannelViewPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@class TVCMainWindowChannelViewSubviewOverlayView;

@interface TVCMainWindowChannelViewSubview : NSView
@property (nonatomic, assign) NSUInteger itemIndex;
@property (nonatomic, assign) BOOL isSelected;
@property (nonatomic, assign) BOOL overlayVisible;
@property (nonatomic, assign) BOOL isObservingBackingView;
@property (readonly) BOOL backingViewIsLoading;
@property (nonatomic, copy) NSString *uniqueIdentifier;
@property (nonatomic, strong, nullable) TVCLogView *backingView;
@property (nonatomic, weak) TVCMainWindowChannelView *parentView;
@property (nonatomic, strong, nullable) TVCMainWindowChannelViewSubviewOverlayView *overlayView;

- (void)toggleOverlayView;
@end

@interface TVCMainWindowChannelViewSubviewOverlayView : NSView
@end

@interface TVCMainWindowChannelView ()
@property (nonatomic, assign) BOOL isMovingDividers;
@property (nonatomic, assign) NSUInteger itemIndexSelected;

- (void)selectionChangeTo:(NSUInteger)itemIndex;
@end

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

#pragma mark -
#pragma mark Overlay View

@implementation TVCMainWindowChannelViewSubview

- (instancetype)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)dealloc
{
	[self teardownBackingView];
}

- (void)prepareInitialState
{
	self.translatesAutoresizingMaskIntoConstraints = NO;
}

- (BOOL)backingViewIsLoading
{
	return self.backingView.isLayingOutView;
}

- (void)setIsSelected:(BOOL)isSelected
{
	if (self->_isSelected != isSelected) {
		self->_isSelected = isSelected;

		[self toggleOverlayView];
	}
}

- (void)setBackingView:(nullable TVCLogView *)backingView
{
	if (self->_backingView != backingView) {
		[self teardownBackingView];

		self->_backingView = backingView;

		[self setupWebView];
	}
}

- (void)teardownBackingView
{
	if (self.isObservingBackingView == NO) {
		return;
	}

	[self.backingView removeObserver:self forKeyPath:@"layingOutView"];

	self.isObservingBackingView = NO;
}

- (void)setupWebView
{
	TVCLogView *backingView = self.backingView;

	if (backingView == nil) {
		return;
	}

	/* Observe even when not loading: deferred and repeated loads (theme
	 reloads, crash recovery) change layingOutView later */
	if (self.isObservingBackingView == NO) {
		self.isObservingBackingView = YES;

		[backingView addObserver:self forKeyPath:@"layingOutView" options:NSKeyValueObservingOptionNew context:NULL];
	}

	NSView *webView = backingView.webView;

	if (self.overlayVisible) {
		[self addSubview:webView positioned:NSWindowBelow relativeTo:self.overlayView];
	} else {
		[self addSubview:webView];
	}

	[self addConstraints:
	 [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[webView(>=30)]-0-|"
											 options:NSLayoutFormatDirectionLeadingToTrailing
											 metrics:nil
											   views:NSDictionaryOfVariableBindings(webView)]];

	[self addConstraints:
	 [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[webView(>=30)]-0-|"
											 options:NSLayoutFormatDirectionLeadingToTrailing
											 metrics:nil
											   views:NSDictionaryOfVariableBindings(webView)]];
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSString *, id> *)change context:(nullable void *)context
{
	if ([keyPath isEqualToString:@"layingOutView"]) {
		[self toggleOverlayView];
	}
}

- (void)constructOverlayView
{
	  TVCMainWindowChannelViewSubviewOverlayView *overlayView =
	[[TVCMainWindowChannelViewSubviewOverlayView alloc] initWithFrame:self.frame];

	overlayView.translatesAutoresizingMaskIntoConstraints = NO;

	self.overlayView = overlayView;
}

- (void)addOverlayView
{
	if (self.overlayVisible) {
		[self.overlayView setNeedsDisplay:YES];

		return;
	}

	if (self.overlayView == nil) {
		[self constructOverlayView];
	}

	TVCMainWindowChannelViewSubviewOverlayView *overlayView = self.overlayView;

	[self addSubview:overlayView];

	[self addConstraints:
	 [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[overlayView]-0-|"
											 options:NSLayoutFormatDirectionLeadingToTrailing
											 metrics:nil
											   views:NSDictionaryOfVariableBindings(overlayView)]];

	[self addConstraints:
	 [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[overlayView]-0-|"
											 options:NSLayoutFormatDirectionLeadingToTrailing
											 metrics:nil
											   views:NSDictionaryOfVariableBindings(overlayView)]];

	self.overlayVisible = YES;
}

- (void)toggleOverlayView
{
	if (self.backingViewIsLoading || self.isSelected == NO) {
		[self addOverlayView];
	} else {
		if ( self.overlayView) {
			[self.overlayView removeFromSuperview];

			self.overlayVisible = NO;
		}
	}
}

- (void)mouseDownSelectionChange
{
	if (self.backingViewIsLoading) {
		return;
	}

	[self.parentView selectionChangeTo:self.itemIndex];
}

- (void)mouseDown:(NSEvent *)theEvent
{
	if (self.overlayVisible) {
		[self mouseDownSelectionChange];

		return;
	}

	[super mouseDown:theEvent];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
	if (self.overlayVisible) {
		[self mouseDownSelectionChange];

		return;
	}

	[super rightMouseDown:theEvent];
}

- (void)otherMouseDown:(NSEvent *)theEvent
{
	if (self.overlayVisible) {
		[self mouseDownSelectionChange];

		return;
	}

	[super otherMouseDown:theEvent];
}

- (nullable NSView *)hitTest:(NSPoint)aPoint
{
	if (NSPointInRect(aPoint, self.frame) == NO) {
		return nil;
	}

	if (self.overlayVisible) {
		return self.overlayView;
	}

	return [super hitTest:aPoint];
}

@end

#pragma mark -

@implementation TVCMainWindowChannelViewSubviewOverlayView

- (void)mouseDown:(NSEvent *)theEvent
{
	[self.superview mouseDown:theEvent];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
	[self.superview rightMouseDown:theEvent];
}

- (void)otherMouseDown:(NSEvent *)theEvent
{
	[self.superview otherMouseDown:theEvent];
}

- (void)drawRect:(NSRect)dirtyRect
{
	if ([self needsToDrawRect:dirtyRect] == NO) {
		return;
	}

	TVCMainWindowChannelViewSubview *subview = (id)self.superview;

	NSColor *backgroundColor = nil;

	if (subview.backingViewIsLoading) {
		backgroundColor = themeSettings().underlyingWindowColor;
	} else {
		backgroundColor = themeSettings().channelViewOverlayColor;
	}

	if (backgroundColor == nil) {
		backgroundColor = [self defaultBackgroundColor];
	}

	[backgroundColor set];

	[NSBezierPath fillRect:dirtyRect];
}

- (NSColor *)defaultBackgroundColor
{
	TVCMainWindow *mainWindow = self.mainWindow;

	TVCMainWindowAppearance *appearance = mainWindow.userInterfaceObjects;

	if (appearance == nil) {
		return [NSColor blackColor];
	}

	if (mainWindow.isActiveForDrawing) {
		return appearance.channelViewOverlayDefaultBackgroundColorActiveWindow;
	} else {
		return appearance.channelViewOverlayDefaultBackgroundColorInactiveWindow;
	}
}

- (nullable NSView *)hitTest:(NSPoint)aPoint
{
	return self;
}

@end

NS_ASSUME_NONNULL_END
