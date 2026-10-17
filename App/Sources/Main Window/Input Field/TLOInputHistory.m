/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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
#import "TXMasterController.h"
#import "TPCPreferencesLocal.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "IRCWorld.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowTextView.h"
#import "TLOInputHistoryPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Private Interface

#define _inputHistoryMax						100

NSString * const _inputHistoryGlobalObjectKey	= @"TLOInputHistoryDefaultObject";

@interface TLOInputHistory ()
@property (nonatomic, weak) TVCMainWindow *window;
@property (nonatomic, strong) NSMutableDictionary *historyObjects;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSAttributedString *> *drafts; // unsent text per channel, query and console (10.11)
@property (nonatomic, copy, nullable) NSString *currentTreeItem;
@end

@interface TLOInputHistoryObject : NSObject <NSCopying>
@property (nonatomic, assign) NSInteger historyBufferPosition;
@property (nonatomic, strong) NSMutableArray *historyBuffer;

- (void)add:(NSAttributedString *)string;

- (nullable NSAttributedString *)up:(NSAttributedString *)string;
- (nullable NSAttributedString *)down:(NSAttributedString *)string;
@end

#pragma mark -
#pragma mark Input History Manager

@implementation TLOInputHistory

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithWindow:(TVCMainWindow *)mainWindow
{
	NSParameterAssert(mainWindow != nil);

	if ((self = [super init])) {
		self.window = mainWindow;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self.historyObjects = [NSMutableDictionary dictionary];

	self.drafts = [NSMutableDictionary dictionary];
}

- (void)destroy:(IRCTreeItem *)treeItem
{
	NSParameterAssert(treeItem != nil);

	@synchronized(self.historyObjects) {
		if (treeItem.isClient) {
			for (IRCChannel *treeItemChild in ((IRCClient *)treeItem).channelList) {
				[self destroy:treeItemChild];
			}
		}

		NSString *itemId = treeItem.uniqueIdentifier;

		/* A closed channel or query takes its draft with it */
		[self.drafts removeObjectForKey:itemId];

		if ([TPCPreferences inputHistoryIsChannelSpecific]) {
			[self.historyObjects removeObjectForKey:itemId];
		}

		if ([self.currentTreeItem isEqualToString:itemId]) {
			self.currentTreeItem = nil;
		}
	}
}

/* Drafts are always kept per channel, query and server console (10.11): a
 half-written message never follows you somewhere else. The setting only
 decides whether ↑/↓ history is per channel or shared. */
- (void)moveFocusTo:(IRCTreeItem *)treeItem
{
	NSParameterAssert(treeItem != nil);

	TVCMainWindow *window = self.window;

	TVCMainWindowTextView *textView = window.inputTextField;

	@synchronized(self.historyObjects) {
		NSString *oldItemId = self.currentTreeItem;

		NSString *newItemId = treeItem.uniqueIdentifier;

		if ([oldItemId isEqualToString:newItemId]) {
			return;
		}

		if (oldItemId) {
			NSAttributedString *draft = textView.attributedStringValue;

			if (draft.length > 0) {
				self.drafts[oldItemId] = [draft copy];
			} else {
				[self.drafts removeObjectForKey:oldItemId];
			}
		}

		self.currentTreeItem = newItemId;

		[window restoreInputDraft:self.drafts[newItemId]];
	}
}

- (nullable NSAttributedString *)draftForTreeItem:(IRCTreeItem *)treeItem
{
	NSParameterAssert(treeItem != nil);

	@synchronized(self.historyObjects) {
		return self.drafts[treeItem.uniqueIdentifier];
	}
}

- (void)appendText:(NSString *)text toDraftForTreeItem:(IRCTreeItem *)treeItem
{
	NSParameterAssert(text != nil);
	NSParameterAssert(treeItem != nil);

	NSString *itemId = treeItem.uniqueIdentifier;

	@synchronized (self.historyObjects) {
		NSMutableAttributedString *draft = [self.drafts[itemId] mutableCopy];

		if (draft == nil) {
			draft = [NSMutableAttributedString new];
		}

		NSString *separator = ((draft.length > 0 && [draft.string hasSuffix:@" "] == NO) ? @" " : @"");

		[draft appendAttributedString:[NSAttributedString attributedStringWithString:[NSString stringWithFormat:@"%@%@ ", separator, text]]];

		self.drafts[itemId] = [draft copy];
	}
}

- (void)setDraft:(nullable NSAttributedString *)draft forTreeItem:(IRCTreeItem *)treeItem
{
	NSParameterAssert(treeItem != nil);

	@synchronized (self.historyObjects) {
		self.drafts[treeItem.uniqueIdentifier] = ((draft.length > 0) ? [draft copy] : nil);
	}
}

- (void)noteInputHistoryObjectScopeDidChange
{
	@synchronized(self.historyObjects) {
		/* If the input history was made channel specific, then we copy the current
		 value of the global input history to all tree items. */
		if ([TPCPreferences inputHistoryIsChannelSpecific])
		{
			for (IRCClient *u in worldController().clientList) {
				[self inputHistoryObjectScopeDidChangeApplyToItem:u.uniqueIdentifier];

				for (IRCChannel *c in u.channelList) {
					[self inputHistoryObjectScopeDidChangeApplyToItem:c.uniqueIdentifier];
				}
			}

			[self.historyObjects removeObjectForKey:_inputHistoryGlobalObjectKey];
		}
		else
		{
			/* Drafts and the current selection stay */
			[self.historyObjects removeAllObjects];
		}
	}
}

- (void)inputHistoryObjectScopeDidChangeApplyToItem:(NSString *)itemId
{
	NSParameterAssert(itemId != nil);

	TLOInputHistoryObject *globalObject = self.historyObjects[_inputHistoryGlobalObjectKey];

	if (globalObject) {
		self.historyObjects[itemId] = [globalObject copy];
	}
}

- (nullable TLOInputHistoryObject *)currentObjectForFocusedTreeView
{
	@synchronized(self.historyObjects) {
		NSString *currentObjectKey = nil;

		if ([TPCPreferences inputHistoryIsChannelSpecific]) {
			currentObjectKey = self.currentTreeItem;
		} else {
			currentObjectKey = _inputHistoryGlobalObjectKey;
		}

		if (currentObjectKey == nil) {
			return nil;
		}

		TLOInputHistoryObject *currentObject = self.historyObjects[currentObjectKey];

		if (currentObject == nil) {
			currentObject = [TLOInputHistoryObject new];

			self.historyObjects[currentObjectKey] = currentObject;
		}

		return currentObject;
	}
}

- (void)add:(NSAttributedString *)string
{
	TLOInputHistoryObject *object = [self currentObjectForFocusedTreeView];

	if (object == nil) {
		return;
	}

	[object add:string];
}

- (nullable NSAttributedString *)up:(NSAttributedString *)string
{
	TLOInputHistoryObject *object = [self currentObjectForFocusedTreeView];

	if (object == nil) {
		return nil;
	}

	return [object up:string];
}

- (nullable NSAttributedString *)down:(NSAttributedString *)string
{
	TLOInputHistoryObject *object = [self currentObjectForFocusedTreeView];

	if (object == nil) {
		return nil;
	}

	return [object down:string];
}

@end

#pragma mark -
#pragma mark Input History Objects

@implementation TLOInputHistoryObject

- (id)init
{
	if ((self = [super init])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self.historyBuffer = [NSMutableArray new];
}

- (void)add:(NSAttributedString *)string
{
	NSParameterAssert(string != nil);

	if (string.length == 0) {
		return;
	}

	@synchronized(self.historyBuffer) {
		NSAttributedString *lastEntry = self.historyBuffer.lastObject;

		/* The same line twice in a row is kept once (the check was inverted
		 and let every line in) */
		if (lastEntry == nil || [lastEntry.string isEqualToString:string.string] == NO) {
			[self addToBuffer:string];
		}

		self.historyBufferPosition = self.historyBuffer.count;
	}
}

- (void)addToBuffer:(NSAttributedString *)string
{
	NSParameterAssert(string != nil);

	[self.historyBuffer addObject:string];

	if (self.historyBuffer.count > _inputHistoryMax) {
		[self.historyBuffer removeObjectAtIndex:0];

		/* The entries moved down one: so does the position (Up showed the line just typed) */
		if (self.historyBufferPosition > 0) {
			self.historyBufferPosition -= 1;
		}
	}
}

- (nullable NSAttributedString *)up:(NSAttributedString *)string
{
	NSParameterAssert(string != nil);

	@synchronized(self.historyBuffer) {
		if (string.length > 0) {
			NSAttributedString *lastEntry = [self entryAtBufferPosition];

			if (lastEntry == nil || [lastEntry.string isEqualToString:string.string] == NO) {
				[self addToBuffer:string];
			}
		}

		self.historyBufferPosition -= 1;

		if (self.historyBufferPosition < 0) {
			self.historyBufferPosition = 0;
		} else if (self.historyBufferPosition < self.historyBuffer.count) {
			return self.historyBuffer[self.historyBufferPosition];
		}

		return nil;
	}
}

- (nullable NSAttributedString *)down:(NSAttributedString *)string
{
	NSParameterAssert(string != nil);

	@synchronized(self.historyBuffer) {
		if (string.length == 0) {
			self.historyBufferPosition = self.historyBuffer.count;

			return nil;
		}

		NSAttributedString *lastEntry = [self entryAtBufferPosition];

		if (lastEntry == nil || [lastEntry.string isEqualToString:string.string] == NO) {
			[self addToBuffer:string];

			return [NSAttributedString attributedString];
		}

		self.historyBufferPosition += 1;

		lastEntry = [self entryAtBufferPosition];

		if (lastEntry) {
			return lastEntry;
		}

		return [NSAttributedString attributedString];
	}
}

- (BOOL)bufferPositionIsInRange
{
	return (self.historyBufferPosition >= 0 &&
			self.historyBufferPosition < self.historyBuffer.count);
}

- (nullable NSAttributedString *)entryAtBufferPosition
{
	if ([self bufferPositionIsInRange] == NO) {
		return nil;
	}

	return self.historyBuffer[self.historyBufferPosition];
}

- (id)copyWithZone:(nullable NSZone *)zone
{
	TLOInputHistoryObject *newObject = [TLOInputHistoryObject new];

	[newObject->_historyBuffer addObjectsFromArray:self->_historyBuffer];

	newObject->_historyBufferPosition = self->_historyBufferPosition;

	return newObject;
}

@end

NS_ASSUME_NONNULL_END
