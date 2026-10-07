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

#import "NSObjectHelperPrivate.h"
#import "TXAppearance.h"
#import "TPCApplicationInfo.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCResourceManager.h"
#import "TPCThemeInternal.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Theme Variety

@implementation TPCThemeVariety

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	if ((self = [super init])) {
		self.url = url.URLByStandardizingPath;

		[self _loadVariety];

		return self;
	}

	return nil;
}

- (void)_loadVariety
{
	NSURL *url = self.url;

	/* CSS file */
	NSURL *cssFile = [url URLByAppendingPathComponent:@"design.css"];

	if ([RZFileManager() fileExistsAtURL:cssFile]) {
		self.cssFile = cssFile;
	}

	/* JavaScript file */
	NSURL *jsFile = [url URLByAppendingPathComponent:@"scripts.js"];

	if ([RZFileManager() fileExistsAtURL:jsFile]) {
		self.jsFile = jsFile;
	}

	NSURL *templatesURL = [self.class _compatTemplatesAtURL:url];

	self.templateRepository = [GRMustacheTemplateRepository templateRepositoryWithBaseURL:templatesURL];

	/* Load settings dictionary */
	NSURL *settingsURL = [self.class _compatSettingsAtURL:url];

	NSDictionary<NSString *, id> *settings = [NSDictionary dictionaryWithContentsOfURL:settingsURL];

	if (settings == nil) {
		settings = @{};
	}

	self.settings = settings;

	/* Appearance */
	TPCThemeAppearanceType appearance = TPCThemeAppearanceTypeDefault;

	NSString *appearanceObject = [settings stringForKey:@"Appearance"];

	if ([appearanceObject isEqual:@"dark"]) {
		appearance = TPCThemeAppearanceTypeDark;
	} else if ([appearanceObject isEqual:@"light"]) {
		appearance = TPCThemeAppearanceTypeLight;
	}

	self.appearance = appearance;
}

static inline BOOL _reevaluateFileDuringSetOrUnset(NSURL *fileURL, NSURL * __strong *setter)
{
	BOOL fileExists = [RZFileManager() fileExistsAtURL:fileURL];

	if (fileExists) {
		if (*setter == nil) {
			*setter = [fileURL copy];

			return YES;
		}
	} else {
		if (*setter) {
			*setter = nil;

			return YES;
		}
	}

	return NO;
}

- (BOOL)_reevaluateFileDuringMonitoringAtURL:(NSURL *)fileURL
{
	NSParameterAssert(fileURL != nil);
	NSParameterAssert(fileURL.isFileURL);

	/* Returns YES if a change is made to property. NO otherwise. */

	/* This method is only called for the root of the variety which
	 means we only need to perform file name comparison. */
	NSString *filename = fileURL.lastPathComponent;

	if ([filename isEqual:@"design.css"]) {
		return _reevaluateFileDuringSetOrUnset(fileURL, &self->_cssFile);
	} else if ([filename isEqual:@"scripts.js"]) {
		return _reevaluateFileDuringSetOrUnset(fileURL, &self->_jsFile);
	}

	return NO;
}

#pragma mark -
#pragma mark Backwards Compatibility

+ (NSURL *)_compatSettingsAtURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSURL *oldURL = [url URLByAppendingPathComponent:@"Data/Settings/styleSettings.plist"];

	if ([RZFileManager() fileExistsAtURL:oldURL]) {
		return oldURL;
	}

	return [url URLByAppendingPathComponent:@"settings.plist"];
}

+ (NSURL *)_compatTemplatesAtURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSURL *oldURL = [url URLByAppendingPathComponent:@"Data/Templates/"];

	if ([RZFileManager() fileExistsAtURL:oldURL]) {
		return oldURL;
	}

	return [url URLByAppendingPathComponent:@"Templates/"];
}

@end

NS_ASSUME_NONNULL_END
