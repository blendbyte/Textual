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


#import "NSObjectHelperPrivate.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "IRCChannelUser.h"
#import "IRCCommandIndex.h"
#import "IRCISupportInfo.h"
#import "IRCUser.h"
#import "THOPluginManagerPrivate.h"
#import "TPCApplicationInfo.h"
#import "TPCPreferencesLocal.h"
#import "TVCMainWindow.h"
#import "TVCMainWindowTextView.h"
#import "TLONicknameCompletionStatusPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TLONicknameCompletionStatus ()
@property (nonatomic, weak) TVCMainWindow *window;
@property (nonatomic, copy, nullable) NSString *completedValue;
@property (nonatomic, copy, nullable) NSString *completedValueCompletionSuffix;
@property (nonatomic, copy, nullable) NSString *currentTextViewStringValue;
@property (nonatomic, copy, nullable) NSString *cachedSearchPattern;
@property (nonatomic, copy, nullable) NSString *cachedSearchPatternPrefixCharacter;
@property (nonatomic, copy, nullable) NSString *cachedCompletionSuffix;
@property (nonatomic, assign) NSRange selectionRangeAfterLastCompletion;
@property (nonatomic, assign) NSRange rangeOfTextSelection;
@property (nonatomic, assign) NSRange rangeOfSearchPattern;
@property (nonatomic, assign) NSRange rangeOfCompletionSuffix;
@property (nonatomic, assign) NSInteger selectionIndexOfLastCompletion;
@property (nonatomic, assign) BOOL completionIsMovingForward;
@property (nonatomic, assign) BOOL isCompletingChannelName;
@property (nonatomic, assign) BOOL isCompletingCommand;
@property (nonatomic, assign) BOOL isCompletingNickname;
@property (nonatomic, assign) BOOL searchPatternIsAtStart;
@property (nonatomic, assign) BOOL searchPatternIsAtEnd;
@property (nonatomic, assign) BOOL completionCacheIsConstructed;
@end

@implementation TLONicknameCompletionStatus

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithWindow:(TVCMainWindow *)mainWindow
{
	if ((self = [super init])) {
		self.window = mainWindow;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[self clear];
}

- (void)completeNickname:(BOOL)movingForward
{
	[self performCompletion:movingForward];
}

#pragma mark -
#pragma mark Completion Management

- (void)performCompletion:(BOOL)movingForward
{
	BOOL canContinuePreviousScan = YES;

	TVCMainWindowTextView *textView = self.window.inputTextField;

	/* Focus text field so if the insertion point we not already
	 in it, its there now so we can get selected range. */
	[textView focus];

	/* Get the selected range. Length may be zero in which
	 case the insertion point is just sitting idle. */
	NSRange selectedRange = [textView selectedRange];

	if (selectedRange.location == NSNotFound) {
		return;
	}

	/* Perform various comparisons to determine whether the
	 cache has to be rebuilt. */
	if ( self.selectionIndexOfLastCompletion == NSNotFound ||
		self.selectionRangeAfterLastCompletion.location == NSNotFound ||
		(self.rangeOfTextSelection.location == NSNotFound &&
		 self.rangeOfSearchPattern.location == 0 && self.rangeOfSearchPattern.length == 0) ||
		selectedRange.location != self.selectionRangeAfterLastCompletion.location ||
		selectedRange.length != self.selectionRangeAfterLastCompletion.length)
	{
		canContinuePreviousScan = NO;
	}

	NSString *currentTextViewStringValue = textView.string;

	if (self.currentTextViewStringValue.length == 0) {
		canContinuePreviousScan = NO;
	} else if ([self.currentTextViewStringValue isEqualToString:currentTextViewStringValue] == NO) {
		canContinuePreviousScan = NO;
	}

	self.currentTextViewStringValue = currentTextViewStringValue;

	self.completionIsMovingForward = movingForward;

	/* Move onto stage two of the completion */
	if (canContinuePreviousScan == NO) {
		self.rangeOfTextSelection = selectedRange;

		[self constructCache];
	}

	if (self.completionCacheIsConstructed) {
		if ([self performCompletion_step1] == NO)
			return;

		[self performCompletion_step2];
		[self performCompletion_step3];
		[self performCompletion_step4];
	}
}

- (BOOL)performCompletion_step1
{
	/* Only blindly complete nicknames */
	BOOL searchPatternIsEmpty = (self.cachedSearchPattern.length == 0);

	if (searchPatternIsEmpty && self.isCompletingNickname == NO) {
		return NO;
	}

	/* Define our choices for the completion. The choicesUppercase array
	 holds all the case-sensitive representations of the completions while
	 the choicesLowercase array holds each completion as a lowercase string.
	 The lowercase string is compared against the lowercase backward cut. If
	 they match, then the actual case is requested from choicesUppercase. */
	NSMutableArray *choicesUppercase = [NSMutableArray array];
	NSMutableArray *choicesLowercase = [NSMutableArray array];

	if (self.isCompletingCommand)
	{
		for (NSString *command in [IRCCommandIndex localCommandList]) {
			[choicesUppercase addObject:command.lowercaseString];
		}

		[choicesUppercase addObjectsFromArray:sharedPluginManager().supportedUserInputCommands];
		[choicesUppercase addObjectsFromArray:sharedPluginManager().supportedAppleScriptCommands];

		/* complete commands in alphabetical order */
		[choicesUppercase sortUsingSelector:@selector(localizedCompare:)];
	}
	else if (self.isCompletingChannelName)
	{
		IRCClient *client = self.window.selectedClient;
		IRCChannel *channel = self.window.selectedChannel;

		if (channel) {
			[choicesUppercase addObject:channel.name];
		}

		for (IRCChannel *cc in client.channelList) {
			if (cc == channel) {
				continue;
			}

			[choicesUppercase addObject:cc.name];
		}
	}
	else if (self.isCompletingNickname)
	{
		/* Complete the entire user list. */
		IRCClient *client = self.window.selectedClient;
		IRCChannel *channel = self.window.selectedChannel;

		if (channel == nil) {
			return NO; // Umm, where to get channels?...
		}

		/* When the search pattern is empty, then special consideration is taken for how
		 the human brain may expect the result. When there is a search pattern, the list
		 is sorted using member weight, but that information is not really relevant when
		 you are targeting all. When the search pattern is empty, the member list is sorted
		 alphabetically and only the single most highly weighted user is placed at the top
		 of the list and that only occurs if there is a user with a different weight. */
		__block IRCChannelUser *userWithGreatestWeight = nil;

		__block BOOL noUserHadGreaterWeightThanOriginal = YES;

		NSArray *memberList = nil;

		if (searchPatternIsEmpty == NO) {
			memberList = [channel.memberList sortedArrayUsingSelector:@selector(compareUsingWeights:)];

			userWithGreatestWeight = memberList.firstObject;
		} else {
			memberList = [channel.memberList sortedArrayUsingComparator:^NSComparisonResult(IRCChannelUser *user1, IRCChannelUser *user2) {
				if (userWithGreatestWeight == nil) {
					userWithGreatestWeight = user1;
				}

				if (userWithGreatestWeight.totalWeight < user2.totalWeight) {
					userWithGreatestWeight = user2;

					noUserHadGreaterWeightThanOriginal = NO;
				}

				return [user1.user.nickname caseInsensitiveCompare:user2.user.nickname];
			}];
		}

		/* Add nicknames to list */
		NSCharacterSet *nonAlphaCharacters = [NSCharacterSet characterSetWithCharactersInString:@"^[]-_`{}\\"];

		void (^addNickname)(NSString *, BOOL) = ^(NSString *nickname, BOOL addTrimmedVariant)
		{
			/* Add unmodified version of nickname */
			[choicesUppercase addObject:nickname];

			[choicesLowercase addObject:nickname.lowercaseString];

			/* Add choice after it has been trimmed of special characters as well. */
			if (addTrimmedVariant == NO)
				return;

			NSString *nicknameTrimmed = [self trimNickname:nickname usingCharacterSet:nonAlphaCharacters];

			if (nicknameTrimmed.length > 0 && [nickname isNotEqualTo:nicknameTrimmed]) {
				NSString *nicknameTrimmedLowercase = nicknameTrimmed.lowercaseString;

				if ([choicesLowercase containsObject:nicknameTrimmedLowercase] == NO) {
					[choicesUppercase addObject:nickname];

					[choicesLowercase addObject:nicknameTrimmedLowercase];
				}
			}
		};

		BOOL includeTrimmedNicknames = (searchPatternIsEmpty == NO);

		if (noUserHadGreaterWeightThanOriginal == NO) {
			addNickname(userWithGreatestWeight.user.nickname, includeTrimmedNicknames);
		}

		for (IRCChannelUser *m in memberList) {
			if (noUserHadGreaterWeightThanOriginal == NO && m == userWithGreatestWeight) {
				continue;
			}

			addNickname(m.user.nickname, includeTrimmedNicknames);
		}

		/* Complete static names, including application name. */
		addNickname(@"NickServ", NO);
		addNickname(@"RootServ", NO);
		addNickname(@"OperServ", NO);
		addNickname(@"HostServ", NO);
		addNickname(@"ChanServ", NO);
		addNickname(@"MemoServ", NO);

		addNickname([TPCApplicationInfo applicationNameWithoutVersion], NO);

		/* Complete network name. */
		NSString *networkName = client.supportInfo.networkName;

		if (networkName) {
			addNickname(networkName, NO);
		}
	}

	/* Quick method for replacing the value of each array
	 object based on a provided selector. */
	if (self.isCompletingChannelName || self.isCompletingCommand) {
		[choicesLowercase addObjectsFromArray:choicesUppercase];

		[choicesLowercase performSelectorOnObjectValueAndReplace:@selector(lowercaseString)];
	}

	/* Now that we know the possible matches, we find all values
	 that has our search pattern as its prefix. */
	NSMutableArray *choicesLowercaseMatched = nil;
	NSMutableArray *choicesUppercaseMatched = nil;

	if (searchPatternIsEmpty) {
		choicesLowercaseMatched = choicesLowercase;
		choicesUppercaseMatched = choicesUppercase;
	}
	else
	{
		choicesUppercaseMatched = [NSMutableArray array];
		choicesLowercaseMatched = [NSMutableArray array];

		NSString *searchPatternLowercase = self.cachedSearchPattern.lowercaseString;

		[choicesLowercase enumerateObjectsUsingBlock:^(NSString *choice, NSUInteger choiceIndex, BOOL *stop) {
			if ([choice hasPrefix:searchPatternLowercase]) {
				[choicesLowercaseMatched addObject:choice];

				[choicesUppercaseMatched addObject:choicesUppercase[choiceIndex]];
			}
		}];
	}

	NSUInteger choicesLowercaseMatchedCount = choicesLowercaseMatched.count;

	if (choicesLowercaseMatchedCount == 0) {
		return NO;
	}

	/* Now that we know the choices that are actually available to the
	 string being completed; we can filter through each going backwards
	 or forward depending on the call to this method. */
	NSString *valueMatchedBySearchPattern = nil;

	NSUInteger indexOfMatchedValue = self.selectionIndexOfLastCompletion;

	if (choicesLowercaseMatchedCount <= indexOfMatchedValue || indexOfMatchedValue == NSNotFound) {
		valueMatchedBySearchPattern = choicesUppercaseMatched[0];

		self.selectionIndexOfLastCompletion = 0;
	} else {
		if (self.completionIsMovingForward) {
			indexOfMatchedValue += 1;

			if (choicesLowercaseMatchedCount <= indexOfMatchedValue) {
				indexOfMatchedValue = 0;
			}
		} else {
			if (indexOfMatchedValue == 0) {
				indexOfMatchedValue = (choicesLowercaseMatchedCount - 1);
			} else {
				indexOfMatchedValue -= 1;
			}
		}

		valueMatchedBySearchPattern = choicesUppercaseMatched[indexOfMatchedValue];

		self.selectionIndexOfLastCompletion = indexOfMatchedValue;
	}

	if (self.cachedSearchPatternPrefixCharacter.length > 0) {
		valueMatchedBySearchPattern = [self.cachedSearchPatternPrefixCharacter stringByAppendingString:valueMatchedBySearchPattern];
	}

	self.completedValue = valueMatchedBySearchPattern;

	return YES;
}

- (void)performCompletion_step2
{
	/* Add the completed string to the spell checker so that a nickname
	 wont show up as spelled incorrectly. The spell checker is cleared
	 of these ignores between channel changes. */
	TVCMainWindowTextView *textView = self.window.inputTextField;

	[RZSpellChecker() ignoreWord:self.completedValue inSpellDocumentWithTag:textView.spellCheckerDocumentTag];
}

- (void)performCompletion_step3
{
	NSString *newCompletionSuffix = nil;

	BOOL whitespaceAlreadyInPosition = NO;
	BOOL whitespaceContainedByCachedSuffix = NO;

	if ([self.cachedCompletionSuffix hasSuffixWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]]) {
		whitespaceAlreadyInPosition = YES;
		whitespaceContainedByCachedSuffix = YES;
	}

	if (whitespaceAlreadyInPosition == NO) {
		NSInteger maximumCompletionSuffixEndPoint = (self.currentTextViewStringValue.length - 1);

		NSInteger nextCharacterInRange = NSMaxRange(self.rangeOfCompletionSuffix);

		if (nextCharacterInRange < maximumCompletionSuffixEndPoint) {
			UniChar nextChar = [self.currentTextViewStringValue characterAtIndex:nextCharacterInRange];

			if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:nextChar]) {
				whitespaceAlreadyInPosition = YES;
			}
		}
	}

	if (self.isCompletingNickname && self.searchPatternIsAtStart)
	{
		NSString *userCompletionSuffix = [TPCPreferences tabCompletionSuffix];

		NSInteger userCompletionSuffixLength = userCompletionSuffix.length;

		if (whitespaceAlreadyInPosition) {
			if ([userCompletionSuffix hasSuffixWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]]) {
				if (whitespaceContainedByCachedSuffix == NO && userCompletionSuffixLength > 1) {
					newCompletionSuffix = [userCompletionSuffix substringToIndex:(userCompletionSuffixLength - 1)];
				} else if (whitespaceContainedByCachedSuffix) {
					newCompletionSuffix = userCompletionSuffix;
				}
			} else {
				newCompletionSuffix = userCompletionSuffix;
			}
		} else {
			if (userCompletionSuffixLength == 0) {
				BOOL doNotAppendWhitespace = [TPCPreferences tabCompletionDoNotAppendWhitespace];

				if (doNotAppendWhitespace == NO) {
					newCompletionSuffix = @" ";
				}
			} else {
				newCompletionSuffix = userCompletionSuffix;
			}
		}
	}
	else
	{
		if (whitespaceAlreadyInPosition == NO) {
			newCompletionSuffix = @" ";
		}
	}

	self.completedValueCompletionSuffix = newCompletionSuffix;
}

- (void)performCompletion_step4
{
	/* Calculate range of the section that will be replaced. */
	NSRange completeReplacementRange;

	completeReplacementRange.location = self.rangeOfSearchPattern.location;
	completeReplacementRange.length = (self.rangeOfSearchPattern.length + self.rangeOfCompletionSuffix.length);

	/* Create the replacement value */
	NSString *combinedCompletedValue = nil;

	if (self.completedValueCompletionSuffix) {
		combinedCompletedValue = [self.completedValue stringByAppendingString:self.completedValueCompletionSuffix];
	} else {
		combinedCompletedValue =  self.completedValue;
	}

	/* Perform replacement of selection with the new value */
	TVCMainWindowTextView *textView = self.window.inputTextField;

	if ([textView shouldChangeTextInRange:completeReplacementRange replacementString:combinedCompletedValue]) {
		[textView replaceCharactersInRange:completeReplacementRange withString:combinedCompletedValue];

		[textView didChangeText];
	}

	/* Modify range to account for new length */
	completeReplacementRange.length = combinedCompletedValue.length;

	/* Scroll new selection into view and select it */
	NSRange newSelectionRange = NSMakeRange((completeReplacementRange.location + completeReplacementRange.length), 0);

	[textView scrollRangeToVisible:newSelectionRange];

	[textView setSelectedRange:newSelectionRange];

	self.selectionRangeAfterLastCompletion = newSelectionRange;

	/* Calculate range for new suffix */
	NSRange completeCompletionSuffixRange;

	completeCompletionSuffixRange.location = (self.rangeOfSearchPattern.location + self.rangeOfSearchPattern.length);
	completeCompletionSuffixRange.length = (completeReplacementRange.length - self.rangeOfSearchPattern.length);

	self.rangeOfCompletionSuffix = completeCompletionSuffixRange;

	/* Finish operation by updating cache */
	self.currentTextViewStringValue = textView.string;

	self.completedValue = nil;
	self.completedValueCompletionSuffix = nil;
}

#pragma mark -
#pragma mark Utilities

- (NSUInteger)textViewMaximumRange
{
	TVCMainWindowTextView *textView = self.window.inputTextField;

	return textView.stringLength;
}

- (nullable NSString *)trimNickname:(NSString *)nickname usingCharacterSet:(NSCharacterSet *)charset
{
	for (NSUInteger i = 0; i < nickname.length; i++) {
		UniChar c = [nickname characterAtIndex:i];

		if ([charset characterIsMember:c]) {
			continue;
		} else {
			return [nickname substringFromIndex:i];
		}
	}

	return nil;
}

#pragma mark -
#pragma mark Cache Construction

- (void)constructCache
{
	[self clearCache];

	if ([self constructCachedSearchPattern] == NO)
		return;

	if ([self constructCachedSearchPatternPrefixCharacter] == NO)
		return;

	if ([self constructCachedCompletionSuffix] == NO)
		return;

	self.completionCacheIsConstructed = YES;
}

- (BOOL)constructCachedSearchPattern
{
	/* Given string and a starting point, we move backwards
	 from that starting point until we reach a comma (,) or
	 a localized space character. */
	NSRange selectedRange = self.rangeOfTextSelection;

	NSInteger searchPatternStartingPoint = 0;

	if (selectedRange.location > 0) {
		for (NSInteger i = (selectedRange.location - 1); i >= 0; i--) {
			UniChar cc = [self.currentTextViewStringValue characterAtIndex:i];

			if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:cc] || cc == '\x02c') {
				searchPatternStartingPoint = (i + 1); // Starting point is plus one to
													  // position the starting index as
													  // character after separator

				break;
			}
		}
	}

	/* Now that we know the starting point, we can extract the search string. */
	NSInteger searchPatternLength = (selectedRange.location - searchPatternStartingPoint);

	self.rangeOfSearchPattern = NSMakeRange(searchPatternStartingPoint, searchPatternLength);

	if (searchPatternLength == 0) {
		self.cachedSearchPattern = @"";
	} else {
		self.cachedSearchPattern = [self.currentTextViewStringValue substringWithRange:self.rangeOfSearchPattern];
	}

	self.searchPatternIsAtStart = (searchPatternStartingPoint == 0);

	return YES;
}

- (BOOL)constructCachedSearchPatternPrefixCharacter
{
	UniChar searchPatternFirstCharacter = 0; // null

	if (self.cachedSearchPattern.length > 0) {
		searchPatternFirstCharacter = [self.cachedSearchPattern characterAtIndex:0];
	}

	if (self.searchPatternIsAtStart && searchPatternFirstCharacter == '\x02f')
	{
		self.isCompletingCommand = YES;

		self.cachedSearchPattern = [self.cachedSearchPattern substringFromIndex:1];
		self.cachedSearchPatternPrefixCharacter = @"\x02f";
	}
	else if (searchPatternFirstCharacter == '\x040')
	{
		self.isCompletingNickname = YES;

		self.cachedSearchPattern = [self.cachedSearchPattern substringFromIndex:1];
		self.cachedSearchPatternPrefixCharacter = @"\x040";
	}
	else if (searchPatternFirstCharacter == '\x023')
	{
		self.isCompletingChannelName = YES;
	}
	else
	{
		self.isCompletingNickname = YES;
	}

	if (self.cachedSearchPattern == nil) {
		return NO;
	} else {
		return YES;
	}
}

- (BOOL)constructCachedCompletionSuffix
{
	/* Given string and a starting point, we move forward until the
	 user's configured completion prefix is found. If its not found,
	 then we look for a localized space, colon (:), or comma (,) */
	NSUInteger totalTextLength = (self.currentTextViewStringValue).length;

	NSRange selectedRange = self.rangeOfTextSelection;

	NSUInteger selectedRangeStartPoint = selectedRange.location;

	NSRange completionSuffixRange;

	/* If the user has a selection in the text field, then we
	 will be happy to use that as our completion suffix. */
	if (selectedRange.length > 0) {
		completionSuffixRange = selectedRange;

		goto complete_operation;
	} else {
		completionSuffixRange = NSMakeRange(selectedRangeStartPoint, 0);
	}

	/* Create search pattern for the user configured completion suffix and
	 search for it. If its found within range, we return that. */
	/* If the range from start of our search to the beginning of the user's
	 completion suffix contains a whitespace or exceeds 30 characters, then
	 we do not use that range. */
	if (self.isCompletingNickname) {
		NSString *userCompletionSuffix = [TPCPreferences tabCompletionSuffix];

		if (userCompletionSuffix.length > 0) {
			NSRange completionSearchRange = NSMakeRange(selectedRange.location,
														(totalTextLength - selectedRange.location));

			NSRange completionRangePosition = [self.currentTextViewStringValue rangeOfString:userCompletionSuffix options:0 range:completionSearchRange];

			if (NSRangeIsValid(completionRangePosition) && completionRangePosition.length < 30) {
				NSRange whitespaceSearchRange = NSMakeRange(selectedRange.location,
															completionRangePosition.location - selectedRange.location);

				NSRange whitespaceSearchResult =
				[self.currentTextViewStringValue rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet] options:0 range:whitespaceSearchRange];

				if (whitespaceSearchResult.location == NSNotFound) {
					completionSuffixRange.length = (NSMaxRange(completionRangePosition) - selectedRangeStartPoint);

					goto complete_operation;
				}
			}
		}
	}

	/* Search for interesting characters. */
	BOOL cutNextWord = [TPCPreferences tabCompletionCutForwardToFirstWhitespace];

	if (cutNextWord) {
		NSInteger maximumCompletionSuffixEndPoint = (totalTextLength - 1);

		for (NSInteger i = selectedRangeStartPoint; i <= maximumCompletionSuffixEndPoint; i++) {
			UniChar cc = [self.currentTextViewStringValue characterAtIndex:i];

			if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:cc]
				|| cc == '\x03a'
				|| cc == '\x02c')
			{
				completionSuffixRange.length = (i - selectedRangeStartPoint);

				goto complete_operation;
			}
		}

		// Fallback when we never found a character
		completionSuffixRange.length = (totalTextLength - selectedRangeStartPoint);
	}

	/* Cache relevant information */
complete_operation:
	self.rangeOfCompletionSuffix = completionSuffixRange;

	if (self.rangeOfCompletionSuffix.length == 0) {
		self.cachedCompletionSuffix = @"";
	} else {
		self.cachedCompletionSuffix = [self.currentTextViewStringValue substringWithRange:self.rangeOfCompletionSuffix];
	}

	self.searchPatternIsAtEnd = (NSMaxRange(self.rangeOfCompletionSuffix) == totalTextLength);

	return YES;
}

#pragma mark -
#pragma mark Cache Management

- (void)clearCache
{
	self.completedValue = nil;
	self.completedValueCompletionSuffix = nil;

	self.cachedSearchPattern = nil;
	self.cachedSearchPatternPrefixCharacter = nil;

	self.selectionIndexOfLastCompletion = NSNotFound;

	self.cachedCompletionSuffix = nil;

	self.rangeOfCompletionSuffix = NSMakeRange(0, 0);
	self.rangeOfSearchPattern = NSMakeRange(0, 0);

	self.completionCacheIsConstructed = NO;

	self.isCompletingChannelName = NO;
	self.isCompletingCommand = NO;
	self.isCompletingNickname = NO;

	self.searchPatternIsAtEnd = NO;
	self.searchPatternIsAtStart = NO;
}

- (void)clear
{
	[self clearCache];

	self.currentTextViewStringValue = nil;

	self.rangeOfTextSelection = NSEmptyRange();

	self.selectionRangeAfterLastCompletion = NSEmptyRange();

	self.completionIsMovingForward = NO;
}

@end

NS_ASSUME_NONNULL_END
