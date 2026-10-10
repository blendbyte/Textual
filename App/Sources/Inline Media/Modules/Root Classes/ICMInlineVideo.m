/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2017, 2018 Codeux Software, LLC & respective contributors.
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

#import "TPCPreferences.h"
#import "ICLHelpers.h"
#import "ICLInlineContentModulePrivate.h"
#import "ICLMediaAssessor.h"
#import "ICMInlineVideo.h"

NS_ASSUME_NONNULL_BEGIN

@interface ICMInlineVideo ()
@property (nonatomic, strong, nullable) ICLMediaAssessor *videoCheck;
@end

@implementation ICMInlineVideo

- (void)performAction
{
	[self performActionWithVideoCheck:YES];
}

- (void)performActionWithVideoCheck:(BOOL)checkVideo
{
	if (checkVideo) {
		[self _performVideoCheck];
	} else {
		[self _safeToLoadVideo];
	}
}

- (void)performActionForURL:(NSURL *)url
{
	[self performActionForURL:url bypassVideoCheck:NO];
}

- (void)performActionForURL:(NSURL *)url bypassVideoCheck:(BOOL)bypassVideoCheck
{
	NSParameterAssert(url != nil);

	if (self.videoCheck) {
		LogToConsoleError("Module already started");

		return;
	}

	self.payload.urlToInline = url;

	[self performActionWithVideoCheck:(bypassVideoCheck == NO)];
}

- (void)performActionForAddress:(NSString *)address
{
	[self performActionForAddress:address bypassVideoCheck:NO];
}

- (void)performActionForAddress:(NSString *)address bypassVideoCheck:(BOOL)bypassVideoCheck
{
	NSParameterAssert(address != nil);

	NSURL *url = [ICLHelpers URLWithString:address];

	if (url == nil) {
		[self notifyUnsafeToLoadVideo];

		return;
	}

	[self performActionForURL:url bypassVideoCheck:bypassVideoCheck];
}

- (void)_performVideoCheck
{
	ICLPayload *payload = self.payload;

	ICLMediaAssessor *videoCheck =
	[ICLMediaAssessor assessorForURL:payload.urlToInline
							 session:payload.session
							withType:ICLMediaTypeVideo
					 completionBlock:^(ICLMediaAssessment *assessment, NSError *error) {
						 BOOL safeToLoad = (error == nil);

						 if (safeToLoad) {
							 [self _safeToLoadVideo];
						 } else {
							 [self _unsafeToLoadVideo];

							 [ICLMediaAssessor logError:error];
						 }

						 self.videoCheck = nil;
					 }];

	self.videoCheck = videoCheck;

	[videoCheck resume];
}

- (void)_unsafeToLoadVideo
{
	[self notifyUnsafeToLoadVideo];
}

- (void)_safeToLoadVideo
{
	ICLPayloadMutable *payload = self.payload;

	double playbackSpeed = self.videoPlaybackSpeed;

	if (playbackSpeed < 0.125 || playbackSpeed > 6.0) {
		playbackSpeed = 1.0;
	}

	NSDictionary *templateAttributes =
	@{
		@"anchorLink" : payload.address,
		@"classAttribute" : payload.classAttribute,
		@"preferredMaximumWidth" : @([TPCPreferences inlineMediaMaxWidth]),
		@"uniqueIdentifier" : payload.uniqueIdentifier,
		@"videoAutoplayEnabled" : @(self.videoAutoplayEnabled),
		@"videoControlsEnabled" : @(self.videoControlsEnabled),
		@"videoLoopEnabled" : @(self.videoLoopEnabled),
		@"videoMuteEnabled" : @(self.videoMuteEnabled),
		@"videoPlaybackSpeed" : @(playbackSpeed),
		@"videoStartTime" : @(self.videoStartTime),
		@"videoURL" : payload.addressToInline
	};

	NSError *templateRenderError = nil;

	NSString *html = [self.template renderObject:templateAttributes error:&templateRenderError];

	payload.html = html;

	[self finalizeWithError:templateRenderError];
}

- (void)notifyUnsafeToLoadVideo
{
	[self cancel];
}

#pragma mark -
#pragma mark Action Block

+ (ICLInlineContentModuleActionBlock)actionBlockForForURL:(NSURL *)url
{
	return [self actionBlockForForURL:url bypassVideoCheck:NO];
}

+ (ICLInlineContentModuleActionBlock)actionBlockForForURL:(NSURL *)url bypassVideoCheck:(BOOL)bypassVideoCheck
{
	NSParameterAssert(url != nil);

	return [self actionBlockForAddress:url.absoluteString bypassVideoCheck:bypassVideoCheck];
}

+ (ICLInlineContentModuleActionBlock)actionBlockForAddress:(NSString *)address
{
	return [self actionBlockForAddress:address bypassVideoCheck:NO];
}

+ (ICLInlineContentModuleActionBlock)actionBlockForAddress:(NSString *)address bypassVideoCheck:(BOOL)bypassVideoCheck
{
	NSParameterAssert(address != nil);

	return [^(ICLInlineContentModule *module) {
		__weak ICMInlineVideo *moduleTyped = (id)module;

		[moduleTyped performActionForAddress:address bypassVideoCheck:bypassVideoCheck];
	} copy];
}

@end

#pragma mark -
#pragma mark Foundation

@implementation ICMInlineVideoFoundation

- (instancetype)initWithPayload:(ICLPayloadMutable *)payload
{
	if ((self = [super initWithPayload:payload])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self.videoControlsEnabled = YES;

	self.videoPlaybackSpeed = 1.0;
}

+ (BOOL)contentImageOrVideo
{
	return YES;
}

- (nullable NSURL *)templateURL
{
	return ICLResourceURL(@"ICMInlineVideo", @"mustache");
}

- (nullable NSArray<NSURL *> *)styleResources
{
	static NSArray<NSURL *> *styleResources = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		styleResources =
		@[
		  ICLResourceURL(@"ICMInlineVideo", @"css")
		];
	});

	return styleResources;
}

- (nullable NSArray<NSURL *> *)scriptResources
{
	static NSArray<NSURL *> *scriptResources = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		scriptResources =
		@[
		  ICLResourceURL(@"ICMInlineVideo", @"js")
		];
	});

	return scriptResources;
}

- (nullable NSString *)entrypoint
{
	return @"_ICMInlineVideo";
}

+ (NSTimeInterval)parseYouTubeEsqueTimestamp:(NSString *)timestamp
{
	NSParameterAssert(timestamp != nil);
	
	if (timestamp.isPositiveWholeNumber) {
		return timestamp.doubleValue;
	}
	
	__block NSTimeInterval startTime = 0;
	
	__block BOOL matchedHour = NO;
	__block BOOL matchedMinute = NO;
	__block BOOL matchedSecond = NO;

	[timestamp enumerateMatchesOfRegularExpression:@"[0-9]+[hms]"
										 withBlock:^(NSRange range, BOOL *stop)
	 {
		 NSString *fragment = [timestamp substringWithRange:range];
		 
		 NSString *fragmentUnit = [fragment substringAtIndex:0 toLength:(-1)];
		 NSString *fragmentValue = [fragment substringAtIndex:(-1) toLength:0];
		 
		 /* Could use dictionary to index each formatter, but
		  that seemed like overkill for this implemention. */
		 if (matchedHour == NO && [fragmentUnit isEqualToString:@"h"]) {
			 matchedHour = YES;
			 startTime += (fragmentValue.integerValue * 3600); // 1 hour
		 } else if (matchedMinute == NO && [fragmentUnit isEqualToString:@"m"]) {
			 matchedMinute = YES;
			 startTime += (fragmentValue.integerValue * 60); // 1 minute
		 } else if (matchedSecond == NO && [fragmentUnit isEqualToString:@"s"]) {
			 matchedSecond = YES;
			 startTime += fragmentValue.integerValue;
		 }
		 
		 if (matchedHour && matchedMinute && matchedSecond) {
			*stop = YES;
		 }
	 }
										   options:NSCaseInsensitiveSearch];
	
	return startTime;
}

@end

#pragma mark -
#pragma mark Gif Video

@implementation ICMInlineGifVideo

/* Called by -[ICMInlineVideoFoundation initWithPayload:] */
- (void)prepareInitialState
{
	[super prepareInitialState];

	self.videoAutoplayEnabled = YES;
	self.videoControlsEnabled = NO;
	self.videoLoopEnabled = YES;
	self.videoMuteEnabled = YES;
}

@end

NS_ASSUME_NONNULL_END
