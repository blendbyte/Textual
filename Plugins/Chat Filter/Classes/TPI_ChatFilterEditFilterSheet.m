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

#import "TPI_ChatFilterEditFilterSheet.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TPI_ChatFilterEditFilterSheetSelection)
{
	TPI_ChatFilterEditFilterSheetSelectionGeneral = 0,
	TPI_ChatFilterEditFilterSheetSelectionChannels = 1,
	TPI_ChatFilterEditFilterSheetSelectionEvents = 2,
	TPI_ChatFilterEditFilterSheetSelectionSender = 3,
	TPI_ChatFilterEditFilterSheetSelectionNotes = 4,
	TPI_ChatFilterEditFilterSheetSelectionAdvanced = 5
};

@interface TPI_ChatFilterEditFilterSheet () <NSTokenFieldDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate>
@property (nonatomic, strong) TPI_ChatFilterMutable *filter;
@property (nonatomic, weak) IBOutlet NSTabView *contentViewTabView;
@property (nonatomic, weak) IBOutlet NSTextField *filterAgeLimitTextField;
@property (nonatomic, weak) IBOutlet NSTextField *filterMatchTextField;
@property (nonatomic, weak) IBOutlet NSTextField *filterSenderMatchTextField;
@property (nonatomic, weak) IBOutlet NSTextField *filterTitleTextField;
@property (nonatomic, weak) IBOutlet NSTextField *filterNotesTextField;
@property (nonatomic, weak) IBOutlet NSTextField *filterActionFloodControlIntervalTextField;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *filterEventNumericTextField;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *filterForwardToDestinationTextField;
@property (nonatomic, weak) IBOutlet TVCAutoExpandingTokenField *filterActionTokenField;
@property (nonatomic, weak) IBOutlet NSTokenField *filterActionTokenChannelName;
@property (nonatomic, weak) IBOutlet NSTokenField *filterActionTokenLocalNickname;
@property (nonatomic, weak) IBOutlet NSTokenField *filterActionTokenNetworkName;
@property (nonatomic, weak) IBOutlet NSTokenField *filterActionTokenOriginalMessage;
@property (nonatomic, weak) IBOutlet NSTokenField *filterActionTokenSenderAddress;
@property (nonatomic, weak) IBOutlet NSTokenField *filterActionTokenSenderHostmask;
@property (nonatomic, weak) IBOutlet NSTokenField *filterActionTokenSenderNickname;
@property (nonatomic, weak) IBOutlet NSTokenField *filterActionTokenSenderUsername;
@property (nonatomic, weak) IBOutlet NSTokenField *filterActionTokenServerAddress;
@property (nonatomic, weak) IBOutlet NSView *filterLimitedToHostView;
@property (nonatomic, weak) IBOutlet NSView *filterLimitedToSelectionHostView;
@property (nonatomic, weak) IBOutlet NSPopUpButton *filterAgeLimitComparatorButton;
@property (nonatomic, weak) IBOutlet NSButton *filterLimitToNoLimitButton;
@property (nonatomic, weak) IBOutlet NSButton *filterLimitToOnlyChannelsButton;
@property (nonatomic, weak) IBOutlet NSButton *filterLimitToOnlyPrivateMessagesButton;
@property (nonatomic, weak) IBOutlet NSButton *filterLimitToSpecificItemsButton;
@property (nonatomic, weak) IBOutlet NSButton *filterIgnoreContentCheck;
@property (nonatomic, weak) IBOutlet NSButton *filterIgnoreOperatorsCheck;
@property (nonatomic, weak) IBOutlet NSButton *filterLogMatchCheck;
@property (nonatomic, weak) IBOutlet NSButton *filterEventPlainTextMessageCheck;
@property (nonatomic, weak) IBOutlet NSButton *filterEventActionMessageCheck;
@property (nonatomic, weak) IBOutlet NSButton *filterEventNoticeMessageCheck;
@property (nonatomic, weak) IBOutlet NSButton *filterEventUserJoinedChannelCheck;
@property (nonatomic, weak) IBOutlet NSButton *filterEventUserLeftChannelCheck;
@property (nonatomic, weak) IBOutlet NSButton *filterEventUserKickedFromChannelCheck;
@property (nonatomic, weak) IBOutlet NSButton *filterEventUserDisconnectedCheck;
@property (nonatomic, weak) IBOutlet NSButton *filterEventUserChangedNicknameCheck;
@property (nonatomic, weak) IBOutlet NSButton *filterEventChannelTopicReceivedCheck;
@property (nonatomic, weak) IBOutlet NSButton *filterEventChannelTopicChangedCheck;
@property (nonatomic, weak) IBOutlet NSButton *filterEventChannelModeReceivedCheck;
@property (nonatomic, weak) IBOutlet NSButton *filterEventChannelModeChangedCheck;
@property (nonatomic, weak) IBOutlet NSButton *filterLimitedToMyselfCheck;
@property (nonatomic, assign) BOOL filterIgnoreOperatorsCheckEnabled;
@property (nonatomic, copy) NSArray<NSString *> *filterActionAutoCompletedTokens;
@property (nonatomic, strong) IBOutlet TVCChannelSelectionViewController *filterLimitToSelectionOutlineView;

- (IBAction)viewFilterMatchHelpText:(nullable id)sender;
- (IBAction)viewFilterActionHelpText:(nullable id)sender;
- (IBAction)viewFilterSenderMatchHelpText:(nullable id)sender;
- (IBAction)viewFilterForwardToDestinationHelpText:(nullable id)sender;

- (IBAction)filterLimitedToMatrixChanged:(nullable id)sender;
- (IBAction)filterIgnoreContentCheckChanged:(nullable id)sender;
- (IBAction)filterEventTypeChanged:(nullable id)sender;
- (IBAction)filterLimitedToMyselfChanged:(nullable id)sender;
@end

#pragma mark -

@interface TPI_ChatFilterFilterActionToken : NSObject
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy, readonly, nullable) NSString *tokenTitle;

+ (TPI_ChatFilterFilterActionToken *)tokenWithToken:(NSString *)token;
+ (nullable TPI_ChatFilterFilterActionToken *)tokenWithTokenTitle:(NSString *)tokenTitle;

+ (NSArray *)tokens;
+ (NSArray *)tokenTitles;

+ (nullable NSString *)titleForToken:(NSString *)token;

+ (BOOL)isToken:(NSString *)token;
@end

#pragma mark -

@implementation TPI_ChatFilterEditFilterSheet

#pragma mark -
#pragma mark Primary Sheet Structure

- (instancetype)initWithFilter:(nullable TPI_ChatFilter *)filter
{
	if ((self = [super initWithWindow:nil])) {
		if (filter == nil) {
			self.filter = [TPI_ChatFilterMutable new];
		} else {
			self.filter = [filter mutableCopy];
		}

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[TPIBundleFromClass() loadNibNamed:@"TPI_ChatFilterEditFilterSheet" owner:self topLevelObjects:nil];

	[self populateTokenFieldStringValues];

	[self setupTextFieldRules];

	[self loadFilter];

	[self updateEnabledStateOfSenderMatch];
	[self updateEnabledStateOfFilterEvents];
	[self updateEnableStateOfFilterActionTokenField];
	[self updateEnabledStateOfComponentsConstrainedByFilterEvents];
	[self updateFilterLimitedToMatrix];
	[self updateVisibilityOfLimitedToTableHostView];

	[self toggleOkButton];

	[self.filterLimitToSelectionOutlineView attachToView:self.filterLimitedToSelectionHostView];
}

- (void)start
{
	[self startSheet];
}

- (void)loadFilter
{
	self.filterMatchTextField.stringValue = self.filter.filterMatch;

	[self setTokens:self.filter.filterAction inTokenField:self.filterActionTokenField];

	[self.filterAgeLimitComparatorButton selectItemWithTag:self.filter.filterAgeComparator];
	self.filterAgeLimitTextField.integerValue = self.filter.filterAgeLimit;

	self.filterActionFloodControlIntervalTextField.integerValue = self.filter.filterActionFloodControlInterval;

	self.filterTitleTextField.stringValue = self.filter.filterTitle;
	self.filterNotesTextField.stringValue = self.filter.filterNotes;

	self.filterSenderMatchTextField.stringValue = self.filter.filterSenderMatch;

	self.filterForwardToDestinationTextField.stringValue = self.filter.filterForwardToDestination;

	self.filterIgnoreContentCheck.state = self.filter.filterIgnoreContent;

	self.filterLogMatchCheck.state = self.filter.filterLogMatch;

	self.filterLimitedToMyselfCheck.state = self.filter.filterLimitedToMyself;

	self.filterEventPlainTextMessageCheck.state = [self.filter isEventTypeEnabled:TPI_ChatFilterEventTypePlainTextMessage];
	self.filterEventActionMessageCheck.state = [self.filter isEventTypeEnabled:TPI_ChatFilterEventTypeActionMessage];
	self.filterEventNoticeMessageCheck.state = [self.filter isEventTypeEnabled:TPI_ChatFilterEventTypeNoticeMessage];
	self.filterEventUserJoinedChannelCheck.state = [self.filter isEventTypeEnabled:TPI_ChatFilterEventTypeUserJoinedChannel];
	self.filterEventUserLeftChannelCheck.state = [self.filter isEventTypeEnabled:TPI_ChatFilterEventTypeUserLeftChannel];
	self.filterEventUserKickedFromChannelCheck.state = [self.filter isEventTypeEnabled:TPI_ChatFilterEventTypeUserKickedFromChannel];
	self.filterEventUserDisconnectedCheck.state = [self.filter isEventTypeEnabled:TPI_ChatFilterEventTypeUserDisconnected];
	self.filterEventUserChangedNicknameCheck.state = [self.filter isEventTypeEnabled:TPI_ChatFilterEventTypeUserChangedNickname];
	self.filterEventChannelTopicReceivedCheck.state = [self.filter isEventTypeEnabled:TPI_ChatFilterEventTypeChannelTopicReceived];
	self.filterEventChannelTopicChangedCheck.state = [self.filter isEventTypeEnabled:TPI_ChatFilterEventTypeChannelTopicChanged];
	self.filterEventChannelModeReceivedCheck.state = [self.filter isEventTypeEnabled:TPI_ChatFilterEventTypeChannelModeReceived];
	self.filterEventChannelModeChangedCheck.state = [self.filter isEventTypeEnabled:TPI_ChatFilterEventTypeChannelModeChanged];

	NSArray *filterEventsNumerics = self.filter.filterEventsNumerics;

	if (filterEventsNumerics) {
		NSString *filterEventsNumericsJoined = [filterEventsNumerics componentsJoinedByString:@", "];

		self.filterEventNumericTextField.stringValue = filterEventsNumericsJoined;
	} else {
		[self.filterEventNumericTextField performValidation];
	}

	NSArray *filterLimitedToClientsIDs = self.filter.filterLimitedToClientsIDs;
	NSArray *filterLimitedToChannelsIDs = self.filter.filterLimitedToChannelsIDs;

	self.filterLimitToSelectionOutlineView.selectedClientIds = filterLimitedToClientsIDs;
	self.filterLimitToSelectionOutlineView.selectedChannelIds = filterLimitedToChannelsIDs;
}

- (void)saveFilter
{
	self.filter.filterMatch = self.filterMatchTextField.stringValue;

	NSString *filterActionStringValue = [self stringValueForTokenField:self.filterActionTokenField];

	self.filter.filterAction = filterActionStringValue;

	self.filter.filterAgeComparator = self.filterAgeLimitComparatorButton.selectedTag;

	NSInteger filterAgeLimit = self.filterAgeLimitTextField.integerValue;

	if (filterAgeLimit < 0) {
		filterAgeLimit = 0;
	}

	self.filter.filterAgeLimit = filterAgeLimit;

	NSInteger filterActionFloodControlInterval = self.filterActionFloodControlIntervalTextField.integerValue;

	if (filterActionFloodControlInterval < 0) {
		filterActionFloodControlInterval = 0;
	}

	self.filter.filterActionFloodControlInterval = filterActionFloodControlInterval;

	self.filter.filterTitle = self.filterTitleTextField.stringValue;
	self.filter.filterNotes = self.filterNotesTextField.stringValue;

	self.filter.filterSenderMatch = self.filterSenderMatchTextField.stringValue;

	self.filter.filterForwardToDestination = self.filterForwardToDestinationTextField.stringValue;

	self.filter.filterIgnoreOperators = (self.filterIgnoreOperatorsCheck.state == NSControlStateValueOn);

	self.filter.filterIgnoreContent = (self.filterIgnoreContentCheck.state == NSControlStateValueOn);

	self.filter.filterLogMatch = (self.filterLogMatchCheck.state == NSControlStateValueOn);

	self.filter.filterLimitedToMyself = (self.filterLimitedToMyselfCheck.state == NSControlStateValueOn);

	self.filter.filterEvents = [self compileFilterEvents];

	self.filter.filterEventsNumerics = [self compileFilterEventsNumericsOrReturnEmptyArray];

	self.filter.filterLimitedToClientsIDs = self.filterLimitToSelectionOutlineView.selectedClientIds;
	self.filter.filterLimitedToChannelsIDs = self.filterLimitToSelectionOutlineView.selectedChannelIds;
}

- (BOOL)filterIgnoreOperatorsCheckValue
{
	if (self.filterIgnoreOperatorsCheckEnabled == NO) {
		return NO;
	}

	return self.filter.filterIgnoreOperators;
}

- (void)setFilterIgnoreOperatorsCheckValue:(BOOL)filterIgnoreOperatorsCheckValue
{
	self.filter.filterIgnoreOperators = filterIgnoreOperatorsCheckValue;
}

- (NSArray<NSString *> *)compileFilterEventsNumericsOrReturnEmptyArray
{
	NSArray *filterEventNumerics = [self compileFilterEventsNumerics];

	if (filterEventNumerics == nil) {
		return @[];
	}

	return filterEventNumerics;
}

- (nullable NSArray<NSString *> *)compileFilterEventsNumerics
{
	NSString *numericsString = self.filterEventNumericTextField.value;

	NSArray *numerics = [numericsString componentsSeparatedByString:@","];

	NSMutableArray *filterEventsNumerics = nil; // Create later so we don't waste memory if error.

	for (__strong NSString *numeric in numerics) {
		numeric = numeric.trim;

		if (numeric.length == 0) {
			continue; // Empty segment. We can ignore.
		}

		if (numeric.numericOnly) {
			if (numeric.length > 3) {
				return nil; // Bad value, fail completely
			}

			// Convert to integer and back to remove leading zeros
			numeric = [NSString stringWithFormat:@"%ld", numeric.integerValue];
		} else if (numeric.alphabeticNumericOnly) {
			if (numeric.length > 20) {
				return nil; // Bad value, fail completely
			}

			numeric = numeric.uppercaseString;
		} else {
			return nil; // Bad value, fail completely
		}

		if (filterEventsNumerics == nil) {
			filterEventsNumerics = [NSMutableArray array];
		}

		if ([filterEventsNumerics containsObject:numeric] == NO) {
			[filterEventsNumerics addObject:numeric];
		}
	}

	return [filterEventsNumerics copy];
}

- (TPI_ChatFilterEventType)compileFilterEvents
{
	TPI_ChatFilterEventType filterEvents = 0;

	if (self.filterEventPlainTextMessageCheck.state == NSControlStateValueOn)
		filterEvents |= TPI_ChatFilterEventTypePlainTextMessage;

	if (self.filterEventActionMessageCheck.state == NSControlStateValueOn)
		filterEvents |= TPI_ChatFilterEventTypeActionMessage;

	if (self.filterEventNoticeMessageCheck.state == NSControlStateValueOn)
		filterEvents |= TPI_ChatFilterEventTypeNoticeMessage;

	if (self.filterEventUserJoinedChannelCheck.state == NSControlStateValueOn)
		filterEvents |= TPI_ChatFilterEventTypeUserJoinedChannel;

	if (self.filterEventUserLeftChannelCheck.state == NSControlStateValueOn)
		filterEvents |= TPI_ChatFilterEventTypeUserLeftChannel;

	if (self.filterEventUserKickedFromChannelCheck.state == NSControlStateValueOn)
		filterEvents |= TPI_ChatFilterEventTypeUserKickedFromChannel;

	if (self.filterEventUserDisconnectedCheck.state == NSControlStateValueOn)
		filterEvents |= TPI_ChatFilterEventTypeUserDisconnected;

	if (self.filterEventUserChangedNicknameCheck.state == NSControlStateValueOn)
		filterEvents |= TPI_ChatFilterEventTypeUserChangedNickname;

	if (self.filterEventChannelTopicReceivedCheck.state == NSControlStateValueOn)
		filterEvents |= TPI_ChatFilterEventTypeChannelTopicReceived;

	if (self.filterEventChannelTopicChangedCheck.state == NSControlStateValueOn)
		filterEvents |= TPI_ChatFilterEventTypeChannelTopicChanged;

	if (self.filterEventChannelModeReceivedCheck.state == NSControlStateValueOn)
		filterEvents |= TPI_ChatFilterEventTypeChannelModeReceived;

	if (self.filterEventChannelModeChangedCheck.state == NSControlStateValueOn)
		filterEvents |= TPI_ChatFilterEventTypeChannelModeChanged;

	return filterEvents;
}

- (void)ok:(nullable id)sender
{
	if ([self okOrError] == NO) {
		return;
	}

	[self saveFilter];

	if ([self.delegate respondsToSelector:@selector(chatFilterEditFilterSheet:onOk:)]) {
		[self.delegate chatFilterEditFilterSheet:self onOk:[self.filter copy]];
	}

	[super ok:nil];
}

- (BOOL)okOrError
{
	if ([self okOrErrorForRegularExpressionInTextField:self.filterMatchTextField inSelection:TPI_ChatFilterEditFilterSheetSelectionGeneral] == NO) {
		return NO;
	}

	if ([self okOrErrorForRegularExpressionInTextField:self.filterSenderMatchTextField inSelection:TPI_ChatFilterEditFilterSheetSelectionSender] == NO) {
		return NO;
	}

	if ([self okOrErrorForTextField:self.filterEventNumericTextField inSelection:TPI_ChatFilterEditFilterSheetSelectionEvents] == NO) {
		return NO;
	}

	if ([self okOrErrorForTextField:self.filterForwardToDestinationTextField inSelection:TPI_ChatFilterEditFilterSheetSelectionAdvanced] == NO) {
		return NO;
	}

	return YES;
}

- (BOOL)okOrErrorForTextField:(TVCValidatedTextField *)textField inSelection:(TPI_ChatFilterEditFilterSheetSelection)selection
{
	if (textField.valueIsValid) {
		return YES;
	}

	[self navigateToSelection:selection];

	/* Give navigation time to settle before trying to attach popover */
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[textField showValidationErrorPopover];
	});

	return NO;
}

/* A pattern that doesn't compile would never match, so it can't be saved */
- (BOOL)okOrErrorForRegularExpressionInTextField:(NSTextField *)textField inSelection:(TPI_ChatFilterEditFilterSheetSelection)selection
{
	NSString *pattern = textField.stringValue;

	if (textField.enabled == NO || pattern.length == 0 || [XRRegularExpression isValidRegex:pattern]) {
		return YES;
	}

	[self navigateToSelection:selection];

	NSAlert *alert = [NSAlert new];

	alert.messageText = TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[r7x-q1]");
	alert.informativeText = TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[r7x-q2]", pattern);

	[alert beginSheetModalForWindow:self.sheet completionHandler:^(NSModalResponse returnCode) {
		[self.sheet makeFirstResponder:textField];
	}];

	return NO;
}

- (void)navigateToSelection:(TPI_ChatFilterEditFilterSheetSelection)selection
{
	if (self.contentViewTabView.indexOfSelectedItem == selection) {
		return;
	}

	[self.contentViewTabView selectTabViewItemAtIndex:selection];
}

- (void)windowWillClose:(NSNotification *)note
{
	[RZNotificationCenter() removeObserver:self];

	if ([self.delegate respondsToSelector:@selector(chatFilterEditFilterSheetWillClose:)]) {
		[self.delegate chatFilterEditFilterSheetWillClose:self];
	}
}

#pragma mark -
#pragma mark Token Field Delegate

- (void)populateTokenFieldStringValues
{
	NSCharacterSet *emptyCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@""];

	self.filterActionTokenField.tokenizingCharacterSet = emptyCharacterSet;

	self.filterActionTokenField.completionDelay = 0.2;

	[self setToken:@"%_channelName_%" inTokenField:self.filterActionTokenChannelName];
	[self setToken:@"%_localNickname_%" inTokenField:self.filterActionTokenLocalNickname];
	[self setToken:@"%_networkName_%" inTokenField:self.filterActionTokenNetworkName];
	[self setToken:@"%_originalMessage_%" inTokenField:self.filterActionTokenOriginalMessage];
	[self setToken:@"%_senderNickname_%" inTokenField:self.filterActionTokenSenderNickname];
	[self setToken:@"%_senderUsername_%" inTokenField:self.filterActionTokenSenderUsername];
	[self setToken:@"%_senderAddress_%" inTokenField:self.filterActionTokenSenderAddress];
	[self setToken:@"%_senderHostmask_%" inTokenField:self.filterActionTokenSenderHostmask];
	[self setToken:@"%_serverAddress_%" inTokenField:self.filterActionTokenServerAddress];
}

- (nullable NSArray *)tokenField:(NSTokenField *)tokenField readFromPasteboard:(NSPasteboard *)pboard
{
	NSString *stringContent = pboard.stringContent;

	return [self tokensFromString:stringContent];
}

- (BOOL)tokenField:(NSTokenField *)tokenField writeRepresentedObjects:(NSArray *)objects toPasteboard:(NSPasteboard *)pboard
{
	NSString *stringContent = [objects componentsJoinedByString:@""];

	pboard.stringContent = stringContent;

	return YES;
}

- (NSTokenStyle)tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject
{
	if ([representedObject isKindOfClass:[TPI_ChatFilterFilterActionToken class]]) {
		return NSTokenStyleRounded;
	}

	return NSTokenStyleNone;
}

- (nullable NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject
{
	if ([representedObject isKindOfClass:[TPI_ChatFilterFilterActionToken class]]) {
		return [representedObject tokenTitle];
	}

	return representedObject;
}

- (nullable id)tokenField:(NSTokenField *)tokenField representedObjectForEditingString:(NSString *)editingString
{
	if (tokenField == self.filterActionTokenField) {
		NSArray *tokenTitles = [self.filterActionAutoCompletedTokens filteredArrayUsingPredicate:
				[NSPredicate predicateWithFormat:@"SELF beginswith[cd] %@", editingString]];

		if (tokenTitles.count > 0) {
			NSString *tokenTitle = tokenTitles.firstObject;

			return [TPI_ChatFilterFilterActionToken tokenWithTokenTitle:tokenTitle];
		}
	}

	return editingString;
}

- (nullable NSArray *)tokenField:(NSTokenField *)tokenField completionsForSubstring:(NSString *)substring indexOfToken:(NSInteger)tokenIndex indexOfSelectedItem:(nullable NSInteger *)selectedIndex
{
	if (tokenField == self.filterActionTokenField) {
		NSArray *tokenTitles = [TPI_ChatFilterFilterActionToken tokenTitles];

		NSArray *tokenTitlesFiltered = [tokenTitles filteredArrayUsingPredicate:
				[NSPredicate predicateWithFormat:@"SELF beginswith[cd] %@", substring]];

		self.filterActionAutoCompletedTokens = tokenTitlesFiltered;

		return tokenTitlesFiltered;
	}

	return nil;
}

- (void)performFilterActionTokenCompletion
{

}

- (NSString *)stringValueForTokenField:(NSTokenField *)tokenField
{
	return [tokenField.objectValue componentsJoinedByString:@""];
}

- (void)setTokens:(NSString *)tokens inTokenField:(NSTokenField *)tokenField
{
	NSArray *tokenObjects = [self tokensFromString:tokens];

	tokenField.objectValue = tokenObjects;
}

- (void)setToken:(NSString *)token inTokenField:(NSTokenField *)tokenField
{
	 TPI_ChatFilterFilterActionToken *tokenObject =
	[TPI_ChatFilterFilterActionToken tokenWithToken:token];

	tokenField.objectValue = @[tokenObject];
}

- (NSArray *)tokensFromString:(nullable NSString *)string
{
	NSString *tokenString = string;

	if (tokenString == nil) {
		return @[];
	}

	NSMutableArray *tokens = [NSMutableArray array];

	NSInteger currentPosition = 0;

	NSInteger tokenStringLength = tokenString.length;

	while (currentPosition < tokenStringLength) {
		NSRange searchRange = NSMakeRange(currentPosition, (tokenStringLength - currentPosition));

		NSRange range = [tokenString rangeOfString:@"%_([a-zA-Z0-9_]+)_%"
										   options:NSRegularExpressionSearch
											 range:searchRange];

		if (range.location == NSNotFound) {
			NSString *tokenStringPrefix = [tokenString substringWithRange:searchRange];

			[tokens addObject:tokenStringPrefix];

			break;
		}

		NSRange tokenStringPrefixRange = NSMakeRange(currentPosition, (range.location - currentPosition));

		if (tokenStringPrefixRange.length > 0) {
			NSString *tokenStringPrefix = [tokenString substringWithRange:tokenStringPrefixRange];

			[tokens addObject:tokenStringPrefix];
		}

		NSString *tokenStringToken = [tokenString substringWithRange:range];

		if ([TPI_ChatFilterFilterActionToken isToken:tokenStringToken]) {
			 TPI_ChatFilterFilterActionToken *token =
			[TPI_ChatFilterFilterActionToken tokenWithToken:tokenStringToken];

			[tokens addObject:token];
		} else {
			[tokens addObject:tokenStringToken];
		}

		currentPosition = NSMaxRange(range);
	}

	if (tokens.count == 0) {
		[tokens addObject:tokenString];
	}

	return tokens;
}

#pragma mark -
#pragma mark Utilities

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
	if (control != self.filterActionTokenField && control != self.filterNotesTextField) {
		return NO;
	}

	NSRange selectedRange = [textView selectedRange];

	if (selectedRange.length > 0) {
		return NO;
	}

	if (commandSelector == @selector(insertNewline:))
	{
		NSRange editedRange = textView.textStorage.editedRange;

		if (editedRange.length > 1) {
			return NO;
		}

		[textView insertNewlineIgnoringFieldEditor:self];

		return YES;
	}

	return NO;
}

- (void)controlTextDidChange:(NSNotification *)notification
{
	[self toggleOkButton];
}

- (void)validatedTextFieldTextDidChange:(nullable id)sender
{
	[self toggleOkButton];
}

- (void)toggleOkButton
{
	BOOL disabled = NO;

	if (self.filterTitleTextField.stringValue.length == 0) {
		disabled = YES;
	}

	if (disabled == NO) {
		if (self.filterIgnoreContentCheck.state == NSControlStateValueOff &&
			self.filterForwardToDestinationTextField.stringValue.length == 0)
		{
			if (self.filterActionTokenField.stringValue.length == 0) {
				disabled = YES;
			}
		}
	}

	self.okButton.enabled = (disabled == NO);
}

- (void)setupTextFieldRules
{
	/* "Forward To" text field */
	self.filterForwardToDestinationTextField.textDidChangeCallback = self;

	self.filterForwardToDestinationTextField.performValidationWhenEmpty = NO;

	self.filterForwardToDestinationTextField.stringValueIsInvalidOnEmpty = NO;
	self.filterForwardToDestinationTextField.stringValueIsTrimmed = YES;
	self.filterForwardToDestinationTextField.stringValueUsesOnlyFirstToken = NO;

	self.filterForwardToDestinationTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if (currentValue.length > 125) {
			return TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[m0u-tw]");
		}

		if ([XRRegularExpression string:currentValue isMatchedByRegex:@"^([a-zA-Z0-9\\-\\_\\s]+)$"] == NO) {
			return TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[5kd-jt]");
		}

		return nil;
	};

	/* "Numerics" text field */
	self.filterEventNumericTextField.textDidChangeCallback = self;

	self.filterEventNumericTextField.performValidationWhenEmpty = NO;

	self.filterEventNumericTextField.stringValueIsInvalidOnEmpty = NO;
	self.filterEventNumericTextField.stringValueIsTrimmed = NO;
	self.filterEventNumericTextField.stringValueUsesOnlyFirstToken = NO;

	self.filterEventNumericTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if ([self compileFilterEventsNumerics] == nil) {
			return TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[9ri-sd]");
		}

		return nil;
	};
}

- (void)updateVisibilityOfLimitedToTableHostView
{
	if (self.filter.filterLimitedToValue == TPI_ChatFilterLimitToValueSpecificItems) {
		self.filterLimitedToHostView.hidden = NO;
	} else {
		self.filterLimitedToHostView.hidden = YES;
	}
}

- (void)updateEnableStateOfFilterActionTokenField
{

}

- (void)updateEnabledStateOfFilterEvents
{
	BOOL enabled = (self.filter.filterLimitedToValue != TPI_ChatFilterLimitToValuePrivateMessages);

	self.filterEventUserJoinedChannelCheck.enabled = enabled;
	self.filterEventUserLeftChannelCheck.enabled = enabled;
	self.filterEventUserKickedFromChannelCheck.enabled = enabled;
	self.filterEventUserDisconnectedCheck.enabled = enabled;
	self.filterEventUserChangedNicknameCheck.enabled = enabled;
	self.filterEventChannelTopicReceivedCheck.enabled = enabled;
	self.filterEventChannelTopicChangedCheck.enabled = enabled;
	self.filterEventChannelModeReceivedCheck.enabled = enabled;
	self.filterEventChannelModeChangedCheck.enabled = enabled;
}

- (void)updateEnabledStateOfComponentsConstrainedByFilterEvents
{
	BOOL enabled = (self.filterEventPlainTextMessageCheck.state == NSControlStateValueOn ||
					self.filterEventActionMessageCheck.state == NSControlStateValueOn ||
					self.filterEventNoticeMessageCheck.state == NSControlStateValueOn);

	self.filterIgnoreOperatorsCheckEnabled = enabled;

	[self willChangeValueForKey:@"filterIgnoreOperatorsCheckValue"];
	[self didChangeValueForKey:@"filterIgnoreOperatorsCheckValue"];
}

- (void)updateEnabledStateOfSenderMatch
{
	BOOL enabled = (self.filterLimitedToMyselfCheck.state == NSControlStateValueOff);

	self.filterSenderMatchTextField.enabled = enabled;
}

- (void)updateFilterLimitedToMatrix
{
	TPI_ChatFilterLimitToValue limitedTo = self.filter.filterLimitedToValue;

	self.filterLimitToNoLimitButton.state = (limitedTo == TPI_ChatFilterLimitToValueNoLimit);
	self.filterLimitToOnlyChannelsButton.state = (limitedTo == TPI_ChatFilterLimitToValueChannels);
	self.filterLimitToOnlyPrivateMessagesButton.state = (limitedTo == TPI_ChatFilterLimitToValuePrivateMessages);
	self.filterLimitToSpecificItemsButton.state = (limitedTo == TPI_ChatFilterLimitToValueSpecificItems);
}

- (void)filterLimitedToMyselfChanged:(nullable id)sender
{
	[self updateEnabledStateOfSenderMatch];
}

- (void)filterEventTypeChanged:(nullable id)sender
{
	[self updateEnabledStateOfComponentsConstrainedByFilterEvents];
}

- (void)viewFilterMatchHelpText:(nullable id)sender
{
	[TLOpenLink openWithString:@"https://help.codeux.com/textual/Introduction-to-the-Chat-Filter-Addon.kb#faq-entry-1" inBackground:NO];
}

- (void)viewFilterActionHelpText:(nullable id)sender
{
	[TLOpenLink openWithString:@"https://help.codeux.com/textual/Introduction-to-the-Chat-Filter-Addon.kb#faq-entry-2" inBackground:NO];
}

- (void)viewFilterSenderMatchHelpText:(nullable id)sender
{
	[TLOpenLink openWithString:@"https://help.codeux.com/textual/Introduction-to-the-Chat-Filter-Addon.kb#faq-entry-3" inBackground:NO];
}

- (void)viewFilterForwardToDestinationHelpText:(nullable id)sender
{
	[TLOpenLink openWithString:@"https://help.codeux.com/textual/Introduction-to-the-Chat-Filter-Addon.kb#faq-entry-4" inBackground:NO];
}

- (void)filterLimitedToMatrixChanged:(nullable id)sender
{
	self.filter.filterLimitedToValue = [sender tag];

	[self updateVisibilityOfLimitedToTableHostView];

	[self updateEnabledStateOfFilterEvents];
}

- (void)filterIgnoreContentCheckChanged:(nullable id)sender
{
	[self updateEnableStateOfFilterActionTokenField];

	[self toggleOkButton];
}

@end

#pragma mark -
#pragma mark Token Object

@implementation TPI_ChatFilterFilterActionToken

+ (TPI_ChatFilterFilterActionToken *)tokenWithToken:(NSString *)token
{
	TPI_ChatFilterFilterActionToken *tokenField = [TPI_ChatFilterFilterActionToken new];

	tokenField.token = token;

	return tokenField;
}

+ (nullable TPI_ChatFilterFilterActionToken *)tokenWithTokenTitle:(NSString *)tokenTitle
{
	NSArray *tokenTitles = [TPI_ChatFilterFilterActionToken tokenTitles];

	NSInteger tokenTitleIndex = [tokenTitles indexOfObject:tokenTitle];

	if (tokenTitleIndex == NSNotFound) {
		return nil;
	}

	NSArray *tokens = [TPI_ChatFilterFilterActionToken tokens];

	NSString *token = tokens[tokenTitleIndex];

	return [TPI_ChatFilterFilterActionToken tokenWithToken:token];
}

+ (BOOL)isToken:(NSString *)token
{
	NSArray *tokens = [TPI_ChatFilterFilterActionToken tokens];

	return ([tokens indexOfObject:token] != NSNotFound);
}

+ (NSArray<NSString *> *)tokens
{
	/* The index of this array should match the index of -tokenTitles */
	static NSArray *tokens = nil;

	if (tokens == nil) {
		tokens = @[
		   @"%_channelName_%",
		   @"%_localNickname_%",
		   @"%_networkName_%",
		   @"%_originalMessage_%",
		   @"%_senderNickname_%",
		   @"%_senderUsername_%",
		   @"%_senderAddress_%",
		   @"%_senderHostmask_%",
		   @"%_serverAddress_%",
		   @"%_Parameter_0_%",
		   @"%_Parameter_1_%",
		   @"%_Parameter_2_%",
		   @"%_Parameter_3_%",
		   @"%_Parameter_4_%",
		   @"%_Parameter_5_%",
		   @"%_Parameter_6_%",
		   @"%_Parameter_7_%",
		   @"%_Parameter_8_%"
		];
	}

	return tokens;
}

+ (NSArray<NSString *> *)tokenTitles
{
	/* The index of this array should match the index of -tokens */
	static NSArray *tokens = nil;

	if (tokens == nil) {
		tokens = @[
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[90e-tj]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[tbc-wc]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[840-f9]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[sch-hi]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[k82-6i]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[2sk-ui]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[xt2-bv]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[je5-u2]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[9xy-vf]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[kph-dc]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[8bd-nt]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[4vk-v8]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[kvz-ej]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[2pa-ju]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[jen-7o]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[t5v-4o]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[vyf-el]"),
		   TPILocalizedString(@"TPI_ChatFilterEditFilterSheet[0x4-ib]")
		];
	}

	return tokens;
}

+ (nullable NSString *)titleForToken:(NSString *)token
{
	NSArray *tokens = [TPI_ChatFilterFilterActionToken tokens];

	NSInteger tokenIndex = [tokens indexOfObject:token];

	if (tokenIndex == NSNotFound) {
		return nil;
	}

	NSArray *tokenTitles = [TPI_ChatFilterFilterActionToken tokenTitles];

	return tokenTitles[tokenIndex];
}

- (nullable NSString *)tokenTitle
{
	return [TPI_ChatFilterFilterActionToken titleForToken:self.token];
}

- (NSString *)description
{
	return self.token;
}

@end

NS_ASSUME_NONNULL_END
