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

#import "IRCClientConfigPrivate.h"
#import "IRCClientPrivate.h"
#import "TLOLocalization.h"
#import "TDCServerPropertiesPanePrivate.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark Uploads

/* Where files go on this network if it offers no uploads: the
 address in Settings, none, or this server's own */
@interface TDCServerPropertiesUploadsPane ()
@property (nonatomic, strong) NSPopUpButton *uploadModeButton;
@property (nonatomic, strong) NSButton *uploadEditButton;
@property (nonatomic, strong) NSTextField *ownDestinationLabel;
@property (nonatomic, strong) NSGridRow *ownDestinationRow;
@property (nonatomic, copy, nullable) TLOUploadDestination *ownUploadDestination;
@end

@implementation TDCServerPropertiesUploadsPane

- (instancetype)init
{
	if ((self = [super init])) {
		[self buildView];

		return self;
	}

	return nil;
}

- (void)buildView
{
	NSView *view = [NSView new];

	/* Pinned to the sheet's content area with constraints */
	view.translatesAutoresizingMaskIntoConstraints = NO;

	NSTextField *label = [NSTextField labelWithString:TXTLS(@"TDCServerPropertiesSheet[upl-l1]")];

	NSPopUpButton *modeButton = [NSPopUpButton new];

	[modeButton addItemsWithTitles:@[
		TXTLS(@"TDCServerPropertiesSheet[upl-m1]"), // IRCClientUploadDestinationModeDefault
		TXTLS(@"TDCServerPropertiesSheet[upl-m2]"), // …Off
		TXTLS(@"TDCServerPropertiesSheet[upl-m3]") // …Own
	]];

	modeButton.target = self;
	modeButton.action = @selector(uploadModeChanged:);

	NSTextField *ownLabel = [NSTextField labelWithString:@""];

	ownLabel.textColor = [NSColor secondaryLabelColor];

	NSButton *editButton = [NSButton buttonWithTitle:TXTLS(@"TDCServerPropertiesSheet[upl-b1]") target:self action:@selector(editOwnUploadDestination:)];

	NSStackView *ownRow = [NSStackView stackViewWithViews:@[ownLabel, editButton]];

	ownRow.spacing = 8;

	NSTextField *note = [NSTextField wrappingLabelWithString:TXTLS(@"TDCServerPropertiesSheet[upl-n1]")];

	note.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	note.textColor = [NSColor secondaryLabelColor];

	[note.widthAnchor constraintLessThanOrEqualToConstant:340].active = YES;

	NSGridView *grid = [NSGridView gridViewWithViews:@[
		@[label, modeButton],
		@[[NSGridCell emptyContentView], ownRow],
		@[[NSGridCell emptyContentView], note]
	]];

	grid.translatesAutoresizingMaskIntoConstraints = NO;
	grid.rowSpacing = 8;
	grid.columnSpacing = 8;
	grid.rowAlignment = NSGridRowAlignmentFirstBaseline;

	[grid columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;

	[view addSubview:grid];

	[NSLayoutConstraint activateConstraints:@[
		[grid.topAnchor constraintEqualToAnchor:view.topAnchor constant:20],
		[grid.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
		[grid.leadingAnchor constraintGreaterThanOrEqualToAnchor:view.leadingAnchor constant:20],
		[grid.bottomAnchor constraintLessThanOrEqualToAnchor:view.bottomAnchor constant:-20]
	]];

	self.view = view;

	self.uploadModeButton = modeButton;
	self.uploadEditButton = editButton;
	self.ownDestinationLabel = ownLabel;
	self.ownDestinationRow = [grid rowAtIndex:1];
}

- (void)updateUploadRow
{
	BOOL own = (self.uploadModeButton.indexOfSelectedItem == IRCClientUploadDestinationModeOwn);

	TLOUploadDestination *destination = self.ownUploadDestination;

	self.ownDestinationRow.hidden = (own == NO);

	self.ownDestinationLabel.stringValue = ((destination) ? destination.name : TXTLS(@"TDCServerPropertiesSheet[upl-o1]"));

	self.uploadEditButton.title = ((destination) ? TXTLS(@"TDCServerPropertiesSheet[upl-b1]") : TXTLS(@"TDCServerPropertiesSheet[upl-b2]"));
}

- (void)uploadModeChanged:(nullable id)sender
{
	[self updateUploadRow];

	/* Own, but none yet: set it up now */
	if (self.uploadModeButton.indexOfSelectedItem == IRCClientUploadDestinationModeOwn && self.ownUploadDestination == nil) {
		[self editOwnUploadDestination:nil];
	}
}

- (void)editOwnUploadDestination:(nullable id)sender
{
	NSWindow *window = self.view.window;

	if (window == nil) {
		return;
	}

	[TDCUploadDestinationSheet editDestination:self.ownUploadDestination
									  inWindow:window
							   showsHideOption:NO
							   completionBlock:^(TLOUploadDestination * _Nullable destination) {
								   self.ownUploadDestination = destination;

								   /* Removed: back to the one in Preferences */
								   if (destination == nil) {
									   [self.uploadModeButton selectItemAtIndex:IRCClientUploadDestinationModeDefault];
								   }

								   [self updateUploadRow];
							   }];
}

- (void)loadFromConfig:(IRCClientConfig *)config
{
	NSDictionary *uploadDestination = config.uploadDestination;

	self.ownUploadDestination = ((uploadDestination) ? [TLOUploadDestination destinationWithPropertyList:uploadDestination secretsIdentifier:config.uniqueIdentifier] : nil);

	IRCClientUploadDestinationMode uploadMode = config.uploadDestinationMode;

	if (uploadMode > IRCClientUploadDestinationModeOwn || (uploadMode == IRCClientUploadDestinationModeOwn && self.ownUploadDestination == nil)) {
		uploadMode = IRCClientUploadDestinationModeDefault;
	}

	[self.uploadModeButton selectItemAtIndex:uploadMode];

	[self updateUploadRow];
}

- (void)saveToConfig:(IRCClientConfigMutable *)config
{
	/* The tokens go to the Keychain now, the rest with the server */
	TLOUploadDestination *ownUploadDestination = self.ownUploadDestination;

	if (ownUploadDestination) {
		[ownUploadDestination saveSecretsWithIdentifier:config.uniqueIdentifier];

		config.uploadDestination = ownUploadDestination.propertyList;
	} else {
		[TLOUploadDestination removeSecretsWithIdentifier:config.uniqueIdentifier];

		config.uploadDestination = nil;
	}

	IRCClientUploadDestinationMode uploadMode = self.uploadModeButton.indexOfSelectedItem;

	if (uploadMode == IRCClientUploadDestinationModeOwn && ownUploadDestination == nil) {
		uploadMode = IRCClientUploadDestinationModeDefault;
	}

	config.uploadDestinationMode = uploadMode;
}

@end

NS_ASSUME_NONNULL_END
