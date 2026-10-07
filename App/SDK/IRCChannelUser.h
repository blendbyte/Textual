/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2019 Codeux Software, LLC & respective contributors.
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

@class IRCUser, IRCUserMutable;

typedef NS_OPTIONS(NSUInteger, IRCUserRank) {
	IRCUserRankNone				= 1 << 0,	// nothing
	IRCUserRankIRCopByMode		= 1 << 1,	// +y/+Y
	IRCUserRankChannelOwner		= 1 << 2,	// +q
	IRCUserRankSuperOperator	= 1 << 3,	// +a
	IRCUserRankNormalOperator	= 1 << 4,	// +o
	IRCUserRankHalfOperator		= 1 << 5,	// +h
	IRCUserRankVoiced			= 1 << 6	// +v
};

#pragma mark -
#pragma mark Immutable Object

@interface IRCChannelUser : XRPortablePropertyObject
@property (readonly, strong) IRCUser *user;

@property (getter=isOp, readonly) BOOL op;
@property (getter=isHalfOp, readonly) BOOL halfOp;

// -rank(s) returns IRCUserRankIRCopByMode if the +Y/+y modes defined
// by InspIRCd-2.0 for IRC operators are in use by this user. It does not
// return this if the user is an IRC operator, but lacks these modes.
// Use -isCop for the status of the user regardless of these modes.
@property (readonly) IRCUserRank rank; // Highest rank user has
@property (readonly) IRCUserRank ranks; // All ranks user as a bitmask

@property (readonly, copy) NSString *modes; // List of all user modes, ranked highest to lowest
@property (readonly, copy) NSString *mark; // Returns mode symbol for highest rank (-modes)

/* Weight used when completing nicknames. */
/* Accessing totalWeight decays the weight. */
/* Accessing other weight properties does not. */
@property (readonly) double totalWeight; // (incoming + outgoing) with decay
@property (readonly) double incomingWeight;
@property (readonly) double outgoingWeight;

/* Timestamp instance of IRCChannelUser was created. */
@property (readonly) NSTimeInterval creationTime;

- (instancetype)init NS_UNAVAILABLE;
@end

#pragma mark -
#pragma mark Mutable Object

@interface IRCChannelUserMutable : IRCChannelUser
@property (nonatomic, copy, readwrite) NSString *modes;
@end

NS_ASSUME_NONNULL_END
