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

#import "BuildConfig.h"

#import "OELReachability.h"
#import "TXAppearance.h"
#import "TXMasterController.h"
#import "TXMenuController.h"
#import "TXWindowControllerPrivate.h"
#import "TPCThemeController.h"
#import "THOPluginManagerPrivate.h"
#import "IRCWorld.h"
#import "TLONotificationController.h"
#import "TLOSpeechSynthesizerPrivate.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCLicenseManagerDialogPrivate.h"
#import "TVCLogControllerOperationQueuePrivate.h"
#import "TXSharedApplicationPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const TXErrorDomain = @"TextualErrorDomain";

#define _defineSharedInstance(si_name, si_class, si_init_method)	\
			+ (si_class *)si_name									\
			{														\
				static id sharedSelf = nil;							\
																	\
				static dispatch_once_t onceToken;					\
																	\
				dispatch_once(&onceToken, ^{						\
					sharedSelf = [si_class si_init_method];			\
				});													\
																	\
				return sharedSelf;									\
			}

@implementation TXSharedApplication

_defineSharedInstance(sharedAppearance, TXAppearance, new)

_defineSharedInstance(sharedNetworkReachabilityNotifier, OELReachability, reachabilityForInternetConnection)
_defineSharedInstance(sharedNotificationController, TLONotificationController, new)
_defineSharedInstance(sharedPluginManager, THOPluginManager, new)
_defineSharedInstance(sharedPrintingQueue, TVCLogControllerPrintingOperationQueue, new)
_defineSharedInstance(sharedSpeechSynthesizer, TLOSpeechSynthesizer, new)
_defineSharedInstance(sharedThemeController, TPCThemeController, new)
_defineSharedInstance(sharedWindowController, TXWindowController, new)

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
_defineSharedInstance(sharedLicenseManagerDialog, TDCLicenseManagerDialog, new)
#endif

_defineSharedInstance(sharedFileTransferDialog, TDCFileTransferDialog, new)

os_log_t ApplicationTerminationLogSubsystem(void)
{
	static os_log_t cachedValue = NULL;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		cachedValue = os_log_create(TXBundleBuildProductIdentifierCString, "Termination");
	});

	return cachedValue;
}

@end

#pragma mark -

@implementation NSObject (TXSharedApplicationObjectExtension)

__weak static TXMasterController *TXGlobalMasterControllerClassReference;

+ (void)setGlobalMasterControllerClassReference:(id)masterController
{
	TXGlobalMasterControllerClassReference = masterController;
}

- (TXMasterController *)masterController
{
	return TXGlobalMasterControllerClassReference;
}

+ (TXMasterController *)masterController
{
	return TXGlobalMasterControllerClassReference;
}

@end

NS_ASSUME_NONNULL_END
