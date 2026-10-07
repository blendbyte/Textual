/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2018 - 2020Codeux Software, LLC & respective contributors.
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
#import "TVCAppearancePrivate.h"
#import "TDCChannelSpotlightControlsPrivate.h"
#import "TDCChannelSpotlightAppearanceInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCChannelSpotlightAppearance ()
#pragma mark -
#pragma mark Search Field

@property (nonatomic, copy, nullable, readwrite) NSColor *searchFieldTextColor;
@property (nonatomic, copy, nullable, readwrite) NSColor *searchFieldCompletionTextColor;
@property (nonatomic, copy, nullable, readwrite) NSColor *searchFieldNoResultsTextColor;

#pragma mark -
#pragma mark Search Result

@property (nonatomic, copy, nullable, readwrite) NSColor *searchResultRowSelectionColorActiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSColor *searchResultRowSelectionColorInactiveWindow;
@property (nonatomic, assign, readwrite) BOOL searchResultRowEmphasized;
@property (nonatomic, copy, nullable, readwrite) NSColor *searchResultChannelNameTextColor;
@property (nonatomic, copy, nullable, readwrite) NSColor *searchResultChannelDescriptionTextColor;
@property (nonatomic, copy, nullable, readwrite) NSColor *searchResultKeyboardShortcutTextColor;
@property (nonatomic, assign, readwrite) CGFloat searchResultKeyboardShortcutDeselectedOffset;
@property (nonatomic, assign, readwrite) CGFloat searchResultKeyboardShortcutSelectedOffset;
@property (nonatomic, copy, nullable, readwrite) NSColor *searchResultSelectedTextColor;
@end

@implementation TDCChannelSpotlightAppearance

#pragma mark -
#pragma mark Initialization

- (nullable instancetype)initWithWindow:(TDCChannelSpotlightPanel *)window
{
	NSParameterAssert(window != nil);

	NSURL *appearanceLocation = [self.class appearanceLocation];

	BOOL forRetinaDisplay = window.runningInHighResolutionMode;

	if ((self = [super initWithAppearanceAtURL:appearanceLocation forRetinaDisplay:forRetinaDisplay])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

+ (NSURL *)appearanceLocation
{
	return [RZMainBundle() URLForResource:@"TDCChannelSpotlightAppearance" withExtension:@"plist"];
}

- (void)prepareInitialState
{
	NSDictionary *properties = self.appearanceProperties;

	NSDictionary *searchField = properties[@"Search Field"];

	self.searchFieldTextColor = [self colorInGroup:searchField withKey:@"controlTextColor"];
	self.searchFieldCompletionTextColor = [self colorInGroup:searchField withKey:@"completionTextColor"];
	self.searchFieldNoResultsTextColor = [self colorInGroup:searchField withKey:@"noResultsTextColor"];

	NSDictionary *searchResult = properties[@"Search Result"];

	self.searchResultRowSelectionColorActiveWindow = [self colorInGroup:searchResult withKey:@"selectionColor" forActiveWindow:YES];
	self.searchResultRowSelectionColorInactiveWindow = [self colorInGroup:searchResult withKey:@"selectionColor" forActiveWindow:NO];
	self.searchResultRowEmphasized = [searchResult boolForKey:@"rowEmphasized"];
	self.searchResultChannelNameTextColor = [self colorInGroup:searchResult withKey:@"channelNameTextColor"];
	self.searchResultChannelDescriptionTextColor = [self colorInGroup:searchResult withKey:@"channelDescriptionTextColor"];
	self.searchResultKeyboardShortcutTextColor = [self colorInGroup:searchResult withKey:@"keyboardShortcutTextColor"];
	self.searchResultKeyboardShortcutDeselectedOffset = [self measurementInGroup:searchResult withKey:@"keyboardShortcutDeselectedOffset"];
	self.searchResultKeyboardShortcutSelectedOffset = [self measurementInGroup:searchResult withKey:@"keyboardShortcutSelectedOffset"];
	self.searchResultSelectedTextColor = [self colorInGroup:searchResult withKey:@"selectedTextColor"];

	[self flushAppearanceProperties];
}

@end

NS_ASSUME_NONNULL_END
