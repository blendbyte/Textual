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
#import "TXMasterControllerPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCISupportInfoPrivate.h"
#import "IRCMessagePrivate.h"
#import "IRCClientPrivate.h"
#import "IRCClientInternal.h"
#import "TVCLogControllerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* Reactions (https://ircv3.net/specs/client-tags/react): a TAGMSG with
 +draft/react (or +draft/unreact) and +reply naming the message. They are
 shown under that message, and sent the same way (tag-only, decided
 2026-10-16: no text for clients without them).

 Deleting (https://ircv3.net/specs/extensions/message-redaction): REDACT
 <target> <msgid> [reason]; the message stays as "Message deleted", with
 who did it when that wasn't its sender. Without a reason: the spec asks
 clients not to make one up. */

#define _reactionMaximumLength		64

@implementation IRCClient (Reactions)

+ (nullable NSString *)validatedReaction:(nullable id)value
{
	if ([value isKindOfClass:[NSString class]] == NO) {
		return nil;
	}

	NSString *reaction = [value trim];

	if (reaction.length == 0 || reaction.length > _reactionMaximumLength) {
		return nil;
	}

	static NSCharacterSet *invalidCharacters = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSMutableCharacterSet *characters = [NSMutableCharacterSet newlineCharacterSet];

		[characters formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];

		invalidCharacters = [characters copy];
	});

	if ([reaction rangeOfCharacterFromSet:invalidCharacters].location != NSNotFound) {
		return nil;
	}

	return reaction;
}

- (BOOL)canSendReactions
{
	return ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityMessageTags] &&
			[self.supportInfo isClientTagAllowed:@"draft/react"]);
}

- (void)noteUnavailableMessageActions
{
	if (self.messageActionsNoteShown) {
		return;
	}

	self.messageActionsNoteShown = YES;

	BOOL replies = self.canSendReplies;
	BOOL reactions = self.canSendReactions;

	if (replies && reactions) {
		return;
	}

	/* Without message-tags nothing passes; with them the network may deny
	 some (CLIENTTAGDENY, e.g. Libera.Chat: everything but typing) */
	NSString *note = nil;

	if (replies == NO && reactions == NO) {
		note = TXTLS(@"IRC[rpl-n1]");
	} else if (reactions == NO) {
		note = TXTLS(@"IRC[rpl-n2]");
	} else {
		note = TXTLS(@"IRC[rpl-n3]");
	}

	[self printDebugInformationToConsole:note];
}

- (BOOL)canDeleteMessages
{
	return [self isCapabilityEnabled:ClientIRCv3SupportedCapabilityMessageRedaction];
}

/* A channel, or the query: with the sender, or ours (echoed) with the target */
- (nullable IRCChannel *)channelForMessageAction:(IRCMessage *)m
{
	NSString *sender = m.senderNickname;

	NSString *target = [m paramAt:0];

	if ([self stringIsChannelName:target]) {
		return [self findChannel:target];
	} else if ([self nicknameIsMyself:sender]) {
		return [self findChannel:target];
	}

	return [self findChannel:sender];
}

- (void)receiveRedact:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	if (m.paramsCount < 2 || m.senderNickname.length == 0) {
		return;
	}

	NSString *msgid = [IRCMessage validatedMessageIdentifier:[m paramAt:1]];

	if (msgid == nil) {
		return;
	}

	NSString *reason = ((m.paramsCount > 2) ? [m paramAt:2].trim : nil);

	if (reason.length == 0) {
		reason = nil;
	}

	IRCChannel *channel = [self channelForMessageAction:m];

	if (channel == nil) {
		return;
	}

	[channel.viewController deleteMessage:msgid byNickname:m.senderNickname reason:reason];
}

/* The server sends REDACT back when it is done (or FAIL REDACT, shown as any standard reply) */
- (void)deleteMessage:(NSString *)msgid inChannel:(IRCChannel *)channel
{
	NSParameterAssert(msgid != nil);
	NSParameterAssert(channel != nil);

	msgid = [IRCMessage validatedMessageIdentifier:msgid];

	if (msgid == nil || self.canDeleteMessages == NO || self.isLoggedIn == NO || channel.isUtility) {
		return;
	}

	[self send:@"REDACT", channel.name, msgid, nil];
}

- (BOOL)receiveReactionTagmsg:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSDictionary *tags = m.messageTags;

	NSString *added = [IRCClient validatedReaction:tags[@"+draft/react"]];
	NSString *removed = [IRCClient validatedReaction:tags[@"+draft/unreact"]];

	if (added == nil && removed == nil) {
		return NO;
	}

	NSString *msgid = m.replyToMsgid;

	NSString *sender = m.senderNickname;

	if (msgid == nil || sender.length == 0 || m.senderIsServer || m.paramsCount == 0) {
		return YES;
	}

	IRCChannel *channel = [self channelForMessageAction:m];

	if (channel == nil) {
		return YES;
	}

	[channel.viewController setReaction:((added) ?: removed) byNickname:sender onMessage:msgid added:(added != nil)];

	return YES;
}

- (void)sendReaction:(NSString *)reaction toMessage:(NSString *)msgid inChannel:(IRCChannel *)channel removing:(BOOL)removing
{
	NSParameterAssert(reaction != nil);
	NSParameterAssert(msgid != nil);
	NSParameterAssert(channel != nil);

	reaction = [IRCClient validatedReaction:reaction];

	msgid = [IRCMessage validatedMessageIdentifier:msgid];

	if (reaction == nil || msgid == nil || self.canSendReactions == NO || channel.isUtility || self.isLoggedIn == NO) {
		return;
	}

	NSString *tag = ((removing) ? @"+draft/unreact" : @"+draft/react");

	[self sendLine:[NSString stringWithFormat:@"@%@=%@;+reply=%@ TAGMSG %@", tag, reaction.encodedMessageTagString, msgid.encodedMessageTagString, channel.name]];

	/* With echo-message the server sends it back like anyone's */
	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityEchoMessage] == NO) {
		[channel.viewController setReaction:reaction byNickname:self.userNickname onMessage:msgid added:(removing == NO)];
	}
}

@end

NS_ASSUME_NONNULL_END
