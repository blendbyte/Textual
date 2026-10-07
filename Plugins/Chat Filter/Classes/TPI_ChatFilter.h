/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2015 - 2018 Codeux Software, LLC & respective contributors.
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

#import "Textual.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TPI_ChatFilterLimitToValue) {
	TPI_ChatFilterLimitToValueNoLimit				= 0,
	TPI_ChatFilterLimitToValueChannels				= 1,
	TPI_ChatFilterLimitToValuePrivateMessages		= 2,
	TPI_ChatFilterLimitToValueSpecificItems			= 3
};

typedef NS_ENUM(NSUInteger, TPI_ChatFilterAgeComparator) {
	TPI_ChatFilterAgeComparatorNone				= 0,
	TPI_ChatFilterAgeComparatorLessThan			= 1, // Filter only executes if age of user is < limit
	TPI_ChatFilterAgeComparatorGreaterThan		= 2 // Filter only executes if age of user is >= limit
};

typedef NS_OPTIONS(NSUInteger, TPI_ChatFilterEventType) {
	TPI_ChatFilterEventTypeNumeric					= 1 << 0,
	TPI_ChatFilterEventTypePlainTextMessage			= 1 << 1,
	TPI_ChatFilterEventTypeActionMessage			= 1 << 2,
	TPI_ChatFilterEventTypeNoticeMessage			= 1 << 3,
	TPI_ChatFilterEventTypeUserJoinedChannel		= 1 << 4,
	TPI_ChatFilterEventTypeUserLeftChannel			= 1 << 5,
	TPI_ChatFilterEventTypeUserKickedFromChannel	= 1 << 6,
	TPI_ChatFilterEventTypeUserDisconnected			= 1 << 7,
	TPI_ChatFilterEventTypeUserChangedNickname		= 1 << 8,
	TPI_ChatFilterEventTypeChannelTopicReceived		= 1 << 9,
	TPI_ChatFilterEventTypeChannelTopicChanged		= 1 << 10,
	TPI_ChatFilterEventTypeChannelModeReceived		= 1 << 11,
	TPI_ChatFilterEventTypeChannelModeChanged		= 1 << 12
};

@interface TPI_ChatFilter : XRPortablePropertyDict
@property (readonly) BOOL filterIgnoreContent;
@property (readonly) BOOL filterIgnoreOperators;
@property (readonly) BOOL filterLogMatch;
@property (readonly) BOOL filterLimitedToMyself;
@property (readonly) TPI_ChatFilterEventType filterEvents;
@property (readonly) TPI_ChatFilterLimitToValue filterLimitedToValue;
@property (readonly) TPI_ChatFilterAgeComparator filterAgeComparator;
@property (readonly) NSUInteger filterAgeLimit;
@property (readonly) NSUInteger filterActionFloodControlInterval;
@property (readonly, copy) NSArray<NSString *> *filterLimitedToChannelsIDs;
@property (readonly, copy) NSArray<NSString *> *filterLimitedToClientsIDs;
@property (readonly, copy) NSArray<NSString *> *filterEventsNumerics;
@property (readonly, copy) NSString *filterAction;
@property (readonly, copy) NSString *filterDescription;
@property (readonly, copy) NSString *filterForwardToDestination;
@property (readonly, copy) NSString *filterMatch;
@property (readonly, copy) NSString *filterNotes;
@property (readonly, copy) NSString *filterSenderMatch;
@property (readonly, copy) NSString *filterTitle;
@property (readonly, copy) NSString *uniqueIdentifier;

- (BOOL)isEventTypeEnabled:(TPI_ChatFilterEventType)eventType;
- (BOOL)isCommandEnabled:(NSString *)command;

- (nullable instancetype)initWithContentsOfPath:(NSString *)path;
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url;

- (BOOL)writeToPath:(NSString *)path;
- (BOOL)writeToURL:(NSURL *)url;
@end

#pragma mark -

@interface TPI_ChatFilterMutable : TPI_ChatFilter
@property (nonatomic, assign, readwrite) BOOL filterIgnoreContent;
@property (nonatomic, assign, readwrite) BOOL filterIgnoreOperators;
@property (nonatomic, assign, readwrite) BOOL filterLogMatch;
@property (nonatomic, assign, readwrite) BOOL filterLimitedToMyself;
@property (nonatomic, assign, readwrite) TPI_ChatFilterEventType filterEvents;
@property (nonatomic, assign, readwrite) TPI_ChatFilterLimitToValue filterLimitedToValue;
@property (nonatomic, assign, readwrite) TPI_ChatFilterAgeComparator filterAgeComparator;
@property (nonatomic, assign, readwrite) NSUInteger filterAgeLimit;
@property (nonatomic, assign, readwrite) NSUInteger filterActionFloodControlInterval;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *filterLimitedToChannelsIDs;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *filterLimitedToClientsIDs;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *filterEventsNumerics;
@property (nonatomic, copy, readwrite) NSString *filterAction;
@property (nonatomic, copy, readwrite) NSString *filterForwardToDestination;
@property (nonatomic, copy, readwrite) NSString *filterMatch;
@property (nonatomic, copy, readwrite) NSString *filterNotes;
@property (nonatomic, copy, readwrite) NSString *filterSenderMatch;
@property (nonatomic, copy, readwrite) NSString *filterTitle;
@end

NS_ASSUME_NONNULL_END
