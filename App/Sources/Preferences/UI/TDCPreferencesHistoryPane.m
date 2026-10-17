/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

#import "TLOLocalization.h"
#import "TLOMessageArchivePrivate.h"
#import "TPCPathInfoPrivate.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesReload.h"
#import "TVCMainWindowPrivate.h"
#import "TXMasterController.h"
#import "TDCPreferencesPanePrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _paneWidth			670

/* Preferences → History (10.9 F): the message archive (how long it keeps
 messages, its size, Delete Archive…, Import Text Logs…) and text logs (moved
 here from Advanced → Log Location). Built in code. */
@interface TDCPreferencesHistoryPane ()
@property (nonatomic, strong) NSPopUpButton *keepPeriodButton;
@property (nonatomic, strong) NSTextField *sizeLabel;
@property (nonatomic, strong) NSButton *deleteButton;
@property (nonatomic, strong) NSButton *importButton;
@property (nonatomic, strong) NSTextField *importStatusLabel;
@property (nonatomic, strong) NSButton *transcriptCheckbox;
@property (nonatomic, strong) NSPopUpButton *transcriptFolderButton;
@property (nonatomic, assign) NSUInteger messageCount;
@property (nonatomic, assign) BOOL importing;
@property (nonatomic, assign) BOOL deleting;
@end

@implementation TDCPreferencesHistoryPane

- (void)loadView
{
	NSGridView *grid = [self _grid];

	NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, _paneWidth, 300)];

	[view addSubview:grid];

	[NSLayoutConstraint activateConstraints:@[
		[grid.topAnchor constraintEqualToAnchor:view.topAnchor constant:30],
		[grid.centerXAnchor constraintEqualToAnchor:view.centerXAnchor]
	]];

	/* As tall as what's in it */
	[view setFrameSize:NSMakeSize(_paneWidth, (grid.fittingSize.height + 60))];

	self.view = view;

	[self _updateControls];

	[self _updateArchiveSize];
}

- (NSGridView *)_grid
{
	/* Keep messages: [1 year] */
	NSPopUpButton *keepPeriodButton = [NSPopUpButton new];

	for (NSNumber *days in @[@(TPCMessageArchiveKeepPeriodTwoWeeks),
							 @(TPCMessageArchiveKeepPeriodThirtyDays),
							 @(TPCMessageArchiveKeepPeriodNinetyDays),
							 @(TPCMessageArchiveKeepPeriodHalfYear),
							 @(TPCMessageArchiveKeepPeriodOneYear),
							 @(TPCMessageArchiveKeepPeriodTwoYears),
							 @(TPCMessageArchiveKeepPeriodForever)])
	{
		switch (days.integerValue) {
			case TPCMessageArchiveKeepPeriodOneYear:
			{
				[keepPeriodButton addItemWithTitle:TXTLS(@"TDCPreferencesController[his-p1]")];

				break;
			}
			case TPCMessageArchiveKeepPeriodTwoYears:
			{
				[keepPeriodButton addItemWithTitle:TXTLS(@"TDCPreferencesController[his-p5]")];

				break;
			}
			case TPCMessageArchiveKeepPeriodForever:
			{
				[keepPeriodButton addItemWithTitle:TXTLS(@"TDCPreferencesController[his-p3]")];

				break;
			}
			default:
			{
				[keepPeriodButton addItemWithTitle:TXTLS(@"TDCPreferencesController[his-p2]", days.integerValue)];

				break;
			}
		}

		keepPeriodButton.lastItem.tag = days.integerValue;
	}

	[keepPeriodButton.menu addItem:[NSMenuItem separatorItem]];

	[keepPeriodButton addItemWithTitle:TXTLS(@"TDCPreferencesController[his-p4]")];
	keepPeriodButton.lastItem.tag = TPCMessageArchiveKeepPeriodOff;

	keepPeriodButton.target = self;
	keepPeriodButton.action = @selector(keepPeriodChanged:);

	NSTextField *note = [self _noteWithString:TXTLS(@"TDCPreferencesController[his-n1]")];

	/* 48,210 messages, 12.4 MB [Delete Archive…] */
	NSTextField *sizeLabel = [NSTextField labelWithString:@""];

	NSButton *deleteButton = [NSButton buttonWithTitle:TXTLS(@"TDCPreferencesController[his-b1]") target:self action:@selector(deleteArchive:)];

	NSStackView *sizeRow = [NSStackView stackViewWithViews:@[sizeLabel, deleteButton]];

	sizeRow.alignment = NSLayoutAttributeFirstBaseline;
	sizeRow.spacing = 12;

	/* [Import Text Logs…] Importing… */
	NSButton *importButton = [NSButton buttonWithTitle:TXTLS(@"TDCPreferencesController[his-b2]") target:self action:@selector(importTextLogs:)];

	NSTextField *importStatusLabel = [self _noteWithString:@""];

	NSStackView *importRow = [NSStackView stackViewWithViews:@[importButton, importStatusLabel]];

	importRow.alignment = NSLayoutAttributeFirstBaseline;
	importRow.spacing = 12;

	NSTextField *importNote = [self _noteWithString:TXTLS(@"TDCPreferencesController[his-n2]")];

	/* [x] Save to folder: [Folder] */
	NSButton *transcriptCheckbox = [NSButton checkboxWithTitle:TXTLS(@"TDCPreferencesController[his-c1]") target:self action:@selector(transcriptCheckboxChanged:)];

	NSPopUpButton *transcriptFolderButton = [NSPopUpButton new];

	transcriptFolderButton.autoenablesItems = NO;

	[transcriptFolderButton addItemWithTitle:@" "];

	[transcriptFolderButton.menu addItem:[NSMenuItem separatorItem]];

	[transcriptFolderButton addItemWithTitle:TXTLS(@"TDCPreferencesController[his-f1]")];
	transcriptFolderButton.lastItem.tag = 2;

	[transcriptFolderButton addItemWithTitle:TXTLS(@"TDCPreferencesController[his-f2]")];
	transcriptFolderButton.lastItem.tag = 3;

	transcriptFolderButton.target = self;
	transcriptFolderButton.action = @selector(transcriptFolderChanged:);

	[transcriptFolderButton.widthAnchor constraintEqualToConstant:200].active = YES;

	NSStackView *transcriptRow = [NSStackView stackViewWithViews:@[transcriptCheckbox, transcriptFolderButton]];

	transcriptRow.alignment = NSLayoutAttributeFirstBaseline;
	transcriptRow.spacing = 8;

	NSTextField *transcriptNote = [self _noteWithString:TXTLS(@"TDCPreferencesController[his-n3]")];

	NSView *empty = [NSGridCell emptyContentView];

	NSGridView *grid = [NSGridView gridViewWithViews:@[
		@[[NSTextField labelWithString:TXTLS(@"TDCPreferencesController[his-l1]")], keepPeriodButton],
		@[empty, note],
		@[[NSTextField labelWithString:TXTLS(@"TDCPreferencesController[his-l2]")], sizeRow],
		@[empty, importRow],
		@[empty, importNote],
		@[[NSTextField labelWithString:TXTLS(@"TDCPreferencesController[his-l3]")], transcriptRow],
		@[empty, transcriptNote]
	]];

	grid.translatesAutoresizingMaskIntoConstraints = NO;

	grid.rowAlignment = NSGridRowAlignmentFirstBaseline;
	grid.rowSpacing = 8;
	grid.columnSpacing = 8;

	[grid columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;

	[grid rowAtIndex:2].topPadding = 14;
	[grid rowAtIndex:5].topPadding = 22;

	self.keepPeriodButton = keepPeriodButton;
	self.sizeLabel = sizeLabel;
	self.deleteButton = deleteButton;
	self.importButton = importButton;
	self.importStatusLabel = importStatusLabel;
	self.transcriptCheckbox = transcriptCheckbox;
	self.transcriptFolderButton = transcriptFolderButton;

	return grid;
}

- (NSTextField *)_noteWithString:(NSString *)string
{
	NSTextField *note = [NSTextField wrappingLabelWithString:string];

	note.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	note.textColor = [NSColor secondaryLabelColor];
	note.selectable = NO;

	note.preferredMaxLayoutWidth = 360;

	[note.widthAnchor constraintLessThanOrEqualToConstant:360].active = YES;

	return note;
}

#pragma mark -
#pragma mark State

- (void)_updateControls
{
	TPCMessageArchiveKeepPeriod keepPeriod = [TPCPreferences messageArchiveKeepPeriod];

	[self.keepPeriodButton selectItemWithTag:keepPeriod];

	BOOL archiveOn = (keepPeriod != TPCMessageArchiveKeepPeriodOff);

	BOOL busy = (self.importing || self.deleting);

	self.keepPeriodButton.enabled = (busy == NO);

	self.deleteButton.enabled = (busy == NO && self.messageCount > 0);

	self.importButton.enabled = (busy == NO && archiveOn);

	BOOL logTranscript = [TPCPreferences logToDisk];

	self.transcriptCheckbox.state = ((logTranscript) ? NSControlStateValueOn : NSControlStateValueOff);

	self.transcriptFolderButton.enabled = logTranscript;

	NSURL *transcriptFolderURL = [TPCPathInfo transcriptFolderURL];

	[self.transcriptFolderButton.menu itemWithTag:3].enabled = (transcriptFolderURL != nil);

	[self showFolder:transcriptFolderURL
	   inPopUpButton:self.transcriptFolderButton
		 placeholder:TXTLS(@"TDCPreferencesController[70s-c6]")];
}

/* "48,210 messages, 12.4 MB" */
- (void)_updateArchiveSize
{
	TLOMessageArchive *archive = sharedMessageArchive();

	[archive countMessagesOfServer:nil inView:nil completionHandler:^(NSUInteger count) {
		self.messageCount = count;

		NSString *size = [NSByteCountFormatter stringFromByteCount:(long long)archive.fileSize countStyle:NSByteCountFormatterCountStyleFile];

		if ([TPCPreferences messageArchiveKeepPeriod] == TPCMessageArchiveKeepPeriodOff && count == 0) {
			self.sizeLabel.stringValue = TXTLS(@"TDCPreferencesController[his-s3]");
		} else if (count == 1) {
			self.sizeLabel.stringValue = TXTLS(@"TDCPreferencesController[his-s2]", size);
		} else {
			NSString *countString = [NSNumberFormatter localizedStringFromNumber:@(count) numberStyle:NSNumberFormatterDecimalStyle];

			self.sizeLabel.stringValue = TXTLS(@"TDCPreferencesController[his-s1]", countString, size);
		}

		[self _updateControls];
	}];
}

#pragma mark -
#pragma mark Keep Period

- (void)keepPeriodChanged:(NSPopUpButton *)sender
{
	TPCMessageArchiveKeepPeriod oldPeriod = [TPCPreferences messageArchiveKeepPeriod];

	TPCMessageArchiveKeepPeriod newPeriod = sender.selectedTag;

	if (newPeriod == oldPeriod) {
		return;
	}

	/* Off deletes what's kept; a shorter period what's older */
	if (newPeriod == TPCMessageArchiveKeepPeriodOff && self.messageCount > 0) {
		NSString *countString = [NSNumberFormatter localizedStringFromNumber:@(self.messageCount) numberStyle:NSNumberFormatterDecimalStyle];

		[self _confirmWithTitle:TXTLS(@"TDCPreferencesController[his-o1]")
					informative:TXTLS(@"TDCPreferencesController[his-o2]", countString)
						 button:TXTLS(@"TDCPreferencesController[his-o3]")
					 completion:^(BOOL confirmed) {
						 if (confirmed) {
							 [self _changeKeepPeriodTo:newPeriod from:oldPeriod];
						 } else {
							 [self _updateControls];
						 }
					 }];

		return;
	}

	BOOL shorter = (newPeriod > 0 && oldPeriod != TPCMessageArchiveKeepPeriodOff && (oldPeriod == TPCMessageArchiveKeepPeriodForever || newPeriod < oldPeriod));

	if (shorter && self.messageCount > 0) {
		[self _confirmWithTitle:TXTLS(@"TDCPreferencesController[his-k1]", sender.titleOfSelectedItem)
					informative:TXTLS(@"TDCPreferencesController[his-k2]")
						 button:TXTLS(@"TDCPreferencesController[his-k3]")
					 completion:^(BOOL confirmed) {
						 if (confirmed) {
							 [self _changeKeepPeriodTo:newPeriod from:oldPeriod];
						 } else {
							 [self _updateControls];
						 }
					 }];

		return;
	}

	[self _changeKeepPeriodTo:newPeriod from:oldPeriod];
}

- (void)_changeKeepPeriodTo:(TPCMessageArchiveKeepPeriod)newPeriod from:(TPCMessageArchiveKeepPeriod)oldPeriod
{
	[TPCPreferences setMessageArchiveKeepPeriod:newPeriod];

	TLOMessageArchive *archive = sharedMessageArchive();

	archive.keepDays = newPeriod;

	if (newPeriod == TPCMessageArchiveKeepPeriodOff) {
		/* Turned on again, it starts with the scrollback */
		self.deleting = YES;

		[archive deleteAllMessagesImportingScrollbackAgain:YES completionHandler:^{
			self.deleting = NO;

			[self _updateArchiveSize];
		}];
	} else if (oldPeriod == TPCMessageArchiveKeepPeriodOff) {
		[mainWindow() maintainHistoricLog];
	}

	[self _updateControls];

	/* Removing older messages takes a moment */
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self _updateArchiveSize];
	});
}

- (void)_confirmWithTitle:(NSString *)title informative:(NSString *)informative button:(NSString *)button completion:(void (^)(BOOL confirmed))completion
{
	NSAlert *alert = [NSAlert new];

	alert.alertStyle = NSAlertStyleWarning;
	alert.messageText = title;
	alert.informativeText = informative;

	[alert addButtonWithTitle:button];
	[alert addButtonWithTitle:TXTLS(@"Prompts[qso-2g]")];

	alert.buttons.firstObject.hasDestructiveAction = YES;

	[alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
		completion(response == NSAlertFirstButtonReturn);
	}];
}

#pragma mark -
#pragma mark Delete Archive

- (void)deleteArchive:(nullable id)sender
{
	NSString *countString = [NSNumberFormatter localizedStringFromNumber:@(self.messageCount) numberStyle:NSNumberFormatterDecimalStyle];

	[self _confirmWithTitle:TXTLS(@"TDCPreferencesController[his-d1]")
				informative:TXTLS(@"TDCPreferencesController[his-d2]", countString)
					 button:TXTLS(@"TDCPreferencesController[his-d3]")
				 completion:^(BOOL confirmed) {
					 if (confirmed == NO) {
						 return;
					 }

					 self.deleting = YES;

					 self.importStatusLabel.stringValue = @"";

					 [self _updateControls];

					 [sharedMessageArchive() deleteAllMessagesImportingScrollbackAgain:NO completionHandler:^{
						 self.deleting = NO;

						 [self _updateArchiveSize];
					 }];
				 }];
}

#pragma mark -
#pragma mark Import Text Logs

- (void)importTextLogs:(nullable id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];

	panel.allowsMultipleSelection = NO;
	panel.canChooseDirectories = YES;
	panel.canChooseFiles = NO;
	panel.canCreateDirectories = NO;
	panel.resolvesAliases = YES;

	panel.directoryURL = [TPCPathInfo transcriptFolderURL];

	panel.message = TXTLS(@"TDCPreferencesController[his-i1]");
	panel.prompt = TXTLS(@"TDCPreferencesController[his-i2]");

	[panel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger returnCode) {
		if (returnCode != NSModalResponseOK) {
			return;
		}

		[self _importTextLogsInFolder:panel.URLs[0]];
	}];
}

- (void)_importTextLogsInFolder:(NSURL *)folderURL
{
	BOOL accessing = [folderURL startAccessingSecurityScopedResource];

	self.importing = YES;

	self.importStatusLabel.stringValue = TXTLS(@"TDCPreferencesController[his-i6]");

	[self _updateControls];

	[sharedMessageArchive() importTextLogsInFolder:folderURL progressHandler:^(NSUInteger filesDone, NSUInteger fileCount) {
		self.importStatusLabel.stringValue = TXTLS(@"TDCPreferencesController[his-i3]", filesDone, fileCount);
	} completionHandler:^(NSUInteger importedCount) {
		if (accessing) {
			[folderURL stopAccessingSecurityScopedResource];
		}

		self.importing = NO;

		if (importedCount == 0) {
			self.importStatusLabel.stringValue = TXTLS(@"TDCPreferencesController[his-i5]");
		} else {
			NSString *countString = [NSNumberFormatter localizedStringFromNumber:@(importedCount) numberStyle:NSNumberFormatterDecimalStyle];

			self.importStatusLabel.stringValue = TXTLS(@"TDCPreferencesController[his-i4]", countString);
		}

		[self _updateArchiveSize];
	}];
}

#pragma mark -
#pragma mark Text Logs

- (void)transcriptCheckboxChanged:(NSButton *)sender
{
	[TPCPreferences setLogToDisk:(sender.state == NSControlStateValueOn)];

	/* Turned off: closes the log files that are open */
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionLogTranscripts];

	[self _updateControls];
}

- (void)transcriptFolderChanged:(NSPopUpButton *)sender
{
	[self chooseFolderFromPopUpButton:sender completionBlock:^(NSData * _Nullable bookmark) {
		[TPCPathInfo setTranscriptFolderURL:bookmark];

		[TPCPreferences performReloadAction:TPCPreferencesReloadActionLogTranscripts];

		[self _updateControls];
	}];
}

@end

NS_ASSUME_NONNULL_END
