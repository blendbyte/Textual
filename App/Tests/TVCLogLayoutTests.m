/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\__|\__,_|\__,_|_|
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

#import <XCTest/XCTest.h>
#import <JavaScriptCore/JavaScriptCore.h>

#import "TPCPathInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCLogLayoutTests : XCTestCase
@end

@implementation TVCLogLayoutTests

/* The chat view's load events (core/events.js) with a window whose animation
 frames and timers only run when the test says so */
- (JSContext *)eventsContext
{
	NSString *path = [[TPCPathInfo applicationResources] stringByAppendingPathComponent:@"JavaScript/API/private/core/events.js"];

	NSString *source = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];

	XCTAssertNotNil(source);

	JSContext *context = [JSContext new];

	[context evaluateScript:@"var layoutsFinished = 0, frames = [], timers = [];"
							"var Textual = { viewBodyDidLoad: function() {}, viewFinishedLoading: function() {}, viewFinishedReload: function() {}, changeTextSizeMultiplier: function() {}, clearSelection: function() {} };"
							"var _Textual = {};"
							"var TextualScroller = { isScrolledToBottom: function() { return true; }, scrollToBottom: function() {} };"
							"var _TextualScroller = { bindToBestElement: function() {}, createMutationObserver: function() {} };"
							"var appPrivate = { finishedLayingOutView: function() { layoutsFinished += 1; } };"
							"var document = { body: { dataset: {} }, addEventListener: function() {} };"
							"var window = {"
							"  requestAnimationFrame: function(f) { frames.push(f); return frames.length; },"
							"  cancelAnimationFrame: function(i) { frames[i - 1] = null; },"
							"  setTimeout: function(f) { timers.push(f); return timers.length; },"
							"  clearTimeout: function(i) { timers[i - 1] = null; }"
							"};"
							"function run(list) { list.forEach(function(f) { if (f) { f(); } }); }"
							"function finishedLoading(visible) { _Textual.viewFinishedLoading({ selected: visible, visible: visible, reloadingTheme: false, textSizeMultiplier: 1, scrollbackLimit: 0 }); }"];

	[context evaluateScript:(source ?: @"")];

	XCTAssertNil(context.exception);

	return context;
}

/* WebKit gives a view in a window that isn't visible no animation frames;
 the overlay waiting for layout then stayed up and the view was blank (8.3) */
- (void)testLayoutFinishesWithoutAnimationFrames
{
	JSContext *context = [self eventsContext];

	[context evaluateScript:@"_Textual.viewBodyDidLoad()"];

	XCTAssertEqual([[context evaluateScript:@"layoutsFinished"] toInt32], 0);

	[context evaluateScript:@"run(timers)"];

	XCTAssertEqual([[context evaluateScript:@"layoutsFinished"] toInt32], 1);

	/* The frame arriving late, and the app saying the document loaded, change nothing */
	[context evaluateScript:@"run(frames); finishedLoading(true)"];

	XCTAssertEqual([[context evaluateScript:@"layoutsFinished"] toInt32], 1);

	XCTAssertNil(context.exception);
}

/* Neither frames nor timers: the app saying the document loaded finishes
 layout, for the view on screen too */
- (void)testDocumentLoadFinishesLayoutOfVisibleView
{
	JSContext *context = [self eventsContext];

	[context evaluateScript:@"_Textual.viewBodyDidLoad(); finishedLoading(true)"];

	XCTAssertEqual([[context evaluateScript:@"layoutsFinished"] toInt32], 1);

	[context evaluateScript:@"run(frames); run(timers)"];

	XCTAssertEqual([[context evaluateScript:@"layoutsFinished"] toInt32], 1);

	XCTAssertNil(context.exception);
}

@end

NS_ASSUME_NONNULL_END
