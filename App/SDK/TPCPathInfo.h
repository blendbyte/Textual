/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
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

NS_ASSUME_NONNULL_BEGIN

@interface TPCPathInfo : NSObject
#pragma mark -
#pragma mark Application Specific

@property (readonly, class, copy) NSString *applicationBundle;
@property (readonly, class, copy) NSURL *applicationBundleURL;

@property (readonly, class, copy) NSString *applicationResources;
@property (readonly, class, copy) NSURL *applicationResourcesURL;

@property (readonly, class, copy, nullable) NSString *applicationCaches;
@property (readonly, class, copy, nullable) NSURL *applicationCachesURL;

@property (readonly, class, copy, nullable) NSString *groupContainer;
@property (readonly, class, copy, nullable) NSURL *groupContainerURL;

@property (readonly, class, copy, nullable) NSString *groupContainerApplicationCaches;
@property (readonly, class, copy, nullable) NSURL *groupContainerApplicationCachesURL;

@property (readonly, class, copy, nullable) NSString *applicationSupport;
@property (readonly, class, copy, nullable) NSURL *applicationSupportURL;

@property (readonly, class, copy, nullable) NSString *groupContainerApplicationSupport;
@property (readonly, class, copy, nullable) NSURL *groupContainerApplicationSupportURL;

@property (readonly, class, copy, nullable) NSString *applicationLogs;
@property (readonly, class, copy, nullable) NSURL *applicationLogsURL;

@property (readonly, class, copy) NSString *applicationTemporary;
@property (readonly, class, copy) NSURL *applicationTemporaryURL;

@property (readonly, class, copy) NSString *applicationTemporaryProcessSpecific;
@property (readonly, class, copy) NSURL *applicationTemporaryProcessSpecificURL;

@property (readonly, class, copy) NSString *bundledExtensions;
@property (readonly, class, copy) NSURL *bundledExtensionsURL;

@property (readonly, class, copy) NSString *bundledScripts;
@property (readonly, class, copy) NSURL *bundledScriptsURL;

@property (readonly, class, copy) NSString *bundledThemes;
@property (readonly, class, copy) NSURL *bundledThemesURL;

@property (readonly, class, copy, nullable) NSString *customExtensions;
@property (readonly, class, copy, nullable) NSURL *customExtensionsURL;

@property (readonly, class, copy, nullable) NSString *customScripts;
@property (readonly, class, copy, nullable) NSURL *customScriptsURL;

@property (readonly, class, copy, nullable) NSString *customThemes;
@property (readonly, class, copy, nullable) NSURL *customThemesURL;

#pragma mark -
#pragma mark System Specific

@property (readonly, class, copy, nullable) NSString *systemApplications;
@property (readonly, class, copy, nullable) NSURL *systemApplicationsURL;

@property (readonly, class, copy) NSString *systemDiagnosticReports;
@property (readonly, class, copy) NSURL *systemDiagnosticReportsURL;

#pragma mark -
#pragma mark User Specific

@property (readonly, class, copy, nullable) NSString *userApplicationScripts;
@property (readonly, class, copy, nullable) NSURL *userApplicationScriptsURL;

@property (readonly, class, copy) NSString *userDiagnosticReports;
@property (readonly, class, copy) NSURL *userDiagnosticReportsURL;

@property (readonly, class, copy, nullable) NSString *userDownloads;
@property (readonly, class, copy, nullable) NSURL *userDownloadsURL;

@property (readonly, class, copy) NSString *userHome;
@property (readonly, class, copy) NSURL *userHomeURL;

@property (readonly, class, copy, nullable) NSString *userPreferences;
@property (readonly, class, copy, nullable) NSURL *userPreferencesURL;
@end

NS_ASSUME_NONNULL_END
