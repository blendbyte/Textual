/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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
#import "TLOLocalization.h"
#import "TVCValidatedTextField.h"
#import "TDCAddressBookSheetInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCAddressBookIgnoreSheet ()
@property (nonatomic, strong) IBOutlet TVCValidatedTextField *ignoreEntryHostmaskTextField;
@property (nonatomic, strong) IBOutlet NSTextField *limitedToChannelsTextField;
@property (nonatomic, strong) IBOutlet NSButton *ignoreClientToClientProtocolCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignoreFileTransferRequestsCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignoreGeneralEventMessagesCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignoreInlineMediaCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignoreNoticeMessagesCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignorePrivateMessageHighlightsCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignorePrivateMessagesCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignorePublicMessageHighlightsCheck;
@property (nonatomic, strong) IBOutlet NSButton *ignorePublicMessagesCheck;
@end

@implementation TDCAddressBookIgnoreSheet

- (void)prepareInitialState
{
	self.ignoreEntryHostmaskTextField.stringValueIsInvalidOnEmpty = YES;
	self.ignoreEntryHostmaskTextField.stringValueUsesOnlyFirstToken = YES;

	self.ignoreEntryHostmaskTextField.validationBlock = ^NSString *(NSString *currentValue) {
		/* $a:account follows a services account */
		if (currentValue.length > 3 && [currentValue.lowercaseString hasPrefix:@"$a:"]) {
			return nil;
		}

		NSString *valueWithoutWildcard = [currentValue stringByReplacingOccurrencesOfString:@"*" withString:@"-"];

		if (valueWithoutWildcard.isHostmask == NO) {
			return TXTLS(@"TDCAddressBookSheet[csu-bv]");
		}

		return nil;
	};
}

- (void)loadConfig
{
	self.ignoreEntryHostmaskTextField.stringValue = self.config.hostmask;

	self.limitedToChannelsTextField.stringValue = [self.config.limitedToChannels componentsJoinedByString:@" "];

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

- (void)saveConfig
{
	self.config.hostmask = self.ignoreEntryHostmaskTextField.value;

	/* Channel names, separated by spaces or commas (which a name can't contain) */
	NSMutableArray<NSString *> *limitedToChannels = [NSMutableArray array];

	for (NSString *channelName in [self.limitedToChannelsTextField.stringValue componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ,\t"]]) {
		if (channelName.length > 0 && [limitedToChannels containsObjectIgnoringCase:channelName] == NO) {
			[limitedToChannels addObject:channelName];
		}
	}

	self.config.limitedToChannels = limitedToChannels;

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

- (TVCValidatedTextField *)entryTextField
{
	return self.ignoreEntryHostmaskTextField;
}

@end

NS_ASSUME_NONNULL_END
