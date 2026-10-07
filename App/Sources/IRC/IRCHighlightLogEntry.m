/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
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

#import "NSColorHelper.h"
#import "NSStringHelper.h"
#import "NSTableViewHelperPrivate.h"
#import "TXGlobalModels.h"
#import "TXMasterController.h"
#import "IRCChannel.h"
#import "IRCWorld.h"
#import "TLOLocalization.h"
#import "TLONotificationControllerPrivate.h"
#import "TVCLogLinePrivate.h"
#import "IRCHighlightLogEntryInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCHighlightLogEntry

- (NSString *)description
{
	IRCChannel *channel = self.channel;

	if (channel == nil) {
		return [super description];
	}

	TVCLogLine *logLine = self.lineLogged;

	return [logLine renderedBodyForTranscriptLogInChannel:channel];
}

- (NSString *)timeLoggedFormatted
{
	TVCLogLine *logLine = self.lineLogged;

	NSTimeInterval timeInterval = logLine.receivedAt.timeIntervalSinceNow;

	NSString *formattedTimeInterval = TXHumanReadableTimeInterval(timeInterval, YES, 0);

	return TXTLS(@"BasicLanguage[4um-w4]", formattedTimeInterval);
}

- (nullable IRCChannel *)channel
{
	IRCChannel *channel = [worldController() findChannelWithId:self.channelId onClientWithId:self.clientId];

	return channel;
}

- (NSString *)channelName
{
	IRCChannel *channel = self.channel;

	if (channel) {
		return channel.name;
	}

	return TXTLS(@"BasicLanguage[vbl-xi]");
}

- (NSAttributedString *)renderedMessage
{
	IRCChannel *channel = self.channel;

	TVCLogLine *logLine = self.lineLogged;

	NSString *nicknameBody = nil;

	NSString *messageBody = nil;

	if (logLine.lineType == TVCLogLineTypeAction) {
		/* Actions are presented in the format "• <nickname>: <message" in the Highlight List. */
		nicknameBody = logLine.nickname;

		messageBody = TXNotificationHighlightLogStandardActionFormat;
	} else {
		nicknameBody = [logLine formattedNicknameInChannel:channel];

		messageBody = TXNotificationHighlightLogStandardMessageFormat;
	}

	messageBody = [NSString stringWithFormat:messageBody, nicknameBody, logLine.messageBody];

	return [messageBody attributedStringWithIRCFormatting:[NSTableView preferredGlobalTableViewFont]
									   preferredFontColor:[NSColor controlTextColor]];
}

- (NSString *)lineNumber
{
	TVCLogLine *logLine = self.lineLogged;

	return logLine.uniqueIdentifier;
}

- (NSDate *)timeLogged
{
	TVCLogLine *logLine = self.lineLogged;

	return logLine.receivedAt;
}

- (void)initializedClassHealthCheck
{
	if (self.mutable || self.initializedAsCopy) {
		return;
	}

	NSParameterAssert(self->_lineLogged != nil);
	NSParameterAssert(self->_clientId.length > 0);
	NSParameterAssert(self->_channelId.length > 0);
}

- (void)populateDuringCopy:(__kindof XRPortablePropertyObject *)newObject mutableCopy:(BOOL)mutableCopy
{
	IRCHighlightLogEntry *object = (IRCHighlightLogEntry *)newObject;

	object->_lineLogged = self->_lineLogged;
	object->_clientId = self->_clientId;
	object->_channelId = self->_channelId;
}

- (__kindof XRPortablePropertyObject *)mutableClass
{
	return [IRCHighlightLogEntryMutable self];
}

@end

#pragma mark -

@implementation IRCHighlightLogEntryMutable

@dynamic lineLogged;
@dynamic clientId;
@dynamic channelId;

+ (BOOL)isMutable
{
	return YES;
}

- (__kindof XRPortablePropertyObject *)immutableClass
{
	return [IRCHighlightLogEntry self];
}

- (void)setLineLogged:(TVCLogLine *)lineLogged
{
	NSParameterAssert(lineLogged != nil);

	if (self->_lineLogged != lineLogged) {
		self->_lineLogged = [lineLogged copy];
	}
}

- (void)setClientId:(NSString *)clientId
{
	NSParameterAssert(clientId != nil);

	if (self->_clientId != clientId) {
		self->_clientId = [clientId copy];
	}
}

- (void)setChannelId:(NSString *)channelId
{
	NSParameterAssert(channelId != nil);

	if (self->_channelId != channelId) {
		self->_channelId = [channelId copy];
	}
}

@end

NS_ASSUME_NONNULL_END
