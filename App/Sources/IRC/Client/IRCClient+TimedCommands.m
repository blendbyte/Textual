/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
 *      Please see Acknowledgements.pdf for additional information.
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

#import <objc/message.h>
#import "NSObjectHelperPrivate.h"
#import "NSStringHelper.h"
#import "TPCApplicationInfo.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCResourceManager.h"
#import "TPCThemeController.h"
#import "TPCTheme.h"
#import "THOPluginDispatcherPrivate.h"
#import "THOPluginManagerPrivate.h"
#import "THOPluginProtocol.h"
#import "TLOFileLoggerPrivate.h"
#import "TLOInputHistoryPrivate.h"
#import "TLOLocalization.h"
#import "TLONotificationControllerPrivate.h"
#import "TLOpenLink.h"
#import "TLOSoundPlayer.h"
#import "TLOSpeechSynthesizerPrivate.h"
#import "TLOSpokenNotificationPrivate.h"
#import "TLOTimer.h"
#import "TXGlobalModelsPrivate.h"
#import "TXMasterControllerPrivate.h"
#import "TXMenuControllerPrivate.h"
#import "TXWindowControllerPrivate.h"
#import "TVCDockIconPrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogControllerInlineMediaServicePrivate.h"
#import "TVCLogControllerOperationQueuePrivate.h"
#import "TVCLogRenderer.h"
#import "TVCLogViewPrivate.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowTextViewPrivate.h"
#import "TVCServerListPrivate.h"
#import "TDCAlert.h"
#import "TDCChannelBanListSheetPrivate.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCFileTransferDialogTransferControllerPrivate.h"
#import "TDCServerChannelListDialogPrivate.h"
#import "TDCServerHighlightListSheetPrivate.h"
#import "IRC.h"
#import "IRCAddressBook.h"
#import "IRCAddressBookMatchCachePrivate.h"
#import "IRCAddressBookUserTrackingPrivate.h"
#import "IRCChannelConfig.h"
#import "IRCChannelModePrivate.h"
#import "IRCChannelUserPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCClientConfigPrivate.h"
#import "IRCClientRequestedCommandsPrivate.h"
#import "IRCColorFormatPrivate.h"
#import "IRCConnectionPrivate.h"
#import "IRCConnectionConfig.h"
#import "IRCConnectionErrors.h"
#import "IRCExtrasPrivate.h"
#import "IRCHighlightLogEntryPrivate.h"
#import "IRCHighlightMatchCondition.h"
#import "IRCISupportInfoPrivate.h"
#import "IRCMessagePrivate.h"
#import "IRCMessageBatchPrivate.h"
#import "IRCModeInfo.h"
#import "IRCPrefix.h"
#import "IRCNumerics.h"
#import "IRCSendingMessage.h"
#import "IRCServerPrivate.h"
#import "IRCTimerCommandPrivate.h"
#import "IRCTreeItemPrivate.h"
#import "IRCUserPrivate.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCWorldPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCClient (TimedCommands)

#pragma mark -
#pragma mark Command Queue

- (NSString *)descriptionForTimedCommand:(IRCTimedCommand *)timedCommand
{
	NSParameterAssert(timedCommand != nil);

	NSString *timerInterval = TXHumanReadableTimeInterval(timedCommand.timerInterval, NO, 0);

	NSString *timeRemaining = TXHumanReadableTimeInterval(timedCommand.timeRemaining, NO, 0);

	NSString *timerStatus = nil;

	if (timedCommand.timerIsActive == NO) {
		timerStatus = TXTLS(@"IRC[ww4-sn]");
	} else {
		timerStatus = TXTLS(@"IRC[bhz-9e]");
	}

	if (timedCommand.repeatTimer == NO) {
		return TXTLS(@"IRC[4n6-2x]",
					 timedCommand.identifier,
					 timerStatus,
					 timerInterval,
					 timeRemaining,
					 timedCommand.command);
	} else {
		NSUInteger repeatLimit = timedCommand.iterations;

		NSString *repeatLimitDescriptor = nil;

		if (repeatLimit == 0) {
			repeatLimitDescriptor = TXTLS(@"IRC[o26-ae]");
		} else {
			repeatLimitDescriptor = [NSString stringWithUnsignedInteger:repeatLimit];
		}

		return TXTLS(@"IRC[uw0-v2]",
					 timedCommand.identifier,
					 timerStatus,
					 timerInterval,
					 timeRemaining,
					 repeatLimitDescriptor,
					 timedCommand.currentIteration,
					 timedCommand.command);
	}
}

- (nullable IRCTimedCommand *)timedCommandWithIdentifier:(NSString *)identifier
{
	NSParameterAssert(identifier != nil);

	@synchronized (self.timedCommands) {
		return self.timedCommands[identifier];
	}
}

- (NSArray<IRCTimedCommand *> *)listOfTimedCommands
{
	@synchronized (self.timedCommands) {
		return self.timedCommands.allValues;
	}
}

- (void)addTimedCommand:(IRCTimedCommand *)timedCommand
{
	NSParameterAssert(timedCommand != nil);

	@synchronized (self.timedCommands) {
		self.timedCommands[timedCommand.identifier] = timedCommand;
	}
}

- (void)removeTimedCommands
{
	@synchronized (self.timedCommands) {
		[self.timedCommands removeAllObjects];
	}
}

- (void)removeTimedCommand:(IRCTimedCommand *)timedCommand
{
	NSParameterAssert(timedCommand != nil);

	@synchronized (self.timedCommands) {
		[self.timedCommands removeObjectForKey:timedCommand.identifier];
	}
}

- (void)stopTimedCommand:(IRCTimedCommand *)timedCommand
{
	NSParameterAssert(timedCommand != nil);

	[timedCommand stop];
}

- (void)startTimedCommand:(IRCTimedCommand *)timedCommand interval:(NSUInteger)timerInterval
{
	NSParameterAssert(timedCommand != nil);

	[self startTimedCommand:timedCommand interval:timerInterval onRepeat:NO iterations:0];
}

- (void)startTimedCommand:(IRCTimedCommand *)timedCommand interval:(NSUInteger)timerInterval onRepeat:(BOOL)repeatTimer
{
	NSParameterAssert(timedCommand != nil);

	[self startTimedCommand:timedCommand interval:timerInterval onRepeat:repeatTimer iterations:0];
}

- (void)startTimedCommand:(IRCTimedCommand *)timedCommand interval:(NSUInteger)timerInterval onRepeat:(BOOL)repeatTimer iterations:(NSUInteger)iterations
{
	NSParameterAssert(timedCommand != nil);

	[timedCommand start:timerInterval onRepeat:repeatTimer iterations:iterations];
}

- (BOOL)restartTimedCommand:(IRCTimedCommand *)timedCommand
{
	NSParameterAssert(timedCommand != nil);

	return [timedCommand restart];
}

- (void)onTimedCommand:(IRCTimedCommand *)timedCommand
{
	NSParameterAssert(timedCommand != nil);

	/* Remove timer */
	if (timedCommand.timerIsActive == NO) {
		[self removeTimedCommand:timedCommand];
	}

	/* The -channelId is only a suggestion. It's okay if this returns nil.
	 The channel is what was selected at the time that the timer was created.
	 -sendCommand:completeTarget:target: may very well ignore the channel we
	 give it, even if it's non-nil, depending on format of command. */
	IRCChannel *channel = (IRCChannel *)[worldController() findItemWithId:timedCommand.channelId];

	[self sendCommand:timedCommand.command completeTarget:YES target:channel.name];
}

@end

NS_ASSUME_NONNULL_END
