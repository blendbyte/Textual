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
#import "IRCTimedCommandPrivate.h"
#import "IRCTreeItemPrivate.h"
#import "IRCUserPrivate.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCWorldPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCClient (Scripts)

#pragma mark -
#pragma mark Plugins and Scripts

- (void)outputDescriptionForError:(NSError *)error forTextualCmdScriptAtPath:(NSString *)path inputString:(NSString *)inputString
{
	NSString *filename = path.lastPathComponent;

	NSString *errorDescription = error.userInfo[NSAppleScriptErrorMessage];

	if (errorDescription == nil) {
		errorDescription = error.userInfo[NSAppleScriptErrorBriefMessage];
	}

	if (errorDescription == nil) {
		errorDescription = error.localizedFailureReason;
	}

	if (errorDescription == nil) {
		errorDescription = error.localizedDescription;
	}

	if (inputString.length == 0) {
		inputString = @"(no input)";
	}

	[self printDebugInformation:TXTLS(@"IRC[2mc-h0]", filename, inputString, errorDescription)];

	LogToConsoleError("%{public}@", TXTLS(@"IRC[ax0-mt]", errorDescription));
}

- (void)sendTextualCmdScriptResult:(nullable NSString *)resultString toChannel:(nullable NSString *)channel
{
	/* Scripts that return nothing, a non-string AppleScript result,
	 or output that is not valid UTF-8 have no output to send. */
	resultString = resultString.trim;

	if (resultString.length == 0) {
		return;
	}

	IRCTreeItem *destination = nil;

	if (channel == nil) {
		destination = self;
	} else {
		destination = [self findChannel:channel];
	}

	if (destination == nil) {
		LogToConsoleFault("A script returned a result but its destination no longer exists");

		return;
	}

	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self inputText:resultString destination:destination];
	});
}

- (void)executeTextualCmdScriptInContext:(NSDictionary<NSString *, NSString *> *)context
{
	XRPerformBlockAsynchronouslyOnQueue([THOPluginDispatcher dispatchQueue], ^{
		[self _executeTextualCmdScriptInContext:context];
	});
}

- (void)_executeTextualCmdScriptInContext:(NSDictionary<NSString *, NSString *> *)context
{
	NSParameterAssert(context != nil);

	NSString *inputString = context[@"inputString"];

	NSString *path = context[@"path"];

	NSString *targetChannel = context[@"targetChannel"];

	NSParameterAssert(path != nil);

	NSURL *pathURL = [NSURL fileURLWithPath:path];

	/* Is it AppleScript? */
	if ([path hasSuffix:TPCResourceManagerScriptDocumentTypeExtension]) {
		BOOL isBuiltinScript = [path hasPrefix:[TPCPathInfo applicationResources]];

		/* /////////////////////////////////////////////////////// */
		/* Event Descriptor */
		/* /////////////////////////////////////////////////////// */

		NSAppleEventDescriptor *firstParameter = [NSAppleEventDescriptor descriptorWithString:inputString];
		NSAppleEventDescriptor *secondParameter = [NSAppleEventDescriptor descriptorWithString:targetChannel];

		NSAppleEventDescriptor *parameters = [NSAppleEventDescriptor listDescriptor];

		[parameters insertDescriptor:firstParameter atIndex:1];
		[parameters insertDescriptor:secondParameter atIndex:2];

		ProcessSerialNumber process = { 0, kCurrentProcess };

		NSAppleEventDescriptor *target = [NSAppleEventDescriptor descriptorWithDescriptorType:typeProcessSerialNumber
																						bytes:&process
																					   length:sizeof(ProcessSerialNumber)];

		NSAppleEventDescriptor *handler = [NSAppleEventDescriptor descriptorWithString:@"textualcmd"];

		NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite
																				 eventID:kASSubroutineEvent
																		targetDescriptor:target
																				returnID:kAutoGenerateReturnID
																		   transactionID:kAnyTransactionID];

		[event setParamDescriptor:handler forKeyword:keyASSubroutineName];

		[event setParamDescriptor:parameters forKeyword:keyDirectObject];

		/* /////////////////////////////////////////////////////// */
		/* Execute Event */
		/* /////////////////////////////////////////////////////// */
		/* NSUserAppleScriptTask expects the script to be in the Application Scripts folder 
		 which means if we want to execute scripts in the app's Resources folder, we use a
		 regular call to NSAppleScript. It's pretty safe to say that scripts we make ourselves
		 wont produce errors which means the logic for handling errors is ignored for scripts
		 that are performed in the Resources folder. */

		if (isBuiltinScript)
		{
			NSAppleScript *appleScript = [[NSAppleScript alloc] initWithContentsOfURL:pathURL error:NULL];

			if (appleScript == nil) {
				return;
			}

			NSAppleEventDescriptor *result = [appleScript executeAppleEvent:event error:NULL];

			if (result == nil) {
				return;
			}

			[self sendTextualCmdScriptResult:result.stringValue toChannel:targetChannel];
		}
		else // isBuiltinScript
		{
			NSError *appleScriptError = nil;

			NSUserAppleScriptTask *appleScript = [[NSUserAppleScriptTask alloc] initWithURL:pathURL error:&appleScriptError];

			if (appleScript == nil) {
				[self outputDescriptionForError:appleScriptError forTextualCmdScriptAtPath:path inputString:inputString];

				return;
			}

			[appleScript executeWithAppleEvent:event
							 completionHandler:^(NSAppleEventDescriptor *result, NSError *error)
			 {
				 if (result == nil) {
					 [self outputDescriptionForError:error forTextualCmdScriptAtPath:path inputString:inputString];
				 } else {
					 [self sendTextualCmdScriptResult:result.stringValue toChannel:targetChannel];
				 }
			 }];
		}

		return;
	}

	/* /////////////////////////////////////////////////////// */
	/* Execute Shell Script */
	/* /////////////////////////////////////////////////////// */

	/* Build list of arguments. */
	NSMutableArray *taskArguments = [NSMutableArray array];

	if (targetChannel) {
		[taskArguments addObject:targetChannel];
	} else {
		[taskArguments addObject:@""];
	}

	NSArray *inputStringComponents = [inputString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

	[taskArguments addObjectsFromArray:inputStringComponents];

	/* Create task object */
	NSError *taskError = nil;

	NSUserUnixTask *task = [[NSUserUnixTask alloc] initWithURL:pathURL error:&taskError];

	if (task == nil) {
		[self outputDescriptionForError:taskError forTextualCmdScriptAtPath:path inputString:inputString];

		return;
	}

	/* Prepare pipe */
	NSPipe *standardOutputPipe = [NSPipe pipe];

	NSFileHandle *readingPipe = standardOutputPipe.fileHandleForReading;
	NSFileHandle *writingPipe = standardOutputPipe.fileHandleForWriting;

	task.standardOutput = writingPipe;

	/* Output is read as it arrives: read only at the end, a script printing
	 more than the pipe holds (64 KB) blocked for ever. The result is handled
	 once the output reached its end and the task finished, in either order. */
	NSMutableData *output = [NSMutableData data];

	dispatch_queue_t outputQueue = dispatch_queue_create("Textual.IRCClient.scriptOutput", DISPATCH_QUEUE_SERIAL);

	__block BOOL outputEnded = NO;
	__block BOOL taskFinished = NO;
	__block NSError *executionError = nil;

	void (^finish)(void) = ^{
		NSData *result = [output copy];

		NSError *error = executionError;

		if (error) {
			[self outputDescriptionForError:error forTextualCmdScriptAtPath:path inputString:inputString];

			return;
		}

		NSString *resultString = [NSString stringWithData:result encoding:NSUTF8StringEncoding];

		[self sendTextualCmdScriptResult:resultString toChannel:targetChannel];
	};

	/* The handler holds the pipe (its reading end would close when this
	 method returns) and lets it go at end of file */
	readingPipe.readabilityHandler = ^(NSFileHandle *handle) {
		NSData *data = handle.availableData;

		if (data.length == 0) {
			handle.readabilityHandler = nil;

			[standardOutputPipe.fileHandleForReading closeFile];
		}

		dispatch_async(outputQueue, ^{
			if (data.length > 0) {
				[output appendData:data];

				return;
			}

			outputEnded = YES;

			if (taskFinished) {
				finish();
			}
		});
	};

	/* Try performing task */
	[task executeWithArguments:taskArguments completionHandler:^(NSError *error) {
		/* Ends the output if the task never ran */
		[writingPipe closeFile];

		dispatch_async(outputQueue, ^{
			taskFinished = YES;

			executionError = error;

			if (outputEnded) {
				finish();
			}
		});
	}];
}

- (void)processBundlesUserMessage:(NSString *)message command:(NSString *)command
{
	NSParameterAssert(message != nil);

	[THOPluginDispatcher userInputCommandInvokedOnClient:self commandString:command messageString:message];
}

- (void)processBundlesServerMessage:(IRCMessage *)message
{
	NSParameterAssert(message != nil);

	[THOPluginDispatcher didReceiveServerInput:message onClient:self];
}

- (BOOL)postReceivedMessage:(IRCMessage *)referenceMessage
{
	NSParameterAssert(referenceMessage != nil);

	return [self postReceivedMessage:referenceMessage
							withText:referenceMessage.sequence
						 destinedFor:nil];
}

- (BOOL)postReceivedMessage:(IRCMessage *)referenceMessage withText:(nullable NSString *)text destinedFor:(nullable IRCChannel *)textDestination
{
	NSParameterAssert(referenceMessage != nil);

	return [self postReceivedCommand:referenceMessage.command
							withText:text
						 destinedFor:textDestination
					referenceMessage:referenceMessage];
}

- (BOOL)postReceivedCommand:(NSString *)command withText:(nullable NSString *)text destinedFor:(nullable IRCChannel *)textDestination referenceMessage:(IRCMessage *)referenceMessage
{
	NSParameterAssert(command != nil);
	NSParameterAssert(referenceMessage != nil);

	return [THOPluginDispatcher receivedCommand:command
									   withText:text
									 authoredBy:referenceMessage.sender
									destinedFor:textDestination
									   onClient:self
									 receivedAt:referenceMessage.receivedAt
							   referenceMessage:referenceMessage];
}

@end

NS_ASSUME_NONNULL_END
