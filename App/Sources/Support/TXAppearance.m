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
 *	* Redistributions of source code must retain the above copyright
 *	  notice, this list of conditions and the following disclaimer.
 *	* Redistributions in binary form must reproduce the above copyright
 *	  notice, this list of conditions and the following disclaimer in the
 *	  documentation and/or other materials provided with the distribution.
 *  * Neither the name of Textual and/or Codeux Software, nor the names of
 *    its contributors may be used to endorse or promote products derived
 * 	  from this software without specific prior written permission.
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
#import "TPCPreferencesLocal.h"
#import "TXAppearance.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const TXApplicationAppearanceChangedNotification = @"TXApplicationAppearanceChangedNotification";
NSString * const TXSystemAppearanceChangedNotification = @"TXSystemAppearanceChangedNotification";

@interface TXAppearancePropertyCollection ()
@property (nonatomic, copy, readwrite) NSString *appearanceName;
@property (nonatomic, assign, readwrite) TXAppearanceType appearanceType;
@property (nonatomic, assign, readwrite) BOOL isDarkAppearance;
@property (nonatomic, assign, readwrite) TXAppKitAppearanceTarget appKitAppearanceTarget;
@end

@interface TXAppearance ()
@property (nonatomic, strong, readwrite) TXAppearancePropertyCollection *properties;
@end

@implementation TXAppearance

#pragma mark -
#pragma mark Initialization

- (instancetype)init
{
	if ((self = [super init])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[self updateAppearance];

	[RZWorkspaceNotificationCenter() addObserver:self
										selector:@selector(accessibilityDisplayOptionsDidChange:)
											name:NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification
										  object:nil];

	[NSApp addObserver:self forKeyPath:@"effectiveAppearance" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)prepareForApplicationTermination
{
	LogToConsoleTerminationProgress("Removing appearance change observers");

	[RZNotificationCenter() removeObserver:self];

	[NSApp removeObserver:self forKeyPath:@"effectiveAppearance"];
}

#pragma mark -
#pragma mark Properties

+ (nullable NSString *)appearanceNameForType:(TXAppearanceType)type
{
	switch (type) {
		case TXAppearanceTypeBigSurLight:
		{
			return @"BigSurLight";
		}
		case TXAppearanceTypeBigSurDark:
		{
			return @"BigSurDark";
		}
		default:
		{
			return nil;
		}
	}
}

#pragma mark -
#pragma mark Notifications

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSString *, id> *)change context:(nullable void *)context
{
	if ([keyPath isEqualToString:@"effectiveAppearance"]) {
		[self applicationAppearanceChanged];
	}
}

- (void)applicationAppearanceChanged
{
	/* Wait until next pass of the run loop to perform
	 update because the effective appearance may not
	 be propagated to all subviews when this is called. */
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self updateAppearanceBySystemChange];
	});
}

- (void)systemColorsDidChange:(NSNotification *)aNote
{
	[self updateAppearanceBySystemChange];
}

- (void)accessibilityDisplayOptionsDidChange:(NSNotification *)aNote
{
	[self updateAppearanceBySystemChange];
}

- (void)updateAppearance
{
	[self updateAppearanceBySystemChange:NO];
}

- (void)updateAppearanceBySystemChange
{
	[self updateAppearanceBySystemChange:YES];
}

- (void)updateAppearanceBySystemChange:(BOOL)systemChanged
{
	TXAppearanceType appearanceType = TXAppearanceTypeBigSurLight;

	TXPreferredAppearance preferredAppearance = [TPCPreferences appearance];

	/* Determine user's preference */
	switch (preferredAppearance) {
		case TXPreferredAppearanceInherited:
		{
			if ([TXAppearancePropertyCollection systemWideDarkModeEnabled]) {
				appearanceType = TXAppearanceTypeBigSurDark;
			}

			break;
		}
		case TXPreferredAppearanceDark:
		{
			appearanceType = TXAppearanceTypeBigSurDark;

			break;
		}
		default:
		{
			break;
		}
	}

	BOOL isAppearanceDark = (appearanceType == TXAppearanceTypeBigSurDark);

	/* Determine best appearance inheritance approach */
	/* Before Mojave, appearance needs to be applied to every view.
	 After Mojave, views properly inherit the appearance of the parent
	 window or the system. If the user selects a specific appearance,
	 then we apply that to the parent window on Mojave and later to
	 allow views to inherit that. If the user selects the system
	 appearance, then we apply nothing and allow it to be inherited
	 from the system. */
	TXAppKitAppearanceTarget appKitAppearanceTarget = TXAppKitAppearanceTargetNone;

	if (preferredAppearance != TXPreferredAppearanceInherited) {
		appKitAppearanceTarget = TXAppKitAppearanceTargetWindow;
	}

	/* Test for changes */
	TXAppearancePropertyCollection *oldProperties = self.properties;

	BOOL changeAppearance = (oldProperties == nil ||
							 (oldProperties.appearanceType != appearanceType) ||
							 (oldProperties.appKitAppearanceTarget != appKitAppearanceTarget));

	if (changeAppearance == NO)
	{
		/* Even if the desired appearance hasn't changed, we still
		 signal views to perform selection update so that vibrant
		 views can draw correctly when the system changes. */

		if (systemChanged == NO) {
			return;
		}
	}
	else
	{
		/* When appearance changes as a result of a system change, then we
		 treat it as an application change as that's more specialized. */
		systemChanged = NO;
	}

	/* Assign new properties */
	TXAppearancePropertyCollection *newProperties = [TXAppearancePropertyCollection new];

	newProperties.appearanceName = [self.class appearanceNameForType:appearanceType];

	newProperties.appearanceType = appearanceType;

	newProperties.isDarkAppearance = isAppearanceDark;
	
	newProperties.appKitAppearanceTarget = appKitAppearanceTarget;

	self.properties = newProperties;

	/* Notify observers */
	if (systemChanged == NO) {
		[self notifyApplicationAppearanceChanged];
	} else {
		[self notifySystemAppearanceChanged];
	}
}

- (void)notifyApplicationAppearanceChanged
{
	[RZNotificationCenter() postNotificationName:TXApplicationAppearanceChangedNotification object:self];
}

- (void)notifySystemAppearanceChanged
{
	[RZNotificationCenter() postNotificationName:TXSystemAppearanceChangedNotification object:self];
}

@end

#pragma mark -
#pragma mark Property Collection

@implementation TXAppearancePropertyCollection

- (nullable NSAppearance *)appKitAppearance
{
	if (self.appKitAppearanceTarget == TXAppKitAppearanceTargetNone) {
		return nil;
	}

	if (self.isDarkAppearance) {
		return [self.class appKitDarkAppearance];
	} else {
		return [self.class appKitLightAppearance];
	}
}

- (NSString *)shortAppearanceDescription
{
	if (self.isDarkAppearance == NO) {
		return @"light";
	} else {
		return @"dark";
	}
}

+ (BOOL)systemWideDarkModeEnabled
{
	return ([[NSApp effectiveAppearance] bestMatchFromAppearancesWithNames:@[NSAppearanceNameDarkAqua]] != nil);
}

+ (nullable NSAppearance *)appKitDarkAppearance
{
	return [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
}

+ (nullable NSAppearance *)appKitLightAppearance
{
	return [NSAppearance appearanceNamed:NSAppearanceNameAqua];
}

@end

NS_ASSUME_NONNULL_END
