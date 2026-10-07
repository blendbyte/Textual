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

/* Defines for operating system detection. */
#define TXLoadMacOSVersionSpecificFeatures		1

/* Shortcut defines. */
#define RZAnimationCurrentContext()				[NSAnimationContext	currentContext]
#define RZAppearanceCurrentController()			[NSAppearance currentAppearance]
#define RZAppleEventManager()					[NSAppleEventManager sharedAppleEventManager]
#define RZCurrentCalendar()						[NSCalendar currentCalendar]
#define RZCurrentRunLoop()						[NSRunLoop currentRunLoop]
#define RZDistributedNotificationCenter()		[NSDistributedNotificationCenter defaultCenter]
#define RZFileManager()							[NSFileManager defaultManager]
#define RZFontManager()							[NSFontManager sharedFontManager]
#define RZGraphicsCurrentContext()				[NSGraphicsContext currentContext]
#define RZMainBundle()							[NSBundle mainBundle]
#define RZMainOperationQueue()					[NSOperationQueue mainQueue]
#define RZMainRunLoop()							[NSRunLoop mainRunLoop]
#define RZMainScreen()							[NSScreen mainScreen]
#define RZNotificationCenter()					[NSNotificationCenter defaultCenter]
#define RZPasteboard()							[NSPasteboard generalPasteboard]
#define RZProcessInfo()							[NSProcessInfo processInfo]
#define RZRunningApplication()					[NSRunningApplication currentApplication]
#define RZSharedApplication()					[NSApplication sharedApplication]
#define RZSpellChecker()						[NSSpellChecker	sharedSpellChecker]
#define RZUbiquitousKeyValueStore()				[NSUbiquitousKeyValueStore defaultStore]
#define RZUserNotificationCenter()				[UNUserNotificationCenter currentNotificationCenter]
#define RZWorkspace()							[NSWorkspace sharedWorkspace]
#define RZWorkspaceNotificationCenter()			[[NSWorkspace sharedWorkspace] notificationCenter]

/* Misc. */
#define NSInvertedComparisonResult(c)			((c) * (-1))

#define NSIsCurrentThreadMain()					[[NSThread isMainThread]]

/* Deprecation and symbol visibility. */
#define TEXTUAL_EXTERN							extern

#define TEXTUAL_SYMBOL_USED						__attribute__((used))

#define TEXTUAL_RUNNING_ON(version, name)		COCOA_EXTENSIONS_RUNNING_ON(version, name)
#define TEXTUAL_RUNNING_ON_BIGSUR 				TEXTUAL_RUNNING_ON(11.0, BigSur)
#define TEXTUAL_RUNNING_ON_MOJAVE 				TEXTUAL_RUNNING_ON(10.14, Mojave)
#define TEXTUAL_RUNNING_ON_HIGHSIERRA 			TEXTUAL_RUNNING_ON(10.13, HighSierra)
#define TEXTUAL_RUNNING_ON_SIERRA 				TEXTUAL_RUNNING_ON(10.12, Sierra)
#define TEXTUAL_RUNNING_ON_ELCAPITAN 			TEXTUAL_RUNNING_ON(10.11, ElCapitan)
#define TEXTUAL_RUNNING_ON_YOSEMITE 			TEXTUAL_RUNNING_ON(10.10, Yosemite)
#define TEXTUAL_RUNNING_ON_MAVERICKS 			TEXTUAL_RUNNING_ON(10.9, Mavericks)

#define TEXTUAL_DEPRECATED(reason)				COCOA_EXTENSIONS_DEPRECATED(reason)

#define TEXTUAL_DEPRECATED_ASSERT				COCOA_EXTENSIONS_DEPRECATED_ASSERT
#define TEXTUAL_DEPRECATED_ASSERT_C				COCOA_EXTENSIONS_DEPRECATED_ASSERT_C

#define TEXTUAL_DEPRECATED_WARNING				COCOA_EXTENSIONS_DEPRECATED_WARNING

#define TEXTUAL_IGNORE_DEPRECATION_BEGIN		COCOA_EXTENSIONS_IGNORE_DEPRECATION_BEGIN
#define TEXTUAL_IGNORE_DEPRECATION_END			COCOA_EXTENSIONS_IGNORE_DEPRECATION_END

#define TEXTUAL_IGNORE_AVAILABILITY_BEGIN		_Pragma("clang diagnostic push")									\
												_Pragma("clang diagnostic ignored \"-Wpartial-availability\"")

#define TEXTUAL_IGNORE_AVAILABILITY_END			_Pragma("clang diagnostic pop")

/* WebView deprecation */
/* The entirety of pre-WebKit2 code is deprecated by Apple.
 Textual uses a great deal of this code and if left unchecked, a large number
 of deprecation warnings will appear during build. It would be overwhelming
 to suppress every warning individually. Entire files have been marked to
 ignore deprecation warnings. As we cannot ignore WebKit specific deprecation
 warnings, this leaves the problem of unrelated deprecation warnings ignored.
 Modify the following flag routinely to check for unrelated deprecations. */
#define TEXTUAL_IGNORE_WEBKIT_DEPRECATIONS	1

#if TEXTUAL_IGNORE_WEBKIT_DEPRECATIONS == 1
	#define TEXTUAL_IGNORE_WEBKIT_DEPRECATIONS_BEGIN TEXTUAL_IGNORE_DEPRECATION_BEGIN
	#define TEXTUAL_IGNORE_WEBKIT_DEPRECATIONS_END TEXTUAL_IGNORE_DEPRECATION_END
#else
	#define TEXTUAL_IGNORE_WEBKIT_DEPRECATIONS_BEGIN
	#define TEXTUAL_IGNORE_WEBKIT_DEPRECATIONS_END
#endif

/* Helper function */
#define StringFromBOOL(value) ((value) ? @"YES" : @"NO")

#define SetVariableIfNil(variable, value)					\
	if ((variable) == nil) {								\
		(variable) = (value);								\
	}

#define SetVariableIfNilCopy(variable, value)				\
	SetVariableIfNil((variable), [(value) copy])

/* Define features */
#import "FeatureFlags.h"

/* @end */
