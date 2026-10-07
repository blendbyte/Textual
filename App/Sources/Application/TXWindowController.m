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

#import "TXMasterController.h"
#import "TVCMainWindow.h"
#import "TXWindowControllerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TXWindowController ()
@property (nonatomic, strong) NSMutableDictionary *windowObjects;
@end

@implementation TXWindowController

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
	self.windowObjects = [NSMutableDictionary dictionary];
}

- (void)prepareForApplicationTermination
{
	LogToConsoleTerminationProgress("Preparing window controller");

	@synchronized(self.windowObjects) {
		[self.windowObjects removeAllObjects];
		 self.windowObjects = nil;
	}
}

+ (NSString *)windowDescriptionForWindow:(id)window
{
	return [self windowDescriptionForWindow:window inRelationTo:nil];
}

+ (NSString *)windowDescriptionForWindow:(id)window inRelationTo:(nullable id)relatedObject
{
	NSParameterAssert(window != nil);

	NSString *windowClass = NSStringFromClass([window class]);

	if (relatedObject == nil) {
		return windowClass;
	}

	return [NSString stringWithFormat:@"%@ -> %@", windowClass, [relatedObject description]];
}

- (void)addWindowToWindowList:(id)window
{
	[self addWindowToWindowList:window inRelationTo:nil];
}

- (void)addWindowToWindowList:(id)window inRelationTo:(nullable id)relatedObject
{
	NSString *windowDescription = [self.class windowDescriptionForWindow:window inRelationTo:relatedObject];

	[self addWindowToWindowList:window withDescription:windowDescription];
}

- (void)addWindowToWindowList:(id)window withDescription:(NSString *)windowDescription
{
	NSParameterAssert(window != nil);

	NSAssert([window respondsToSelector:@selector(window)],
		@"'window' does not respond to -window");

	@synchronized(self.windowObjects) {
		self.windowObjects[windowDescription] = window;
	}
}

- (void)removeWindowFromWindowList:(id)window
{
	[self removeWindowFromWindowList:window inRelationTo:nil];
}

- (void)removeWindowFromWindowList:(id)window inRelationTo:(nullable id)relatedObject
{
	NSParameterAssert(window != nil);

	if ([window isKindOfClass:[NSArray class]]) {
		for (id object in window) {
			[self removeWindowFromWindowList:object inRelationTo:relatedObject];
		}

		return; // Do not continue...
	}

	BOOL windowWasString = NO;

	NSString *windowDescription = nil;

	if ([window isKindOfClass:[NSString class]]) {
		windowWasString = YES;

		windowDescription = window;
	} else {
		windowDescription = [self.class windowDescriptionForWindow:window inRelationTo:relatedObject];
	}

	if (windowDescription == nil) {
		return; // Cannot continue...
	}

	@synchronized(self.windowObjects) {
		if (self.windowObjects[windowDescription] == nil && windowWasString == NO) {
			windowDescription = [self.windowObjects firstKeyForObject:window];
		}

		if (windowDescription) {
			[self.windowObjects removeObjectForKey:windowDescription];
		}
	}
}

- (nullable id)windowFromWindowList:(NSString *)windowDescription
{
	NSParameterAssert(windowDescription != nil);

	@synchronized(self.windowObjects) {
		return self.windowObjects[windowDescription];
	}
}

- (NSArray *)windowsFromWindowList:(NSArray<NSString *> *)windowDescriptions
{
	NSParameterAssert(windowDescriptions != nil);

	@synchronized(self.windowObjects) {
		NSMutableArray *returnedValues = [NSMutableArray array];

		for (id windowDescription in windowDescriptions) {
			if ([windowDescription isKindOfClass:[NSString class]] == NO) {
				continue;
			}

			id windowObject = self.windowObjects[windowDescription];

			if (windowObject) {
				[returnedValues addObject:windowObject];
			}
		}

		return [returnedValues copy];
	}
}

- (BOOL)maybeBringWindowForward:(NSString *)windowDescription
{
	NSParameterAssert(windowDescription != nil);

	id windowObject = [self windowFromWindowList:windowDescription];

	if (windowObject) {
		NSWindow *window = [windowObject window];

		[window makeKeyAndOrderFront:nil];

		return YES;
	}

	return NO;
}

- (void)popMainWindowSheetIfExists
{
	NSWindow *attachedSheet = mainWindow().attachedSheet;

	if (attachedSheet == nil) {
		return;
	}

	[attachedSheet close];
}

@end

NS_ASSUME_NONNULL_END
