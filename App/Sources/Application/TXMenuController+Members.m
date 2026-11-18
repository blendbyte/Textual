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
#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCChannelMode.h"
#import "IRCChannelUser.h"
#import "IRCExtrasPrivate.h"
#import "IRCISupportInfo.h"
#import "IRCUser.h"
#import "IRCWorldPrivate.h"
#import "TVCBasicTableView.h"
#import "TVCLogController.h"
#import "TVCLogViewPrivate.h"
#import "TVCLogViewInternalWK2.h"
#import "TVCMemberList.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowSearchPanelPrivate.h"
#import "TVCMainWindowSplitView.h"
#import "TVCMainWindowTextView.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLOLocalization.h"
#import "TLOpenLink.h"
#import "TDCAlert.h"
#import "TDCChannelInviteSheetPrivate.h"
#import "TDCChannelModifyModesSheetPrivate.h"
#import "TDCChannelModifyTopicSheetPrivate.h"
#import "TDCChannelPropertiesSheetPrivate.h"
#import "TDCChannelSpotlightControllerPrivate.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCInputPrompt.h"
#import "TDCLicenseManagerDialogPrivate.h"
#import "TDCNicknameColorSheetPrivate.h"
#import "TDCServerChangeNicknameSheetPrivate.h"
#import "TDCServerPropertiesSheetPrivate.h"
#import "TPCPathInfoPrivate.h"
#import "TPCPreferencesImportExport.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesReload.h"
#import "TPCPreferencesUserDefaults.h"
#import "TXMasterControllerPrivate.h"
#import "TXWindowControllerPrivate.h"

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
#import <Sparkle/Sparkle.h>
#endif
#import "TXMenuControllerInternal.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Kick Sheet

/* "Kick…" and "Ban and Kick…": the reason, and for a ban how long it lasts.
 Built in code, a sheet on the main window; hands back the reason and the
 duration in seconds (0: forever), or nothing when cancelled. */
@interface TXMenuControllerKickSheet : NSObject
@property (nonatomic, assign) BOOL ban;
@property (nonatomic, strong) NSWindow *sheetWindow;
@property (nonatomic, weak) NSWindow *parentWindow;
@property (nonatomic, strong) NSTextField *reasonField;
@property (nonatomic, strong, nullable) NSPopUpButton *durationPopup;
@property (nonatomic, strong, nullable) NSTextField *durationNote;
@property (nonatomic, copy, nullable) void (^completionHandler)(NSString *reason, NSTimeInterval duration);
@end

static TXMenuControllerKickSheet * _Nullable _kickSheet = nil;

@implementation TXMenuControllerKickSheet

- (void)beginForNicknames:(NSArray<NSString *> *)nicknames inChannel:(NSString *)channelName ban:(BOOL)ban window:(NSWindow *)window completionHandler:(void (^)(NSString *reason, NSTimeInterval duration))completionHandler
{
	self.ban = ban;
	self.parentWindow = window;
	self.completionHandler = completionHandler;

	/* Heading: "Kick bob from #textual", or "Ban and kick 3 people from #textual" */
	NSString *who = ((nicknames.count == 1) ? nicknames[0] : TXTLS(@"Prompts[kck-p1]", nicknames.count));

	NSTextField *heading = [NSTextField labelWithString:TXTLS((ban) ? @"Prompts[kck-h2]" : @"Prompts[kck-h1]", who, channelName)];

	heading.font = [NSFont boldSystemFontOfSize:[NSFont systemFontSize]];
	heading.lineBreakMode = NSLineBreakByTruncatingMiddle;

	NSTextField *reasonField = [NSTextField textFieldWithString:([TPCPreferences defaultKickMessage] ?: @"")];

	[reasonField.widthAnchor constraintEqualToConstant:300].active = YES;

	self.reasonField = reasonField;

	NSTextField *reasonLabel = [NSTextField labelWithString:TXTLS(@"Prompts[kck-r1]")];

	reasonLabel.alignment = NSTextAlignmentRight;

	NSMutableArray *rows = [NSMutableArray array];

	[rows addObject:@[reasonLabel, reasonField]];

	if (ban) {
		NSPopUpButton *durationPopup = [NSPopUpButton new];

		NSArray *durations = @[@(0), @(5 * 60), @(60 * 60), @(24 * 60 * 60)];
		NSArray *titles = @[@"Prompts[kck-d0]", @"Prompts[kck-d1]", @"Prompts[kck-d2]", @"Prompts[kck-d3]"];

		for (NSUInteger i = 0; i < durations.count; i++) {
			[durationPopup addItemWithTitle:TXTLS(titles[i])];

			durationPopup.lastItem.tag = [durations[i] integerValue];
		}

		durationPopup.target = self;
		durationPopup.action = @selector(onChangedDuration:);

		self.durationPopup = durationPopup;

		NSTextField *durationLabel = [NSTextField labelWithString:TXTLS(@"Prompts[kck-d]")];

		durationLabel.alignment = NSTextAlignmentRight;

		[rows addObject:@[durationLabel, durationPopup]];

		/* A timed ban is lifted by Textual itself: only while it is connected */
		NSTextField *durationNote = [NSTextField wrappingLabelWithString:TXTLS(@"Prompts[kck-n1]")];

		durationNote.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
		durationNote.textColor = [NSColor secondaryLabelColor];
		durationNote.preferredMaxLayoutWidth = 300;

		self.durationNote = durationNote;

		[rows addObject:@[[NSGridCell emptyContentView], durationNote]];
	}

	NSGridView *grid = [NSGridView gridViewWithViews:rows];

	grid.rowSpacing = 10;
	grid.columnSpacing = 8;
	grid.rowAlignment = NSGridRowAlignmentFirstBaseline;

	[grid columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;

	NSButton *cancelButton = [NSButton buttonWithTitle:TXTLS(@"Prompts[qso-2g]") target:self action:@selector(onCancel:)];

	cancelButton.keyEquivalent = @"\e";

	NSButton *okButton = [NSButton buttonWithTitle:TXTLS((ban) ? @"Prompts[kck-b2]" : @"Prompts[kck-b1]") target:self action:@selector(onOk:)];

	okButton.keyEquivalent = @"\r";

	NSStackView *buttons = [NSStackView stackViewWithViews:@[cancelButton, okButton]];

	buttons.spacing = 12;

	NSView *contentView = [NSView new];

	for (NSView *view in @[heading, grid, buttons]) {
		view.translatesAutoresizingMaskIntoConstraints = NO;

		[contentView addSubview:view];
	}

	[NSLayoutConstraint activateConstraints:@[
		[heading.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20],
		[heading.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
		[heading.trailingAnchor constraintLessThanOrEqualToAnchor:contentView.trailingAnchor constant:(-20)],

		[grid.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:16],
		[grid.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
		[grid.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:(-20)],

		[buttons.topAnchor constraintEqualToAnchor:grid.bottomAnchor constant:20],
		[buttons.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:(-20)],
		[buttons.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:(-20)]
	]];

	NSWindow *sheetWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 420, 160) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];

	sheetWindow.contentView = contentView;

	sheetWindow.initialFirstResponder = reasonField;

	self.sheetWindow = sheetWindow;

	[self updateDurationNote];

	[window beginSheet:sheetWindow completionHandler:nil];
}

- (void)updateDurationNote
{
	NSTextField *durationNote = self.durationNote;

	if (durationNote == nil) {
		return;
	}

	[self.durationPopup.superview.superview layoutSubtreeIfNeeded];

	durationNote.hidden = (self.durationPopup.selectedTag == 0);

	/* The note's row goes with it */
	NSGridView *grid = (NSGridView *)durationNote.superview;

	if ([grid isKindOfClass:[NSGridView class]]) {
		[grid cellForView:durationNote].row.hidden = durationNote.hidden;
	}

	NSWindow *sheetWindow = self.sheetWindow;

	[sheetWindow.contentView layoutSubtreeIfNeeded];

	[sheetWindow setContentSize:sheetWindow.contentView.fittingSize];
}

- (void)onChangedDuration:(id)sender
{
	[self updateDurationNote];
}

- (void)_end
{
	[self.parentWindow endSheet:self.sheetWindow];

	[self.sheetWindow orderOut:nil];

	self.completionHandler = nil;

	_kickSheet = nil;
}

- (void)onCancel:(id)sender
{
	[self _end];
}

- (void)onOk:(id)sender
{
	void (^completionHandler)(NSString *, NSTimeInterval) = self.completionHandler;

	NSString *reason = self.reasonField.stringValue.trim;

	NSTimeInterval duration = ((self.durationPopup) ? self.durationPopup.selectedTag : 0);

	[self _end];

	if (completionHandler) {
		completionHandler(reason, duration);
	}
}

@end

#pragma mark -

@implementation TXMenuController (Members)

#pragma mark -
#pragma mark Selected User(s)

- (NSArray<IRCChannelUser *> *)selectedMembers:(nullable id)sender
{
	return [self selectedMembers:sender returnStrings:NO];
}

- (NSArray<NSString *> *)selectedMembersNicknames:(nullable id)sender
{
	return [self selectedMembers:sender returnStrings:YES];
}

- (NSArray *)selectedMembers:(nullable id)sender returnStrings:(BOOL)returnStrings
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isActive == NO) {
		return @[];
	}

	/* Return a specific nickname for WebView events */
	NSString *pointedNickname = nil;

	if ([sender isKindOfClass:[NSMenuItem class]]) {
		pointedNickname = ((NSMenuItem *)sender).userInfo;
	} else {
		pointedNickname = self.pointedNickname;
	}

	if (pointedNickname) {
		if (returnStrings) {
			return @[pointedNickname];
		}

		IRCChannelUser *user = [c findMember:pointedNickname];

		if (user) {
			return @[user];
		}

		return @[];
	}

	/* If we did not have a specific nickname, then query
	 the user list for selected rows. */
	NSMutableArray *userArray = [NSMutableArray array];

	NSIndexSet *selectedRows = TVCMainWindow.currentWindow.memberList.selectedRowIndexes;

	[selectedRows enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		IRCChannelUser *user = [TVCMainWindow.currentWindow.memberList itemAtRow:index];

		if (returnStrings) {
			[userArray addObject:user.user.nickname];
		} else {
			[userArray addObject:user];
		}
	}];

	return [userArray copy];
}

- (void)deselectMembers:(nullable id)sender
{
	if ([sender isKindOfClass:[NSMenuItem class]]) {
		if (((NSMenuItem *)sender).userInfo.length > 0) {
			return; // Nothing to deselect when our sender used userInfo
		}
	}

	if (self.pointedNickname) {
		self.pointedNickname = nil;

		return;
	}

	[TVCMainWindow.currentWindow.memberList deselectAll:sender];
}

#pragma mark -
#pragma mark Ignores

- (void)memberAddIgnore:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	NSString *command = [NSString stringWithFormat:@"ignore %@", nicknames[0]];

	[u sendCommand:command completeTarget:YES target:c.name];
}

/* Follows the services account, whatever nickname or host they use next */
- (void)memberAddAccountIgnore:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count != 1) {
		return;
	}

	NSString *account = [u findUser:nicknames[0]].account;

	[self deselectMembers:sender];

	if (account.length == 0) {
		return;
	}

	[u sendCommand:[NSString stringWithFormat:@"ignore $a:%@", account] completeTarget:YES target:c.name];
}

- (void)memberRemoveIgnore:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	NSString *command = [NSString stringWithFormat:@"unignore %@", nicknames[0]];

	[u sendCommand:command completeTarget:YES target:c.name];
}

- (void)memberToggleInlineMediaIgnore:(nullable id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	NSArray<NSString *> *nicknames = [self selectedMembersNicknames:sender];

	[self deselectMembers:sender];

	if (nicknames.count != 1) {
		return;
	}

	NSString *nickname = nicknames[0];

	[u setIgnoresInlineMedia:([u ignoresInlineMediaFromNickname:nickname] == NO) fromNickname:nickname];
}

- (void)memberModifyIgnore:(nullable id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	NSArray<IRCChannelUser *> *nicknames = [self selectedMembers:sender];

	[self deselectMembers:sender];

	/* User's hostmask and other information can change between the point
	 the menu item is opened and the point the action is performed.
	 We therefore perform a new query for ignores when performing action. */
	NSString *hostmask = nicknames.firstObject.user.hostmask;

	if (nicknames.count != 1 || hostmask == nil) {
		return;
	}

	NSArray *userIgnores = [u findIgnoresForHostmask:hostmask];

	/* If we have more than one user ignore, then open
	 the address book instead of a specific ignore. */
	if (userIgnores.count == 1) {
		[self showServerPropertiesSheetForClient:u
								   withSelection:TDCServerPropertiesSheetSelectionNewIgnoreEntry
										 context:userIgnores[0]];
	} else {
		[self showServerPropertiesSheetForClient:u
								   withSelection:TDCServerPropertiesSheetSelectionAddressBook
										 context:nil];
	}
}

#pragma mark -
#pragma mark Members

- (void)memberInMemberListDoubleClicked:(nullable id)sender
{
	/* The member list's selection, never a nickname left from the chat view */
	self.pointedNickname = nil;

	NSInteger rowBeneathMouse = TVCMainWindow.currentWindow.memberList.rowBeneathMouse;

	if (rowBeneathMouse < 0) {
		return;
	}

	TXUserDoubleClickAction action = [TPCPreferences userDoubleClickOption];

	if (action == TXUserDoubleClickActionWhois) {
		[self whoisSelectedMembers:sender];
	} else if (action == TXUserDoubleClickActionPrivateMessage) {
		[self memberStartPrivateMessage:sender];
	} else if (action == TXUserDoubleClickActionInsertTextField) {
		[self memberInsertNameIntoTextField:sender];
	}
}

- (void)memberInChannelViewDoubleClicked:(nullable id)sender
{
	TXUserDoubleClickAction action = [TPCPreferences userDoubleClickOption];

	if (action == TXUserDoubleClickActionWhois) {
		[self whoisSelectedMembers:sender];
	} else if (action == TXUserDoubleClickActionPrivateMessage) {
		[self memberStartPrivateMessage:sender];
	} else if (action == TXUserDoubleClickActionInsertTextField) {
		[self memberInsertNameIntoTextField:sender];
	}

	/* For this double-click only: an action that returned early left it set */
	self.pointedNickname = nil;
}

- (void)memberInsertNameIntoTextField:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	TVCMainWindowTextView *textView = TVCMainWindow.currentWindow.inputTextField;

	NSRange selectedRange = textView.selectedRange;

	NSMutableString *stringToInsert = [NSMutableString string];

	if (selectedRange.location > 0) {
		UniChar previousCharacter = [textView.stringValue characterAtIndex:(selectedRange.location - 1)];

		if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:previousCharacter] == NO) {
			[stringToInsert appendString:@" "];
		}
	}

	NSString *nicknamesString = [nicknames componentsJoinedByString:@", "];

	[stringToInsert appendString:nicknamesString];

	NSString *completionSuffix = [TPCPreferences tabCompletionSuffix];

	if (completionSuffix != nil) {
		[stringToInsert appendString:completionSuffix];
	}

	[textView replaceCharactersInRange:selectedRange withString:stringToInsert];

	/* The inserted text: the selection it replaced could be longer */
	[textView resetFontColorInRange:NSMakeRange(selectedRange.location, stringToInsert.length)];

	[textView focus];
}

- (void)memberSendWhois:(nullable id)sender
{
	[self whoisSelectedMembers:sender];
}

- (void)whoisSelectedMembers:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendWhois:nickname];
	}

	[self deselectMembers:sender];
}

- (void)memberStartPrivateMessage:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	IRCChannel *lastQuery = nil;

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		IRCChannel *query = [u findChannelOrCreate:nickname isPrivateMessage:YES];

		[mainWindow() select:query];

		lastQuery = query;
	}

	/* Before another window comes forward: it clears the current window's list */
	[self deselectMembers:sender];

	/* From a separate window: the query opened in the main window, which then
	 comes forward instead of staying behind (a query in a window of its own
	 already came forward with select:) */
	if (lastQuery && [TVCMainWindow popOutWindowForItem:lastQuery] == nil) {
		[mainWindow() makeKeyAndOrderFront:nil];
	}
}

- (void)memberSendCTCPPing:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPPing:nickname];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPFinger:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPQuery:nickname command:@"FINGER" text:nil];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPTime:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPQuery:nickname command:@"TIME" text:nil];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPVersion:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPQuery:nickname command:@"VERSION" text:nil];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPUserinfo:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPQuery:nickname command:@"USERINFO" text:nil];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPClientInfo:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPQuery:nickname command:@"CLIENTINFO" text:nil];
	}

	[self deselectMembers:sender];
}

- (void)_processModeChange:(nullable id)sender usingCommand:(NSString *)modeCommand
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	[self deselectMembers:sender];

	NSString *nicknamesString = [nicknames componentsJoinedByString:@" "];

	NSString *command = [NSString stringWithFormat:@"%@ %@", modeCommand, nicknamesString];

	[u sendCommand:command completeTarget:YES target:c.name];
}

- (void)memberModeGiveOp:(nullable id)sender
{
	[self _processModeChange:sender usingCommand:@"OP"];
}

- (void)memberModeTakeOp:(nullable id)sender
{ 
	[self _processModeChange:sender usingCommand:@"DEOP"];
}

- (void)memberModeGiveOwner:(nullable id)sender
{
	[self _processModeChange:sender usingCommand:@"OWNER"];
}

- (void)memberModeTakeOwner:(nullable id)sender
{
	[self _processModeChange:sender usingCommand:@"DEOWNER"];
}

- (void)memberModeGiveHalfop:(nullable id)sender
{ 
	[self _processModeChange:sender usingCommand:@"HALFOP"];
}

- (void)memberModeTakeHalfop:(nullable id)sender
{ 
	[self _processModeChange:sender usingCommand:@"DEHALFOP"];
}

- (void)memberModeGiveVoice:(nullable id)sender
{ 
	[self _processModeChange:sender usingCommand:@"VOICE"];
}

- (void)memberModeTakeVoice:(nullable id)sender
{ 
	[self _processModeChange:sender usingCommand:@"DEVOICE"];
}

/* ⌥ with the menu item (clicked, not ⌥⌘K): at once, with the default kick message */
- (BOOL)_kickAtOnce
{
	NSEvent *event = NSApp.currentEvent;

	return (event.type != NSEventTypeKeyDown && (event.modifierFlags & NSEventModifierFlagOption) == NSEventModifierFlagOption);
}

/* Kick, or ban and kick, the people selected: the reason (and the ban's
 duration) from a sheet; a timed ban is lifted by a timed command, which
 ends when Textual disconnects */
- (void)_kickSelectedMembers:(nullable id)sender ban:(BOOL)ban
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	NSArray<NSString *> *nicknames = [self selectedMembersNicknames:sender];

	[self deselectMembers:sender];

	if (nicknames.count == 0) {
		return;
	}

	void (^kick)(NSString *, NSTimeInterval) = ^(NSString *reason, NSTimeInterval duration) {
		if (u.isLoggedIn == NO || c.isActive == NO) {
			return;
		}

		if (reason.length == 0) {
			reason = [TPCPreferences defaultKickMessage];
		}

		for (NSString *nickname in nicknames) {
			/* The mask KICKBAN bans, kept for lifting it */
			NSString *banMask = ([c findMember:nickname].user.banMask ?: nickname);

			NSString *command = [NSString stringWithFormat:@"%@ %@ %@", ((ban) ? @"KICKBAN" : @"KICK"), nickname, reason];

			[u sendCommand:command completeTarget:YES target:c.name];

			if (ban == NO || duration <= 0) {
				continue;
			}

			/* Once, through /timer (listed by /timer list) */
			NSString *unban = [NSString stringWithFormat:@"TIMER %lu 1 MODE %@ -b %@", (unsigned long)duration, c.name, banMask];

			[u sendCommand:unban completeTarget:YES target:c.name];
		}
	};

	if ([self _kickAtOnce]) {
		kick([TPCPreferences defaultKickMessage], 0);

		return;
	}

	NSWindow *window = TVCMainWindow.currentWindow;

	if (window == nil || _kickSheet != nil) {
		return;
	}

	_kickSheet = [TXMenuControllerKickSheet new];

	[_kickSheet beginForNicknames:nicknames inChannel:c.name ban:ban window:window completionHandler:kick];
}

- (void)memberKickFromChannel:(nullable id)sender
{
	[self _kickSelectedMembers:sender ban:NO];
}

/* Search Everywhere with from:nickname */
- (void)memberSearchMessages:(nullable id)sender
{
	NSArray<NSString *> *nicknames = [self selectedMembersNicknames:sender];

	[self deselectMembers:sender];

	TVCMainWindow *window = TVCMainWindow.currentWindow;

	if (nicknames.count != 1 || window == nil) {
		return;
	}

	[window showSearchPanelWithScope:TVCMainWindowSearchScopeEverywhere text:[NSString stringWithFormat:@"from:%@ ", nicknames[0]]];
}

/* Quieted: stays, can't speak (the quiet list, +q where it isn't a status) */
- (void)memberQuietInChannel:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCommand:[NSString stringWithFormat:@"QUIET %@", nickname] completeTarget:YES target:c.name];
	}

	[self deselectMembers:sender];
}

- (void)memberBanFromChannel:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		NSString *command = [NSString stringWithFormat:@"BAN %@", nickname];

		[u sendCommand:command completeTarget:YES target:c.name];
	}

	[self deselectMembers:sender];
}

/* Banned by services account, which a new nickname or address doesn't escape */
- (void)memberBanAccountFromChannel:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		NSString *account = [u findUser:nickname].account;

		if (account.length == 0) {
			continue;
		}

		NSString *mask = [u.supportInfo accountBanMaskForAccount:account];

		if (mask == nil) {
			continue;
		}

		[u sendCommand:[NSString stringWithFormat:@"MODE %@ +b %@", c.name, mask] completeTarget:NO target:nil];
	}

	[self deselectMembers:sender];
}

- (void)memberKickbanFromChannel:(nullable id)sender
{
	[self _kickSelectedMembers:sender ban:YES];
}

- (void)memberKillFromServer:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		NSString *command = [NSString stringWithFormat:@"KILL %@ %@", nickname, [TPCPreferences IRCopDefaultKillMessage]];

		[u sendCommand:command];
	}

	[self deselectMembers:sender];
}

- (void)memberBanFromServer:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		if ([u nicknameIsMyself:nickname]) {
			[u printDebugInformation:TXTLS(@"IRC[0r1-5l]", u.serverAddress) inChannel:c];

			continue;
		}

		NSString *command = [NSString stringWithFormat:@"GLINE %@ %@", nickname, [TPCPreferences IRCopDefaultGlineMessage]];

		[u sendCommand:command];
	}

	[self deselectMembers:sender];
}

- (void)memberShunOnServer:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		NSString *command = [NSString stringWithFormat:@"SHUN %@ %@", nickname, [TPCPreferences IRCopDefaultShunMessage]];

		[u sendCommand:command];
	}

	[self deselectMembers:sender];
}

- (void)_showSetVhostPromptOpenDialog:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	void (^promptCompletionBlock)(NSString *) = ^(NSString *resultString)
	{
		NSString *vhost = resultString.trimAndGetFirstToken;

		if (vhost.length == 0) {
			return;
		}

		for (NSString *nickname in nicknames) {
			NSString *command = [NSString stringWithFormat:@"hs setall %@ %@", nickname, vhost];

			[u sendCommand:command completeTarget:NO target:nil];
		}
	};

	NSString *vhost = nil;

	TVCAlertResponseButton response =
	[TDCInputPrompt promptWithMessage:TXTLS(@"Prompts[2mx-jf]")
								title:TXTLS(@"Prompts[7gr-e4]")
						defaultButton:TXTLS(@"Prompts[c7s-dq]")
					  alternateButton:TXTLS(@"Prompts[qso-2g]")
						prefillString:nil
						 resultString:&vhost];

	if (response == TVCAlertResponseButtonFirst) {
		promptCompletionBlock(vhost);
	}
}

- (void)showSetVhostPrompt:(nullable id)sender
{
	[self _showSetVhostPromptOpenDialog:sender];
}

#pragma mark -
#pragma mark File Transfers

- (void)showFileTransfersWindow:(nullable id)sender
{
	[self.fileTransferController show:YES restorePosition:YES];
}

- (void)memberSendFileRequest:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	NSOpenPanel *openPanel = [NSOpenPanel openPanel];

	openPanel.allowsMultipleSelection = YES;
	openPanel.canChooseDirectories = NO;
	openPanel.canChooseFiles = YES;
	openPanel.canCreateDirectories = NO;
	openPanel.resolvesAliases = YES;

	[openPanel beginSheetModalForWindow:TVCMainWindow.currentWindow completionHandler:^(NSInteger returnCode) {
		if (returnCode != NSModalResponseOK) {
			return;
		}

		/* Disconnected (or deleted) while the panel was open */
		if (u.isLoggedIn == NO) {
			return;
		}

		for (NSString *nickname in nicknames) {
			for (NSURL *path in openPanel.URLs) {
				[self.fileTransferController addSenderForClient:u nickname:nickname path:path.path autoOpen:YES];
			}
		}
	}];
}

- (void)answerDroppedFiles:(NSArray<NSString *> *)files
{
	NSParameterAssert(files != nil);

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil) {
		return;
	}

	[self answerDroppedFiles:files onClient:u inChannel:c];
}

- (void)answerDroppedFiles:(NSArray<NSString *> *)files onClient:(IRCClient *)u inChannel:(nullable IRCChannel *)c
{
	NSParameterAssert(files != nil);
	NSParameterAssert(u != nil);

	NSString *recipient = ((c.isPrivateMessage) ? c.name : nil);

	if ([self offerToUploadFiles:files recipient:recipient onClient:u inChannel:c]) {
		return;
	}

	[self answerDroppedFiles:files recipient:recipient onClient:u inChannel:c];
}

/* Where the network offers uploads: Upload, and DCC (a private
 message) or Insert Path as the other choice. NO when it doesn't. */
- (BOOL)offerToUploadFiles:(NSArray<NSString *> *)files recipient:(nullable NSString *)recipient onClient:(IRCClient *)client inChannel:(nullable IRCChannel *)channel
{
	NSParameterAssert(files != nil);
	NSParameterAssert(client != nil);

	NSString *destination = client.fileUploadDestinationDescription;

	NSArray *sendableFiles = [TDCFileTransferDialog sendableFilePaths:files];

	if (destination == nil || sendableFiles.count == 0) {
		return NO;
	}

	IRCTreeItem *item = ((channel) ?: client);

	NSString *title = nil;

	if (sendableFiles.count == 1) {
		title = TXTLS(@"Prompts[d7f-u1]", [sendableFiles.firstObject lastPathComponent]);
	} else {
		title = TXTLS(@"Prompts[d7f-u2]", (unsigned long)sendableFiles.count);
	}

	NSString *body = TXTLS(@"Prompts[d7f-u3]", destination);

	if (sendableFiles.count < files.count) {
		body = [body stringByAppendingFormat:@" %@", TXTLS(@"Prompts[d7f-s4]")];
	}

	NSString *otherButton = ((recipient) ? TXTLS(@"Prompts[d7f-u5]") : TXTLS(@"Prompts[d7f-p1]")); // Send by DCC, Insert Path

	[TDCAlert alertSheetWithWindow:TVCMainWindow.currentWindow
							  body:body
							 title:title
					 defaultButton:TXTLS(@"Prompts[d7f-u4]") // Upload
				   alternateButton:TXTLS(@"Prompts[d7f-c4]") // Cancel
					   otherButton:otherButton
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
					   if (buttonClicked == TDCAlertResponseDefault) {
						   [TVCMainWindow.currentWindow uploadFiles:sendableFiles onClient:client toItem:item];
					   } else if (buttonClicked == TDCAlertResponseOther) {
						   if (recipient) {
							   [self sendDroppedFiles:sendableFiles to:recipient onClient:client];
						   } else {
							   [self insertDroppedFilePaths:files];
						   }
					   }
				   }];

	return YES;
}

- (void)answerPastedPictureOnPasteboard:(NSPasteboard *)pasteboard
{
	NSParameterAssert(pasteboard != nil);

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil) {
		return;
	}

	NSString *destination = u.fileUploadDestinationDescription;

	if (destination == nil) {
		[TVCMainWindow.currentWindow offerUploadSetupForClient:u];

		return;
	}

	/* A PNG of it, named after now */
	NSData *data = [pasteboard dataForType:NSPasteboardTypePNG];

	if (data == nil) {
		NSImage *image = [[NSImage alloc] initWithPasteboard:pasteboard];

		NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];

		data = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
	}

	if (data == nil) {
		return;
	}

	NSDateFormatter *formatter = [NSDateFormatter new];

	formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
	formatter.dateFormat = @"yyyy-MM-dd 'at' HH.mm.ss";

	NSString *folder = [[NSTemporaryDirectory() stringByAppendingPathComponent:TVCMainWindowPastedPicturesFolderName] stringByAppendingPathComponent:[NSUUID UUID].UUIDString];

	if ([RZFileManager() createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL] == NO) {
		return;
	}

	NSString *path = [folder stringByAppendingPathComponent:TXTLS(@"Prompts[d7f-i3]", [formatter stringFromDate:[NSDate date]])];

	if ([data writeToFile:path atomically:YES] == NO) {
		return;
	}

	IRCTreeItem *item = ((c) ?: u);

	[TDCAlert alertSheetWithWindow:TVCMainWindow.currentWindow
							  body:TXTLS(@"Prompts[d7f-u3]", destination)
							 title:TXTLS(@"Prompts[d7f-i4]")
					 defaultButton:TXTLS(@"Prompts[d7f-u4]") // Upload
				   alternateButton:TXTLS(@"Prompts[d7f-c4]") // Cancel
					   otherButton:nil
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
					   if (buttonClicked == TDCAlertResponseDefault) {
						   [TVCMainWindow.currentWindow uploadFiles:@[path] onClient:u toItem:item];
					   } else {
						   [RZFileManager() removeItemAtPath:folder error:NULL];
					   }
				   }];
}

- (void)memberSendDroppedFiles:(NSArray<NSString *> *)files row:(NSUInteger)row
{
	NSParameterAssert(files != nil);

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || c.isChannel == NO) {
		return;
	}

	IRCChannelUser *member = [TVCMainWindow.currentWindow.memberList itemAtRow:row];

	if (member == nil) {
		return;
	}

	[self sendDroppedFiles:files toMember:member onClient:u inChannel:c];
}

- (void)sendDroppedFiles:(NSArray<NSString *> *)files toMember:(IRCChannelUser *)member onClient:(IRCClient *)u inChannel:(nullable IRCChannel *)c
{
	NSParameterAssert(files != nil);
	NSParameterAssert(member != nil);
	NSParameterAssert(u != nil);

	if (c == nil || c.isChannel == NO) {
		return;
	}

	[self answerDroppedFiles:files recipient:member.user.nickname onClient:u inChannel:c];
}

- (void)answerDroppedFiles:(NSArray<NSString *> *)files recipient:(nullable NSString *)recipient onClient:(IRCClient *)client inChannel:(nullable IRCChannel *)channel
{
	NSParameterAssert(files != nil);
	NSParameterAssert(client != nil);

	if (files.count == 0) {
		return;
	}

	NSArray *sendableFiles = [TDCFileTransferDialog sendableFilePaths:files];

	TDCFileTransferDropAnswer answer =
	[TDCFileTransferDialog dropAnswerForSendableFileCount:sendableFiles.count
												recipient:recipient
												connected:client.isLoggedIn];

	NSString *title = nil;
	NSString *body = nil;

	NSString *defaultButton = TXTLS(@"Prompts[d7f-p1]"); // Insert Path
	NSString *alternateButton = TXTLS(@"Prompts[d7f-c4]"); // Cancel
	NSString *otherButton = nil;

	switch (answer) {
		case TDCFileTransferDropAnswerSend:
		{
			if (sendableFiles.count == 1) {
				title = TXTLS(@"Prompts[d7f-s1]", [sendableFiles.firstObject lastPathComponent], recipient);
			} else {
				title = TXTLS(@"Prompts[d7f-s2]", (unsigned long)sendableFiles.count, recipient);
			}

			body = TXTLS(@"Prompts[d7f-s3]", recipient);

			if (sendableFiles.count < files.count) {
				body = [body stringByAppendingFormat:@" %@", TXTLS(@"Prompts[d7f-s4]")];
			}

			defaultButton = TXTLS(@"Prompts[d7f-s5]"); // Send
			otherButton = TXTLS(@"Prompts[d7f-p1]"); // Insert Path

			break;
		}
		case TDCFileTransferDropAnswerNoRecipient:
		{
			if (channel == nil) {
				title = TXTLS(@"Prompts[d7f-n2]");
			} else {
				title = TXTLS(@"Prompts[d7f-n1]");
			}

			body = TXTLS(@"Prompts[d7f-n3]");

			/* Uploads would do: offered unless turned off */
			if (client.fileUploadsAvailable == NO && client.config.uploadDestinationMode != IRCClientUploadDestinationModeOff) {
				body = [body stringByAppendingFormat:@" %@", TXTLS(@"Prompts[d7f-n4]")];

				otherButton = TXTLS(@"TVCMainWindow[upl-s3]"); // Set Up Upload Address…
			}

			break;
		}
		case TDCFileTransferDropAnswerNothingToSend:
		{
			title = TXTLS(@"Prompts[d7f-f1]");

			body = TXTLS(@"Prompts[d7f-f2]");

			break;
		}
		case TDCFileTransferDropAnswerNotConnected:
		{
			title = TXTLS(@"Prompts[d7f-o1]", client.networkNameAlt);

			body = TXTLS(@"Prompts[d7f-o2]", recipient);

			break;
		}
	}

	[TDCAlert alertSheetWithWindow:TVCMainWindow.currentWindow
							  body:body
							 title:title
					 defaultButton:defaultButton
				   alternateButton:alternateButton
					   otherButton:otherButton
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
					   BOOL insertPath = ((answer == TDCFileTransferDropAnswerSend) ?
										  (buttonClicked == TDCAlertResponseOther) :
										  (buttonClicked == TDCAlertResponseDefault));

					   if (insertPath) {
						   [self insertDroppedFilePaths:files];
					   } else if (answer == TDCFileTransferDropAnswerNoRecipient && buttonClicked == TDCAlertResponseOther) {
						   XRPerformBlockAsynchronouslyOnMainQueue(^{
							   [TVCMainWindow.currentWindow editUploadDestinationForClient:client];
						   });
					   } else if (answer == TDCFileTransferDropAnswerSend && buttonClicked == TDCAlertResponseDefault) {
						   [self sendDroppedFiles:sendableFiles to:recipient onClient:client];
					   }
				   }];
}

- (void)insertDroppedFilePaths:(NSArray<NSString *> *)files
{
	NSParameterAssert(files != nil);

	TVCMainWindowTextView *textField = TVCMainWindow.currentWindow.inputTextField;

	[textField focus];

	[textField insertText:[files componentsJoinedByString:@" "] replacementRange:textField.selectedRange];
}

- (void)sendDroppedFiles:(NSArray<NSString *> *)files to:(NSString *)nickname onClient:(IRCClient *)client
{
	NSParameterAssert(files != nil);
	NSParameterAssert(nickname != nil);
	NSParameterAssert(client != nil);

	/* Disconnected while the sheet was open */
	if (client.isLoggedIn == NO) {
		return;
	}

	for (NSString *file in files) {
		[self.fileTransferController addSenderForClient:client nickname:nickname path:file autoOpen:YES];
	}
}

@end

NS_ASSUME_NONNULL_END
