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

@interface TVCLogScrollerTests : XCTestCase
@end

@implementation TVCLogScrollerTests

/* The chat view's scroller (scroller/state.js) with a stand-in for the scrolled
 element: only the user's own scrolling may stop it following new lines */
- (JSContext *)scrollerContext
{
	NSString *path = [[TPCPathInfo applicationResources] stringByAppendingPathComponent:@"JavaScript/API/private/scroller/state.js"];

	NSString *source = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];

	XCTAssertNotNil(source);

	JSContext *context = [JSContext new];

	[context evaluateScript:@"var Element = function() {}; var Node = { ELEMENT_NODE: 1 }; var Event = function(type) { this.type = type; };"
							"var document = { hidden: false, body: null, dispatchEvent: function() {} };"
							"var window = { addEventListener: function() {}, removeEventListener: function() {} };"];

	[context evaluateScript:(source ?: @"")];

	[context evaluateScript:@"var view = { clientHeight: 400, scrollHeight: 2000, scrollTop: 1600 };"
							"view.scrollToBottom = function() { this.scrollTop = (this.scrollHeight - this.clientHeight); };"
							"_TextualScroller._scrolledElement = view;"
							"function scrolled(clientHeight, scrollTop) { view.clientHeight = clientHeight; view.scrollTop = scrollTop; _TextualScroller._documentScrolledCallback(); return TextualScroller.userScrolled; }"];

	XCTAssertNil(context.exception);

	return context;
}

/* macOS 27 shrinks a hidden view (to zero or another height) and the scroll
 position moves with it: that is not the user scrolling up (7.1) */
- (void)testLayoutChangesAreNotUserScrolling
{
	JSContext *context = [self scrollerContext];

	XCTAssertFalse([[context evaluateScript:@"scrolled(400, 1600)"] toBool]); // at the bottom

	XCTAssertFalse([[context evaluateScript:@"scrolled(0, 1600)"] toBool]); // hidden: no height

	/* Shown again with another height, above the bottom: still following, and back at the bottom */
	XCTAssertFalse([[context evaluateScript:@"scrolled(424, 1500)"] toBool]);
	XCTAssertEqual([[context evaluateScript:@"view.scrollTop"] toInt32], 1576);

	/* The user scrolls up: that counts, and a later layout change keeps the position */
	XCTAssertTrue([[context evaluateScript:@"scrolled(424, 1000)"] toBool]);
	XCTAssertTrue([[context evaluateScript:@"scrolled(400, 1000)"] toBool]);
	XCTAssertEqual([[context evaluateScript:@"view.scrollTop"] toInt32], 1000);

	XCTAssertNil(context.exception);
}

@end

NS_ASSUME_NONNULL_END
