/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2017, 2018 Codeux Software, LLC & respective contributors.
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

#import "ICLInlineContentModule.h"
#import "ICLURLSessionPrivate.h"
#import "ICLHelpers.h"

NS_ASSUME_NONNULL_BEGIN

/* JSON responses larger than this are refused */
#define _maximumJSONLength			(1024 * 1024)

/* Remembered answers: how long and how many */
#define _JSONCacheLifetime			(30 * 60)
#define _JSONCacheLimit				500
#define _JSONCacheCostLimit			(4 * 1024 * 1024)

/* Page metadata keeps what the cards read, at a length a card can show */
#define _maximumMetadataValueLength	2048

/* Remembered answers (JSON and page metadata), main thread only */
@interface ICLHelpers (Cache)
+ (nullable id)_cachedValueForKey:(NSString *)key;
+ (void)_cacheValue:(id)value forKey:(NSString *)key cost:(NSUInteger)cost;
+ (void)_removeCachedValueForKey:(NSString *)key;
+ (NSSet<NSString *> *)_metadataNames;
@end

NSURL * _Nullable ICLResourceURL(NSString *name, NSString *extension)
{
	NSCParameterAssert(name != nil);
	NSCParameterAssert(extension != nil);

	return [RZMainBundle() URLForResource:name withExtension:extension subdirectory:@"Inline Media"];
}

@implementation ICLHelpers

+ (nullable NSURL *)URLWithString:(NSString *)address
{
	NSParameterAssert(address != nil);

	if ([address hasPrefix:@"//"]) {
		address = [@"https:" stringByAppendingString:address];
	}

	NSURL *url = [NSURL URLWithString:address];

	NSString *urlScheme = url.scheme.lowercaseString;

	if ([urlScheme isEqualToString:@"http"] == NO &&
		[urlScheme isEqualToString:@"https"] == NO)
	{
		return nil;
	}

	if (url.host.length == 0) {
		return nil;
	}

	return url;
}

@end

#pragma mark -
#pragma mark Errors

@implementation ICLHelpers (Errors)

+ (NSError *)genericValidationFailedError
{
	static NSError *error = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		error =
		[NSError errorWithDomain:ICLInlineContentErrorDomain
							code:1003
						userInfo:@{
			NSLocalizedDescriptionKey : @"Validation failed"
		}];
	});

	return error;
}

@end

#pragma mark -
#pragma mark HTML

/* Pages are read up to this length */
#define _maximumPageLength			(512 * 1024)

@implementation ICLHelpers (HTML)

+ (NSString *)plainTextFromHTMLFragment:(NSString *)fragment
{
	NSParameterAssert(fragment != nil);

	NSMutableString *text = [NSMutableString stringWithCapacity:fragment.length];

	NSScanner *scanner = [NSScanner scannerWithString:fragment];

	scanner.charactersToBeSkipped = nil;

	while (scanner.isAtEnd == NO) {
		NSString *chunk = nil;

		if ([scanner scanUpToString:@"<" intoString:&chunk]) {
			[text appendString:chunk];
		}

		if (scanner.isAtEnd) {
			break;
		}

		/* A tag starts with a letter, / or !: "I <3 New York" is text */
		NSUInteger afterBracket = (scanner.scanLocation + 1);

		unichar next = ((afterBracket < fragment.length) ? [fragment characterAtIndex:afterBracket] : 0);

		if ([[NSCharacterSet letterCharacterSet] characterIsMember:next] == NO && next != '/' && next != '!') {
			[text appendString:@"<"];

			scanner.scanLocation = afterBracket;

			continue;
		}

		NSString *tag = nil;

		[scanner scanUpToString:@">" intoString:&tag];

		if (scanner.isAtEnd == NO) {
			scanner.scanLocation += 1;
		}

		/* <br> and <br/> become line breaks; other tags go */
		if ([tag.lowercaseString hasPrefix:@"<br"]) {
			[text appendString:@"\n"];
		}
	}

	return [self stringByDecodingHTMLEntities:text].trim;
}

+ (NSString *)stringByDecodingHTMLEntities:(NSString *)string
{
	if ([string containsString:@"&"] == NO) {
		return string;
	}

	NSDictionary<NSString *, NSString *> *named =
	@{
	  @"amp" : @"&", @"lt" : @"<", @"gt" : @">", @"quot" : @"\"", @"apos" : @"'",
	  @"nbsp" : @"\u00A0", @"mdash" : @"\u2014", @"ndash" : @"\u2013", @"hellip" : @"\u2026"
	};

	NSMutableString *result = [NSMutableString stringWithCapacity:string.length];

	NSScanner *scanner = [NSScanner scannerWithString:string];

	scanner.charactersToBeSkipped = nil;

	while (scanner.isAtEnd == NO) {
		NSString *chunk = nil;

		if ([scanner scanUpToString:@"&" intoString:&chunk]) {
			[result appendString:chunk];
		}

		if (scanner.isAtEnd) {
			break;
		}

		NSUInteger entityStart = scanner.scanLocation;

		NSRange semicolon = [string rangeOfString:@";" options:0 range:NSMakeRange(entityStart, MIN((NSUInteger)12, (string.length - entityStart)))];

		if (semicolon.location == NSNotFound) {
			[result appendString:@"&"];

			scanner.scanLocation = (entityStart + 1);

			continue;
		}

		NSString *entity = [string substringWithRange:NSMakeRange((entityStart + 1), (semicolon.location - entityStart - 1))];

		NSString *decoded = named[entity];

		if (decoded == nil && [entity hasPrefix:@"#"] && entity.length > 1) {
			unsigned long long codePoint = 0;

			BOOL hexadecimal = ([entity hasPrefix:@"#x"] || [entity hasPrefix:@"#X"]);

			NSScanner *numberScanner = [NSScanner scannerWithString:[entity substringFromIndex:((hexadecimal) ? 2 : 1)]];

			BOOL scanned = ((hexadecimal) ? [numberScanner scanHexLongLong:&codePoint] : [numberScanner scanUnsignedLongLong:&codePoint]);

			if (scanned && numberScanner.isAtEnd && codePoint > 0 && codePoint <= 0x10FFFF && (codePoint < 0xD800 || codePoint > 0xDFFF)) {
				UTF32Char character = (UTF32Char)codePoint;

				decoded = [[NSString alloc] initWithBytes:&character length:sizeof(character) encoding:NSUTF32LittleEndianStringEncoding];
			}
		}

		if (decoded) {
			[result appendString:decoded];

			scanner.scanLocation = NSMaxRange(semicolon);
		} else {
			[result appendString:@"&"];

			scanner.scanLocation = (entityStart + 1);
		}
	}

	return [result copy];
}

/* The value of name="…" or name='…' in a tag, or nil */
+ (nullable NSString *)_attribute:(NSString *)name inTag:(NSString *)tag
{
	NSUInteger searchFrom = 0;

	while (searchFrom < tag.length) {
		NSRange nameRange = [tag rangeOfString:name options:NSCaseInsensitiveSearch range:NSMakeRange(searchFrom, (tag.length - searchFrom))];

		if (nameRange.location == NSNotFound) {
			return nil;
		}

		searchFrom = NSMaxRange(nameRange);

		/* A whole attribute name: after a space, followed by = */
		unichar before = ((nameRange.location > 0) ? [tag characterAtIndex:(nameRange.location - 1)] : ' ');

		if (before != ' ' && before != '\t' && before != '\n' && before != '\r') {
			continue;
		}

		NSUInteger position = NSMaxRange(nameRange);

		while (position < tag.length && [tag characterAtIndex:position] == ' ') {
			position++;
		}

		if (position >= tag.length || [tag characterAtIndex:position] != '=') {
			continue;
		}

		position++;

		while (position < tag.length && [tag characterAtIndex:position] == ' ') {
			position++;
		}

		if (position >= tag.length) {
			return nil;
		}

		unichar quote = [tag characterAtIndex:position];

		if (quote != '"' && quote != '\'') {
			continue;
		}

		NSRange closingQuote = [tag rangeOfString:[NSString stringWithCharacters:&quote length:1] options:0 range:NSMakeRange((position + 1), (tag.length - position - 1))];

		if (closingQuote.location == NSNotFound) {
			return nil;
		}

		return [tag substringWithRange:NSMakeRange((position + 1), (closingQuote.location - position - 1))];
	}

	return nil;
}

+ (NSDictionary<NSString *, NSString *> *)metadataInHTML:(NSString *)html
{
	NSParameterAssert(html != nil);

	if (html.length > _maximumPageLength) {
		html = [html substringToIndex:_maximumPageLength];
	}

	NSRange headEnd = [html rangeOfString:@"</head>" options:NSCaseInsensitiveSearch];

	if (headEnd.location != NSNotFound) {
		html = [html substringToIndex:headEnd.location];
	}

	NSMutableDictionary<NSString *, NSString *> *metadata = [NSMutableDictionary dictionary];

	/* <title>…</title> */
	NSRange titleStart = [html rangeOfString:@"<title" options:NSCaseInsensitiveSearch];

	if (titleStart.location != NSNotFound) {
		NSRange titleTagEnd = [html rangeOfString:@">" options:0 range:NSMakeRange(NSMaxRange(titleStart), (html.length - NSMaxRange(titleStart)))];

		if (titleTagEnd.location != NSNotFound) {
			NSRange titleEnd = [html rangeOfString:@"</title>" options:NSCaseInsensitiveSearch range:NSMakeRange(NSMaxRange(titleTagEnd), (html.length - NSMaxRange(titleTagEnd)))];

			if (titleEnd.location != NSNotFound) {
				/* No tags in a title: only its entities are decoded */
				NSString *title = [self stringByDecodingHTMLEntities:[html substringWithRange:NSMakeRange(NSMaxRange(titleTagEnd), (titleEnd.location - NSMaxRange(titleTagEnd)))]].trim;

				if (title.length > _maximumMetadataValueLength) {
					title = [title substringToIndex:_maximumMetadataValueLength];
				}

				if (title.length > 0) {
					metadata[@"title"] = title;
				}
			}
		}
	}

	/* <meta property="og:…" content="…"> and <meta name="twitter:…" content="…"> */
	NSUInteger searchFrom = 0;

	while (searchFrom < html.length) {
		NSRange metaStart = [html rangeOfString:@"<meta" options:NSCaseInsensitiveSearch range:NSMakeRange(searchFrom, (html.length - searchFrom))];

		if (metaStart.location == NSNotFound) {
			break;
		}

		/* The tag ends at the first > outside quotes ("Docs > Setup" is a value) */
		NSUInteger tagSearchEnd = (NSMaxRange(metaStart) + MIN((NSUInteger)4096, (html.length - NSMaxRange(metaStart))));

		NSRange metaEnd = NSMakeRange(NSNotFound, 0);

		unichar openQuote = 0;

		for (NSUInteger position = NSMaxRange(metaStart); position < tagSearchEnd; position++) {
			unichar character = [html characterAtIndex:position];

			if (openQuote) {
				if (character == openQuote) {
					openQuote = 0;
				}
			} else if (character == '"' || character == '\'') {
				openQuote = character;
			} else if (character == '>') {
				metaEnd = NSMakeRange(position, 1);

				break;
			}
		}

		/* Too long (or never closed): skipped, the ones after it still count */
		if (metaEnd.location == NSNotFound) {
			searchFrom = NSMaxRange(metaStart);

			continue;
		}

		searchFrom = NSMaxRange(metaEnd);

		NSString *tag = [html substringWithRange:NSMakeRange(metaStart.location, (NSMaxRange(metaEnd) - metaStart.location))];

		NSString *name = ([self _attribute:@"property" inTag:tag] ?: [self _attribute:@"name" inTag:tag]).lowercaseString;

		if (name == nil || [[self _metadataNames] containsObject:name] == NO) {
			continue;
		}

		/* The first value of a name wins (og:image can repeat) */
		if (metadata[name] != nil) {
			continue;
		}

		NSString *content = [self _attribute:@"content" inTag:tag];

		if (content == nil) {
			continue;
		}

		content = [self stringByDecodingHTMLEntities:content].trim;

		if (content.length > _maximumMetadataValueLength) {
			content = [content substringToIndex:_maximumMetadataValueLength];
		}

		if (content.length > 0) {
			metadata[name] = content;
		}
	}

	return [metadata copy];
}

+ (nullable NSString *)stringFromHTMLData:(NSData *)data textEncodingName:(nullable NSString *)textEncodingName
{
	NSParameterAssert(data != nil);

	/* The charset of the response, else of a <meta> near the top */
	NSString *charset = textEncodingName;

	if (charset == nil) {
		NSString *top = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, MIN(data.length, (NSUInteger)2048))] encoding:NSISOLatin1StringEncoding];

		NSRange charsetRange = [top rangeOfString:@"charset=" options:NSCaseInsensitiveSearch];

		if (charsetRange.location != NSNotFound) {
			NSCharacterSet *nameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_:."];

			NSScanner *scanner = [NSScanner scannerWithString:top];

			scanner.charactersToBeSkipped = [NSCharacterSet characterSetWithCharactersInString:@"\"' "];

			scanner.scanLocation = NSMaxRange(charsetRange);

			NSString *name = nil;

			if ([scanner scanCharactersFromSet:nameCharacters intoString:&name]) {
				charset = name;
			}
		}
	}

	NSStringEncoding encoding = NSUTF8StringEncoding;

	if (charset) {
		CFStringEncoding charsetEncoding = CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)charset);

		if (charsetEncoding != kCFStringEncodingInvalidId) {
			encoding = CFStringConvertEncodingToNSStringEncoding(charsetEncoding);
		}
	}

	/* The read stops anywhere, so the last character can be cut short */
	for (NSUInteger dropped = 0; dropped < 4 && dropped < data.length; dropped++) {
		NSString *string = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, (data.length - dropped))] encoding:encoding];

		if (string) {
			return string;
		}
	}

	return [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
}

+ (BOOL)responseIsHTML:(NSHTTPURLResponse *)response
{
	NSParameterAssert(response != nil);

	NSString *contentType = response.MIMEType.lowercaseString;

	return ([contentType isEqualToString:@"text/html"] ||
			[contentType isEqualToString:@"application/xhtml+xml"]);
}

+ (void)requestPageMetadataFromURL:(NSURL *)url session:(NSURLSession *)session completionBlock:(void (^)(NSDictionary<NSString *, NSString *> * _Nullable metadata))completionBlock
{
	NSParameterAssert(completionBlock != nil);

	[self requestPageMetadataFromURL:url session:session responseBlock:nil completionBlock:^(NSDictionary<NSString *, NSString *> * _Nullable metadata, NSURL * _Nullable pageURL) {
		completionBlock(metadata);
	}];
}

+ (void)requestPageMetadataFromURL:(NSURL *)url session:(NSURLSession *)session responseBlock:(nullable BOOL (^)(NSHTTPURLResponse *response))responseBlock completionBlock:(void (^)(NSDictionary<NSString *, NSString *> * _Nullable metadata, NSURL * _Nullable pageURL))completionBlock
{
	NSParameterAssert(url != nil);
	NSParameterAssert(session != nil);
	NSParameterAssert(completionBlock != nil);

	NSString *cacheKey = [@"page " stringByAppendingString:url.absoluteString];

	NSArray *cachedPage = [self _cachedValueForKey:cacheKey];

	if (cachedPage) {
		dispatch_async(dispatch_get_main_queue(), ^{
			completionBlock(cachedPage[0], cachedPage[1]);
		});

		return;
	}

	/* The metadata is in the head: the read stops at its end */
	NSArray<NSData *> *endMarkers = @[[@"</head>" dataUsingEncoding:NSASCIIStringEncoding],
									  [@"</HEAD>" dataUsingEncoding:NSASCIIStringEncoding]];

	[ICLURLSession requestPrefixFromURL:url
								session:session
						  maximumLength:_maximumPageLength
							 endMarkers:endMarkers
						  responseBlock:^BOOL(NSHTTPURLResponse *response) {
							  if (responseBlock && responseBlock(response) == NO) {
								  return NO;
							  }

							  return [self responseIsHTML:response];
						  }
						completionBlock:^(NSHTTPURLResponse * _Nullable response, NSData * _Nullable data) {
							NSURL *pageURL = response.URL;

							if (data == nil || pageURL == nil) {
								completionBlock(nil, nil);

								return;
							}

							NSString *html = [self stringFromHTMLData:data textEncodingName:response.textEncodingName];

							NSDictionary *metadata = ((html) ? [self metadataInHTML:html] : nil);

							if (metadata.count == 0) {
								completionBlock(nil, nil);

								return;
							}

							NSUInteger cost = 0;

							for (NSString *value in metadata.allValues) {
								cost += (value.length * sizeof(unichar));
							}

							[self _cacheValue:@[metadata, pageURL] forKey:cacheKey cost:cost];

							completionBlock(metadata, pageURL);
						}];
}

@end

#pragma mark -
#pragma mark JSON

@implementation ICLHelpers (JSON)

+ (void)requestJSONObject:(NSString *)objectKey ofType:(Class)objectType inHierarchy:(nullable NSArray<NSString *> *)hierarchy fromURL:(NSURL *)url session:(NSURLSession *)session completionBlock:(void (^)(id _Nullable object))completionBlock
{
	NSParameterAssert(objectKey != nil);
	NSParameterAssert(objectType != NULL);
	NSParameterAssert(url != nil);
	NSParameterAssert(completionBlock != nil);

	[self requestJSONDataFromURL:url session:session completionBlock:^(BOOL success, NSDictionary<NSString *,id> * _Nullable data) {
		/* Return nothing if underlying request failed. */
		if (success == NO) {
			completionBlock(nil);

			return;
		}

		/* Traverse hiearchy */
		/* hierarchy is the path we will traverse to find objectKey.
		 All keys assigned to hierarchy are expected to be a dictionary.
		 If a key in hierarchy does not exist or is not a dictionary,
		 then the request exits. */
		NSDictionary *currentContext = data;

		if (hierarchy) {
			for (NSString *hierarchyKey in hierarchy) {
				id hierarchyContext = [currentContext dictionaryForKey:hierarchyKey];

				/* Return nothing if we cannot go deeper. */
				if (hierarchyContext == nil) {
					completionBlock(nil);

					return;
				}

				currentContext = hierarchyContext;
			}
		}

		/* Get object value and check type */
		id objectValue = currentContext[objectKey];

		/* Object is not a type we are interested in */
		if ([objectValue isKindOfClass:objectType] == NO) {
			completionBlock(nil);

			return;
		}

		/* Object is a type we are interested in */
		completionBlock(objectValue);
	}];
}

+ (void)requestJSONObject:(NSString *)objectKey ofType:(Class)objectType inHierarchy:(nullable NSArray<NSString *> *)hierarchy fromAddress:(NSString *)address session:(NSURLSession *)session completionBlock:(void (^)(id _Nullable object))completionBlock
{
	NSParameterAssert(objectKey != nil);
	NSParameterAssert(objectType != NULL);
	NSParameterAssert(address != nil);
	NSParameterAssert(completionBlock != nil);

	NSURL *url = [ICLHelpers URLWithString:address];

	if (url == nil) {
		completionBlock(nil);

		return;
	}

	[self requestJSONObject:objectKey ofType:objectType inHierarchy:hierarchy fromURL:url session:session completionBlock:completionBlock];
}

/* Main thread only: key → @[date, value, cost]. The cost is the size of the
 response, so a few large answers can't fill memory under the count limit. */
static NSMutableDictionary<NSString *, NSArray *> *_JSONCache = nil;

static NSUInteger _JSONCacheCost = 0;

+ (nullable id)_cachedValueForKey:(NSString *)key
{
	NSArray *entry = _JSONCache[key];

	if (entry == nil) {
		return nil;
	}

	NSDate *date = entry[0];

	if (date.timeIntervalSinceNow < -(_JSONCacheLifetime)) {
		[self _removeCachedValueForKey:key];

		return nil;
	}

	return entry[1];
}

+ (void)_removeCachedValueForKey:(NSString *)key
{
	NSArray *entry = _JSONCache[key];

	if (entry == nil) {
		return;
	}

	_JSONCacheCost -= [entry[2] unsignedIntegerValue];

	[_JSONCache removeObjectForKey:key];
}

+ (void)_cacheValue:(id)value forKey:(NSString *)key cost:(NSUInteger)cost
{
	/* Larger than a quarter of the cache: used once, not kept */
	if (cost > (_JSONCacheCostLimit / 4)) {
		return;
	}

	if (_JSONCache == nil) {
		_JSONCache = [NSMutableDictionary dictionary];
	}

	[self _removeCachedValueForKey:key];

	/* Full: the oldest go, a quarter of them or as many as make room */
	if (_JSONCache.count >= _JSONCacheLimit || (_JSONCacheCost + cost) > _JSONCacheCostLimit) {
		NSArray<NSString *> *keys = [_JSONCache keysSortedByValueUsingComparator:^NSComparisonResult(NSArray *entry1, NSArray *entry2) {
			return [(NSDate *)entry1[0] compare:(NSDate *)entry2[0]];
		}];

		NSUInteger removed = 0;

		for (NSString *oldKey in keys) {
			if (removed > (keys.count / 4) && (_JSONCacheCost + cost) <= _JSONCacheCostLimit) {
				break;
			}

			[self _removeCachedValueForKey:oldKey];

			removed += 1;
		}
	}

	_JSONCache[key] = @[[NSDate date], value, @(cost)];

	_JSONCacheCost += cost;
}

+ (NSSet<NSString *> *)_metadataNames
{
	static NSSet<NSString *> *names = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		names = [NSSet setWithArray:@[
			@"description",
			@"og:title", @"og:description", @"og:site_name",
			@"og:image", @"og:image:url", @"og:image:secure_url",
			@"twitter:title", @"twitter:description", @"twitter:image", @"twitter:image:src"
		]];
	});

	return names;
}

+ (void)requestJSONFromURL:(NSURL *)url session:(NSURLSession *)session completionBlock:(void (^)(id _Nullable json))completionBlock
{
	NSParameterAssert(url != nil);
	NSParameterAssert(completionBlock != nil);

	id cachedJSON = [self _cachedValueForKey:url.absoluteString];

	if (cachedJSON) {
		dispatch_async(dispatch_get_main_queue(), ^{
			completionBlock(cachedJSON);
		});

		return;
	}

	[ICLURLSession requestDataFromURL:url session:session maximumLength:_maximumJSONLength completionBlock:^(NSData * _Nullable data) {
		/* The session logs why a request failed */
		if (data == nil) {
			completionBlock(nil);

			return;
		}

		NSError *decodedJsonError;

		id decodedJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:&decodedJsonError];

		if (decodedJson == nil) {
			LogToConsoleError("Failed to decode response: %{public}@",
				decodedJsonError.localizedDescription);

			completionBlock(nil);

			return;
		}

		[self _cacheValue:decodedJson forKey:url.absoluteString cost:data.length];

		completionBlock(decodedJson);
	}];
}

+ (void)requestJSONDataFromURL:(NSURL *)url session:(NSURLSession *)session completionBlock:(void (^)(BOOL success, NSDictionary<NSString *, id> * _Nullable data))completionBlock
{
	NSParameterAssert(url != nil);
	NSParameterAssert(completionBlock != nil);

	[self requestJSONFromURL:url session:session completionBlock:^(id _Nullable json) {
		if ([json isKindOfClass:[NSDictionary class]] == NO) {
			completionBlock(NO, nil);

			return;
		}

		completionBlock(YES, json);
	}];
}

+ (void)requestJSONDataFromAddress:(NSString *)address session:(NSURLSession *)session completionBlock:(void (^)(BOOL success, NSDictionary<NSString *, id> * _Nullable data))completionBlock
{
	NSParameterAssert(address != nil);
	NSParameterAssert(completionBlock != nil);

	NSURL *url = [ICLHelpers URLWithString:address];

	if (url == nil) {
		completionBlock(NO, nil);

		return;
	}

	[self requestJSONDataFromURL:url session:session completionBlock:completionBlock];
}

@end

#pragma mark -
#pragma mark Strings

@implementation NSString (ICLHelpers)

- (BOOL)isDomain:(NSString *)domain
{
	NSParameterAssert(domain != nil);

	return [self isEqualToString:domain];
}

- (BOOL)isDomainOrSubdomain:(NSString *)domain
{
	NSParameterAssert(domain != nil);

	return ([self isEqualToString:domain] || [self hasSuffix:[@"." stringByAppendingString:domain]]);
}

@end

NS_ASSUME_NONNULL_END
