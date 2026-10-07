/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2013 - 2018 Codeux Software, LLC & respective contributors.
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

#import "TPISmileyConverter.h"

NS_ASSUME_NONNULL_BEGIN

@interface TPISmileyConverter ()
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *conversionTable;
@property (nonatomic, copy) NSArray<NSString *> *sortedSmileyList;
@property (nonatomic, strong) IBOutlet NSView *preferencesPane;

- (IBAction)preferenceChanged:(id)sender;
@end

@implementation TPISmileyConverter

#pragma mark -
#pragma mark Plugin API

- (void)pluginLoadedIntoMemory
{
	XRPerformBlockSynchronouslyOnMainQueue(^{
		[TPIBundleFromClass() loadNibNamed:@"TPISmileyConverter" owner:self topLevelObjects:nil];
	});

	[self maybeBuildConversionTable];
}

- (void)maybeBuildConversionTable
{
	BOOL serviceEnabled = [RZUserDefaults() boolForKey:@"Smiley Converter Extension -> Enable Service"];

	if (serviceEnabled == NO) {
		return;
	}

	[self buildConversionTable];
}

- (void)buildConversionTable
{
	NSMutableDictionary<NSString *, NSString *> *conversionTable = [NSMutableDictionary dictionary];

	NSURL *tablePath = [TPIBundleFromClass() URLForResource:@"conversionTable" withExtension:@"plist"];

	/* Load primary table */
	NSDictionary *tableData = [NSDictionary dictionaryWithContentsOfURL:tablePath];

	NSAssert((tableData != nil),
		@"Failed to load conversion table");

	[conversionTable addEntriesFromDictionary:tableData];

	/* Load larger table */
	if ([RZUserDefaults() boolForKey:@"Smiley Converter Extension -> Enable Extra Emoticons"]) {
		NSURL *tablePath2 = [TPIBundleFromClass() URLForResource:@"conversionTable2" withExtension:@"plist"];

		NSDictionary *tableData2 = [NSDictionary dictionaryWithContentsOfURL:tablePath2];

		NSAssert((tableData2 != nil),
			@"Failed to load conversion table");

		[conversionTable addEntriesFromDictionary:tableData2];
	}

	/* Save table contents */
	self.conversionTable = conversionTable;

	self.sortedSmileyList = conversionTable.sortedDictionaryKeysReversed;
}

- (void)destroyConversionTable
{
	self.conversionTable = nil;

	self.sortedSmileyList = nil;
}

- (void)preferenceChanged:(id)sender
{
	[self destroyConversionTable];

	[self maybeBuildConversionTable];
}

- (NSView *)pluginPreferencesPaneView
{
	return self.preferencesPane;
}

- (NSString *)pluginPreferencesPaneMenuItemName
{
	return TPILocalizedString(@"BasicLanguage[3kj-8f]");
}

- (NSString *)willRenderMessage:(NSString *)newMessage forViewController:(TVCLogController *)viewController lineType:(TVCLogLineType)lineType memberType:(TVCLogLineMemberType)memberType
{
	BOOL serviceEnabled = [RZUserDefaults() boolForKey:@"Smiley Converter Extension -> Enable Service"];

	if (serviceEnabled == NO) {
		return newMessage;
	}

	if (lineType == TVCLogLineTypeAction ||
		lineType == TVCLogLineTypePrivateMessage)
	{
		return [self convertStringToEmoji:newMessage];
	}

	return newMessage;
}

#pragma mark -
#pragma mark Convert API

- (NSString *)convertStringToEmoji:(NSString *)string
{
	NSMutableString *finalString = [string mutableCopy];

	for (NSString *smiley in self.sortedSmileyList) {
		[self stringWithReplacedSmiley:smiley inString:finalString];
	}

	return [finalString copy];
}

/* The replacement call uses a lot of work done by the actual Textual rendering engine. */
- (void)stringWithReplacedSmiley:(NSString *)smiley inString:(NSMutableString *)inString
{
	NSUInteger currentPosition = 0;

	while (currentPosition < inString.length) {
		NSRange range = [inString rangeOfString:smiley
										options:NSCaseInsensitiveSearch
										  range:NSMakeRange(currentPosition, (inString.length - currentPosition))];

		if (range.location == NSNotFound) {
			break;
		}

		BOOL enabled = YES;

		NSInteger leftLocation = (range.location - 1);

		if (leftLocation >= 0 && leftLocation < inString.length) {
			UniChar c = [inString characterAtIndex:leftLocation];

			if (c != ' ') {
				enabled = NO;

				goto next_pass;
			}
		}

		NSInteger rightLocation = NSMaxRange(range);

		if (rightLocation < inString.length) {
			UniChar c = [inString characterAtIndex:rightLocation];

			if (c != ' ') {
				enabled = NO;

				goto next_pass;
			}
		}

next_pass:
		if (enabled) {
			NSString *emoji = self.conversionTable[smiley];

			[inString replaceCharactersInRange:range withString:emoji];

			currentPosition = (range.location + emoji.length + 1);
		} else {
			currentPosition = (NSMaxRange(range) + 1);
		}
	}
}

@end

NS_ASSUME_NONNULL_END
