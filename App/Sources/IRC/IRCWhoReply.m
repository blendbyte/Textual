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

#import "IRCMessage.h"
#import "IRCWhoReplyPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const IRCWhoReplyWhoxRequest = @"%tcuhnfar,152";

@interface IRCWhoReply ()
@property (nonatomic, copy, readwrite) NSString *channelName;
@property (nonatomic, copy, readwrite) NSString *nickname;
@property (nonatomic, copy, readwrite) NSString *username;
@property (nonatomic, copy, readwrite) NSString *address;
@property (nonatomic, copy, readwrite) NSString *flags;
@property (nonatomic, copy, readwrite, nullable) NSString *realName;
@property (nonatomic, assign, readwrite) BOOL accountKnown;
@property (nonatomic, copy, readwrite, nullable) NSString *account;
@end

@implementation IRCWhoReply

/* <me> <channel> <user> <host> <server> <nick> <H|G>[*][prefixes] :<hopcount> <real name> */
+ (nullable instancetype)replyFromWhoReply:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	if (m.paramsCount < 7) {
		return nil;
	}

	IRCWhoReply *reply = [self new];

	reply.channelName = [m paramAt:1];
	reply.username = [m paramAt:2];
	reply.address = [m paramAt:3];
	reply.nickname = [m paramAt:5];
	reply.flags = [m paramAt:6];

	/* The last parameter is the hop count and the real name */
	if (m.paramsCount > 7) {
		NSString *hopsAndRealName = [m paramAt:7];

		NSRange space = [hopsAndRealName rangeOfString:@" "];

		reply.realName = ((space.location == NSNotFound) ? @"" : [hopsAndRealName substringFromIndex:NSMaxRange(space)]);
	}

	return reply;
}

/* <me> 152 <channel> <user> <host> <nick> <flags> <account> :<real name> */
+ (nullable instancetype)replyFromWhoxReply:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	if (m.paramsCount < 9 || [[m paramAt:1] isEqualToString:@"152"] == NO) {
		return nil;
	}

	IRCWhoReply *reply = [self new];

	reply.channelName = [m paramAt:2];
	reply.username = [m paramAt:3];
	reply.address = [m paramAt:4];
	reply.nickname = [m paramAt:5];
	reply.flags = [m paramAt:6];
	reply.realName = [m paramAt:8];

	reply.accountKnown = YES;

	/* WHOX says "0" for no account */
	NSString *account = [m paramAt:7];

	if ([account isEqualToString:@"0"] == NO && account.length > 0) {
		reply.account = account;
	}

	return reply;
}

@end

NS_ASSUME_NONNULL_END
