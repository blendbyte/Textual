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

#import "TXGlobalModels.h"
#import "NSViewHelper.h"
#import "TLOLocalization.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "TDCChannelSpotlightAppearancePrivate.h"
#import "TDCChannelSpotlightControllerInternal.h"
#import "TDCChannelSpotlightSearchResultPrivate.h"
#import "TDCChannelSpotlightSearchResultsTablePrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCChannelSpotlightSearchResultRowView ()
@property (nonatomic, weak) TDCChannelSpotlightController *controller;
@property (nonatomic, weak) TDCChannelSpotlightSearchResultCellView *childCell;
@property (readonly) TDCChannelSpotlightAppearance *userInterfaceObjects;
@end

@interface TDCChannelSpotlightSearchResultCellView ()
@property (readonly, copy) NSAttributedString *channelName;
@property (readonly, copy) NSString *keyboardShortcut;
@property (readonly, copy) NSString *unreadCountDescription;
@property (nonatomic, weak) IBOutlet NSTextField *channelNameField;
@property (nonatomic, weak) IBOutlet NSTextField *keyboardShortcutField;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *keyboardShortcutFieldOffsetConstraint;
@property (nonatomic, weak) IBOutlet NSTextField *unreadCountDescriptionField;
@property (nonatomic, assign) BOOL staticLabelsPopulated;
@property (readonly) TDCChannelSpotlightAppearance *userInterfaceObjects;
@property (readonly) TDCChannelSpotlightController *controller;
@property (readonly) TDCChannelSpotlightSearchResultRowView *rowCell;
@end

@implementation TDCChannelSpotlightSearchResultCellView

- (BOOL)wantsLayer
{
	return YES;
}

- (NSViewLayerContentsRedrawPolicy)layerContentsRedrawPolicy
{
	return NSViewLayerContentsRedrawOnSetNeedsDisplay;
}

- (void)setInitialValues
{
	[self channelNameChanged];
}

- (void)updateLayer
{
	[self updateAppearance];

	[self keyboardShortcutChanged];
}

- (void)updateAppearance
{
	TDCChannelSpotlightSearchResultRowView *rowCell = self.rowCell;

	[self updateTextFieldTextColorIsSelected:rowCell.isSelected];
}

- (void)updateTextFieldTextColorIsSelected:(BOOL)isSelected
{
	TDCChannelSpotlightAppearance *appearance = self.userInterfaceObjects;
	
	if (isSelected == NO)
	{
		self.channelNameField.textColor = appearance.searchResultChannelNameTextColor;

		self.unreadCountDescriptionField.textColor = appearance.searchResultChannelDescriptionTextColor;

		self.keyboardShortcutField.textColor = appearance.searchResultKeyboardShortcutTextColor;
		self.keyboardShortcutFieldOffsetConstraint.constant = appearance.searchResultKeyboardShortcutDeselectedOffset;
	}
	else
	{
		NSColor *selectedTextColor = appearance.searchResultSelectedTextColor;

		self.channelNameField.textColor = selectedTextColor;

		self.unreadCountDescriptionField.textColor = selectedTextColor;

		self.keyboardShortcutField.textColor = selectedTextColor;
		self.keyboardShortcutFieldOffsetConstraint.constant = appearance.searchResultKeyboardShortcutSelectedOffset;
	}
}

- (NSAttributedString *)channelName
{
	TDCChannelSpotlightSearchResult *searchResult = self.objectValue;

	if (searchResult == nil) {
		return [NSAttributedString attributedString];
	}

	static NSMutableParagraphStyle *paragraphStyle = nil;

	if (paragraphStyle == nil) {
		paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

		paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
	}

	NSString *channelName = searchResult.channel.name;

	NSFont *channelNameFieldFont = self.channelNameField.font;

	NSMutableAttributedString *resultString =
	[NSMutableAttributedString
	 mutableAttributedStringWithString:TXTLS(@"TDCChannelSpotlightController[jpw-cj]", channelName)
							attributes:@{
								NSFontAttributeName : channelNameFieldFont,
								NSParagraphStyleAttributeName : paragraphStyle
							}];

	TDCChannelSpotlightController *controller = self.controller;

	NSString *searchString = controller.searchString;

	[resultString.string
	 enumerateFirstOccurrenceOfCharactersInString:searchString
										withBlock:^(NSRange range, BOOL *stop) {
											NSFont *boldFont = [RZFontManager() convertFont:channelNameFieldFont toHaveTrait:NSBoldFontMask];

											[resultString addAttribute:NSFontAttributeName value:boldFont range:range];
										} options:NSCaseInsensitiveSearch];

	NSString *networkName = searchResult.channel.associatedClient.networkNameAlt;

	[resultString appendString:TXTLS(@"TDCChannelSpotlightController[z68-5q]", networkName)];

	return resultString;
}

- (void)channelNameChanged
{
	[self willChangeValueForKey:@"channelName"];
	[self didChangeValueForKey:@"channelName"];
}

- (NSString *)keyboardShortcut
{
	TDCChannelSpotlightSearchResult *searchResult = self.objectValue;

	if (searchResult == nil) {
		return @"";
	}

	TDCChannelSpotlightController *controller = self.controller;

	NSArray *searchResults = controller.searchResultsFiltered;

	NSUInteger searchResultIndex = [searchResults indexOfObjectIdenticalTo:searchResult];

	if (searchResultIndex == controller.selectedSearchResult) {
		return @"↩︎";
	}

	if (searchResultIndex > 9) {
		return @"";
	}

	NSUInteger keyboardShortcutIndex = (searchResultIndex + 1);

	if (keyboardShortcutIndex == 10) {
		keyboardShortcutIndex = 0;
	}

	return [NSString stringWithFormat:@"⌘%lu", keyboardShortcutIndex];
}

- (void)keyboardShortcutChanged
{
	[self willChangeValueForKey:@"keyboardShortcut"];
	[self didChangeValueForKey:@"keyboardShortcut"];
}

- (NSString *)unreadCountDescription
{
	TDCChannelSpotlightSearchResult *searchResult = self.objectValue;

	if (searchResult == nil) {
		return @"";
	}

	NSUInteger nicknameHighlightCount = searchResult.channel.nicknameHighlightCount;

	NSString *nicknameHighlightCountDescription = nil;

	if (nicknameHighlightCount == 1) {
		nicknameHighlightCountDescription = TXTLS(@"TDCChannelSpotlightController[0lz-oh]",TXFormattedNumber(nicknameHighlightCount));
	} else {
		nicknameHighlightCountDescription = TXTLS(@"TDCChannelSpotlightController[c4u-21]", TXFormattedNumber(nicknameHighlightCount));
	}

	NSUInteger unreadCount = searchResult.channel.treeUnreadCount;

	NSString *unreadCountDescription = nil;

	if (unreadCount == 1) {
		unreadCountDescription = TXTLS(@"TDCChannelSpotlightController[43s-x4]", TXFormattedNumber(unreadCount));
	} else {
		unreadCountDescription = TXTLS(@"TDCChannelSpotlightController[vzj-30]", TXFormattedNumber(unreadCount));
	}

	return TXTLS(@"TDCChannelSpotlightController[et7-c5]", nicknameHighlightCountDescription, unreadCountDescription);
}

- (void)unreadCountDescriptionChanged
{
	[self willChangeValueForKey:@"unreadCountDescription"];
	[self didChangeValueForKey:@"unreadCountDescription"];
}

- (TDCChannelSpotlightSearchResultRowView *)rowCell
{
	return (id)self.superview;
}

- (TDCChannelSpotlightAppearance *)userInterfaceObjects
{
	return self.rowCell.userInterfaceObjects;
}

- (TDCChannelSpotlightController *)controller
{
	return self.rowCell.controller;
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];

	TDCChannelSpotlightSearchResult *searchResult = self.objectValue;

	IRCChannel *channel = searchResult.channel;

	if (self.window == nil)
	{
		[channel removeObserver:self forKeyPath:@"nicknameHighlightCount"];
		[channel removeObserver:self forKeyPath:@"treeUnreadCount"];
	}
	else
	{
		[channel addObserver:self forKeyPath:@"nicknameHighlightCount" options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew) context:nil];
		[channel addObserver:self forKeyPath:@"treeUnreadCount" options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew) context:nil];

		[self setInitialValues];
	}
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSString *, id> *)change context:(nullable void *)context
{
	if ([keyPath isEqualToString:@"nicknameHighlightCount"] ||
		[keyPath isEqualToString:@"treeUnreadCount"])
	{
		[self unreadCountDescriptionChanged];
	}
}

@end

#pragma mark -

@implementation TDCChannelSpotlightSearchResultRowView

- (instancetype)initWithController:(TDCChannelSpotlightController *)controller
{
	NSParameterAssert(controller != nil);

	if ((self = [super initWithFrame:NSZeroRect])) {
		self.controller = controller;

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

	BOOL isWindowActive = self.window.isActiveForDrawing;

	TDCChannelSpotlightAppearance *appearance = self.userInterfaceObjects;

	NSColor *selectionColor = nil;

	if (isWindowActive) {
		selectionColor = appearance.searchResultRowSelectionColorActiveWindow;
	} else {
		selectionColor = appearance.searchResultRowSelectionColorInactiveWindow;
	} // isWindowActive

	if (selectionColor) {
		[selectionColor set];

		NSRect selectionRect = self.bounds;

		NSRectFill(selectionRect);
	} else {
		[super drawSelectionInRect:dirtyRect];
	} // selectionColor
}

- (BOOL)isEmphasized
{
	TDCChannelSpotlightAppearance *appearance = self.userInterfaceObjects;

	NSWindow *window = self.window;

	return (appearance.searchResultRowEmphasized &&
			(window == nil || window.isKeyWindow));
}

- (nullable TDCChannelSpotlightSearchResultCellView *)childCell
{
	if (self->_childCell == nil) {
		if (self.numberOfColumns == 0) {
			return nil;
		}

		self->_childCell = [self viewAtColumn:0];
	}

	return self->_childCell;
}

- (TDCChannelSpotlightAppearance *)userInterfaceObjects
{
	return self.controller.userInterfaceObjects;
}

@end

NS_ASSUME_NONNULL_END
