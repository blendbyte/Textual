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
/* Lower-cased smiley -> emoji. Replaced as a whole (atomic): lines are
 rendered on another queue while preferences change the table. */
@property (atomic, copy, nullable) NSDictionary<NSString *, NSString *> *conversionTable;
@property (nonatomic, strong) IBOutlet NSView *preferencesPane;

- (IBAction)preferenceChanged:(nullable id)sender;
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

	/* Matched without case */
	NSMutableDictionary<NSString *, NSString *> *lowercaseTable = [NSMutableDictionary dictionaryWithCapacity:conversionTable.count];

	[conversionTable enumerateKeysAndObjectsUsingBlock:^(NSString *smiley, NSString *emoji, BOOL *stop) {
		NSString *key = smiley.lowercaseString;

		if (lowercaseTable[key] == nil) {
			lowercaseTable[key] = emoji;
		}
	}];

	self.conversionTable = lowercaseTable;
}

- (void)destroyConversionTable
{
	self.conversionTable = nil;
}

- (void)preferenceChanged:(nullable id)sender
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

/* A smiley is converted when it is a whole word between spaces: one lookup
 per word (the message was searched once per smiley, up to 950 times) */
- (NSString *)convertStringToEmoji:(NSString *)string
{
	NSDictionary<NSString *, NSString *> *conversionTable = self.conversionTable;

	if (conversionTable.count == 0 || string.length == 0) {
		return string;
	}

	NSArray<NSString *> *words = [string componentsSeparatedByString:@" "];

	NSMutableArray<NSString *> *convertedWords = nil;

	for (NSUInteger index = 0; index < words.count; index++) {
		NSString *emoji = conversionTable[words[index].lowercaseString];

		if (emoji == nil) {
			continue;
		}

		if (convertedWords == nil) {
			convertedWords = [words mutableCopy];
		}

		convertedWords[index] = emoji;
	}

	if (convertedWords == nil) {
		return string;
	}

	return [convertedWords componentsJoinedByString:@" "];
}

@end

NS_ASSUME_NONNULL_END
