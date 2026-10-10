/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
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

#import "TXMasterController.h"
#import "IRCClient.h"
#import "IRCTreeItem.h"
#import "IRCWorld.h"
#import "TVCLogControllerPrivate.h"
#import "ICLURLSessionPrivate.h"
#import "ICLPayload.h"
#import "ICLInlineContentLoaderPrivate.h"
#import "TVCLogControllerInlineMediaServicePrivate.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TVCLogControllerInlineMediaService

+ (TVCLogControllerInlineMediaService *)sharedInstance
{
	static id sharedSelf = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedSelf = [[self alloc] init];
	});

	return sharedSelf;
}

- (void)prepareForApplicationTermination
{
	LogToConsoleTerminationProgress("Cancelling inline media requests");

	[[ICLInlineContentLoader sharedLoader] prepareForApplicationTermination];
}

#pragma mark -
#pragma mark Public API

- (void)processAddress:(NSString *)address withUniqueIdentifier:(NSString *)uniqueIdentifier atLineNumber:(NSString *)lineNumber index:(NSUInteger)index forItem:(IRCTreeItem *)item
{
	NSParameterAssert(address != nil);
	NSParameterAssert(uniqueIdentifier != nil);
	NSParameterAssert(lineNumber != nil);
	NSParameterAssert(item != nil);

	/* WebKit is able to translate an address to punycode
	 for us by giving it a pasteboard with the URL. */
	NSURL *url = address.URLUsingWebKitPasteboard;

	if (url == nil) {
		LogToConsoleError("Address could not be normalized");

		return;
	}

	[self processURL:url withUniqueIdentifier:uniqueIdentifier atLineNumber:lineNumber index:index forItem:item];
}

- (void)processURL:(NSURL *)url withUniqueIdentifier:(NSString *)uniqueIdentifier atLineNumber:(NSString *)lineNumber index:(NSUInteger)index forItem:(IRCTreeItem *)item
{
	NSParameterAssert(url != nil);
	NSParameterAssert(uniqueIdentifier != nil);
	NSParameterAssert(lineNumber != nil);
	NSParameterAssert(item != nil);

	NSString *viewIdentifier = item.uniqueIdentifier;

	/* Requests go through the server's proxy, like its connection */
	NSURLSession *session = [ICLURLSession sessionForClient:item.associatedClient];

	/* The loader and its modules run on the main thread */
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[[ICLInlineContentLoader sharedLoader] processURL:url withUniqueIdentifier:uniqueIdentifier atLineNumber:lineNumber index:index inView:viewIdentifier session:session];
	});
}

#pragma mark -
#pragma mark Results

- (void)processingPayloadSucceeded:(ICLPayload *)payload
{
	IRCTreeItem *item = [worldController() findItemWithId:payload.viewIdentifier];

	if (item == nil) {
		return;
	}

	[self _processingPayloadSucceeded:payload forItem:item];
}

- (void)processingPayload:(ICLPayload *)payload failedWithError:(NSError *)error
{
	IRCTreeItem *item = [worldController() findItemWithId:payload.viewIdentifier];

	if (item == nil) {
		return;
	}

	[self _processingPayload:payload forItem:item failedWithError:error];
}

- (void)_processingPayloadSucceeded:(ICLPayload *)payload forItem:(IRCTreeItem *)item
{
	[item.viewController processingInlineMediaPayloadSucceeded:payload];
}

- (void)_processingPayload:(ICLPayload *)payload forItem:(IRCTreeItem *)item failedWithError:(NSError *)error
{
	[item.viewController processingInlineMediaPayload:payload failedWithError:error];
}


@end

NS_ASSUME_NONNULL_END
