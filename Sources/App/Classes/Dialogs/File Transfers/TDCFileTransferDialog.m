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
#import "TPCPathInfo.h"
#import "TPCPreferencesLocal.h"
#import "TPCPreferencesUserDefaults.h"
#import "TLOInternetAddressLookup.h"
#import "TLOLocalization.h"
#import "TLOTimer.h"
#import "IRCWorld.h"
#import "TVCBasicTableView.h"
#import "TDCFileTransferDialogTableCellPrivate.h"
#import "TDCFileTransferDialogTransferControllerPrivate.h"
#import "TDCFileTransferDialogInternal.h"

NS_ASSUME_NONNULL_BEGIN

/* Refuse more than this many unfinished incoming transfers at a time. */
#define _addReceiverHardLimit			120

@interface TDCFileTransferDialog () <NSMenuItemValidation>
@property (nonatomic, weak) IBOutlet NSButton *clearButton;
@property (nonatomic, weak) IBOutlet NSSegmentedCell *navigationControllerCell;
@property (nonatomic, weak, readwrite) IBOutlet TVCBasicTableView *fileTransferTable;
@property (nonatomic, strong) IBOutlet NSArrayController *fileTransfersController;
@property (nonatomic, strong, nullable) TLOInternetAddressLookup *IPAddressRequest;
@property (readonly) TDCFileTransferDialogSelection navigationSelection;
@property (nonatomic, strong) TLOTimer *maintenanceTimer;
@property (nonatomic, copy, nullable) NSURL *downloadDestinationURLPrivate;
@property (nonatomic, assign) BOOL downloadDestinationURLIsAccessed;

- (IBAction)hideWindow:(id)sender;

- (IBAction)clear:(id)sender;

- (IBAction)startTransferOfFile:(id)sender;
- (IBAction)stopTransferOfFile:(id)sender;
- (IBAction)removeTransferFromList:(id)sender;
- (IBAction)openReceivedFile:(id)sender;
- (IBAction)revealReceivedFileInFinder:(id)sender;

- (IBAction)navigationSelectionDidChange:(id)sender;
@end

@implementation TDCFileTransferDialog

- (instancetype)init
{
	if ((self = [super init])) {
		[self prepareInitialState];
	}

	return self;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCFileTransferDialog" owner:self topLevelObjects:nil];

	self.maintenanceTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[self onMaintenanceTimer];
	} onQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];

	[RZNotificationCenter() addObserver:self selector:@selector(clientWillBeDestroyed:) name:IRCWorldWillDestroyClientNotification object:nil];
}

- (void)dealloc
{
	[RZNotificationCenter() removeObserver:self];

	[self.maintenanceTimer stop];
	 self.maintenanceTimer = nil;
}

- (void)show
{
	[self show:YES restorePosition:YES];
}

- (void)show:(BOOL)makeKeyWindow
{
	[self show:makeKeyWindow restorePosition:YES];
}

- (void)show:(BOOL)makeKeyWindow restorePosition:(BOOL)restorePosition
{
	if (makeKeyWindow) {
		[self.window makeKeyAndOrderFront:nil];
	} else {
		[self.window orderFront:nil];
	}

	if (restorePosition) {
		[self.window restoreWindowStateForClass:self.class];
	}
}

- (nullable TDCFileTransferDialogTransferController *)fileTransferForClient:(IRCClient *)client peer:(NSString *)nickname isSender:(BOOL)isSender token:(nullable NSString *)transferToken port:(uint16_t)port
{
	NSParameterAssert(client != nil);
	NSParameterAssert(nickname != nil);

	TDCFileTransferDialogTransferController *fileTransfer =
	[self fileTransferMatchingCondition:^BOOL(TDCFileTransferDialogTransferController *controller) {
		if (controller.isSender != isSender || [controller isWithClient:client peer:nickname] == NO) {
			return NO;
		}

		if (transferToken) {
			return [transferToken isEqualToString:controller.transferToken];
		}

		return (controller.transferToken == nil && controller.hostPort == port);
	}];

	return fileTransfer;
}

- (nullable TDCFileTransferDialogTransferController *)fileTransferWithUniqueIdentifier:(NSString *)identifier
{
	NSParameterAssert(identifier != nil);

	TDCFileTransferDialogTransferController *fileTransfer =
	[self fileTransferMatchingCondition:^BOOL(TDCFileTransferDialogTransferController *controller) {
		return [identifier isEqualToString:controller.uniqueIdentifier];
	}];

	return fileTransfer;
}

- (BOOL)fileTransferExistsWithToken:(NSString *)transferToken
{
	NSParameterAssert(transferToken != nil);

	TDCFileTransferDialogTransferController *fileTransfer =
	[self fileTransferMatchingCondition:^BOOL(TDCFileTransferDialogTransferController *controller) {
		return [transferToken isEqualToString:controller.transferToken];
	}];

	return (fileTransfer != nil);
}

- (void)prepareForApplicationTermination
{
	LogToConsoleTerminationProgress("Stopping access to download destination bookmark");

	[self stopUsingDownloadDestinationURL];

	LogToConsoleTerminationProgress("Closing file transfer window");

	[self close];

	LogToConsoleTerminationProgress("Preparing all file transfers for destruction");

	[self enumerateFileTransfers:^(TDCFileTransferDialogTransferController *fileTransfer, BOOL *stop) {
		[fileTransfer prepareForPermanentDestruction];
	}];
}

- (nullable NSString *)addReceiverForClient:(IRCClient *)client nickname:(NSString *)nickname address:(NSString *)hostAddress port:(uint16_t)hostPort filename:(NSString *)filename filesize:(uint64_t)totalFilesize token:(nullable NSString *)transferToken
{
	NSParameterAssert(client != nil);
	NSParameterAssert(nickname != nil);
	NSParameterAssert(hostAddress != nil);
	NSParameterAssert(filename != nil);

	/* A hard limit exists to prevent a bad person continuously sending file transfers 
	 which appear in the file transfer, exhausting resources. */
	if ([self unfinishedReceiverCount] >= _addReceiverHardLimit) {
		LogToConsoleError("Max receiver count of %{public}i exceeded", _addReceiverHardLimit);

		return nil;
	}

	TDCFileTransferDialogTransferController *controller = [TDCFileTransferDialogTransferController receiverForClient:client nickname:nickname address:hostAddress port:hostPort filename:filename filesize:totalFilesize token:transferToken];

	if (controller == nil) {
		return nil;
	}

	[self show:NO restorePosition:NO];

	[self addFileTransfer:controller];

	NSString *savePath = self.downloadDestinationURLPrivate.path;

	if ([TPCPreferences fileTransferRequestReplyAction] == TXFileTransferRequestReplyAutomaticallyDownload) {
		if (savePath == nil) {
			savePath = [TPCPathInfo userDownloads];
		}

		[controller openWithPath:savePath];
	}

	return controller.uniqueIdentifier;
}

- (nullable NSString *)addSenderForClient:(IRCClient *)client nickname:(NSString *)nickname path:(NSString *)path autoOpen:(BOOL)autoOpen
{
	NSParameterAssert(client != nil);
	NSParameterAssert(nickname != nil);
	NSParameterAssert(path != nil);

	TDCFileTransferDialogTransferController *controller = [TDCFileTransferDialogTransferController senderForClient:client nickname:nickname path:path];

	if (controller == nil) {
		return nil;
	}

	[self show:YES restorePosition:NO];

	[self addFileTransfer:controller];

	if (autoOpen) {
		[controller open];
	}

	return controller.uniqueIdentifier;
}

- (void)updateClearButton
{
	NSArray *stoppedFileTransfers = [self stoppedFileTransfers];

	self.clearButton.enabled = (stoppedFileTransfers.count > 0);
}

- (void)addFileTransfer:(TDCFileTransferDialogTransferController *)controller
{
	/* Resetting the predicate the each time a controller is added is stupid,
	 but this is a low frequency task that we can forgive. */
	NSPredicate *filterPredicate = self.fileTransfersController.filterPredicate;

	self.fileTransfersController.filterPredicate = nil;

	[self.fileTransfersController insertObject:controller atArrangedObjectIndex:0];

	self.fileTransfersController.filterPredicate = filterPredicate;
}

- (void)removeFileTransfersMatchingClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	NSArray *fileTransfers = [self fileTransfersMatchingClient:client];

	if (fileTransfers.count == 0) {
		return;
	}

	[fileTransfers makeObjectsPerformSelector:@selector(prepareForPermanentDestruction)];

	[self.fileTransfersController removeObjects:fileTransfers];
}

#pragma mark -
#pragma mark Notifications

- (void)clientWillBeDestroyed:(NSNotification *)notification
{
	[self removeFileTransfersMatchingClient:notification.object];
}

#pragma mark -
#pragma mark Actions

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
	NSInteger tag = item.tag;

	NSArray *selectedFileTransfers = [self selectedFileTransfers];

	if (selectedFileTransfers.count == 0) {
		return NO;
	}

	/* Begin actual validation. */
	switch (tag) {
		case 3001:	// Start Download
		{
			for (TDCFileTransferDialogTransferController *fileTransfer in selectedFileTransfers) {
				TDCFileTransferDialogTransferStatus transferStatus = fileTransfer.transferStatus;

				if (transferStatus == TDCFileTransferDialogTransferStatusStopped ||
					transferStatus == TDCFileTransferDialogTransferStatusRecoverableError)
				{
					return YES;
				}
			}

			return NO;
		}
		case 3003: // Stop Download
		{
			for (TDCFileTransferDialogTransferController *fileTransfer in selectedFileTransfers) {
				if (fileTransfer.isStopped == NO) {
					return YES;
				}
			}

			return NO;
		}
		case 3004: // Remove Item
		{
			return YES;
		}
		case 3005: // Open File
		{
			for (TDCFileTransferDialogTransferController *fileTransfer in selectedFileTransfers) {
				TDCFileTransferDialogTransferStatus transferStatus = fileTransfer.transferStatus;

				if (fileTransfer.isSender != NO) {
					continue;
				}

				if (transferStatus == TDCFileTransferDialogTransferStatusComplete) {
					return YES;
				}
			}

			return NO;
		}
		case 3006: // Reveal In Finder
		{
			for (TDCFileTransferDialogTransferController *fileTransfer in selectedFileTransfers) {
				TDCFileTransferDialogTransferStatus transferStatus = fileTransfer.transferStatus;

				if (fileTransfer.isSender != NO) {
					continue;
				}

				if (transferStatus == TDCFileTransferDialogTransferStatusComplete) {
					return YES;
				}
			}

			return NO;
		}
	}

	return NO; // Default validation to NO.
}

- (void)clear:(id)sender
{
	NSArray *stoppedFileTransfers = [self stoppedFileTransfers];

	[stoppedFileTransfers makeObjectsPerformSelector:@selector(prepareForPermanentDestruction)];

	[self.fileTransfersController removeObjects:stoppedFileTransfers];

	[self updateClearButton];
}

- (void)startTransferOfFile:(id)sender
{
	NSString *savePath = self.downloadDestinationURLPrivate.path;

	NSMutableArray<TDCFileTransferDialogTransferController *> *fileTransfersPending = [NSMutableArray array];

	/* Open all file transfers who are senders or have a path */
	[self enumerateSelectedFileTransfers:^(TDCFileTransferDialogTransferController *fileTransfer, NSUInteger index, BOOL *stop) {
		TDCFileTransferDialogTransferStatus transferStatus = fileTransfer.transferStatus;

		if (transferStatus != TDCFileTransferDialogTransferStatusStopped &&
			transferStatus != TDCFileTransferDialogTransferStatusRecoverableError)
		{
			return;
		}

		if (fileTransfer.isSender || fileTransfer.path != nil) {
			[fileTransfer open];

			return;
		} else if (fileTransfer.path == nil && savePath != nil) {
			[fileTransfer openWithPath:savePath];

			return;
		}

		[fileTransfersPending addObject:fileTransfer];
	}];

	/* If there are file transfers that weren't opened because of a missing
	 path, then we now prompt the user for where they want to save the files. */
	if (fileTransfersPending.count == 0) {
		return;
	}

	NSOpenPanel *openDialog = [NSOpenPanel openPanel];

	openDialog.directoryURL = [TPCPathInfo userDownloadsURL];

	openDialog.allowsMultipleSelection = NO;
	openDialog.canChooseDirectories = YES;
	openDialog.canChooseFiles = NO;
	openDialog.canCreateDirectories = YES;
	openDialog.resolvesAliases = YES;

	openDialog.message = TXTLS(@"TDCFileTransferDialog[dcm-w7]");

	openDialog.prompt = TXTLS(@"Prompts[xne-79]");

	[openDialog beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
		if (result != NSModalResponseOK) {
			return;
		}

		NSString *path = openDialog.URL.path;

		for (TDCFileTransferDialogTransferController *fileTransfer in fileTransfersPending) {
			[fileTransfer openWithPath:path];
		}
	}];
}

- (void)stopTransferOfFile:(id)sender
{
	[self enumerateSelectedFileTransfers:^(TDCFileTransferDialogTransferController *fileTransfer, NSUInteger index, BOOL *stop) {
		[fileTransfer closeAndPostNotification:NO];
	}];
}

- (void)removeTransferFromList:(id)sender
{
	NSArray *selectedFileTransfers = [self selectedFileTransfers];

	for (TDCFileTransferDialogTransferController *fileTransfer in selectedFileTransfers) {
		[fileTransfer prepareForPermanentDestruction];
	}

	[self.fileTransfersController removeObjects:selectedFileTransfers];
}

- (void)openReceivedFile:(id)sender
{
	[self enumerateSelectedFileTransfers:^(TDCFileTransferDialogTransferController *fileTransfer, NSUInteger index, BOOL *stop) {
		if (fileTransfer.isSender != NO) {
			return;
		}

		[RZWorkspace() openURL:fileTransfer.fileURL];
	}];
}

- (void)revealReceivedFileInFinder:(id)sender
{
	[self enumerateSelectedFileTransfers:^(TDCFileTransferDialogTransferController *fileTransfer, NSUInteger index, BOOL *stop) {
		if (fileTransfer.isSender != NO) {
			return;
		}

		[RZWorkspace() selectFile:fileTransfer.filePath inFileViewerRootedAtPath:@""];
	}];
}

#pragma mark -
#pragma mark Timer

- (void)updateMaintenanceTimerOnMainThread
{
	NSArray *activeFileTransfers = [self activeFileTransfers];

	if (self.maintenanceTimer.timerIsActive) {
		if (activeFileTransfers.count == 0) {
			[self.maintenanceTimer stop];
		}
	} else {
		if (activeFileTransfers.count > 0) {
			[self.maintenanceTimer start:1.0 onRepeat:YES];
		}
	}
}

- (void)updateMaintenanceTimer
{
	XRPerformBlockSynchronouslyOnMainQueue(^{
		[self updateMaintenanceTimerOnMainThread];
	});
}

- (void)onMaintenanceTimer
{
	NSArray *activeFileTransfers = [self activeFileTransfers];

	for (TDCFileTransferDialogTransferController *fileTransfer in activeFileTransfers) {
		[fileTransfer onMaintenanceTimer];
	}
}

#pragma mark -
#pragma mark Table View Delegate

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	TDCFileTransferDialogTransferController *fileTransfer = self.fileTransfersController.arrangedObjects[row];

	TDCFileTransferDialogTableCell *newView =
	(TDCFileTransferDialogTableCell *)[tableView makeViewWithIdentifier:@"GroupView" owner:self];

	fileTransfer.transferTableCell = newView;

	return newView;
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
	TDCFileTransferDialogTableCell *tableCell = [tableView viewAtColumn:0 row:row makeIfNecessary:NO];

	[tableCell prepareInitialState];
}

#pragma mark -
#pragma mark Network Information

- (nullable NSString *)IPAddress
{
	if ([TPCPreferences fileTransferIPAddressDetectionMethod] == TXFileTransferIPAddressMethodManual) {
		NSString *userAddress = [TPCPreferences fileTransferManuallyEnteredIPAddress];

		if (userAddress.length == 0) {
			return nil;
		}

		return userAddress;
	}

	return self->_IPAddress;
}

- (void)clearIPAddress
{
	self.IPAddress = nil;

	[self.IPAddressRequest cancelLookup];
	self.IPAddressRequest = nil;
}

- (void)requestIPAddress
{
	if (self.IPAddressRequest != nil) {
		return;
	}

	TLOInternetAddressLookup *lookupRequest = [[TLOInternetAddressLookup alloc] initWithDelegate:(id)self];

	[lookupRequest performLookup];

	self.IPAddressRequest = lookupRequest;
}

- (void)internetAddressLookupReturnedAddress:(NSString *)address
{
	self.IPAddress = address;

	/* Senders and reverse receivers both wait for the address */
	[self enumerateFileTransfers:^(TDCFileTransferDialogTransferController *fileTransfer, BOOL *stop) {
		if (fileTransfer.transferStatus != TDCFileTransferDialogTransferStatusWaitingForLocalIPAddress) {
			return;
		}

		[fileTransfer noteIPAddressLookupSucceeded];
	}];

	self.IPAddressRequest = nil;
}

- (void)internetAddressLookupFailed
{
	[self enumerateFileTransfers:^(TDCFileTransferDialogTransferController *fileTransfer, BOOL *stop) {
		if (fileTransfer.transferStatus != TDCFileTransferDialogTransferStatusWaitingForLocalIPAddress) {
			return;
		}

		[fileTransfer noteIPAddressLookupFailed];
	}];

	self.IPAddressRequest = nil;
}

#pragma mark -
#pragma mark Navigation

- (TDCFileTransferDialogSelection)navigationSelection
{
	return self.navigationControllerCell.selectedSegment;
}

- (void)navigationSelectionDidChange:(id)sender
{
	TDCFileTransferDialogSelection selection = self.navigationSelection;

	NSPredicate *filterPredicate = nil;

	if (selection == TDCFileTransferDialogSelectionSending) {
		filterPredicate = [NSPredicate predicateWithFormat:@"isSender == YES"];
	} else if (selection == TDCFileTransferDialogSelectionReceiving) {
		filterPredicate = [NSPredicate predicateWithFormat:@"isSender == NO"];
	}

	self.fileTransfersController.filterPredicate = filterPredicate;
}

#pragma mark -
#pragma mark Transfer Search

/* Offers not yet accepted count too; complete and failed ones don't. */
- (NSUInteger)unfinishedReceiverCount
{
	__block NSUInteger receiverCount = 0;

	[self enumerateFileTransferReceivers:^(TDCFileTransferDialogTransferController *fileTransfer, BOOL *stop) {
		TDCFileTransferDialogTransferStatus transferStatus = fileTransfer.transferStatus;

		if (transferStatus == TDCFileTransferDialogTransferStatusComplete ||
			transferStatus == TDCFileTransferDialogTransferStatusFatalError ||
			transferStatus == TDCFileTransferDialogTransferStatusRecoverableError)
		{
			return;
		}

		receiverCount += 1;
	}];

	return receiverCount;
}

- (NSArray<TDCFileTransferDialogTransferController *> *)stoppedFileTransfers
{
	return [self fileTransfersMatchingCondition:^BOOL(TDCFileTransferDialogTransferController *fileTransfer) {
		return fileTransfer.isStopped;
	}];
}

- (NSArray<TDCFileTransferDialogTransferController *> *)activeFileTransfers
{
	return [self fileTransfersMatchingCondition:^BOOL(TDCFileTransferDialogTransferController *fileTransfer) {
		return fileTransfer.isActive;
	}];
}

- (NSArray<TDCFileTransferDialogTransferController *> *)fileTransfersMatchingCondition:(BOOL (NS_NOESCAPE ^)(TDCFileTransferDialogTransferController *fileTransfer))matchCondition
{
	NSMutableArray<TDCFileTransferDialogTransferController *> *fileTransfers = [NSMutableArray array];

	[self enumerateFileTransfers:^(TDCFileTransferDialogTransferController *fileTransfer, BOOL *stop) {
		if (matchCondition(fileTransfer) == NO) {
			return;
		}

		[fileTransfers addObject:fileTransfer];
	}];

	return [fileTransfers copy];
}

- (nullable TDCFileTransferDialogTransferController *)fileTransferMatchingCondition:(BOOL (NS_NOESCAPE ^)(TDCFileTransferDialogTransferController *fileTransfer))matchCondition
{
	__block TDCFileTransferDialogTransferController *fileTransferMatched = nil;

	[self enumerateFileTransfers:^(TDCFileTransferDialogTransferController *fileTransfer, BOOL *stop) {
		if (matchCondition(fileTransfer) == NO) {
			return;
		}

		fileTransferMatched = fileTransfer;

		*stop = YES;
	}];

	return fileTransferMatched;
}

- (NSArray<TDCFileTransferDialogTransferController *> *)selectedFileTransfers
{
	NSMutableArray<TDCFileTransferDialogTransferController *> *selectedFileTransfers = [NSMutableArray array];

	[self enumerateSelectedFileTransfers:^(TDCFileTransferDialogTransferController *fileTransfer, NSUInteger index, BOOL *stop) {
		[selectedFileTransfers addObject:fileTransfer];
	}];

	return [selectedFileTransfers copy];
}

- (NSArray<TDCFileTransferDialogTransferController *> *)fileTransfersMatchingClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	return [self fileTransfersMatchingCondition:^BOOL(TDCFileTransferDialogTransferController * _Nonnull fileTransfer) {
		return (fileTransfer.client == client);
	}];
}

- (void)enumerateSelectedFileTransfers:(void (NS_NOESCAPE ^)(TDCFileTransferDialogTransferController *fileTransfer, NSUInteger index, BOOL *stop))enumerationBlock
{
	NSIndexSet *selectedRows = self.fileTransferTable.selectedRowIndexes;

	[selectedRows enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		TDCFileTransferDialogTransferController *fileTransfer = self.fileTransfersController.arrangedObjects[index];

		enumerationBlock(fileTransfer, index, stop);
	}];
}

- (void)enumerateFileTransfers:(void (NS_NOESCAPE ^)(TDCFileTransferDialogTransferController *fileTransfer, BOOL *stop))enumerationBlock
{
	[self _enumerateFileTransfers:enumerationBlock limitScope:NO limitScopeToSenders:NO];
}

- (void)enumerateFileTransferReceivers:(void (NS_NOESCAPE ^)(TDCFileTransferDialogTransferController *fileTransfer, BOOL *stop))enumerationBlock
{
	[self _enumerateFileTransfers:enumerationBlock limitScope:YES limitScopeToSenders:NO];
}

- (void)_enumerateFileTransfers:(void (NS_NOESCAPE ^)(TDCFileTransferDialogTransferController *fileTransfer, BOOL *stop))enumerationBlock limitScope:(BOOL)limitScope limitScopeToSenders:(BOOL)limitScopeToSenders
{
	NSParameterAssert(enumerationBlock != nil);

	for (TDCFileTransferDialogTransferController *fileTransfer in self.fileTransfersController.arrangedObjects) {
		if (limitScope && limitScopeToSenders != fileTransfer.isSender) {
			continue;
		}

		BOOL stop = NO;

		enumerationBlock(fileTransfer, &stop);

		if (stop) {
			break;
		}
	}
}

#pragma mark -
#pragma mark Window Delegate

- (void)windowWillClose:(NSNotification *)note
{
	[self.window saveWindowStateForClass:self.class];
}

- (void)hideWindow:(id)sender
{
	[self close];
}

@end

#pragma mark -
#pragma mark Destination Folder

@implementation TDCFileTransferDialog (TDCFileTransferDialogDownloadDestinationExtension)

- (nullable NSURL *)downloadDestinationURL
{
	return self.downloadDestinationURLPrivate;
}

- (void)startUsingDownloadDestinationURL
{
	NSData *bookmark = [RZUserDefaults() dataForKey:@"File Transfers -> File Transfer Download Folder Bookmark"];

	if (bookmark == nil) {
		return;
	}

	BOOL resolvedBookmarkIsStale = NO;

	NSError *resolvedBookmarkError = nil;

	NSURL *resolvedBookmark =
	[NSURL URLByResolvingBookmarkData:bookmark
							  options:NSURLBookmarkResolutionWithSecurityScope
						relativeToURL:nil
				  bookmarkDataIsStale:&resolvedBookmarkIsStale
								error:&resolvedBookmarkError];

	if (resolvedBookmark == nil) {
		LogToConsoleError("Error creating bookmark for URL: %{public}@",
			  resolvedBookmarkError.localizedDescription);

		return;
	}

	self.downloadDestinationURLPrivate = resolvedBookmark;

	self.downloadDestinationURLIsAccessed = [resolvedBookmark startAccessingSecurityScopedResource];

	if (self.downloadDestinationURLIsAccessed == NO) {
		LogToConsoleError("Failed to access bookmark");

		return;
	}

	/* A stale bookmark (the folder moved or was renamed) still resolves,
	 but has to be replaced while it is being accessed. */
	if (resolvedBookmarkIsStale) {
		NSData *newBookmark = [resolvedBookmark bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
										 includingResourceValuesForKeys:nil
														  relativeToURL:nil
																  error:NULL];

		if (newBookmark) {
			[RZUserDefaults() setObject:newBookmark forKey:@"File Transfers -> File Transfer Download Folder Bookmark"];
		}
	}
}

- (void)stopUsingDownloadDestinationURL
{
	if (self.downloadDestinationURLIsAccessed) {
		[self.downloadDestinationURLPrivate stopAccessingSecurityScopedResource];

		self.downloadDestinationURLIsAccessed = NO;
	}

	self.downloadDestinationURLPrivate = nil;
}

- (void)setDownloadDestinationBookmark:(nullable NSData *)downloadDestinationBookmark
{
	[self stopUsingDownloadDestinationURL];

	[RZUserDefaults() setObject:downloadDestinationBookmark forKey:@"File Transfers -> File Transfer Download Folder Bookmark"];

	[self startUsingDownloadDestinationURL];
}

@end

NS_ASSUME_NONNULL_END
