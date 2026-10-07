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

#import "IRCClient.h"
#import "TLOLocalization.h"
#import "TDCChannelInviteSheetPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCChannelInviteSheet ()
@property (nonatomic, strong, readwrite) IRCClient *client;
@property (nonatomic, copy, readwrite) NSString *clientId;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *nicknames;
@property (nonatomic, weak) IBOutlet NSTextField *headerTitleTextField;
@property (nonatomic, weak) IBOutlet NSPopUpButton *channelListPopup;
@end

@implementation TDCChannelInviteSheet

- (instancetype)initWithNicknames:(NSArray<NSString *> *)nicknames onClient:(IRCClient *)client
{
	NSParameterAssert(nicknames != nil);
	NSParameterAssert(client != nil);

	if ((self = [super initWithWindow:nil])) {
		self.nicknames = nicknames;

		self.client = client;
		self.clientId = client.uniqueIdentifier;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCChannelInviteSheet" owner:self topLevelObjects:nil];

	NSUInteger nicknameCount = self.nicknames.count;

	NSString *headerTitle = nil;

	if (nicknameCount == 1) {
		headerTitle = self.nicknames[0];
	} else if (nicknameCount == 2) {
		headerTitle = TXTLS(@"TDCChannelInviteSheet[7i1-ds]", self.nicknames[0], self.nicknames[1]);
	} else {
		headerTitle = TXTLS(@"TDCChannelInviteSheet[c8p-sb]", nicknameCount);
	}

	self.headerTitleTextField.stringValue = TXTLS(@"TDCChannelInviteSheet[0lg-er]", headerTitle);
}

- (void)startWithChannels:(NSArray<NSString *> *)channels
{
	NSParameterAssert(channels != nil);

	for (NSString *channel in channels) {
		[self.channelListPopup addItemWithTitle:channel];
	}

	[self startSheet];
}

- (void)ok:(id)sender
{
	if ([self.delegate respondsToSelector:@selector(channelInviteSheet:onSelectChannel:)]) {
		NSString *channelName = self.channelListPopup.titleOfSelectedItem;

		[self.delegate channelInviteSheet:self onSelectChannel:channelName];
	}

	[super ok:nil];
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	if ([self.delegate respondsToSelector:@selector(channelInviteSheetWillClose:)]) {
		[self.delegate channelInviteSheetWillClose:self];
	}
}

@end

NS_ASSUME_NONNULL_END
