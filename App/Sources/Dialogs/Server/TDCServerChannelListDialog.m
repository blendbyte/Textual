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
#import "TXGlobalModels.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "TDCServerChannelListWindowPrivate.h"
#import "TDCServerChannelListDialogPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCServerChannelListDialog () <NSWindowDelegate>
@property (nonatomic, strong, readwrite) IRCClient *client;
@property (nonatomic, copy, readwrite) NSString *clientId;
@property (nonatomic, assign) BOOL isWaitingForWrites;
@property (nonatomic, strong) NSMutableArray<TDCServerChannelListDialogEntry *> *queuedWrites;
@property (nonatomic, strong) TDCServerChannelListWindow *windowContent;
@end

@implementation TDCServerChannelListDialog

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if ((self = [super init])) {
		self.client = client;
		self.clientId = client.uniqueIdentifier;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self.queuedWrites = [NSMutableArray array];

	__weak typeof(self) weakSelf = self;

	/* The window is SwiftUI (TDCServerChannelListWindow.swift) */
	self.windowContent =
	[[TDCServerChannelListWindow alloc] initWithNetworkName:self.client.networkNameAlt
													  join:^(NSArray<NSString *> *channels) {
														  [weakSelf joinChannels:channels];
													  }
												   refresh:^{
													   [weakSelf refresh];
												   }
											joinedChannels:^NSSet<NSString *> *{
												return [weakSelf joinedChannelNames];
											}];

	self.window = self.windowContent.window;

	self.window.delegate = self;
}

- (void)show
{
	[self.window restoreWindowStateForClass:self.class];

	/* A frame saved by the old, smaller window */
	NSSize minimumSize = self.window.minSize;

	NSRect frame = self.window.frame;

	if (NSWidth(frame) < minimumSize.width || NSHeight(frame) < minimumSize.height) {
		frame.size.width = MAX(NSWidth(frame), minimumSize.width);
		frame.size.height = MAX(NSHeight(frame), minimumSize.height);

		[self.window setFrame:frame display:NO];
	}

	[super show];
}

- (void)clear
{
	/* The queue too: rows waiting for the timer came back after an update */
	[self cancelPerformRequestsWithSelector:@selector(queuedWritesTimer)];

	self.isWaitingForWrites = NO;

	@synchronized(self.queuedWrites) {
		[self.queuedWrites removeAllObjects];
	}

	self.contentAlreadyReceived = NO;

	[self.windowContent clear];
}

- (void)addChannel:(NSString *)channel count:(NSUInteger)count topic:(nullable NSString *)topic
{
	NSParameterAssert(channel != nil);

	TDCServerChannelListDialogEntry *newEntry = [TDCServerChannelListDialogEntry new];

	newEntry.channelName = channel;
	newEntry.channelMemberCount = count;
	newEntry.channelTopic = (topic ?: @"");

	@synchronized(self.queuedWrites) {
		[self.queuedWrites addObject:newEntry];
	}

	/* In batches: a big network lists tens of thousands of channels */
	if (self.isWaitingForWrites == NO) {
		self.isWaitingForWrites = YES;

		[self performSelectorInCommonModes:@selector(queuedWritesTimer) withObject:nil afterDelay:1.0];
	}
}

- (void)setContentAlreadyReceived:(BOOL)contentAlreadyReceived
{
	self->_contentAlreadyReceived = contentAlreadyReceived;

	/* The end of the list: what's queued shows at once */
	if (contentAlreadyReceived) {
		[self cancelPerformRequestsWithSelector:@selector(queuedWritesTimer)];

		self.isWaitingForWrites = NO;

		[self writeQueuedWrites];

		[self.windowContent finishLoading];
	}
}

- (void)queuedWritesTimer
{
	self.isWaitingForWrites = NO;

	[self writeQueuedWrites];
}

- (void)writeQueuedWrites
{
	NSArray<TDCServerChannelListDialogEntry *> *entries = nil;

	@synchronized(self.queuedWrites) {
		if (self.queuedWrites.count == 0) {
			return;
		}

		entries = [self.queuedWrites copy];

		[self.queuedWrites removeAllObjects];
	}

	[self.windowContent addEntries:entries];
}

#pragma mark -
#pragma mark Actions

- (void)refresh
{
	if ([self.delegate respondsToSelector:@selector(serverChannelListDialogOnUpdate:)]) {
		[self.delegate serverChannelListDialogOnUpdate:self];
	}
}

- (void)joinChannels:(NSArray<NSString *> *)channels
{
	NSParameterAssert(channels != nil);

	if ([self.delegate respondsToSelector:@selector(serverChannelListDialog:joinChannels:)]) {
		[self.delegate serverChannelListDialog:self joinChannels:channels];
	}
}

/* Lowercased, to compare with the list */
- (NSSet<NSString *> *)joinedChannelNames
{
	NSMutableSet<NSString *> *channelNames = [NSMutableSet set];

	for (IRCChannel *channel in self.client.channelList) {
		if (channel.isChannel && channel.isActive) {
			[channelNames addObject:channel.name.lowercaseString];
		}
	}

	return [channelNames copy];
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	[self cancelPerformRequests];

	[self.window saveWindowStateForClass:self.class];

	[super windowWillClose:note];
}

@end

#pragma mark -

@implementation TDCServerChannelListDialogEntry
@end

NS_ASSUME_NONNULL_END
