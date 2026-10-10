/*
 * The AutoHyperlinks Framework is the legal property of its developers (DEVELOPERS), 
 * whose names are listed in the copyright file included with this source distribution.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the AutoHyperlinks Framework nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY ITS DEVELOPERS ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL ITS DEVELOPERS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "AHLinkLexer.h"

#import "AHHyperlinkScanner.h"
#import "AHHyperlinkScannerResultPrivate.h"

NS_ASSUME_NONNULL_BEGIN

typedef void					*yyscan_t;
typedef struct					AH_buffer_state *AH_BUFFER_STATE;

extern long						AHlex(yyscan_t yyscanner);
extern long						AHlex_init(yyscan_t *ptr_yy_globals);
extern long						AHlex_destroy(yyscan_t yyscanner);
extern long						AHget_leng(yyscan_t scanner);
extern void						AHset_in(FILE *in_str, yyscan_t scanner);
extern void						AH_switch_to_buffer(AH_BUFFER_STATE, yyscan_t scanner);
extern void						AH_delete_buffer(AH_BUFFER_STATE, yyscan_t scanner);
extern YY_EXTRA_TYPE			AHget_extra(yyscan_t scanner);
extern AH_BUFFER_STATE			AH_scan_string(const char *, yyscan_t scanner);

#define DEFAULT_URL_SCHEME	@"https://"

#define ENC_INDEX_KEY		@"encIndex"
#define ENC_CHAR_KEY		@"encChar"

#define MIN_URL_LENGTH 	4

@interface AHHyperlinkScannerContext : NSObject
@property (nonatomic, copy) NSString *scanString;
@property (nonatomic, assign) NSUInteger scanLocation;
@property (nonatomic, assign) BOOL strictMatch;
@property (nonatomic, strong) NSMutableArray *openEnclosureStack;

- (instancetype)initWithString:(NSString *)inString strictMatching:(BOOL)strictMatch;
@end

@implementation AHHyperlinkScanner

static NSArray *s_enclosureKeys = nil;
static NSArray *s_enclosureStartArray	= nil;
static NSArray *s_enclosureStopArray = nil;

static NSCharacterSet *s_enclosureCharacterSet = nil;
static NSCharacterSet *s_endCharacterSet = nil;
static NSCharacterSet *s_hostnameComponentCharacterSet = nil;
static NSCharacterSet *s_punctuationCharacterSet = nil;
static NSCharacterSet *s_skipCharacterSet	= nil;
static NSCharacterSet *s_startCharacterSet = nil;

#pragma mark -
#pragma mark Initialization

+ (void)initialize
{
	if (self == [AHHyperlinkScanner class]) {
		NSMutableCharacterSet *mutableSkipSet = [NSMutableCharacterSet new];

		[mutableSkipSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
		[mutableSkipSet formUnionWithCharacterSet:[NSCharacterSet illegalCharacterSet]];
		[mutableSkipSet formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
		[mutableSkipSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];

		NSMutableCharacterSet *mutableStartSet = [NSMutableCharacterSet new];

		[mutableStartSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
		[mutableStartSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"\"'“”‘’.…,:;<?!-–—@"]];

		NSMutableCharacterSet *mutablePuncSet = [NSMutableCharacterSet new];

		[mutablePuncSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
		[mutablePuncSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"\"'“”‘’.…,:;–—<?!"]];
		
		s_skipCharacterSet = [NSCharacterSet characterSetWithBitmapRepresentation:mutableSkipSet.bitmapRepresentation];
		s_punctuationCharacterSet = [NSCharacterSet characterSetWithBitmapRepresentation:mutablePuncSet.bitmapRepresentation];
		s_startCharacterSet = [NSCharacterSet characterSetWithBitmapRepresentation:mutableStartSet.bitmapRepresentation];
		s_endCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"\"'“”‘’,:;>)]}–—.…?!@"];

		s_hostnameComponentCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"./"];

		s_enclosureStartArray = @[@"(",@"[",@"{"];
		s_enclosureStopArray = @[@")",@"]",@"}"];
		s_enclosureCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"()[]{}"];

		s_enclosureKeys = @[ENC_INDEX_KEY, ENC_CHAR_KEY];
	}
}

#pragma mark -
#pragma mark Public Methods

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

+ (NSArray<AHHyperlinkScannerResult *> *)matchesInString:(NSString *)inString
{
	return [self matchesInString:inString strictMatching:NO];
}

+ (NSArray<AHHyperlinkScannerResult *> *)matchesInString:(NSString *)inString strictMatching:(BOOL)strictMatch
{
	NSParameterAssert(inString != nil);

	AHHyperlinkScannerContext *context = [[AHHyperlinkScannerContext alloc] initWithString:inString strictMatching:strictMatch];

	NSMutableArray<AHHyperlinkScannerResult *> *results = [NSMutableArray array];

	AHHyperlinkScannerResult *result = nil;

	while ((result = [self _nextURLInContext:context])) {
		[results addObject:result];
	}

	return [results copy];
}

+ (nullable NSString *)URLWithProperScheme:(NSString *)url
{
	AHParserStatus parserStatus = [self _isStringValidURL:url strictMatching:NO withIndex:NULL];

	if (parserStatus == AHParserURLInvalid) {
		return nil;
	}

	return [self _URLWithProperScheme:url parserStatus:parserStatus];
}

#pragma mark -
#pragma mark Private Methods

+ (AHParserStatus)_isStringValidURL:(NSString *)scanString strictMatching:(BOOL)strictMatch withIndex:(NSUInteger * _Nullable)scanLocationIn
{
	const char *CScanString = [scanString cStringUsingEncoding:NSUTF8StringEncoding];

	if (CScanString == NULL) {
		return AHParserURLInvalid;
	}

	yyscan_t scanner;

	AHlex_init(&scanner);
	
    AH_BUFFER_STATE buffer = AH_scan_string(CScanString, scanner);
	
    AHParserStatus validStatus = (AHParserStatus)AHlex(scanner);

	long scannerLength = AHget_leng(scanner);

	if (validStatus != AHParserURLInvalid && scannerLength != strlen(CScanString))
	{
		validStatus = AHParserURLInvalid;
	}
	else if (validStatus == AHParserURLWithScheme)
	{
		if ([self _isPermittedSchemeInString:scanString] == NO) {
			validStatus = AHParserURLInvalid;
		}
	}
	else if (validStatus == AHParserURLWithoutScheme && [self _hasRecognizedTopLevelDomain:scanString] == NO)
	{
		validStatus = AHParserURLInvalid;
	}
	else if (validStatus != AHParserURLPreconfigured && strictMatch)
	{
		validStatus = AHParserURLInvalid;
	}

	AH_delete_buffer(buffer, scanner);

	buffer = NULL;

	AHlex_destroy(scanner);

	/* The whole string is the URL: past it, in UTF-16 units (the lexer's
	 length is in UTF-8 bytes, so after a link with non-ASCII characters the
	 next link was missed or cut). Nothing moves for an invalid string; the
	 caller steps past it. */
	if (scanLocationIn && validStatus != AHParserURLInvalid) {
		*scanLocationIn += scanString.length;
	}

	return validStatus;
}

/* IANA's top-level domains (updated with Scripts/UpdateTopLevelDomains.sh), plus
 .local */
+ (NSSet<NSString *> *)_topLevelDomains
{
	static NSSet<NSString *> *topLevelDomains = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSURL *listURL = [[NSBundle bundleForClass:self] URLForResource:@"tlds-alpha-by-domain" withExtension:@"txt"];

		NSString *list = [NSString stringWithContentsOfURL:listURL encoding:NSUTF8StringEncoding error:NULL];

		NSMutableSet<NSString *> *domains = [NSMutableSet setWithObject:@"local"];

		for (NSString *line in [list componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
			if (line.length == 0 || [line hasPrefix:@"#"]) {
				continue;
			}

			[domains addObject:line.lowercaseString];
		}

		topLevelDomains = [domains copy];
	});

	return topLevelDomains;
}

/* Country codes that are also file extensions: "main.rs" or "readme.md" in a
 message is a file name, unless the address starts with www. */
+ (NSSet<NSString *> *)_fileExtensionTopLevelDomains
{
	static NSSet<NSString *> *extensions = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		extensions = [NSSet setWithArray:@[@"md", @"mov", @"py", @"rs", @"sh", @"zip"]];
	});

	return extensions;
}

/* For an address without a scheme: its host ends in a real top-level domain */
+ (BOOL)_hasRecognizedTopLevelDomain:(NSString *)url
{
	NSRange hostEnd = [url rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@":/?"]];

	NSString *host = ((hostEnd.location == NSNotFound) ? url : [url substringToIndex:hostEnd.location]).lowercaseString;

	NSRange lastDot = [host rangeOfString:@"." options:NSBackwardsSearch];

	if (lastDot.location == NSNotFound) {
		return NO;
	}

	NSString *topLevelDomain = [host substringFromIndex:NSMaxRange(lastDot)];

	if ([[self _topLevelDomains] containsObject:topLevelDomain] == NO) {
		return NO;
	}

	if ([[self _fileExtensionTopLevelDomains] containsObject:topLevelDomain] && [host hasPrefix:@"www."] == NO) {
		return NO;
	}

	return YES;
}

+ (BOOL)_isPermittedSchemeInString:(NSString *)scanString
{
	NSRange schemeColonRange = [scanString rangeOfString:@":" options:NSLiteralSearch];

	/* While a string without a scheme is technically invalid,
	 it is still permitted based on the logic of our parser. */
	if (schemeColonRange.location == NSNotFound) {
		return YES;
	}

	NSString *urlScheme = [scanString substringToIndex:schemeColonRange.location];

	return [self _isPermittedScheme:urlScheme];
}

/* Read from the defaults once, and again when they change: every candidate
 read all three keys */
+ (NSDictionary<NSString *, id> *)_permittedSchemes
{
	static NSDictionary<NSString *, id> *permittedSchemes = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		[[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *notification) {
			@synchronized (self) {
				permittedSchemes = nil;
			}
		}];
	});

	@synchronized (self) {
		if (permittedSchemes == nil) {
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

			NSMutableSet<NSString *> *schemes = [NSMutableSet set];

			for (NSString *key in @[@"com.adiumX.AutoHyperlinks.permittedSchemesDefault", @"com.adiumX.AutoHyperlinks.permittedSchemes"]) {
				for (id scheme in [defaults arrayForKey:key]) {
					if ([scheme isKindOfClass:[NSString class]]) {
						[schemes addObject:[scheme lowercaseString]];
					}
				}
			}

			permittedSchemes = @{
				@"any" : @([defaults boolForKey:@"com.adiumX.AutoHyperlinks.permittedSchemesAny"]),
				@"schemes" : [schemes copy]
			};
		}

		return permittedSchemes;
	}
}

/* Schemes are case-insensitive (HTTPS:// was not linked) */
+ (BOOL)_isPermittedScheme:(NSString *)scheme
{
	scheme = scheme.lowercaseString;

	if ([scheme isEqualToString:@"http"] ||
		[scheme isEqualToString:@"https"])
	{
		return YES;
	}

	NSDictionary *permittedSchemes = [self _permittedSchemes];

	if ([permittedSchemes[@"any"] boolValue]) {
		return YES;
	}

	return [permittedSchemes[@"schemes"] containsObject:scheme];
}

+ (nullable AHHyperlinkScannerResult *)_nextURLInContext:(AHHyperlinkScannerContext *)context
{
	NSParameterAssert(context != nil);

	NSString *scanString = context.scanString;

	NSUInteger scanLocation = context.scanLocation;

	NSRange	scanRange;

	// scan up to the next whitespace character so that we don't unnecessarily confuse flex
	// otherwise we end up validating urls that look like this "http://www.adium.im/ <--cool"
	[self _scanString:scanString charactersFromSet:s_startCharacterSet intoRange:nil withIndex:&scanLocation];

	NSMutableArray *openEnclosures = context.openEnclosureStack;

	// main scanning loop
	while ([self _scanString:scanString upToCharactersFromSet:s_skipCharacterSet intoRange:&scanRange withIndex:&scanLocation])
	{
		if (scanRange.length < MIN_URL_LENGTH) {
			continue;
		}

		/* Enclosures around a link: "(see https://example.com)" over several
		 words. A closing bracket is only taken off when it has no opening one
		 in the word, so "https://en.wikipedia.org/wiki/Foo_(bar)" keeps its
		 own; an unrelated "(" earlier in the message took it off. */
		NSString *firstCharacter = [scanString substringWithRange:NSMakeRange(scanRange.location, 1)];

		NSUInteger openingIndex = [s_enclosureStartArray indexOfObject:firstCharacter];

		NSString *topEncChar = openEnclosures.lastObject;

		if (openingIndex != NSNotFound) {
			scanRange.location++;
			scanRange.length--;

			if ([self _removeUnbalancedClosing:s_enclosureStopArray[openingIndex] opening:s_enclosureStartArray[openingIndex] fromRange:&scanRange inString:scanString] == NO) {
				if (openEnclosures.count < 16) {
					[openEnclosures addObject:s_enclosureStartArray[openingIndex]];
				}
			}
		} else if (topEncChar) {
			NSUInteger encIndex = [s_enclosureStartArray indexOfObject:topEncChar];

			if ([self _removeUnbalancedClosing:s_enclosureStopArray[encIndex] opening:topEncChar fromRange:&scanRange inString:scanString]) {
				[openEnclosures removeLastObject];
			}
		}

		if (scanRange.length == 0) {
			break;
		}

		// Find balanced enclosure characters
		NSRange longestEnclosure = [self _longestBalancedEnclosureInString:scanString range:scanRange];

		NSUInteger longestEnclosureMax = NSMaxRange(longestEnclosure);

		/* Trailing punctuation goes unless it closes a balanced enclosure (the
		 last character's index is compared: the length was, so nothing was
		 trimmed for links after the start of the message) */
		while (scanRange.length > 2 && [s_endCharacterSet characterIsMember:[scanString characterAtIndex:(NSMaxRange(scanRange) - 1)]]) {
			if (longestEnclosureMax < NSMaxRange(scanRange)) {
				scanRange.length--;
			} else {
				break;
			}
		}

		// Update the scan location
		scanLocation = scanRange.location;

		// If we have a valid URL then save the scanned string, and make a AHHyperlinkScannerResult out of it.
		AHHyperlinkScannerResult *result = [self _resultInString:scanString range:scanRange withIndex:&scanLocation strictMatching:context.strictMatch];

		if (result) {
			context.scanLocation = scanLocation;

			return result;
		}

		// Step location after scanning a string
		NSRange startRange = [scanString rangeOfCharacterFromSet:s_punctuationCharacterSet options:NSLiteralSearch range:scanRange];

		if (startRange.location != NSNotFound) {
			scanLocation = NSMaxRange(startRange);
		} else {
			scanLocation += scanRange.length;
		}

		context.scanLocation = scanLocation;
	}

	// Signal we are finished
	return nil;
}

+ (nullable AHHyperlinkScannerResult *)_resultInString:(NSString *)scanString range:(NSRange)scanRange withIndex:(NSUInteger * _Nullable)scanLocation strictMatching:(BOOL)strictMatch
{
	NSParameterAssert(scanString != NULL);

	if (scanRange.length < MIN_URL_LENGTH) {
		return nil;
	}

	NSString *fragment = [scanString substringWithRange:scanRange];

	AHParserStatus parserStatus = [self _isStringValidURL:fragment strictMatching:strictMatch withIndex:scanLocation];

	if (parserStatus == AHParserURLInvalid) {
		return nil;
	}

	if (parserStatus == AHParserURLWithoutScheme && scanRange.location > 0) {
		UniChar leftmost = [scanString characterAtIndex:(scanRange.location - 1)];

		// I don't remember the purpose of this but don't remove it in case it might be important
		if (leftmost == '@' || leftmost == '.') {
			return nil;
		}
	}

	return [self _resultWithProperURLScheme:fragment inRange:scanRange parserStatus:parserStatus];
}

+ (AHHyperlinkScannerResult *)_resultWithProperURLScheme:(NSString *)url inRange:(NSRange)range parserStatus:(AHParserStatus)parserStatus
{
	NSParameterAssert(url != nil);
	NSParameterAssert(parserStatus != AHParserURLInvalid);

	NSString *urlProper = [self _URLWithProperScheme:url parserStatus:parserStatus];

	  AHHyperlinkScannerResult *result =
	[[AHHyperlinkScannerResult alloc] initWithString:urlProper
											 inRange:range
										 strictMatch:(parserStatus == AHParserURLPreconfigured ||
													  parserStatus == AHParserURLWithScheme)];

	return result;
}

+ (NSString *)_URLWithProperScheme:(NSString *)url parserStatus:(AHParserStatus)parserStatus
{
	NSParameterAssert(url != nil);

	NSString *urlProper = url;

	if (parserStatus == AHParserURLWithoutScheme) {
		urlProper = [DEFAULT_URL_SCHEME stringByAppendingString:url];
	} else if (parserStatus == AHParserURLSpecialCaseReddit) {
		urlProper = [@"https://www.reddit.com" stringByAppendingString:url];
	}

	 urlProper =
	[urlProper stringByReplacingOccurrencesOfString:@"\"" withString:@"%22"];

	return urlProper;
}

/* Cuts the range at its last closing bracket when the range has more closing
 than opening ones. Returns whether it did. */
+ (BOOL)_removeUnbalancedClosing:(NSString *)closing opening:(NSString *)opening fromRange:(NSRange *)range inString:(NSString *)scanString
{
	if (range->length == 0) {
		return NO;
	}

	NSString *word = [scanString substringWithRange:*range];

	NSUInteger openingCount = ([word componentsSeparatedByString:opening].count - 1);
	NSUInteger closingCount = ([word componentsSeparatedByString:closing].count - 1);

	if (closingCount <= openingCount) {
		return NO;
	}

	NSRange lastClosing = [word rangeOfString:closing options:NSBackwardsSearch];

	range->length = lastClosing.location;

	return YES;
}

+ (NSRange)_longestBalancedEnclosureInString:(NSString *)scanString range:(NSRange)range
{
	NSParameterAssert(scanString != nil);

	NSDictionary *encDict = nil;

	NSMutableArray *enclosureArray = nil;
	NSMutableArray *enclosureStack = nil;

	NSUInteger encScanLocation = range.location;

	NSUInteger encMaxLength = NSMaxRange(range);

	NSRange result = NSMakeRange(0, 0); // A value must be defined

	while (encScanLocation < encMaxLength)
	{
		[self _scanString:scanString upToCharactersFromSet:s_enclosureCharacterSet intoRange:nil withIndex:&encScanLocation];
		
		if (encScanLocation >= encMaxLength) {
			break;
		}
		
		NSString *matchCharacter = [scanString substringWithRange:NSMakeRange(encScanLocation, 1)];
		
		if ([s_enclosureStartArray containsObject:matchCharacter])
		{
			encDict = [NSDictionary	dictionaryWithObjects:@[@(encScanLocation), matchCharacter]
												  forKeys:s_enclosureKeys];
			
			if (enclosureStack == nil) {
				enclosureStack = [NSMutableArray array];
			}
			
			[enclosureStack addObject:encDict];
		}
		else if ([s_enclosureStopArray containsObject:matchCharacter])
		{
			NSEnumerator *encEnumerator = [enclosureStack objectEnumerator];
			
			while ((encDict = [encEnumerator nextObject]))
			{
				NSUInteger encTagIndex = [encDict[ENC_INDEX_KEY] unsignedIntegerValue];

				NSUInteger encStartIndex = [s_enclosureStartArray indexOfObjectIdenticalTo:encDict[ENC_CHAR_KEY]];
				
				if ([s_enclosureStopArray indexOfObjectIdenticalTo:matchCharacter] == encStartIndex)
				{
					NSRange encRange = NSMakeRange(encTagIndex, (encScanLocation - encTagIndex + 1));

					if (enclosureArray == nil) {
						enclosureArray = [NSMutableArray array];
					}

					if (enclosureStack == nil) {
						enclosureStack = [NSMutableArray array];
					}
					
					[enclosureStack removeObject:encDict];

					[enclosureArray addObject:[NSValue valueWithRange:encRange]];

					result = encRange;

					break;
				} // if
			} // while
		} // if
		
		if (encScanLocation < encMaxLength) {
			encScanLocation++;
		}
	} // while

	return result;
}

// functional replacement for -[NSScanner scanUpToCharactersFromSet:intoString:]
+ (BOOL)_scanString:(NSString *)scanString upToCharactersFromSet:(NSCharacterSet *)characterSet intoRange:(NSRange * _Nullable)rangeRef withIndex:(NSUInteger *)indexRef
{
	NSParameterAssert(scanString != nil);
	NSParameterAssert(characterSet != nil);
	NSParameterAssert(indexRef != NULL);

	NSUInteger scanLength = scanString.length;

	NSUInteger indexIn = *indexRef;

	if (indexIn >= scanLength) {
		return NO;
	}

	// Absorb s_skipCharacterSet
	NSUInteger firstIndex;

	for (firstIndex = indexIn; firstIndex < scanLength; firstIndex++) {
		UniChar c = [scanString characterAtIndex:firstIndex];

		if ([s_skipCharacterSet characterIsMember:c] == NO) {
			break;
		}
	}

	// scanUpTo:
	NSUInteger secondIndex;

	for (secondIndex = firstIndex; secondIndex < scanLength; secondIndex++) {
		UniChar c = [scanString characterAtIndex:secondIndex];

		if ([s_skipCharacterSet characterIsMember:c] || [characterSet characterIsMember:c]) {
			break;
		}
	}

	NSRange rangeOut = NSMakeRange(firstIndex, (secondIndex - firstIndex));

	*indexRef = secondIndex;

	if (rangeOut.length > 0) {
		if ( rangeRef) {
			*rangeRef = rangeOut;
		}

		return YES;
	}

	return NO;
}

// functional replacement for -[NSScanner scanCharactersFromSet:intoString:]
+ (BOOL)_scanString:(NSString *)scanString charactersFromSet:(NSCharacterSet *)characterSet intoRange:(NSRange * _Nullable)rangeRef withIndex:(NSUInteger *)indexRef
{
	NSParameterAssert(scanString != nil);
	NSParameterAssert(characterSet != nil);
	NSParameterAssert(indexRef != NULL);

	NSUInteger scanLength = scanString.length;

	NSUInteger indexIn = *indexRef;

	if (indexIn >= scanLength) {
		return NO;
	}

	// Absorb s_skipCharacterSet
	NSUInteger firstIndex;

	for (firstIndex = indexIn; firstIndex < scanLength; firstIndex++) {
		UniChar c = [scanString characterAtIndex:firstIndex];
		
		if ([s_skipCharacterSet characterIsMember:c] == NO) {
			break;
		}
	}

	// scanCharacters:
	NSUInteger secondIndex;

	for (secondIndex = firstIndex; secondIndex < scanLength; secondIndex++) {
		UniChar c = [scanString characterAtIndex:secondIndex];
		
		if ([characterSet characterIsMember:c] == NO) {
			break;
		}
	}

	NSRange rangeOut = NSMakeRange(firstIndex, (secondIndex - firstIndex));

	*indexRef = secondIndex;

	if (rangeOut.length > 0) {
		if ( rangeRef) {
			*rangeRef = rangeOut;
		}
		
		return YES;
	}

	return NO;
}

@end

#pragma mark -
#pragma mark Context Object

@implementation AHHyperlinkScannerContext

- (instancetype)initWithString:(NSString *)inString strictMatching:(BOOL)strictMatch
{
	NSParameterAssert(inString != nil);

	if ((self = [super init])) {
		self.scanString = inString;

		self.strictMatch = strictMatch;

		self.openEnclosureStack = [NSMutableArray array];

		return self;
	}

	return nil;
}

@end

NS_ASSUME_NONNULL_END
