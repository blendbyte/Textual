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

#import "IRCHighlightMatchCondition.h"
#import "IRCISupportInfo.h"

NS_ASSUME_NONNULL_BEGIN

/* Highlight keywords: one list in Preferences →
 Highlights for every server. A keyword can be limited to channels or whole
 networks and to people; a highlight word can have its own sound. Stored in
 "Highlight List -> Primary Matches" and "Highlight List -> Excluded Matches"
 as dictionaries with these keys (only "string" is required). */
extern NSString * const IRCHighlightKeywordStringKey; // the keyword
extern NSString * const IRCHighlightKeywordLimitedToKey; // client and channel ids; none = everywhere
extern NSString * const IRCHighlightKeywordNicknamesKey; // nicknames; none = anyone
extern NSString * const IRCHighlightKeywordSoundKey; // a sound name; none = the highlight sound

@interface IRCHighlightKeyword : NSObject
@property (readonly, copy) NSString *keyword;
@property (readonly, copy) NSArray<NSString *> *limitedTo;
@property (readonly, copy) NSArray<NSString *> *nicknames;
@property (readonly, copy, nullable) NSString *sound;

/* Entries without a keyword are left out */
+ (NSArray<IRCHighlightKeyword *> *)keywordsWithDictionaries:(nullable NSArray *)dictionaries;

- (BOOL)appliesToChannelWithId:(NSString *)channelId clientId:(NSString *)clientId;

/* Compared with the server's case mapping */
- (BOOL)appliesToNickname:(NSString *)nickname supportInfo:(IRCISupportInfo *)supportInfo;

/* A server's own list (Textual 7's Server Properties → Highlights) moved
 into the stored entries: a keyword without a channel is limited to that
 server. Skipped when the keyword is already there for everyone; added to
 the limits of an entry for the same keyword limited to other places */
+ (NSArray<NSDictionary *> *)entries:(nullable NSArray<NSDictionary *> *)entries
		  mergingServerConditions:(NSArray<IRCHighlightMatchCondition *> *)conditions
						 excluded:(BOOL)excluded
						 clientId:(NSString *)clientId;
@end

NS_ASSUME_NONNULL_END
