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

#import <XCTest/XCTest.h>

#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCFileTransferDialogTransferControllerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCFileTransferDialog (Testing)
- (void)addFileTransfer:(TDCFileTransferDialogTransferController *)controller;
@end

@interface TDCFileTransferTests : XCTestCase
@end

@implementation TDCFileTransferTests

/* A DCC reply (SEND, RESUME, ACCEPT) must only ever reach a transfer with
 the same peer on the same connection, or anyone could redirect it. */
- (void)testRepliesMatchOnlyTheSamePeerOnTheSameClient
{
	IRCClient *client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];
	IRCClient *otherClient = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	TDCFileTransferDialog *dialog = [TDCFileTransferDialog new];

	TDCFileTransferDialogTransferController *byToken =
	[TDCFileTransferDialogTransferController receiverForClient:client nickname:@"alice" address:@"192.0.2.1" port:0 filename:@"a.txt" filesize:10 token:@"1234567"];

	TDCFileTransferDialogTransferController *byPort =
	[TDCFileTransferDialogTransferController receiverForClient:client nickname:@"bob" address:@"192.0.2.2" port:5000 filename:@"b.txt" filesize:10 token:nil];

	[dialog addFileTransfer:byToken];
	[dialog addFileTransfer:byPort];

	XCTAssertEqual([dialog fileTransferForClient:client peer:@"alice" isSender:NO token:@"1234567" port:0], byToken);
	XCTAssertEqual([dialog fileTransferForClient:client peer:@"ALICE" isSender:NO token:@"1234567" port:0], byToken);
	XCTAssertNil([dialog fileTransferForClient:client peer:@"mallory" isSender:NO token:@"1234567" port:0]);
	XCTAssertNil([dialog fileTransferForClient:otherClient peer:@"alice" isSender:NO token:@"1234567" port:0]);
	XCTAssertNil([dialog fileTransferForClient:client peer:@"alice" isSender:YES token:@"1234567" port:0]);

	XCTAssertEqual([dialog fileTransferForClient:client peer:@"bob" isSender:NO token:nil port:5000], byPort);
	XCTAssertNil([dialog fileTransferForClient:client peer:@"mallory" isSender:NO token:nil port:5000]);
	XCTAssertNil([dialog fileTransferForClient:otherClient peer:@"bob" isSender:NO token:nil port:5000]);
}

/* Only Textual's own partial download of the same file from the same peer
 is resumed; a peer must never append to (or learn the size of) another file.
 Offered names can't create dotfiles. */
- (void)testResumeOnlyOntoOwnPartialDownloads
{
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];

	XCTAssertTrue([[NSData dataWithBytes:"partial" length:7] writeToFile:path atomically:NO]);

	BOOL (^isPartial)(NSString *, NSString *, uint64_t) = ^BOOL(NSString *clientIdentifier, NSString *peer, uint64_t filesize) {
		return [TDCFileTransferDialogTransferController fileAtPath:path isPartialDownloadForClientIdentifier:clientIdentifier peer:peer filename:@"file.zip" filesize:filesize];
	};

	XCTAssertFalse(isPartial(@"client", @"alice", 100), @"a file Textual didn't download is never resumed");

	[TDCFileTransferDialogTransferController recordPartialDownloadAtPath:path clientIdentifier:@"client" peer:@"Alice" filename:@"file.zip" filesize:100];

	XCTAssertTrue(isPartial(@"client", @"alice", 100));
	XCTAssertFalse(isPartial(@"client", @"mallory", 100));
	XCTAssertFalse(isPartial(@"other-client", @"alice", 100));
	XCTAssertFalse(isPartial(@"client", @"alice", 200));

	/* Another file put in its place under the same name */
	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];

	XCTAssertTrue([[NSData dataWithBytes:"replaced" length:8] writeToFile:path atomically:NO]);

	XCTAssertFalse(isPartial(@"client", @"alice", 100), @"a replaced file is never resumed");

	[TDCFileTransferDialogTransferController recordPartialDownloadAtPath:path clientIdentifier:@"client" peer:@"alice" filename:@"file.zip" filesize:100];
	[TDCFileTransferDialogTransferController forgetPartialDownloadAtPath:path];

	XCTAssertFalse(isPartial(@"client", @"alice", 100), @"a completed download is never resumed");

	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];

	XCTAssertEqualObjects([TDCFileTransferDialogTransferController filenameForOfferedFilename:@".zshrc"], @"_.zshrc");
	XCTAssertEqualObjects([TDCFileTransferDialogTransferController filenameForOfferedFilename:@"../.ssh/config"], @"_.._.ssh_config");
	XCTAssertEqualObjects([TDCFileTransferDialogTransferController filenameForOfferedFilename:@"photo.jpg"], @"photo.jpg");
}

/* A dropped or pasted file is only ever offered for sending to one person
 who can be reached: never to a channel or the console, never a folder,
 never while disconnected. */
- (void)testDroppedFilesAreOnlyOfferedToAReachablePerson
{
	NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
	NSString *file = [folder stringByAppendingPathComponent:@"notes.txt"];
	NSString *subfolder = [folder stringByAppendingPathComponent:@"photos"];
	NSString *missing = [folder stringByAppendingPathComponent:@"gone.txt"];

	XCTAssertTrue([[NSFileManager defaultManager] createDirectoryAtPath:subfolder withIntermediateDirectories:YES attributes:nil error:NULL]);
	XCTAssertTrue([[NSData dataWithBytes:"hello" length:5] writeToFile:file atomically:NO]);

	XCTAssertEqualObjects([TDCFileTransferDialog sendableFilePaths:(@[file, subfolder, missing])], @[file]);

	[[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];

	TDCFileTransferDropAnswer (^answer)(NSUInteger, NSString * _Nullable, BOOL) = ^(NSUInteger count, NSString * _Nullable recipient, BOOL connected) {
		return [TDCFileTransferDialog dropAnswerForSendableFileCount:count recipient:recipient connected:connected];
	};

	XCTAssertEqual(answer(2, @"alice", YES), TDCFileTransferDropAnswerSend);
	XCTAssertEqual(answer(2, @"alice", NO), TDCFileTransferDropAnswerNotConnected);
	XCTAssertEqual(answer(0, @"alice", YES), TDCFileTransferDropAnswerNothingToSend);
	XCTAssertEqual(answer(2, nil, YES), TDCFileTransferDropAnswerNoRecipient, @"a channel or the console");
	XCTAssertEqual(answer(2, @"", YES), TDCFileTransferDropAnswerNoRecipient);
	XCTAssertEqual(answer(0, nil, NO), TDCFileTransferDropAnswerNoRecipient);
}

@end

NS_ASSUME_NONNULL_END
