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

#import "ICMAssessedMedia.h"
#import "ICMCommonInlineImages.h"
#import "ICMCommonInlineVideos.h"
#import "ICMDailymotion.h"
#import "ICMGyazo.h"
#import "ICMImgurGifv.h"
#import "ICMPornhub.h"
#import "ICMStreamable.h"
#import "ICMTweet.h"
#import "ICMVimeo.h"
#import "ICMXkcd.h"
#import "ICMYouTube.h"
#import "ICPCoreMediaPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@implementation ICPCoreMedia

+ (NSArray<Class> *)modules
{
	static NSArray<Class> *modules = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		/* Twitch (clips and live) was removed: its embeds require a
		 parent= domain and Textual loads the chat view from file://. */
		modules =
		@[
			[ICMDailymotion class],
			[ICMGyazo class],
			[ICMImgurGifv class],
			[ICMPornhub class],
			[ICMStreamable class],
			[ICMTweet class],
			[ICMVimeo class],
			[ICMXkcd class],
			[ICMYouTube class],

			[ICMCommonInlineVideos class],
			[ICMCommonInlineImages class],

			/* This module should ALWAYS be the last
			 in line because it matches any URL. */
			[ICMAssessedMedia class]
		];
	});

	return modules;
}

@end

NS_ASSUME_NONNULL_END
