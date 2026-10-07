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

/* Each user on a server is allocated one instance of IRCUser. 
 IRCUser is used to keep track of information related to the user. */
/* There is ever only one instance of IRCUser kept track of by the
 IRCClient class. It is possible to create a mutable copy of a user
 to change properties, but those changes will not be recognized until
 the modified user is given to IRCClient. IRCClient will then perform
 the actions necessary to update all components depending on the user. */

NS_ASSUME_NONNULL_BEGIN

@class IRCClient;

#pragma mark -
#pragma mark Immutable Object

@interface IRCUser : XRPortablePropertyObject
@property (readonly, copy) NSString *nickname;
@property (readonly, copy, nullable) NSString *username;
@property (readonly, copy, nullable) NSString *address;
@property (readonly, copy, nullable) NSString *hostmask;
@property (readonly, copy, nullable) NSString *hostmaskFragment; // -hostmask without nickname
@property (readonly, copy, nullable) NSString *realName;
@property (readonly) BOOL isAway;
@property (readonly) BOOL isIRCop;

@property (readonly, copy) NSString *banMask;

@property (readonly, copy) NSString *lowercaseNickname;
@property (readonly, copy) NSString *uppercaseNickname;

/* -presentAwayMessageFor301 keeps track of the last time raw numeric
 301 (away message) is received and will return YES if the message
 should be presented, NO otherwise. */
@property (readonly) BOOL presentAwayMessageFor301;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithNickname:(NSString *)nickname onClient:(IRCClient *)client NS_DESIGNATED_INITIALIZER;

- (void)markAsAway;
- (void)markAsReturned;
@end

#pragma mark -
#pragma mark Mutable Object

@interface IRCUserMutable : IRCUser
@property (nonatomic, copy, readwrite) NSString *nickname; // Defaults to empty string
@property (nonatomic, copy, readwrite, nullable) NSString *username;
@property (nonatomic, copy, readwrite, nullable) NSString *address;
@property (nonatomic, copy, readwrite, nullable) NSString *realName;
@property (nonatomic, assign, readwrite) BOOL isAway;
@property (nonatomic, assign, readwrite) BOOL isIRCop;

- (instancetype)initWithClient:(IRCClient *)client;
@end

NS_ASSUME_NONNULL_END
