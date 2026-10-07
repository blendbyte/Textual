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

@class THOPluginOutputSuppressionRule;

typedef NS_OPTIONS(NSUInteger, THOPluginItemSupportedFeature) {
	THOPluginItemSupportedFeatureDidReceiveCommandEvent				= 1 << 1,
	THOPluginItemSupportedFeatureDidReceivePlainTextMessageEvent	= 1 << 2,
//	THOPluginItemSupportedFeatureInlineMediaManipulation			= 1 << 3,
	THOPluginItemSupportedFeatureNewMessagePostedEvent				= 1 << 4,
	THOPluginItemSupportedFeatureOutputSuppressionRules				= 1 << 5,
	THOPluginItemSupportedFeaturePreferencePane						= 1 << 6,
	THOPluginItemSupportedFeatureServerInputDataInterception		= 1 << 7,
	THOPluginItemSupportedFeatureSubscribedServerInputCommands		= 1 << 8,
	THOPluginItemSupportedFeatureSubscribedUserInputCommands		= 1 << 9,
	THOPluginItemSupportedFeatureUserInputDataInterception			= 1 << 10,
	THOPluginItemSupportedFeatureWebViewJavaScriptPayloads			= 1 << 11,
	THOPluginItemSupportedFeatureWillRenderMessageEvent				= 1 << 12,
};

@interface THOPluginItem : NSObject
@property (readonly, nullable) NSBundle *bundle;
@property (readonly, nullable) id primaryClass;
@property (readonly, assign) THOPluginItemSupportedFeature supportedFeatures;
@property (readonly, copy, nullable) NSArray<NSString *> *supportedServerInputCommands;
@property (readonly, copy, nullable) NSArray<NSString *> *supportedUserInputCommands;
@property (readonly, copy, nullable) NSArray<THOPluginOutputSuppressionRule *> *outputSuppressionRules;
@property (readonly, copy, nullable) NSString *pluginPreferencesPaneMenuItemTitle;
@property (readonly, nullable) NSView *pluginPreferencesPaneView;

- (BOOL)loadBundle:(NSBundle *)bundle;
- (void)unloadBundle;

/* Every call into a plugin goes through here. A plugin that throws an
 exception is logged and disabled: it gets no further calls. Returns NO
 if the plugin is disabled or threw. */
- (BOOL)performCall:(void (NS_NOESCAPE ^)(void))call;

- (BOOL)supportsFeature:(THOPluginItemSupportedFeature)feature;
@end

NS_ASSUME_NONNULL_END
