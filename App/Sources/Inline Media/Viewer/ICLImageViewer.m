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

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "TLOLocalization.h"
#import "TPCPathInfo.h"
#import "ICLMediaSchemeHandlerPrivate.h"
#import "ICLURLSessionPrivate.h"
#import "ICLImageViewer.h"

NS_ASSUME_NONNULL_BEGIN

static NSToolbarItemIdentifier const ICLImageViewerSaveItem = @"ICLImageViewerSave";

@interface ICLImageViewer ()
@property (nonatomic, strong) ICLMediaSchemeEntry *entry;
@property (nonatomic, strong, nullable) ICLMediaFetch *saveFetch;
@end

@implementation ICLImageViewer

+ (void)showImageAtMediaURL:(NSURL *)mediaURL linkURL:(NSURL *)linkURL imageSize:(NSSize)imageSize
{
	NSParameterAssert(mediaURL != nil);
	NSParameterAssert(linkURL != nil);

	ICLMediaSchemeEntry *entry = [[ICLMediaSchemeHandler sharedHandler] entryForMediaURL:mediaURL];

	if (entry == nil || entry.type != ICLMediaTypeImage) {
		return;
	}

	ICLImageViewer *openViewer = [self openViewerPassingTest:^BOOL(ICLMediaViewer *viewer) {
		return ([viewer isKindOfClass:[ICLImageViewer class]] && [((ICLImageViewer *)viewer).entry.url isEqual:entry.url]);
	}];

	if (openViewer) {
		[openViewer.window makeKeyAndOrderFront:nil];

		return;
	}

	NSURL *url = entry.url;

	NSString *title = url.lastPathComponent.stringByRemovingPercentEncoding;

	if (title.length == 0 || [title isEqualToString:@"/"]) {
		title = url.host;
	}

	NSSize contentSize = [self contentSizeForMediaSize:imageSize onScreen:([NSApp mainWindow].screen ?: [NSScreen mainScreen])];

	ICLImageViewer *viewer = [[self alloc] initWithLinkURL:linkURL title:title contentSize:contentSize];

	viewer.entry = entry;

	[viewer showViewer];
}

- (void)loadContent
{
	ICLMediaSchemeEntry *entry = self.entry;

	/* A new address: the chat view's may be forgotten while this is open */
	NSURL *imageURL =
	[[ICLMediaSchemeHandler sharedHandler] URLForMediaAtURL:entry.url
													session:entry.session
													   type:ICLMediaTypeImage
											  maximumLength:entry.maximumLength];

	NSString *html =
	[NSString stringWithFormat:
	 @"<!DOCTYPE html><html><head><meta charset=\"utf-8\"><style>"
	 @":root { color-scheme: light dark; }"
	 @"html, body { margin: 0; height: 100%%; }"
	 @"body { display: flex; align-items: center; justify-content: center; background-color: Canvas; }"
	 @"img { max-width: 100%%; max-height: 100%%; object-fit: contain; }"
	 @"</style></head><body><img src=\"%@\" alt=\"\"></body></html>", imageURL.absoluteString];

	[self.webView loadHTMLString:html baseURL:nil];
}

#pragma mark -
#pragma mark Saving

- (IBAction)saveToDownloads:(nullable id)sender
{
	if (self.saveFetch) {
		return;
	}

	NSURL *downloadsURL = [TPCPathInfo userDownloadsURL];

	if (downloadsURL == nil) {
		self.window.subtitle = TXTLS(@"TVCMainWindow[ivw-sf]");

		return;
	}

	ICLMediaSchemeEntry *entry = self.entry;

	/* Fetched again with every check; the bytes are written as they come */
	ICLMediaFetch *fetch =
	[[ICLMediaFetch alloc] initWithURL:entry.url
							   session:[ICLURLSession mediaSessionForSession:entry.session]
								  type:ICLMediaTypeImage
						 maximumLength:entry.maximumLength
						   rangeHeader:nil];

	NSMutableData *data = [NSMutableData data];

	__block NSString *contentType = nil;

	fetch.responseBlock = ^(NSInteger statusCode, NSDictionary<NSString *, NSString *> *headerFields) {
		contentType = headerFields[@"Content-Type"];
	};

	fetch.dataBlock = ^(NSData *dataIn) {
		[data appendData:dataIn];
	};

	/* The viewer stays until the picture is saved, also when its window is
	 closed first (it was released, and the picture silently not saved) */
	fetch.completionBlock = ^(NSError * _Nullable error) {
		self.saveFetch = nil;

		if (error || data.length == 0) {
			self.window.subtitle = TXTLS(@"TVCMainWindow[ivw-sf]");

			return;
		}

		[self _writeData:data contentType:contentType toFolder:downloadsURL];
	};

	self.saveFetch = fetch;

	[fetch start];
}

- (void)_writeData:(NSData *)data contentType:(nullable NSString *)contentType toFolder:(NSURL *)folderURL
{
	NSParameterAssert(data != nil);
	NSParameterAssert(folderURL != nil);

	NSString *fileName = [self.class fileNameForImageAtURL:self.entry.url contentType:contentType];

	NSString *baseName = fileName.stringByDeletingPathExtension;
	NSString *extension = fileName.pathExtension;

	/* "cat.jpg", then "cat 2.jpg", … */
	for (NSUInteger number = 1; number < 1000; number++) {
		NSString *candidate = fileName;

		if (number > 1) {
			candidate = [NSString stringWithFormat:@"%@ %lu", baseName, number];

			if (extension.length > 0) {
				candidate = [candidate stringByAppendingPathExtension:extension];
			}
		}

		NSURL *fileURL = [folderURL URLByAppendingPathComponent:candidate isDirectory:NO];

		NSError *writeError = nil;

		if ([data writeToURL:fileURL options:NSDataWritingWithoutOverwriting error:&writeError]) {
			self.window.subtitle = TXTLS(@"TVCMainWindow[ivw-sv]", candidate);

#if TEXTUAL_BUILT_FOR_APP_STORE_DISTRIBUTION == 0
			/* The Downloads stack in the Dock bounces (a notification of the
			 system's own, so not in the App Store build) */
			[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.apple.DownloadFileFinished" object:fileURL.path];
#endif

			return;
		}

		if ([writeError.domain isEqualToString:NSCocoaErrorDomain] && writeError.code == NSFileWriteFileExistsError) {
			continue;
		}

		LogToConsoleError("Failed to save image: %{public}@", writeError.localizedDescription);

		break;
	}

	self.window.subtitle = TXTLS(@"TVCMainWindow[ivw-sf]");
}

+ (NSString *)fileNameForImageAtURL:(NSURL *)url contentType:(nullable NSString *)contentType
{
	NSParameterAssert(url != nil);

	NSString *fileName = url.lastPathComponent.stringByRemovingPercentEncoding;

	fileName = [fileName stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
	fileName = [fileName stringByReplacingOccurrencesOfString:@":" withString:@"-"];

	/* Control characters (from %00 to %1F in the address) have no place in a name */
	fileName = [[fileName componentsSeparatedByCharactersInSet:[NSCharacterSet controlCharacterSet]] componentsJoinedByString:@"-"];

	fileName = [fileName stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@". \t\n"]];

	/* A name is at most 255 bytes of UTF-8: room is left for the extension,
	 and a character is never cut in half */
	while ([fileName lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 200) {
		NSRange lastCharacter = [fileName rangeOfComposedCharacterSequenceAtIndex:(fileName.length - 1)];

		fileName = [fileName substringToIndex:lastCharacter.location];
	}

	if (fileName.length == 0 || [fileName isEqualToString:@"-"]) {
		fileName = @"image";
	}

	UTType *type = ((contentType) ? [UTType typeWithMIMEType:contentType] : nil);

	NSString *typeExtension = type.preferredFilenameExtension;

	if (typeExtension == nil) {
		return fileName;
	}

	NSArray<NSString *> *typeExtensions = type.tags[UTTagClassFilenameExtension];

	if ([typeExtensions containsObject:fileName.pathExtension.lowercaseString]) {
		return fileName;
	}

	return [fileName stringByAppendingPathExtension:typeExtension];
}

#pragma mark -
#pragma mark Toolbar and Menu

- (NSArray<NSToolbarItemIdentifier> *)toolbarItemIdentifiers
{
	return [[super toolbarItemIdentifiers] arrayByAddingObject:ICLImageViewerSaveItem];
}

- (nullable NSToolbarItem *)toolbarItemForIdentifier:(NSToolbarItemIdentifier)identifier
{
	if ([identifier isEqualToString:ICLImageViewerSaveItem]) {
		return [self toolbarItemWithIdentifier:identifier label:TXTLS(@"TVCMainWindow[ivw-sd]") symbolName:@"square.and.arrow.down" action:@selector(saveToDownloads:)];
	}

	return [super toolbarItemForIdentifier:identifier];
}

- (NSArray<NSMenuItem *> *)contextMenuItems
{
	NSMenuItem *saveItem = [[NSMenuItem alloc] initWithTitle:TXTLS(@"TVCMainWindow[ivw-sd]") action:@selector(saveToDownloads:) keyEquivalent:@""];

	saveItem.target = self;

	return [[super contextMenuItems] arrayByAddingObjectsFromArray:@[[NSMenuItem separatorItem], saveItem]];
}

@end

NS_ASSUME_NONNULL_END
