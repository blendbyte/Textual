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

#import "TDCAlert.h"
#import "TLOLocalization.h"
#import "TPCApplicationInfo.h"
#import "TXApplicationPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TXApplication

+ (BOOL)checkForOtherCopiesOfTextualRunning
{
	pid_t ourProcessIdentifier = [[NSProcessInfo processInfo] processIdentifier];

	for (NSRunningApplication *application in RZWorkspace().runningApplications) {
		if ([application.bundleIdentifier isEqualToString:@"com.textualapp.app"] ||
			[application.bundleIdentifier isEqualToString:@"com.codeux.apps.textual"] ||
			[application.bundleIdentifier isEqualToString:@"com.codeux.apps.textual-mas"] ||
			[application.bundleIdentifier isEqualToString:@"com.codeux.irc.textual5"])
		{
			if (application.processIdentifier == ourProcessIdentifier) {
				continue;
			}

			BOOL continueLaunch = [TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[kx4-q8]")
															title:TXTLS(@"Prompts[hcb-3i]")
													defaultButton:TXTLS(@"Prompts[mvh-ms]")
												  alternateButton:TXTLS(@"Prompts[99q-gg]")];

			return continueLaunch;
		}
	}

	return YES;
}

- (void)sendEvent:(NSEvent *)event
{
	BOOL performedCustomEvent = [self performedCustomKeyboardEvent:event];

	if (performedCustomEvent) {
		return;
	}

	[super sendEvent:event];
}

- (BOOL)performedCustomKeyboardEvent:(NSEvent *)event
{
	if (event.type != NSEventTypeKeyDown) {
		return NO;
	}

	NSWindow *keyWindow = self.keyWindow;

	if ([self sendCustomKeyboardEvent:event toObject:keyWindow]) {
		return YES;
	}

	NSResponder *firstResponder = keyWindow.firstResponder;

	if ([self sendCustomKeyboardEvent:event toObject:firstResponder]) {
		return YES;
	}

	return NO;
}

- (BOOL)sendCustomKeyboardEvent:(NSEvent *)event toObject:(nullable id)object
{
	if (object == nil) {
		return NO;
	}

	if ([object respondsToSelector:@selector(performedCustomKeyboardEvent:)]) {
		if ([(id)object performedCustomKeyboardEvent:event]) {
			return YES;
		}
	}

	return NO;
}

@end

NS_ASSUME_NONNULL_END
