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

#import "TLOKeychainPrivate.h"
#import "TLOLocalization.h"
#import "TPCPreferencesUserDefaultsLocal.h"
#import "TLOUploadDestinationPrivate.h"

NS_ASSUME_NONNULL_BEGIN

static NSString * const _globalDestinationKey = @"Uploads -> Destination";
static NSString * const _hideButtonKey = @"Uploads -> Hide Upload Button Without Destination";
static NSString * const _globalSecretsIdentifier = @"global";

@implementation TLOUploadDestination

- (instancetype)init
{
	if ((self = [super init])) {
		self.name = @"";
		self.requestAddress = @"";
		self.method = @"POST";
		self.body = TLOUploadDestinationBodyMultipart;
		self.fileFieldName = @"file";
		self.headers = @{};
		self.parameters = @{};
		self.arguments = @{};
		self.regexes = @[];

		return self;
	}

	return nil;
}

- (id)copyWithZone:(nullable NSZone *)zone
{
	TLOUploadDestination *object = [[TLOUploadDestination allocWithZone:zone] init];

	object.name = self.name;
	object.requestAddress = self.requestAddress;
	object.method = self.method;
	object.body = self.body;
	object.fileFieldName = self.fileFieldName;
	object.headers = self.headers;
	object.parameters = self.parameters;
	object.arguments = self.arguments;
	object.regexes = self.regexes;
	object.linkTemplate = self.linkTemplate;
	object.errorTemplate = self.errorTemplate;

	return object;
}

#pragma mark -
#pragma mark ShareX

/* String values only: a ShareX dictionary can hold anything */
+ (NSDictionary<NSString *, NSString *> *)stringDictionary:(nullable id)value
{
	if ([value isKindOfClass:[NSDictionary class]] == NO) {
		return @{};
	}

	NSMutableDictionary *strings = [NSMutableDictionary dictionary];

	[(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
		if ([key isKindOfClass:[NSString class]] == NO) {
			return;
		}

		if ([object isKindOfClass:[NSString class]]) {
			strings[key] = object;
		} else if ([object isKindOfClass:[NSNumber class]]) {
			strings[key] = [object stringValue];
		}
	}];

	return [strings copy];
}

+ (nullable instancetype)destinationWithShareXData:(NSData *)data failureReason:(NSString * _Nullable * _Nullable)failureReason
{
	NSParameterAssert(data != nil);

	id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];

	if ([object isKindOfClass:[NSDictionary class]] == NO) {
		if (failureReason) {
			*failureReason = TXTLS(@"Prompts[upd-x1]");
		}

		return nil;
	}

	NSDictionary *uploader = object;

	/* Only uploaders of files, pictures or text */
	NSString *destinationType = uploader[@"DestinationType"];

	if ([destinationType isKindOfClass:[NSString class]] && destinationType.length > 0 &&
		[destinationType rangeOfString:@"ImageUploader"].location == NSNotFound &&
		[destinationType rangeOfString:@"FileUploader"].location == NSNotFound &&
		[destinationType rangeOfString:@"TextUploader"].location == NSNotFound)
	{
		if (failureReason) {
			*failureReason = TXTLS(@"Prompts[upd-x2]");
		}

		return nil;
	}

	TLOUploadDestination *destination = [TLOUploadDestination new];

	NSString *(^string)(NSString *) = ^NSString *(NSString *key) {
		id value = uploader[key];

		return (([value isKindOfClass:[NSString class]] && [value length] > 0) ? value : nil);
	};

	destination.requestAddress = (string(@"RequestURL") ?: @"");

	destination.name = (string(@"Name") ?: ([NSURL URLWithString:destination.requestAddress].host ?: @""));

	destination.method = (string(@"RequestMethod") ?: @"POST").uppercaseString;

	NSString *body = (string(@"Body") ?: @"MultipartFormData");

	if ([body isEqualToString:@"MultipartFormData"]) {
		destination.body = TLOUploadDestinationBodyMultipart;
	} else if ([body isEqualToString:@"Binary"]) {
		destination.body = TLOUploadDestinationBodyBinary;
	} else {
		if (failureReason) {
			*failureReason = TXTLS(@"Prompts[upd-x3]", body);
		}

		return nil;
	}

	destination.fileFieldName = (string(@"FileFormName") ?: @"file");

	destination.headers = [self stringDictionary:uploader[@"Headers"]];
	destination.parameters = [self stringDictionary:uploader[@"Parameters"]];
	destination.arguments = [self stringDictionary:uploader[@"Arguments"]];

	NSMutableArray *regexes = [NSMutableArray array];

	for (id regex in ([uploader[@"RegexList"] isKindOfClass:[NSArray class]] ? uploader[@"RegexList"] : @[])) {
		if ([regex isKindOfClass:[NSString class]]) {
			[regexes addObject:regex];
		}
	}

	destination.regexes = regexes;

	destination.linkTemplate = string(@"URL");
	destination.errorTemplate = string(@"ErrorMessage");

	NSString *problem = destination.problem;

	if (problem) {
		if (failureReason) {
			*failureReason = problem;
		}

		return nil;
	}

	return destination;
}

+ (BOOL)addressIsAllowed:(NSURL *)address
{
	NSParameterAssert(address != nil);

	NSString *scheme = address.scheme.lowercaseString;

	NSString *host = address.host.lowercaseString;

	if (host.length == 0) {
		return NO;
	}

	if ([scheme isEqualToString:@"https"]) {
		return YES;
	}

	/* Plain HTTP only to this Mac (a local uploader, or testing) */
	return ([scheme isEqualToString:@"http"] &&
			([host isEqualToString:@"localhost"] || [host isEqualToString:@"127.0.0.1"] || [host isEqualToString:@"::1"]));
}

- (nullable NSString *)problem
{
	NSURL *address = [NSURL URLWithString:self.requestAddress];

	if (self.requestAddress.length == 0 || address == nil || address.host.length == 0) {
		return TXTLS(@"Prompts[upd-p1]");
	}

	if ([self.class addressIsAllowed:address] == NO) {
		return TXTLS(@"Prompts[upd-p2]");
	}

	if ([self.method isEqualToString:@"POST"] == NO && [self.method isEqualToString:@"PUT"] == NO) {
		return TXTLS(@"Prompts[upd-p3]", self.method);
	}

	return nil;
}

#pragma mark -
#pragma mark Keeping

- (NSDictionary<NSString *, id> *)propertyList
{
	NSMutableDictionary *propertyList = [NSMutableDictionary dictionary];

	propertyList[@"name"] = self.name;
	propertyList[@"requestAddress"] = self.requestAddress;
	propertyList[@"method"] = self.method;
	propertyList[@"body"] = @(self.body);
	propertyList[@"fileFieldName"] = self.fileFieldName;
	propertyList[@"regexes"] = self.regexes;

	if (self.linkTemplate) {
		propertyList[@"linkTemplate"] = self.linkTemplate;
	}

	if (self.errorTemplate) {
		propertyList[@"errorTemplate"] = self.errorTemplate;
	}

	return [propertyList copy];
}

+ (nullable instancetype)destinationWithPropertyList:(NSDictionary<NSString *, id> *)propertyList secretsIdentifier:(nullable NSString *)secretsIdentifier
{
	NSParameterAssert(propertyList != nil);

	if ([propertyList isKindOfClass:[NSDictionary class]] == NO) {
		return nil;
	}

	TLOUploadDestination *destination = [TLOUploadDestination new];

	NSString *(^string)(NSString *, NSString *) = ^NSString *(NSString *key, NSString *fallback) {
		id value = propertyList[key];

		return (([value isKindOfClass:[NSString class]]) ? value : fallback);
	};

	destination.name = string(@"name", @"");
	destination.requestAddress = string(@"requestAddress", @"");
	destination.method = string(@"method", @"POST");
	destination.fileFieldName = string(@"fileFieldName", @"file");
	destination.linkTemplate = string(@"linkTemplate", nil);
	destination.errorTemplate = string(@"errorTemplate", nil);

	destination.body = (([propertyList[@"body"] unsignedIntegerValue] == TLOUploadDestinationBodyBinary) ? TLOUploadDestinationBodyBinary : TLOUploadDestinationBodyMultipart);

	if ([propertyList[@"regexes"] isKindOfClass:[NSArray class]]) {
		destination.regexes = propertyList[@"regexes"];
	}

	if (destination.requestAddress.length == 0) {
		return nil;
	}

	/* The tokens */
	NSString *secretsString = ((secretsIdentifier) ? [TLOKeychain passwordOfKind:TLOKeychainItemKindUploadSecrets forIdentifier:secretsIdentifier] : nil);

	NSData *secretsData = [secretsString dataUsingEncoding:NSUTF8StringEncoding];

	NSDictionary *secrets = ((secretsData) ? [NSJSONSerialization JSONObjectWithData:secretsData options:0 error:NULL] : nil);

	if ([secrets isKindOfClass:[NSDictionary class]]) {
		destination.headers = [self stringDictionary:secrets[@"headers"]];
		destination.parameters = [self stringDictionary:secrets[@"parameters"]];
		destination.arguments = [self stringDictionary:secrets[@"arguments"]];
	}

	return destination;
}

- (BOOL)saveSecretsWithIdentifier:(NSString *)identifier
{
	NSParameterAssert(identifier != nil);

	if (self.headers.count == 0 && self.parameters.count == 0 && self.arguments.count == 0) {
		[self.class removeSecretsWithIdentifier:identifier];

		return YES;
	}

	NSDictionary *secrets = @{
		@"headers" : self.headers,
		@"parameters" : self.parameters,
		@"arguments" : self.arguments
	};

	NSData *data = [NSJSONSerialization dataWithJSONObject:secrets options:0 error:NULL];

	NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	if (string == nil) {
		return NO;
	}

	return [TLOKeychain setPassword:string ofKind:TLOKeychainItemKindUploadSecrets forIdentifier:identifier];
}

+ (void)removeSecretsWithIdentifier:(NSString *)identifier
{
	NSParameterAssert(identifier != nil);

	[TLOKeychain deletePasswordOfKind:TLOKeychainItemKindUploadSecrets forIdentifier:identifier];
}

+ (nullable TLOUploadDestination *)globalDestination
{
	NSDictionary *propertyList = [RZUserDefaults() dictionaryForKey:_globalDestinationKey];

	if (propertyList == nil) {
		return nil;
	}

	return [self destinationWithPropertyList:propertyList secretsIdentifier:_globalSecretsIdentifier];
}

+ (void)setGlobalDestination:(nullable TLOUploadDestination *)globalDestination
{
	if (globalDestination == nil) {
		[RZUserDefaults() removeObjectForKey:_globalDestinationKey];

		[self removeSecretsWithIdentifier:_globalSecretsIdentifier];

		return;
	}

	[globalDestination saveSecretsWithIdentifier:_globalSecretsIdentifier];

	[RZUserDefaults() setObject:globalDestination.propertyList forKey:_globalDestinationKey];
}

+ (BOOL)hidesUploadButtonWithoutDestination
{
	return [RZUserDefaults() boolForKey:_hideButtonKey];
}

+ (void)setHidesUploadButtonWithoutDestination:(BOOL)hidesUploadButtonWithoutDestination
{
	[RZUserDefaults() setBool:hidesUploadButtonWithoutDestination forKey:_hideButtonKey];
}

#pragma mark -
#pragma mark Request

- (NSDictionary<NSString *, NSString *> *)expandedDictionary:(NSDictionary<NSString *, NSString *> *)dictionary fileName:(NSString *)fileName
{
	NSMutableDictionary *expanded = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];

	[dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
		expanded[key] = [self.class expandTemplate:value response:nil data:nil regexes:@[] fileName:fileName];
	}];

	return [expanded copy];
}

/* A name in a form part: quotes and line breaks escaped (HTML's way) */
+ (NSString *)formQuotedString:(NSString *)string
{
	string = [string stringByReplacingOccurrencesOfString:@"\"" withString:@"%22"];
	string = [string stringByReplacingOccurrencesOfString:@"\r" withString:@"%0D"];
	string = [string stringByReplacingOccurrencesOfString:@"\n" withString:@"%0A"];

	return string;
}

- (nullable NSMutableURLRequest *)requestForFileAtURL:(NSURL *)fileURL
											 fileName:(NSString *)fileName
										  contentType:(NSString *)contentType
									  temporaryFolder:(NSURL *)folder
										   bodyFileURL:(NSURL * _Nullable * _Nonnull)bodyFileURL
{
	NSParameterAssert(fileURL != nil);
	NSParameterAssert(fileName != nil);
	NSParameterAssert(contentType != nil);
	NSParameterAssert(folder != nil);

	if (self.problem) {
		return nil;
	}

	NSURLComponents *components = [NSURLComponents componentsWithString:self.requestAddress];

	if (components == nil) {
		return nil;
	}

	NSDictionary *parameters = [self expandedDictionary:self.parameters fileName:fileName];

	if (parameters.count > 0) {
		NSMutableArray *queryItems = [NSMutableArray arrayWithArray:(components.queryItems ?: @[])];

		for (NSString *key in [parameters.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
			[queryItems addObject:[NSURLQueryItem queryItemWithName:key value:parameters[key]]];
		}

		components.queryItems = queryItems;
	}

	NSURL *address = components.URL;

	if (address == nil || [self.class addressIsAllowed:address] == NO) {
		return nil;
	}

	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:address];

	request.HTTPMethod = self.method;

	NSDictionary *headers = [self expandedDictionary:self.headers fileName:fileName];

	[headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
		[request setValue:value forHTTPHeaderField:key];
	}];

	if (self.body == TLOUploadDestinationBodyBinary) {
		if ([request valueForHTTPHeaderField:@"Content-Type"] == nil) {
			[request setValue:contentType forHTTPHeaderField:@"Content-Type"];
		}

		*bodyFileURL = fileURL;

		return request;
	}

	/* A form: the fields, then the file */
	NSString *boundary = [NSString stringWithFormat:@"Textual-%@", [NSUUID UUID].UUIDString];

	NSURL *formURL = [folder URLByAppendingPathComponent:@"form-body"];

	if ([RZFileManager() createFileAtPath:formURL.path contents:nil attributes:nil] == NO) {
		return nil;
	}

	NSFileHandle *output = [NSFileHandle fileHandleForWritingToURL:formURL error:NULL];

	NSFileHandle *input = [NSFileHandle fileHandleForReadingFromURL:fileURL error:NULL];

	if (output == nil || input == nil) {
		return nil;
	}

	NSMutableString *head = [NSMutableString string];

	NSDictionary *arguments = [self expandedDictionary:self.arguments fileName:fileName];

	for (NSString *key in [arguments.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
		[head appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n%@\r\n", boundary, [self.class formQuotedString:key], arguments[key]];
	}

	[head appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\nContent-Type: %@\r\n\r\n",
		boundary, [self.class formQuotedString:self.fileFieldName], [self.class formQuotedString:fileName], contentType];

	BOOL written = [output writeData:[head dataUsingEncoding:NSUTF8StringEncoding] error:NULL];

	while (written) {
		NSData *chunk = [input readDataUpToLength:(1024 * 1024) error:NULL];

		if (chunk == nil) {
			written = NO;

			break;
		}

		if (chunk.length == 0) {
			break;
		}

		written = [output writeData:chunk error:NULL];
	}

	if (written) {
		written = [output writeData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding] error:NULL];
	}

	[output closeAndReturnError:NULL];
	[input closeAndReturnError:NULL];

	if (written == NO) {
		return nil;
	}

	[request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];

	*bodyFileURL = formURL;

	return request;
}

#pragma mark -
#pragma mark Answer

- (nullable NSURL *)linkFromResponse:(NSHTTPURLResponse *)response data:(NSData *)data
{
	NSParameterAssert(response != nil);
	NSParameterAssert(data != nil);

	NSString *linkString = nil;

	if (self.linkTemplate.length > 0) {
		linkString = [self.class expandTemplate:self.linkTemplate response:response data:data regexes:self.regexes fileName:nil];
	} else {
		/* Without a template: Location, else the answer's text */
		linkString = [response valueForHTTPHeaderField:@"Location"];

		if (linkString.length == 0) {
			linkString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		}
	}

	linkString = [linkString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	if (linkString.length == 0) {
		return nil;
	}

	NSURL *link = [NSURL URLWithString:linkString relativeToURL:response.URL].absoluteURL;

	NSString *scheme = link.scheme.lowercaseString;

	if (link.host.length == 0 || ([scheme isEqualToString:@"https"] == NO && [scheme isEqualToString:@"http"] == NO)) {
		return nil;
	}

	return link;
}

- (nullable NSString *)errorFromResponse:(NSHTTPURLResponse *)response data:(NSData *)data
{
	NSParameterAssert(response != nil);
	NSParameterAssert(data != nil);

	if (self.errorTemplate.length == 0) {
		return nil;
	}

	NSString *error = [self.class expandTemplate:self.errorTemplate response:response data:data regexes:self.regexes fileName:nil];

	error = [error stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	return ((error.length > 0) ? error : nil);
}

#pragma mark -
#pragma mark Templates

/* a.b[0].c, with or without a leading "$." */
+ (nullable id)valueAtJSONPath:(NSString *)path inObject:(nullable id)object
{
	NSParameterAssert(path != nil);

	if ([path hasPrefix:@"$."]) {
		path = [path substringFromIndex:2];
	} else if ([path hasPrefix:@"$"]) {
		path = [path substringFromIndex:1];
	}

	NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"([^.\\[\\]]+)|\\[(\\d+)\\]" options:0 error:NULL];

	__block id value = object;

	[expression enumerateMatchesInString:path options:0 range:NSMakeRange(0, path.length) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
		if ([match rangeAtIndex:1].location != NSNotFound) {
			NSString *key = [path substringWithRange:[match rangeAtIndex:1]];

			value = (([value isKindOfClass:[NSDictionary class]]) ? value[key] : nil);
		} else {
			NSUInteger index = [path substringWithRange:[match rangeAtIndex:2]].integerValue;

			value = (([value isKindOfClass:[NSArray class]] && index < [value count]) ? value[index] : nil);
		}

		if (value == nil) {
			*stop = YES;
		}
	}];

	return value;
}

+ (NSString *)expandTemplate:(NSString *)template response:(nullable NSHTTPURLResponse *)response data:(nullable NSData *)data regexes:(NSArray<NSString *> *)regexes fileName:(nullable NSString *)fileName
{
	NSParameterAssert(template != nil);
	NSParameterAssert(regexes != nil);

	NSString *text = ((data) ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil);

	__block id json = nil;
	__block BOOL jsonRead = NO;

	NSString *(^valueFor)(NSString *, NSString *) = ^NSString *(NSString *function, NSString *argument) {
		function = function.lowercaseString;

		if ([function isEqualToString:@"filename"]) {
			return fileName;
		}

		if ([function isEqualToString:@"response"]) {
			return text;
		}

		if ([function isEqualToString:@"header"] && argument) {
			return [response valueForHTTPHeaderField:argument];
		}

		if ([function isEqualToString:@"json"] && argument) {
			if (jsonRead == NO && data) {
				json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:NULL];

				jsonRead = YES;
			}

			id value = [self valueAtJSONPath:argument inObject:json];

			if ([value isKindOfClass:[NSString class]]) {
				return value;
			} else if ([value isKindOfClass:[NSNumber class]]) {
				return [value stringValue];
			}

			return nil;
		}

		if ([function isEqualToString:@"regex"] && argument && text) {
			/* $regex:1|1$: the first pattern of the list, its first group (or a named one) */
			NSArray *parts = [argument componentsSeparatedByString:@"|"];

			NSInteger index = [parts[0] integerValue] - 1;

			if (index < 0 || index >= (NSInteger)regexes.count) {
				return nil;
			}

			NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regexes[index] options:0 error:NULL];

			NSTextCheckingResult *match = [expression firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];

			if (match == nil) {
				return nil;
			}

			NSString *group = ((parts.count > 1) ? parts[1] : @"0");

			NSRange range = NSMakeRange(NSNotFound, 0);

			if ([group rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound) {
				NSUInteger groupIndex = group.integerValue;

				if (groupIndex < match.numberOfRanges) {
					range = [match rangeAtIndex:groupIndex];
				}
			} else {
				range = [match rangeWithName:group];
			}

			return ((range.location != NSNotFound) ? [text substringWithRange:range] : nil);
		}

		return (id)[NSNull null]; // not a function of ours: left as it is
	};

	/* $function:argument$ (ShareX before 14) and {function:argument} (since) */
	NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"\\$([a-zA-Z]+)(?::([^$]*))?\\$|\\{([a-zA-Z]+)(?::([^{}]*))?\\}" options:0 error:NULL];

	NSMutableString *result = [NSMutableString string];

	__block NSUInteger position = 0;

	[expression enumerateMatchesInString:template options:0 range:NSMakeRange(0, template.length) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
		NSRange functionRange = (([match rangeAtIndex:1].location != NSNotFound) ? [match rangeAtIndex:1] : [match rangeAtIndex:3]);
		NSRange argumentRange = (([match rangeAtIndex:1].location != NSNotFound) ? [match rangeAtIndex:2] : [match rangeAtIndex:4]);

		NSString *function = [template substringWithRange:functionRange];
		NSString *argument = ((argumentRange.location != NSNotFound) ? [template substringWithRange:argumentRange] : nil);

		[result appendString:[template substringWithRange:NSMakeRange(position, (match.range.location - position))]];

		id value = valueFor(function, argument);

		if (value == [NSNull null]) {
			[result appendString:[template substringWithRange:match.range]];
		} else if (value) {
			[result appendString:value];
		}

		position = NSMaxRange(match.range);
	}];

	[result appendString:[template substringFromIndex:position]];

	return [result copy];
}

@end

NS_ASSUME_NONNULL_END
