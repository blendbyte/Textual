/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

#import "TLOUploadDestinationPrivate.h"
#import "TDCUploadDestinationSheetPrivate.h"
#import "NSViewHelper.h"
#import "TXMasterController.h"
#import "TPCPathInfoPrivate.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesReload.h"
#import "TPCPreferencesUserDefaults.h"
#import "THOPluginManagerPrivate.h"
#import "IRC.h"
#import "TLOLocalization.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCPreferencesPanePrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _unsignedIntegerString(_value_)		[NSString stringWithUnsignedInteger:(_value_)]

/* The value clamped to a range, as a string (the fields are bound to strings) */
static NSString *TDCPreferencesClampedValue(id value, NSInteger minimum, NSInteger maximum)
{
	NSInteger valueInteger = [value integerValue];

	if (valueInteger < minimum) {
		valueInteger = minimum;
	} else if (valueInteger > maximum) {
		valueInteger = maximum;
	}

	return _unsignedIntegerString(valueInteger);
}

#pragma mark File Transfers

#define _fileTransferPortRangeMin		1024
#define _fileTransferPortRangeMax		TXMaximumTCPPort

@interface TDCPreferencesFileTransfersPane ()
@property (nonatomic, weak) IBOutlet NSPopUpButton *downloadFolderButton;
@property (nonatomic, strong, nullable) NSTextField *uploadDestinationLabel;
@property (nonatomic, strong, nullable) NSButton *uploadDestinationButton;
@property (nonatomic, weak) IBOutlet NSTextField *manualIPAddressTextField;

/* Bound in the nib */
@property (nonatomic, copy) NSString *fileTransferPortRangeStart;
@property (nonatomic, copy) NSString *fileTransferPortRangeEnd;

- (IBAction)onFileTransferDownloadDestinationFolderChanged:(nullable id)sender;
- (IBAction)onFileTransferIPAddressDetectionMethodChanged:(nullable id)sender;
@end

@implementation TDCPreferencesFileTransfersPane

- (void)viewDidLoad
{
	[super viewDidLoad];

	[self updateDownloadFolder];

	[self onFileTransferIPAddressDetectionMethodChanged:nil];

	[self addUploadDestinationRow];
}

/* Uploads (9.18 B): the address used on networks without one of their own */
- (void)addUploadDestinationRow
{
	NSGridView *grid = nil;

	for (NSView *subview in self.view.subviews) {
		if ([subview isKindOfClass:[NSGridView class]]) {
			grid = (NSGridView *)subview;

			break;
		}
	}

	if (grid == nil) {
		return;
	}

	NSTextField *titleLabel = [NSTextField labelWithString:TXTLS(@"TDCPreferencesController[upl-t1]")];

	NSTextField *label = [NSTextField labelWithString:@""];

	label.lineBreakMode = NSLineBreakByTruncatingTail;

	[label setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

	NSButton *button = [NSButton buttonWithTitle:@"" target:self action:@selector(editUploadDestination:)];

	NSStackView *stack = [NSStackView stackViewWithViews:@[label, button]];

	stack.alignment = NSLayoutAttributeFirstBaseline;
	stack.spacing = 8;

	NSTextField *note = [NSTextField wrappingLabelWithString:TXTLS(@"TDCPreferencesController[upl-n1]")];

	note.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	note.textColor = [NSColor secondaryLabelColor];

	[note.widthAnchor constraintLessThanOrEqualToConstant:300].active = YES;

	[grid addRowWithViews:@[titleLabel, stack]];
	[grid addRowWithViews:@[[NSGridCell emptyContentView], note]];

	self.uploadDestinationLabel = label;
	self.uploadDestinationButton = button;

	[self updateUploadDestination];
}

- (void)updateUploadDestination
{
	TLOUploadDestination *destination = [TLOUploadDestination globalDestination];

	if (destination) {
		self.uploadDestinationLabel.stringValue = destination.name;

		self.uploadDestinationButton.title = TXTLS(@"TDCPreferencesController[upl-b2]");
	} else {
		self.uploadDestinationLabel.stringValue = TXTLS(@"TDCPreferencesController[upl-l1]");

		self.uploadDestinationButton.title = TXTLS(@"TDCPreferencesController[upl-b1]");
	}
}

- (void)editUploadDestination:(nullable id)sender
{
	[TDCUploadDestinationSheet editGlobalDestinationInWindow:self.view.window completionBlock:^{
		[self updateUploadDestination];
	}];
}

- (void)updateDownloadFolder
{
	[self showFolder:[TXSharedApplication sharedFileTransferDialog].downloadDestinationURL
	   inPopUpButton:self.downloadFolderButton
		 placeholder:TXTLS(@"TDCPreferencesController[721-ie]")];
}

- (void)onFileTransferDownloadDestinationFolderChanged:(nullable id)sender
{
	[self chooseFolderFromPopUpButton:self.downloadFolderButton completionBlock:^(NSData * _Nullable bookmark) {
		[[TXSharedApplication sharedFileTransferDialog] setDownloadDestinationBookmark:bookmark];

		[self updateDownloadFolder];
	}];
}

- (void)onFileTransferIPAddressDetectionMethodChanged:(nullable id)sender
{
	self.manualIPAddressTextField.enabled =
	([TPCPreferences fileTransferIPAddressDetectionMethod] == TXFileTransferIPAddressMethodManual);
}

- (NSString *)fileTransferPortRangeStart
{
	return _unsignedIntegerString([TPCPreferences fileTransferPortRangeStart]);
}

- (void)setFileTransferPortRangeStart:(NSString *)value
{
	[TPCPreferences setFileTransferPortRangeStart:value.integerValue];
}

- (NSString *)fileTransferPortRangeEnd
{
	return _unsignedIntegerString([TPCPreferences fileTransferPortRangeEnd]);
}

- (void)setFileTransferPortRangeEnd:(NSString *)value
{
	[TPCPreferences setFileTransferPortRangeEnd:value.integerValue];
}

/* The start of the range stays at or below its end */
- (BOOL)validateValue:(inout id *)value forKey:(NSString *)key error:(out NSError **)outError
{
	if ([key isEqualToString:@"fileTransferPortRangeStart"]) {
		*value = TDCPreferencesClampedValue(*value, _fileTransferPortRangeMin, _fileTransferPortRangeMax);

		*value = TDCPreferencesClampedValue(*value, _fileTransferPortRangeMin, [TPCPreferences fileTransferPortRangeEnd]);
	} else if ([key isEqualToString:@"fileTransferPortRangeEnd"]) {
		*value = TDCPreferencesClampedValue(*value, _fileTransferPortRangeMin, _fileTransferPortRangeMax);

		*value = TDCPreferencesClampedValue(*value, [TPCPreferences fileTransferPortRangeStart], _fileTransferPortRangeMax);
	}

	return YES;
}

@end

#pragma mark -
#pragma mark Log Location

@interface TDCPreferencesLogLocationPane ()
@property (nonatomic, weak) IBOutlet NSPopUpButton *transcriptFolderButton;

/* Bound in the nib */
@property (nonatomic, assign) BOOL logTranscript;

- (IBAction)onChangedTranscriptFolder:(nullable id)sender;
@end

@implementation TDCPreferencesLogLocationPane

- (void)viewDidLoad
{
	[super viewDidLoad];

	[self updateTranscriptFolder];
}

- (BOOL)logTranscript
{
	return [TPCPreferences logToDisk];
}

- (void)setLogTranscript:(BOOL)logTranscript
{
	[TPCPreferences setLogToDisk:logTranscript];

	/* Turned off: closes the log files that are open */
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionLogTranscripts];
}

- (void)updateTranscriptFolder
{
	[self showFolder:[TPCPathInfo transcriptFolderURL]
	   inPopUpButton:self.transcriptFolderButton
		 placeholder:TXTLS(@"TDCPreferencesController[70s-c6]")];
}

- (void)onChangedTranscriptFolder:(nullable id)sender
{
	[self chooseFolderFromPopUpButton:self.transcriptFolderButton completionBlock:^(NSData * _Nullable bookmark) {
		[TPCPathInfo setTranscriptFolderURL:bookmark];

		[TPCPreferences performReloadAction:TPCPreferencesReloadActionLogTranscripts];

		[self updateTranscriptFolder];
	}];
}

@end

#pragma mark -
#pragma mark Installed Addons

@interface TDCPreferencesInstalledAddonsPane ()
@property (nonatomic, weak) IBOutlet NSTableView *installedScriptsTable;

/* Bound in the nib */
@property (readonly, copy) NSArray<NSDictionary *> *installedScripts;

- (IBAction)onOpenPathToScripts:(nullable id)sender;
@end

@implementation TDCPreferencesInstalledAddonsPane

- (void)viewDidLoad
{
	[super viewDidLoad];

	self.installedScriptsTable.sortDescriptors = @[
		[NSSortDescriptor sortDescriptorWithKey:@"string" ascending:YES selector:@selector(caseInsensitiveCompare:)]
	];
}

- (NSArray<NSDictionary *> *)installedScripts
{
	NSMutableArray *scriptsInstalled = [NSMutableArray array];

	[scriptsInstalled addObjectsFromArray:sharedPluginManager().supportedAppleScriptCommands];
	[scriptsInstalled addObjectsFromArray:sharedPluginManager().supportedUserInputCommands];

	return scriptsInstalled.stringArrayControllerObjects;
}

- (void)onOpenPathToScripts:(nullable id)sender
{
	[RZWorkspace() openURL:[TPCPathInfo applicationSupportURL]];
}

@end

#pragma mark -
#pragma mark Hidden Preferences

#define _scrollbackVisibleLinesMin		100
#define _scrollbackVisibleLinesMax		15000

#define _noModeColorKey		@"User List Mode Badge Colors -> no mode"

@interface TDCPreferencesHiddenPane ()
/* Bound in the nib */
@property (nonatomic, assign) BOOL appNapEnabled;
@property (nonatomic, copy) NSString *scrollbackVisibleLimit;
@property (nonatomic, copy) NSColor *userListNoModeColor; // clear: the appearance's own colour

- (IBAction)onChangedScrollbackVisibleLimit:(nullable id)sender;
- (IBAction)onChangedUserListModeColor:(nullable id)sender;
@end

@implementation TDCPreferencesHiddenPane

- (void)viewDidLoad
{
	[super viewDidLoad];

	/* Reset with the other user list colours in the Interface section */
	[RZUserDefaults() addObserver:self forKeyPath:_noModeColorKey options:0 context:NULL];
}

- (void)dealloc
{
	if (self.viewLoaded) {
		[RZUserDefaults() removeObserver:self forKeyPath:_noModeColorKey];
	}
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change context:(nullable void *)context
{
	if ([keyPath isEqualToString:_noModeColorKey]) {
		[self willChangeValueForKey:@"userListNoModeColor"];
		[self didChangeValueForKey:@"userListNoModeColor"];

		return;
	}

	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (BOOL)appNapEnabled
{
	return [TPCPreferences appNapEnabled];
}

- (void)setAppNapEnabled:(BOOL)appNapEnabled
{
	[TPCPreferences setAppNapEnabled:appNapEnabled];
}

- (NSString *)scrollbackVisibleLimit
{
	return _unsignedIntegerString([TPCPreferences scrollbackVisibleLimit]);
}

- (void)setScrollbackVisibleLimit:(NSString *)value
{
	[TPCPreferences setScrollbackVisibleLimit:value.integerValue];
}

/* 0 means no limit */
- (BOOL)validateValue:(inout id *)value forKey:(NSString *)key error:(out NSError **)outError
{
	if ([key isEqualToString:@"scrollbackVisibleLimit"] && [*value integerValue] != 0) {
		*value = TDCPreferencesClampedValue(*value, _scrollbackVisibleLinesMin, _scrollbackVisibleLinesMax);
	}

	return YES;
}

- (void)onChangedScrollbackVisibleLimit:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionScrollbackVisibleLimit];
}

- (NSColor *)userListNoModeColor
{
	return ([RZUserDefaults() colorForKey:_noModeColorKey] ?: [NSColor clearColor]);
}

- (void)setUserListNoModeColor:(NSColor *)userListNoModeColor
{
	NSColor *newValue = userListNoModeColor;

	if ([newValue isEqual:[NSColor clearColor]]) {
		newValue = nil;
	}

	[RZUserDefaults() setColor:newValue forKey:_noModeColorKey];
}

- (void)onChangedUserListModeColor:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionMemberListUserBadges forKey:_noModeColorKey];
}

@end

NS_ASSUME_NONNULL_END
