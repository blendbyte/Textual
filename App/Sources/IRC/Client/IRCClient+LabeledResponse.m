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

#import "TXMasterControllerPrivate.h"
#import "TVCMainWindowPrivate.h"
#import "IRCChannel.h"
#import "IRCMessage.h"
#import "IRCMessagePrivate.h"
#import "IRCMessageBatchPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

/* labeled-response (https://ircv3.net/specs/extensions/labeled-response): a
 command typed in a window carries a label, and the server's answer (one line
 with the label, a labeled-response batch, or ACK for none) comes back with it,
 so the answer goes to that window instead of wherever is selected when it
 arrives. Lines Textual sends by itself (WHO and ISON polls, PING, CAP) carry
 none and are answered as before. */

@implementation IRCClientLabeledRequest

- (instancetype)initWithLabel:(NSString *)label command:(NSString *)command channel:(nullable IRCChannel *)channel
{
	NSParameterAssert(label != nil);
	NSParameterAssert(command != nil);

	if ((self = [super init])) {
		self->_label = [label copy];
		self->_command = [command copy];
		self->_channel = channel;
		self->_toConsole = (channel == nil);
		self->_sentAt = [NSDate date];

		return self;
	}

	return nil;
}

@end

#pragma mark -

@implementation IRCClient (LabeledResponse)

- (BOOL)labeledResponsesUsable
{
	return ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityLabeledResponse] &&
			[self isCapabilityEnabled:ClientIRCv3SupportedCapabilityBatch]);
}

- (void)performLabeledCommandFromChannel:(nullable IRCChannel *)channel block:(void (NS_NOESCAPE ^)(void))block
{
	NSParameterAssert(block != nil);

	/* A command that runs other commands (an alias) answers in the first one's window */
	if (self.labelingDepth == 0) {
		self.labelingChannel = channel;
	}

	self.labelingDepth += 1;

	block();

	self.labelingDepth -= 1;

	if (self.labelingDepth == 0) {
		self.labelingChannel = nil;
	}
}

/* The command of a line, after any tags and prefix */
+ (NSString *)_commandOfLine:(NSString *)line
{
	NSArray *tokens = [line componentsSeparatedByString:@" "];

	for (NSString *token in tokens) {
		if (token.length == 0 || [token hasPrefix:@"@"] || [token hasPrefix:@":"]) {
			continue;
		}

		return token.uppercaseString;
	}

	return @"";
}

+ (NSString *)line:(NSString *)line withLabel:(NSString *)label
{
	NSParameterAssert(line != nil);
	NSParameterAssert(label != nil);

	if ([line hasPrefix:@"@"]) {
		return [NSString stringWithFormat:@"@label=%@;%@", label, [line substringFromIndex:1]];
	}

	return [NSString stringWithFormat:@"@label=%@ %@", label, line];
}

- (NSString *)lineByLabelingLine:(NSString *)line
{
	NSParameterAssert(line != nil);

	if (self.labelingDepth == 0 || self.labeledResponsesUsable == NO) {
		return line;
	}

	/* Answered by no one, or part of the connection itself */
	static NSSet<NSString *> *unlabeledCommands = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		unlabeledCommands = [NSSet setWithArray:@[@"AUTHENTICATE", @"CAP", @"PING", @"PONG", @"QUIT"]];
	});

	NSString *command = [self.class _commandOfLine:line];

	if ([unlabeledCommands containsObject:command]) {
		return line;
	}

	/* A /raw line with a label of its own keeps it; the lines of a batch we
	 send carry no other tags (draft/multiline), only its opening is labeled */
	if ([line hasPrefix:@"@"]) {
		NSString *tags = [[line substringFromIndex:1] componentsSeparatedByString:@" "].firstObject;

		for (NSString *tag in [tags componentsSeparatedByString:@";"]) {
			if ([tag hasPrefix:@"label="] || [tag hasPrefix:@"batch="]) {
				return line;
			}
		}
	}

	if ([command isEqualToString:@"BATCH"] && [line rangeOfString:@"BATCH -"].location != NSNotFound) {
		return line;
	}

	[self _removeExpiredLabeledRequests];

	self.labeledRequestCount += 1;

	NSString *label = [NSString stringWithFormat:@"t%lu", self.labeledRequestCount];

	self.labeledRequests[label] = [[IRCClientLabeledRequest alloc] initWithLabel:label command:command channel:self.labelingChannel];

	return [self.class line:line withLabel:label];
}

- (void)_removeExpiredLabeledRequests
{
	NSDate *oldest = [NSDate dateWithTimeIntervalSinceNow:(-_labeledRequestTimeout)];

	NSMutableArray *expired = [NSMutableArray array];

	[self.labeledRequests enumerateKeysAndObjectsUsingBlock:^(NSString *label, IRCClientLabeledRequest *request, BOOL *stop) {
		if ([request.sentAt compare:oldest] == NSOrderedAscending) {
			[expired addObject:label];
		}
	}];

	[self.labeledRequests removeObjectsForKeys:expired];
}

- (void)removeLabeledRequests
{
	[self.labeledRequests removeAllObjects];

	self.labeledReplyRequest = nil;
}

#pragma mark -
#pragma mark Replies

- (nullable IRCClientLabeledRequest *)labeledRequestForMessage:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	if (self.labeledRequests.count == 0) {
		return nil;
	}

	NSString *label = m.messageTags[@"label"];

	if (label.length == 0) {
		IRCMessageBatchMessage *batch = m.parentBatchMessage;

		while (batch && batch.label.length == 0) {
			batch = batch.parentBatchMessage;
		}

		label = batch.label;
	}

	if (label.length == 0) {
		return nil;
	}

	return self.labeledRequests[label];
}

- (void)labeledMessageProcessed:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	/* The opening of a labeled batch: the request lasts until its end */
	if ([m.command isEqualToString:@"BATCH"]) {
		return;
	}

	NSString *label = m.messageTags[@"label"];

	if (label.length > 0) {
		[self.labeledRequests removeObjectForKey:label];
	}
}

- (void)labeledBatchFinished:(IRCMessageBatchMessage *)batch
{
	NSParameterAssert(batch != nil);

	if (batch.label.length > 0) {
		[self.labeledRequests removeObjectForKey:batch.label];
	}
}

- (BOOL)processingLabeledReply
{
	return (self.labeledReplyRequest != nil);
}

- (BOOL)processingLabeledReplyToCommand:(NSString *)command
{
	NSParameterAssert(command != nil);

	return [self.labeledReplyRequest.command isEqualToString:command];
}

- (BOOL)processingLabeledReplyToListCommand
{
	NSString *command = self.labeledReplyRequest.command;

	if (command == nil) {
		return NO;
	}

	return [@[@"NAMES", @"WHO", @"ISON", @"WATCH", @"MONITOR"] containsObject:command];
}

- (nullable IRCChannel *)channelForReplyWithFallback:(nullable IRCChannel *)fallback
{
	IRCClientLabeledRequest *request = self.labeledReplyRequest;

	if (request == nil) {
		return fallback;
	}

	if (request.toConsole) {
		return nil;
	}

	/* Closed since: where it would have gone anyway */
	IRCChannel *channel = request.channel;

	if (channel == nil) {
		return fallback;
	}

	return channel;
}

- (nullable IRCChannel *)selectedChannelForReplies
{
	return [self channelForReplyWithFallback:[mainWindow() selectedChannelOn:self]];
}

@end

NS_ASSUME_NONNULL_END
