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

#import "TLOLocalization.h"
#import "TPCPreferencesLocal.h"
#import "TXMasterControllerPrivate.h"
#import "TVCMainWindowPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCISupportInfoPrivate.h"
#import "IRCMessage.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

/* Typing notifications (https://ircv3.net/specs/client-tags/typing): the
 client-only tag +typing on TAGMSG, so they need message-tags and a server
 that doesn't deny the tag (CLIENTTAGDENY) */

/* "active" at most this often while typing */
static NSTimeInterval const IRCClientTypingActiveInterval = 3.0;

/* Someone shown as typing without a refresh for this long has stopped */
static NSTimeInterval const IRCClientTypingExpiryInterval = 6.0;

@implementation IRCClient (Typing)

- (BOOL)canSendTypingNotificationsToChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if (self.isLoggedIn == NO || [TPCPreferences sendTypingNotifications] == NO) {
		return NO;
	}

	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityMessageTags] == NO ||
		[self.supportInfo isClientTagAllowed:@"typing"] == NO)
	{
		return NO;
	}

	if (channel.isChannel) {
		return channel.isActive;
	}

	return channel.isPrivateMessage;
}

/* The input field of channel changed to text */
- (void)typingInputChanged:(NSString *)text inChannel:(IRCChannel *)channel
{
	NSParameterAssert(text != nil);
	NSParameterAssert(channel != nil);

	/* Emptied: stopped typing */
	if (text.length == 0) {
		[self sendTypingDoneToChannel:channel];

		return;
	}

	/* A command being typed isn't a message in progress */
	if ([text hasPrefix:@"/"]) {
		return;
	}

	if ([self canSendTypingNotificationsToChannel:channel] == NO) {
		return;
	}

	NSDate *sentAt = channel.typingActiveSentAt;

	if (sentAt && [[NSDate date] timeIntervalSinceDate:sentAt] < IRCClientTypingActiveInterval) {
		return;
	}

	channel.typingActiveSentAt = [NSDate date];

	[self sendLine:[NSString stringWithFormat:@"@+typing=active TAGMSG %@", channel.name]];
}

- (void)sendTypingDoneToChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	/* Nothing to end */
	if (channel.typingActiveSentAt == nil) {
		return;
	}

	channel.typingActiveSentAt = nil;

	if ([self canSendTypingNotificationsToChannel:channel] == NO) {
		return;
	}

	[self sendLine:[NSString stringWithFormat:@"@+typing=done TAGMSG %@", channel.name]];
}

/* A message ends typing without a "done" */
- (void)typingMessageSentInChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	channel.typingActiveSentAt = nil;
}

- (void)receiveTagmsg:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] > 0);

	NSString *state = m.messageTags[@"+typing"];

	if (state == nil || m.isPrintOnlyMessage) {
		return;
	}

	NSString *sender = m.senderNickname;

	if (sender.length == 0 || m.senderIsServer || [self nicknameIsMyself:sender]) {
		return;
	}

	/* A channel, or the query with the sender; typing alone never opens a query */
	NSString *target = [m paramAt:0];

	IRCChannel *channel = nil;

	if ([self stringIsChannelName:target]) {
		channel = [self findChannel:target];
	} else {
		channel = [self findChannel:sender];
	}

	if (channel == nil) {
		return;
	}

	/* "paused" and "done" both end the indicator */
	if ([state isEqualToString:@"active"]) {
		[channel markNicknameAsTyping:sender until:[NSDate dateWithTimeIntervalSinceNow:IRCClientTypingExpiryInterval]];
	} else {
		[channel clearTypingForNickname:sender];
	}

	[mainWindow() updateTypingIndicatorForChannel:channel];
}

/* A message from someone ends their typing */
- (void)typingEndedByMessageFrom:(NSString *)nickname inChannel:(IRCChannel *)channel
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(channel != nil);

	if ([channel clearTypingForNickname:nickname]) {
		[mainWindow() updateTypingIndicatorForChannel:channel];
	}
}

+ (nullable NSString *)typingIndicatorTextForNicknames:(NSArray<NSString *> *)nicknames
{
	NSParameterAssert(nicknames != nil);

	switch (nicknames.count) {
		case 0:
			return nil;
		case 1:
			return TXTLS(@"IRC[ty9-1a]", nicknames[0]);
		case 2:
			return TXTLS(@"IRC[ty9-2b]", nicknames[0], nicknames[1]);
		default:
			return TXTLS(@"IRC[ty9-3c]", nicknames.count);
	}
}

@end

NS_ASSUME_NONNULL_END
