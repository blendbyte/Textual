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

#import "ICLHelpers.h"
#import "TLOLocalization.h"
#import "ICLInlineContentModulePrivate.h"
#import "ICLMediaAssessor.h"
#import "ICLMediaAssessment.h"
#import "ICLMediaSchemeHandlerPrivate.h"
#import "ICMInlineAudio.h"

NS_ASSUME_NONNULL_BEGIN

@interface ICMInlineAudio ()
@property (nonatomic, strong, nullable) ICLMediaAssessor *audioCheck;
@end

@implementation ICMInlineAudio

- (void)performAction
{
	[self performActionWithAudioCheck:YES];
}

- (void)performActionWithAudioCheck:(BOOL)checkAudio
{
	if (checkAudio == NO) {
		[self _safeToLoadAudioOfType:nil];

		return;
	}

	ICLPayload *payload = self.payload;

	ICLMediaAssessor *audioCheck =
	[ICLMediaAssessor assessorForURL:payload.urlToInline
							 session:payload.session
							withType:ICLMediaTypeAudio
					 completionBlock:^(ICLMediaAssessment *assessment, NSError *error) {
						 if (error == nil) {
							 [self _safeToLoadAudioOfType:assessment.contentType];
						 } else {
							 [ICLMediaAssessor logError:error];

							 [self cancel];
						 }

						 self.audioCheck = nil;
					 }];

	self.audioCheck = audioCheck;

	[audioCheck resume];
}

- (void)_safeToLoadAudioOfType:(nullable NSString *)contentType
{
	ICLPayloadMutable *payload = self.payload;

	NSURL *url = payload.urlToInline;

	NSURL *audioURL =
	[[ICLMediaSchemeHandler sharedHandler] URLForMediaAtURL:url
													session:payload.session
													   type:ICLMediaTypeAudio
											  maximumLength:0];

	NSString *fileName = url.lastPathComponent.stringByRemovingPercentEncoding;

	if (fileName.length == 0 || [fileName isEqualToString:@"/"]) {
		fileName = url.host;
	}

	/* WebKit picks its player by the type before loading, and the address
	 has no extension: without it, Ogg fails. Ogg sent as application/ogg
	 is audio here. */
	if ([contentType isEqualToString:@"application/ogg"]) {
		contentType = @"audio/ogg";
	}

	NSMutableDictionary<NSString *, id> *templateAttributes = [NSMutableDictionary dictionary];

	templateAttributes[@"audioURL"] = audioURL.absoluteString;
	templateAttributes[@"classAttribute"] = payload.classAttribute;
	templateAttributes[@"contentType"] = contentType;
	templateAttributes[@"fileName"] = fileName;
	templateAttributes[@"host"] = url.host;
	templateAttributes[@"uniqueIdentifier"] = payload.uniqueIdentifier;
	templateAttributes[@"hideLabel"] = TXTLS(@"TVCMainWindow[icm-h1]");

	NSError *templateRenderError = nil;

	NSString *html = [self.template renderObject:templateAttributes error:&templateRenderError];

	payload.html = html;

	/* For the script: the type WebKit is asked about before the card shows.
	 Set after the HTML, which the payload copies into it. */
	payload.entrypointPayload = @{@"contentType" : (contentType ?: @"")};

	[self finalizeWithError:templateRenderError];
}

#pragma mark -
#pragma mark Action Block

+ (ICLInlineContentModuleActionBlock)actionBlockForAddress:(NSString *)address
{
	NSParameterAssert(address != nil);

	return [^(ICLInlineContentModule *module) {
		NSURL *url = [ICLHelpers URLWithString:address];

		if (url == nil) {
			[module cancel];

			return;
		}

		module.payload.urlToInline = url;

		[(ICMInlineAudio *)module performAction];
	} copy];
}

#pragma mark -
#pragma mark Resources

- (nullable NSURL *)templateURL
{
	return ICLResourceURL(@"ICMInlineAudio", @"mustache");
}

- (nullable NSArray<NSURL *> *)scriptResources
{
	static NSArray<NSURL *> *scriptResources = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		scriptResources =
		@[
		  ICLResourceURL(@"ICMInlineAudio", @"js")
		];
	});

	return scriptResources;
}

- (nullable NSString *)entrypoint
{
	return @"_ICMInlineAudio";
}

- (void)finalizePreflight
{
	self.payload.classAttribute = @"inlinePreviewCard inlineAudio";
}

@end

NS_ASSUME_NONNULL_END
