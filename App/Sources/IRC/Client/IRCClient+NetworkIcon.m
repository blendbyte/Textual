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

#import <ImageIO/ImageIO.h>

#import "TXGlobalModelsPrivate.h"
#import "TXMasterControllerPrivate.h"
#import "TPCPathInfo.h"
#import "IRCClientConfig.h"
#import "IRCISupportInfo.h"
#import "IRCClientPrivate.h"
#import "IRCClientInternal.h"
#import "TVCMainWindowPrivate.h"
#import "ICLURLSessionPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* draft/ICON (https://ircv3.net/specs/extensions/network-icon): the image
 a network names in ISUPPORT is shown in front of its name in the server
 list, unless one was chosen in Server Properties (config.customIcon). It is downloaded through the server's proxy with the inline media
 rules (HTTPS only, no local addresses), drawn at the list's size and kept
 in the caches folder, so it shows before connecting and is downloaded
 again only when the network names a different address. */

#define _networkIconPointSize			16
#define _networkIconPixelSize			(_networkIconPointSize * 2)
#define _networkIconMaximumLength		(1024 * 1024)
#define _networkIconMaximumDimension	4096
#define _customIconPixelSize			64 // also shown larger in Server Properties

@implementation IRCClient (NetworkIcon)

+ (nullable NSURL *)networkIconURLForAddress:(NSString *)address pixelSize:(NSUInteger)pixelSize
{
	NSParameterAssert(address != nil);

	NSString *size = [NSString stringWithFormat:@"%lu", pixelSize];

	NSURL *url = [NSURL URLWithString:[address stringByReplacingOccurrencesOfString:@"{size}" withString:size]];

	if ([url.scheme.lowercaseString isEqualToString:@"https"] == NO || url.host.length == 0) {
		return nil;
	}

	return url;
}

/* The image in a square of pixelSize, as PNG; nil if it isn't one */
+ (nullable NSData *)networkIconDataFromImageData:(NSData *)data pixelSize:(NSUInteger)pixelSize
{
	NSParameterAssert(data != nil);

	/* Refuse a small file that unpacks into a huge picture. SVG isn't
	 read by ImageIO and has no pixel size; NSImage draws it. */
	CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);

	if (source) {
		NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));

		CFRelease(source);

		NSUInteger width = [properties[(__bridge NSString *)kCGImagePropertyPixelWidth] unsignedIntegerValue];
		NSUInteger height = [properties[(__bridge NSString *)kCGImagePropertyPixelHeight] unsignedIntegerValue];

		if (width > _networkIconMaximumDimension || height > _networkIconMaximumDimension) {
			return nil;
		}
	}

	NSImage *image = [[NSImage alloc] initWithData:data];

	NSSize imageSize = image.size;

	if (image.isValid == NO || imageSize.width <= 0 || imageSize.height <= 0) {
		return nil;
	}

	NSBitmapImageRep *bitmap =
	[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
											pixelsWide:pixelSize
											pixelsHigh:pixelSize
										 bitsPerSample:8
									   samplesPerPixel:4
											  hasAlpha:YES
											  isPlanar:NO
										colorSpaceName:NSDeviceRGBColorSpace
										   bytesPerRow:0
										  bitsPerPixel:0];

	NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];

	if (context == nil) {
		return nil;
	}

	/* Fitted into the square, centred */
	CGFloat scale = MIN((pixelSize / imageSize.width), (pixelSize / imageSize.height));

	NSSize drawnSize = NSMakeSize((imageSize.width * scale), (imageSize.height * scale));

	NSRect drawnRect = NSMakeRect(((pixelSize - drawnSize.width) / 2.0), ((pixelSize - drawnSize.height) / 2.0), drawnSize.width, drawnSize.height);

	[NSGraphicsContext saveGraphicsState];

	NSGraphicsContext.currentContext = context;

	context.imageInterpolation = NSImageInterpolationHigh;

	[image drawInRect:drawnRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];

	/* A logo with see-through parts goes on a white tile: on the
	 selection's blue or in Dark Mode a dark logo would disappear */
	if ([self bitmapHasTransparency:bitmap]) {
		[[NSColor whiteColor] setFill];

		NSRectFillUsingOperation(NSMakeRect(0, 0, pixelSize, pixelSize), NSCompositingOperationDestinationOver);
	}

	[NSGraphicsContext restoreGraphicsState];

	return [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
}

+ (BOOL)bitmapHasTransparency:(NSBitmapImageRep *)bitmap
{
	NSParameterAssert(bitmap != nil);

	NSInteger width = bitmap.pixelsWide;
	NSInteger height = bitmap.pixelsHigh;

	NSUInteger samples[4];

	for (NSInteger y = 0; y < height; y++) {
		for (NSInteger x = 0; x < width; x++) {
			[bitmap getPixel:samples atX:x y:y];

			if (samples[3] < 255) {
				return YES;
			}
		}
	}

	return NO;
}

+ (nullable NSData *)customIconDataFromImageData:(NSData *)data
{
	NSParameterAssert(data != nil);

	return [self networkIconDataFromImageData:data pixelSize:_customIconPixelSize];
}

+ (nullable NSImage *)serverListIconWithData:(NSData *)data
{
	NSParameterAssert(data != nil);

	NSImage *icon = [[NSImage alloc] initWithData:data];

	icon.size = NSMakeSize(_networkIconPointSize, _networkIconPointSize);

	return icon;
}

- (nullable NSString *)networkIconFilePath
{
	NSString *caches = [TPCPathInfo applicationCaches];

	if (caches == nil) {
		return nil;
	}

	NSString *folder = [caches stringByAppendingPathComponent:@"Network Icons"];

	return [folder stringByAppendingPathComponent:[self.uniqueIdentifier stringByAppendingPathExtension:@"plist"]];
}

/* The file has the address it came from and the drawn icon */
- (void)loadNetworkIconIfNeeded
{
	if (self.networkIconLoaded) {
		return;
	}

	self.networkIconLoaded = YES;

	NSString *path = [self networkIconFilePath];

	NSDictionary *contents = ((path) ? [NSDictionary dictionaryWithContentsOfFile:path] : nil);

	NSString *address = contents[@"address"];

	NSData *iconData = contents[@"icon"];

	if ([address isKindOfClass:[NSString class]] == NO || [iconData isKindOfClass:[NSData class]] == NO) {
		return;
	}

	NSImage *icon = [IRCClient serverListIconWithData:iconData];

	if (icon == nil) {
		return;
	}

	self.networkIconImage = icon;
	self.networkIconSavedAddress = address;
}

- (nullable NSImage *)networkIcon
{
	NSData *customIcon = self.config.customIcon;

	if ([customIcon isKindOfClass:[NSData class]] == NO) {
		return self.networkProvidedIcon;
	}

	if ([customIcon isEqual:self.customIconSourceData] == NO) {
		self.customIconImage = [IRCClient serverListIconWithData:customIcon];
		self.customIconSourceData = customIcon;
	}

	return ((self.customIconImage) ?: self.networkProvidedIcon);
}

- (nullable NSImage *)networkProvidedIcon
{
	[self loadNetworkIconIfNeeded];

	return self.networkIconImage;
}

- (void)saveNetworkIconData:(NSData *)iconData fromAddress:(NSString *)address
{
	NSParameterAssert(iconData != nil);
	NSParameterAssert(address != nil);

	NSImage *icon = [IRCClient serverListIconWithData:iconData];

	if (icon == nil) {
		return;
	}

	self.networkIconImage = icon;
	self.networkIconSavedAddress = address;

	NSString *path = [self networkIconFilePath];

	if (path) {
		[RZFileManager() createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];

		[@{@"address" : address, @"icon" : iconData} writeToFile:path atomically:YES];
	}

	[mainWindow() reloadTreeItem:self];
}

- (void)removeNetworkIconFile
{
	NSString *path = [self networkIconFilePath];

	if (path) {
		[RZFileManager() removeItemAtPath:path error:NULL];
	}
}

- (void)forgetNetworkIcon
{
	[self loadNetworkIconIfNeeded];

	self.networkIconRequestAddress = nil;

	if (self.networkIconSavedAddress == nil) {
		return;
	}

	self.networkIconImage = nil;
	self.networkIconSavedAddress = nil;

	[self removeNetworkIconFile];

	[mainWindow() reloadTreeItem:self];
}

- (void)updateNetworkIcon
{
	NSString *address = self.supportInfo.networkIconAddress;

	/* No icon named (yet): ISUPPORT can take several lines, so a missing
	 one is only decided at the end of registration */
	if (address == nil) {
		return;
	}

	[self loadNetworkIconIfNeeded];

	if ([address isEqualToString:self.networkIconSavedAddress] ||
		[address isEqualToString:self.networkIconRequestAddress])
	{
		return;
	}

	NSURL *url = [IRCClient networkIconURLForAddress:address pixelSize:_networkIconPixelSize];

	if (url == nil) {
		LogToConsoleDebug("Ignored a network icon that isn't an HTTPS address");

		return;
	}

	self.networkIconRequestAddress = address;

	NSURLSession *session = [ICLURLSession sessionForClient:self];

	__weak IRCClient *weakSelf = self;

	/* A failed download keeps the icon shown and is tried again on the next connect */
	[ICLURLSession requestDataFromURL:url session:session maximumLength:_networkIconMaximumLength completionBlock:^(NSData * _Nullable data) {
		IRCClient *client = weakSelf;

		if (client == nil || [address isEqualToString:client.networkIconRequestAddress] == NO) {
			return;
		}

		if (data == nil) {
			client.networkIconRequestAddress = nil;

			return;
		}

		dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
			NSData *iconData = [IRCClient networkIconDataFromImageData:data pixelSize:_networkIconPixelSize];

			dispatch_async(dispatch_get_main_queue(), ^{
				IRCClient *finishedClient = weakSelf;

				if (finishedClient == nil || [address isEqualToString:finishedClient.networkIconRequestAddress] == NO) {
					return;
				}

				finishedClient.networkIconRequestAddress = nil;

				if (iconData == nil) {
					LogToConsoleDebug("The network icon isn't an image Textual can show");

					return;
				}

				[finishedClient saveNetworkIconData:iconData fromAddress:address];
			});
		});
	}];
}

- (void)finishNetworkIconAfterRegistration
{
	/* The network names no icon (any more) */
	if (self.supportInfo.networkIconAddress == nil) {
		[self forgetNetworkIcon];
	}
}

@end

NS_ASSUME_NONNULL_END
