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

#import "IRCColorFormatPrivate.h"
#import "IRCMessage.h"
#import "IRCMessagePrivate.h"
#import "IRCMessageBatchPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

/* draft/multiline (https://ircv3.net/specs/extensions/multiline): a message of
 several lines, or one too long for a single line, goes out as one batch of
 PRIVMSG or NOTICE lines (draft/multiline-concat on the pieces of a long line),
 and a received batch is shown as the one message it stands for. */

@implementation IRCClientMultilinePart

+ (instancetype)partWithText:(NSString *)text concat:(BOOL)concat
{
	NSParameterAssert(text != nil);

	IRCClientMultilinePart *part = [self new];

	part->_text = [text copy];
	part->_concat = concat;

	return part;
}

@end

#pragma mark -

@implementation IRCClient (Multiline)

- (BOOL)processMultilineCapabilityValue:(nullable NSString *)value
{
	NSUInteger maxBytes = 0;
	NSUInteger maxLines = 0;

	/* Tokens not understood are ignored */
	for (NSString *token in [value componentsSeparatedByString:@","]) {
		NSArray *keyValue = [token componentsSeparatedByString:@"="];

		if (keyValue.count != 2) {
			continue;
		}

		NSInteger number = [keyValue[1] integerValue];

		if (number <= 0) {
			continue;
		}

		if ([keyValue[0] isEqualToString:@"max-bytes"]) {
			maxBytes = number;
		} else if ([keyValue[0] isEqualToString:@"max-lines"]) {
			maxLines = number;
		}
	}

	self.multilineMaxBytes = maxBytes;
	self.multilineMaxLines = maxLines;

	return (maxBytes > 0);
}

- (BOOL)multilineUsable
{
	return ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityMultiline] &&
			[self isCapabilityEnabled:ClientIRCv3SupportedCapabilityBatch] &&
			self.multilineMaxBytes > 0);
}

#pragma mark -
#pragma mark Sending

- (nullable NSArray<NSArray<IRCClientMultilinePart *> *> *)multilineBatchesForLines:(NSArray<NSAttributedString *> *)lines target:(NSString *)target lineType:(TVCLogLineType)lineType
{
	NSParameterAssert(lines != nil);
	NSParameterAssert(target != nil);

	if (self.multilineUsable == NO || (lineType != TVCLogLineTypePrivateMessage && lineType != TVCLogLineTypeNotice)) {
		return nil;
	}

	NSMutableArray<IRCClientMultilinePart *> *parts = [NSMutableArray array];

	for (NSAttributedString *line in lines) {
		if (line.length == 0) {
			[parts addObject:[IRCClientMultilinePart partWithText:@"" concat:NO]];

			continue;
		}

		/* A long line in pieces of what fits on one line, joined back without a break */
		NSMutableAttributedString *lineMutable = [line mutableCopy];

		BOOL firstPiece = YES;

		while (lineMutable.length > 0) {
			NSString *piece = [lineMutable stringFormattedForChannel:target onClient:self withLineType:lineType];

			if (piece.length == 0) {
				break;
			}

			[parts addObject:[IRCClientMultilinePart partWithText:piece concat:(firstPiece == NO)]];

			firstPiece = NO;
		}
	}

	/* Not a message of blank lines only, nor blank lines around it */
	while (parts.count > 0 && parts.firstObject.text.length == 0) {
		[parts removeObjectAtIndex:0];
	}

	while (parts.count > 0 && parts.lastObject.text.length == 0) {
		[parts removeLastObject];
	}

	/* One line that fits: an ordinary message */
	if (parts.count < 2) {
		return nil;
	}

	return [self.class multilineBatchesOfParts:parts maxBytes:self.multilineMaxBytes maxLines:self.multilineMaxLines];
}

+ (NSArray<NSArray<IRCClientMultilinePart *> *> *)multilineBatchesOfParts:(NSArray<IRCClientMultilinePart *> *)parts maxBytes:(NSUInteger)maxBytes maxLines:(NSUInteger)maxLines
{
	NSParameterAssert(parts != nil);

	NSMutableArray *batches = [NSMutableArray array];

	NSMutableArray<IRCClientMultilinePart *> *batch = [NSMutableArray array];

	NSUInteger batchBytes = 0;

	for (IRCClientMultilinePart *partIn in parts) {
		IRCClientMultilinePart *part = partIn;

		NSUInteger partBytes = [part.text lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

		/* A line break before it counts as a byte */
		NSUInteger addedBytes = (partBytes + ((batch.count > 0 && part.concat == NO) ? 1 : 0));

		BOOL full = (batch.count > 0 &&
					 ((batchBytes + addedBytes) > maxBytes || (maxLines > 0 && batch.count >= maxLines)));

		if (full) {
			while (batch.lastObject.text.length == 0) {
				[batch removeLastObject];
			}

			[batches addObject:[batch copy]];

			[batch removeAllObjects];

			batchBytes = 0;
		}

		/* A batch starts a line of its own; a blank one isn't worth carrying over */
		if (batch.count == 0) {
			if (part.text.length == 0) {
				continue;
			}

			if (part.concat) {
				part = [IRCClientMultilinePart partWithText:part.text concat:NO];
			}

			addedBytes = partBytes;
		}

		[batch addObject:part];

		batchBytes += addedBytes;
	}

	/* A batch can't end on blank lines either */
	while (batch.count > 0 && batch.lastObject.text.length == 0) {
		[batch removeLastObject];
	}

	if (batch.count > 0) {
		[batches addObject:[batch copy]];
	}

	return [batches copy];
}

+ (NSString *)multilineTextOfParts:(NSArray<IRCClientMultilinePart *> *)parts
{
	NSParameterAssert(parts != nil);

	NSMutableString *text = [NSMutableString string];

	[parts enumerateObjectsUsingBlock:^(IRCClientMultilinePart *part, NSUInteger index, BOOL *stop) {
		if (index > 0 && part.concat == NO) {
			[text appendString:@"\n"];
		}

		[text appendString:part.text];
	}];

	return [text copy];
}

- (void)sendMultilineBatch:(NSArray<IRCClientMultilinePart *> *)parts command:(NSString *)command target:(NSString *)target
{
	NSParameterAssert(parts != nil);
	NSParameterAssert(command != nil);
	NSParameterAssert(target != nil);

	self.multilineBatchCount += 1;

	NSString *reference = [NSString stringWithFormat:@"ml%lu", self.multilineBatchCount];

	[self sendLine:[NSString stringWithFormat:@"BATCH +%@ draft/multiline %@", reference, target]];

	for (IRCClientMultilinePart *part in parts) {
		NSString *tags = ((part.concat) ? [NSString stringWithFormat:@"@batch=%@;draft/multiline-concat", reference] : [NSString stringWithFormat:@"@batch=%@", reference]);

		[self sendLine:[NSString stringWithFormat:@"%@ %@ %@ :%@", tags, command, target, part.text]];
	}

	[self sendLine:[NSString stringWithFormat:@"BATCH -%@", reference]];
}

#pragma mark -
#pragma mark Receiving

- (nullable IRCMessage *)messageCombiningMultilineBatch:(IRCMessageBatchMessage *)batch
{
	NSParameterAssert(batch != nil);

	NSMutableArray<IRCClientMultilinePart *> *parts = [NSMutableArray array];

	IRCMessage *firstMessage = nil;

	for (id entry in batch.queuedEntries) {
		if ([entry isKindOfClass:[IRCMessage class]] == NO) {
			continue;
		}

		IRCMessage *message = entry;

		if (message.paramsCount < 2) {
			continue;
		}

		if (firstMessage == nil) {
			firstMessage = message;
		} else if ([message.command isEqualToString:firstMessage.command] == NO) {
			continue; // PRIVMSG and NOTICE don't mix in one
		}

		BOOL concat = (parts.count > 0 && message.messageTags[@"draft/multiline-concat"] != nil);

		[parts addObject:[IRCClientMultilinePart partWithText:message.params.lastObject concat:concat]];
	}

	if (firstMessage == nil) {
		return nil;
	}

	IRCMessageMutable *combined = [firstMessage mutableCopy];

	NSMutableArray *params = [firstMessage.params mutableCopy];

	params[(params.count - 1)] = [self.class multilineTextOfParts:parts];

	combined.params = params;

	/* The batch's tags (msgid, time, account, label) are the message's */
	NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:(firstMessage.messageTags ?: @{})];

	[tags addEntriesFromDictionary:(batch.openingMessage.messageTags ?: @{})];

	[tags removeObjectForKey:@"draft/multiline-concat"];

	combined.messageTags = tags;

	IRCMessage *openingMessage = batch.openingMessage;

	if (openingMessage) {
		combined.receivedAt = openingMessage.receivedAt;
		combined.isHistoric = openingMessage.isHistoric;
	}

	return [combined copy];
}

@end

NS_ASSUME_NONNULL_END
