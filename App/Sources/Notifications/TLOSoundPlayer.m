/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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

#import <AudioToolbox/AudioToolbox.h>

#import "TLONotificationConfigurationPrivate.h"
#import "TLOSoundPlayer.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TLOSoundPlayer

+ (NSDictionary<NSString *, NSString *> *)soundFilesAtPath:(NSString *)path
{
	NSMutableDictionary<NSString *, NSString *> *resultData = [NSMutableDictionary dictionary];

	NSArray *files = [RZFileManager() contentsOfDirectoryAtPath:path error:NULL];

	for (NSString *file in files) {
		NSString *filePath = [path stringByAppendingPathComponent:file];

		NSString *fileWithoutExtension = file.stringByDeletingPathExtension;

		resultData[fileWithoutExtension] = filePath;
	}

	return resultData;
}

+ (nullable NSDictionary<NSString *, NSString *> *)systemAlertSoundFiles
{
	NSArray *folders = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES);

	if (folders.count == 0) {
		return nil;
	}

	NSString *folder = [folders[0] stringByAppendingPathComponent:@"/Sounds/"];

	return [self soundFilesAtPath:folder];
}

+ (nullable NSDictionary<NSString *, NSString *> *)systemLibrarySoundFiles
{
	NSArray *folders = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSLocalDomainMask, YES);

	if (folders.count == 0) {
		return nil;
	}

	NSString *folder = [folders[0] stringByAppendingPathComponent:@"/Sounds/"];

	return [self soundFilesAtPath:folder];
}

+ (nullable NSDictionary<NSString *, NSString *> *)userLibrarySoundFiles
{
	NSArray *folders = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);

	if (folders.count == 0) {
		return nil;
	}

	NSString *folder = [folders[0] stringByAppendingPathComponent:@"/Sounds/"];

	return [self soundFilesAtPath:folder];
}

+ (void)doesSoundFileDictionary:(NSDictionary<NSString *, NSString *> *)fileList containName:(NSString *)name returnedPath:(NSString **)path
{
	NSString *filePath = fileList[name];

	if (filePath == nil) {
		return;
	}

	NSString *fileExtension = filePath.pathExtension;

	CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(
		kUTTagClassFilenameExtension, (__bridge CFStringRef)fileExtension, NULL);

	if (UTTypeConformsTo(fileUTI, kUTTypeAudio) == false) {
		LogToConsoleDebug("File is not audio file: '%{public}@'", filePath.standardizedTildePath);

		CFRelease(fileUTI);

		return;
	}

	CFRelease(fileUTI);

	if ( path) {
		*path = filePath;
	}
}

+ (SystemSoundID)alertSoundNamed:(NSString *)name
{
	NSString *soundPath = nil;

	NSDictionary *soundFiles = [self userLibrarySoundFiles];

	[self doesSoundFileDictionary:soundFiles containName:name returnedPath:&soundPath];

	if (soundPath == nil) {
		soundFiles = [self systemLibrarySoundFiles];

		[self doesSoundFileDictionary:soundFiles containName:name returnedPath:&soundPath];
	}

	if (soundPath == nil) {
		soundFiles = [self systemAlertSoundFiles];

		[self doesSoundFileDictionary:soundFiles containName:name returnedPath:&soundPath];
	}

	if (soundPath == nil) {
		return 0;
	}

	NSURL *soundPathURL = [NSURL fileURLWithPath:soundPath];

	SystemSoundID soundID;

	OSStatus soundLoadError = AudioServicesCreateSystemSoundID((__bridge CFURLRef)(soundPathURL), &soundID);

	if (soundLoadError == noErr) {
		return soundID;
	}

	LogToConsoleError("Returned error code %{public}i when loading file at path: %{public}@",
		soundLoadError, soundPathURL.standardizedTildePath);

	return 0;
}

+ (void)playAlertSound:(NSString *)name
{
	NSParameterAssert(name != nil);

	if ([name isEqualToString:TXNoAlertSoundPreferenceValue]) {
		return;
	}

	if ([name isEqualToString:@"Beep"]) {
		NSBeep();

		return;
	}

	SystemSoundID soundID = [self alertSoundNamed:name];

	if (soundID) {
		AudioServicesPlayAlertSound(soundID);

		// AudioServicesDisposeSystemSoundID(soundID);
	} else {
		LogToConsoleError("Error: Unable to locate sound '%{public}@'", name);
	}
}

+ (NSArray<NSString *> *)uniqueListOfSounds
{
	NSMutableArray<NSString *> *sounds = [NSMutableArray array];

	[sounds addObject:@"Beep"]; // For NSBeep()

	for (NSString *sound in [self systemAlertSoundFiles]) {
		if ([sounds containsObject:sound] == NO) {
			[sounds addObject:sound];
		}
	}

	for (NSString *sound in [self systemLibrarySoundFiles]) {
		if ([sounds containsObject:sound] == NO) {
			[sounds addObject:sound];
		}
	}

	for (NSString *sound in [self userLibrarySoundFiles]) {
		if ([sounds containsObject:sound] == NO) {
			[sounds addObject:sound];
		}
	}

	[sounds sortUsingSelector:@selector(caseInsensitiveCompare:)];

	return [sounds copy];
}

@end

NS_ASSUME_NONNULL_END
