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

#import "IRC.h"
#import "IRCClient.h"
#import "IRCISupportInfo.h"
#import "IRCColorFormat.h"
#import "TPCPreferencesLocal.h"
#import "TVCLogRenderer.h"

NS_ASSUME_NONNULL_BEGIN

NSStringEncoding const TXDefaultPrimaryStringEncoding = NSUTF8StringEncoding;
NSStringEncoding const TXDefaultFallbackStringEncoding = NSISOLatin1StringEncoding;

@implementation NSString (TXStringHelper)

- (BOOL)isValidInternetAddress
{
	if (self.length == 0) {
		return NO;
	}

	if (self.isIPAddress || [self isEqualToString:@"localhost"]) {
		return YES;
	}

	return [self onlyContainsCharactersFromCharacterSet:
			[NSCharacterSet Ato9UnderscoreDashPeriod]];
}

- (BOOL)isValidInternetPort
{
	if (self.isNumericOnly == NO) {
		return NO;
	}

	NSInteger selfInt = self.integerValue;

	return (selfInt > 0 && selfInt <= TXMaximumTCPPort);
}

- (NSString *)stringByAppendingIRCFormattingStop
{
	return [self stringByAppendingFormat:@"%C", IRCTextFormatterTerminatingCharacter];
}

- (BOOL)hostmaskComponents:(NSString * _Nullable * _Nullable)nickname username:(NSString * _Nullable * _Nullable)username address:(NSString * _Nullable * _Nullable)address
{
	return [self hostmaskComponents:nickname username:username address:address onClient:nil];
}

- (BOOL)hostmaskComponents:(NSString * _Nullable * _Nullable)nickname username:(NSString * _Nullable * _Nullable)username address:(NSString * _Nullable * _Nullable)address onClient:(nullable IRCClient *)client
{
	if (self.length == 0) {
		return NO;
	}

	/* Find first ! starting from left side of string */
	NSRange bang1pos = [self rangeOfString:@"!" options:NSLiteralSearch];

	/* Find first @ starting from the right side of string */
	NSRange bang2pos = [self rangeOfString:@"@" options:(NSLiteralSearch | NSBackwardsSearch)];

	if ((bang1pos.location == NSNotFound) ||
		(bang2pos.location == NSNotFound) ||
		(bang2pos.location <= bang1pos.location))
	{
		return NO;
	}

	NSString *nicknameInt = [self substringToIndex:bang1pos.location];

	NSString *usernameInt = [self substringWithRange:
							 NSMakeRange((bang1pos.location + 1),
										 (bang2pos.location - (bang1pos.location + 1)))];

	NSString *addressInt = [self substringAfterIndex:bang2pos.location];

	if ([nicknameInt isHostmaskNicknameOn:client] == NO ||
		[usernameInt isHostmaskUsernameOn:client] == NO ||
		[addressInt isHostmaskAddressOn:client] == NO)
	{
		return NO;
	}

	if ( nickname) {
		*nickname = nicknameInt;
	}

	if ( username) {
		*username = usernameInt;
	}

	if ( address) {
		*address = addressInt;
	}

	return YES;
}

- (BOOL)isHostmask
{
	return [self hostmaskComponents:nil username:nil address:nil];
}

- (BOOL)isHostmaskAddress
{
	return [self isHostmaskAddressOn:nil];
}

- (BOOL)isHostmaskAddressOn:(nullable IRCClient *)client
{
	return (self.length > 0 &&
			[self containsCharacters:@"\x021\x040\x000\x020\x00d\x00a"] == NO);
}

- (BOOL)isHostmaskUsername
{
	return [self isHostmaskUsernameOn:nil];
}

- (BOOL)isHostmaskUsernameOn:(nullable IRCClient *)client
{
	return (self.length > 0 &&
			self.length <= TXMaximumIRCUsernameLength &&
			[self containsCharacters:@"\x000\x020\x00d\x00a"] == NO);
}

- (BOOL)isHostmaskNickname
{
	return [self isHostmaskNicknameOn:nil];
}

- (BOOL)isHostmaskNicknameOn:(nullable IRCClient *)client
{
	NSUInteger maximumLength = TXMaximumIRCNicknameLength;

	if (client) {
		/* At least one server has been found (gitter.im) has been found
		 which does not send a configuration profile. They allow a 
		 nickname length larger than IRCISupportInfo uses as a default
		 which means parsing will go wonky. */
		/* A smarter workaround would probably to check if specific 
		 configuration options were received (e.g. "NICKLEN"), but that 
		 has more overhead than using a boolean. */

		if (client.supportInfo.configurationReceived) {
			maximumLength = client.supportInfo.maximumNicknameLength;
		} else {
			maximumLength = 0;
		}

		/* If we are connected to ZNC, then do not enforce maximum 
		 nickname length. It is easier to disable this check than
		 to check whether a nickname (e.g. *buffextras) should be
		 handled differently. */
		if (client.isConnectedToZNC) {
			maximumLength = 0;
		}
	}

	if (maximumLength == 0) {
		maximumLength = TXMaximumIRCNicknameLength;
	}

	return ([self isNotEqualTo:@"*"] &&
			self.length > 0 &&
			self.length <= maximumLength &&
			[self containsCharacters:@"\x021\x040\x000\x020\x00d\x00a"] == NO);
}

- (BOOL)isChannelNameOn:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if (self.length == 0) {
		return NO;
	}

	/* A maximum length is not current imposed on channel names,
	 even though we have that information, because -isChannelNameOn:
	 is called in -[IRCClient sendCommand:...] to check whether the
	 the input string for a command begins with a channel name before
	 we perform tokenizing. During that time, the input string can be
	 any possible length. We therefore only check if the string begins
	 with known channel name prefixes and allow server to perform
	 extensive validation on the channel name. */
	NSArray *channelNamePrefixes = client.supportInfo.channelNamePrefixes;

	if (self.length == 1) {
		NSString *character = [self stringCharacterAtIndex:0];

		return [channelNamePrefixes containsObject:character];
	}

	NSString *character1 = [self stringCharacterAtIndex:0];
	NSString *character2 = [self stringCharacterAtIndex:1];

	/* The ~ prefix is considered special. It is used by the ZNC partyline plugin. */
	BOOL isPartyline = ([character1 isEqualToString:@"~"] && [character2 isEqualToString:@"#"]);

	return (isPartyline || [channelNamePrefixes containsObject:character1]);
}

- (BOOL)isChannelName
{
	if (self.length == 0) {
		return NO;
	}

	UniChar c = [self characterAtIndex:0];

	return (c == '#' ||
			c == '&' ||
			c == '+' ||
			c == '!' ||
			c == '~' ||
			c == '?');
}

- (nullable NSString *)channelNameWithoutBang
{
	if (self.isChannelName == NO) {
		return self;
	}

	return [self substringFromIndex:1];
}

- (nullable NSString *)channelNameWithoutBangOn:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if ([self isChannelNameOn:client] == NO) {
		return self;
	}

	if (self.length < 2) { // Do not turn "#" into empty string
		return self;
	}

	NSArray *channelNamePrefixes = client.supportInfo.channelNamePrefixes;

	NSString *character = [self stringCharacterAtIndex:0];

	if ([channelNamePrefixes containsObject:character]) {
		return [self substringFromIndex:1];
	}

	return self;
}

- (nullable NSString *)nicknameFromHostmask
{
	NSString *nickname = nil;

	if ([self hostmaskComponents:&nickname username:nil address:nil]) {
		return nickname;
	}

	return self;
}

- (nullable NSString *)usernameFromHostmask
{
	NSString *username = nil;

	if ([self hostmaskComponents:nil username:&username address:nil]) {
		return username;
	}

	return nil;
}

- (nullable NSString *)addressFromHostmask
{
	NSString *address = nil;

	if ([self hostmaskComponents:nil username:nil address:&address]) {
		return address;
	}

	return nil;
}

- (nullable NSString *)stringWithValidURIScheme
{
	return [AHHyperlinkScanner URLWithProperScheme:self];
}

- (nullable NSAttributedString *)attributedStringWithIRCFormatting:(NSFont *)preferredFont preferredFontColor:(nullable NSColor *)preferredFontColor honorFormattingPreference:(BOOL)formattingPreference
{
	if (formattingPreference && [TPCPreferences removeAllFormatting]) {
		NSString *string = self.stripIRCEffects;

		return [NSAttributedString attributedStringWithString:string];
	}

	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

	if (preferredFont) {
		attributes[TVCLogRendererConfigurationAttributedStringPreferredFontAttribute] = preferredFont;
	}

	if (preferredFontColor) {
		attributes[TVCLogRendererConfigurationAttributedStringPreferredFontColorAttribute] = preferredFontColor;
	}

	return [TVCLogRenderer renderBodyAsAttributedString:self withAttributes:attributes];
}

- (nullable NSAttributedString *)attributedStringWithIRCFormatting:(NSFont *)preferredFont preferredFontColor:(nullable NSColor *)preferredFontColor
{
	return [self attributedStringWithIRCFormatting:preferredFont preferredFontColor:preferredFontColor honorFormattingPreference:NO];
}

- (NSString *)stripIRCEffects
{
	NSUInteger stringLength = self.length;

	if (stringLength == 0) {
		return self;
	}

	NSUInteger currentPosition = 0;

	NSUInteger bufferLength = (stringLength * sizeof(UniChar));

	UniChar *inputBuffer = alloca(bufferLength);
	UniChar *outputBuffer = alloca(bufferLength);

	[self getCharacters:inputBuffer range:self.range];

	for (NSUInteger i = 0; i < stringLength; i++) {
		UniChar character = inputBuffer[i];

		switch (character) {
			case IRCTextFormatterEffectBoldCharacter:
			case IRCTextFormatterEffectItalicCharacter:
			case IRCTextFormatterEffectItalicCharacterOld:
			case IRCTextFormatterEffectMonospaceCharacter:
			case IRCTextFormatterEffectStrikethroughCharacter:
			case IRCTextFormatterEffectUnderlineCharacter:
			case IRCTextFormatterTerminatingCharacter:
			{
				break;
			}
			case IRCTextFormatterEffectColorAsDigitCharacter:
			case IRCTextFormatterEffectColorAsHexCharacter:
			{
				// One is subtracted because the for loop will increment by one for us
				i += ([self colorComponentsOfCharacter:character startingAt:i foregroundColor:NULL backgroundColor:NULL] - 1);

				break;
			}
			default:
			{
				outputBuffer[currentPosition++] = character;

				break;
			}
		}
	}

	return [NSString stringWithCharacters:outputBuffer length:currentPosition];
}

- (NSUInteger)colorComponentsOfCharacter:(UniChar)character startingAt:(NSUInteger)rangeStart foregroundColor:(id _Nullable * _Nullable)foregroundColor backgroundColor:(id _Nullable * _Nullable)backgroundColor
{
	if (character == IRCTextFormatterEffectColorAsDigitCharacter) {
		return [self colorAsDigitStartingAt:rangeStart foregroundColor:foregroundColor backgroundColor:backgroundColor];
	} else if (character == IRCTextFormatterEffectColorAsHexCharacter) {
		return [self colorAsHexStartingAt:rangeStart foregroundColor:foregroundColor backgroundColor:backgroundColor];
	}

	return 0;
}

- (NSUInteger)colorAsHexStartingAt:(NSUInteger)rangeStart foregroundColor:(NSColor * _Nullable * _Nullable)foregroundColor backgroundColor:(NSColor * _Nullable * _Nullable)backgroundColor
{
	NSUInteger selfLength = self.length;

	NSParameterAssert(rangeStart < selfLength);

	NSUInteger currentPosition = rangeStart;

	NSString *m_foregroundColor = nil;
	NSString *m_backgroundColor = nil;

	BOOL commaEaten = NO;

	// ========================================== //

	/* Control character */
	currentPosition++;

	// ========================================== //

	/* Foreground hex color */
	if ((currentPosition + 6) > selfLength) {
		goto return_method;
	}

	m_foregroundColor = [self substringWithRange:NSMakeRange(currentPosition, 6)];

	if ([m_foregroundColor onlyContainsCharactersFromCharacterSet:[NSCharacterSet hexadecimalCharacterSet]]) {
		currentPosition += 6; // Eat foreground color
	} else {
		m_foregroundColor = nil;

		goto return_method;
	}

	// ========================================== //

	/* Comma */
	if (currentPosition >= selfLength) {
		goto return_method;
	}

	UniChar a = [self characterAtIndex:currentPosition];

	if (a == ',') {
		commaEaten = YES;

		currentPosition++; // Eat comma
	} else {
		goto return_method;
	}

	// ========================================== //

	/* Background hex color */
	if ((currentPosition + 6) > selfLength) {
		goto return_method;
	}

	m_backgroundColor = [self substringWithRange:NSMakeRange(currentPosition, 6)];

	if ([m_backgroundColor onlyContainsCharactersFromCharacterSet:[NSCharacterSet hexadecimalCharacterSet]]) {
		currentPosition += 6; // Eat background color
	} else {
		m_backgroundColor = nil;
	}

	// ========================================== //

return_method:
	if (m_backgroundColor == nil && commaEaten) {
		currentPosition -= 1;
	}

	if ( foregroundColor && m_foregroundColor != nil) {
		*foregroundColor = [NSColor colorWithHexadecimalValue:m_foregroundColor.uppercaseString];
	}

	if ( backgroundColor && m_backgroundColor != nil) {
		*backgroundColor = [NSColor colorWithHexadecimalValue:m_backgroundColor.uppercaseString];
	}

	return (currentPosition - rangeStart);
}

- (NSUInteger)colorAsDigitStartingAt:(NSUInteger)rangeStart foregroundColor:(NSNumber * _Nullable * _Nullable)foregroundColor backgroundColor:(NSNumber * _Nullable * _Nullable)backgroundColor
{
	NSUInteger selfLength = self.length;

	NSParameterAssert(rangeStart < selfLength);

	NSUInteger currentPosition = rangeStart;

	NSUInteger m_foregroundColor = NSNotFound;
	NSUInteger m_backgroundColor = NSNotFound;

	BOOL commaEaten = NO;

	// ========================================== //

	/* Control character */
	currentPosition++;

	// ========================================== //

	/* Foreground color first color number */
	if (currentPosition >= selfLength) {
		goto return_method;
	}

	UniChar a = [self characterAtIndex:currentPosition];

	if (CS_StringIsBase10Numeric(a) == NO) {
		goto return_method;
	}

	m_foregroundColor = (a - '0');

	currentPosition++; // Eat first color number

	// ========================================== //

	/* Foreground color second color number */
	if (currentPosition >= selfLength) {
		goto return_method;
	}

	UniChar b = [self characterAtIndex:currentPosition];

	if (CS_StringIsBase10Numeric(b)) {
		m_foregroundColor = (m_foregroundColor * 10 + b - '0');

		currentPosition++; // Eat second color number
	}

	// ========================================== //

	/* Comma */
	if (currentPosition >= selfLength) {
		goto return_method;
	}

	UniChar c = [self characterAtIndex:currentPosition];

	if (c == ',') {
		commaEaten = YES;

		currentPosition++; // Eat comma
	} else {
		goto return_method;
	}

	// ========================================== //

	/* Background color first color number */
	if (currentPosition >= selfLength) {
		goto return_method;
	}

	UniChar d = [self characterAtIndex:currentPosition];

	if (CS_StringIsBase10Numeric(d) == NO) {
		goto return_method;
	}

	m_backgroundColor = (d - '0');

	currentPosition++; // Eat first color number

	// ========================================== //

	/* Background color second color number */
	if (currentPosition >= selfLength) {
		goto return_method;
	}

	UniChar e = [self characterAtIndex:currentPosition];

	if (CS_StringIsBase10Numeric(e) == NO) {
		goto return_method;
	}

	m_backgroundColor = (m_backgroundColor * 10 + e - '0');

	currentPosition++; // Eat second color number

	// ========================================== //

return_method:
	if (m_backgroundColor == NSNotFound && commaEaten) {
		currentPosition -= 1;
	}

	if (  foregroundColor &&
		m_foregroundColor != NSNotFound &&
		m_foregroundColor <= IRCTextFormatterEffectColorHighestDigit)
	{
		*foregroundColor = @(m_foregroundColor);
	}

	if (  backgroundColor &&
		m_backgroundColor != NSNotFound &&
		m_backgroundColor <= IRCTextFormatterEffectColorHighestDigit)
	{
		*backgroundColor = @(m_backgroundColor);
	}

	return (currentPosition - rangeStart);
}

- (NSArray<NSString *> *)base64EncodingWithLineLength:(NSUInteger)lineLength
{
	if (self.length == 0) {
		return @[self];
	}

	NSData *selfData = [self dataUsingEncoding:NSUTF8StringEncoding];

	NSString *encodedString = [XRBase64Encoding encodeData:selfData];

	return [encodedString splitWithMaximumLength:lineLength];
}

- (nullable NSString *)padNicknameWithCharacter:(UniChar)padCharacter maximumLength:(NSUInteger)maximumLength
{
	NSParameterAssert(padCharacter != 0);
	NSParameterAssert(maximumLength > 0);

	NSString *padCharacterString = [NSString stringWithUniChar:padCharacter];

	if (self.length < maximumLength) {
		return [self stringByAppendingString:padCharacterString];
	}

	NSString *substring = [self substringToIndex:maximumLength];

	for (NSInteger i = (substring.length - 1); i >= 0; i--) {
		UniChar substringCharacter = [substring characterAtIndex:i];

		if (substringCharacter == padCharacter) {
			continue;
		}

		NSString *stringHead = [substring substringToIndex:i];

		NSMutableString *stringHeadMutable = [stringHead mutableCopy];

		for (NSUInteger j = i; j < substring.length; j++) {
			[stringHeadMutable appendString:@"_"];
		}

		return [stringHeadMutable copy];
	}

	return nil;
}

- (nullable NSString *)prettyLicenseKey
{
#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
	if (self.length == 0) {
		return nil;
	}

	NSRange lastDashRange = [self rangeOfString:@"-" options:NSBackwardsSearch];

	if (lastDashRange.location == NSNotFound) {
		return nil;
	}

	/* Go from dash outward by 5 */
	lastDashRange.length = (lastDashRange.location + 6); // 1 = dash, 5 = numbers (1+5)
	lastDashRange.location = 0;

	NSString *licenseKey = [self substringWithRange:lastDashRange];

	return [licenseKey stringByAppendingString:@"…"];
#else
	return nil;
#endif
}

/* Source: https://ircv3.net/specs/core/message-tags-3.2.html */
- (NSString *)encodedMessageTagString
{
	if (self.length == 0) {
		return self;
	}

	NSMutableString *bob = [self mutableCopy];
	
	[bob replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:bob.range];
	[bob replaceOccurrencesOfString:@";" withString:@"\\:" options:0 range:bob.range];
	[bob replaceOccurrencesOfString:@" " withString:@"\\s" options:0 range:bob.range];
	[bob replaceOccurrencesOfString:@"\r" withString:@"\\r" options:0 range:bob.range];
	[bob replaceOccurrencesOfString:@"\n" withString:@"\\n" options:0 range:bob.range];
	
	return [bob copy];
}

- (NSString *)decodedMessageTagString
{
	/* One pass, so an escaped backslash followed by "s" stays "\s" instead
	 of becoming a space. Unknown escapes drop the backslash; a trailing
	 lone backslash is dropped. */
	if ([self rangeOfString:@"\\"].location == NSNotFound) {
		return self;
	}

	NSUInteger length = self.length;

	NSMutableString *decoded = [NSMutableString stringWithCapacity:length];

	for (NSUInteger i = 0; i < length; i++) {
		unichar character = [self characterAtIndex:i];

		if (character != '\\') {
			[decoded appendFormat:@"%C", character];

			continue;
		}

		i += 1;

		if (i == length) {
			break;
		}

		unichar escaped = [self characterAtIndex:i];

		switch (escaped) {
			case ':':
				[decoded appendString:@";"];
				break;
			case 's':
				[decoded appendString:@" "];
				break;
			case 'r':
				[decoded appendString:@"\r"];
				break;
			case 'n':
				[decoded appendString:@"\n"];
				break;
			default:
				[decoded appendFormat:@"%C", escaped];
				break;
		}
	}

	return [decoded copy];
}

- (BOOL)isModeSymbol
{
	if (self.length != 1) {
		return NO;
	}

	return [[NSCharacterSet AtoZCharacterSet] characterIsMember:[self characterAtIndex:0]];
}

@end

NS_ASSUME_NONNULL_END
