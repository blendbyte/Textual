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

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "TXGlobalModels.h"
#import "TLOLocalization.h"
#import "TDCFileTransferDialogTransferControllerPrivate.h"
#import "TDCFileTransferDialogTableCellPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _filenameFieldWithProgressBarYCord				4
#define _filenameFieldWithoutProgressBarYCord			12

#define _transferInfoFieldWithProgressBarYCord			6
#define _transferInfoFieldWithoutProgressBarYCord		16

@interface TDCFileTransferDialogTableCell ()
@property (readonly) TDCFileTransferDialogTransferController *cellItem;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic, weak) IBOutlet NSImageView *fileIconView;
@property (nonatomic, weak) IBOutlet NSTextField *filenameTextField;
@property (nonatomic, weak) IBOutlet NSTextField *filesizeTextField;
@property (nonatomic, weak) IBOutlet NSTextField *transferProgressTextField;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *filenameTextFieldConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *transferProgressTextFieldConstraint;
@property (readonly) BOOL isReceiving;
@property (readonly) TDCFileTransferDialogTransferStatus transferStatus;
@property (readonly) uint64_t processedFilesize;
@property (readonly) uint64_t totalFilesize;
@property (readonly) uint64_t currentRecord;
@property (readonly, copy) NSArray<NSNumber *> *speedRecords;
@property (readonly, copy, nullable) NSString *errorMessageDescription;
@property (readonly, copy, nullable) NSString *path;
@property (readonly, copy) NSString *filename;
@property (readonly, copy, nullable) NSString *filePath;
@property (readonly, copy) NSString *hostAddress;
@property (readonly, copy) NSString *peerNickname;
@property (readonly) uint16_t hostPort;
@end

@implementation TDCFileTransferDialogTableCell

#pragma mark -
#pragma mark Status Information

- (void)prepareInitialState
{
	NSString *filename = self.filename;

	self.filenameTextField.stringValue = filename;

	uint64_t totalFilesize = self.totalFilesize;

	NSString *totalFilesizeString = [NSByteCountFormatter stringFromByteCountWithPaddedDigits:totalFilesize];

	self.filesizeTextField.stringValue = totalFilesizeString;

	self.progressIndicator.doubleValue = 0;
	self.progressIndicator.minValue = 0;
	self.progressIndicator.maxValue = totalFilesize;

	UTType *fileType = [UTType typeWithFilenameExtension:filename.pathExtension];

	NSImage *iconImage = [RZWorkspace() iconForContentType:(fileType ?: UTTypeData)];

	self.fileIconView.image = iconImage;

	[self reloadStatusInformation];
}

- (void)reloadStatusInformation
{
	XRPerformBlockSynchronouslyOnMainQueue(^{
		[self _reloadStatusInformation];
	});
}

- (void)_reloadStatusInformation
{
	TDCFileTransferDialogTransferStatus transferStatus = self.transferStatus;

	/* No progress to show until data moves (connecting has its own indicator) */
	BOOL transferIsStopped = (self.cellItem.isActive == NO &&
							  transferStatus != TDCFileTransferDialogTransferStatusConnecting);

	uint64_t processedFilesize = self.processedFilesize;

	if (transferIsStopped) {
		if (self.progressIndicator.hidden == NO) {
			self.progressIndicator.hidden = YES;

			self.filenameTextFieldConstraint.constant = _filenameFieldWithoutProgressBarYCord;

			self.transferProgressTextFieldConstraint.constant = _transferInfoFieldWithoutProgressBarYCord;

			[self layoutSubtreeIfNeeded];
		}
	} else {
		if (self.progressIndicator.hidden) {
			self.progressIndicator.hidden = NO;

			self.filenameTextFieldConstraint.constant = _filenameFieldWithProgressBarYCord;

			self.transferProgressTextFieldConstraint.constant = _transferInfoFieldWithProgressBarYCord;

			[self layoutSubtreeIfNeeded];
		}
	}

	if (transferIsStopped == NO) {
		if (transferStatus == TDCFileTransferDialogTransferStatusConnecting) {
			self.progressIndicator.indeterminate = YES;

			[self.progressIndicator startAnimation:nil];
		} else {
			self.progressIndicator.indeterminate = NO;

			self.progressIndicator.doubleValue = self.processedFilesize;
		}
	}

	switch (transferStatus) {
		case TDCFileTransferDialogTransferStatusStopped:
		{
			if (self.isReceiving) {
				self.transferProgressTextField.stringValue = TXTLS(@"TDCFileTransferDialog[jvh-u7]", self.peerNickname);
			} else {
				self.transferProgressTextField.stringValue = TXTLS(@"TDCFileTransferDialog[w3h-p8]", self.peerNickname);
			}

			break;
		}
		case TDCFileTransferDialogTransferStatusMappingListeningPort:
		{
			if (self.isReceiving) {
				self.transferProgressTextField.stringValue = TXTLS(@"TDCFileTransferDialog[495-90]", self.peerNickname);
			} else {
				self.transferProgressTextField.stringValue = TXTLS(@"TDCFileTransferDialog[j1z-88]", self.peerNickname);
			}

			break;
		}
		case TDCFileTransferDialogTransferStatusWaitingForLocalIPAddress:
		{
			if (self.isReceiving) {
				self.transferProgressTextField.stringValue = TXTLS(@"TDCFileTransferDialog[6t1-mb]", self.peerNickname);
			} else {
				self.transferProgressTextField.stringValue = TXTLS(@"TDCFileTransferDialog[onl-av]", self.peerNickname);
			}

			break;
		}
		case TDCFileTransferDialogTransferStatusInitializing:
		{
			if (self.isReceiving) {
				self.transferProgressTextField.stringValue = TXTLS(@"TDCFileTransferDialog[42z-mg]", self.peerNickname);
			} else {
				self.transferProgressTextField.stringValue = TXTLS(@"TDCFileTransferDialog[pcv-kg]", self.peerNickname);
			}

			break;
		}
		case TDCFileTransferDialogTransferStatusIsListeningAsSender:
		{
			self.transferProgressTextField.stringValue = TXTLS(@"TDCFileTransferDialog[ca5-2v]", self.peerNickname);

			break;
		}
		case TDCFileTransferDialogTransferStatusIsListeningAsReceiver:
		{
			self.transferProgressTextField.stringValue = TXTLS(@"TDCFileTransferDialog[pip-z6]", self.peerNickname);

			break;
		}
		case TDCFileTransferDialogTransferStatusFatalError:
		case TDCFileTransferDialogTransferStatusRecoverableError:
		{
			self.transferProgressTextField.stringValue = self.errorMessageDescription;

			break;
		}
		case TDCFileTransferDialogTransferStatusComplete:
		{
			if (self.isReceiving) {
				self.transferProgressTextField.stringValue = TXTLS(@"TDCFileTransferDialog[6gu-za]", self.peerNickname);
			} else {
				self.transferProgressTextField.stringValue = TXTLS(@"TDCFileTransferDialog[rx7-xy]", self.peerNickname);
			}

			break;
		}
		case TDCFileTransferDialogTransferStatusSending:
		case TDCFileTransferDialogTransferStatusReceiving:
		{
			/* Format time remaining */
			NSTimeInterval timeRemaining = 0;

			NSString *timeRemainingString = nil;

			uint64_t currentSpeed = self.currentSpeed;

			if (currentSpeed > 0) {
				timeRemaining = ((self.totalFilesize - processedFilesize) / currentSpeed);

				if (timeRemaining > 0) {
					timeRemainingString = TXHumanReadableTimeInterval(timeRemaining, YES, (NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond));
				}
			}

			/* Update status */
			NSString *totalFilesizeString = self.filesizeTextField.stringValue;

			NSString *currentSpeedString = [NSByteCountFormatter stringFromByteCountWithPaddedDigits:currentSpeed];
			NSString *processedFilesizeString = [NSByteCountFormatter stringFromByteCountWithPaddedDigits:processedFilesize];

			NSString *statusString = nil;

			if (self.isReceiving) {
				if (timeRemainingString) {
					statusString = TXTLS(@"TDCFileTransferDialog[9xn-7j]", processedFilesizeString, totalFilesizeString, currentSpeedString, self.peerNickname, timeRemainingString);
				} else {
					statusString = TXTLS(@"TDCFileTransferDialog[7dk-lp]", processedFilesizeString, totalFilesizeString, currentSpeedString, self.peerNickname);
				}
			} else {
				if (timeRemainingString) {
					statusString = TXTLS(@"TDCFileTransferDialog[u17-ql]", processedFilesizeString, totalFilesizeString, currentSpeedString, self.peerNickname, timeRemainingString);
				} else {
					statusString = TXTLS(@"TDCFileTransferDialog[nvm-nd]", processedFilesizeString, totalFilesizeString, currentSpeedString, self.peerNickname);
				}
			}

			self.transferProgressTextField.stringValue = statusString;

			break;
		}
		case TDCFileTransferDialogTransferStatusConnecting:
		{
			self.transferProgressTextField.stringValue = TXTLS(@"TDCFileTransferDialog[7nf-fr]", self.peerNickname);

			break;
		}
		case TDCFileTransferDialogTransferStatusWaitingForReceiverToAccept:
		{
			self.transferProgressTextField.stringValue = TXTLS(@"TDCFileTransferDialog[cku-24]", self.peerNickname);

			break;
		}
		case TDCFileTransferDialogTransferStatusWaitingForResumeAccept:
		{
			self.transferProgressTextField.stringValue = TXTLS(@"TDCFileTransferDialog[gxq-zu]", self.peerNickname);

			break;
		}
	}

	/* Update clear button */
	[self updateClearButton];
}

#pragma mark -
#pragma mark Proxy Methods

- (void)updateClearButton
{
	[self.cellItem updateClearButton];
}

- (void)onMaintenanceTimer
{
	[self.cellItem onMaintenanceTimer];
}

#pragma mark -
#pragma mark Properties

- (TDCFileTransferDialogTransferController *)cellItem
{
	return self.objectValue;
}

- (TDCFileTransferDialogTransferStatus)transferStatus
{
	return self.cellItem.transferStatus;
}

- (BOOL)isReceiving
{
	return (self.cellItem.isSender == NO);
}

- (nullable NSString *)path
{
	return self.cellItem.path;
}

- (NSString *)filename
{
	return self.cellItem.filename;
}

- (nullable NSString *)filePath
{
	return self.cellItem.filePath;
}

- (NSString *)peerNickname
{
	return self.cellItem.peerNickname;
}

- (nullable NSString *)errorMessageDescription
{
	return self.cellItem.errorMessageDescription;
}

- (NSString *)hostAddress
{
	return self.cellItem.hostAddress;
}

- (uint16_t)hostPort
{
	return self.cellItem.hostPort;
}

- (uint64_t)totalFilesize
{
	return self.cellItem.totalFilesize;
}

- (uint64_t)processedFilesize
{
	return self.cellItem.processedFilesize;
}

- (uint64_t)currentRecord
{
	return self.cellItem.currentRecord;
}

- (uint64_t)currentSpeed
{
	NSArray *speedRecords = self.speedRecords;

	if (speedRecords.count == 0) {
		return 0;
	}

	uint64_t totalTransferred = 0;

	for (NSNumber *record in speedRecords) {
		totalTransferred += record.unsignedLongLongValue;
	}

	return (totalTransferred / speedRecords.count);
}

- (NSArray<NSNumber *> *)speedRecords
{
	return self.cellItem.speedRecords;
}

@end

NS_ASSUME_NONNULL_END
