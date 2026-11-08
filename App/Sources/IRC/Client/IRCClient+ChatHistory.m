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

#import "NSStringHelper.h"
#import "TLOLocalization.h"
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
 message it saw in this run of the app; after a reconnect, the messages
 since then are requested (for a channel once it is joined again, for
 queries at the end of login), by message ID or by time, as the server
 takes them (soju only by time). After a relaunch nothing is remembered per
 channel, so the newest server time seen, which is saved, stands in. Lines
 already shown are skipped, backfilled lines don't notify, and errors leave
 things as they were without it. */

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

/* History: a chathistory or ZNC playback batch, or (a bouncer's buffer
 without a batch) a server time more than two minutes old */
- (BOOL)messageIsReplay:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	if ([self isChatHistoryMessage:m]) {
		return YES;
	}

	for (IRCMessageBatchMessage *batch = m.parentBatchMessage; batch != nil; batch = batch.parentBatchMessage) {
		if ([batch.batchType isEqualToString:@"znc.in/playback"]) {
			return YES;
		}
	}

	return (m.isHistoric && m.receivedAt.timeIntervalSinceNow < -120.0);
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

		/* Asked for by time: a server may include the line at that time */
		NSDate *requestBound = channel.chatHistoryRequestBound;

		if (requestBound && [m.receivedAt compare:requestBound] != NSOrderedDescending) {
			return YES;
		}
	}

	NSString *messageId = m.msgid;

	if (messageId) {
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
	}

	/* A private line shown in a channel (+channel-context, ChanServ) isn't part of its history */
	if (channel.isChannel && [self stringIsChannelName:[m paramAt:0]] == NO) {
		return NO;
	}

	/* The anchor only moves forward: a batch processed after newer live lines doesn't move it back */
	NSDate *anchorTime = channel.chatHistoryAnchorTime;

	if (anchorTime == nil || [m.receivedAt compare:anchorTime] != NSOrderedAscending) {
		channel.chatHistoryAnchorMessageId = messageId;
		channel.chatHistoryAnchorTime = m.receivedAt;
	}

	return NO;
}

/* A server that doesn't say what it takes (MSGREFTYPES) is assumed to take both */
- (BOOL)chatHistoryServerTakesReferenceType:(NSString *)type
{
	NSParameterAssert(type != nil);

	NSArray<NSString *> *types = self.supportInfo.chatHistoryMessageReferenceTypes;

	return (types == nil || [types containsObject:type]);
}

- (NSUInteger)chatHistoryRequestLimit
{
	NSUInteger limit = IRCClientChatHistoryRequestLimit;

	NSUInteger serverLimit = self.supportInfo.chatHistoryLimit;

	if (serverLimit > 0 && serverLimit < limit) {
		limit = serverLimit;
	}

	return limit;
}

/* The time to ask from; nil when asking by message ID, or when there's nothing to go by */
- (nullable NSDate *)chatHistoryTimeBoundForChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if (channel.chatHistoryAnchorMessageId && [self chatHistoryServerTakesReferenceType:@"msgid"]) {
		return nil;
	}

	if ([self chatHistoryServerTakesReferenceType:@"timestamp"] == NO) {
		return nil;
	}

	if (channel.chatHistoryAnchorTime) {
		return channel.chatHistoryAnchorTime;
	}

	if (channel.chatHistoryResumesFromLastSession && self.chatHistoryResumeTime > 0) {
		return [NSDate dateWithTimeIntervalSince1970:self.chatHistoryResumeTime];
	}

	return nil;
}

- (nullable NSString *)chatHistoryRequestForChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	NSString *reference = nil;

	NSDate *timeBound = [self chatHistoryTimeBoundForChannel:channel];

	if (timeBound) {
		reference = [NSString stringWithFormat:@"timestamp=%@", [IRCClient readMarkerTimestampForDate:timeBound]];
	} else if (channel.chatHistoryAnchorMessageId && [self chatHistoryServerTakesReferenceType:@"msgid"]) {
		reference = [NSString stringWithFormat:@"msgid=%@", channel.chatHistoryAnchorMessageId];
	}

	if (reference == nil) {
		return nil;
	}

	return [NSString stringWithFormat:@"CHATHISTORY LATEST %@ %@ %lu", channel.name, reference, (unsigned long)[self chatHistoryRequestLimit]];
}

- (BOOL)chatHistoryRequestsAreAutomatic
{
	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityChatHistory] == NO) {
		return NO;
	}

	/* Playback (ZNC's module, Ergo) replays by itself */
	return ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityPlayback] == NO);
}

- (void)requestChatHistoryForChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if ([self chatHistoryRequestsAreAutomatic] == NO) {
		return;
	}

	NSString *request = [self chatHistoryRequestForChannel:channel];

	channel.chatHistoryRequestBound = [self chatHistoryTimeBoundForChannel:channel];

	channel.chatHistoryResumesFromLastSession = NO;

	if (request == nil) {
		return;
	}

	[self.chatHistoryPendingTargets addObject:[self.supportInfo foldedString:channel.name]];

	channel.chatHistoryRequestTime = [NSDate date];

	channel.chatHistoryRequestLimit = [self chatHistoryRequestLimit];

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

- (void)chatHistoryNoteConnectionRegistered
{
	self.chatHistoryResumeTime = self.lastMessageServerTime;

	for (IRCChannel *channel in self.channelList) {
		channel.chatHistoryResumesFromLastSession = YES;
	}
}

/* An attempt that never logged in ended nothing: what happened since the real drop is still missed */
- (void)chatHistoryNoteConnectionEnded
{
	if (self.isLoggedIn) {
		self.chatHistoryDisconnectTime = [NSDate date];
	}
}

/* Who wrote while we were away, for conversations with no window yet */
- (nullable NSString *)chatHistoryTargetsRequestUntil:(NSDate *)date
{
	NSParameterAssert(date != nil);

	if (self.chatHistoryResumeTime <= 0 || [self chatHistoryServerTakesReferenceType:@"timestamp"] == NO) {
		return nil;
	}

	NSString *from = [IRCClient readMarkerTimestampForDate:[NSDate dateWithTimeIntervalSince1970:self.chatHistoryResumeTime]];
	NSString *until = [IRCClient readMarkerTimestampForDate:date];

	return [NSString stringWithFormat:@"CHATHISTORY TARGETS timestamp=%@ timestamp=%@ %lu", from, until, (unsigned long)[self chatHistoryRequestLimit]];
}

- (void)requestMissedConversations
{
	if (self.chatHistoryMissedConversationsRequested) {
		return;
	}

	self.chatHistoryMissedConversationsRequested = YES;

	[self requestChatHistoryForQueries];

	if ([self chatHistoryRequestsAreAutomatic]) {
		/* An hour on: this Mac's clock and the server's may differ */
		NSString *request = [self chatHistoryTargetsRequestUntil:[NSDate dateWithTimeIntervalSinceNow:3600]];

		if (request) {
			self.chatHistoryTargetsRemaining = [self chatHistoryRequestLimit];

			[self sendLine:request];
		}
	}

	/* After the history, so that it can't bring back a badge the marker clears */
	[self requestReadMarkersForQueries];
}

/* CHATHISTORY TARGETS <target> <time>: someone we have no window for wrote.
 Their lines open one as they arrive; a notice alone doesn't. */
- (void)receiveChatHistory:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	if ([m paramsCount] < 2 || [[m paramAt:0] isEqualToStringIgnoringCase:@"TARGETS"] == NO) {
		return;
	}

	if (self.chatHistoryTargetsRemaining == 0) {
		return;
	}

	self.chatHistoryTargetsRemaining -= 1;

	NSString *target = [m paramAt:1];

	if ([self stringIsChannelName:target] || [self nicknameIsMyself:target] || [self findChannel:target] != nil) {
		return;
	}

	if ([target hasPrefix:@"*"] || [target isHostmaskNicknameOn:self] == NO) {
		return;
	}

	NSString *from = [IRCClient readMarkerTimestampForDate:[NSDate dateWithTimeIntervalSince1970:self.chatHistoryResumeTime]];

	[self.chatHistoryPendingTargets addObject:[self.supportInfo foldedString:target]];

	[self sendLine:[NSString stringWithFormat:@"CHATHISTORY LATEST %@ timestamp=%@ %lu", target, from, (unsigned long)[self chatHistoryRequestLimit]]];

	[self requestReadMarkerForTarget:target];
}

/* A full answer means there may be more than was asked for */
- (void)chatHistoryBatchWillBeProcessed:(IRCMessageBatchMessage *)batchMessage
{
	NSParameterAssert(batchMessage != nil);

	NSString *target = [batchMessage.openingMessage paramAt:2];

	IRCChannel *channel = ((target.length > 0) ? [self findChannel:target] : nil);

	if (channel == nil) {
		return;
	}

	NSUInteger limit = channel.chatHistoryRequestLimit;

	channel.chatHistoryRequestLimit = 0;

	if (limit == 0 || batchMessage.queuedEntriesCount < limit) {
		return;
	}

	[self print:TXTLS(@"IRC[ch7-g1]", (unsigned long)limit)
			 by:nil
	  inChannel:channel
		 asType:TVCLogLineTypeDebug
		command:TVCLogLineDefaultCommandValue];
}

- (nullable IRCMessage *)chatHistoryEventMessage:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	static NSSet<NSString *> *eventCommands = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		eventCommands = [NSSet setWithArray:@[@"JOIN", @"PART", @"QUIT", @"NICK", @"KICK", @"MODE", @"TOPIC"]];
	});

	/* An invite from history is shown, never acted on; it needs no channel to go in */
	if ([m.command isEqualToStringIgnoringCase:@"INVITE"]) {
		NSDate *disconnectTime = self.chatHistoryDisconnectTime;

		if (disconnectTime && [m.receivedAt compare:disconnectTime] != NSOrderedDescending) {
			return nil;
		}

		IRCMessageMutable *invite = [m mutableCopy];

		invite.isPrintOnlyMessage = YES;

		return [invite copy];
	}

	if ([eventCommands containsObject:m.command.uppercaseString] == NO) {
		return m;
	}

	/* The channel the history is for: BATCH +ref chathistory #channel */
	NSString *target = nil;

	for (IRCMessageBatchMessage *batch = m.parentBatchMessage; batch != nil; batch = batch.parentBatchMessage) {
		if ([batch.batchType isEqualToString:@"chathistory"] || [batch.batchType isEqualToString:@"draft/chathistory"]) {
			target = [batch.openingMessage paramAt:2];

			break;
		}
	}

	IRCChannel *channel = ((target.length > 0) ? [self findChannel:target] : nil);

	if (channel == nil || channel.isChannel == NO) {
		return nil;
	}

	/* Our own leaving and coming back were shown as they happened */
	if ([self nicknameIsMyself:m.senderNickname]) {
		return nil;
	}

	/* Only what happened while we were away: before that and since asking it was seen live */
	NSDate *disconnectTime = self.chatHistoryDisconnectTime;
	NSDate *requestTime = channel.chatHistoryRequestTime;

	if (disconnectTime && [m.receivedAt compare:disconnectTime] != NSOrderedDescending) {
		return nil;
	}

	if (requestTime && [m.receivedAt compare:requestTime] != NSOrderedAscending) {
		return nil;
	}

	if ([self chatHistoryShouldSkipMessage:m inChannel:channel fromHistory:YES]) {
		return nil;
	}

	/* Printed, never applied to the members of now; QUIT and NICK name the channel first */
	IRCMessageMutable *event = [m mutableCopy];

	event.isPrintOnlyMessage = YES;

	NSString *command = m.command.uppercaseString;

	if ([command isEqualToString:@"QUIT"] || [command isEqualToString:@"NICK"]) {
		event.params = @[channel.name, (m.params.firstObject ?: @"")];
	}

	return [event copy];
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

	/* A failure that names no target: the reference wasn't taken, or TARGETS isn't offered */
	NSString *subcommand = [m paramAt:2];

	BOOL automaticLatest = ([subcommand isEqualToStringIgnoringCase:@"LATEST"] && self.chatHistoryPendingTargets.count > 0);
	BOOL automaticTargets = ([subcommand isEqualToStringIgnoringCase:@"TARGETS"] && self.chatHistoryTargetsRemaining > 0);

	if (automaticLatest || automaticTargets) {
		self.chatHistoryTargetsRemaining = ((automaticTargets) ? 0 : self.chatHistoryTargetsRemaining);

		LogToConsoleInfo("CHATHISTORY %{public}@ failed: %{public}@", subcommand, [m paramAt:1]);

		return YES;
	}

	return NO;
}

@end

NS_ASSUME_NONNULL_END
