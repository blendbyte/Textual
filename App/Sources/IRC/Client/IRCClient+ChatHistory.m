/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

#import "IRCChannelPrivate.h"
#import "IRCISupportInfoPrivate.h"
#import "IRCMessagePrivate.h"
#import "IRCMessageBatchPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

/* At most this many missed messages are requested per channel or query */
static NSUInteger const IRCClientChatHistoryRequestLimit = 100;

/* Message IDs remembered per channel to recognise lines already shown */
static NSUInteger const IRCClientChatHistoryRecentMessageIdLimit = 500;

@implementation IRCClient (ChatHistory)

/* draft/chathistory gap-fill: each channel and query remembers the newest
 message ID it saw in this run of the app; after a reconnect, the messages
 since then are requested (for a channel once it is joined again, for
 queries at login). Lines already shown are skipped, backfilled lines
 don't notify, and errors leave things as they were without it. */

- (BOOL)isChatHistoryMessage:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	for (IRCMessageBatchMessage *batch = m.parentBatchMessage; batch != nil; batch = batch.parentBatchMessage) {
		NSString *batchType = batch.batchType;

		if ([batchType isEqualToString:@"chathistory"] || [batchType isEqualToString:@"draft/chathistory"]) {
			return YES;
		}
	}

	return NO;
}

- (BOOL)chatHistoryShouldSkipMessage:(IRCMessage *)m inChannel:(IRCChannel *)channel
{
	return [self chatHistoryShouldSkipMessage:m inChannel:channel fromHistory:[self isChatHistoryMessage:m]];
}

- (BOOL)chatHistoryShouldSkipMessage:(IRCMessage *)m inChannel:(IRCChannel *)channel fromHistory:(BOOL)fromHistory
{
	NSParameterAssert(m != nil);
	NSParameterAssert(channel != nil);

	if (fromHistory) {
		/* Our own lines from before the connection ended are on screen already */
		NSDate *disconnectTime = self.chatHistoryDisconnectTime;

		if (disconnectTime && [self nicknameIsMyself:m.senderNickname] &&
			[m.receivedAt compare:disconnectTime] != NSOrderedDescending)
		{
			return YES;
		}
	}

	NSString *messageId = m.msgid;

	if (messageId == nil) {
		return NO;
	}

	NSMutableOrderedSet *recentMessageIds = channel.chatHistoryRecentMessageIds;

	if (recentMessageIds == nil) {
		recentMessageIds = [NSMutableOrderedSet orderedSet];

		channel.chatHistoryRecentMessageIds = recentMessageIds;
	}

	if ([recentMessageIds containsObject:messageId]) {
		return fromHistory;
	}

	[recentMessageIds addObject:messageId];

	if (recentMessageIds.count > IRCClientChatHistoryRecentMessageIdLimit) {
		[recentMessageIds removeObjectAtIndex:0];
	}

	/* The anchor only moves forward: a batch processed after newer live lines doesn't move it back */
	NSDate *anchorTime = channel.chatHistoryAnchorTime;

	if (anchorTime == nil || [m.receivedAt compare:anchorTime] != NSOrderedAscending) {
		channel.chatHistoryAnchorMessageId = messageId;
		channel.chatHistoryAnchorTime = m.receivedAt;
	}

	return NO;
}

- (nullable NSString *)chatHistoryRequestForChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	NSString *anchor = channel.chatHistoryAnchorMessageId;

	if (anchor == nil) {
		return nil;
	}

	NSUInteger limit = IRCClientChatHistoryRequestLimit;

	NSUInteger serverLimit = self.supportInfo.chatHistoryLimit;

	if (serverLimit > 0 && serverLimit < limit) {
		limit = serverLimit;
	}

	return [NSString stringWithFormat:@"CHATHISTORY LATEST %@ msgid=%@ %lu", channel.name, anchor, (unsigned long)limit];
}

- (void)requestChatHistoryForChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityChatHistory] == NO) {
		return;
	}

	/* A ZNC with its playback module replays itself */
	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityPlayback]) {
		return;
	}

	NSString *request = [self chatHistoryRequestForChannel:channel];

	if (request == nil) {
		return;
	}

	[self.chatHistoryPendingTargets addObject:[self.supportInfo foldedString:channel.name]];

	[self sendLine:request];
}

- (void)requestChatHistoryForQueries
{
	for (IRCChannel *channel in self.channelList) {
		if (channel.isPrivateMessage) {
			[self requestChatHistoryForChannel:channel];
		}
	}
}

- (void)chatHistoryBatchOpenedForTarget:(nullable NSString *)target
{
	if (target == nil) {
		return;
	}

	[self.chatHistoryPendingTargets removeObject:[self.supportInfo foldedString:target]];
}

/* FAIL CHATHISTORY for one of our automatic requests: logged, not shown */
- (BOOL)chatHistoryHidesStandardReply:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	if ([[m paramAt:0] isEqualToStringIgnoringCase:@"CHATHISTORY"] == NO) {
		return NO;
	}

	for (NSUInteger i = 2; i < (m.paramsCount - 1); i++) {
		NSString *target = [self.supportInfo foldedString:[m paramAt:i]];

		if ([self.chatHistoryPendingTargets containsObject:target]) {
			[self.chatHistoryPendingTargets removeObject:target];

			LogToConsoleInfo("CHATHISTORY request for %{private}@ failed: %{public}@", [m paramAt:i], [m paramAt:1]);

			return YES;
		}
	}

	return NO;
}

@end

NS_ASSUME_NONNULL_END
