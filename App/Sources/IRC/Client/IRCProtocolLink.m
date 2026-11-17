/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

#import "NSStringHelper.h"
#import "IRCConnectionConfig.h"
#import "IRCProtocolLinkPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCProtocolLink ()
@property (readwrite, copy) NSString *location;
@property (readwrite, copy) NSString *scheme;
@property (readwrite, copy) NSString *host;
@property (readwrite) uint16_t port;
@property (readwrite) BOOL secure;
@property (readwrite, copy) NSArray<NSString *> *channels;
@property (readwrite, copy, nullable) NSString *channelKey;
@property (readwrite, copy) NSArray<NSString *> *nicknames;
@end

@implementation IRCProtocolLink

+ (NSCharacterSet *)invalidChannelCharacters
{
	static NSCharacterSet *characters = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSMutableCharacterSet *charactersMutable = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];

		[charactersMutable formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];

		characters = [charactersMutable copy];
	});

	return characters;
}

+ (nullable instancetype)linkWithString:(NSString *)location
{
	NSParameterAssert(location != nil);

	/* Decoded only once split: an encoded slash or comma is part of a channel's name */
	NSString *locationValue = location.trim;

	/* The channel part is cut off before the rest goes to NSURL, which
	 doesn't handle channels separated by # well */
	NSUInteger totalSlashCount = [locationValue occurrencesOfCharacter:'/'];

	if (totalSlashCount < 2 || totalSlashCount > 3) {
		return nil;
	}

	NSString *serverInfo = locationValue;

	NSString *channelInfo = nil;

	if (totalSlashCount == 3) {
		NSRange backwardRange = [locationValue rangeOfString:@"/" options:NSBackwardsSearch];

		serverInfo = [locationValue substringToIndex:backwardRange.location];

		channelInfo = [locationValue substringAfterIndex:backwardRange.location];
	}

	NSURL *baseURL = [NSURL URLWithString:serverInfo];

	NSString *scheme = baseURL.scheme.lowercaseString;

	NSString *host = baseURL.host;

	if (scheme == nil || host == nil) {
		return nil;
	}

	__block BOOL secure = [scheme isEqualToString:@"ircs"];

	__block BOOL targetsArePeople = NO;

	NSMutableArray<NSString *> *targets = [NSMutableArray array];

	NSString *channelKey = nil;

	/* "?key=…" after the targets; an encoded ? (%3F) stays in a name */
	if (channelInfo) {
		NSRange queryRange = [channelInfo rangeOfString:@"?"];

		if (queryRange.location != NSNotFound) {
			NSString *query = [channelInfo substringFromIndex:NSMaxRange(queryRange)];

			channelInfo = [channelInfo substringToIndex:queryRange.location];

			channelKey = [self channelKeyInQuery:query];
		}
	}

	if (channelInfo) {
		NSArray<NSString *> *sections = [channelInfo split:@","];

		NSArray<NSString *> *flags = @[@"needssl", @"isuser", @"isnick", @"ischannel", @"needkey", @"needpass"];

		[sections enumerateObjectsUsingBlock:^(NSString *sectionIn, NSUInteger index, BOOL *stop) {
			NSString *section = (sectionIn.percentDecodedString ?: sectionIn);

			if (section.length == 0) {
				return;
			}

			if (index > 4) {
				*stop = YES;

				return;
			}

			/* The first section is always a target: irc://host/isuser is #isuser */
			if (index > 0 && [flags containsObject:section.lowercaseString]) {
				NSString *flag = section.lowercaseString;

				if ([flag isEqualToString:@"needssl"]) {
					secure = YES;
				} else if ([flag isEqualToString:@"isuser"] || [flag isEqualToString:@"isnick"]) {
					targetsArePeople = YES;
				}

				return;
			}

			/* No channel name has spaces or control characters; a decoded
			 %0D%0A would have sent the rest as its own command */
			if ([section rangeOfCharacterFromSet:[self invalidChannelCharacters]].location != NSNotFound) {
				return;
			}

			[targets addObject:section];
		}];
	}

	NSMutableArray<NSString *> *channels = [NSMutableArray array];
	NSMutableArray<NSString *> *nicknames = [NSMutableArray array];

	for (NSString *target in targets) {
		if (targetsArePeople) {
			/* A nickname never starts with # */
			if ([target hasPrefix:@"#"] == NO) {
				[nicknames addObject:target];
			}
		} else if ([target hasPrefix:@"#"]) {
			[channels addObject:target];
		} else {
			[channels addObject:[@"#" stringByAppendingString:target]];
		}
	}

	IRCProtocolLink *link = [self new];

	link.location = locationValue;
	link.scheme = scheme;
	link.host = host;
	link.secure = secure;
	link.channels = channels;
	link.nicknames = nicknames;
	link.channelKey = ((channels.count > 0) ? channelKey : nil);

	/* Without a port: the standard one for TLS or plain text (ircs:// used
	 to default to 6667, R3.20) */
	if (baseURL.port) {
		link.port = baseURL.port.unsignedShortValue;
	} else {
		link.port = (secure ? IRCConnectionDefaultSecureServerPort : IRCConnectionDefaultServerPort);
	}

	return link;
}

/* "key=secret" among "&"-separated options; a key has no spaces, commas or
 control characters (it goes into a JOIN) */
+ (nullable NSString *)channelKeyInQuery:(NSString *)query
{
	for (NSString *option in [query componentsSeparatedByString:@"&"]) {
		NSRange equalsRange = [option rangeOfString:@"="];

		if (equalsRange.location == NSNotFound) {
			continue;
		}

		NSString *name = [option substringToIndex:equalsRange.location];

		if ([name isEqualToStringIgnoringCase:@"key"] == NO) {
			continue;
		}

		NSString *valueIn = [option substringFromIndex:NSMaxRange(equalsRange)];

		NSString *value = (valueIn.percentDecodedString ?: valueIn);

		if (value.length == 0 ||
			[value rangeOfCharacterFromSet:[self invalidChannelCharacters]].location != NSNotFound ||
			[value containsString:@","])
		{
			return nil;
		}

		return value;
	}

	return nil;
}

- (NSString *)serverInfo
{
	/* NSURL drops the brackets of an IPv6 address; without them the
	 address can't be told from the port */
	NSString *host = self.host;

	if ([host containsString:@":"] && [host hasPrefix:@"["] == NO) {
		host = [NSString stringWithFormat:@"[%@]", host];
	}

	if (self.secure) {
		return [NSString stringWithFormat:@"-SSL %@:%hu", host, self.port];
	}

	return [NSString stringWithFormat:@"%@:%hu", host, self.port];
}

- (NSString *)channelList
{
	return [self.channels componentsJoinedByString:@","];
}

@end

NS_ASSUME_NONNULL_END
