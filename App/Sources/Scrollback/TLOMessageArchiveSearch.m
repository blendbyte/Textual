/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
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

#import <sqlite3.h>

#import "TLOMessageArchivePrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* Words shorter than this aren't in the text index (trigrams) and are
 looked for in the text itself */
#define _indexedTermLength			3

/* A result's columns, in the order TLOMessageArchiveResult reads them */
#define _resultColumns				@"m.id, m.server_id, m.server_name, m.view_id, m.view_name, m.view_type, m.time, m.line_type, " \
									@"m.nickname, m.is_self, m.is_highlight, m.has_link, m.msgid, m.line_id, m.body"

@interface TLOMessageArchiveResult ()
@property (readwrite) int64_t rowId;
@property (readwrite, copy) NSString *serverId;
@property (readwrite, copy) NSString *serverName;
@property (readwrite, copy) NSString *viewId;
@property (readwrite, copy) NSString *viewName;
@property (readwrite) TLOMessageArchiveViewType viewType;
@property (readwrite, copy) NSDate *date;
@property (readwrite) NSUInteger lineType;
@property (readwrite, copy, nullable) NSString *nickname;
@property (readwrite) BOOL isSelf;
@property (readwrite) BOOL isHighlight;
@property (readwrite) BOOL hasLink;
@property (readwrite, copy, nullable) NSString *msgid;
@property (readwrite, copy) NSString *lineId;
@property (readwrite, copy) NSString *body;
@property (readwrite, copy) NSArray<NSValue *> *matchRanges;

+ (instancetype)_resultWithStatement:(sqlite3_stmt *)statement terms:(NSArray<NSString *> *)terms;
@end

@interface TLOMessageArchiveSearchPage ()
@property (readwrite, copy) NSArray<TLOMessageArchiveResult *> *results;
@property (readwrite) BOOL hasMore;
@end

static NSString * _Nullable TLOMessageArchiveColumnString(sqlite3_stmt *statement, int column)
{
	const unsigned char *text = sqlite3_column_text(statement, column);

	if (text == NULL) {
		return nil;
	}

	return @((const char *)text);
}

#pragma mark -
#pragma mark Query

@interface TLOMessageArchiveQuery ()
@property (readwrite, copy) NSString *string;
@property (readwrite, copy) NSArray<NSString *> *terms;
@property (readwrite, copy) NSArray<NSString *> *nicknames;
@property (readwrite, copy) NSArray<NSString *> *viewNames;
@property (readwrite, copy, nullable) NSDate *earliestDate;
@property (readwrite, copy, nullable) NSDate *latestDate;
@property (readwrite) BOOL hasLink;
@property (readwrite) BOOL mentionsMe;
@end

@implementation TLOMessageArchiveQuery

+ (instancetype)queryWithString:(NSString *)string
{
	return [self queryWithString:string calendar:[NSCalendar currentCalendar] now:[NSDate date]];
}

+ (instancetype)queryWithString:(NSString *)string calendar:(NSCalendar *)calendar now:(NSDate *)now
{
	NSParameterAssert(string != nil);
	NSParameterAssert(calendar != nil);
	NSParameterAssert(now != nil);

	TLOMessageArchiveQuery *query = [self new];

	[query _parseString:string calendar:calendar now:now];

	return query;
}

- (instancetype)init
{
	if ((self = [super init])) {
		self.string = @"";
		self.terms = @[];
		self.nicknames = @[];
		self.viewNames = @[];

		return self;
	}

	return nil;
}

- (id)copyWithZone:(nullable NSZone *)zone
{
	TLOMessageArchiveQuery *query = [[self.class allocWithZone:zone] init];

	query.string = self.string;
	query.terms = self.terms;
	query.nicknames = self.nicknames;
	query.viewNames = self.viewNames;
	query.earliestDate = self.earliestDate;
	query.latestDate = self.latestDate;
	query.hasLink = self.hasLink;
	query.mentionsMe = self.mentionsMe;
	query.serverId = self.serverId;
	query.viewId = self.viewId;
	query.order = self.order;

	return query;
}

- (BOOL)isEmpty
{
	return (self.terms.count == 0 &&
			self.nicknames.count == 0 &&
			self.viewNames.count == 0 &&
			self.earliestDate == nil &&
			self.latestDate == nil &&
			self.hasLink == NO &&
			self.mentionsMe == NO);
}

- (void)_parseString:(NSString *)string calendar:(NSCalendar *)calendar now:(NSDate *)now
{
	self.string = string;

	NSMutableArray<NSString *> *terms = [NSMutableArray array];
	NSMutableArray<NSString *> *nicknames = [NSMutableArray array];
	NSMutableArray<NSString *> *viewNames = [NSMutableArray array];

	for (NSString *token in [self.class _tokensOfString:string]) {
		NSRange colon = [token rangeOfString:@":"];

		if (colon.location != NSNotFound && colon.location > 0) {
			NSString *key = [token substringToIndex:colon.location].lowercaseString;

			NSString *value = [self.class _unquote:[token substringFromIndex:NSMaxRange(colon)]];

			if ([self _applyFilter:key value:value nicknames:nicknames viewNames:viewNames calendar:calendar now:now]) {
				continue;
			}
		}

		NSString *term = [self.class _unquote:token];

		/* Every word is found inside words, so word* is word */
		if ([token hasPrefix:@"\""] == NO) {
			while ([term hasSuffix:@"*"]) {
				term = [term substringToIndex:(term.length - 1)];
			}
		}

		if (term.length > 0) {
			[terms addObject:term];
		}
	}

	self.terms = terms;
	self.nicknames = nicknames;
	self.viewNames = viewNames;
}

/* Split at spaces outside quotes; the quotes stay, so a phrase is known
 by them. Typographic quotes (as text fields put them) count too. */
+ (NSArray<NSString *> *)_tokensOfString:(NSString *)string
{
	for (NSString *quote in @[@"“", @"”", @"„", @"‟"]) {
		string = [string stringByReplacingOccurrencesOfString:quote withString:@"\""];
	}

	NSCharacterSet *spaces = [NSCharacterSet whitespaceAndNewlineCharacterSet];

	NSMutableArray<NSString *> *tokens = [NSMutableArray array];

	NSMutableString *token = [NSMutableString string];

	BOOL quoted = NO;

	for (NSUInteger i = 0; i < string.length; i++) {
		unichar character = [string characterAtIndex:i];

		if (character == '"') {
			quoted = (quoted == NO);
		} else if (quoted == NO && [spaces characterIsMember:character]) {
			if (token.length > 0) {
				[tokens addObject:[token copy]];

				[token setString:@""];
			}

			continue;
		}

		[token appendFormat:@"%C", character];
	}

	if (token.length > 0) {
		[tokens addObject:[token copy]];
	}

	return [tokens copy];
}

+ (NSString *)_unquote:(NSString *)string
{
	return [string stringByReplacingOccurrencesOfString:@"\"" withString:@""];
}

/* NO when it isn't a filter, so it's searched as text */
- (BOOL)_applyFilter:(NSString *)key
			   value:(NSString *)value
		   nicknames:(NSMutableArray<NSString *> *)nicknames
		   viewNames:(NSMutableArray<NSString *> *)viewNames
			calendar:(NSCalendar *)calendar
				 now:(NSDate *)now
{
	BOOL isDateFilter = ([key isEqualToString:@"before"] || [key isEqualToString:@"after"] || [key isEqualToString:@"during"]);

	if ([key isEqualToString:@"from"] == NO &&
		[key isEqualToString:@"in"] == NO &&
		[key isEqualToString:@"has"] == NO &&
		[key isEqualToString:@"mentions"] == NO &&
		isDateFilter == NO)
	{
		return NO;
	}

	/* Still being typed */
	if (value.length == 0) {
		return YES;
	}

	if ([key isEqualToString:@"from"]) {
		if ([value hasPrefix:@"@"]) {
			value = [value substringFromIndex:1];
		}

		if (value.length > 0) {
			[nicknames addObject:value];
		}

		return YES;
	}

	if ([key isEqualToString:@"in"]) {
		[viewNames addObject:value];

		return YES;
	}

	if ([key isEqualToString:@"has"]) {
		if ([value.lowercaseString isEqualToString:@"link"] == NO && [value.lowercaseString isEqualToString:@"links"] == NO) {
			return NO;
		}

		self.hasLink = YES;

		return YES;
	}

	if ([key isEqualToString:@"mentions"]) {
		if ([value.lowercaseString isEqualToString:@"me"] == NO) {
			return NO;
		}

		self.mentionsMe = YES;

		return YES;
	}

	NSDate *start = nil;
	NSDate *end = nil;

	if ([self.class _parseDate:value calendar:calendar now:now start:&start end:&end] == NO) {
		return NO;
	}

	/* Several narrow it down */
	if ([key isEqualToString:@"before"] || [key isEqualToString:@"during"]) {
		NSDate *latest = (([key isEqualToString:@"before"]) ? start : end);

		if (self.latestDate == nil || [latest compare:self.latestDate] == NSOrderedAscending) {
			self.latestDate = latest;
		}
	}

	if ([key isEqualToString:@"after"] || [key isEqualToString:@"during"]) {
		NSDate *earliest = (([key isEqualToString:@"after"]) ? end : start);

		if (self.earliestDate == nil || [earliest compare:self.earliestDate] == NSOrderedDescending) {
			self.earliestDate = earliest;
		}
	}

	return YES;
}

/* A day, a month or a year (2026-10-05, 2026-10, 2026), today or
 yesterday: when it starts and when the next one starts */
+ (BOOL)_parseDate:(NSString *)value calendar:(NSCalendar *)calendar now:(NSDate *)now start:(NSDate * _Nullable * _Nonnull)start end:(NSDate * _Nullable * _Nonnull)end
{
	NSString *lowercaseValue = value.lowercaseString;

	if ([lowercaseValue isEqualToString:@"today"] || [lowercaseValue isEqualToString:@"yesterday"]) {
		NSDate *today = [calendar startOfDayForDate:now];

		if ([lowercaseValue isEqualToString:@"today"]) {
			*start = today;
			*end = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:today options:0];
		} else {
			*start = [calendar dateByAddingUnit:NSCalendarUnitDay value:(-1) toDate:today options:0];
			*end = today;
		}

		return (*start != nil && *end != nil);
	}

	static NSRegularExpression *expression = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		expression = [NSRegularExpression regularExpressionWithPattern:@"^(\\d{4})(?:-(\\d{1,2})(?:-(\\d{1,2}))?)?$" options:0 error:NULL];
	});

	NSTextCheckingResult *match = [expression firstMatchInString:value options:0 range:NSMakeRange(0, value.length)];

	if (match == nil) {
		return NO;
	}

	NSDateComponents *components = [NSDateComponents new];

	components.year = [value substringWithRange:[match rangeAtIndex:1]].integerValue;
	components.month = 1;
	components.day = 1;

	NSCalendarUnit unit = NSCalendarUnitYear;

	if ([match rangeAtIndex:2].location != NSNotFound) {
		components.month = [value substringWithRange:[match rangeAtIndex:2]].integerValue;

		unit = NSCalendarUnitMonth;
	}

	if ([match rangeAtIndex:3].location != NSNotFound) {
		components.day = [value substringWithRange:[match rangeAtIndex:3]].integerValue;

		unit = NSCalendarUnitDay;
	}

	NSDate *date = [calendar dateFromComponents:components];

	if (date == nil) {
		return NO;
	}

	/* 2026-02-30 would be in March */
	NSDateComponents *dateComponents = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:date];

	if (dateComponents.year != components.year || dateComponents.month != components.month || dateComponents.day != components.day) {
		return NO;
	}

	*start = date;
	*end = [calendar dateByAddingUnit:unit value:1 toDate:date options:0];

	return (*end != nil);
}

#pragma mark -
#pragma mark SQL

/* Several names of one filter are any of them; in:textual is #textual too */
- (NSArray<NSString *> *)_viewNamesToMatch
{
	NSMutableArray<NSString *> *viewNames = [NSMutableArray array];

	NSCharacterSet *channelPrefixes = [NSCharacterSet characterSetWithCharactersInString:@"#&!+"];

	for (NSString *viewName in self.viewNames) {
		[viewNames addObject:viewName];

		if ([channelPrefixes characterIsMember:[viewName characterAtIndex:0]] == NO) {
			[viewNames addObject:[@"#" stringByAppendingString:viewName]];
		}
	}

	return [viewNames copy];
}

+ (BOOL)_termIsIndexed:(NSString *)term
{
	return (([term lengthOfBytesUsingEncoding:NSUTF32StringEncoding] / 4) >= _indexedTermLength);
}

/* The FROM and WHERE of the search, with its arguments (strings and numbers) */
- (NSString *)_fromAndWhereWithArguments:(NSMutableArray *)arguments usesIndex:(BOOL *)usesIndex
{
	NSMutableArray<NSString *> *indexedTerms = [NSMutableArray array];
	NSMutableArray<NSString *> *otherTerms = [NSMutableArray array];

	for (NSString *term in self.terms) {
		if ([self.class _termIsIndexed:term]) {
			[indexedTerms addObject:term];
		} else {
			[otherTerms addObject:term];
		}
	}

	NSMutableArray<NSString *> *conditions = [NSMutableArray array];

	NSString *from = @"FROM messages m";

	/* Each term as a string: found as it is written (a phrase in one piece) */
	if (indexedTerms.count > 0) {
		from = @"FROM messages_text JOIN messages m ON m.id = messages_text.rowid";

		NSMutableArray<NSString *> *strings = [NSMutableArray array];

		for (NSString *term in indexedTerms) {
			[strings addObject:[NSString stringWithFormat:@"\"%@\"", [term stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]]];
		}

		[conditions addObject:@"messages_text MATCH ?"];

		[arguments addObject:[strings componentsJoinedByString:@" "]];
	}

	if (self.viewId) {
		[conditions addObject:@"m.view_id = ?"];

		[arguments addObject:self.viewId];
	} else if (self.serverId) {
		[conditions addObject:@"m.server_id = ?"];

		[arguments addObject:self.serverId];
	}

	void (^anyOf)(NSString *, NSArray<NSString *> *) = ^(NSString *column, NSArray<NSString *> *values) {
		if (values.count == 0) {
			return;
		}

		NSMutableArray<NSString *> *placeholders = [NSMutableArray array];

		for (NSString *value in values) {
			[placeholders addObject:@"?"];

			[arguments addObject:value];
		}

		[conditions addObject:[NSString stringWithFormat:@"%@ COLLATE NOCASE IN (%@)", column, [placeholders componentsJoinedByString:@", "]]];
	};

	anyOf(@"m.nickname", self.nicknames);
	anyOf(@"m.view_name", [self _viewNamesToMatch]);

	if (self.earliestDate) {
		[conditions addObject:@"m.time >= ?"];

		[arguments addObject:@(self.earliestDate.timeIntervalSince1970)];
	}

	if (self.latestDate) {
		[conditions addObject:@"m.time < ?"];

		[arguments addObject:@(self.latestDate.timeIntervalSince1970)];
	}

	if (self.hasLink) {
		[conditions addObject:@"m.has_link = 1"];
	}

	if (self.mentionsMe) {
		[conditions addObject:@"m.is_highlight = 1"];
	}

	/* Too short for the index: in the text (any case for ASCII only) */
	for (NSString *term in otherTerms) {
		NSString *pattern = term;

		for (NSString *special in @[@"\\", @"%", @"_"]) {
			pattern = [pattern stringByReplacingOccurrencesOfString:special withString:[@"\\" stringByAppendingString:special]];
		}

		[conditions addObject:@"m.body LIKE ? ESCAPE '\\'"];

		[arguments addObject:[NSString stringWithFormat:@"%%%@%%", pattern]];
	}

	*usesIndex = (indexedTerms.count > 0);

	if (conditions.count == 0) {
		return from;
	}

	return [NSString stringWithFormat:@"%@ WHERE %@", from, [conditions componentsJoinedByString:@" AND "]];
}

+ (nullable sqlite3_stmt *)_prepare:(NSString *)sql arguments:(NSArray *)arguments inDatabase:(sqlite3 *)database
{
	sqlite3_stmt *statement = NULL;

	if (sqlite3_prepare_v2(database, sql.UTF8String, -1, &statement, NULL) != SQLITE_OK) {
		LogToConsoleError("Failed to prepare a message archive search: %{public}s", sqlite3_errmsg(database));

		return NULL;
	}

	[arguments enumerateObjectsUsingBlock:^(id argument, NSUInteger index, BOOL *stop) {
		int position = (int)(index + 1);

		if ([argument isKindOfClass:[NSString class]]) {
			sqlite3_bind_text(statement, position, [argument UTF8String], -1, SQLITE_TRANSIENT);
		} else if (CFNumberIsFloatType((__bridge CFNumberRef)argument)) {
			sqlite3_bind_double(statement, position, [argument doubleValue]);
		} else {
			sqlite3_bind_int64(statement, position, [argument longLongValue]);
		}
	}];

	return statement;
}

/* On the archive's search queue */
- (TLOMessageArchiveSearchPage *)_pageWithOffset:(NSUInteger)offset limit:(NSUInteger)limit inDatabase:(sqlite3 *)database
{
	TLOMessageArchiveSearchPage *page = [TLOMessageArchiveSearchPage new];

	if (self.empty || limit == 0) {
		return page;
	}

	NSMutableArray *arguments = [NSMutableArray array];

	BOOL usesIndex = NO;

	NSString *fromAndWhere = [self _fromAndWhereWithArguments:arguments usesIndex:&usesIndex];

	NSString *order = @"m.time DESC, m.id DESC";

	if (usesIndex && self.order == TLOMessageArchiveSearchOrderBestMatch) {
		order = @"messages_text.rank, m.time DESC, m.id DESC";
	}

	/* One more than asked for tells whether there is a next page */
	NSString *sql = [NSString stringWithFormat:@"SELECT %@ %@ ORDER BY %@ LIMIT ? OFFSET ?", _resultColumns, fromAndWhere, order];

	[arguments addObject:@(limit + 1)];
	[arguments addObject:@(offset)];

	sqlite3_stmt *statement = [self.class _prepare:sql arguments:arguments inDatabase:database];

	if (statement == NULL) {
		return page;
	}

	NSMutableArray<TLOMessageArchiveResult *> *results = [NSMutableArray array];

	int result = SQLITE_OK;

	while ((result = sqlite3_step(statement)) == SQLITE_ROW) {
		if (results.count == limit) {
			page.hasMore = YES;

			break;
		}

		[results addObject:[TLOMessageArchiveResult _resultWithStatement:statement terms:self.terms]];
	}

	if (result != SQLITE_ROW && result != SQLITE_DONE) {
		LogToConsoleError("Message archive search failed: %{public}s", sqlite3_errmsg(database));
	}

	sqlite3_finalize(statement);

	page.results = results;

	return page;
}

/* Up to count messages before the result in its view and count after it,
 with the result, oldest first */
+ (NSArray<TLOMessageArchiveResult *> *)_messagesAround:(TLOMessageArchiveResult *)result count:(NSUInteger)count inDatabase:(sqlite3 *)database
{
	NSMutableArray<TLOMessageArchiveResult *> *messages = [NSMutableArray array];

	NSString *before = [NSString stringWithFormat:@"SELECT %@ FROM messages m WHERE m.view_id = ? AND (m.time, m.id) < (?, ?) ORDER BY m.time DESC, m.id DESC LIMIT ?", _resultColumns];
	NSString *after = [NSString stringWithFormat:@"SELECT %@ FROM messages m WHERE m.view_id = ? AND (m.time, m.id) >= (?, ?) ORDER BY m.time, m.id LIMIT ?", _resultColumns];

	NSArray *beforeArguments = @[result.viewId, @(result.date.timeIntervalSince1970), @(result.rowId), @(count)];
	NSArray *afterArguments = @[result.viewId, @(result.date.timeIntervalSince1970), @(result.rowId), @(count + 1)];

	for (NSUInteger step = 0; step < 2; step++) {
		sqlite3_stmt *statement = [self _prepare:((step == 0) ? before : after) arguments:((step == 0) ? beforeArguments : afterArguments) inDatabase:database];

		if (statement == NULL) {
			return @[];
		}

		NSMutableArray<TLOMessageArchiveResult *> *stepMessages = [NSMutableArray array];

		while (sqlite3_step(statement) == SQLITE_ROW) {
			[stepMessages addObject:[TLOMessageArchiveResult _resultWithStatement:statement terms:@[]]];
		}

		sqlite3_finalize(statement);

		if (step == 0) {
			[messages addObjectsFromArray:stepMessages.reverseObjectEnumerator.allObjects];
		} else {
			[messages addObjectsFromArray:stepMessages];
		}
	}

	return [messages copy];
}

/* See -[TLOMessageArchive messagesInView:rowId:before:after:scrollbackLineId:scrollbackTime:completionHandler:] */
+ (NSArray<TLOMessageArchiveResult *> *)_messagesInView:(NSString *)viewId
												   rowId:(int64_t)rowId
												  before:(NSUInteger)before
												   after:(NSUInteger)after
										scrollbackLineId:(nullable NSString *)scrollbackLineId
										  scrollbackTime:(NSTimeInterval)scrollbackTime
											 anchorIndex:(NSUInteger *)anchorIndex
											  inDatabase:(sqlite3 *)database
{
	*anchorIndex = NSNotFound;

	/* Where the scrollback starts, as (time, id): its first line's own row
	 when the archive has it (messages of the same time stay in order), else
	 the time (before every message of that time) */
	NSNumber *startTime = @(scrollbackTime);
	NSNumber *startRowId = @0;

	if (scrollbackLineId) {
		sqlite3_stmt *statement = [self _prepare:@"SELECT time, id FROM messages WHERE view_id = ? AND line_id = ?" arguments:@[viewId, scrollbackLineId] inDatabase:database];

		if (statement) {
			if (sqlite3_step(statement) == SQLITE_ROW) {
				startTime = @(sqlite3_column_double(statement, 0));
				startRowId = @(sqlite3_column_int64(statement, 1));
			}

			sqlite3_finalize(statement);
		}
	}

	/* The point: the message, or where the scrollback starts */
	NSArray *point = @[startTime, startRowId];

	TLOMessageArchiveResult *anchor = nil;

	if (rowId != 0) {
		NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM messages m WHERE m.id = ? AND m.view_id = ? AND (m.time, m.id) < (?, ?)", _resultColumns];

		sqlite3_stmt *statement = [self _prepare:sql arguments:@[@(rowId), viewId, startTime, startRowId] inDatabase:database];

		if (statement == NULL) {
			return @[];
		}

		if (sqlite3_step(statement) == SQLITE_ROW) {
			anchor = [TLOMessageArchiveResult _resultWithStatement:statement terms:@[]];
		}

		sqlite3_finalize(statement);

		/* Gone, or the scrollback has it */
		if (anchor == nil) {
			return @[];
		}

		point = @[@(anchor.date.timeIntervalSince1970), @(anchor.rowId)];
	}

	NSMutableArray<TLOMessageArchiveResult *> *messages = [NSMutableArray array];

	if (before > 0) {
		NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM messages m WHERE m.view_id = ? AND (m.time, m.id) < (?, ?) ORDER BY m.time DESC, m.id DESC LIMIT ?", _resultColumns];

		sqlite3_stmt *statement = [self _prepare:sql arguments:@[viewId, point[0], point[1], @(before)] inDatabase:database];

		if (statement) {
			while (sqlite3_step(statement) == SQLITE_ROW) {
				[messages insertObject:[TLOMessageArchiveResult _resultWithStatement:statement terms:@[]] atIndex:0];
			}

			sqlite3_finalize(statement);
		}
	}

	if (anchor) {
		*anchorIndex = messages.count;

		[messages addObject:anchor];
	}

	if (anchor && after > 0) {
		NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM messages m WHERE m.view_id = ? AND (m.time, m.id) > (?, ?) AND (m.time, m.id) < (?, ?) ORDER BY m.time, m.id LIMIT ?", _resultColumns];

		sqlite3_stmt *statement = [self _prepare:sql arguments:@[viewId, point[0], point[1], startTime, startRowId, @(after)] inDatabase:database];

		if (statement) {
			while (sqlite3_step(statement) == SQLITE_ROW) {
				[messages addObject:[TLOMessageArchiveResult _resultWithStatement:statement terms:@[]]];
			}

			sqlite3_finalize(statement);
		}
	}

	return [messages copy];
}

/* The most recent first */
+ (NSArray<NSString *> *)_namesInColumn:(NSString *)column limit:(NSUInteger)limit inDatabase:(sqlite3 *)database
{
	NSString *sql = [NSString stringWithFormat:@"SELECT %1$@ FROM messages WHERE %1$@ IS NOT NULL AND %1$@ != '' GROUP BY %1$@ ORDER BY max(time) DESC LIMIT ?", column];

	sqlite3_stmt *statement = [self _prepare:sql arguments:@[@(limit)] inDatabase:database];

	if (statement == NULL) {
		return @[];
	}

	NSMutableArray<NSString *> *names = [NSMutableArray array];

	while (sqlite3_step(statement) == SQLITE_ROW) {
		NSString *name = TLOMessageArchiveColumnString(statement, 0);

		if (name) {
			[names addObject:name];
		}
	}

	sqlite3_finalize(statement);

	return [names copy];
}

- (NSUInteger)_countInDatabase:(sqlite3 *)database
{
	if (self.empty) {
		return 0;
	}

	NSMutableArray *arguments = [NSMutableArray array];

	BOOL usesIndex = NO;

	NSString *sql = [NSString stringWithFormat:@"SELECT count(*) %@", [self _fromAndWhereWithArguments:arguments usesIndex:&usesIndex]];

	sqlite3_stmt *statement = [self.class _prepare:sql arguments:arguments inDatabase:database];

	if (statement == NULL) {
		return 0;
	}

	NSUInteger count = 0;

	if (sqlite3_step(statement) == SQLITE_ROW) {
		count = (NSUInteger)sqlite3_column_int64(statement, 0);
	} else {
		LogToConsoleError("Message archive count failed: %{public}s", sqlite3_errmsg(database));
	}

	sqlite3_finalize(statement);

	return count;
}

@end

#pragma mark -
#pragma mark Results


@implementation TLOMessageArchiveResult

+ (instancetype)_resultWithStatement:(sqlite3_stmt *)statement terms:(NSArray<NSString *> *)terms
{
	TLOMessageArchiveResult *result = [self new];

	result.rowId = sqlite3_column_int64(statement, 0);
	result.serverId = (TLOMessageArchiveColumnString(statement, 1) ?: @"");
	result.serverName = (TLOMessageArchiveColumnString(statement, 2) ?: @"");
	result.viewId = (TLOMessageArchiveColumnString(statement, 3) ?: @"");
	result.viewName = (TLOMessageArchiveColumnString(statement, 4) ?: @"");
	result.viewType = (TLOMessageArchiveViewType)sqlite3_column_int(statement, 5);
	result.date = [NSDate dateWithTimeIntervalSince1970:sqlite3_column_double(statement, 6)];
	result.lineType = (NSUInteger)sqlite3_column_int(statement, 7);
	result.nickname = TLOMessageArchiveColumnString(statement, 8);
	result.isSelf = (sqlite3_column_int(statement, 9) == 1);
	result.isHighlight = (sqlite3_column_int(statement, 10) == 1);
	result.hasLink = (sqlite3_column_int(statement, 11) == 1);
	result.msgid = TLOMessageArchiveColumnString(statement, 12);
	result.lineId = (TLOMessageArchiveColumnString(statement, 13) ?: @"");
	result.body = (TLOMessageArchiveColumnString(statement, 14) ?: @"");
	result.matchRanges = [self _rangesOfTerms:terms inString:result.body];

	return result;
}

/* Any case, as the index finds them; overlapping ones joined */
+ (NSArray<NSValue *> *)_rangesOfTerms:(NSArray<NSString *> *)terms inString:(NSString *)string
{
	NSMutableArray<NSValue *> *ranges = [NSMutableArray array];

	for (NSString *term in terms) {
		NSRange searchRange = NSMakeRange(0, string.length);

		while (searchRange.length > 0) {
			NSRange range = [string rangeOfString:term options:NSCaseInsensitiveSearch range:searchRange];

			if (range.location == NSNotFound) {
				break;
			}

			[ranges addObject:[NSValue valueWithRange:range]];

			searchRange = NSMakeRange(NSMaxRange(range), (string.length - NSMaxRange(range)));
		}
	}

	[ranges sortUsingComparator:^NSComparisonResult(NSValue *range1, NSValue *range2) {
		return [@(range1.rangeValue.location) compare:@(range2.rangeValue.location)];
	}];

	NSMutableArray<NSValue *> *joinedRanges = [NSMutableArray array];

	for (NSValue *value in ranges) {
		NSRange range = value.rangeValue;

		NSRange lastRange = joinedRanges.lastObject.rangeValue;

		if (joinedRanges.count > 0 && range.location <= NSMaxRange(lastRange)) {
			joinedRanges[(joinedRanges.count - 1)] = [NSValue valueWithRange:NSUnionRange(lastRange, range)];
		} else {
			[joinedRanges addObject:value];
		}
	}

	return [joinedRanges copy];
}

- (NSString *)snippetWithMaximumLength:(NSUInteger)maximumLength matchRanges:(NSArray<NSValue *> * _Nullable * _Nullable)matchRanges
{
	NSString *body = self.body;

	if (body.length <= maximumLength) {
		if (matchRanges) {
			*matchRanges = self.matchRanges;
		}

		return body;
	}

	/* The first match about a third in */
	NSRange firstMatch = ((self.matchRanges.count > 0) ? self.matchRanges.firstObject.rangeValue : NSMakeRange(0, 0));

	NSUInteger room = ((maximumLength > firstMatch.length) ? (maximumLength - firstMatch.length) : 0);

	NSUInteger start = ((firstMatch.location > (room / 3)) ? (firstMatch.location - (room / 3)) : 0);

	if ((start + maximumLength) > body.length) {
		start = (body.length - maximumLength);
	}

	/* At the start of a word when one starts close by */
	if (start > 0 && firstMatch.location > start) {
		NSRange space = [body rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
											  options:0
												range:NSMakeRange(start, MIN(15, (firstMatch.location - start)))];

		if (space.location != NSNotFound) {
			start = NSMaxRange(space);
		}
	}

	NSRange window = NSMakeRange(start, MIN(maximumLength, (body.length - start)));

	/* At the end of a word likewise, after the first match */
	if (NSMaxRange(window) < body.length) {
		NSUInteger searchStart = MAX(NSMaxRange(firstMatch), (NSMaxRange(window) - MIN(15, window.length)));

		if (NSMaxRange(window) > searchStart) {
			NSRange space = [body rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
												  options:NSBackwardsSearch
													range:NSMakeRange(searchStart, (NSMaxRange(window) - searchStart))];

			if (space.location != NSNotFound) {
				window.length = (space.location - window.location);
			}
		}
	}

	/* Not through the middle of a character */
	window = [body rangeOfComposedCharacterSequencesForRange:window];

	NSString *prefix = ((window.location > 0) ? @"…" : @"");
	NSString *suffix = ((NSMaxRange(window) < body.length) ? @"…" : @"");

	if (matchRanges) {
		NSMutableArray<NSValue *> *ranges = [NSMutableArray array];

		for (NSValue *value in self.matchRanges) {
			NSRange range = NSIntersectionRange(value.rangeValue, window);

			if (range.length == 0) {
				continue;
			}

			range.location = (range.location - window.location + prefix.length);

			[ranges addObject:[NSValue valueWithRange:range]];
		}

		*matchRanges = [ranges copy];
	}

	return [NSString stringWithFormat:@"%@%@%@", prefix, [body substringWithRange:window], suffix];
}

@end

#pragma mark -
#pragma mark Pages

@implementation TLOMessageArchiveSearchPage

- (instancetype)init
{
	if ((self = [super init])) {
		self.results = @[];

		return self;
	}

	return nil;
}

@end

NS_ASSUME_NONNULL_END
