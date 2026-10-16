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
#import "IRCChannelPrivate.h"
#import "IRCMessagePrivate.h"
#import "IRCMessageBatchPrivate.h"
#import "IRCNumerics.h"
#import "IRCClientPrivate.h"
#import "IRCClientInternal.h"
#import "TVCLogControllerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* Failed sends: a message the server refuses (an error reply or a FAIL
 instead of taking it) is shown dimmed, with why, Resend and Delete. With
 labeled-response the answer names the message exactly; without it, only an
 error about the message's target right after it counts: with echo-message the
 oldest not echoed yet (the server answers in order), without it only when a
 single message went there. With echo-message a message isn't shown until its echo,
 so a refused one is shown then; without it, its line is marked. */

@implementation IRCClientOutgoingMessage
@end

#pragma mark -

@implementation IRCClient (FailedSends)

- (IRCClientOutgoingMessage *)outgoingMessageWithText:(NSString *)text target:(NSString *)target command:(NSString *)command lineType:(TVCLogLineType)lineType channel:(IRCChannel *)channel
{
	NSParameterAssert(text != nil);
	NSParameterAssert(target != nil);
	NSParameterAssert(command != nil);
	NSParameterAssert(channel != nil);

	IRCClientOutgoingMessage *outgoing = [IRCClientOutgoingMessage new];

	outgoing.text = text;
	outgoing.target = target;
	outgoing.command = command;
	outgoing.lineType = lineType;
	outgoing.channel = channel;
	outgoing.replyToMsgid = self.outgoingReplyMsgid;
	outgoing.sentAt = [NSDate date];

	return outgoing;
}

- (void)printOutgoingMessage:(IRCClientOutgoingMessage *)outgoing usingBlock:(void (NS_NOESCAPE ^)(void))block
{
	NSParameterAssert(outgoing != nil);
	NSParameterAssert(block != nil);

	IRCClientOutgoingMessage *previous = self.printingOutgoingMessage;

	self.printingOutgoingMessage = outgoing;

	block();

	self.printingOutgoingMessage = previous;
}

- (void)sendOutgoingMessage:(IRCClientOutgoingMessage *)outgoing usingBlock:(void (NS_NOESCAPE ^)(void))block
{
	NSParameterAssert(outgoing != nil);
	NSParameterAssert(block != nil);

	/* Labeled like a typed command: the first label is the message's (a
	 multi-line message's BATCH) */
	BOOL wasCapturing = self.capturingLabel;

	NSString *previousLabel = self.capturedLabel;

	self.capturingLabel = YES;
	self.capturedLabel = nil;

	[self performLabeledCommandFromChannel:outgoing.channel block:block];

	outgoing.label = self.capturedLabel;

	self.capturingLabel = wasCapturing;
	self.capturedLabel = previousLabel;

	[self _removeExpiredOutgoingMessages];

	/* Without echo-message or labels, only an error can say anything about it */
	[self.outgoingMessages addObject:outgoing];
}

- (void)_removeExpiredOutgoingMessages
{
	NSDate *now = [NSDate date];

	NSIndexSet *expired = [self.outgoingMessages indexesOfObjectsPassingTest:^BOOL(IRCClientOutgoingMessage *outgoing, NSUInteger index, BOOL *stop) {
		NSTimeInterval age = [now timeIntervalSinceDate:outgoing.sentAt];

		return (age > ((outgoing.label) ? _outgoingMessageTimeout : _outgoingMessageErrorWindow));
	}];

	[self.outgoingMessages removeObjectsAtIndexes:expired];
}

- (void)removeOutgoingMessages
{
	[self.outgoingMessages removeAllObjects];

	self.lastEchoedBatch = nil;
}

#pragma mark -
#pragma mark Answers

- (void)outgoingMessageAnsweredWithLabel:(NSString *)label
{
	NSParameterAssert(label != nil);

	NSUInteger index = [self.outgoingMessages indexOfObjectPassingTest:^BOOL(IRCClientOutgoingMessage *outgoing, NSUInteger objectIndex, BOOL *stop) {
		return [outgoing.label isEqualToString:label];
	}];

	if (index != NSNotFound) {
		[self.outgoingMessages removeObjectAtIndex:index];
	}
}

- (void)outgoingMessageEchoed:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	if (self.outgoingMessages.count == 0 ||
		[self isCapabilityEnabled:ClientIRCv3SupportedCapabilityEchoMessage] == NO ||
		[self isChatHistoryMessage:m] ||
		[self nicknameIsMyself:m.senderNickname] == NO)
	{
		return;
	}

	/* A labeled one is taken by its label */
	if ([self labeledRequestForMessage:m]) {
		return;
	}

	/* The lines of a multi-line message echo as one */
	IRCMessageBatchMessage *batch = m.parentBatchMessage;

	if (batch) {
		if (batch == self.lastEchoedBatch) {
			return;
		}

		self.lastEchoedBatch = batch;
	}

	NSString *target = [m paramAt:0];

	NSUInteger index = [self.outgoingMessages indexOfObjectPassingTest:^BOOL(IRCClientOutgoingMessage *outgoing, NSUInteger objectIndex, BOOL *stop) {
		return (outgoing.label == nil && [outgoing.target isEqualToStringIgnoringCase:target]);
	}];

	if (index != NSNotFound) {
		[self.outgoingMessages removeObjectAtIndex:index];
	}
}

/* Errors that refuse a message, about its target (param 1) */
+ (BOOL)_numericRefusesMessage:(NSUInteger)numeric
{
	switch (numeric) {
		case ERR_NOSUCHNICK: // 401
		case ERR_CANNOTSENDTOCHAN: // 404
		case ERR_NEEDREGGEDNICK: // 477: some servers, to speak in a channel
		case 486: // ERR_NONONREG: only registered users may message them
		case 492: // ERR_NOCTCP
		case 531: // ERR_CANTSENDTOUSER
		{
			return YES;
		}
		default:
		{
			return NO;
		}
	}
}

- (BOOL)outgoingMessageFailedWithReply:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	if (self.outgoingMessages.count == 0) {
		return NO;
	}

	[self _removeExpiredOutgoingMessages];

	IRCClientOutgoingMessage *outgoing = nil;

	NSString *label = self.labeledReplyRequest.label;

	if (label) {
		/* The answer to a message of ours, or to something else */
		for (IRCClientOutgoingMessage *object in self.outgoingMessages) {
			if ([object.label isEqualToString:label]) {
				outgoing = object;

				break;
			}
		}
	} else if (m.commandNumeric > 0 && [self.class _numericRefusesMessage:m.commandNumeric]) {
		NSString *target = [m paramAt:1];

		NSMutableArray<IRCClientOutgoingMessage *> *candidates = [NSMutableArray array];

		for (IRCClientOutgoingMessage *object in self.outgoingMessages) {
			if (object.label == nil && [object.target isEqualToStringIgnoringCase:target]) {
				[candidates addObject:object];
			}
		}

		/* With echo-message the ones taken are gone, so it's the oldest; without
		 it nothing says which were taken, so only a single one counts */
		if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityEchoMessage] || candidates.count == 1) {
			outgoing = candidates.firstObject;
		}
	}

	IRCChannel *channel = outgoing.channel;

	if (outgoing == nil || channel == nil) {
		return NO;
	}

	[self.outgoingMessages removeObject:outgoing];

	/* Its line was left out (an output rule): the reply is printed as usual */
	if (outgoing.printedLocally && outgoing.lineNumber == nil) {
		return NO;
	}

	NSString *reason = ((m.paramsCount > 0) ? [m paramAt:(m.paramsCount - 1)] : @"");

	outgoing.failedReason = reason.trim;

	if (outgoing.printedLocally) {
		[channel.viewController markLine:outgoing.lineNumber asSendFailed:outgoing.failedReason];

		return YES;
	}

	/* Never shown (echo-message): now, as not sent */
	[self printOutgoingMessage:outgoing usingBlock:^{
		[self print:outgoing.text
				 by:self.userNickname
		  inChannel:channel
			 asType:outgoing.lineType
			command:outgoing.command
		 receivedAt:outgoing.sentAt];
	}];

	return YES;
}

#pragma mark -
#pragma mark Resend

- (BOOL)resendFailedLine:(TVCLogLine *)logLine inChannel:(IRCChannel *)channel
{
	NSParameterAssert(logLine != nil);
	NSParameterAssert(channel != nil);

	if (self.isLoggedIn == NO || channel.isUtility) {
		return NO;
	}

	IRCRemoteCommand command = IRCRemoteCommandPrivmsg;

	if (logLine.lineType == TVCLogLineTypeAction) {
		command = IRCRemoteCommandPrivmsgAction;
	} else if (logLine.lineType == TVCLogLineTypeNotice) {
		command = IRCRemoteCommandNotice;
	}

	/* Text, not a command: "//text" sends "/text" */
	NSString *text = logLine.messageBody;

	if ([text hasPrefix:@"/"]) {
		text = [@"/" stringByAppendingString:text];
	}

	self.outgoingReplyMsgid = logLine.replyToMsgid;

	[self inputText:text asCommand:command destination:channel];

	self.outgoingReplyMsgid = nil;

	return YES;
}

@end

NS_ASSUME_NONNULL_END
