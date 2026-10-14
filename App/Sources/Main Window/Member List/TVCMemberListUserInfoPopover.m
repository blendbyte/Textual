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
@end

@implementation TVCMemberListUserInfoPopover

/* Added in code, like the other rows: a label and a value in the grid */
- (NSTextField *)accountField
{
	if (self.accountFieldStorage) {
		return self.accountFieldStorage;
	}

	NSTextField *realNameField = self.realNameField;

	NSGridView *grid = (NSGridView *)realNameField.superview;

	NSTextField *valueField = [NSTextField labelWithString:@""];

	/* Looks like the other values */
	valueField.font = realNameField.font;
	valueField.textColor = realNameField.textColor;
	valueField.lineBreakMode = NSLineBreakByTruncatingTail;

	self.accountFieldStorage = valueField;

	if ([grid isKindOfClass:[NSGridView class]] == NO) {
		return valueField;
	}

	NSInteger realNameRow = [grid indexOfRow:[grid cellForView:realNameField].row];

	NSTextField *realNameLabel = (NSTextField *)[grid cellAtColumnIndex:0 rowIndex:realNameRow].contentView;

	NSTextField *labelField = [NSTextField labelWithString:TXTLS(@"TVCMainWindow[acc-l1]")];

	labelField.font = realNameLabel.font;
	labelField.textColor = realNameLabel.textColor;
	labelField.alignment = NSTextAlignmentRight;

	valueField.accessibilityTitleUIElement = labelField;

	[grid insertRowAtIndex:(realNameRow + 1) withViews:@[labelField, valueField]];

	return valueField;
}

- (void)mouseDown:(NSEvent *)event
{
	[self close];
}

@end

NS_ASSUME_NONNULL_END
