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

#import "TLOLocalization.h"
#import "TVCMemberListUserInfoPopoverPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCMemberListUserInfoPopover ()
@property (nonatomic, weak, readwrite) IBOutlet NSTextField *nicknameField;
@property (nonatomic, weak, readwrite) IBOutlet NSTextField *usernameField;
@property (nonatomic, weak, readwrite) IBOutlet NSTextField *addressField;
@property (nonatomic, weak, readwrite) IBOutlet NSTextField *realNameField;
@property (nonatomic, weak, readwrite) IBOutlet NSTextField *privilegesField;
@property (nonatomic, weak, readwrite) IBOutlet NSTextField *awayStatusField;
@property (nonatomic, strong, nullable) NSTextField *accountFieldStorage;
@property (nonatomic, strong, nullable) NSGridRow *botRow;
@end

@implementation TVCMemberListUserInfoPopover

/* Added in code, like the other rows: a label and a value in the grid, under
 the row of the field given */
- (nullable NSGridRow *)_insertRowWithLabel:(NSString *)label value:(NSTextField *)valueField belowField:(NSTextField *)field
{
	NSGridView *grid = (NSGridView *)field.superview;

	/* Looks like the other values */
	valueField.font = field.font;
	valueField.textColor = field.textColor;
	valueField.lineBreakMode = NSLineBreakByTruncatingTail;

	if ([grid isKindOfClass:[NSGridView class]] == NO) {
		return nil;
	}

	NSInteger fieldRow = [grid indexOfRow:[grid cellForView:field].row];

	NSTextField *fieldLabel = (NSTextField *)[grid cellAtColumnIndex:0 rowIndex:fieldRow].contentView;

	NSTextField *labelField = [NSTextField labelWithString:label];

	labelField.font = fieldLabel.font;
	labelField.textColor = fieldLabel.textColor;
	labelField.alignment = NSTextAlignmentRight;

	valueField.accessibilityTitleUIElement = labelField;

	return [grid insertRowAtIndex:(fieldRow + 1) withViews:@[labelField, valueField]];
}

- (NSTextField *)accountField
{
	if (self.accountFieldStorage) {
		return self.accountFieldStorage;
	}

	NSTextField *valueField = [NSTextField labelWithString:@""];

	self.accountFieldStorage = valueField;

	(void)[self _insertRowWithLabel:TXTLS(@"TVCMainWindow[acc-l1]") value:valueField belowField:self.realNameField];

	return valueField;
}

- (void)setShowsBot:(BOOL)showsBot
{
	if (showsBot && self.botRow == nil) {
		NSTextField *valueField = [NSTextField labelWithString:TXTLS(@"TVCMainWindow[bot-t2]")];

		self.botRow = [self _insertRowWithLabel:TXTLS(@"TVCMainWindow[bot-t1]") value:valueField belowField:self.nicknameField];
	}

	self.botRow.hidden = (showsBot == NO);
}

- (BOOL)showsBot
{
	return (self.botRow != nil && self.botRow.hidden == NO);
}

- (void)mouseDown:(NSEvent *)event
{
	[self close];
}

@end

NS_ASSUME_NONNULL_END
