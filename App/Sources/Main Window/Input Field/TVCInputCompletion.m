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
#import "TPCPreferencesLocalPrivate.h"
#import "TPCResourceManager.h"
#import "THOPluginManagerPrivate.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "IRCChannelMemberList.h"
#import "IRCChannelUserPrivate.h"
#import "IRCAliasPrivate.h"
#import "IRCCommandIndex.h"
#import "IRCUser.h"
#import "TLOKeyEventHandler.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowTextView.h"
#import "TVCInputCompletionPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* At most this many suggestions, this many shown at once */
#define _maximumItems			50
#define _visibleRows			8
#define _rowHeight				24.0
#define _listWidth				440.0

#pragma mark -

@interface TVCInputCompletionQuery ()
@property (nonatomic, assign, readwrite) TVCInputCompletionKind kind;
@property (nonatomic, assign, readwrite) NSRange range;
@property (nonatomic, copy, readwrite) NSString *text;
@end

@implementation TVCInputCompletionQuery
@end

@interface TVCInputCompletionItem ()
@property (nonatomic, assign, readwrite) TVCInputCompletionKind kind;
@property (nonatomic, copy, readwrite) NSString *value;
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, copy, readwrite, nullable) NSString *detail;
@end

@implementation TVCInputCompletionItem

+ (instancetype)itemWithKind:(TVCInputCompletionKind)kind value:(NSString *)value title:(NSString *)title detail:(nullable NSString *)detail
{
	NSParameterAssert(value != nil);
	NSParameterAssert(title != nil);

	TVCInputCompletionItem *item = [TVCInputCompletionItem new];

	item.kind = kind;
	item.value = value;
	item.title = title;
	item.detail = detail;

	return item;
}

@end

#pragma mark -

@implementation TVCInputCompletion

+ (nullable TVCInputCompletionQuery *)queryInString:(NSString *)string selectedRange:(NSRange)selectedRange
{
	NSParameterAssert(string != nil);

	if (selectedRange.length > 0 || selectedRange.location > string.length) {
		return nil;
	}

	NSUInteger caret = selectedRange.location;

	NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];

	/* Only at the end of a word */
	if (caret < string.length && [whitespace characterIsMember:[string characterAtIndex:caret]] == NO) {
		return nil;
	}

	NSUInteger start = caret;

	while (start > 0 && [whitespace characterIsMember:[string characterAtIndex:(start - 1)]] == NO) {
		start -= 1;
	}

	if (start == caret) {
		return nil;
	}

	unichar trigger = [string characterAtIndex:start];

	NSRange range = NSMakeRange(start, (caret - start));

	NSString *text = [string substringWithRange:NSMakeRange((start + 1), (caret - start - 1))];

	TVCInputCompletionQuery *query = [TVCInputCompletionQuery new];

	query.range = range;
	query.text = text;

	switch (trigger) {
		case '@':
		{
			/* "@@" or an address like "@host@example" */
			if ([text containsString:@"@"]) {
				return nil;
			}

			query.kind = TVCInputCompletionKindNickname;

			return query;
		}
		case '#':
		{
			query.kind = TVCInputCompletionKindChannel;

			return query;
		}
		case '/':
		{
			/* Only a command at the start of the message; "//" sends a "/" */
			if (start != 0 || [text containsString:@"/"]) {
				return nil;
			}

			query.kind = TVCInputCompletionKindCommand;

			return query;
		}
		case ':':
		{
			/* Two letters at least, so ":)" ":D" and "alice:" never open it */
			if (text.length < 2) {
				return nil;
			}

			NSCharacterSet *nameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789_+-"];

			if ([text.lowercaseString onlyContainsCharactersFromCharacterSet:nameCharacters] == NO) {
				return nil;
			}

			query.kind = TVCInputCompletionKindEmoji;

			return query;
		}
	}

	return nil;
}

+ (NSString *)replacementForItem:(TVCInputCompletionItem *)item query:(TVCInputCompletionQuery *)query inString:(NSString *)string nicknameSuffix:(nullable NSString *)nicknameSuffix
{
	NSParameterAssert(item != nil);
	NSParameterAssert(query != nil);
	NSParameterAssert(string != nil);

	NSString *replacement = nil;

	BOOL addSpace = YES;

	switch (item.kind) {
		case TVCInputCompletionKindNickname:
		{
			replacement = item.value;

			/* "alice: " at the start, as Tab completion does */
			if (query.range.location == 0 && nicknameSuffix.length > 0) {
				replacement = [replacement stringByAppendingString:nicknameSuffix];

				addSpace = ([nicknameSuffix hasSuffix:@" "] == NO);
			}

			break;
		}
		case TVCInputCompletionKindChannel:
		case TVCInputCompletionKindEmoji:
		{
			replacement = item.value;

			break;
		}
		case TVCInputCompletionKindCommand:
		{
			replacement = [@"/" stringByAppendingString:item.value];

			break;
		}
	}

	NSUInteger end = NSMaxRange(query.range);

	if (addSpace && (end >= string.length || [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[string characterAtIndex:end]] == NO)) {
		replacement = [replacement stringByAppendingString:@" "];
	}

	return replacement;
}

+ (NSArray<NSString *> *)names:(NSArray<NSString *> *)names matching:(NSString *)text limit:(NSUInteger)limit
{
	NSParameterAssert(names != nil);
	NSParameterAssert(text != nil);

	if (text.length == 0) {
		return [names subarrayWithRange:NSMakeRange(0, MIN(limit, names.count))];
	}

	NSMutableArray<NSString *> *prefixMatches = [NSMutableArray array];
	NSMutableArray<NSString *> *otherMatches = [NSMutableArray array];

	for (NSString *name in names) {
		NSRange match = [name rangeOfString:text options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch)];

		if (match.location == 0) {
			[prefixMatches addObject:name];
		} else if (match.location != NSNotFound) {
			[otherMatches addObject:name];
		}
	}

	[prefixMatches addObjectsFromArray:otherMatches];

	return [prefixMatches subarrayWithRange:NSMakeRange(0, MIN(limit, prefixMatches.count))];
}

/* [emoji, "names", "tags"] from gemoji */
+ (NSArray<NSArray<NSString *> *> *)_emojiList
{
	static NSArray *emojiList = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSURL *url = [RZMainBundle() URLForResource:@"EmojiShortcodes" withExtension:@"json"];

		NSData *data = ((url) ? [NSData dataWithContentsOfURL:url] : nil);

		id json = ((data) ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil);

		emojiList = (([json isKindOfClass:[NSArray class]]) ? json : @[]);
	});

	return emojiList;
}

+ (NSArray<TVCInputCompletionItem *> *)emojiMatching:(NSString *)text limit:(NSUInteger)limit
{
	NSParameterAssert(text != nil);

	text = text.lowercaseString;

	NSMutableArray<TVCInputCompletionItem *> *nameStarts = [NSMutableArray array];
	NSMutableArray<TVCInputCompletionItem *> *nameContains = [NSMutableArray array];
	NSMutableArray<TVCInputCompletionItem *> *tagStarts = [NSMutableArray array];

	for (NSArray *entry in [self _emojiList]) {
		if ([entry isKindOfClass:[NSArray class]] == NO || entry.count < 3) {
			continue;
		}

		NSString *emoji = entry[0];

		NSArray<NSString *> *aliases = [entry[1] componentsSeparatedByString:@" "];
		NSArray<NSString *> *tags = [entry[2] componentsSeparatedByString:@" "];

		NSString *startingAlias = nil;
		NSString *containingAlias = nil;

		for (NSString *alias in aliases) {
			if ([alias hasPrefix:text]) {
				startingAlias = alias;

				break;
			}

			if (containingAlias == nil && [alias containsString:text]) {
				containingAlias = alias;
			}
		}

		NSString *alias = (startingAlias ?: containingAlias ?: aliases.firstObject);

		if (alias.length == 0) {
			continue;
		}

		TVCInputCompletionItem *item =
		[TVCInputCompletionItem itemWithKind:TVCInputCompletionKindEmoji
									   value:emoji
									   title:[NSString stringWithFormat:@"%@  :%@:", emoji, alias]
									  detail:nil];

		if (startingAlias) {
			[nameStarts addObject:item];
		} else if (containingAlias) {
			[nameContains addObject:item];
		} else {
			for (NSString *tag in tags) {
				if ([tag hasPrefix:text]) {
					[tagStarts addObject:item];

					break;
				}
			}
		}
	}

	/* Shorter names first among those that start the same: ":heart" → ❤️ before 💓 */
	[nameStarts sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(TVCInputCompletionItem *item1, TVCInputCompletionItem *item2) {
		NSUInteger length1 = item1.title.length;
		NSUInteger length2 = item2.title.length;

		return ((length1 < length2) ? NSOrderedAscending : ((length1 > length2) ? NSOrderedDescending : NSOrderedSame));
	}];

	[nameStarts addObjectsFromArray:nameContains];
	[nameStarts addObjectsFromArray:tagStarts];

	return [nameStarts subarrayWithRange:NSMakeRange(0, MIN(limit, nameStarts.count))];
}

+ (nullable NSString *)descriptionForCommand:(NSString *)command
{
	NSParameterAssert(command != nil);

	NSString *key = [NSString stringWithFormat:@"IRC[cmd-%@]", command.lowercaseString];

	NSString *description = TXTLS(key);

	/* A missing string comes back as its key */
	if (description.length == 0 || [description isEqualToString:key] || [description hasPrefix:@"cmd-"]) {
		return nil;
	}

	return description;
}

@end

#pragma mark -
#pragma mark List

@interface TVCInputCompletionController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, weak) TVCMainWindow *window;
@property (nonatomic, strong, nullable) NSPanel *panel;
@property (nonatomic, strong, nullable) NSTableView *tableView;
@property (nonatomic, copy) NSArray<TVCInputCompletionItem *> *items;
@property (nonatomic, strong, nullable) TVCInputCompletionQuery *query;
@property (nonatomic, assign) NSUInteger dismissedLocation; // Esc: not again for this word
@end

/* The chosen row in the accent colour, like a menu, though the list
 never becomes the key window */
@interface TVCInputCompletionRowView : NSTableRowView
@end

@implementation TVCInputCompletionRowView

- (BOOL)isEmphasized
{
	return YES;
}

@end

@implementation TVCInputCompletionController

- (instancetype)initWithWindow:(TVCMainWindow *)window
{
	NSParameterAssert(window != nil);

	if ((self = [super init])) {
		self.window = window;

		self.items = @[];

		self.dismissedLocation = NSNotFound;

		return self;
	}

	return nil;
}

- (BOOL)isVisible
{
	return self.panel.visible;
}

#pragma mark -
#pragma mark Items

- (NSArray<TVCInputCompletionItem *> *)_itemsForQuery:(TVCInputCompletionQuery *)query
{
	NSParameterAssert(query != nil);

	TVCMainWindow *window = self.window;

	IRCClient *client = window.selectedClient;
	IRCChannel *channel = window.selectedChannel;

	NSMutableArray<TVCInputCompletionItem *> *items = [NSMutableArray array];

	switch (query.kind) {
		case TVCInputCompletionKindNickname:
		{
			if (channel == nil) {
				break;
			}

			NSMutableArray<NSString *> *nicknames = [NSMutableArray array];

			if (channel.isChannel) {
				/* As Tab completion orders them: who spoke last first */
				NSArray *members = [channel.memberList sortedArrayUsingSelector:@selector(compareUsingWeights:)];

				NSString *ownNickname = client.userNickname;

				for (IRCChannelUser *member in members) {
					NSString *nickname = member.user.nickname;

					if ([nickname isEqualToStringIgnoringCase:ownNickname] == NO) {
						[nicknames addObject:nickname];
					}
				}
			} else if (channel.isPrivateMessage) {
				[nicknames addObject:channel.name];
			}

			for (NSString *nickname in [TVCInputCompletion names:nicknames matching:query.text limit:_maximumItems]) {
				[items addObject:[TVCInputCompletionItem itemWithKind:TVCInputCompletionKindNickname value:nickname title:nickname detail:nil]];
			}

			break;
		}
		case TVCInputCompletionKindChannel:
		{
			if (client == nil) {
				break;
			}

			NSMutableArray<NSString *> *names = [NSMutableArray array];

			NSMutableDictionary<NSString *, IRCChannel *> *channels = [NSMutableDictionary dictionary];

			for (IRCChannel *serverChannel in client.channelList) {
				if (serverChannel.isChannel == NO) {
					continue;
				}

				/* "#textual" is matched as "textual" */
				NSString *name = [serverChannel.name substringFromIndex:1];

				[names addObject:name];

				channels[name] = serverChannel;
			}

			[names sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

			for (NSString *name in [TVCInputCompletion names:names matching:query.text limit:_maximumItems]) {
				IRCChannel *serverChannel = channels[name];

				NSString *detail = nil;

				if (serverChannel.isActive) {
					detail = TXTLS(@"TVCMainWindow[icp-mc]", serverChannel.numberOfMembers);
				}

				[items addObject:[TVCInputCompletionItem itemWithKind:TVCInputCompletionKindChannel value:serverChannel.name title:serverChannel.name detail:detail]];
			}

			break;
		}
		case TVCInputCompletionKindCommand:
		{
			NSMutableArray<NSString *> *commands = [NSMutableArray array];

			NSMutableDictionary<NSString *, NSString *> *details = [NSMutableDictionary dictionary];

			for (NSString *command in [IRCCommandIndex localCommandList]) {
				NSString *name = command.lowercaseString;

				[commands addObject:name];

				NSString *syntax = [IRCCommandIndex syntaxForLocalCommand:name];

				NSString *arguments = nil;

				if (syntax.length > name.length) {
					arguments = [syntax substringFromIndex:(name.length + 1)];
				}

				NSString *description = [TVCInputCompletion descriptionForCommand:name];

				/* What it does first: the syntax is cut off when long */
				if (arguments && description) {
					details[name] = [NSString stringWithFormat:@"%@ · %@", description, arguments];
				} else {
					details[name] = (description ?: arguments);
				}
			}

			NSDictionary<NSString *, NSString *> *aliases = IRCAlias.aliases;

			for (NSString *name in aliases) {
				if ([commands containsObject:name] == NO) {
					[commands addObject:name];

					details[name] = TXTLS(@"TVCMainWindow[icp-al]", aliases[name]);
				}
			}

			for (NSString *command in sharedPluginManager().supportedUserInputCommands) {
				NSString *name = command.lowercaseString;

				if (details[name] == nil && [commands containsObject:name] == NO) {
					[commands addObject:name];

					details[name] = TXTLS(@"TVCMainWindow[icp-ex]");
				}
			}

			for (NSString *command in sharedPluginManager().supportedAppleScriptCommands) {
				NSString *name = command.lowercaseString;

				if ([commands containsObject:name] == NO) {
					[commands addObject:name];

					details[name] = TXTLS(@"TVCMainWindow[icp-sc]");
				}
			}

			[commands sortUsingSelector:@selector(compare:)];

			for (NSString *command in [TVCInputCompletion names:commands matching:query.text limit:_maximumItems]) {
				[items addObject:[TVCInputCompletionItem itemWithKind:TVCInputCompletionKindCommand value:command title:[@"/" stringByAppendingString:command] detail:details[command]]];
			}

			break;
		}
		case TVCInputCompletionKindEmoji:
		{
			[items addObjectsFromArray:[TVCInputCompletion emojiMatching:query.text limit:_maximumItems]];

			break;
		}
	}

	return [items copy];
}

#pragma mark -
#pragma mark Updating

- (void)update
{
	TVCMainWindow *window = self.window;

	TVCMainWindowTextView *textView = window.inputTextField;

	NSString *string = textView.string;

	TVCInputCompletionQuery *query = nil;

	if (window.firstResponder == textView) {
		query = [TVCInputCompletion queryInString:string selectedRange:textView.selectedRange];
	}

	if (query && [TPCPreferences inputCompletionEnabledForKind:query.kind] == NO) {
		query = nil;
	}

	/* Closed with Esc: not again until another word */
	if (query && query.range.location == self.dismissedLocation) {
		query = nil;
	} else if (query == nil || query.range.location != self.dismissedLocation) {
		self.dismissedLocation = NSNotFound;
	}

	NSArray *items = ((query) ? [self _itemsForQuery:query] : @[]);

	if (items.count == 0) {
		[self close];

		return;
	}

	self.query = query;

	self.items = items;

	[self _showList];
}

- (void)close
{
	self.query = nil;

	self.items = @[];

	if (self.panel.visible) {
		[self.panel.parentWindow removeChildWindow:self.panel];

		[self.panel orderOut:nil];
	}
}

- (void)_showList
{
	TVCMainWindow *window = self.window;

	TVCMainWindowTextView *textView = window.inputTextField;

	if (self.panel == nil) {
		[self _makePanel];
	}

	NSTableView *tableView = self.tableView;

	[tableView reloadData];

	[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

	[tableView scrollRowToVisible:0];

	/* Above the word being completed */
	NSRect wordRect = [textView firstRectForCharacterRange:self.query.range actualRange:NULL];

	CGFloat height = ((MIN(self.items.count, (NSUInteger)_visibleRows) * _rowHeight) + 8.0);

	NSRect frame = NSMakeRect((NSMinX(wordRect) - 10.0), (NSMaxY(wordRect) + 8.0), _listWidth, height);

	NSRect visibleFrame = (window.screen.visibleFrame);

	if (NSMaxX(frame) > NSMaxX(visibleFrame)) {
		frame.origin.x = (NSMaxX(visibleFrame) - NSWidth(frame));
	}

	if (NSMinX(frame) < NSMinX(visibleFrame)) {
		frame.origin.x = NSMinX(visibleFrame);
	}

	/* The window's light or dark, which can differ from the Mac's (a panel
	 of its own otherwise follows the Mac) */
	self.panel.appearance = window.effectiveAppearance;

	[self.panel setFrame:frame display:YES];

	if (self.panel.visible == NO) {
		[window addChildWindow:self.panel ordered:NSWindowAbove];

		[self.panel orderFront:nil];
	}
}

- (void)_makePanel
{
	NSPanel *panel =
	[[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, _listWidth, 100)
							   styleMask:(NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel)
								 backing:NSBackingStoreBuffered
								   defer:YES];

	panel.releasedWhenClosed = NO;
	panel.hasShadow = YES;
	panel.opaque = NO;
	panel.backgroundColor = [NSColor clearColor];
	panel.becomesKeyOnlyIfNeeded = YES;
	panel.hidesOnDeactivate = YES;

	NSVisualEffectView *background = [NSVisualEffectView new];

	background.material = NSVisualEffectMaterialMenu;
	background.state = NSVisualEffectStateActive;
	background.wantsLayer = YES;
	background.layer.cornerRadius = 8.0;
	background.layer.masksToBounds = YES;

	panel.contentView = background;

	NSTableView *tableView = [NSTableView new];

	NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"item"];

	[tableView addTableColumn:column];

	tableView.headerView = nil;
	tableView.rowHeight = _rowHeight;
	tableView.intercellSpacing = NSMakeSize(0, 0);
	tableView.backgroundColor = [NSColor clearColor];
	tableView.style = NSTableViewStyleFullWidth;
	tableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
	tableView.refusesFirstResponder = YES;
	tableView.dataSource = self;
	tableView.delegate = self;
	tableView.target = self;
	tableView.action = @selector(_rowClicked:);

	NSScrollView *scrollView = [NSScrollView new];

	scrollView.documentView = tableView;
	scrollView.hasVerticalScroller = YES;
	scrollView.autohidesScrollers = YES;
	scrollView.drawsBackground = NO;
	scrollView.translatesAutoresizingMaskIntoConstraints = NO;

	[background addSubview:scrollView];

	[NSLayoutConstraint activateConstraints:@[
		[scrollView.leadingAnchor constraintEqualToAnchor:background.leadingAnchor],
		[scrollView.trailingAnchor constraintEqualToAnchor:background.trailingAnchor],
		[scrollView.topAnchor constraintEqualToAnchor:background.topAnchor constant:4.0],
		[scrollView.bottomAnchor constraintEqualToAnchor:background.bottomAnchor constant:-4.0]
	]];

	self.panel = panel;

	self.tableView = tableView;
}

#pragma mark -
#pragma mark Choosing

- (void)_rowClicked:(id)sender
{
	NSInteger row = self.tableView.clickedRow;

	if (row < 0) {
		return;
	}

	[self _chooseItemAtRow:row];
}

- (void)_chooseItemAtRow:(NSInteger)row
{
	if (row < 0 || row >= (NSInteger)self.items.count) {
		return;
	}

	TVCInputCompletionQuery *query = self.query;

	if (query == nil) {
		return;
	}

	TVCInputCompletionItem *item = self.items[row];

	TVCMainWindowTextView *textView = self.window.inputTextField;

	NSString *string = textView.string;

	if (NSMaxRange(query.range) > string.length) {
		[self close];

		return;
	}

	NSString *replacement = [TVCInputCompletion replacementForItem:item query:query inString:string nicknameSuffix:[TPCPreferences tabCompletionSuffix]];

	[self close];

	if ([textView shouldChangeTextInRange:query.range replacementString:replacement]) {
		[textView replaceCharactersInRange:query.range withString:replacement];

		textView.selectedRange = NSMakeRange((query.range.location + replacement.length), 0);

		[textView didChangeText];
	}

	/* The picked word doesn't open the list again */
	[self close];
}

- (BOOL)handleKeyEvent:(NSEvent *)event
{
	if (self.visible == NO) {
		return NO;
	}

	NSEventModifierFlags modifiers = (event.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagShift));

	if (modifiers != 0) {
		return NO;
	}

	NSTableView *tableView = self.tableView;

	NSInteger row = tableView.selectedRow;

	switch (event.keyCode) {
		case TXKeyUpArrowCode:
		{
			row = ((row <= 0) ? ((NSInteger)self.items.count - 1) : (row - 1));

			break;
		}
		case TXKeyDownArrowCode:
		{
			row = ((row >= ((NSInteger)self.items.count - 1)) ? 0 : (row + 1));

			break;
		}
		case TXKeyTabCode:
		case TXKeyReturnCode:
		case TXKeyEnterCode:
		{
			[self _chooseItemAtRow:MAX(row, 0)];

			return YES;
		}
		case TXKeyEscapeCode:
		{
			self.dismissedLocation = self.query.range.location;

			[self close];

			return YES;
		}
		default:
		{
			return NO;
		}
	}

	[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

	[tableView scrollRowToVisible:row];

	return YES;
}

#pragma mark -
#pragma mark Table View

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.items.count;
}

- (nullable NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	return [TVCInputCompletionRowView new];
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSTableCellView *cell = [tableView makeViewWithIdentifier:@"item" owner:self];

	if (cell == nil) {
		cell = [NSTableCellView new];

		cell.identifier = @"item";

		NSTextField *titleField = [NSTextField labelWithString:@""];

		titleField.font = [NSFont systemFontOfSize:13];
		titleField.lineBreakMode = NSLineBreakByTruncatingTail;
		titleField.translatesAutoresizingMaskIntoConstraints = NO;

		[titleField setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];

		NSTextField *detailField = [NSTextField labelWithString:@""];

		detailField.font = [NSFont systemFontOfSize:11];
		detailField.textColor = [NSColor secondaryLabelColor];
		detailField.lineBreakMode = NSLineBreakByTruncatingTail;
		detailField.translatesAutoresizingMaskIntoConstraints = NO;
		detailField.tag = 1;

		[detailField setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

		[cell addSubview:titleField];
		[cell addSubview:detailField];

		cell.textField = titleField;

		[NSLayoutConstraint activateConstraints:@[
			[titleField.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:12.0],
			[titleField.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
			[detailField.leadingAnchor constraintEqualToAnchor:titleField.trailingAnchor constant:10.0],
			[detailField.trailingAnchor constraintLessThanOrEqualToAnchor:cell.trailingAnchor constant:-12.0],
			[detailField.firstBaselineAnchor constraintEqualToAnchor:titleField.firstBaselineAnchor]
		]];
	}

	TVCInputCompletionItem *item = self.items[row];

	cell.textField.stringValue = item.title;

	NSTextField *detailField = [cell viewWithTag:1];

	detailField.stringValue = (item.detail ?: @"");

	return cell;
}

@end

NS_ASSUME_NONNULL_END
