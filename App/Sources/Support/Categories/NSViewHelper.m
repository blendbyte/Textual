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

#import "TVCMainWindow.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSWindow (TXWindowHelper)

- (void)changeFrameToMin
{
	[self changeFrameToMinAndDisplay:YES animate:NO];
}

- (void)changeFrameToMinAndDisplay:(BOOL)display
{
	[self changeFrameToMinAndDisplay:display animate:NO];
}

- (void)changeFrameToMinAndDisplay:(BOOL)display animate:(BOOL)animate
{
	NSSize minSize = self.contentMinSize;

	[self changeFrameTo:minSize display:display animate:NO];
}

- (void)changeFrameTo:(NSSize)minSize display:(BOOL)display animate:(BOOL)animate
{
	NSRect oldFrame = self.frame;
	NSRect newFrame = oldFrame;

	NSRect contentRect = [self contentRectForFrameRect:newFrame];

	float bezelHeight = (newFrame.size.height - contentRect.size.height);

	newFrame.size.width = minSize.width;
	newFrame.size.height = (bezelHeight + minSize.height);

	newFrame.origin.y = (NSMaxY(oldFrame) - newFrame.size.height);

	[self setFrame:newFrame display:display animate:animate];
}

- (void)replaceContentView:(NSView *)withView
{
	self.contentView = nil;

	[self changeFrameTo:withView.frame.size display:NO animate:NO];

	self.contentView = withView;
}

@end

#pragma mark -

@implementation NSView (TXViewHelperPrivate)

- (nullable TVCMainWindow *)mainWindow
{
	NSWindow *window = self.window;

	if ([window isMemberOfClass:[TVCMainWindow class]] == NO) {
		return nil;
	}

	return (TVCMainWindow *)window;
}

@end

#pragma mark -

@implementation NSView (TXViewHelper)

- (void)addConstraintsToSuperviewToHugEdges
{
	NSView *superview = self.superview;

	NSArray *constraints = @[
	 [NSLayoutConstraint constraintWithItem:self
								  attribute:NSLayoutAttributeLeft
								  relatedBy:NSLayoutRelationEqual
									 toItem:superview
								  attribute:NSLayoutAttributeLeft
								 multiplier:1.0
								   constant:0.0],

	 [NSLayoutConstraint constraintWithItem:self
								  attribute:NSLayoutAttributeRight
								  relatedBy:NSLayoutRelationEqual
									 toItem:superview
								  attribute:NSLayoutAttributeRight
								 multiplier:1.0
								   constant:0.0],

	 [NSLayoutConstraint constraintWithItem:self
								  attribute:NSLayoutAttributeTop
								  relatedBy:NSLayoutRelationEqual
									 toItem:superview
								  attribute:NSLayoutAttributeTop
								 multiplier:1.0
								   constant:0.0],

	 [NSLayoutConstraint constraintWithItem:self
								  attribute:NSLayoutAttributeBottom
								  relatedBy:NSLayoutRelationEqual
									 toItem:superview
								  attribute:NSLayoutAttributeBottom
								 multiplier:1.0
								   constant:0.0]
	 ];

	[superview addConstraints:constraints];
}

- (void)addConstraintsToSuperviewToEqualDimensions
{
	NSView *superview = self.superview;

	NSMutableArray *constraints = [NSMutableArray array];

	[constraints addObjectsFromArray:
	 [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[self(0@550)]-0-|"
											 options:NSLayoutFormatDirectionLeadingToTrailing
											 metrics:nil
											   views:NSDictionaryOfVariableBindings(self)]];

	[constraints addObjectsFromArray:
	 [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[self(0@550)]-0-|"
											 options:NSLayoutFormatDirectionLeadingToTrailing
											 metrics:nil
											   views:NSDictionaryOfVariableBindings(self)]];

	[superview addConstraints:constraints];
}

- (void)replaceFirstSubview:(NSView *)withSubview
{
	NSParameterAssert(withSubview != nil);

	/* Remove any views that may already be in place. */
	[self.subviews.firstObject removeFromSuperviewWithoutNeedingDisplay];

	/* Add subview. */
	[self addSubview:withSubview];

	/* Apply constraints. */
	[withSubview addConstraintsToSuperviewToHugEdges];

	[withSubview addConstraintsToSuperviewToEqualDimensions];
}

@end

#pragma mark -

@implementation NSCell (TXCellHelperPrivate)

- (nullable NSWindow *)window
{
	return self.controlView.window;
}

- (nullable TVCMainWindow *)mainWindow
{
	return self.controlView.mainWindow;
}

@end

NS_ASSUME_NONNULL_END
