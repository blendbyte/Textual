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

NS_ASSUME_NONNULL_BEGIN

/* An irc:// or ircs:// link, read but not acted on (or a textual:// link, whose
 host names an app action):

	irc[s]://host[:port][/[#]channel[,[#]channel…][,flag…]][?key=channelkey]
	irc[s]://host[:port]/nickname,isuser

 Channels get a # when they have none. At most five sections after the slash
 count. After the first, the flags "needssl" (asks for TLS), "isuser" or
 "isnick" (the targets are people: a private message opens), "ischannel",
 "needkey" and "needpass" aren't targets (draft-butcher-irc-url-04).
 "?key=" is the first channel's key. */
@interface IRCProtocolLink : NSObject
/* The link with percent escapes decoded and surrounding spaces trimmed */
@property (readonly, copy) NSString *location;

@property (readonly, copy) NSString *scheme;
@property (readonly, copy) NSString *host;

/* The standard port for TLS or plain text when the link has none */
@property (readonly) uint16_t port;
@property (readonly) BOOL secure;

@property (readonly, copy) NSArray<NSString *> *channels;

/* "?key=": the key of the first channel */
@property (readonly, copy, nullable) NSString *channelKey;

/* ",isuser" or ",isnick": the people to open a private message with (no channels then) */
@property (readonly, copy) NSArray<NSString *> *nicknames;

/* "host:port", or "-SSL host:port", with an IPv6 address in brackets:
 as +[IRCExtras createConnectionToServer:…] reads it */
@property (readonly, copy) NSString *serverInfo;

/* The channels separated by commas */
@property (readonly, copy) NSString *channelList;

+ (nullable instancetype)linkWithString:(NSString *)location;
@end

NS_ASSUME_NONNULL_END
