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
 position moves with it: that is not the user scrolling up */
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

/* scroller/state.js and scroller/automatic.js over a stand-in page: a view 500
 high, timers that run when runTimers() is called, user() for a scroll by the
 user and lineArrives() for a line added at the bottom */
- (JSContext *)automaticScrollerContext
{
	JSContext *context = [JSContext new];

	[context evaluateScript:@"function HTMLDocument() {} function Element() {} function Event(name) { this.name = name; }"
							"var timers = []; function setTimeout(f) { timers.push(f); return timers.length; } function clearTimeout(id) { timers[id - 1] = null; }"
							"function runTimers() { var pending = timers; timers = []; pending.forEach(function(f) { if (f) { f(); } }); }"
							"var view = new Element(); view.clientHeight = 500; view.scrollHeight = 2000; view._top = 1500;"
							"Object.defineProperty(view, 'scrollTop', { get: function() { return this._top; }, set: function(v) { this._top = Math.max(0, Math.min(v, this.scrollHeight - this.clientHeight)); } });"
							"var document = new HTMLDocument(); document.hidden = false; document.addEventListener = function() {}; document.dispatchEvent = function() {};"
							"var window = { addEventListener: function() {} };"];

	for (NSString *name in @[@"state", @"automatic"]) {
		NSString *path = [[TPCPathInfo applicationResources] stringByAppendingPathComponent:[NSString stringWithFormat:@"JavaScript/API/private/scroller/%@.js", name]];

		NSString *source = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];

		XCTAssertNotNil(source);

		/* automatic.js scrolls on load, so the view is there first */
		if ([name isEqualToString:@"automatic"]) {
			[context evaluateScript:@"_TextualScroller._scrolledElement = view;"];
		}

		[context evaluateScript:(source ?: @"")];
	}

	[context evaluateScript:@"function scrolled() { _TextualScroller._documentScrolledCallback(); }"
							"function user(top) { view.scrollTop = top; scrolled(); }"
							"function lineArrives() { document.prepareForMutation(); view.scrollHeight += 100; TextualScroller.performScroll(); }"
							"function atBottom() { return (view.scrollTop === view.scrollHeight - view.clientHeight); }"
							"scrolled();"];

	XCTAssertNil(context.exception);

	return context;
}

- (BOOL)evaluate:(NSString *)script inContext:(JSContext *)context
{
	JSValue *value = [context evaluateScript:script];

	XCTAssertNil(context.exception);

	return value.toBool;
}

/* At the bottom, new lines are followed */
- (void)testFollowsNewLinesAtTheBottom
{
	JSContext *context = [self automaticScrollerContext];

	XCTAssertTrue([self evaluate:@"lineArrives(); runTimers(); scrolled(); lineArrives(); runTimers(); atBottom()" inContext:context]);
}

/* Scrolling up while lines and previews keep arriving keeps the view where the
 user put it: a scroll planned just before is dropped */
- (void)testScrollingUpCancelsAPlannedScroll
{
	JSContext *context = [self automaticScrollerContext];

	XCTAssertTrue([self evaluate:@"lineArrives(); user(800); runTimers(); view.scrollTop === 800" inContext:context]);

	XCTAssertTrue([self evaluate:@"lineArrives(); runTimers(); view.scrollTop === 800" inContext:context]);
}

/* A plan whose change never came doesn't pull the view down later; back at the
 bottom, following resumes */
- (void)testStalePlanDoesNotPullTheViewDown
{
	JSContext *context = [self automaticScrollerContext];

	XCTAssertTrue([self evaluate:@"document.prepareForMutation(); user(700); lineArrives(); runTimers(); view.scrollTop === 700" inContext:context]);

	XCTAssertTrue([self evaluate:@"user(view.scrollHeight - view.clientHeight); lineArrives(); runTimers(); atBottom()" inContext:context]);
}

@end

NS_ASSUME_NONNULL_END
