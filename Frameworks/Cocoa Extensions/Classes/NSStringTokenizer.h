/* *********************************************************************
 *
 *         Copyright (c) 2015 - 2018 Codeux Software, LLC
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

typedef NS_OPTIONS(NSUInteger, CSStringQuoteGroupOptions)
{
	/* Only recognize quote groups that begin with a double quote. */
	CSStringQuoteGroupOptionsDoubleQuotes			= 1 << 0,

	/* Only recognize quote groups that begin with a single quote. */
	CSStringQuoteGroupOptionsSingleQuotes			= 1 << 1,

	/* Treat first quote, of any type, as quote group */
	CSStringQuoteGroupOptionsAnyQuotes 				= (CSStringQuoteGroupOptionsDoubleQuotes |
													   CSStringQuoteGroupOptionsSingleQuotes),

	/* The quote group must terminate in a whitespace, newline, or
	 is the end of the string; else it wont be considered valid.*/
	
	/* "This is the inside of a group"4343434 is not valid
	 when enabled. Otherwise, "This is the inside of a group"
	 is returned ignoring the 4343434 after the quote group. */

	/* When this option is set, the deletion range will include
	 all trailing whitespaces or newlines. */
	CSStringQuoteGroupOptionsTerminatesWithSpace 	= 1 << 2,

	/* Collapse multiple backslashes inside quote group. */

	/* Slashes are collapsed left-to-right. */

	/* Slashes are collapsed in pairs.
	 \\ becomes \, \\\ becomes \\, \\\\ becomes \\, etc. */

	/* Slashes are collapsed to next closest level.
	 \\\\\\\\ becomes \\\\. Wont reduce from \\\\ to \\. */

	/* Slashes are collapsed if they appear anywhere in
	 the string. Not only if the precede a quote. */

	/* A quote that is preceded by a single slash will have
	 that single slash treated as an escape for the quote. 
	 This will always occur regardless of whether this option
	 is enabled. */

	/* "one\" two" will result in: one" two */

	/* The single slash escapes the double quote from being
	 used as the end quote. It is treated as literal. */

	/* NOTE: Only quotes of same type are escaped by a slash.
	 If a quote groups opens with a double quote (") and contains
	 a segment with an escaped single quote such as \' then that
	 will not escape the single quote. It will be treated as a
	 literal and \' will be printed. */

	/* Examples of possible values and consequences: */

	/* "one\\" two" will result in: one\
	 The double slashes collapses to a single slash.
	 The single slash is treated as a literal which means the
	 quote that follows it is not escaped. It is the end quote. */

	/* "one\\\" two" will result in: one\" two
	 First two slashes collapse into one. They are treated as a
	 literal. That leaves a single slash that precedes a quote.
	 That quote is escaped by the remaining single slash.
	 Which means it is not treated as the end quote. */

	/* "one\\\ two" will result in: one\\ two
	 First two slashes collapse into one. They are treated as a
	 literal. That leaves a single slash that DOES not precede a
	 quote. That single slash does not have a quote to escape or
	 another slash to collapse into so it is treated as a literal. */
	CSStringQuoteGroupOptionsCollapseSlashes		= 1 << 3,

	/* Default options if none are specified. */
	CSStringQuoteGroupOptionsDefault = (CSStringQuoteGroupOptionsDoubleQuotes |
										CSStringQuoteGroupOptionsTerminatesWithSpace |
										CSStringQuoteGroupOptionsCollapseSlashes)
};

#pragma mark
#pragma mark String Helpers

@interface NSString (CSStringTokenizer)
/*
 Return first token and a range to delete string up to,
 including trailing whitespaces

 For example:

	Given the string: "Tokens     are very awesome!"

	Return value:
		Token: Tokens
		Token range: location = 0, length = 6
		Deletion range: location = 0, length = 11

	The range returned for deletion includes trailing
	whitespaces.

	Both ranges will be empty for an empty string as
	there is nothing to tokenize.
 */
- (void)getTokenFromWhitespaceGroupWithBlock:(void (NS_NOESCAPE ^)(NSString * _Nullable token, NSRange tokenRange, NSRange deletionRange))completionBlock;

/* Trim first before getting token. */
@property (readonly, copy) NSString *trimAndGetFirstToken;

/*
 Return first token and a range to delete string up to,
 including surrounding quote marks.

 For example:

	Given the string: "Tokens are very \"awesome!\""

	Return value:
		Token: Tokens are very "awesome!"
		Token range: location = 1, length = 24
		Deletion range: location = 0, length = 26

	The range returned for the token is the string value
	of the quote group. The string value at this range
	will not always be the same as token because the
	token string value may have collapsed slashes which
	will change its length relative to the ranges.

	The range returned for deletion will include the
	surrounding quote marks. The range returned for 
	deletion includes trailing whitespaces and newlines
	depending on options argument.

	Both ranges will be empty for an empty string as
	there is nothing to tokenize.

	Both ranges will be empty for a string that does
	not begin with a quote. There is nothing to tokenize.

	See CSStringQuoteGroupOptions for additional options.
 */
- (void)getTokenFromQuoteGroupWithBlock:(void (NS_NOESCAPE ^)(NSString * _Nullable token, NSRange tokenRange, NSRange deletionRange))completionBlock options:(CSStringQuoteGroupOptions)options;
@end

#pragma mark
#pragma mark Mutable String Helpers

@interface NSMutableString (CSMutableStringTokenizer)
@property (getter=getToken, readonly, copy) NSString *token;
@property (getter=getTokenInsideQuotes, readonly, copy) NSString *tokenInsideQuotes; // CSStringQuoteGroupOptionsDefault

@property (readonly, copy) NSString *lowercaseGetToken;
@property (readonly, copy) NSString *uppercaseGetToken;
@end

#pragma mark 
#pragma mark Attributed String Helpers

@interface NSAttributedString (CSAttributedStringTokenizer)
- (void)getTokenFromWhitespaceGroupWithBlock:(void (NS_NOESCAPE ^)(NSString * _Nullable token, NSRange tokenRange, NSRange deletionRange))completionBlock;
- (void)getTokenFromQuoteGroupWithBlock:(void (NS_NOESCAPE ^)(NSAttributedString * _Nullable token, NSRange tokenRange, NSRange deletionRange))completionBlock options:(CSStringQuoteGroupOptions)options;
@end

#pragma mark 
#pragma mark Mutable Attributed String Helpers

@interface NSMutableAttributedString (CSMutableAttributedStringTokenizer)
@property (getter=getTokenAsString, readonly, copy) NSString *tokenAsString;
@property (readonly, copy) NSString *lowercaseGetToken;
@property (readonly, copy) NSString *uppercaseGetToken;

@property (getter=getToken, readonly, copy) NSAttributedString *token;
@property (getter=getTokenInsideQuotes, readonly, copy) NSAttributedString *tokenInsideQuotes; // CSStringQuoteGroupOptionsDefault
@end

NS_ASSUME_NONNULL_END
