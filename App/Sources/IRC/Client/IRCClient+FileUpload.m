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
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "NSStringHelper.h"
#import "TLOKeychainPrivate.h"
#import "TLOLocalization.h"
#import "TLOUploadDestinationPrivate.h"
#import "TPCPreferencesUserDefaultsLocal.h"
#import "IRCClientConfig.h"
#import "IRCConnectionPrivate.h"
#import "IRCConnectionProxyPrivate.h"
#import "IRCISupportInfo.h"
#import "IRCClientPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

/* File uploads (https://github.com/ircv3/ircv3-specifications/pull/562): the
 network names an address (draft/FILEHOST, or soju's soju.im/FILEHOST); a
 file is POSTed there and the 201's Location is its link. The SASL login goes
 along (Basic for a password, the certificate for EXTERNAL) only to an HTTPS
 address on the server's own domain. Pictures lose their metadata (location,
 camera) first. The upload goes through the connection's proxy. */

#define _uploadRequestTimeout		60
#define _uploadResourceTimeout		(30 * 60)

@interface IRCFileUpload () <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
@property (nonatomic, copy, readwrite) NSString *filePath;
@property (nonatomic, copy, readwrite) NSString *fileName;
@property (nonatomic, copy, readwrite) NSURL *address;
@property (nonatomic, assign, readwrite) double progress;
@property (nonatomic, copy, readwrite, nullable) NSURL *link;
@property (nonatomic, copy, readwrite, nullable) NSString *failureReason;
@property (nonatomic, copy, nullable) NSString *authorization;
@property (nonatomic, copy, nullable) NSData *clientCertificateReference;
@property (nonatomic, copy, nullable) TLOUploadDestination *destination; // the user's own; nil: the network's
@property (nonatomic, copy) NSURLSessionConfiguration *sessionConfiguration;
@property (nonatomic, strong, nullable) NSURLSession *session;
@property (nonatomic, strong, nullable) NSURLSessionUploadTask *task;
@property (nonatomic, copy, nullable) NSURL *temporaryFolder;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, copy, nullable) void (^completionBlock)(IRCFileUpload *upload);
@property (nonatomic, assign) BOOL cancelled;
@end

@implementation IRCFileUpload

- (instancetype)initWithPath:(NSString *)path address:(NSURL *)address
{
	NSParameterAssert(path != nil);
	NSParameterAssert(address != nil);

	if ((self = [super init])) {
		self.filePath = path;
		self.fileName = path.lastPathComponent;
		self.address = address;

		self.responseData = [NSMutableData data];

		NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];

		configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
		configuration.URLCache = nil;
		configuration.HTTPShouldSetCookies = NO;
		configuration.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
		configuration.HTTPCookieStorage = nil;
		configuration.URLCredentialStorage = nil;
		configuration.timeoutIntervalForRequest = _uploadRequestTimeout;
		configuration.timeoutIntervalForResource = _uploadResourceTimeout;

		self.sessionConfiguration = configuration;

		return self;
	}

	return nil;
}

#pragma mark -
#pragma mark Request

/* inline; filename="…" with only ASCII, and filename* for the real name */
+ (NSString *)contentDispositionForFileName:(NSString *)fileName
{
	NSParameterAssert(fileName != nil);

	NSMutableString *asciiName = [NSMutableString stringWithCapacity:fileName.length];

	BOOL isASCII = YES;

	for (NSUInteger i = 0; i < fileName.length; i++) {
		unichar character = [fileName characterAtIndex:i];

		if (character < 0x20 || character > 0x7e || character == '"' || character == '\\') {
			[asciiName appendString:@"_"];

			isASCII = NO;
		} else {
			[asciiName appendFormat:@"%C", character];
		}
	}

	if (isASCII) {
		return [NSString stringWithFormat:@"inline; filename=\"%@\"", asciiName];
	}

	/* RFC 8187: ASCII letters, digits and a few marks as they are, the rest as UTF-8 bytes */
	NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$&+-.^_`|~"];

	NSString *strictName = [fileName stringByAddingPercentEncodingWithAllowedCharacters:allowed];

	if (strictName == nil) {
		return [NSString stringWithFormat:@"inline; filename=\"%@\"", asciiName];
	}

	return [NSString stringWithFormat:@"inline; filename=\"%@\"; filename*=UTF-8''%@", asciiName, strictName];
}

+ (NSString *)contentTypeForPath:(NSString *)path
{
	NSParameterAssert(path != nil);

	UTType *type = [UTType typeWithFilenameExtension:path.pathExtension];

	NSString *mimeType = type.preferredMIMEType;

	return (mimeType ?: @"application/octet-stream");
}

/* The link a 201 names: absolute, or relative to the upload address; http(s) only */
+ (nullable NSURL *)linkFromLocation:(nullable NSString *)location relativeToAddress:(NSURL *)address
{
	NSParameterAssert(address != nil);

	if (location.length == 0) {
		return nil;
	}

	NSURL *link = [NSURL URLWithString:location relativeToURL:address].absoluteURL;

	NSString *scheme = link.scheme.lowercaseString;

	if (link.host.length == 0 || ([scheme isEqualToString:@"https"] == NO && [scheme isEqualToString:@"http"] == NO)) {
		return nil;
	}

	return link;
}

#pragma mark -
#pragma mark Metadata

/* A copy of a picture without its metadata (location, camera, dates), in
 folder; the orientation stays. nil when it isn't a picture ImageIO reads. */
+ (nullable NSURL *)copyOfImageWithoutMetadataAtURL:(NSURL *)url inFolder:(NSURL *)folder
{
	NSParameterAssert(url != nil);
	NSParameterAssert(folder != nil);

	CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);

	if (source == NULL) {
		return nil;
	}

	CFStringRef type = CGImageSourceGetType(source);

	size_t count = CGImageSourceGetCount(source);

	if (type == NULL || count == 0) {
		CFRelease(source);

		return nil;
	}

	NSURL *destinationURL = [folder URLByAppendingPathComponent:url.lastPathComponent];

	NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));

	NSNumber *orientation = properties[(__bridge NSString *)kCGImagePropertyOrientation];

	BOOL written = NO;

	/* Without decoding first (JPEG, PNG, TIFF): the pixels stay as they are */
	if (count == 1) {
		CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)destinationURL, type, 1, NULL);

		if (destination) {
			CGMutableImageMetadataRef emptyMetadata = CGImageMetadataCreateMutable();

			NSMutableDictionary *options = [NSMutableDictionary dictionary];

			options[(__bridge NSString *)kCGImageDestinationMetadata] = (__bridge id)emptyMetadata;
			options[(__bridge NSString *)kCGImageDestinationMergeMetadata] = @(NO);
			options[(__bridge NSString *)kCGImageMetadataShouldExcludeGPS] = @(YES);
			options[(__bridge NSString *)kCGImageMetadataShouldExcludeXMP] = @(YES);

			if (orientation) {
				options[(__bridge NSString *)kCGImageDestinationOrientation] = orientation;
			}

			written = CGImageDestinationCopyImageSource(destination, source, (__bridge CFDictionaryRef)options, NULL);

			CFRelease(emptyMetadata);
			CFRelease(destination);
		}
	}

	/* Otherwise each frame again, with the metadata dictionaries left out */
	if (written == NO || [self imageHasMetadataAtURL:destinationURL]) {
		CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)destinationURL, type, count, NULL);

		if (destination == NULL) {
			CFRelease(source);

			return nil;
		}

		NSArray *removedKeys = @[
			(__bridge NSString *)kCGImagePropertyExifDictionary,
			(__bridge NSString *)kCGImagePropertyExifAuxDictionary,
			(__bridge NSString *)kCGImagePropertyGPSDictionary,
			(__bridge NSString *)kCGImagePropertyIPTCDictionary,
			(__bridge NSString *)kCGImagePropertyTIFFDictionary,
			(__bridge NSString *)kCGImagePropertyMakerAppleDictionary,
			(__bridge NSString *)kCGImagePropertyMakerCanonDictionary,
			(__bridge NSString *)kCGImagePropertyMakerNikonDictionary,
			(__bridge NSString *)kCGImagePropertyDNGDictionary
		];

		for (size_t i = 0; i < count; i++) {
			NSDictionary *frameProperties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, i, NULL));

			NSMutableDictionary *keptProperties = [NSMutableDictionary dictionary];

			for (NSString *key in removedKeys) {
				keptProperties[key] = (id)kCFNull;
			}

			/* Animation timing and orientation stay */
			for (NSString *key in @[(__bridge NSString *)kCGImagePropertyGIFDictionary, (__bridge NSString *)kCGImagePropertyPNGDictionary, (__bridge NSString *)kCGImagePropertyOrientation]) {
				if (frameProperties[key]) {
					keptProperties[key] = frameProperties[key];
				}
			}

			CGImageDestinationAddImageFromSource(destination, source, i, (__bridge CFDictionaryRef)keptProperties);
		}

		written = CGImageDestinationFinalize(destination);

		CFRelease(destination);
	}

	CFRelease(source);

	if (written == NO || [self imageHasMetadataAtURL:destinationURL]) {
		[RZFileManager() removeItemAtURL:destinationURL error:NULL];

		return nil;
	}

	return destinationURL;
}

/* Location, camera or capture details still in the picture */
+ (BOOL)imageHasMetadataAtURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);

	if (source == NULL) {
		return NO;
	}

	BOOL hasMetadata = NO;

	size_t count = CGImageSourceGetCount(source);

	for (size_t i = 0; i < count && hasMetadata == NO; i++) {
		NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, i, NULL));

		NSDictionary *exif = properties[(__bridge NSString *)kCGImagePropertyExifDictionary];
		NSDictionary *tiff = properties[(__bridge NSString *)kCGImagePropertyTIFFDictionary];

		hasMetadata = (properties[(__bridge NSString *)kCGImagePropertyGPSDictionary] != nil ||
					   properties[(__bridge NSString *)kCGImagePropertyMakerAppleDictionary] != nil ||
					   exif[(__bridge NSString *)kCGImagePropertyExifDateTimeOriginal] != nil ||
					   exif[(__bridge NSString *)kCGImagePropertyExifLensModel] != nil ||
					   tiff[(__bridge NSString *)kCGImagePropertyTIFFModel] != nil ||
					   tiff[(__bridge NSString *)kCGImagePropertyTIFFMake] != nil);
	}

	CFRelease(source);

	return hasMetadata;
}

#pragma mark -
#pragma mark Uploading

- (void)startWithCompletionBlock:(void (^)(IRCFileUpload *upload))completionBlock
{
	NSParameterAssert(completionBlock != nil);

	self.completionBlock = completionBlock;

	NSString *path = self.filePath;

	/* Pictures lose their metadata first, off the main thread */
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSURL *folder = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:[NSString stringWithFormat:@"Textual Uploads/%@", [NSUUID UUID].UUIDString] isDirectory:YES];

		NSURL *uploadedURL = [NSURL fileURLWithPath:path];

		BOOL isPicture = [[UTType typeWithFilenameExtension:path.pathExtension] conformsToType:UTTypeImage];

		BOOL haveFolder = [RZFileManager() createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:NULL];

		if (isPicture && haveFolder) {
			NSURL *copyURL = [self.class copyOfImageWithoutMetadataAtURL:uploadedURL inFolder:folder];

			if (copyURL) {
				uploadedURL = copyURL;
			} else if ([self.class imageHasMetadataAtURL:uploadedURL]) {
				/* Never with its location: not at all */
				dispatch_async(dispatch_get_main_queue(), ^{
					[RZFileManager() removeItemAtURL:folder error:NULL];

					[self finishWithFailureReason:TXTLS(@"IRC[upl-e6]")];
				});

				return;
			}
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			self.temporaryFolder = folder;

			if (self.cancelled) {
				[self finishWithFailureReason:nil];

				return;
			}

			[self uploadFileAtURL:uploadedURL];
		});
	});
}

- (void)uploadFileAtURL:(NSURL *)fileURL
{
	NSParameterAssert(fileURL != nil);

	NSMutableURLRequest *request = nil;

	NSURL *bodyURL = fileURL;

	if (self.destination) {
		/* The user's own: as its uploader says (a form is written to the folder) */
		NSURL *formBodyURL = nil;

		request = [self.destination requestForFileAtURL:fileURL
											   fileName:self.fileName
											contentType:[self.class contentTypeForPath:self.fileName]
										temporaryFolder:self.temporaryFolder
											bodyFileURL:&formBodyURL];

		if (request == nil || formBodyURL == nil) {
			[self finishWithFailureReason:TXTLS(@"IRC[upl-e7]")];

			return;
		}

		bodyURL = formBodyURL;
	} else {
		request = [NSMutableURLRequest requestWithURL:self.address];

		request.HTTPMethod = @"POST";

		[request setValue:[self.class contentTypeForPath:self.fileName] forHTTPHeaderField:@"Content-Type"];
		[request setValue:[self.class contentDispositionForFileName:self.fileName] forHTTPHeaderField:@"Content-Disposition"];

		if (self.authorization) {
			[request setValue:self.authorization forHTTPHeaderField:@"Authorization"];
		}
	}

	self.session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration delegate:self delegateQueue:[NSOperationQueue mainQueue]];

	self.task = [self.session uploadTaskWithRequest:request fromFile:bodyURL];

	[self.task resume];
}

- (void)cancel
{
	self.cancelled = YES;

	[self.task cancel];
}

- (void)finishWithFailureReason:(nullable NSString *)failureReason
{
	self.failureReason = failureReason;

	[self.session finishTasksAndInvalidate];

	self.session = nil;
	self.task = nil;

	if (self.temporaryFolder) {
		[RZFileManager() removeItemAtURL:self.temporaryFolder error:NULL];

		self.temporaryFolder = nil;
	}

	void (^completionBlock)(IRCFileUpload *) = self.completionBlock;

	self.completionBlock = nil;

	if (completionBlock) {
		completionBlock(self);
	}
}

/* Why it failed, from the server's answer */
+ (NSString *)failureReasonForStatusCode:(NSInteger)statusCode
{
	switch (statusCode) {
		case 401:
		case 403:
		{
			return TXTLS(@"IRC[upl-e1]");
		}
		case 413:
		{
			return TXTLS(@"IRC[upl-e2]");
		}
		case 415:
		{
			return TXTLS(@"IRC[upl-e3]");
		}
		default:
		{
			return TXTLS(@"IRC[upl-e4]", (long)statusCode, [NSHTTPURLResponse localizedStringForStatusCode:statusCode]);
		}
	}
}

#pragma mark -
#pragma mark Session Delegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
	if (totalBytesExpectedToSend <= 0) {
		return;
	}

	self.progress = ((double)totalBytesSent / (double)totalBytesExpectedToSend);

	if (self.progressBlock) {
		self.progressBlock(self);
	}
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
	/* The network's: only the headers matter (a little of the body for logs);
	 the user's own may put the link in the body */
	if (self.responseData.length < ((self.destination) ? (1024 * 1024) : 4096)) {
		[self.responseData appendData:data];
	}
}

/* Never elsewhere with the login: no redirects */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler
{
	completionHandler(nil);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
	NSString *method = challenge.protectionSpace.authenticationMethod;

	/* SASL EXTERNAL: the connection's certificate */
	if ([method isEqualToString:NSURLAuthenticationMethodClientCertificate] && self.clientCertificateReference) {
		SecIdentityRef identity = [TLOKeychain copyClientCertificateIdentityForReference:self.clientCertificateReference];

		if (identity) {
			NSURLCredential *credential = [NSURLCredential credentialWithIdentity:identity certificates:nil persistence:NSURLCredentialPersistenceNone];

			CFRelease(identity);

			completionHandler(NSURLSessionAuthChallengeUseCredential, credential);

			return;
		}
	}

	completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
	if (self.cancelled) {
		[self finishWithFailureReason:nil];

		return;
	}

	if (error) {
		[self finishWithFailureReason:error.localizedDescription];

		return;
	}

	NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;

	if ([response isKindOfClass:[NSHTTPURLResponse class]] == NO) {
		[self finishWithFailureReason:TXTLS(@"IRC[upl-e5]")];

		return;
	}

	BOOL succeeded = ((self.destination) ? (response.statusCode >= 200 && response.statusCode < 300) : (response.statusCode == 201));

	if (succeeded == NO) {
		LogToConsoleError("Upload refused (%ld): %{public}@", (long)response.statusCode,
			[[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding]);

		NSString *serverReason = [self.destination errorFromResponse:response data:self.responseData];

		[self finishWithFailureReason:(serverReason ?: [self.class failureReasonForStatusCode:response.statusCode])];

		return;
	}

	NSURL *link = nil;

	if (self.destination) {
		link = [self.destination linkFromResponse:response data:self.responseData];
	} else {
		link = [self.class linkFromLocation:[response valueForHTTPHeaderField:@"Location"] relativeToAddress:self.address];
	}

	if (link == nil) {
		[self finishWithFailureReason:TXTLS(@"IRC[upl-e5]")];

		return;
	}

	self.link = link;

	[self finishWithFailureReason:nil];
}

@end

#pragma mark -

@implementation IRCClient (FileUpload)

/* The network's upload address, if this connection may use it: HTTPS, or
 plain HTTP only on a connection without TLS */
- (nullable NSURL *)fileUploadAddress
{
	NSString *addressString = self.supportInfo.fileHostAddress;

	if (addressString.length == 0) {
		return nil;
	}

	NSURL *address = [NSURL URLWithString:addressString];

	NSString *scheme = address.scheme.lowercaseString;

	if (address.host.length == 0) {
		return nil;
	}

	if ([scheme isEqualToString:@"https"]) {
		return address;
	}

	if ([scheme isEqualToString:@"http"] && self.isSecured == NO) {
		return address;
	}

	return nil;
}

+ (BOOL)uploadHost:(NSString *)uploadHost sharesDomainWithHost:(NSString *)serverHost
{
	NSParameterAssert(uploadHost != nil);
	NSParameterAssert(serverHost != nil);

	NSString * (^normalized)(NSString *) = ^NSString *(NSString *host) {
		host = host.lowercaseString;

		if ([host hasSuffix:@"."]) {
			host = [host substringToIndex:(host.length - 1)];
		}

		return host;
	};

	uploadHost = normalized(uploadHost);
	serverHost = normalized(serverHost);

	if (uploadHost.length == 0 || serverHost.length == 0) {
		return NO;
	}

	if ([uploadHost isEqualToString:serverHost]) {
		return YES;
	}

	/* An address, not a name: only itself */
	if (serverHost.isIPAddress || uploadHost.isIPAddress) {
		return NO;
	}

	/* irc.example.org → example.org: example.org and *.example.org */
	NSArray *labels = [serverHost componentsSeparatedByString:@"."];

	NSString *domain = serverHost;

	if (labels.count >= 3) {
		domain = [[labels subarrayWithRange:NSMakeRange(1, (labels.count - 1))] componentsJoinedByString:@"."];
	}

	return ([uploadHost isEqualToString:domain] || [uploadHost hasSuffix:[@"." stringByAppendingString:domain]]);
}

/* The login goes along only over HTTPS to the server's own domain: Basic
 for a password mechanism (PLAIN, SCRAM), nothing for EXTERNAL (its
 certificate is offered instead) or anything else */
+ (nullable NSString *)fileUploadAuthorizationForAddress:(NSURL *)address
											  serverHost:(nullable NSString *)serverHost
											   mechanism:(nullable NSString *)mechanism
												username:(nullable NSString *)username
												password:(nullable NSString *)password
{
	NSParameterAssert(address != nil);

	if ([self fileUploadMayAuthenticateWithAddress:address serverHost:serverHost] == NO) {
		return nil;
	}

	mechanism = mechanism.uppercaseString;

	if (([mechanism isEqualToString:@"PLAIN"] || [mechanism hasPrefix:@"SCRAM-"]) == NO || username.length == 0 || password.length == 0) {
		return nil;
	}

	NSString *login = [NSString stringWithFormat:@"%@:%@", username, password];

	return [@"Basic " stringByAppendingString:[[login dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]];
}

+ (BOOL)fileUploadMayAuthenticateWithAddress:(NSURL *)address serverHost:(nullable NSString *)serverHost
{
	NSParameterAssert(address != nil);

	if ([address.scheme.lowercaseString isEqualToString:@"https"] == NO || serverHost == nil || address.host == nil) {
		return NO;
	}

	return [self uploadHost:address.host sharesDomainWithHost:serverHost];
}

/* Where the network offers none: the server's choice (9.18 B) */
- (BOOL)customUploadDestinationConfigured
{
	IRCClientConfig *config = self.config;

	switch (config.uploadDestinationMode) {
		case IRCClientUploadDestinationModeOff:
		{
			return NO;
		}
		case IRCClientUploadDestinationModeOwn:
		{
			return (config.uploadDestination != nil);
		}
		default:
		{
			return ([RZUserDefaults() dictionaryForKey:@"Uploads -> Destination"] != nil);
		}
	}
}

- (nullable TLOUploadDestination *)customUploadDestination
{
	IRCClientConfig *config = self.config;

	switch (config.uploadDestinationMode) {
		case IRCClientUploadDestinationModeOff:
		{
			return nil;
		}
		case IRCClientUploadDestinationModeOwn:
		{
			NSDictionary *propertyList = config.uploadDestination;

			return ((propertyList) ? [TLOUploadDestination destinationWithPropertyList:propertyList secretsIdentifier:config.uniqueIdentifier] : nil);
		}
		default:
		{
			return [TLOUploadDestination globalDestination];
		}
	}
}

- (BOOL)fileUploadsAvailable
{
	return (self.fileUploadAddress != nil || self.customUploadDestinationConfigured);
}

- (nullable NSString *)fileUploadDestinationDescription
{
	NSURL *address = self.fileUploadAddress;

	if (address) {
		return TXTLS(@"IRC[upl-d1]", address.host);
	}

	if (self.customUploadDestinationConfigured == NO) {
		return nil;
	}

	TLOUploadDestination *destination = self.customUploadDestination;

	if (destination == nil) {
		return nil;
	}

	return TXTLS(@"IRC[upl-d2]", destination.name);
}

- (nullable IRCFileUpload *)fileUploadForPath:(NSString *)path
{
	NSParameterAssert(path != nil);

	NSURL *address = self.fileUploadAddress;

	if (address == nil) {
		/* The user's own: no IRC login goes along */
		TLOUploadDestination *destination = self.customUploadDestination;

		if (destination == nil) {
			return nil;
		}

		return [self fileUploadForPath:path destination:destination];
	}

	IRCFileUpload *upload = [[IRCFileUpload alloc] initWithPath:path address:address];

	[IRCConnectionProxy applyClientConfig:self.config toSessionConfiguration:upload.sessionConfiguration];

	/* Signed in with SASL: the same login, where it may go */
	if (self.isAuthenticatedWithSASL) {
		NSString *serverHost = self.socket.config.serverAddress;

		NSString *mechanism = self.saslMechanism;

		upload.authorization = [self.class fileUploadAuthorizationForAddress:address
																   serverHost:serverHost
																	mechanism:mechanism
																	 username:self.saslUsername
																	 password:self.config.nicknamePassword];

		if ([mechanism isEqualToStringIgnoringCase:@"EXTERNAL"] && [self.class fileUploadMayAuthenticateWithAddress:address serverHost:serverHost]) {
			upload.clientCertificateReference = self.config.identityClientSideCertificate;
		}
	}

	return upload;
}

/* An uploader's address (the user's own, or the paste service): no IRC login goes along */
- (nullable IRCFileUpload *)fileUploadForPath:(NSString *)path destination:(TLOUploadDestination *)destination
{
	NSParameterAssert(path != nil);
	NSParameterAssert(destination != nil);

	NSURL *requestAddress = [NSURL URLWithString:destination.requestAddress];

	if (destination.problem || requestAddress == nil) {
		return nil;
	}

	IRCFileUpload *upload = [[IRCFileUpload alloc] initWithPath:path address:requestAddress];

	upload.destination = destination;

	[IRCConnectionProxy applyClientConfig:self.config toSessionConfiguration:upload.sessionConfiguration];

	return upload;
}

- (BOOL)pasteServiceUsable
{
	return (self.fileUploadsAvailable == NO &&
			self.config.uploadDestinationMode != IRCClientUploadDestinationModeOff &&
			[TLOUploadDestination sendsLongPastesToPasteService]);
}

- (nullable NSString *)textUploadDestinationDescription
{
	if (self.pasteServiceUsable) {
		return [TLOUploadDestination pasteServiceDestination].name;
	}

	return self.fileUploadDestinationDescription;
}

- (nullable IRCFileUpload *)textUploadForPath:(NSString *)path
{
	NSParameterAssert(path != nil);

	if (self.pasteServiceUsable) {
		return [self fileUploadForPath:path destination:[TLOUploadDestination pasteServiceDestination]];
	}

	return [self fileUploadForPath:path];
}

@end

NS_ASSUME_NONNULL_END
