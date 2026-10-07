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

#import "NSViewHelperPrivate.h"
#import "TXGlobalModels.h"
#import "TLOLocalization.h"
#import "TPCPreferencesLocal.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "TVCMainWindow.h"
#import "TVCServerListAppearancePrivate.h"
#import "TVCServerListPrivate.h"
#import "TVCServerListCellInternal.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Row Cell

@implementation TVCServerListRowCell

- (instancetype)initWithServerList:(TVCServerList *)serverList
{
	if ((self = [super initWithFrame:NSZeroRect])) {
		self.serverList = serverList;

		return self;
	}

	return nil;
}

- (void)drawDraggingDestinationFeedbackInRect:(NSRect)dirtyRect
{
	; // Do nothing for this...
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

	TVCServerListAppearance *appearance = self.userInterfaceObjects;

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
	TVCServerListCellGroupItem *childCell = self.childCell;

	[childCell defineConstraints];

	[super didAddSubview:subview];
}

#pragma mark -
#pragma mark Cell Information

- (BOOL)isEmphasized
{
	TVCServerListAppearance *appearance = self.userInterfaceObjects;

	BOOL emphasized = NO;

	if (self.isGroupItem) {
		emphasized = appearance.serverRowEmphasized;
	} else {
		emphasized = appearance.channelRowEmphasized;
	}

	NSWindow *window = self.window;

	return (emphasized &&
			(window == nil || window.isKeyWindow));
}

- (__kindof TVCServerListCell * _Nullable)childCell
{
	if (self->_childCell == nil) {
		if (self.numberOfColumns == 0) {
			return nil;
		}

		self->_childCell = [self viewAtColumn:0];
	}

	return self->_childCell;
}

- (TVCServerListAppearance *)userInterfaceObjects
{
	return self.serverList.userInterfaceObjects;
}

- (BOOL)isGroupItem
{
	return [self isKindOfClass:[TVCServerListGroupRowCell class]];
}

@end

@implementation TVCServerListGroupRowCell
@end

@implementation TVCServerListChildRowCell
@end

NS_ASSUME_NONNULL_END
