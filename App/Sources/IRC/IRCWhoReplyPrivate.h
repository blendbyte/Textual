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

NS_ASSUME_NONNULL_BEGIN

@class IRCMessage;

/* One line of a WHO answer: RPL_WHOREPLY (352) or, for Textual's own WHOX
 request "%tcuhnfar,152", RPL_WHOSPCRPL (354) */
@interface IRCWhoReply : NSObject
@property (readonly, copy) NSString *channelName;
@property (readonly, copy) NSString *nickname;
@property (readonly, copy) NSString *username;
@property (readonly, copy) NSString *address;
@property (readonly, copy) NSString *flags; // H|G, then * for IRC operators, then member prefixes
@property (readonly, copy, nullable) NSString *realName;
@property (readonly) BOOL accountKnown; // only WHOX reports the account
@property (readonly, copy, nullable) NSString *account; // nil: logged out (when accountKnown)

/* nil when the line is malformed (or, for 354, not an answer to Textual's request) */
+ (nullable instancetype)replyFromWhoReply:(IRCMessage *)m;
+ (nullable instancetype)replyFromWhoxReply:(IRCMessage *)m;
@end

/* The WHOX fields and query type Textual requests: t=token (152), c=channel,
 u=username, h=host, n=nickname, f=flags, a=account, r=real name */
TEXTUAL_EXTERN NSString * const IRCWhoReplyWhoxRequest;

NS_ASSUME_NONNULL_END
