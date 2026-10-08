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

#import "NSObjectHelperPrivate.h"
#import "TXGlobalModelsPrivate.h"
#import "TXMasterControllerPrivate.h"
#import "TVCDockIconPrivate.h"
#import "TVCMainWindowPrivate.h"
#import "TVCServerListPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCMessagePrivate.h"
#import "IRCTreeItemPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

/* How long after the newest line a channel being viewed is marked as read */
static NSTimeInterval const IRCClientReadMarkerDelay = 2.0;

@implementation IRCClient (ReadMarker)

/* draft/read-marker: while you look at a channel or query, the server is
 told you have read it up to its newest message (when you select it, and
 a moment after new lines arrive); when another client reports reading
 everything shown here, the unread and highlight badges go away. */

+ (nullable NSString *)readMarkerTimestampForDate:(NSDate *)date
{
	NSParameterAssert(date != nil);

	static NSISO8601DateFormatter *formatter = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		formatter = [NSISO8601DateFormatter new];

		formatter.formatOptions = (NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds);
	});

	return [formatter stringFromDate:date];
}

- (BOOL)readMarkerChannelIsViewed:(IRCChannel *)channel
{
	return (mainWindow().keyWindow && [mainWindow() isItemSelected:channel]);
}

- (void)readMarkerNoteMessageAt:(NSDate *)receivedAt inChannel:(IRCChannel *)channel
{
	NSParameterAssert(receivedAt != nil);
	NSParameterAssert(channel != nil);

	NSDate *newestMessageTime = channel.newestMessageTime;

	if (newestMessageTime && [receivedAt compare:newestMessageTime] != NSOrderedDescending) {
		return;
	}

	channel.newestMessageTime = receivedAt;

	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityReadMarker] && [self readMarkerChannelIsViewed:channel]) {
		[self cs_reschedulePerformSelectorInCommonModes:@selector(markChannelAsRead:) withObject:channel afterDelay:IRCClientReadMarkerDelay];
	}
}

- (nullable NSString *)readMarkerRequestForChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	NSDate *newestMessageTime = channel.newestMessageTime;

	if (newestMessageTime == nil) {
		return nil;
	}

	NSDate *readMarkerTime = channel.readMarkerTime;

	if (readMarkerTime && [newestMessageTime compare:readMarkerTime] != NSOrderedDescending) {
		return nil;
	}

	return [NSString stringWithFormat:@"MARKREAD %@ timestamp=%@", channel.name, [self.class readMarkerTimestampForDate:newestMessageTime]];
}

- (void)markChannelAsRead:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityReadMarker] == NO || self.isLoggedIn == NO) {
		return;
	}

	if (channel.associatedClient != self || [self readMarkerChannelIsViewed:channel] == NO) {
		return;
	}

	if (channel.isChannel && channel.isActive == NO) {
		return;
	}

	NSString *request = [self readMarkerRequestForChannel:channel];

	if (request == nil) {
		return;
	}

	channel.readMarkerTime = channel.newestMessageTime;

	[self sendLine:request];
}

/* MARKREAD <target> timestamp=<time or *>; YES when it cleared the badges */
- (BOOL)applyReadMarker:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	if ([m paramsCount] < 2) {
		return NO;
	}

	IRCChannel *channel = [self findChannel:[m paramAt:0]];

	if (channel == nil) {
		return NO;
	}

	NSString *value = [m paramAt:1];

	if ([value hasPrefix:@"timestamp="] == NO) {
		return NO;
	}

	NSDate *readMarkerTime = [TXSharedISOStandardDateFormatter() dateFromString:[value substringFromIndex:10]];

	/* "timestamp=*": nothing is known to be read */
	if (readMarkerTime == nil) {
		return NO;
	}

	channel.readMarkerTime = readMarkerTime;

	NSDate *newestMessageTime = channel.newestMessageTime;

	if (newestMessageTime == nil || [readMarkerTime compare:newestMessageTime] == NSOrderedAscending) {
		return NO;
	}

	if (channel.treeUnreadCount == 0 && channel.nicknameHighlightCount == 0 && channel.dockUnreadCount == 0) {
		return NO;
	}

	[channel resetState];

	return YES;
}

- (void)receiveMarkRead:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	if (m.isPrintOnlyMessage) {
		return;
	}

	if ([self applyReadMarker:m] == NO) {
		return;
	}

	IRCChannel *channel = [self findChannel:[m paramAt:0]];

	if (channel) {
		[mainWindowServerList() refreshMessageCountForItem:channel];
	}

	[TVCDockIcon updateDockIcon];
}

@end

NS_ASSUME_NONNULL_END
