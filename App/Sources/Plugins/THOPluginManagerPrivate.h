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

#import "THOPluginItemPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@class THOPluginOutputSuppressionRule;

TEXTUAL_EXTERN NSNotificationName const THOPluginManagerFinishedLoadingPluginsNotification;

@interface THOPluginManager : NSObject
- (void)loadPlugins;
- (void)unloadPlugins;

@property (readonly) BOOL pluginsLoaded;

@property (readonly, copy, nullable) NSArray<THOPluginItem *> *loadedPlugins; // nil until load completes

@property (readonly, copy) NSArray<NSString *> *supportedServerInputCommands;
@property (readonly, copy) NSArray<NSString *> *supportedUserInputCommands;

@property (readonly, copy) NSArray<NSString *> *supportedAppleScriptCommands;
@property (readonly, copy) NSDictionary<NSString *, NSString *> *supportedAppleScriptCommandsAndPaths;

@property (readonly, copy) NSArray<THOPluginItem *> *pluginsWithPreferencePanes;

@property (readonly, copy) NSArray<THOPluginOutputSuppressionRule *> *pluginOutputSuppressionRules;

/* YES for extensions of removed features (Blowfish, Wiki-style Link Parser) */
- (BOOL)bundleIsUnsupported:(NSBundle *)bundle;

/* Returns YES if at least one loaded plugin supports the feature */
- (BOOL)supportsFeature:(THOPluginItemSupportedFeature)feature;

- (void)findHandlerForOutgoingCommand:(NSString *)command
								 path:(NSString * _Nullable * _Nullable)path
							 isScript:(BOOL *)isScript
						  isExtension:(BOOL *)isExtension;
@end

NS_ASSUME_NONNULL_END
