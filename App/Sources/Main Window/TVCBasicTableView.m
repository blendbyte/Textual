/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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

#import <objc/runtime.h>

#import "TVCBasicTableView.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TVCBasicTableView

#pragma mark -
#pragma mark Table View

- (BOOL)respondsToSelector:(SEL)aSelector
{
	/* AppKit will stop on a response that has copy: but if we have
	 no delegate for this method, then it's best to lie about having
	 it in our class. */
	if (aSelector == @selector(copy:)) {
		return [self.pasteboardDelegate respondsToSelector:@selector(copy:)];
	}

	return class_respondsToSelector(self.class, aSelector);
}

- (void)copy:(id)sender
{
	/* There is no need for a delegate response check here because it
	 is assumed the only way we can lead to this path is if we responded
	 to the call to -respondsToSelector: */
	[self.pasteboardDelegate copy:sender];
}

- (nullable NSMenu *)menuForEvent:(NSEvent *)event
{
	if (self.selectedRow < 0 && self.presentMenuForEmptySelection == NO) {
		return nil;
	}

	return self.menu;
}

- (void)rightMouseDown:(NSEvent *)e
{
	NSInteger rowBeneathMouse = self.rowBeneathMouse;

	if (rowBeneathMouse >= 0) {
		if ([self.selectedRowIndexes containsIndex:rowBeneathMouse] == NO) {
			[self selectItemAtIndex:rowBeneathMouse];
		}
	}

	[super rightMouseDown:e];
}

- (void)textDidEndEditing:(NSNotification *)note
{
	if ([self.textEditingDelegate respondsToSelector:@selector(textDidEndEditing:)]) {
		[self.textEditingDelegate textDidEndEditing:note];

		return;
	}

	[super textDidEndEditing:note];
}

@end

NS_ASSUME_NONNULL_END
