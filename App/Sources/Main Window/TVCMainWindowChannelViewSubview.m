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

		[self.overlayView setLoading:self.backingViewIsLoading];
	} else {
		if ( self.overlayView) {
			[self.overlayView setLoading:NO];

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

@interface TVCMainWindowChannelViewSubviewOverlayView ()
@property (nonatomic, strong, nullable) NSProgressIndicator *loadingIndicator;
@end

@implementation TVCMainWindowChannelViewSubviewOverlayView

- (void)setLoading:(BOOL)loading
{
	if (loading == NO) {
		[self cancelPerformRequestsWithSelector:@selector(showLoadingIndicator)];

		[self.loadingIndicator stopAnimation:nil];

		self.loadingIndicator.hidden = YES;

		return;
	}

	if (self.loadingIndicator.hidden == NO && self.loadingIndicator != nil) {
		return;
	}

	[self cs_reschedulePerformSelectorInCommonModes:@selector(showLoadingIndicator) withObject:nil afterDelay:0.5];
}

- (void)showLoadingIndicator
{
	NSProgressIndicator *loadingIndicator = self.loadingIndicator;

	if (loadingIndicator == nil) {
		loadingIndicator = [NSProgressIndicator new];

		loadingIndicator.style = NSProgressIndicatorStyleSpinning;
		loadingIndicator.controlSize = NSControlSizeRegular;
		loadingIndicator.displayedWhenStopped = NO;

		loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;

		[self addSubview:loadingIndicator];

		[self addConstraints:@[
			[loadingIndicator.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
			[loadingIndicator.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
		]];

		self.loadingIndicator = loadingIndicator;
	}

	/* Light on dark styles: the window around the view may be light */
	BOOL dark = (theme().appearance == TPCThemeAppearanceTypeDark || themeSettings().underlyingWindowColorIsDark);

	loadingIndicator.appearance = ((dark) ? [TXAppearancePropertyCollection appKitDarkAppearance] : [TXAppearancePropertyCollection appKitLightAppearance]);

	loadingIndicator.hidden = NO;

	[loadingIndicator startAnimation:nil];
}

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
