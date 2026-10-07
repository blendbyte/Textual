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
#import "TLOLocalization.h"
#import "TVCValidatedTextField.h"
#import "TDCAddressBookSheetPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCAddressBookSheet ()
@property (nonatomic, strong) IRCAddressBookEntryMutable *config;
@property (nonatomic, assign) IRCAddressBookEntryType entryType;
@property (nonatomic, strong) IBOutlet NSButton *ignoreClientToClientProtocolCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignoreFileTransferRequestsCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignoreGeneralEventMessagesCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignoreInlineMediaCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignoreNoticeMessagesCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignorePrivateMessageHighlightsCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignorePrivateMessagesCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignorePublicMessageHighlightsCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignorePublicMessagesCheck;
@property (nonatomic, strong) IBOutlet NSButton *trackUserActivityCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignoreEntrySaveButton;
@property (nonatomic, strong) IBOutlet NSButton *userTrackingEntrySaveButton;
@property (nonatomic, strong) IBOutlet TVCValidatedTextField *ignoreEntryHostmaskTextField;
@property (nonatomic, strong) IBOutlet TVCValidatedTextField *userTrackingEntryNicknameTextField;
@property (nonatomic, strong) IBOutlet NSWindow *ignoreEntryView;
@property (nonatomic, strong) IBOutlet NSWindow *userTrackingEntryView;
@end

@implementation TDCAddressBookSheet

- (instancetype)initWithEntryType:(IRCAddressBookEntryType)entryType
{
	NSParameterAssert(entryType == IRCAddressBookEntryTypeIgnore ||
					  entryType == IRCAddressBookEntryTypeUserTracking);

	if ((self = [super initWithWindow:nil])) {
		if (entryType == IRCAddressBookEntryTypeIgnore) {
			self.config = [IRCAddressBookEntryMutable newIgnoreEntry];
		} else if (entryType == IRCAddressBookEntryTypeUserTracking) {
			self.config = [IRCAddressBookEntryMutable newUserTrackingEntry];
		}

		self.entryType = entryType;

		[self prepareInitialState];

		[self loadConfig];

		return self;
	}

	return nil;
}

- (instancetype)initWithConfig:(IRCAddressBookEntry *)config
{
	NSParameterAssert(config != nil);
	NSParameterAssert(config.entryType == IRCAddressBookEntryTypeIgnore ||
					  config.entryType == IRCAddressBookEntryTypeUserTracking);

	if ((self = [super initWithWindow:nil])) {
		self.config = [config mutableCopy];

		self.entryType = config.entryType;

		[self prepareInitialState];

		[self loadConfig];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCAddressBookSheet" owner:self topLevelObjects:nil];

	self.ignoreEntryHostmaskTextField.stringValueIsInvalidOnEmpty = YES;
	self.ignoreEntryHostmaskTextField.stringValueUsesOnlyFirstToken = YES;

	self.ignoreEntryHostmaskTextField.validationBlock = ^NSString *(NSString *currentValue) {
		NSString *valueWithoutWildcard = [currentValue stringByReplacingOccurrencesOfString:@"*" withString:@"-"];

		if (valueWithoutWildcard.isHostmask == NO) {
			return TXTLS(@"TDCAddressBookSheet[csu-bv]");
		}

		return nil;
	};

	self.userTrackingEntryNicknameTextField.stringValueIsInvalidOnEmpty = YES;
	self.userTrackingEntryNicknameTextField.stringValueUsesOnlyFirstToken = YES;

	self.userTrackingEntryNicknameTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if (currentValue.isHostmaskNickname == NO) {
			return TXTLS(@"CommonErrors[och-j5]");
		}

		return nil;
	};
}

- (void)loadConfig
{
	if (self.entryType == IRCAddressBookEntryTypeIgnore)
	{
		self.ignoreEntryHostmaskTextField.stringValue = self.config.hostmask;

		self.ignoreClientToClientProtocolCheck.state = self.config.ignoreClientToClientProtocol;
		self.ignoreFileTransferRequestsCheck.state = self.config.ignoreFileTransferRequests;
		self.ignoreGeneralEventMessagesCheck.state = self.config.ignoreGeneralEventMessages;
		self.ignoreInlineMediaCheck.state = self.config.ignoreInlineMedia;
		self.ignoreNoticeMessagesCheck.state = self.config.ignoreNoticeMessages;
		self.ignorePrivateMessageHighlightsCheck.state = self.config.ignorePrivateMessageHighlights;
		self.ignorePrivateMessagesCheck.state = self.config.ignorePrivateMessages;
		self.ignorePublicMessageHighlightsCheck.state = self.config.ignorePublicMessageHighlights;
		self.ignorePublicMessagesCheck.state = self.config.ignorePublicMessages;
	}
	else if (self.entryType == IRCAddressBookEntryTypeUserTracking)
	{
		self.userTrackingEntryNicknameTextField.stringValue = self.config.hostmask;

		self.trackUserActivityCheck.state = self.config.trackUserActivity;
	}
}

- (void)start
{
	if (self.entryType == IRCAddressBookEntryTypeIgnore)
	{
		self.sheet = self.ignoreEntryView;

		[self.sheet makeFirstResponder:self.ignoreEntryHostmaskTextField];
	}
	else if (self.entryType == IRCAddressBookEntryTypeUserTracking)
	{
		self.sheet = self.userTrackingEntryView;

		[self.sheet makeFirstResponder:self.userTrackingEntryNicknameTextField];
	}

	[self startSheet];
}

- (void)ok:(id)sender
{
	if ([self okOrError] == NO) {
		return;
	}

	if (self.entryType == IRCAddressBookEntryTypeIgnore)
	{
		self.config.hostmask = self.ignoreEntryHostmaskTextField.value;

		self.config.ignoreClientToClientProtocol = (self.ignoreClientToClientProtocolCheck.state == NSControlStateValueOn);
		self.config.ignoreFileTransferRequests = (self.ignoreFileTransferRequestsCheck.state == NSControlStateValueOn);
		self.config.ignoreGeneralEventMessages = (self.ignoreGeneralEventMessagesCheck.state == NSControlStateValueOn);
		self.config.ignoreInlineMedia = (self.ignoreInlineMediaCheck.state == NSControlStateValueOn);
		self.config.ignoreNoticeMessages = (self.ignoreNoticeMessagesCheck.state == NSControlStateValueOn);
		self.config.ignorePrivateMessageHighlights = (self.ignorePrivateMessageHighlightsCheck.state == NSControlStateValueOn);
		self.config.ignorePrivateMessages = (self.ignorePrivateMessagesCheck.state == NSControlStateValueOn);
		self.config.ignorePublicMessageHighlights = (self.ignorePublicMessageHighlightsCheck.state == NSControlStateValueOn);
		self.config.ignorePublicMessages = (self.ignorePublicMessagesCheck.state == NSControlStateValueOn);
	}
	else if (self.entryType == IRCAddressBookEntryTypeUserTracking)
	{
		self.config.hostmask = self.userTrackingEntryNicknameTextField.value;

		self.config.trackUserActivity = (self.trackUserActivityCheck.state == NSControlStateValueOn);
	}

	if ([self.delegate respondsToSelector:@selector(addressBookSheet:onOk:)]) {
		[self.delegate addressBookSheet:self onOk:[self.config copy]];
	}

	[super ok:nil];
}

- (BOOL)okOrError
{
	if (self.entryType == IRCAddressBookEntryTypeIgnore)
	{
		return [self okOrErrorForTextField:self.ignoreEntryHostmaskTextField];
	}
	else if (self.entryType == IRCAddressBookEntryTypeUserTracking)
	{
		return [self okOrErrorForTextField:self.userTrackingEntryNicknameTextField];
	}

	return NO;
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	if ([self.delegate respondsToSelector:@selector(addressBookSheetWillClose:)]) {
		[self.delegate addressBookSheetWillClose:self];
	}
}

@end

NS_ASSUME_NONNULL_END
