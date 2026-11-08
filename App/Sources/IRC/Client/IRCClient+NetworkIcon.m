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
#import <objc/runtime.h>

#import "TXGlobalModelsPrivate.h"
#import "TXMasterControllerPrivate.h"
#import "TPCPathInfo.h"
#import "IRCClientConfigPrivate.h"
#import "IRCServer.h"
#import "IRCISupportInfo.h"
#import "IRCAtlasFeedStorePrivate.h"
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
 again only when the network names a different address.

 Until a network names one, IRC Atlas's logo for the server's address is
 shown instead: downloaded and kept the same way, beside it in the file. */

#define _networkIconPointSize			16
#define _networkIconPixelSize			(_networkIconPointSize * 2)
#define _networkIconMaximumLength		(1024 * 1024)
#define _networkIconMaximumDimension	4096
#define _customIconPixelSize			64 // also shown larger in Server Properties

/* Icons in files without this version were stored on a white tile:
 they are downloaded again */
#define _networkIconFileVersion			2

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

	/* NSImage would open a PDF too, which no icon needs */
	NSData *PDFMarker = [@"%PDF" dataUsingEncoding:NSASCIIStringEncoding];

	if ([data rangeOfData:PDFMarker options:0 range:NSMakeRange(0, MIN(data.length, 1024))].location != NSNotFound) {
		return nil;
	}

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

	/* See-through parts stay see-through, so the selection shows behind
	 them; a dark logo gets its tile only where it's drawn on dark
	 (+networkIconNeedsTileOnDark:) */
	[NSGraphicsContext restoreGraphicsState];

	return [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
}

/* A logo with see-through parts whose visible part is dark: on a dark
 row it would disappear without a light tile behind it. Worked out once
 per image. */
+ (BOOL)networkIconNeedsTileOnDark:(NSImage *)icon
{
	NSParameterAssert(icon != nil);

	static char _tileKey;

	NSNumber *cached = objc_getAssociatedObject(icon, &_tileKey);

	if (cached) {
		return cached.boolValue;
	}

	NSInteger side = 16;

	NSBitmapImageRep *bitmap =
	[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
											pixelsWide:side
											pixelsHigh:side
										 bitsPerSample:8
									   samplesPerPixel:4
											  hasAlpha:YES
											  isPlanar:NO
										colorSpaceName:NSDeviceRGBColorSpace
										   bytesPerRow:0
										  bitsPerPixel:0];

	NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];

	BOOL needsTile = NO;

	if (context) {
		[NSGraphicsContext saveGraphicsState];

		NSGraphicsContext.currentContext = context;

		[icon drawInRect:NSMakeRect(0, 0, side, side) fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1.0];

		[NSGraphicsContext restoreGraphicsState];

		BOOL seeThrough = NO;

		double luminance = 0;

		NSUInteger visible = 0;

		NSUInteger samples[4];

		for (NSInteger y = 0; y < side; y++) {
			for (NSInteger x = 0; x < side; x++) {
				[bitmap getPixel:samples atX:x y:y];

				if (samples[3] < 255) {
					seeThrough = YES;
				}

				/* Premultiplied: undone for pixels that are mostly there */
				if (samples[3] >= 128) {
					double alpha = samples[3];

					luminance += (0.2126 * samples[0] + 0.7152 * samples[1] + 0.0722 * samples[2]) / alpha;

					visible += 1;
				}
			}
		}

		needsTile = (seeThrough && visible > 0 && (luminance / visible) < 0.4);
	}

	objc_setAssociatedObject(icon, &_tileKey, @(needsTile), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	return needsTile;
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

/* The icon under these keys of the file, with the address it came from */
+ (nullable NSImage *)iconInFileContents:(nullable NSDictionary *)contents
							  addressKey:(NSString *)addressKey
								 iconKey:(NSString *)iconKey
								 address:(NSString * _Nullable __autoreleasing * _Nonnull)address
								iconData:(NSData * _Nullable __autoreleasing * _Nonnull)iconData
{
	NSString *savedAddress = contents[addressKey];

	NSData *savedIcon = contents[iconKey];

	if ([savedAddress isKindOfClass:[NSString class]] == NO || [savedIcon isKindOfClass:[NSData class]] == NO) {
		return nil;
	}

	NSImage *icon = [IRCClient serverListIconWithData:savedIcon];

	if (icon) {
		*address = savedAddress;
		*iconData = savedIcon;
	}

	return icon;
}

/* The file has, for the network's icon and for IRC Atlas's logo, the
 address it came from and the drawn icon */
- (void)loadNetworkIconIfNeeded
{
	if (self.networkIconLoaded) {
		return;
	}

	self.networkIconLoaded = YES;

	/* Whether IRC Atlas has a logo for the server, after the list is drawn */
	__weak IRCClient *weakSelf = self;

	dispatch_async(dispatch_get_main_queue(), ^{
		[weakSelf updateAtlasLogo];
	});

	NSString *path = [self networkIconFilePath];

	NSDictionary *contents = ((path) ? [NSDictionary dictionaryWithContentsOfFile:path] : nil);

	if ([contents[@"version"] integerValue] < _networkIconFileVersion) {
		contents = nil;
	}

	NSString *address = nil;

	NSData *iconData = nil;

	self.networkIconImage = [IRCClient iconInFileContents:contents addressKey:@"address" iconKey:@"icon" address:&address iconData:&iconData];
	self.networkIconData = iconData;
	self.networkIconSavedAddress = address;

	address = nil;

	iconData = nil;

	self.atlasLogoImage = [IRCClient iconInFileContents:contents addressKey:@"atlasAddress" iconKey:@"atlasIcon" address:&address iconData:&iconData];
	self.atlasLogoData = iconData;
	self.atlasLogoSavedAddress = address;
}

- (void)writeNetworkIconFile
{
	NSString *path = [self networkIconFilePath];

	if (path == nil) {
		return;
	}

	NSMutableDictionary *contents = [NSMutableDictionary dictionary];

	if (self.networkIconSavedAddress && self.networkIconData) {
		contents[@"address"] = self.networkIconSavedAddress;
		contents[@"icon"] = self.networkIconData;
	}

	if (self.atlasLogoSavedAddress && self.atlasLogoData) {
		contents[@"atlasAddress"] = self.atlasLogoSavedAddress;
		contents[@"atlasIcon"] = self.atlasLogoData;
	}

	if (contents.count == 0) {
		[self removeNetworkIconFile];

		return;
	}

	contents[@"version"] = @(_networkIconFileVersion);

	[RZFileManager() createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];

	[contents writeToFile:path atomically:YES];
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

	return ((self.networkIconImage) ?: self.atlasLogoImage);
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
	self.networkIconData = iconData;
	self.networkIconSavedAddress = address;

	[self writeNetworkIconFile];

	[mainWindow() reloadTreeItem:self];
}

- (void)saveAtlasLogoData:(NSData *)iconData fromAddress:(NSString *)address
{
	NSParameterAssert(iconData != nil);
	NSParameterAssert(address != nil);

	NSImage *icon = [IRCClient serverListIconWithData:iconData];

	if (icon == nil) {
		return;
	}

	self.atlasLogoImage = icon;
	self.atlasLogoData = iconData;
	self.atlasLogoSavedAddress = address;

	[self writeNetworkIconFile];

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
	self.networkIconData = nil;
	self.networkIconSavedAddress = nil;

	[self writeNetworkIconFile];

	[mainWindow() reloadTreeItem:self];

	/* IRC Atlas's logo, if there is one, takes its place */
	[self updateAtlasLogo];
}

/* Downloads through the server's proxy, then draws the image at the list's
 size; the block gets nil for a failed download or something not an image */
- (void)downloadIconFromURL:(NSURL *)url completionBlock:(void (^)(NSData * _Nullable iconData))completionBlock
{
	NSParameterAssert(url != nil);
	NSParameterAssert(completionBlock != nil);

	NSURLSession *session = [ICLURLSession sessionForClient:self];

	[ICLURLSession requestDataFromURL:url session:session maximumLength:_networkIconMaximumLength completionBlock:^(NSData * _Nullable data) {
		if (data == nil) {
			dispatch_async(dispatch_get_main_queue(), ^{
				completionBlock(nil);
			});

			return;
		}

		dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
			NSData *iconData = [IRCClient networkIconDataFromImageData:data pixelSize:_networkIconPixelSize];

			if (iconData == nil) {
				LogToConsoleDebug("The network icon isn't an image Textual can show");
			}

			dispatch_async(dispatch_get_main_queue(), ^{
				completionBlock(iconData);
			});
		});
	}];
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

	/* The address comes from the network behind the bouncer, and fetching
	 it would show that network where this Mac really is */
	if (self.config.bouncerAccountIdentifier != nil || self.isConnectedToZNC ||
		[self isCapabilityEnabled:ClientIRCv3SupportedCapabilityBouncerNetworks])
	{
		return;
	}

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

	__weak IRCClient *weakSelf = self;

	/* A failed download keeps the icon shown and is tried again on the next connect */
	[self downloadIconFromURL:url completionBlock:^(NSData * _Nullable iconData) {
		IRCClient *client = weakSelf;

		if (client == nil || [address isEqualToString:client.networkIconRequestAddress] == NO) {
			return;
		}

		client.networkIconRequestAddress = nil;

		if (iconData) {
			[client saveNetworkIconData:iconData fromAddress:address];
		}
	}];
}

- (void)finishNetworkIconAfterRegistration
{
	/* The network names no icon (any more) */
	if (self.supportInfo.networkIconAddress == nil) {
		[self forgetNetworkIcon];
	}
}

/* IRC Atlas's logo for the network at the server's address. Not downloaded
 while the network's own icon is shown, and again only when the feed names
 a different address; a failed download is tried again on the next launch. */
- (void)updateAtlasLogo
{
	if (self.isTerminating) {
		return;
	}

	[self loadNetworkIconIfNeeded];

	/* Behind a bouncer the address is the bouncer's, the same for each network */
	NSString *serverAddress = ((self.config.bouncerAccountIdentifier == nil) ? self.config.serverList.firstObject.serverAddress : nil);

	NSString *address = ((serverAddress) ? [IRCAtlasFeedStore logoAddressWithServerAddress:serverAddress] : nil);

	/* Another network, or IRC Atlas has no logo for it (any more) */
	if (address == nil) {
		self.atlasLogoRequestAddress = nil;

		if (self.atlasLogoSavedAddress == nil) {
			return;
		}

		self.atlasLogoImage = nil;
		self.atlasLogoData = nil;
		self.atlasLogoSavedAddress = nil;

		[self writeNetworkIconFile];

		[mainWindow() reloadTreeItem:self];

		return;
	}

	if (self.networkIconSavedAddress != nil) {
		return;
	}

	if ([address isEqualToString:self.atlasLogoSavedAddress] ||
		[address isEqualToString:self.atlasLogoRequestAddress])
	{
		return;
	}

	NSURL *url = [NSURL URLWithString:address];

	if (url == nil) {
		return;
	}

	self.atlasLogoRequestAddress = address;

	__weak IRCClient *weakSelf = self;

	[self downloadIconFromURL:url completionBlock:^(NSData * _Nullable iconData) {
		IRCClient *client = weakSelf;

		if (client == nil || [address isEqualToString:client.atlasLogoRequestAddress] == NO) {
			return;
		}

		client.atlasLogoRequestAddress = nil;

		if (iconData) {
			[client saveAtlasLogoData:iconData fromAddress:address];
		}
	}];
}

@end

NS_ASSUME_NONNULL_END
