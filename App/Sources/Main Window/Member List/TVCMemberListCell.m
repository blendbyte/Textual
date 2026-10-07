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
#import "TVCMemberListCellPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@class TVCMemberListCellDrawingContext;

@interface TVCMemberListRowCell ()
@property (nonatomic, weak) TVCMemberList *memberList;
@property (nonatomic, weak) TVCMemberListCell *childCell;
@property (readonly) TVCMemberListAppearance *userInterfaceObjects;
@end

@interface TVCMemberListCell ()
@property (nonatomic, weak) IBOutlet NSTextField *cellTextField;
@property (readonly, copy) TVCMemberListCellDrawingContext *drawingContext;
@property (readonly) TVCMemberList *memberList;
@property (readonly) TVCMemberListRowCell *rowCell;
@property (readonly) TVCMemberListAppearance *userInterfaceObjects;
@property (readonly) IRCChannelUser *cellItem;
@property (readonly) NSInteger rowIndex;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *markBadgeLeftMarginConstraint;
@end

@interface TVCMemberListCellDrawingContext : NSObject
@property (nonatomic, assign) BOOL isInverted;
@property (nonatomic, assign) BOOL isSelected;
@property (nonatomic, assign) BOOL isWindowActive;
@end

@implementation TVCMemberListCell

#pragma mark -
#pragma mark Drawing

- (void)defineConstraints
{
	TVCMemberListAppearance *appearance = self.userInterfaceObjects;

	self.markBadgeLeftMarginConstraint.constant = appearance.markBadgeLeftMargin;
}

- (void)applicationAppearanceChanged
{
	[self defineConstraints];
}

- (BOOL)wantsUpdateLayer
{
	return YES;
}

- (NSViewLayerContentsRedrawPolicy)layerContentsRedrawPolicy
{
	return NSViewLayerContentsRedrawOnSetNeedsDisplay;
}

- (void)updateLayer
{
	[self updateDrawing];
}

- (void)updateDrawing
{
	TVCMemberListCellDrawingContext *drawingContext = self.drawingContext;

	[self updateTextFieldInContext:drawingContext];

	TVCMemberListAppearance *appearance = self.userInterfaceObjects;

	[self updateDrawingWithAppearance:appearance inContext:drawingContext];

	[self updateMarkBadgeWithAppearance:appearance inContext:drawingContext];
}

- (void)updateTextFieldInContext:(TVCMemberListCellDrawingContext *)drawingContext
{
	NSParameterAssert(drawingContext != nil);

	/* Update string value */
	IRCChannelUser *cellItem = self.cellItem;

	NSString *stringValueNew = cellItem.user.nickname;

	NSTextField *textField = self.cellTextField;

	NSString *stringValueOld = textField.stringValue;

	if ([stringValueOld isEqualTo:stringValueNew]) {
		return;
	}

	textField.stringValue = stringValueNew;

	/* Update accessibility */
	NSTextFieldCell *textFieldCell = textField.cell;

	[textFieldCell setAccessibilityValueDescription:TXTLS(@"Accessibility[alq-6s]", stringValueNew)];
}

- (void)updateDrawingWithAppearance:(TVCMemberListAppearance *)appearance inContext:(TVCMemberListCellDrawingContext *)drawingContext
{
	NSParameterAssert(appearance != nil);
	NSParameterAssert(drawingContext != nil);

	NSAttributedString *newValue = [self attributedTextFieldValueWithAppearance:appearance inContext:drawingContext];

	self.cellTextField.attributedStringValue = newValue;
}

- (NSAttributedString *)attributedTextFieldValueWithAppearance:(TVCMemberListAppearance *)appearance inContext:(TVCMemberListCellDrawingContext *)drawingContext
{
	NSParameterAssert(appearance != nil);
	NSParameterAssert(drawingContext != nil);

	BOOL isSelected = drawingContext.isSelected;
	BOOL isWindowActive = drawingContext.isWindowActive;

	IRCChannelUser *cellItem = self.cellItem;

	NSTextField *textField = self.cellTextField;

	NSAttributedString *stringValue = textField.attributedStringValue;

	NSMutableAttributedString *mutableStringValue = [stringValue mutableCopy];

	[mutableStringValue beginEditing];

	NSFont *controlFont = nil;

	if (isSelected) {
		controlFont = appearance.cellFontSelected;
	} else {
		controlFont = appearance.cellFont;
	} // isSelected

	NSColor *controlColor = nil;

	if (isSelected) {
		if (isWindowActive) {
			controlColor = appearance.cellSelectedTextColorActiveWindow;
		} else {
			controlColor = appearance.cellSelectedTextColorInactiveWindow;
		} // isWindowActive
	} else if (cellItem.user.isAway) {
		if (isWindowActive) {
			controlColor = appearance.cellAwayTextColorActiveWindow;
		} else {
			controlColor = appearance.cellAwayTextColorInactiveWindow;
		} // isWindowActive
	} else {
		if (isWindowActive) {
			controlColor = appearance.cellTextColorActiveWindow;
		} else {
			controlColor = appearance.cellTextColorInactiveWindow;
		} // isWindowActive
	}

	NSRange stringValueRange = stringValue.range;

	if (controlFont) {
		[mutableStringValue addAttribute:NSFontAttributeName value:controlFont range:stringValueRange];
	}

	if (controlColor) {
		[mutableStringValue addAttribute:NSForegroundColorAttributeName value:controlColor	range:stringValueRange];
	}

	[mutableStringValue endEditing];

	return mutableStringValue;
}

#pragma mark -
#pragma mark Badge Drawing

- (NSAttributedString *)markBadgeTextForModeSymbol:(NSString *)modeSymbol isSelected:(BOOL)isSelected withAppearance:(TVCMemberListAppearance *)appearance inContext:(TVCMemberListCellDrawingContext *)drawingContext
{
	NSParameterAssert(appearance != nil);
	NSParameterAssert(drawingContext != nil);

	BOOL isWindowActive = drawingContext.isWindowActive;

	NSFont *controlFont = nil;

	if (isSelected) {
		controlFont = appearance.markBadgeFontSelected;
	} else {
		controlFont = appearance.markBadgeFont;
	} // isSelected

	NSColor *controlColor = nil;

	if (isSelected) {
		if (isWindowActive) {
			controlColor = appearance.markBadgeSelectedTextColorActiveWindow;
		} else {
			controlColor = appearance.markBadgeSelectedTextColorInactiveWindow;
		} // isWindowActive
	} else {
		if (isWindowActive) {
			controlColor = appearance.markBadgeTextColorActiveWindow;
		} else {
			controlColor = appearance.markBadgeTextColorInactiveWindow;
		} // isWindowActive
	} // isSelected

	NSDictionary *attributes = @{NSForegroundColorAttributeName : controlColor, NSFontAttributeName : controlFont};

	NSAttributedString *stringToDraw = [NSAttributedString attributedStringWithString:modeSymbol attributes:attributes];

	return stringToDraw;
}

- (void)updateMarkBadgeWithAppearance:(TVCMemberListAppearance *)appearance inContext:(TVCMemberListCellDrawingContext *)drawingContext
{
	NSParameterAssert(appearance != nil);
	NSParameterAssert(drawingContext != nil);

	BOOL isSelected = drawingContext.isSelected;

	IRCChannelUser *cellItem = self.cellItem;

	NSString *modeSymbol = cellItem.mark;

	IRCUserRank userRankToDraw = IRCUserRankNone;

	if ([TPCPreferences memberListSortFavorsServerStaff]) {
		if (cellItem.user.isIRCop) {
			userRankToDraw = IRCUserRankIRCopByMode;
		}
	}

	if (userRankToDraw == IRCUserRankNone) {
		userRankToDraw = cellItem.rank;
	}

	NSImage *cachedImage = nil;

	if (isSelected == NO) {
		cachedImage = [appearance cachedUserMarkBadgeForSymbol:modeSymbol rank:userRankToDraw];
	}

	if (cachedImage == nil) {
		cachedImage = [self drawMarkBadgeForRank:userRankToDraw isSelected:isSelected withAppearance:appearance inContext:drawingContext];

		if (isSelected == NO) {
			[appearance cacheUserMarkBadge:cachedImage forSymbol:modeSymbol rank:userRankToDraw];
		}
	}

	self.imageView.image = cachedImage;
}

- (NSImage *)drawMarkBadgeForRank:(IRCUserRank)userRank isSelected:(BOOL)isSelected withAppearance:(TVCMemberListAppearance *)appearance inContext:(TVCMemberListCellDrawingContext *)drawingContext
{
	NSParameterAssert(appearance != nil);
	NSParameterAssert(drawingContext != nil);

	BOOL isWindowActive = drawingContext.isWindowActive;

	/* Create image that we will draw into. */
	NSRect imageViewFrame = self.imageView.frame;

	NSRect badgeFrame = NSMakeRect(0.0, 0.0, imageViewFrame.size.width, imageViewFrame.size.height);

	NSImage *badgeImage = [NSImage newImageWithSize:NSMakeSize(NSWidth(badgeFrame),  NSHeight(badgeFrame))];

	[badgeImage lockFocus];

	/* Decide the background color */
	NSColor *backgroundColor = nil;

	if (isSelected) {
		if (isWindowActive) {
			backgroundColor = appearance.markBadgeSelectedBackgroundColorActiveWindow;
		} else {
			backgroundColor = appearance.markBadgeSelectedBackgroundColorInactiveWindow;
		} // isWindowActive
	} else if (userRank == IRCUserRankIRCopByMode) {
		backgroundColor = appearance.markBadgeBackgroundColor_Y;
	} else if (userRank == IRCUserRankChannelOwner) {
		backgroundColor = appearance.markBadgeBackgroundColor_Q;
	} else if (userRank == IRCUserRankSuperOperator) {
		backgroundColor = appearance.markBadgeBackgroundColor_A;
	} else if (userRank == IRCUserRankNormalOperator) {
		backgroundColor = appearance.markBadgeBackgroundColor_O;
	} else if (userRank == IRCUserRankHalfOperator) {
		backgroundColor = appearance.markBadgeBackgroundColor_H;
	} else if (userRank == IRCUserRankVoiced) {
		backgroundColor = appearance.markBadgeBackgroundColor_V;
	} else {
		NSColor *customColor = appearance.markBadgeBackgroundColorByUser;

		if (customColor && [customColor isEqual:[NSColor clearColor]] == NO) {
			backgroundColor = customColor;
		} else {
			if (isWindowActive) {
				backgroundColor = appearance.markBadgeBackgroundColorActiveWindow;
			} else {
				backgroundColor = appearance.markBadgeBackgroundColorInactiveWindow;
			} // isWindowActive
		} // custom color set
	}

	/* Set "x" if the user has no modes set */
	NSString *stringToDraw = self.cellItem.mark;

	if ([TPCPreferences memberListDisplayNoModeSymbol]) {
		if (stringToDraw.length == 0) {
			stringToDraw = @"×";
		}
	}

	/* Draw the background of the badge */
	NSBezierPath *badgePath = [NSBezierPath bezierPathWithRoundedRect:badgeFrame xRadius:4.0 yRadius:4.0];

	[backgroundColor set];

	[badgePath fill];

	/* Begin building the actual mode string */
	if (stringToDraw.length > 0) {
		NSAttributedString *badgeText = [self markBadgeTextForModeSymbol:stringToDraw isSelected:isSelected withAppearance:appearance inContext:drawingContext];

		NSSize badgeTextSize = badgeText.size;

		NSPoint badgeTextPoint = NSMakePoint((NSMidX(badgeFrame) - (badgeTextSize.width / 2.0)),
											 (NSMidY(badgeFrame) - (badgeTextSize.height / 2.0)));

		if (appearance.isHighResolutionAppearance)
		{
			if ([stringToDraw isEqualToString:@"+"] ||
				[stringToDraw isEqualToString:@"~"] ||
				[stringToDraw isEqualToString:@"×"])
			{
				badgeTextPoint.y += 1.0;
			}
			else if ([stringToDraw isEqualToString:@"^"])
			{
				badgeTextPoint.y -= 2.0;
			}
			else if ([stringToDraw isEqualToString:@"*"])
			{
				badgeTextPoint.y -= 2.5;
			}
/*			else if ([stringToDraw isEqualToString:@"@"] ||
					 [stringToDraw isEqualToString:@"!"] ||
					 [stringToDraw isEqualToString:@"%"] ||
					 [stringToDraw isEqualToString:@"&"] ||
					 [stringToDraw isEqualToString:@"#"] ||
					 [stringToDraw isEqualToString:@"?"] ||
					 [stringToDraw isEqualToString:@"$"])
			{
				badgeTextPoint.y -= 0.0;
			} */
		}
		else // isDrawingForRetina
		{
			if ([stringToDraw isEqualToString:@"+"] ||
				[stringToDraw isEqualToString:@"~"] ||
				[stringToDraw isEqualToString:@"×"])
			{
				badgeTextPoint.y += 2.0;
			}
			else if ([stringToDraw isEqualToString:@"@"] ||
					 [stringToDraw isEqualToString:@"!"] ||
					 [stringToDraw isEqualToString:@"%"] ||
					 [stringToDraw isEqualToString:@"&"] ||
					 [stringToDraw isEqualToString:@"#"] ||
					 [stringToDraw isEqualToString:@"?"])
			{
				badgeTextPoint.y += 1.0;
			}
/*			else if ([stringToDraw isEqualToString:@"^"])
			{
				badgeTextPoint.y -= 0.0;
			} */
			else if ([stringToDraw isEqualToString:@"*"])
			{
				badgeTextPoint.y -= 1.0;
			}
			else if ([stringToDraw isEqualToString:@"$"])
			{
				badgeTextPoint.y += 1.0;
			}
		}

		[badgeText drawAtPoint:badgeTextPoint];
	}

	[badgeImage unlockFocus];

	return badgeImage;
}

#pragma mark -
#pragma mark Expansion Frame

- (void)drawWithExpansionFrame
{
	TVCMemberList *memberList = self.memberList;

	TVCMemberListUserInfoPopover *userInfoPopover = memberList.memberListUserInfoPopover;

	IRCChannelUser *cellItem = self.cellItem;

	/* =============================================== */

	userInfoPopover.nicknameField.stringValue = cellItem.user.nickname;

	/* =============================================== */

	NSString *hostmaskUsername = cellItem.user.username;

	if (hostmaskUsername.length == 0) {
		hostmaskUsername = TXTLS(@"TVCMainWindow[d85-9n]");
	}

	userInfoPopover.usernameField.stringValue = hostmaskUsername;

	/* =============================================== */

	BOOL stripIRCFormatting = [TPCPreferences removeAllFormatting];

	NSString *hostmaskAddress = cellItem.user.address;

	if (hostmaskAddress.length == 0) {
		hostmaskAddress = TXTLS(@"TVCMainWindow[d85-9n]");
	}

	if (stripIRCFormatting) {
		userInfoPopover.addressField.stringValue = hostmaskAddress;
	} else {
		NSAttributedString *hostmaskAddressFormatted =
		[hostmaskAddress attributedStringWithIRCFormatting:[NSFont systemFontOfSize:12.0]
										preferredFontColor:nil
								 honorFormattingPreference:NO];

		userInfoPopover.addressField.attributedStringValue = hostmaskAddressFormatted;
	}

	/* =============================================== */

	NSString *realName = cellItem.user.realName;

	if (realName.length == 0) {
		realName = TXTLS(@"TVCMainWindow[d85-9n]");
	}

	if (stripIRCFormatting) {
		userInfoPopover.realNameField.stringValue = realName;
	} else {
		NSAttributedString *realNameFormatted =
		[realName attributedStringWithIRCFormatting:[NSFont systemFontOfSize:12.0]
								 preferredFontColor:nil
						  honorFormattingPreference:NO];

		userInfoPopover.realNameField.attributedStringValue = realNameFormatted;
	}

	/* =============================================== */

	if (cellItem.user.isAway) {
		userInfoPopover.awayStatusField.stringValue = TXTLS(@"TVCMainWindow[jkr-ed]");
	} else {
		userInfoPopover.awayStatusField.stringValue = TXTLS(@"TVCMainWindow[gi6-wf]");
	}

	/* =============================================== */

	IRCUserRank userRank = cellItem.rank;

	if (cellItem.user.isIRCop) {
		userRank = IRCUserRankIRCopByMode;
	}

	NSString *userPrivileges = nil;

	if (userRank == IRCUserRankIRCopByMode) {
		userPrivileges = TXTLS(@"TVCMainWindow[i8t-vb]");
	} else if (userRank == IRCUserRankChannelOwner) {
		userPrivileges = TXTLS(@"TVCMainWindow[p1z-sc]");
	} else if (userRank == IRCUserRankSuperOperator) {
		userPrivileges = TXTLS(@"TVCMainWindow[som-zo]");
	} else if (userRank == IRCUserRankNormalOperator) {
		userPrivileges = TXTLS(@"TVCMainWindow[0kn-s5]");
	} else if (userRank == IRCUserRankHalfOperator) {
		userPrivileges = TXTLS(@"TVCMainWindow[0nn-te]");
	} else if (userRank == IRCUserRankVoiced) {
		userPrivileges = TXTLS(@"TVCMainWindow[ya1-sk]");
	} else {
		userPrivileges = TXTLS(@"TVCMainWindow[tjj-z2]");
	}

	userInfoPopover.privilegesField.stringValue = userPrivileges;

	/* =============================================== */

	NSInteger rowIndex = [memberList rowForView:self];

	NSRect cellFrame = [memberList frameOfCellAtColumn:0 row:rowIndex];

	/* Presenting the popover will steal focus. To workaround this,
	 we record the active first responder then set it back. */
	NSWindow *window = self.window;

	NSResponder *activeFirstResponder = window.firstResponder;

	[userInfoPopover showRelativeToRect:cellFrame
								 ofView:memberList
						  preferredEdge:NSMaxXEdge];

	[window makeFirstResponder:activeFirstResponder];
}

- (TVCMemberListRowCell *)rowCell
{
	return (id)self.superview;
}

- (IRCChannelUser *)cellItem
{
	return self.objectValue;
}

- (TVCMemberList *)memberList
{
	return self.rowCell.memberList;
}

- (TVCMemberListAppearance *)userInterfaceObjects
{
	return self.rowCell.userInterfaceObjects;
}

- (TVCMemberListCellDrawingContext *)drawingContext
{
	TVCMemberList *memberList = self.memberList;

	NSInteger rowIndex = [memberList rowForView:self];

	TVCMemberListAppearance *appearance = self.userInterfaceObjects;

	TVCMemberListCellDrawingContext *drawingContext = [TVCMemberListCellDrawingContext new];

	TVCMainWindow *mainWindow = self.mainWindow;

	drawingContext.isInverted = appearance.isDarkAppearance;
	drawingContext.isSelected = [memberList isRowSelected:rowIndex];
	drawingContext.isWindowActive = mainWindow.isActiveForDrawing;

	return drawingContext;
}

@end

@implementation TVCMemberListCellDrawingContext
@end

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
