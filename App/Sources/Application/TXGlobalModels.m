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

#import <time.h>

#import "TLOLocalization.h"
#import "TXGlobalModels.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Time

NSString * _Nullable TXFormattedTimestamp(NSDate *date, NSString *format)
{
	NSCParameterAssert(date != nil);
	NSCParameterAssert(format != nil);

	time_t global = (time_t)date.timeIntervalSince1970;

	const size_t outputBufferSize = 256;

	char outputBuffer[(outputBufferSize + 1)];

	struct tm *localTime = localtime(&global);

	if (strftime(outputBuffer, outputBufferSize, format.UTF8String, localTime) == 0) {
		return nil;
	}

	return @(outputBuffer);
}

NSString * _Nullable TXHumanReadableTimeInterval(NSTimeInterval dateInterval, BOOL shortValue, NSCalendarUnit orderMatrix)
{
	/* Default what we will return */
	if (orderMatrix == 0) {
		orderMatrix = (NSCalendarUnitYear			|
					   NSCalendarUnitMonth			|
					   NSCalendarUnitDay			|
					   NSCalendarUnitHour			|
					   NSCalendarUnitMinute			|
					   NSCalendarUnitSecond);
	}

	/* Convert calendar units to a text rep */
	NSMutableArray<NSNumber *> *units = [NSMutableArray arrayWithCapacity:6];

	if (orderMatrix & NSCalendarUnitYear) {
		[units addObject:@(NSCalendarUnitYear)];
	}

	if (orderMatrix & NSCalendarUnitMonth) {
		[units addObject:@(NSCalendarUnitMonth)];
	}

	if (orderMatrix & NSCalendarUnitDay) {
		[units addObject:@(NSCalendarUnitDay)];
	}

	if (orderMatrix & NSCalendarUnitHour) {
		[units addObject:@(NSCalendarUnitHour)];
	}

	if (orderMatrix & NSCalendarUnitMinute) {
		[units addObject:@(NSCalendarUnitMinute)];
	}

	if (orderMatrix & NSCalendarUnitSecond) {
		[units addObject:@(NSCalendarUnitSecond)];
	}

	/* Build compare information */
	NSCalendar *systemCalendar = [NSCalendar currentCalendar];

	NSDate *date1 = [NSDate date];

	NSDate *date2 = [NSDate dateWithTimeIntervalSinceNow:dateInterval];

	/* Perform comparison */
	NSDateComponents *breakdownInfo = [systemCalendar components:orderMatrix fromDate:date1 toDate:date2 options:0];

	if (breakdownInfo == nil) {
		return nil;
	}

	NSMutableString *returnResult = nil;

	for (NSNumber *unit in units) {
		NSInteger unitValue = [breakdownInfo valueForComponent:unit.unsignedIntegerValue];

		/* If results isn't zero, we show it */
		if (unitValue == 0) {
			continue;
		}

		if (unitValue < 0) {
			unitValue *= (-1);
		}

		NSString *languageKey = nil;

		if (unitValue == 1) { // plurals
			languageKey = [NSString stringWithFormat:@"fko-64-%@", unit];
		} else {
			languageKey = [NSString stringWithFormat:@"eoq-pr-%@", unit];
		}

		/* shortValue returns only the first time component */
		if (shortValue) {
			return [NSString stringWithFormat:@"%ld %@", unitValue, TXTLS(languageKey)];
		}

		if (returnResult == nil) {
			returnResult = [NSMutableString string];
		}

		if (unit == units.lastObject) {
			[returnResult appendFormat:@"%ld %@", unitValue, TXTLS(languageKey)];
		} else {
			[returnResult appendFormat:@"%ld %@, ", unitValue, TXTLS(languageKey)];
		}
	}

	if (returnResult.length > 0) {
		return [returnResult copy];
	}

	/* Return "0 seconds" when there are no results. */
	return [NSString stringWithFormat:@"0 %@", TXTLS(@"BasicLanguage[eoq-pr-128]")];
}

NSString * _Nullable TXFormatDateLongStyle(id dateObject, BOOL relativeOutput)
{
	return TXFormatDate(dateObject, NSDateFormatterLongStyle, NSDateFormatterLongStyle, relativeOutput);
}

NSString * _Nullable TXFormatDate(id dateObject, NSDateFormatterStyle dateStyle, NSDateFormatterStyle timeStyle, BOOL relativeOutput)
{
	NSCParameterAssert(dateObject != nil);

	NSDateFormatter *dateFormatter = [NSDateFormatter new];

	dateFormatter.doesRelativeDateFormatting = relativeOutput;

	dateFormatter.lenient = YES;

	dateFormatter.dateStyle = dateStyle;
	dateFormatter.timeStyle = timeStyle;

	NSString *resultString = nil;

	if ([dateObject isKindOfClass:[NSString class]]) {
		resultString = [dateFormatter stringForObjectValue:dateObject];
	} else if ([dateObject isKindOfClass:[NSDate class]]) {
		resultString = [dateFormatter stringFromDate:dateObject];
	}

	return resultString;
}

NSDateFormatter *TXSharedISOStandardDateFormatter(void)
{
	static NSDateFormatter *_isoStandardDateFormatter = nil;

	if (_isoStandardDateFormatter == nil) {
		NSDateFormatter *dateFormatter = [NSDateFormatter new];

		dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];

		dateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];

		dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"; //2011-10-19T16:40:51.620Z

		_isoStandardDateFormatter = dateFormatter;
	}

	return _isoStandardDateFormatter;
}

#pragma mark -
#pragma mark Misc

NSUInteger TXRandomNumber(u_int32_t maximum)
{
	return arc4random_uniform(maximum);
}

NSString *TXFormattedNumber(NSInteger number)
{
	return [NSNumberFormatter localizedStringFromNumber:@(number) numberStyle:NSNumberFormatterDecimalStyle];
}

NSComparator NSDefaultComparator = ^(id object1, id object2)
{
	return [object1 compare:object2];
};

NS_ASSUME_NONNULL_END
