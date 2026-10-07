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

#import "NSObjectHelperPrivate.h"
#import "NSStringHelper.h"
#import "IRCClient.h"
#import "TLOLocalization.h"
#import "TVCValidatedTextField.h"
#import "TDCServerChangeNicknameSheetPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCServerChangeNicknameSheet ()
@property (nonatomic, strong, readwrite) IRCClient *client;
@property (nonatomic, copy, readwrite) NSString *clientId;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *tnewNicknameTextField;
@property (nonatomic, weak) IBOutlet NSTextField *toldNicknameTextField;
@end

@implementation TDCServerChangeNicknameSheet

- (instancetype)initWithClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if ((self = [super initWithWindow:nil])) {
		self.client = client;
		self.clientId = client.uniqueIdentifier;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCServerChangeNicknameSheet" owner:self topLevelObjects:nil];

	self.tnewNicknameTextField.stringValueIsInvalidOnEmpty = YES;
	self.tnewNicknameTextField.stringValueUsesOnlyFirstToken = YES;

	self.tnewNicknameTextField.textDidChangeCallback = self;

	self.tnewNicknameTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if ([currentValue isHostmaskNicknameOn:self.client] == NO) {
			return TXTLS(@"CommonErrors[och-j5]");
		}

		return nil;
	};

	NSString *nickname = self.client.userNickname;

	self.tnewNicknameTextField.stringValue = nickname;

	self.toldNicknameTextField.stringValue = nickname;
}

- (void)start
{
	[self startSheet];

	[self.sheet makeFirstResponder:self.tnewNicknameTextField];
}

- (void)ok:(id)sender
{
	if ([self okOrError] == NO) {
		return;
	}

	if ([self.delegate respondsToSelector:@selector(serverChangeNicknameSheet:didInputNickname:)]) {
		NSString *newNickname = self.tnewNicknameTextField.value;

		[self.delegate serverChangeNicknameSheet:self didInputNickname:newNickname];
	}

	[super ok:sender];
}

- (BOOL)okOrError
{
	return [self okOrErrorForTextField:self.tnewNicknameTextField];
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	if ([self.delegate respondsToSelector:@selector(serverChangeNicknameSheetWillClose:)]) {
		[self.delegate serverChangeNicknameSheetWillClose:self];
	}
}

@end

NS_ASSUME_NONNULL_END
