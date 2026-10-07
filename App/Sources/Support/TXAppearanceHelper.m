/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
 *       Please see Acknowledgements.pdf for additional information.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *	* Redistributions of source code must retain the above copyright
 *	  notice, this list of conditions and the following disclaimer.
 *	* Redistributions in binary form must reproduce the above copyright
 *	  notice, this list of conditions and the following disclaimer in the
 *	  documentation and/or other materials provided with the distribution.
 *  * Neither the name of Textual and/or Codeux Software, nor the names of
 *    its contributors may be used to endorse or promote products derived
 * 	  from this software without specific prior written permission.
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

#import "TXAppearanceHelper.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark NSView Category

@implementation NSView (TXAppearance)

- (BOOL)needsDisplayWhenApplicationAppearanceChanges
{
	return NO;
}

- (BOOL)needsDisplayWhenSystemAppearanceChanges
{
	return NO;
}

- (BOOL)sendApplicationAppearanceChangedToSubviews
{
	return YES;
}

- (BOOL)sendSystemAppearanceChangedToSubviews
{
	return YES;
}

- (void)applicationAppearanceChanged
{
	if (self.needsDisplayWhenApplicationAppearanceChanges) {
		self.needsDisplay = YES;
	}
}

- (void)systemAppearanceChanged
{
	if (self.needsDisplayWhenSystemAppearanceChanges) {
		self.needsDisplay = YES;
	}
}

- (void)notifyApplicationAppearanceChanged
{
	[self applicationAppearanceChanged];

	if (self.sendApplicationAppearanceChangedToSubviews == NO) {
		return;
	}

	for (NSView *view in self.subviews) {
		[view notifyApplicationAppearanceChanged];
	}
}

- (void)notifySystemAppearanceChanged
{
	[self systemAppearanceChanged];

	if (self.sendSystemAppearanceChangedToSubviews == NO) {
		return;
	}

	for (NSView *view in self.subviews) {
		[view notifySystemAppearanceChanged];
	}
}

@end

#pragma mark -
#pragma mark NSWindow Category

@implementation NSWindow (TXApplication)

- (void)notifyApplicationAppearanceChanged
{
	[self.contentView.superview notifyApplicationAppearanceChanged];

	for (NSTitlebarAccessoryViewController *viewController in self.titlebarAccessoryViewControllers) {
		[viewController.view notifyApplicationAppearanceChanged];
	}
}

- (void)notifySystemAppearanceChanged
{
	[self.contentView.superview notifySystemAppearanceChanged];

	for (NSTitlebarAccessoryViewController *viewController in self.titlebarAccessoryViewControllers) {
		[viewController.view notifySystemAppearanceChanged];
	}
}

@end

NS_ASSUME_NONNULL_END
