/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
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
#import "NSStringHelper.h"
#import "IRCChannelPrivate.h"
#import "IRCChannelMode.h"
#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "IRCTreeItemPrivate.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCWorldPrivate.h"
#import "TVCDockIconPrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogViewPrivate.h"
#import "TVCMainWindowAppearancePrivate.h"
#import "TVCMainWindowChannelViewPrivate.h"
#import "TVCMainWindowLoadingScreenPrivate.h"
#import "TVCMainWindowSplitViewPrivate.h"
#import "TVCMainWindowTextViewPrivate.h"
#import "TVCMainWindowTitlebarAccessoryViewPrivate.h"
#import "TVCServerListPrivate.h"
#import "TVCServerListAppearancePrivate.h"
#import "TVCServerListCellPrivate.h"
#import "TVCMemberListPrivate.h"
#import "TVCTextViewIRCFormattingMenuPrivate.h"
#import "TVCTextViewWithIRCFormatterPrivate.h"
#import "TPCApplicationInfo.h"
#import "TPCPreferencesLocal.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCThemeControllerPrivate.h"
#import "TPCTheme.h"
#import "TXGlobalModels.h"
#import "TXMasterControllerPrivate.h"
#import "TXMenuControllerPrivate.h"
#import "THOPluginDispatcherPrivate.h"
#import "TLOKeyEventHandler.h"
#import "TLOInputHistoryPrivate.h"
#import "TLOLocalization.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLONicknameCompletionStatusPrivate.h"
#import "TLONotificationControllerPrivate.h"
#import "TLOSpeechSynthesizerPrivate.h"
#import "TDCAlert.h"
#import "TDCLicenseManagerDialogPrivate.h"
#import "TVCInputCompletionPrivate.h"
#import "TVCMainWindowTextViewInternal.h"
#import "TLOUploadDestinationPrivate.h"
#import "TDCUploadDestinationSheetPrivate.h"
#import "TVCMainWindowInternal.h"

NS_ASSUME_NONNULL_BEGIN

/* File uploads: files go up one after another; a bar above the input
 field shows which and how far, with Cancel. Each link is put in the input
 field of the channel the files were meant for (its draft when another is
 selected). A paperclip button beside the input field chooses files, shown
 while the selected server offers uploads. Long pastes go the same
 way as a text file, and their link is sent; if they can't go, their text
 comes back to the input field. */

#define _uploadBarHeight		24.0

@interface TVCMainWindowUpload : NSObject
@property (nonatomic, copy) NSString *path;
@property (nonatomic, weak) IRCClient *client;
@property (nonatomic, weak) IRCTreeItem *item;
@property (nonatomic, copy, nullable) NSString *pastedText; // a long paste: path is its text file
@property (nonatomic, assign) IRCRemoteCommand command;
@end

@implementation TVCMainWindowUpload
@end

@implementation TVCMainWindow (Uploads)

#pragma mark -
#pragma mark Interface

- (void)setUpUploads
{
	if (self.uploadBar) {
		return;
	}

	[self setUpUploadBar];

	[self setUpUploadButton];

	self.uploadQueue = [NSMutableArray array];
}

/* Between the chat view and the reply bar: what sat on the reply bar's top sits on this one */
- (void)setUpUploadBar
{
	NSView *replyBar = self.replyBar;

	NSView *windowContentView = replyBar.superview;

	if (replyBar == nil || windowContentView == nil) {
		return;
	}

	NSView *bar = [NSView new];

	bar.translatesAutoresizingMaskIntoConstraints = NO;

	bar.hidden = YES;

	[windowContentView addSubview:bar];

	for (NSLayoutConstraint *constraint in [windowContentView.constraints copy]) {
		if (constraint.firstItem != replyBar || constraint.firstAttribute != NSLayoutAttributeTop ||
			constraint.secondAttribute != NSLayoutAttributeBottom || constraint.secondItem == nil)
		{
			continue;
		}

		NSLayoutConstraint *replacement =
		[NSLayoutConstraint constraintWithItem:bar
									 attribute:NSLayoutAttributeTop
									 relatedBy:NSLayoutRelationEqual
										toItem:constraint.secondItem
									 attribute:NSLayoutAttributeBottom
									multiplier:1.0
									  constant:0.0];

		replacement.priority = constraint.priority;

		constraint.active = NO;

		replacement.active = YES;
	}

	NSLayoutConstraint *heightConstraint = [bar.heightAnchor constraintEqualToConstant:0];

	[NSLayoutConstraint activateConstraints:@[
		[bar.bottomAnchor constraintEqualToAnchor:replyBar.topAnchor],
		[bar.leadingAnchor constraintEqualToAnchor:windowContentView.leadingAnchor],
		[bar.trailingAnchor constraintEqualToAnchor:windowContentView.trailingAnchor],
		heightConstraint
	]];

	/* ⇧ Uploading “photo.jpg” to files.example.org  ▓▓▓░░  ⓧ */
	NSImageView *icon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"arrow.up.circle" accessibilityDescription:nil]];

	icon.contentTintColor = [NSColor secondaryLabelColor];

	NSTextField *label = [NSTextField labelWithString:@""];

	label.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	label.textColor = [NSColor secondaryLabelColor];
	label.lineBreakMode = NSLineBreakByTruncatingMiddle;

	[label setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
	[label setContentHuggingPriority:(NSLayoutPriorityDefaultLow - 1) forOrientation:NSLayoutConstraintOrientationHorizontal];

	NSProgressIndicator *progress = [NSProgressIndicator new];

	progress.style = NSProgressIndicatorStyleBar;
	progress.controlSize = NSControlSizeSmall;
	progress.indeterminate = NO;
	progress.minValue = 0;
	progress.maxValue = 1;

	[progress.widthAnchor constraintEqualToConstant:120].active = YES;

	NSButton *cancelButton = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"xmark.circle.fill" accessibilityDescription:TXTLS(@"TVCMainWindow[upl-c1]")]
												target:self
												action:@selector(cancelUploadsButtonClicked:)];

	cancelButton.bordered = NO;
	cancelButton.contentTintColor = [NSColor tertiaryLabelColor];
	cancelButton.toolTip = TXTLS(@"TVCMainWindow[upl-c1]");

	NSStackView *stack = [NSStackView stackViewWithViews:@[icon, label, progress, cancelButton]];

	stack.translatesAutoresizingMaskIntoConstraints = NO;

	stack.spacing = 6;
	stack.edgeInsets = NSEdgeInsetsMake(0, 12, 0, 10);

	stack.distribution = NSStackViewDistributionFill;

	[bar addSubview:stack];

	[NSLayoutConstraint activateConstraints:@[
		[stack.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
		[stack.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
		[stack.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor]
	]];

	self.uploadBar = bar;
	self.uploadBarLabel = label;
	self.uploadBarProgress = progress;
	self.uploadBarHeightConstraint = heightConstraint;
}

/* A paperclip at the right end of the input field's row */
- (void)setUpUploadButton
{
	NSView *inputArea = self.inputTextField.contentView;

	NSView *background = nil;

	for (NSView *subview in inputArea.subviews) {
		if ([subview isKindOfClass:[TVCMainWindowTextViewBackground class]]) {
			background = subview;

			break;
		}
	}

	if (background == nil) {
		return;
	}

	NSLayoutConstraint *trailingConstraint = nil;

	for (NSLayoutConstraint *constraint in inputArea.constraints) {
		BOOL backgroundFirst = (constraint.firstItem == background && constraint.secondItem == inputArea);
		BOOL backgroundSecond = (constraint.secondItem == background && constraint.firstItem == inputArea);

		if ((backgroundFirst || backgroundSecond) &&
			constraint.firstAttribute == NSLayoutAttributeTrailing && constraint.secondAttribute == NSLayoutAttributeTrailing)
		{
			trailingConstraint = constraint;

			break;
		}
	}

	if (trailingConstraint == nil) {
		return;
	}

	NSButton *button = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"paperclip" accessibilityDescription:TXTLS(@"TVCMainWindow[upl-b1]")]
										  target:self
										  action:@selector(chooseFilesToUpload:)];

	button.translatesAutoresizingMaskIntoConstraints = NO;
	button.bordered = NO;
	button.contentTintColor = [NSColor secondaryLabelColor];
	button.toolTip = TXTLS(@"TVCMainWindow[upl-b1]");
	button.hidden = YES;

	[inputArea addSubview:button];

	CGFloat margin = ABS(trailingConstraint.constant);

	NSLayoutConstraint *besideButton = [background.trailingAnchor constraintEqualToAnchor:button.leadingAnchor constant:-6];

	[NSLayoutConstraint activateConstraints:@[
		[button.trailingAnchor constraintEqualToAnchor:inputArea.trailingAnchor constant:-margin],
		[button.centerYAnchor constraintEqualToAnchor:background.centerYAnchor]
	]];

	self.uploadButton = button;
	self.uploadButtonTrailingConstraint = trailingConstraint; // active while the button is hidden
	self.uploadButtonBesideConstraint = besideButton;
}

- (void)updateUploadButton
{
	NSButton *button = self.uploadButton;

	if (button == nil) {
		return;
	}

	IRCClient *client = self.selectedClient;

	/* Shown where uploads work, and elsewhere to offer setting them up unless that's turned off */
	BOOL hidden = (client == nil || (client.fileUploadsAvailable == NO && [TLOUploadDestination hidesUploadButtonWithoutDestination]));

	if (button.hidden == hidden) {
		return;
	}

	button.hidden = hidden;

	/* One, then the other: never both */
	if (hidden) {
		self.uploadButtonBesideConstraint.active = NO;
		self.uploadButtonTrailingConstraint.active = YES;
	} else {
		self.uploadButtonTrailingConstraint.active = NO;
		self.uploadButtonBesideConstraint.active = YES;
	}

	[self.inputTextField recalculateTextViewSizeForced];
}

- (void)updateUploadBar
{
	IRCFileUpload *upload = self.currentUpload;

	BOOL hidden = (upload == nil);

	if (hidden == NO) {
		NSString *text = TXTLS(@"TVCMainWindow[upl-l1]", upload.fileName, upload.address.host);

		NSUInteger total = (self.uploadsDone + self.uploadQueue.count + 1);

		if (total > 1) {
			text = [text stringByAppendingFormat:@" %@", TXTLS(@"TVCMainWindow[upl-l2]", (unsigned long)(self.uploadsDone + 1), (unsigned long)total)];
		}

		self.uploadBarLabel.stringValue = text;

		self.uploadBarProgress.doubleValue = upload.progress;
	}

	if (self.uploadBar.hidden == hidden) {
		return;
	}

	self.uploadBar.hidden = hidden;

	self.uploadBarHeightConstraint.constant = ((hidden) ? 0 : _uploadBarHeight);
}

#pragma mark -
#pragma mark Choosing

- (void)chooseFilesToUpload:(nullable id)sender
{
	IRCClient *client = self.selectedClient;

	IRCTreeItem *item = self.selectedItem;

	if (client == nil || item == nil) {
		return;
	}

	NSString *destination = client.fileUploadDestinationDescription;

	if (destination == nil) {
		[self offerUploadSetupForClient:client];

		return;
	}

	NSOpenPanel *openPanel = [NSOpenPanel openPanel];

	openPanel.canChooseFiles = YES;
	openPanel.canChooseDirectories = NO;
	openPanel.allowsMultipleSelection = YES;
	openPanel.resolvesAliases = YES;

	openPanel.prompt = TXTLS(@"TVCMainWindow[upl-p1]");
	openPanel.message = TXTLS(@"TVCMainWindow[upl-p2]", destination);

	[openPanel beginSheetModalForWindow:self completionHandler:^(NSModalResponse returnCode) {
		if (returnCode != NSModalResponseOK) {
			return;
		}

		NSMutableArray *paths = [NSMutableArray arrayWithCapacity:openPanel.URLs.count];

		for (NSURL *url in openPanel.URLs) {
			[paths addObject:url.path];
		}

		[self uploadFiles:paths onClient:client toItem:item];
	}];
}

#pragma mark -
#pragma mark Setting Up

/* No upload address applies: why, and setting one up (the server's own, or the one in Preferences) */
- (void)offerUploadSetupForClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if (client.config.uploadDestinationMode == IRCClientUploadDestinationModeOff) {
		[TDCAlert alertSheetWithWindow:self
								  body:TXTLS(@"TVCMainWindow[upl-s4]", client.networkNameAlt)
								 title:TXTLS(@"TVCMainWindow[upl-s1]")
						 defaultButton:TXTLS(@"Prompts[c7s-dq]")
					   alternateButton:nil
						   otherButton:nil
					   completionBlock:nil];

		return;
	}

	[TDCAlert alertSheetWithWindow:self
							  body:TXTLS(@"TVCMainWindow[upl-s2]", client.networkNameAlt)
							 title:TXTLS(@"TVCMainWindow[upl-s1]")
					 defaultButton:TXTLS(@"TVCMainWindow[upl-s3]")
				   alternateButton:TXTLS(@"Prompts[d7f-c4]")
					   otherButton:nil
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
					   if (buttonClicked != TDCAlertResponseDefault) {
						   return;
					   }

					   /* After the alert's sheet is gone */
					   XRPerformBlockAsynchronouslyOnMainQueue(^{
						   [self editUploadDestinationForClient:client];
					   });
				   }];
}

- (void)editUploadDestinationForClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if (client.config.uploadDestinationMode != IRCClientUploadDestinationModeOwn) {
		[TDCUploadDestinationSheet editGlobalDestinationInWindow:self completionBlock:nil];

		return;
	}

	[TDCUploadDestinationSheet editDestination:client.customUploadDestination
									  inWindow:self
							   showsHideOption:NO
							   completionBlock:^(TLOUploadDestination * _Nullable destination) {
								   NSString *identifier = client.config.uniqueIdentifier;

								   IRCClientConfigMutable *config = [client.config mutableCopy];

								   if (destination) {
									   [destination saveSecretsWithIdentifier:identifier];

									   config.uploadDestination = destination.propertyList;
								   } else {
									   [TLOUploadDestination removeSecretsWithIdentifier:identifier];

									   config.uploadDestination = nil;
								   }

								   [client updateConfig:config];

								   [self updateUploadButton];
							   }];
}

#pragma mark -
#pragma mark Queue

- (void)uploadFiles:(NSArray<NSString *> *)paths onClient:(IRCClient *)client toItem:(IRCTreeItem *)item
{
	NSParameterAssert(paths != nil);
	NSParameterAssert(client != nil);
	NSParameterAssert(item != nil);

	for (NSString *path in paths) {
		TVCMainWindowUpload *upload = [TVCMainWindowUpload new];

		upload.path = path;
		upload.client = client;
		upload.item = item;

		[self.uploadQueue addObject:upload];
	}

	if (self.currentUpload == nil) {
		self.uploadsDone = 0;

		[self startNextUpload];
	} else {
		[self updateUploadBar];
	}
}

- (void)sendText:(NSString *)text asLinkOnClient:(IRCClient *)client toItem:(IRCTreeItem *)item asCommand:(IRCRemoteCommand)command
{
	NSParameterAssert(text != nil);
	NSParameterAssert(client != nil);
	NSParameterAssert(item != nil);

	NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Textual Pastes/%@", [NSUUID UUID].UUIDString]];

	NSString *path = [folder stringByAppendingPathComponent:@"paste.txt"];

	BOOL written = ([RZFileManager() createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL] &&
					[text writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL]);

	TVCMainWindowUpload *upload = [TVCMainWindowUpload new];

	upload.path = path;
	upload.client = client;
	upload.item = item;
	upload.pastedText = text;
	upload.command = command;

	if (written == NO) {
		[self returnPastedTextOfUpload:upload];

		return;
	}

	[self.uploadQueue addObject:upload];

	if (self.currentUpload == nil) {
		self.uploadsDone = 0;

		[self startNextUpload];
	} else {
		[self updateUploadBar];
	}
}

/* A paste that didn't go: its text back where it was typed, its file gone */
- (void)returnPastedTextOfUpload:(TVCMainWindowUpload *)upload
{
	NSParameterAssert(upload != nil);

	NSString *text = upload.pastedText;

	if (text == nil) {
		return;
	}

	[RZFileManager() removeItemAtPath:upload.path.stringByDeletingLastPathComponent error:NULL];

	IRCTreeItem *item = upload.item;

	if (item == nil) {
		return;
	}

	if (item != self.selectedItem) {
		[self.inputHistoryManager appendText:text toDraftForTreeItem:item];

		return;
	}

	TVCMainWindowTextView *textField = self.inputTextField;

	[textField focus];

	if (textField.string.length == 0) {
		textField.stringValue = text;
	} else {
		[textField insertText:[@"\n" stringByAppendingString:text] replacementRange:NSMakeRange(textField.string.length, 0)];
	}
}

/* The queue given up (a failure, Cancel): pastes still in it come back */
- (void)discardUploadQueue
{
	NSArray *queue = [self.uploadQueue copy];

	[self.uploadQueue removeAllObjects];

	for (TVCMainWindowUpload *upload in queue) {
		[self returnPastedTextOfUpload:upload];
	}
}

- (void)startNextUpload
{
	TVCMainWindowUpload *next = self.uploadQueue.firstObject;

	if (next == nil) {
		self.currentUpload = nil;

		[self updateUploadBar];

		return;
	}

	[self.uploadQueue removeObjectAtIndex:0];

	IRCClient *client = next.client;

	IRCTreeItem *item = next.item;

	/* The network's address withdrawn (disconnected), or the user's own removed, since */
	IRCFileUpload *upload = ((next.pastedText) ? [client textUploadForPath:next.path] : [client fileUploadForPath:next.path]);

	if (upload == nil || item == nil) {
		[self returnPastedTextOfUpload:next];

		[self discardUploadQueue];

		self.currentUpload = nil;

		[self updateUploadBar];

		return;
	}

	self.currentUpload = upload;

	__weak typeof(self) weakSelf = self;

	upload.progressBlock = ^(IRCFileUpload *progressedUpload) {
		[weakSelf updateUploadBar];
	};

	[self updateUploadBar];

	[upload startWithCompletionBlock:^(IRCFileUpload *finishedUpload) {
		[weakSelf uploadFinished:finishedUpload ofQueuedUpload:next];
	}];
}

- (void)uploadFinished:(IRCFileUpload *)upload ofQueuedUpload:(TVCMainWindowUpload *)queuedUpload
{
	NSParameterAssert(upload != nil);
	NSParameterAssert(queuedUpload != nil);

	if (upload != self.currentUpload) {
		return;
	}

	self.uploadsDone += 1;

	NSURL *link = upload.link;

	IRCTreeItem *item = queuedUpload.item;

	IRCClient *client = queuedUpload.client;

	if (link && item) {
		if (queuedUpload.pastedText) {
			[RZFileManager() removeItemAtPath:queuedUpload.path.stringByDeletingLastPathComponent error:NULL];
		}

		/* A paste's link goes instead of its lines (if disconnected meanwhile,
		 it waits in the input field like a file's) */
		if (queuedUpload.pastedText && client.isLoggedIn) {
			[client inputText:link.absoluteString asCommand:queuedUpload.command destination:item];
		} else {
			[self insertUploadedLink:link.absoluteString forItem:item];
		}

		[self startNextUpload];

		return;
	}

	/* Cancelled, or failed: the rest stay where they are */
	BOOL wasPaste = (queuedUpload.pastedText != nil);

	[self returnPastedTextOfUpload:queuedUpload];

	[self discardUploadQueue];

	self.currentUpload = nil;

	[self updateUploadBar];

	if (upload.failureReason == nil) {
		return;
	}

	[TDCAlert alertSheetWithWindow:self
							  body:upload.failureReason
							 title:((wasPaste) ? TXTLS(@"TVCMainWindow[upl-e2]") : TXTLS(@"TVCMainWindow[upl-e1]", upload.fileName))
					 defaultButton:TXTLS(@"Prompts[c7s-dq]")
				   alternateButton:nil
					   otherButton:nil
				   completionBlock:nil];
}

- (void)cancelUploadsButtonClicked:(id)sender
{
	[self discardUploadQueue];

	[self.currentUpload cancel];
}

/* At the cursor, set apart by spaces; or at the end of that channel's draft */
- (void)insertUploadedLink:(NSString *)link forItem:(IRCTreeItem *)item
{
	NSParameterAssert(link != nil);
	NSParameterAssert(item != nil);

	if (item != self.selectedItem) {
		[self.inputHistoryManager appendText:link toDraftForTreeItem:item];

		return;
	}

	TVCMainWindowTextView *textField = self.inputTextField;

	NSString *text = textField.string;

	NSRange selection = textField.selectedRange;

	NSMutableString *insertion = [link mutableCopy];

	if (selection.location > 0 && selection.location <= text.length &&
		[[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[text characterAtIndex:(selection.location - 1)]] == NO)
	{
		[insertion insertString:@" " atIndex:0];
	}

	[insertion appendString:@" "];

	[textField focus];

	[textField insertText:insertion replacementRange:selection];
}

@end

NS_ASSUME_NONNULL_END
