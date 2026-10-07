/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2018 - 2020 Codeux Software, LLC & respective contributors.
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

typedef NS_ENUM(NSUInteger, TXAppearanceType)
{
	TXAppearanceTypeBigSurLight,
	TXAppearanceTypeBigSurDark,
};

/* TXAppKitAppearanceTarget defines which items the NSAppearance
 object returned by -appKitAppearance should be assigned to. */
typedef NS_ENUM(NSUInteger, TXAppKitAppearanceTarget)
{
	/* The NSAppearance object should be assigned to the window. */
	TXAppKitAppearanceTargetWindow,

	/* The NSAppearance object shouldn't be assigned to anything. */
	TXAppKitAppearanceTargetNone
};

/* None of these properties are observable.
 See -[TXAppearance properties] for information about observing. */
@protocol TXAppearanceProperties <NSObject>
@property (readonly, copy) NSString *appearanceName;

@property (readonly) TXAppearanceType appearanceType;

@property (readonly, copy) NSString *shortAppearanceDescription; // e.g. "light", "dark"

@property (readonly) BOOL isDarkAppearance;

@property (readonly) TXAppKitAppearanceTarget appKitAppearanceTarget;
@property (readonly, nullable) NSAppearance *appKitAppearance; // nil when -appKitAppearanceTarget = none
@end

@interface TXAppearancePropertyCollection : NSObject <TXAppearanceProperties>
@property (readonly, class) BOOL systemWideDarkModeEnabled;

@property (readonly, class, nullable) NSAppearance *appKitLightAppearance;
@property (readonly, class, nullable) NSAppearance *appKitDarkAppearance;
@end

/* Access through +[TXSharedApplication sharedAppearance] */
@interface TXAppearance : NSObject
/* TXAppearance replaces the property collection object whenever the
 appearance changes so that there is no delay from when one property
 is set and another is set. Observe changes to the properties collection
 object and not an individual property. Latter will not work. */
@property (readonly, strong) TXAppearancePropertyCollection *properties;
@end

TEXTUAL_EXTERN NSNotificationName const TXApplicationAppearanceChangedNotification;
TEXTUAL_EXTERN NSNotificationName const TXSystemAppearanceChangedNotification;

NS_ASSUME_NONNULL_END

#import "TXAppearanceHelper.h"
