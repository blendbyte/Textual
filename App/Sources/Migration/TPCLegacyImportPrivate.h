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

NS_ASSUME_NONNULL_BEGIN

/* An earlier installation of Textual. Every one keeps its data in a group
 container under ~/Library/Group Containers (migration plan §3.1). */
@interface TPCLegacyImportSource : NSObject
@property (readonly, copy) NSString *groupIdentifier;
@property (readonly, copy) NSString *displayName;
@property (readonly, copy) NSURL *groupURL;

/* The preferences file when it is outside the group container (before the
 sandbox), which takes a grant of its own */
@property (readonly, copy, nullable) NSURL *outsidePreferencesURL;

/* When the earlier version last saved its settings, if macOS tells */
@property (readonly, copy, nullable) NSDate *lastUsedDate;

/* Licence-manager builds: the folder with the earlier version's licence,
 if it exists and this copy has no licence yet */
@property (readonly, copy, nullable) NSURL *licenseFolderURL;
@end

/* What an import did, for the summary */
@interface TPCLegacyImportResult : NSObject
@property (readonly) NSUInteger serverCount;
@property (readonly, copy) NSArray<NSString *> *styles;
@property (readonly, copy) NSArray<NSString *> *extensions;
@property (readonly, copy) NSArray<NSString *> *inlineMediaModules;
@property (readonly) NSUInteger failureCount;
@property (readonly) BOOL importedScrollback;
@property (readonly) BOOL triedLicense;
@property (readonly) BOOL importedLicense;
@property (readonly) BOOL hadTranscriptFolder;
@property (readonly) BOOL hadDownloadFolder;
@property (readonly, copy, nullable) NSURL *encryptionComponentsURL;
@property (readonly, copy, nullable) NSURL *scriptsURL;
@end

typedef NS_ENUM(NSUInteger, TPCLegacyImportReadError) {
	TPCLegacyImportReadErrorNone = 0,
	TPCLegacyImportReadErrorUnreadable, // no settings file in the folder
	TPCLegacyImportReadErrorEmpty // never set up
};

/* Imports the settings, files, scrollback and licence of Textual 7 (or an
 earlier version) through folders the user grants access to. Textual 8 has
 a new identity (D7), so nothing of the earlier version's is reused in place.
 The window that walks the user through it is TDCLegacyImportAssistant. */
@interface TPCLegacyImport : NSObject
/* Sources with settings, most recently used first */
@property (class, readonly, copy) NSArray<TPCLegacyImportSource *> *availableSources;

/* Textual 7 or an earlier version is running: its settings and scrollback
 could change while they are copied */
@property (class, readonly) BOOL earlierVersionIsRunning;

/* This copy already has servers: an import replaces its settings */
@property (class, readonly) BOOL hasServers;

/* At launch: not offered before, no servers yet, something to import
 (development builds only when asked to) */
@property (class, readonly) BOOL shouldOfferAtLaunch;

/* The launch offer stays away (after an import, or "Start Fresh") */
+ (void)markOffered;

/* A folder granted before (security-scoped bookmark), or nil */
+ (nullable NSURL *)rememberedURLForFolder:(NSURL *)folderURL;
+ (void)rememberGrantedURL:(NSURL *)url;

/* The import, in steps so the window can show progress. Call
 -startAccessingSecurityScopedResource on the granted URLs first. */
- (instancetype)initWithSource:(TPCLegacyImportSource *)source;

@property (readonly) TPCLegacyImportSource *source;
@property (readonly) TPCLegacyImportResult *result;

- (TPCLegacyImportReadError)readPreferencesAtURL:(NSURL *)preferencesURL;
- (NSURL *)preferencesURLInGroupURL:(NSURL *)groupURL;

@property (readonly) NSUInteger serverCount; // after reading

- (void)importStylesFromGroupURL:(NSURL *)groupURL;
- (void)importExtensionsFromGroupURL:(NSURL *)groupURL;
- (void)importScrollbackFromGroupURL:(NSURL *)groupURL;
- (void)noteOtherContentOfGroupURL:(NSURL *)groupURL; // modules, OTR keys, scripts
- (void)importPreferences; // last: replaces this copy's settings

- (void)importLicenseFromFolderURL:(NSURL *)folderURL;

/* After the import */
- (BOOL)saveEncryptionComponentsToFolderURL:(NSURL *)folderURL groupURL:(NSURL *)groupURL;
- (void)deleteEarlierDataInGroupURL:(NSURL *)groupURL;

/* Quits without saving and starts a new copy */
+ (void)restart;
@end

NS_ASSUME_NONNULL_END
