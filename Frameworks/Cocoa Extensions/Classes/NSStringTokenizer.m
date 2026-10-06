/* *********************************************************************
 *
 *         Copyright (c) 2015 - 2020 Codeux Software, LLC
 *     Please see ACKNOWLEDGEMENT for additional information.
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
 *  * Neither the name of "Codeux Software, LLC", nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
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

/* Tokenizer can handle NSString and NSAttributedString.
 Unfortunately you cannot cast a protocol on an extension
 so it is not clear both these classes conform to these.
 They do though. This makes it easier so we aren't
 constantly casting what type of string we are working
 with since the tokenizer takes `id` which is any type. */
@protocol CSStringTokenizerStringMutable;

@protocol CSStringTokenizerString <NSObject>
@property (readonly, copy) NSString *t_scannerString;

- (id <CSStringTokenizerString>)t_copy;
- (id <CSStringTokenizerStringMutable>)t_mutableCopy;

- (id <CSStringTokenizerString>)t_substringFromRange:(NSRange)range;
- (id <CSStringTokenizerStringMutable>)t_mutableSubstringFromRange:(NSRange)range;
@end

@protocol CSStringTokenizerStringMutable <CSStringTokenizerString>
- (void)t_deleteCharactersInRange:(NSRange)range;
@end

@implementation NSString (CSStringTokenizer)

- (void)getTokenFromWhitespaceGroupWithBlock:(void (NS_NOESCAPE ^)(NSString * _Nullable token, NSRange tokenRange, NSRange deletionRange))completionBlock
{
	NSParameterAssert(completionBlock != nil);

	[NSString _getTokenFromWhitespaceGroup:(id <CSStringTokenizerString>)self
								 withBlock:completionBlock];
}

- (void)getTokenFromQuoteGroupWithBlock:(void (NS_NOESCAPE ^)(NSString * _Nullable token, NSRange tokenRange, NSRange deletionRange))completionBlock options:(CSStringQuoteGroupOptions)options
{
	NSParameterAssert(completionBlock != nil);

	[NSString _getTokenFromQuoteGroup:(id <CSStringTokenizerString>)self
							  options:options withBlock:completionBlock];
}

+ (void)_getTokenFromWhitespaceGroup:(id <CSStringTokenizerString>)objectIn withBlock:(void (NS_NOESCAPE ^)(NSString * _Nullable token, NSRange tokenRange, NSRange deletionRange))completionBlock
{
	NSParameterAssert(objectIn != nil);
	NSParameterAssert(completionBlock != nil);

	/* Establish context */
	NSString *stringValue = objectIn.t_scannerString;

	if (stringValue.length == 0) {
		completionBlock(nil, NSEmptyRange(), NSEmptyRange());

		return;
	}

	NSScanner *scanner = [NSScanner scannerWithString:stringValue];

	scanner.charactersToBeSkipped = nil;

	/* Scan up to first space. */
	NSString *token = nil;

	BOOL whitespaceFound = [scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&token];

	NSRange tokenRange = NSMakeRange(0, token.length);

	/* Scanner returning no means we scanned up to the end of the
	 string without a whitespace. That effectively makes the token
	 the entire string, and that its deletion range as well. */
	if (whitespaceFound == NO) {
		completionBlock(token, tokenRange, tokenRange);

		return;
	}

	/* Scan up to remaining whitespaces */
	[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];

	NSRange deletionRange = NSMakeRange(0, scanner.scanLocation);

	completionBlock(token, tokenRange, deletionRange);
}

+ (void)_getTokenFromQuoteGroup:(id <CSStringTokenizerString>)objectIn options:(CSStringQuoteGroupOptions)options withBlock:(void (NS_NOESCAPE ^)(id _Nullable token, NSRange tokenRange, NSRange deletionRange))completionBlock
{
	NSParameterAssert(objectIn != nil);
	NSParameterAssert(completionBlock != nil);

	/* Establish context */
	NSString *stringValue = objectIn.t_scannerString;

	if (stringValue.length < 2) { // Opening quote and closing quote
		LogToConsoleDebugWithSubsystem(_CSFrameworkInternalLogSubsystem(),
			"Failed to scan quote group because string value is too short.");

		completionBlock(nil, NSEmptyRange(), NSEmptyRange());

		return;
	}

	NSScanner *scanner = [NSScanner scannerWithString:stringValue];

	scanner.charactersToBeSkipped = nil;

	/* Establish options */
	if (options == 0) {
		options = CSStringQuoteGroupOptionsDefault;
	}

	BOOL configSingleQuotes = ((options & CSStringQuoteGroupOptionsSingleQuotes) == CSStringQuoteGroupOptionsSingleQuotes);
	BOOL configDoubleQuotes = ((options & CSStringQuoteGroupOptionsDoubleQuotes) == CSStringQuoteGroupOptionsDoubleQuotes);
	BOOL configTerminateWithSpace = ((options & CSStringQuoteGroupOptionsTerminatesWithSpace) == CSStringQuoteGroupOptionsTerminatesWithSpace);
	BOOL configCollapseSlashes = ((options & CSStringQuoteGroupOptionsCollapseSlashes) == CSStringQuoteGroupOptionsCollapseSlashes);

	/* Find first quote */
	NSString *openingQuoteCharacter = nil;

	if (configDoubleQuotes) {
		if ([scanner scanString:@"\"" intoString:nil]) {
			openingQuoteCharacter = @"\"";
		}
	}

	if (configSingleQuotes && openingQuoteCharacter == nil) {
		if ([scanner scanString:@"'" intoString:nil]) {
			openingQuoteCharacter = @"'";
		}
	}

	if (openingQuoteCharacter == nil) {
		/* There is not an opening character. */
		/* Do we want an assert when the configuration option for
		 double quotes nor single quotes are present. Should we?
		 This is pretty much soft error for that as well. */
		LogToConsoleDebugWithSubsystem(_CSFrameworkInternalLogSubsystem(),
			"Failed to scan quote group because there is not an opening quote or "
			"the string value does not begin with a quote.");

		completionBlock(nil, NSEmptyRange(), NSEmptyRange());

		return;
	}

	/* Scanner loop */
	/* The scanner loop will want to delete certain characters,
	 such as slashes that escape quotes. This array keeps track
	 of these ranges so that we can perform all those deletes at
	 one time at the end of the loop. The other option was to
	 maintain an offset integer and apply to location each time
	 we need to access it. Array is slower but more reliable. */
	NSMutableArray<NSValue *> *rangesToDelete = nil;

	while (scanner.atEnd == NO) {
		/* Scan up to what should be the ending quote based on what is the opening quote. */
		/* We do not fail if this returns NO because if after one pass of the loop moves
		 the location forward, this could return NO because the current location is
		 already another quote character. */
		[scanner scanUpToString:openingQuoteCharacter intoString:nil];

		/* The scanner will only be at the end if it could not find
		 an end quote. This -atEnd check is different compared to the
		 one that follows because the one that follows is after we
		 move the location forward. */
		if (scanner.atEnd) {
			/* Quote group does not have a closing character. */
			LogToConsoleDebugWithSubsystem(_CSFrameworkInternalLogSubsystem(),
			 "Failed to scan quote group because all possible characters have been exhausted.");

			completionBlock(nil, NSEmptyRange(), NSEmptyRange());

			return;
		}

		/* Scan location is now set at this quote. */
		NSUInteger endQuoteLocation = scanner.scanLocation;

		/* Advanced scanner location after quote. */
		/* This puts us either at the end of the string or
		 onto next segment. */
		scanner.scanLocation += 1;

		/* Check the left side of the quote. */
		NSUInteger slashCount = 0;

		/* Find all slashes left of this quote. */
		for (NSUInteger i = (endQuoteLocation - 1); i > 0; i--) {
			UniChar c = [stringValue characterAtIndex:i];

			if (c == '\\') {
				slashCount += 1;
			} else {
				break;
			}
		}

		BOOL slashesAreEven = ((slashCount % 2) == 0);

		/* If the number of slashes are even, then that means there
		 is none left to escape the quote. */
		BOOL probableEndQuote = (slashCount == 0 || slashesAreEven);

		if (scanner.atEnd) {
			/* There is no where else to go and we do not have an
			 end quote. This group is not valid. */
			if (probableEndQuote == NO) {
				LogToConsoleDebugWithSubsystem(_CSFrameworkInternalLogSubsystem(),
					"Failed to scan quote group because all possible characters have been exhausted. "
					"A possible end quote was found. It however is escaped by an uneven number of "
					"slashes which makes it unusable as a closing quote.");

				completionBlock(nil, NSEmptyRange(), NSEmptyRange());

				return;
			}

			/* We are not at the end of the string. In that case,
			 if this is likely the end quote, what is next to it? */
		} else if (configTerminateWithSpace && probableEndQuote) {
			/* The current scanner location is after the quote. */
			UniChar rightChar = [stringValue characterAtIndex:scanner.scanLocation];;

			if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:rightChar] == NO) {
				/* Next character is not one we are interested in. */
				LogToConsoleDebugWithSubsystem(_CSFrameworkInternalLogSubsystem(),
					"Failed to scan quote group because the right side of the closing quote "
					"is not a newline or whitespace.");

				completionBlock(nil, NSEmptyRange(), NSEmptyRange());

				return;
			}
		}

		/* Delete escape slash if there is one. */
		/* \" => "
		 * \\\" => \\"
		 * \\\\\" => \\\\" */
		if (slashCount > 0 && slashesAreEven == NO) {
			NSRange range = NSMakeRange((endQuoteLocation - 1), 1);

			if (rangesToDelete == nil) {
				rangesToDelete = [NSMutableArray new];
			}

			[rangesToDelete addObject:[NSValue valueWithRange:range]];
		}

		/* No condition has told us otherwise. Break from loop. */
		if (probableEndQuote) {
			break;
		}
	}

	/* Compute token */
	/* Token begins after first quote and ends before second. */
	NSRange tokenRange = NSMakeRange(1, (scanner.scanLocation - 2));

	/* Token will be mutable until return to allow slash collapsing
	 to modify it without having to keep casting between read only
	 and mutable. */
	id token = [objectIn t_mutableSubstringFromRange:tokenRange];

	/* This isn't the most efficient way to do this but what of any of this is? */
	if (rangesToDelete) {
		for (NSValue *rangeValue in rangesToDelete.reverseObjectEnumerator) {
			NSRange range = rangeValue.rangeValue;

			/* Decrease by one to account for the lost opening quote. */
			/* This seemed like the easier solution. */
			range.location -= 1;

			/* Delete the characters */
			[token t_deleteCharactersInRange:range];
		} // for
	} // rangesToDelete

	/* Read in additional spaces */
	if (configTerminateWithSpace) {
		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
	}

	NSRange deletionRange = NSMakeRange(0, scanner.scanLocation);

	/* Collapse slashes */
	if (configCollapseSlashes) {
		[self _collapseSlashesInQuoteGroupToken:token];
	}

	completionBlock([token copy], tokenRange, deletionRange);
}

/* Accepts NSMutableString or NSMutableAttributedString */
+ (void)_collapseSlashesInQuoteGroupToken:(id <CSStringTokenizerStringMutable>)token
{
	NSParameterAssert(token != nil);

	/* Scanner uses a character set because it will scan multiple pairs
	 of the same character so there can be any number of slashes. */
	NSCharacterSet *slashesSet = [NSCharacterSet characterSetWithCharactersInString:@"\\"];

	NSString *stringValue = token.t_scannerString;

	NSScanner *scanner = [NSScanner scannerWithString:stringValue];

	scanner.charactersToBeSkipped = nil;

	NSMutableArray<NSValue *> *rangesToDelete = nil;

	while (scanner.atEnd == NO) {
		/* Scan up to next slash or exit */
		/* Do not return on NO. String could start with a slash. */
		[scanner scanUpToCharactersFromSet:slashesSet intoString:nil];

		if (scanner.isAtEnd) {
			break;
		}

		/* Scan all slashes into a single string. */
		NSString *slashes = nil;

		[scanner scanCharactersFromSet:slashesSet intoString:&slashes];

		NSUInteger slashesCount = slashes.length;

		/* A single slash cannot be collapsed. */
		if (slashesCount == 1) {
			continue;
		}

		/* If the number of slashes is not an even number,
		 then reduce by one. The last slash will not be
		 collapsed because it has nothing collapsing it. */
		BOOL slashesAreEven = ((slashesCount % 2) == 0);

		if (slashesAreEven == NO) {
			slashesCount -= 1;
		}

		/* Collapse slashes from two pairs to one.
		 // => /
		 //// => //
		 ////// => /// etc. */
		NSUInteger slashesDelta = (slashesCount / 2);

		NSRange deletionRange = NSMakeRange((scanner.scanLocation - slashes.length), slashesDelta);

		/* This probably isn't thread safe. */
		if (rangesToDelete == nil) {
			rangesToDelete = [NSMutableArray new];
		}

		[rangesToDelete addObject:[NSValue valueWithRange:deletionRange]];
	}

	/* Perform delete */
	if (rangesToDelete == nil) {
		return;
	}

	for (NSValue *rangeValue in rangesToDelete.reverseObjectEnumerator) {
		NSRange range = rangeValue.rangeValue;

		[token t_deleteCharactersInRange:range];
	}
}

- (NSString *)trimAndGetFirstToken
{
	__block NSString *tokenOut = nil;

	id objectId = (id <CSStringTokenizerString>)self.trim;

	[NSString _getTokenFromWhitespaceGroup:objectId withBlock:^(id token, NSRange tokenRange, NSRange deletionRange) {
		tokenOut = token;
	}];

	if (tokenOut == nil) {
		return @"";
	}

	return tokenOut;
}

@end

#pragma mark -
#pragma mark Mutable String Helper

@implementation NSMutableString (NSMutableStringTokenizer)

- (NSString *)getTokenInsideQuotes
{
	__block NSString *tokenOut = nil;

	__block NSRange deletionRangeOut;

	[self getTokenFromQuoteGroupWithBlock:^(NSString *token, NSRange tokenRange, NSRange deletionRange) {
		tokenOut = token;

		deletionRangeOut = deletionRange;
	} options:CSStringQuoteGroupOptionsDefault];

	if (deletionRangeOut.location != NSNotFound) {
		[self deleteCharactersInRange:deletionRangeOut];
	}

	if (tokenOut == nil) {
		return @"";
	}

	return tokenOut;
}

- (NSString *)getToken
{
	__block NSString *tokenOut = nil;

	__block NSRange deletionRangeOut;

	[self getTokenFromWhitespaceGroupWithBlock:^(NSString *token, NSRange tokenRange, NSRange deletionRange) {
		tokenOut = token;

		deletionRangeOut = deletionRange;
	}];

	if (deletionRangeOut.location != NSNotFound) {
		[self deleteCharactersInRange:deletionRangeOut];
	}

	if (tokenOut == nil) {
		return @"";
	}

	return tokenOut;
}

- (NSString *)lowercaseGetToken
{
	return self.token.lowercaseString;
}

- (NSString *)uppercaseGetToken
{
	return self.token.uppercaseString;
}

@end

#pragma mark -
#pragma mark Attributed String Helper

@implementation NSAttributedString (NSAttributedStringTokenizer)

- (void)getTokenFromWhitespaceGroupWithBlock:(void (NS_NOESCAPE ^)(NSString * _Nullable token, NSRange tokenRange, NSRange deletionRange))completionBlock
{
	NSParameterAssert(completionBlock != nil);

	[NSString _getTokenFromWhitespaceGroup:(id <CSStringTokenizerString>)self
								 withBlock:completionBlock];
}

- (void)getTokenFromQuoteGroupWithBlock:(void (NS_NOESCAPE ^)(NSAttributedString * _Nullable token, NSRange tokenRange, NSRange deletionRange))completionBlock options:(CSStringQuoteGroupOptions)options
{
	NSParameterAssert(completionBlock != nil);

	[NSString _getTokenFromQuoteGroup:(id <CSStringTokenizerString>)self
							  options:options
							withBlock:completionBlock];
}

@end

#pragma mark -
#pragma mark Mutable Attributed String Helper

@implementation NSMutableAttributedString (NSMutableAttributedStringTokenizer)

- (NSString *)lowercaseGetToken
{
	return self.tokenAsString.lowercaseString;
}

- (NSString *)uppercaseGetToken
{
	return self.tokenAsString.uppercaseString;
}

- (NSAttributedString *)getTokenInsideQuotes
{
	__block NSAttributedString *tokenOut = nil;

	__block NSRange deletionRangeOut;

	[self getTokenFromQuoteGroupWithBlock:^(NSAttributedString *token, NSRange tokenRange, NSRange deletionRange) {
		tokenOut = token;

		deletionRangeOut = deletionRange;
	} options:CSStringQuoteGroupOptionsDefault];

	if (deletionRangeOut.location != NSNotFound) {
		[self deleteCharactersInRange:deletionRangeOut];
	}

	if (tokenOut == nil) {
		return [[NSAttributedString alloc] initWithString:@""];
	}

	return tokenOut;
}

- (NSAttributedString *)getToken
{
	return [self _getTokenAsString:NO];
}

- (NSString *)getTokenAsString
{
	return [self _getTokenAsString:YES];
}

- (id)_getTokenAsString:(BOOL)asString
{
	/* The faster path is to ask for a string since
	 the scanner will already return that for us. */
	__block NSString *tokenOut = nil;

	__block NSRange tokenRangeOut;
	__block NSRange deletionRangeOut;

	[self getTokenFromWhitespaceGroupWithBlock:^(NSString *token, NSRange tokenRange, NSRange deletionRange) {
		tokenOut = token;

		tokenRangeOut = tokenRange;
		deletionRangeOut = deletionRange;
	}];

	if (deletionRangeOut.location != NSNotFound) {
		[self deleteCharactersInRange:deletionRangeOut];
	}

	if (tokenOut == nil) {
		if (asString) {
			return @"";
		}

		return [[NSAttributedString alloc] initWithString:@""];
	}

	if (asString) {
		return tokenOut;
	}

	return [self attributedSubstringFromRange:tokenRangeOut];
}

@end

#pragma mark -
#pragma mark String Protocol Shims

@implementation NSString (CSStringTokenizerProtocol)

- (NSString *)t_scannerString
{
	return self;
}

- (id <CSStringTokenizerString>)t_copy
{
	return [self copy];
}

- (id <CSStringTokenizerStringMutable>)t_mutableCopy
{
	return [self mutableCopy];
}

- (id <CSStringTokenizerString>)t_substringFromRange:(NSRange)range
{
	return (id)[self substringWithRange:range];
}

- (id <CSStringTokenizerStringMutable>)t_mutableSubstringFromRange:(NSRange)range
{
	NSString *substring = [self substringWithRange:range];

	return [substring mutableCopy];
}

@end

#pragma mark -

@implementation NSAttributedString (CSAttributedStringTokenizerProtocol)

- (NSString *)t_scannerString
{
	return self.string;
}

- (id <CSStringTokenizerString>)t_copy
{
	return [self copy];
}

- (id <CSStringTokenizerStringMutable>)t_mutableCopy
{
	return [self mutableCopy];
}

- (id <CSStringTokenizerString>)t_substringFromRange:(NSRange)range
{
	return (id)[self attributedSubstringFromRange:range];
}

- (id <CSStringTokenizerStringMutable>)t_mutableSubstringFromRange:(NSRange)range
{
	NSAttributedString *substring = [self attributedSubstringFromRange:range];

	return [substring mutableCopy];
}

@end

#pragma mark -

@implementation NSMutableString (CSMutableStringTokenizerProtocol)

- (NSString *)t_scannerString
{
	return [self copy];
}

- (void)t_deleteCharactersInRange:(NSRange)range
{
	[self deleteCharactersInRange:range];
}

@end

#pragma mark -

@implementation NSMutableAttributedString (CSMutableAttributedStringTokenizerProtocol)

- (void)t_deleteCharactersInRange:(NSRange)range
{
	[self deleteCharactersInRange:range];
}

@end

NS_ASSUME_NONNULL_END
