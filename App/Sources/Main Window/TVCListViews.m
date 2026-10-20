/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

#import <CoreText/CoreText.h>

#import "NSViewHelperPrivate.h"
#import "TVCListViewsPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCListRowView ()
@property (nonatomic, weak, nullable) __kindof NSTableCellView *childCell;
@end

@implementation TVCListRowView

- (void)setSelected:(BOOL)selected
{
	super.selected = selected;

	if (selected == NO && self.invalidatingBackgroundForSelection) {
		return;
	}

	[self setNeedsDisplayOnChild];
}

- (void)setNeedsDisplayOnChild
{
	self.childCell.needsDisplay = YES;
}

- (void)drawSelectionInRect:(NSRect)dirtyRect
{
	if ([self needsToDrawRect:dirtyRect] == NO) {
		return;
	}

	BOOL activeWindow = self.window.isActiveForDrawing;

	/* An appearance's own colour, else the system's, as in Finder's sidebar:
	 the accent colour while this list has the keyboard focus (emphasized),
	 neutral grey otherwise, which fits every style */
	NSColor *selectionColor = [self selectionColorForActiveWindow:activeWindow];

	if (selectionColor == nil) {
		selectionColor = ((self.isEmphasized) ? [NSColor selectedContentBackgroundColor] : [NSColor unemphasizedSelectedContentBackgroundColor]);
	}

	[selectionColor set];

	/* A rounded bar inset from the edges, as in the system's sidebars */
	NSRect selectionRect = NSInsetRect(self.bounds, 6.0, 1.0);

	[[NSBezierPath bezierPathWithRoundedRect:selectionRect xRadius:5.0 yRadius:5.0] fill];
}

- (nullable NSColor *)selectionColorForActiveWindow:(BOOL)activeWindow
{
	return nil;
}

- (BOOL)wantsEmphasis
{
	return NO;
}

/* Lists that want it are emphasized while their window is key; the others
 when the table has the keyboard focus (the table sets it) */
- (BOOL)isEmphasized
{
	if (self.wantsEmphasis == NO) {
		return super.isEmphasized;
	}

	NSWindow *window = self.window;

	return (window == nil || window.isKeyWindow);
}

- (void)setEmphasized:(BOOL)emphasized
{
	if (super.isEmphasized == emphasized) {
		return;
	}

	super.emphasized = emphasized;

	if (self.selected) {
		self.needsDisplay = YES;

		[self setNeedsDisplayOnChild];
	}
}

- (nullable __kindof NSTableCellView *)childCell
{
	NSTableCellView *childCell = self->_childCell;

	/* Rows are reused and reloaded: the cached cell may sit in another row now
	 (still alive, so the weak reference didn't clear) */
	if (childCell && childCell.superview != self) {
		childCell = nil;
	}

	if (childCell == nil && self.numberOfColumns > 0) {
		childCell = [self viewAtColumn:0];

		self->_childCell = childCell;
	}

	return childCell;
}

@end

#pragma mark -

@implementation TVCListBadge

+ (NSImage *)imageWithSize:(NSSize)size
			  cornerRadius:(CGFloat)cornerRadius
		   backgroundColor:(nullable NSColor *)backgroundColor
					string:(nullable NSAttributedString *)string
{
	return [NSImage imageWithSize:size flipped:NO drawingHandler:^BOOL(NSRect badgeFrame) {
		if (backgroundColor) {
			[backgroundColor set];

			[[NSBezierPath bezierPathWithRoundedRect:badgeFrame xRadius:cornerRadius yRadius:cornerRadius] fill];
		}

		if (string.length == 0) {
			return YES;
		}

		CGContextRef context = [NSGraphicsContext currentContext].CGContext;

		CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)string);

		/* The glyphs' ink, relative to the start of the baseline */
		CGRect inkBounds = CTLineGetImageBounds(line, context);

		CGFloat x = (NSMidX(badgeFrame) - CGRectGetMidX(inkBounds));
		CGFloat y = (NSMidY(badgeFrame) - CGRectGetMidY(inkBounds));

		CGContextSaveGState(context);

		CGContextSetTextMatrix(context, CGAffineTransformIdentity);
		CGContextSetTextPosition(context, round(x), round(y));

		CTLineDraw(line, context);

		CGContextRestoreGState(context);

		CFRelease(line);

		return YES;
	}];
}

@end

NS_ASSUME_NONNULL_END
