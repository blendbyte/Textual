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

@class IRCModeInfo;

typedef NS_ENUM(NSUInteger, IRCISupportInfoListType)
{
	IRCISupportInfoListTypeBan,
	IRCISupportInfoListTypeBanException,
	IRCISupportInfoListTypeInviteException,
	IRCISupportInfoListTypeQuiet
};

/* How nicknames and channel names compare without regard to case (CASEMAPPING) */
typedef NS_ENUM(NSUInteger, IRCISupportInfoCaseMapping)
{
	IRCISupportInfoCaseMappingRFC1459 = 0, // A-Z and []\~ fold to a-z and {}|^; the default when a server doesn't say
	IRCISupportInfoCaseMappingStrictRFC1459, // A-Z and []\ fold to a-z and {}|
	IRCISupportInfoCaseMappingASCII, // A-Z fold to a-z
	IRCISupportInfoCaseMappingUnicode // any other mapping (e.g. rfc8265): Unicode lower case
};

#define IRCISupportInfoHighestUserPrefixRank			100

#define IRCISupportUserModeSymbolsSymbolsKey			@"modeSymbols"
#define IRCISupportUserModeSymbolsCharactersKey			@"characters"

@interface IRCISupportInfo : NSObject
@property (readonly) BOOL configurationReceived;
@property (readonly) NSUInteger maximumAwayLength; // 0 = no limit
@property (readonly) NSUInteger maximumChannelNameLength; // 0 = no limit - unused
@property (readonly) NSUInteger maximumKeyLength; // 0 = no limit
@property (readonly) NSUInteger maximumKickLength; // 0 = no limit
@property (readonly) NSUInteger maximumNicknameLength;
@property (readonly) NSUInteger maximumTopicLength; // 0 = no limit
@property (readonly) NSUInteger maximumModeCount;
@property (readonly, copy) NSArray<NSString *> *channelNamePrefixes;
@property (readonly, copy) NSArray<NSString *> *statusMessageModeSymbols;
@property (readonly, copy) NSDictionary<NSString *, NSNumber *> *channelModes;
@property (readonly, copy) NSDictionary<NSString *, NSArray *> *userModeSymbols;
@property (readonly, copy, nullable) NSString *banExceptionModeSymbol;
@property (readonly, copy, nullable) NSString *inviteExceptionModeSymbol;
@property (readonly, copy, nullable) NSString *serverAddress;
@property (readonly, copy, nullable) NSString *networkName;
@property (readonly, copy, nullable) NSString *networkNameFormatted;
@property (readonly) IRCISupportInfoCaseMapping caseMapping;
@property (readonly) NSUInteger chatHistoryLimit; // CHATHISTORY: most messages per request; 0 = not advertised or no limit
@property (readonly) BOOL utf8Only; // UTF8ONLY: the server takes and sends only UTF-8
@property (readonly) BOOL whoxSupported; // WHOX: extended WHO with selectable fields

/* A nickname or channel name folded with the server's CASEMAPPING: two
 names are the same when their folded strings are equal */
- (NSString *)foldedString:(NSString *)string;

- (instancetype)init NS_UNAVAILABLE;

- (nullable NSString *)modeSymbolForUserPrefix:(NSString *)character;
- (nullable NSString *)userPrefixForModeSymbol:(NSString *)modeSymbol;

- (BOOL)characterIsUserPrefix:(NSString *)character;
- (BOOL)modeSymbolIsUserPrefix:(NSString *)modeSymbol;

- (nullable NSString *)statusMessagePrefixForModeSymbol:(NSString *)modeSymbol;
- (NSString *)extractStatusMessagePrefixFromChannelNamed:(NSString *)channel;

- (NSUInteger)rankForUserPrefixWithMode:(NSString *)modeSymbol; // Starts at 100; 100 = highest rank

- (IRCModeInfo *)createModeWithSymbol:(NSString *)modeSymbol;
- (IRCModeInfo *)createModeWithSymbol:(NSString *)modeSymbol modeIsSet:(BOOL)modeIsSet modeParameter:(nullable NSString *)modeParameter;

- (BOOL)isListSupported:(IRCISupportInfoListType)listType;

- (nullable NSString *)modeSymbolForList:(IRCISupportInfoListType)listType;
@end

NS_ASSUME_NONNULL_END
