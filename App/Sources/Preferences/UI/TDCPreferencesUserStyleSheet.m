/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 *    Copyright (c) 2019 Codeux Software, LLC & respective contributors.
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

#import "TLOLocalization.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TDCPreferencesUserStyleSheetPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCPreferencesUserStyleSheet ()
@property (nonatomic, unsafe_unretained) IBOutlet NSTextView *rulesTextView;
@property (nonatomic, assign) BOOL rulesChanged;
@property (nonatomic, copy, readonly) NSString *defaultRules;
@end

@implementation TDCPreferencesUserStyleSheet

- (instancetype)initWithWindow:(nullable NSWindow *)window
{
	if ((self = [super initWithWindow:window])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCPreferencesUserStyleSheet" owner:self topLevelObjects:nil];

	self.rulesTextView.font = [NSFont systemFontOfSize:13.0];

	self.rulesTextView.textContainerInset = NSMakeSize(1, 3);

	[self loadRules];
}

- (void)start
{
	[self startSheet];
}

- (void)textDidChange:(NSNotification *)aNotification
{
	if (aNotification.object == self.rulesTextView) {
		self.rulesChanged = YES;
	}
}

- (void)loadRules
{
	NSString *rules = [TPCPreferences themeUserStyleSheetRules];

	/* We can define the default rules in the defaults property list
	 but we don't do that for this preference so that it doesn't append
	 to the HTML unless the user entered a value. It is easier to do
	 that here versus making a comparison to the default in higher up. */
	if (rules == nil) {
		rules = self.defaultRules;
	}

	self.rulesTextView.string = rules;

	self.rulesChanged = NO;
}

- (void)saveRules
{
	NSString *rules = self.rulesTextView.string.trim;

	if (rules.length == 0 || [rules isEqualToString:self.defaultRules]) {
		rules = nil;
	}

	[TPCPreferences setThemeUserStyleSheetRules:rules];

	if ([self.delegate respondsToSelector:@selector(userStyleSheetRulesChanged:)]) {
		[self.delegate userStyleSheetRulesChanged:self];
	}
}

- (void)ok:(id)sender
{
	if (self.rulesChanged) {
		[self saveRules];
	}

	[super ok:nil];
}

- (NSString *)defaultRules
{
	return TXTLS(@"TDCPreferencesUserStyleSheet[q4s-3m]");
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	if ([self.delegate respondsToSelector:@selector(userStyleSheetWillClose:)]) {
		[self.delegate userStyleSheetWillClose:self];
	}
}

@end

NS_ASSUME_NONNULL_END
