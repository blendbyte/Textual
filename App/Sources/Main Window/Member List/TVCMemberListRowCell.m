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

#import "NSStringHelper.h"
#import "NSTableViewHelperPrivate.h"
#import "NSViewHelperPrivate.h"
#import "TLOLocalization.h"
#import "TPCPreferencesLocal.h"
#import "IRCChannelUser.h"
#import "IRCUser.h"
#import "TVCMainWindow.h"
#import "TVCMemberListAppearance.h"
#import "TVCMemberListPrivate.h"
#import "TVCMemberListUserInfoPopoverPrivate.h"
#import "TVCMemberListCellInternal.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Row View Cell

@implementation TVCMemberListRowCell

- (instancetype)initWithMemberList:(TVCMemberList *)memberList
{
	NSParameterAssert(memberList != nil);

	if ((self = [super initWithFrame:NSZeroRect])) {
		self.memberList = memberList;

		return self;
	}

	return nil;
}

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

	BOOL isWindowActive = self.mainWindow.isActiveForDrawing;

	TVCMemberListAppearance *appearance = self.userInterfaceObjects;

	NSColor *selectionColor = nil;

	if (isWindowActive) {
		selectionColor = appearance.rowSelectionColorActiveWindow;
	} else {
		selectionColor = appearance.rowSelectionColorInactiveWindow;
	} // isWindowActive

	if (selectionColor) {
		[selectionColor set];

		NSRect selectionRect = self.bounds;

		NSRectFill(selectionRect);
	} else {
		[super drawSelectionInRect:dirtyRect];
	} // selectionColor
}

- (void)didAddSubview:(NSView *)subview
{
	TVCMemberListCell *childCell = self.childCell;

	[childCell defineConstraints];

	[super didAddSubview:subview];
}

#pragma mark -
#pragma mark Cell Information

- (BOOL)isEmphasized
{
	TVCMemberListAppearance *appearance = self.userInterfaceObjects;

	NSWindow *window = self.window;

	return (appearance.cellRowEmphasized &&
			(window == nil || window.isKeyWindow));
}

- (TVCMemberListCell * _Nullable)childCell
{
	if (self->_childCell == nil) {
		if (self.numberOfColumns == 0) {
			return nil;
		}

		self->_childCell = [self viewAtColumn:0];
	}

	return self->_childCell;
}

- (TVCMemberListAppearance *)userInterfaceObjects
{
	return self.memberList.userInterfaceObjects;
}

@end

NS_ASSUME_NONNULL_END
