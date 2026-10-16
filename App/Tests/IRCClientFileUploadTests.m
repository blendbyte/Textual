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
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "IRCISupportInfoPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientFileUploadTests : XCTestCase
@end

@implementation IRCClientFileUploadTests

/* draft/FILEHOST and soju.im/FILEHOST name the address; only http(s), and
 plain http only without TLS (this client isn't connected, so no TLS) */
- (void)testUploadAddress
{
	IRCClient *client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	XCTAssertNil(client.fileUploadAddress);

	[client.supportInfo processConfigurationData:@"me draft/FILEHOST=https://files.example.org/upload :are supported by this server"];

	XCTAssertEqualObjects(client.fileUploadAddress.absoluteString, @"https://files.example.org/upload");

	[client.supportInfo processConfigurationData:@"me -draft/FILEHOST :are supported by this server"];

	XCTAssertNil(client.fileUploadAddress);

	[client.supportInfo processConfigurationData:@"me soju.im/FILEHOST=http://127.0.0.1:8080/uploads :are supported by this server"];

	XCTAssertEqualObjects(client.fileUploadAddress.absoluteString, @"http://127.0.0.1:8080/uploads");

	[client.supportInfo processConfigurationData:@"me draft/FILEHOST=ftp://files.example.org/ :are supported by this server"];

	XCTAssertNil(client.fileUploadAddress);
}

/* The login goes only to the server's own domain */
- (void)testLoginOnlyToTheServersDomain
{
	XCTAssertTrue([IRCClient uploadHost:@"irc.example.org" sharesDomainWithHost:@"irc.example.org"]);
	XCTAssertTrue([IRCClient uploadHost:@"files.example.org" sharesDomainWithHost:@"irc.example.org"]);
	XCTAssertTrue([IRCClient uploadHost:@"Example.org." sharesDomainWithHost:@"irc.example.org"]);
	XCTAssertTrue([IRCClient uploadHost:@"up.example.org" sharesDomainWithHost:@"example.org"]);

	XCTAssertFalse([IRCClient uploadHost:@"evil-example.org" sharesDomainWithHost:@"irc.example.org"]);
	XCTAssertFalse([IRCClient uploadHost:@"example.org.evil.net" sharesDomainWithHost:@"irc.example.org"]);
	XCTAssertFalse([IRCClient uploadHost:@"files.other.org" sharesDomainWithHost:@"irc.example.org"]);
	XCTAssertFalse([IRCClient uploadHost:@"192.0.2.2" sharesDomainWithHost:@"192.0.2.1"]);
	XCTAssertTrue([IRCClient uploadHost:@"192.0.2.1" sharesDomainWithHost:@"192.0.2.1"]);

	NSURL *own = [NSURL URLWithString:@"https://files.example.org/upload"];

	XCTAssertEqualObjects([IRCClient fileUploadAuthorizationForAddress:own serverHost:@"irc.example.org" mechanism:@"PLAIN" username:@"alice" password:@"secret"],
						  @"Basic YWxpY2U6c2VjcmV0");
	XCTAssertNotNil([IRCClient fileUploadAuthorizationForAddress:own serverHost:@"irc.example.org" mechanism:@"SCRAM-SHA-256" username:@"alice" password:@"secret"]);

	/* Not over plain HTTP, not elsewhere, not for EXTERNAL or without a password */
	XCTAssertNil([IRCClient fileUploadAuthorizationForAddress:[NSURL URLWithString:@"http://files.example.org/upload"] serverHost:@"irc.example.org" mechanism:@"PLAIN" username:@"alice" password:@"secret"]);
	XCTAssertNil([IRCClient fileUploadAuthorizationForAddress:[NSURL URLWithString:@"https://uploads.other.net/"] serverHost:@"irc.example.org" mechanism:@"PLAIN" username:@"alice" password:@"secret"]);
	XCTAssertNil([IRCClient fileUploadAuthorizationForAddress:own serverHost:@"irc.example.org" mechanism:@"EXTERNAL" username:@"alice" password:@"secret"]);
	XCTAssertNil([IRCClient fileUploadAuthorizationForAddress:own serverHost:@"irc.example.org" mechanism:@"PLAIN" username:@"alice" password:nil]);
}

/* The name as headers carry it, and the link from a relative Location */
- (void)testRequestAndAnswer
{
	XCTAssertEqualObjects([IRCFileUpload contentDispositionForFileName:@"photo.jpg"], @"inline; filename=\"photo.jpg\"");
	XCTAssertEqualObjects([IRCFileUpload contentDispositionForFileName:@"Grüße \"x\".png"],
						  @"inline; filename=\"Gr__e _x_.png\"; filename*=UTF-8''Gr%C3%BC%C3%9Fe%20%22x%22.png");

	NSURL *address = [NSURL URLWithString:@"https://files.example.org/upload"];

	XCTAssertEqualObjects([IRCFileUpload linkFromLocation:@"/upload/abc.png" relativeToAddress:address].absoluteString, @"https://files.example.org/upload/abc.png");
	XCTAssertEqualObjects([IRCFileUpload linkFromLocation:@"https://cdn.example.net/abc.png" relativeToAddress:address].absoluteString, @"https://cdn.example.net/abc.png");
	XCTAssertNil([IRCFileUpload linkFromLocation:@"javascript:alert(1)" relativeToAddress:address]);
	XCTAssertNil([IRCFileUpload linkFromLocation:nil relativeToAddress:address]);
}

/* A photo's location and camera go; its orientation stays */
- (void)testPictureMetadataRemoved
{
	NSURL *folder = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:[NSUUID UUID].UUIDString isDirectory:YES];

	XCTAssertTrue([[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:NULL]);

	NSURL *photoURL = [folder URLByAppendingPathComponent:@"photo.jpg"];

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL, 8, 4, 8, 0, colorSpace, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
	CGContextSetRGBFillColor(context, 1, 0, 0, 1);
	CGContextFillRect(context, CGRectMake(0, 0, 8, 4));
	CGImageRef image = CGBitmapContextCreateImage(context);

	CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)photoURL, (__bridge CFStringRef)UTTypeJPEG.identifier, 1, NULL);

	NSDictionary *properties = @{
		(__bridge NSString *)kCGImagePropertyOrientation : @(6),
		(__bridge NSString *)kCGImagePropertyGPSDictionary : @{(__bridge NSString *)kCGImagePropertyGPSLatitude : @(52.52), (__bridge NSString *)kCGImagePropertyGPSLatitudeRef : @"N"},
		(__bridge NSString *)kCGImagePropertyTIFFDictionary : @{(__bridge NSString *)kCGImagePropertyTIFFMake : @"Apple", (__bridge NSString *)kCGImagePropertyTIFFModel : @"iPhone"},
		(__bridge NSString *)kCGImagePropertyExifDictionary : @{(__bridge NSString *)kCGImagePropertyExifDateTimeOriginal : @"2026:10:16 12:00:00"}
	};

	CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)properties);

	XCTAssertTrue(CGImageDestinationFinalize(destination));

	CFRelease(destination);
	CGImageRelease(image);
	CGContextRelease(context);
	CGColorSpaceRelease(colorSpace);

	XCTAssertTrue([IRCFileUpload imageHasMetadataAtURL:photoURL]);

	NSURL *cleanFolder = [folder URLByAppendingPathComponent:@"clean" isDirectory:YES];

	XCTAssertTrue([[NSFileManager defaultManager] createDirectoryAtURL:cleanFolder withIntermediateDirectories:YES attributes:nil error:NULL]);

	NSURL *cleanURL = [IRCFileUpload copyOfImageWithoutMetadataAtURL:photoURL inFolder:cleanFolder];

	XCTAssertNotNil(cleanURL);
	XCTAssertFalse([IRCFileUpload imageHasMetadataAtURL:cleanURL]);

	CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)cleanURL, NULL);

	NSDictionary *cleanProperties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));

	CFRelease(source);

	XCTAssertEqualObjects(cleanProperties[(__bridge NSString *)kCGImagePropertyOrientation], @(6));
	XCTAssertNil(cleanProperties[(__bridge NSString *)kCGImagePropertyGPSDictionary]);

	/* Not a picture: nothing to copy */
	NSURL *textURL = [folder URLByAppendingPathComponent:@"notes.txt"];

	[@"hello" writeToURL:textURL atomically:YES encoding:NSUTF8StringEncoding error:NULL];

	XCTAssertNil([IRCFileUpload copyOfImageWithoutMetadataAtURL:textURL inFolder:cleanFolder]);

	[[NSFileManager defaultManager] removeItemAtURL:folder error:NULL];
}

@end

NS_ASSUME_NONNULL_END
