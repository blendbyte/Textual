/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
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

@class IRCChannelUser, IRCUser;

#pragma mark -
#pragma mark Prototype

/* IRCChannel proxies many methods declared by IRCChannelMemberList
 for backwards compatibility and convenience through the use of
 IRCChannelMemberListPrototype protocol. It's atypical to access
 IRCChannelMemberList directly. The declaration for it is only
 public to allow KVO binding to -memberList and -numberOfMembers. */

/* In context of IRCChannel proxied methods:

 An instance of IRCChannel will only have a member list when in
 active state. This includes regular channels and private messages.
 Utility channels will never have a member list.

 All proxied methods will do nothing when there is no member list.
 */
@protocol IRCChannelMemberListPrototype <NSObject>
/* Member changes (adding, removing, modifying) are done so asynchronously.
 This means that changes wont be immediately reflected by -memberList. */
/* It is safe to call -memberExists: and -findMember: immediately after
 changing a member because those methods do not require the member to
 be present in the member list to produce a result. */
- (void)addUser:(IRCUser *)user;

- (void)addMember:(IRCChannelUser *)member;

- (void)removeMember:(IRCChannelUser *)member;
- (void)removeMemberWithNickname:(NSString *)nickname;

- (BOOL)memberExists:(NSString *)nickname;

- (nullable IRCChannelUser *)findMember:(NSString *)nickname;

/* -memberList and -numberOfMembers are KVO compliant when
 bound directly to an instance of IRCChannelMemberList.
 The methods that IRCChannel proxy will not post KVO changes. */
@property (readonly) NSUInteger numberOfMembers;

@property (readonly, copy, nullable) NSArray<IRCChannelUser *> *memberList; // Automatically sorted by channel rank

/* Resort the entire member list using all known conditions. */
/* This can be an expensive task for large channels. */
- (void)sortMembers;
@end

#pragma mark -
#pragma mark Interface

@interface IRCChannelMemberList : NSObject <IRCChannelMemberListPrototype>
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
