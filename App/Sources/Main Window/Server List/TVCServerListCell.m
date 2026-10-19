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
#import "IRCClientPrivate.h"
#import "IRCChannel.h"
#import "IRCClientConfig.h"
#import "IRCChannelConfig.h"
#import "TVCMainWindow.h"
#import "TVCServerListAppearancePrivate.h"
#import "TVCServerListPrivate.h"
#import "TVCServerListCellInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCServerListCellDrawingContext : NSObject
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, assign) BOOL isGroupItem;
@property (nonatomic, assign) BOOL isInverted;
@property (nonatomic, assign) BOOL isSelected;
@property (nonatomic, assign) BOOL isSelectedFrontmost;
@property (nonatomic, assign) BOOL isWindowActive;
@end

@implementation TVCServerListCell

#pragma mark -
#pragma mark Cell Drawing

- (void)defineConstraints
{

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
	TVCServerListCellDrawingContext *drawingContext = self.drawingContext;

	[self updateTextFieldInContext:drawingContext];

	TVCServerListAppearance *appearance = self.userInterfaceObjects;

	[self updateDrawingForWithAppearance:appearance inContext:drawingContext];

	[self updateAccessibilityInContext:drawingContext];
}

/* What VoiceOver reads for the row: kind, joined or connected state,
 a failed join, and the unread and highlight counts the badge shows */
- (void)updateAccessibilityInContext:(TVCServerListCellDrawingContext *)drawingContext
{
	NSParameterAssert(drawingContext != nil);

	IRCTreeItem *cellItem = self.cellItem;

	NSString *label = cellItem.label;

	BOOL isActive = drawingContext.isActive;

	NSMutableArray<NSString *> *components = [NSMutableArray array];

	if (drawingContext.isGroupItem) {
		if (isActive) {
			[components addObject:TXTLS(@"Accessibility[bmy-d2]", label)];
		} else {
			[components addObject:TXTLS(@"Accessibility[tu4-8u]", label)];
		} // isActive
	} else {
		IRCChannel *channel = (IRCChannel *)cellItem;

		if (channel.isChannel == NO) {
			[components addObject:TXTLS(@"Accessibility[9sn-xp]", label)];
		} else if (isActive) {
			[components addObject:TXTLS(@"Accessibility[75f-og]", label)];
		} else {
			[components addObject:TXTLS(@"Accessibility[edc-7o]", label)];
		} // isChannel

		if (channel.errorOnLastJoinAttempt) {
			[components addObject:TXTLS(@"Accessibility[s5c-e1]")];
		}

		NSUInteger unreadCount = channel.treeUnreadCount;

		if (unreadCount == 1) {
			[components addObject:TXTLS(@"Accessibility[s5c-u2]")];
		} else if (unreadCount > 1) {
			[components addObject:TXTLS(@"Accessibility[s5c-u3]", unreadCount)];
		}

		NSUInteger highlightCount = ((channel.config.ignoreHighlights) ? 0 : channel.nicknameHighlightCount);

		if (highlightCount == 1) {
			[components addObject:TXTLS(@"Accessibility[s5c-h4]")];
		} else if (highlightCount > 1) {
			[components addObject:TXTLS(@"Accessibility[s5c-h5]", highlightCount)];
		}

		/* The status icon and the badge are part of the description
		 (controls are exposed through their cells) */
		[self.imageView.cell setAccessibilityElement:NO];
		[self.messageCountBadgeImageView.cell setAccessibilityElement:NO];
	} // isGroupItem

	NSString *description = [components componentsJoinedByString:@", "];

	/* The row is one element for VoiceOver, read with this label
	 (it reads a text field's text, not a value description) */
	self.accessibilityElement = YES;
	self.accessibilityRole = NSAccessibilityCellRole;

	if ([self.accessibilityLabel isEqualToString:description] == NO) {
		self.accessibilityLabel = description;
	}

	[self.cellTextField.cell setAccessibilityElement:NO];
}

- (void)updateTextFieldInContext:(TVCServerListCellDrawingContext *)drawingContext
{
	NSParameterAssert(drawingContext != nil);

	/* Update string value */
	IRCTreeItem *cellItem = self.cellItem;

	NSString *stringValueNew = cellItem.label;

	NSTextField *textField = self.cellTextField;

	NSString *stringValueOld = textField.stringValue;

	if ([stringValueOld isEqualTo:stringValueNew]) {
		return;
	}

	textField.stringValue = stringValueNew;
}

- (void)updateDrawingForWithAppearance:(TVCServerListAppearance *)appearance inContext:(TVCServerListCellDrawingContext *)drawingContext
{
	NSParameterAssert(appearance != nil);
	NSParameterAssert(drawingContext != nil);

	BOOL isActive = drawingContext.isActive;
	BOOL isGroupItem = drawingContext.isGroupItem;
	BOOL isSelected = drawingContext.isSelected;
	BOOL isWindowActive = drawingContext.isWindowActive;

	if (isGroupItem == NO) {
		IRCTreeItem *cellItem = self.cellItem;

		IRCChannel *channel = (IRCChannel *)cellItem;

		NSString *iconName = nil;

		BOOL iconIsTemplate = NO;

		if (channel.isChannel) {
			iconName = [appearance statusIconForActiveChannel:isActive selected:isSelected activeWindow:isWindowActive treatAsTemplate:&iconIsTemplate];
		} else {
			iconName = [appearance statusIconForActiveQuery:isActive selected:isSelected activeWindow:isWindowActive treatAsTemplate:&iconIsTemplate];
		} // isChannel

		NSImage *icon = [NSImage imageNamed:iconName];

		icon.template = iconIsTemplate;

		self.imageView.image = icon;
	}

	NSAttributedString *newValue = [self attributedTextFieldValueWithAppearance:appearance inContext:drawingContext];

	self.cellTextField.attributedStringValue = newValue;

	/* Muted: dimmed, and so are the channels of a muted network.
	 The views fade rather than the text color, which an inactive window
	 drew at full strength. */
	IRCTreeItem *mutedItem = self.cellItem;

	BOOL isMuted = mutedItem.associatedClient.config.muted;

	if (isGroupItem == NO && isMuted == NO) {
		isMuted = ((IRCChannel *)mutedItem).config.muted;
	}

	CGFloat alphaValue = ((isMuted && isSelected == NO) ? 0.45 : 1.0);

	self.cellTextField.alphaValue = alphaValue;

	self.imageView.alphaValue = alphaValue;

	if (isGroupItem == NO) {
		[self populateMessageCountBadgeWithAppearance:appearance inContext:drawingContext];
	}
}

- (NSAttributedString *)attributedTextFieldValueWithAppearance:(TVCServerListAppearance *)appearance inContext:(TVCServerListCellDrawingContext *)drawingContext
{
	NSParameterAssert(appearance != nil);
	NSParameterAssert(drawingContext != nil);

	BOOL isActive = drawingContext.isActive;
	BOOL isGroupItem = drawingContext.isGroupItem;
	BOOL isSelected = drawingContext.isSelected;
	BOOL isWindowActive = drawingContext.isWindowActive;

	IRCTreeItem *cellItem = self.cellItem;

	BOOL isErroneous = NO;

	BOOL isHighlight = NO;

	if (isGroupItem == NO) {
		IRCChannel *associatedChannel = (id)cellItem;

		isErroneous = associatedChannel.errorOnLastJoinAttempt;

		isHighlight = (associatedChannel.nicknameHighlightCount > 0);
	}

	NSTextField *textField = self.cellTextField;

	NSAttributedString *stringValue = textField.attributedStringValue;

	NSMutableAttributedString *mutableStringValue = [stringValue mutableCopy];

	[mutableStringValue beginEditing];

	NSFont *controlFont = nil;

	NSColor *controlColor = nil;

	if (isGroupItem)
	{
		if (isSelected) {
			controlFont = appearance.serverFontSelected;
		} else {
			controlFont = appearance.serverFont;
		} // isSelected

		if (isSelected) {
			if (isWindowActive) {
				controlColor = appearance.serverSelectedTextColorActiveWindow;
			} else {
				controlColor = appearance.serverSelectedTextColorInactiveWindow;
			} // isWindowActive
		} else if (isActive) {
			if (isWindowActive) {
				controlColor = appearance.serverTextColorActiveWindow;
			} else {
				controlColor = appearance.serverTextColorInactiveWindow;
			} // isWindowActive
		} else {
			if (isWindowActive) {
				controlColor = appearance.serverDisabledTextColorActiveWindow;
			} else {
				controlColor = appearance.serverDisabledTextColorInactiveWindow;
			} // isWindowActive
		}
	}
	else // isGroupItem
	{
		if (isSelected) {
			controlFont = appearance.channelFontSelected;
		} else {
			controlFont = appearance.channelFont;
		} // isSelected

		if (isSelected) {
			if (isWindowActive) {
				controlColor = appearance.channelSelectedTextColorActiveWindow;
			} else {
				controlColor = appearance.channelSelectedTextColorInactiveWindow;
			} // isWindowActive
		} else if (isActive && isHighlight) {
			NSColor *customColor = appearance.unreadBadgeHighlightBackgroundColorByUser;

			if (customColor && [customColor isEqual:[NSColor clearColor]] == NO) {
				controlColor = customColor;
			} else {
				if (isWindowActive) {
					controlColor = appearance.channelHighlightTextColorActiveWindow;
				} else {
					controlColor = appearance.channelHighlightTextColorInactiveWindow;
				} // isWindowActive
			} // custom color set
		} else if (isActive) {
			if (isWindowActive) {
				controlColor = appearance.channelTextColorActiveWindow;
			} else {
				controlColor = appearance.channelTextColorInactiveWindow;
			} // isWindowActive
		} else if (isErroneous) {
			if (isWindowActive) {
				controlColor = appearance.channelErroneousTextColorActiveWindow;
			} else {
				controlColor = appearance.channelErroneousTextColorInactiveWindow;
			} // isWindowActive
		} else {
			if (isWindowActive) {
				controlColor = appearance.channelDisabledTextColorActiveWindow;
			} else {
				controlColor = appearance.channelDisabledTextColorInactiveWindow;
			} // isWindowActive
		}
	} // isGroupItem

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

- (void)populateMessageCountBadge
{
	TVCServerListAppearance *appearance = self.userInterfaceObjects;

	TVCServerListCellDrawingContext *drawingContext = self.drawingContext;

	[self populateMessageCountBadgeWithAppearance:appearance inContext:drawingContext];

	[self updateAccessibilityInContext:drawingContext];
}

- (void)populateMessageCountBadgeWithAppearance:(TVCServerListAppearance *)appearance inContext:(TVCServerListCellDrawingContext *)drawingContext
{
	NSParameterAssert(appearance != nil);
	NSParameterAssert(drawingContext != nil);

	BOOL isSelected = drawingContext.isSelected;
	BOOL isSelectedFrontmost = drawingContext.isSelectedFrontmost;
	BOOL isWindowActive = drawingContext.isWindowActive;
	BOOL multipleRowsSelected = (self.serverList.numberOfSelectedRows > 1);

	IRCChannel *associatedChannel = (id)self.cellItem;

	BOOL drawMessageBadge = (isSelected == NO ||
							(isSelectedFrontmost == NO && isSelected && multipleRowsSelected) ||
							(isWindowActive == NO && isSelected));

	if (associatedChannel.config.showTreeBadgeCount == NO) {
		drawMessageBadge = NO;
	}

	NSUInteger treeUnreadCount = associatedChannel.treeUnreadCount;
	NSUInteger nicknameHighlightCount = associatedChannel.nicknameHighlightCount;

	BOOL isHighlight = (nicknameHighlightCount > 0);

	if (associatedChannel.config.ignoreHighlights) {
		isHighlight = NO;
	}

	/* Begin draw if we want to. */
	if (treeUnreadCount > 0 && drawMessageBadge) {
		NSAttributedString *stringToDraw = [self messageCountBadgeTextForCount:treeUnreadCount isHighlight:isHighlight withAppearance:appearance inContext:drawingContext];

		NSRect badgeRect = [self messageCountBadgeRectForText:stringToDraw withAppearance:appearance inContext:drawingContext];

		[self drawMessageCountBadgeWithString:stringToDraw inRect:badgeRect isHighlight:isHighlight withAppearance:appearance inContext:drawingContext];

		self.messageCountBadgeLeadingConstraint.active = YES;
		self.messageCountBadgeTrailingConstraint.active = YES;
	} else {
		self.messageCountBadgeImageView.image = nil;

		/* Disable constraints when badge is not visible to
		 allow text field to hug the right of the table view. */
		self.messageCountBadgeLeadingConstraint.active = NO;
		self.messageCountBadgeTrailingConstraint.active = NO;
	}
}

- (NSAttributedString *)messageCountBadgeTextForCount:(NSUInteger)messageCount isHighlight:(BOOL)isHighlight withAppearance:(TVCServerListAppearance *)appearance inContext:(TVCServerListCellDrawingContext *)drawingContext
{
	NSParameterAssert(appearance != nil);
	NSParameterAssert(drawingContext != nil);

	BOOL isSelected = drawingContext.isSelected;
	BOOL isWindowActive = drawingContext.isWindowActive;

	NSString *messageCountString = TXFormattedNumber(messageCount);

	NSFont *controlFont = nil;

	if (isSelected) {
		controlFont = appearance.unreadBadgeFontSelected;
	} else {
		controlFont = appearance.unreadBadgeFont;
	} // isSelected

	NSColor *controlColor = nil;

	if (isSelected) {
		if (isWindowActive) {
			controlColor = appearance.unreadBadgeSelectedTextColorActiveWindow;
		} else {
			controlColor = appearance.unreadBadgeSelectedTextColorInactiveWindow;
		} // isWindowActive
	} else if (isHighlight) {
		if (isWindowActive) {
			controlColor = appearance.unreadBadgeHighlightTextColorActiveWindow;
		} else {
			controlColor = appearance.unreadBadgeHighlightTextColorInactiveWindow;
		} // isWindowActive
	} else {
		if (isWindowActive) {
			controlColor = appearance.unreadBadgeTextColorActiveWindow;
		} else {
			controlColor = appearance.unreadBadgeTextColorInactiveWindow;
		} // isWindowActive
	}

	NSDictionary *attributes = @{NSForegroundColorAttributeName : controlColor, NSFontAttributeName : controlFont};

	NSAttributedString *stringToDraw = [NSAttributedString attributedStringWithString:messageCountString attributes:attributes];

	return stringToDraw;
}

- (NSRect)messageCountBadgeRectForText:(NSAttributedString *)stringToDraw withAppearance:(TVCServerListAppearance *)appearance inContext:(TVCServerListCellDrawingContext *)drawingContext
{
	NSParameterAssert(appearance != nil);
	NSParameterAssert(drawingContext != nil);

	CGFloat messageCountWidth = (stringToDraw.size.width + (appearance.unreadBadgePadding * 2.0));

	NSRect badgeFrame = NSMakeRect(0.0, 0.0, messageCountWidth, appearance.unreadBadgeHeight);

	CGFloat minimumWidth = appearance.unreadBadgeMinimumWidth;

	if (badgeFrame.size.width < minimumWidth) {
		CGFloat widthDiff  = (minimumWidth - badgeFrame.size.width);

		badgeFrame.size.width += widthDiff;

		badgeFrame.origin.x -= widthDiff;
	}

	return badgeFrame;
}

- (void)drawMessageCountBadgeWithString:(NSAttributedString *)stringToDraw inRect:(NSRect)rectToDraw isHighlight:(BOOL)isHighlight withAppearance:(TVCServerListAppearance *)appearance inContext:(TVCServerListCellDrawingContext *)drawingContext
{
	NSParameterAssert(appearance != nil);
	NSParameterAssert(drawingContext != nil);

	BOOL isSelected = drawingContext.isSelected;
	BOOL isWindowActive = drawingContext.isWindowActive;

	/* Decide the background color */
	NSColor *backgroundColor = nil;

	if (isSelected) {
		if (isWindowActive) {
			backgroundColor = appearance.unreadBadgeSelectedBackgroundColorActiveWindow;
		} else {
			backgroundColor = appearance.unreadBadgeSelectedBackgroundColorInactiveWindow;
		} // isWindowActive
	} else if (isHighlight) {
		NSColor *customColor = appearance.unreadBadgeHighlightBackgroundColorByUser;

		if (customColor && [customColor isEqual:[NSColor clearColor]] == NO) {
			backgroundColor = customColor;
		} else {
			if (isWindowActive) {
				backgroundColor = appearance.unreadBadgeHighlightBackgroundColorActiveWindow;
			} else {
				backgroundColor = appearance.unreadBadgeHighlightBackgroundColorInactiveWindow;
			} // isWindowActive
		} // custom color set
	} else {
		if (isWindowActive) {
			backgroundColor = appearance.unreadBadgeBackgroundColorActiveWindow;
		} else {
			backgroundColor = appearance.unreadBadgeBackgroundColorInactiveWindow;
		} // isWindowActive
	}

	self.messageCountBadgeImageView.image =
	[TVCListBadge imageWithSize:rectToDraw.size
				   cornerRadius:7.0
				backgroundColor:backgroundColor
						 string:stringToDraw];
}

#pragma mark -
#pragma mark Cell Information

- (BOOL)isGroupItem
{
	return [self isKindOfClass:[TVCServerListCellGroupItem class]];
}

- (__kindof TVCServerListRowCell *)rowCell
{
	return (id)self.superview;
}

- (IRCTreeItem *)cellItem
{
	return self.objectValue;
}

- (TVCServerList *)serverList
{
	return self.rowCell.serverList;
}

- (TVCServerListAppearance *)userInterfaceObjects
{
	return self.rowCell.userInterfaceObjects;
}

- (TVCServerListCellDrawingContext *)drawingContext
{
	TVCServerList *serverList = self.serverList;

	TVCServerListAppearance *appearance = self.userInterfaceObjects;

	IRCTreeItem *cellItem = self.cellItem;

	NSInteger rowIndex = [serverList rowForItem:cellItem];

	TVCMainWindow *mainWindow = self.mainWindow;

	TVCServerListCellDrawingContext *drawingContext = [TVCServerListCellDrawingContext new];

	drawingContext.isActive = cellItem.isActive;
	drawingContext.isGroupItem = self.isGroupItem;
	drawingContext.isInverted = appearance.isDarkAppearance;
	drawingContext.isSelected = [serverList isRowSelected:rowIndex];
	drawingContext.isSelectedFrontmost = [mainWindow isItemSelected:cellItem];
	drawingContext.isWindowActive = mainWindow.isActiveForDrawing;

	return drawingContext;
}

- (BOOL)needsDisplayWhenApplicationAppearanceChanges
{
	return NO;
}

- (BOOL)needsDisplayWhenSystemAppearanceChanges
{
	return NO;
}

@end

@implementation TVCServerListCellGroupItem

/* The network's icon (draft/ICON) goes in front of the name */
#define _networkIconSize		16.0
#define _networkIconSpacing		5.0

- (void)defineConstraints
{
	TVCServerListAppearance *appearance = self.userInterfaceObjects;

	CGFloat leftMargin = appearance.serverLabelLeftMargin;

	NSImageView *iconView = self.networkIconView;

	if (iconView && iconView.hidden == NO) {
		leftMargin += (_networkIconSize + _networkIconSpacing);
	}

	self.cellTextFieldLeftMarginConstraint.constant = leftMargin;
}

- (void)updateDrawingForWithAppearance:(TVCServerListAppearance *)appearance inContext:(TVCServerListCellDrawingContext *)drawingContext
{
	[super updateDrawingForWithAppearance:appearance inContext:drawingContext];

	[self updateNetworkIconWithAppearance:appearance inContext:drawingContext];
}

- (void)updateNetworkIconWithAppearance:(TVCServerListAppearance *)appearance inContext:(TVCServerListCellDrawingContext *)drawingContext
{
	NSImage *icon = ((IRCClient *)self.cellItem).networkIcon;

	NSImageView *iconView = self.networkIconView;

	if (icon && iconView == nil) {
		iconView = [NSImageView imageViewWithImage:icon];

		iconView.translatesAutoresizingMaskIntoConstraints = NO;

		iconView.imageScaling = NSImageScaleProportionallyUpOrDown;

		iconView.wantsLayer = YES;
		iconView.layer.cornerRadius = 3.0;
		iconView.layer.masksToBounds = YES;

		/* The row is read as one element */
		[iconView.cell setAccessibilityElement:NO];

		iconView.hidden = YES; // shown below, with the margin

		[self addSubview:iconView];

		[NSLayoutConstraint activateConstraints:@[
			[iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:appearance.serverLabelLeftMargin],
			[iconView.centerYAnchor constraintEqualToAnchor:self.cellTextField.centerYAnchor],
			[iconView.widthAnchor constraintEqualToConstant:_networkIconSize],
			[iconView.heightAnchor constraintEqualToConstant:_networkIconSize]
		]];

		self.networkIconView = iconView;
	}

	BOOL hidden = (icon == nil);

	if (iconView.image != icon) {
		iconView.image = icon;
	}

	/* Faded while disconnected, as the name is */
	CGFloat alphaValue = self.cellTextField.alphaValue;

	if (drawingContext.isActive == NO && drawingContext.isSelected == NO) {
		alphaValue *= 0.5;
	}

	iconView.alphaValue = alphaValue;

	if (iconView && iconView.hidden != hidden) {
		iconView.hidden = hidden;

		[self defineConstraints];
	}
}

- (void)applicationAppearanceChanged
{
	[super defineConstraints];

	[self defineConstraints];
}

@end

@implementation TVCServerListCellChildItem
@end

@implementation TVCServerListCellDrawingContext
@end

NS_ASSUME_NONNULL_END
