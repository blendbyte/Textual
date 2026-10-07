/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
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

NS_ASSUME_NONNULL_BEGIN

@class IRCClient, IRCPrefix;

#pragma mark -
#pragma mark Immutable Object

@interface IRCMessage : XRPortablePropertyObject
@property (readonly, copy) IRCPrefix *sender;
@property (readonly, copy) NSString *command;
@property (readonly) NSUInteger commandNumeric;
@property (readonly, copy) NSArray<NSString *> *params;
@property (readonly, copy) NSDate *receivedAt;
@property (readonly) BOOL isHistoric; // Whether a custom @time= was supplied during parsing.
@property (readonly) BOOL isEventOnlyMessage; /* The message should be parsed and special actions performed such as adding/removing user but the result is never passed to print: */
@property (readonly) BOOL isPrintOnlyMessage; /* The message should be parsed and passed to print: but special actions such as adding/removing user from member list should be ignored. (currently unused) */
@property (readonly, copy, nullable) NSString *batchToken;
@property (readonly, copy, nullable) NSDictionary<NSString *, NSString *> *messageTags; /* IRCv3 message tags. See ircv3.net for more information regarding extensions in the IRC protocol. */

- (nullable instancetype)initWithLine:(NSString *)line;
- (nullable instancetype)initWithLine:(NSString *)line onClient:(nullable IRCClient *)client NS_DESIGNATED_INITIALIZER;

@property (readonly, copy, nullable) NSString *senderNickname;
@property (readonly, copy, nullable) NSString *senderUsername;
@property (readonly, copy, nullable) NSString *senderAddress;
@property (readonly, copy, nullable) NSString *senderHostmask;

@property (readonly) BOOL senderIsServer;

@property (readonly) NSUInteger paramsCount;

- (NSString *)paramAt:(NSUInteger)index;

@property (readonly, copy) NSString *sequence;
- (NSString *)sequence:(NSUInteger)index;
@end

#pragma mark -
#pragma mark Mutable Object

@interface IRCMessageMutable : IRCMessage
@property (nonatomic, copy, readwrite) IRCPrefix *sender;
@property (nonatomic, copy, readwrite) NSString *command;
@property (nonatomic, assign, readwrite) NSUInteger commandNumeric;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *params;
@property (nonatomic, copy, readwrite) NSDate *receivedAt;
@property (nonatomic, assign, readwrite) BOOL isHistoric;
@property (nonatomic, assign, readwrite) BOOL isEventOnlyMessage;
@property (nonatomic, assign, readwrite) BOOL isPrintOnlyMessage;
@property (nonatomic, copy, readwrite, nullable) NSString *batchToken;
@property (nonatomic, copy, readwrite, nullable) NSDictionary<NSString *, NSString *> *messageTags;
@end

NS_ASSUME_NONNULL_END
