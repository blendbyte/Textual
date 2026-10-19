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

@interface TVCLogEventGroupTests : XCTestCase
@end

@implementation TVCLogEventGroupTests

/* core/eventGroups.js over a small stand-in for the message buffer: shape()
 lists its children, "[summary]" for a summary line and "-" after a hidden line */
- (JSContext *)eventGroupsContext
{
	NSString *path = [[TPCPathInfo applicationResources] stringByAppendingPathComponent:@"JavaScript/API/private/core/eventGroups.js"];

	NSString *source = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];

	XCTAssertNotNil(source);

	JSContext *context = [JSContext new];

	[context evaluateScript:@"function El(tag) {"
							"  var self = this; this.tagName = tag; this.id = ''; this.className = ''; this.attrs = {}; this.children = []; this.parentNode = null; this.style = { display: '' }; this.textContent = '';"
							"  this.classList = { contains: function(name) { return (' ' + self.className + ' ').indexOf(' ' + name + ' ') >= 0; } };"
							"}"
							"El.prototype.getAttribute = function(name) { return (name in this.attrs) ? this.attrs[name] : null; };"
							"El.prototype.setAttribute = function(name, value) { this.attrs[name] = String(value); };"
							"El.prototype.index = function() { return (this.parentNode) ? this.parentNode.children.indexOf(this) : -1; };"
							"Object.defineProperty(El.prototype, 'previousElementSibling', { get: function() { var i = this.index(); return (i > 0) ? this.parentNode.children[i - 1] : null; } });"
							"Object.defineProperty(El.prototype, 'nextElementSibling', { get: function() { var i = this.index(); return (i >= 0 && i < this.parentNode.children.length - 1) ? this.parentNode.children[i + 1] : null; } });"
							"Object.defineProperty(El.prototype, 'firstElementChild', { get: function() { return this.children[0] || null; } });"
							"El.prototype.remove = function() { if (this.parentNode) { this.parentNode.children.splice(this.index(), 1); this.parentNode = null; } };"
							"El.prototype.appendChild = function(child) { child.remove(); child.parentNode = this; this.children.push(child); return child; };"
							"El.prototype.insertBefore = function(child, before) { child.remove(); child.parentNode = this; this.children.splice(this.children.indexOf(before), 0, child); return child; };"
							"El.prototype.replaceChildren = function() { var self = this; this.children = []; Array.prototype.forEach.call(arguments, function(child) { self.appendChild(child); }); };"
							"El.prototype.querySelector = function() { return null; };"
							"El.prototype.addEventListener = function() {};"
							"var buffer = new El('div');"
							"var document = {"
							"  createElement: function(tag) { return new El(tag); },"
							"  createTextNode: function(text) { var node = new El('#text'); node.textContent = text; return node; },"
							"  getElementByLineNumber: function(number) { return buffer.children.filter(function(e) { return e.id === 'line-' + number; })[0] || null; },"
							"  prepareForMutation: function() {}"
							"};"
							"var MessageBuffer = { bufferElement: function() { return buffer; } };"
							"function line(number, type, nickname, newNickname) {"
							"  var e = new El('div'); e.id = 'line-' + number; e.className = 'line'; e.setAttribute('data-line-type', type);"
							"  if (nickname) { e.setAttribute('data-event-nickname', nickname); }"
							"  if (newNickname) { e.setAttribute('data-event-new-nickname', newNickname); }"
							"  return buffer.appendChild(e);"
							"}"
							"function other(className) { var e = new El('div'); e.className = className; return buffer.appendChild(e); }"
							"function shape() {"
							"  return buffer.children.map(function(e) {"
							"    if (e.classList.contains('eventGroupSummary')) { return '[' + e.getAttribute('data-summary') + ']'; }"
							"    return (e.id) ? (e.id.substring(5) + ((e.style.display === 'none') ? '-' : '')) : e.className;"
							"  }).join(' ');"
							"}"
							"function summaryAbove(number) { return document.getElementByLineNumber(number).previousElementSibling; }"];

	[context evaluateScript:(source ?: @"")];

	[context evaluateScript:@"_EventGroups.configure(true, { joined: '%@ joined', left: '%@ left', quit: '%@ quit', nickname: '%@ changed nickname', separator: ', ',"
							"  nicknameChange: '%1$@ is now %2$@', listPair: '%1$@ and %2$@', listMore: '%1$@, %2$@' });"];

	XCTAssertNil(context.exception);

	return context;
}

- (NSString *)shapeInContext:(JSContext *)context afterScript:(NSString *)script
{
	[context evaluateScript:script];

	XCTAssertNil(context.exception);

	return [context evaluateScript:@"shape()"].toString;
}

/* Two or more joins, parts, quits or nickname changes in a row share one
 summary line; a single one, kicks and anything between them stay as they are */
- (void)testRunsOfEventsAreCollapsed
{
	JSContext *context = [self eventGroupsContext];

	XCTAssertEqualObjects([self shapeInContext:context afterScript:
						   @"line(1, 'privmsg'); line(2, 'join'); line(3, 'join'); line(4, 'quit'); line(5, 'privmsg');"
							"line(6, 'part'); other('date_indicator'); line(7, 'nick'); line(8, 'nick'); line(9, 'kick');"
							"_EventGroups.regroupAll();"],
						  @"1 [2 joined, 1 quit] 2- 3- 4- 5 6 date_indicator [2 changed nickname] 7- 8- 9");

	/* New lines at the bottom: alone first, then a group */
	XCTAssertEqualObjects([self shapeInContext:context afterScript:@"line(10, 'join'); _EventGroups.linesAdded(['10'], false);"],
						  @"1 [2 joined, 1 quit] 2- 3- 4- 5 6 date_indicator [2 changed nickname] 7- 8- 9 10");

	XCTAssertEqualObjects([self shapeInContext:context afterScript:@"line(11, 'part'); _EventGroups.linesAdded(['11'], false);"],
						  @"1 [2 joined, 1 quit] 2- 3- 4- 5 6 date_indicator [2 changed nickname] 7- 8- 9 [1 joined, 1 left] 10- 11-");
}

/* A kind hidden in Preferences counts nowhere and doesn't split a run (the
 view's stylesheet hides it); away and back changes collapse too; a summary is
 dimmed only when all of its lines are */
- (void)testHiddenKindsArePassedOver
{
	JSContext *context = [self eventGroupsContext];

	[context evaluateScript:@"_EventGroups.configure(true, { joined: '%@ joined', left: '%@ left', quit: '%@ quit', nickname: '%@ changed nickname', away: '%@ went away', back: '%@ came back',"
							"  separator: ', ', nicknameChange: '%1$@ is now %2$@', listPair: '%1$@ and %2$@', listMore: '%1$@, %2$@' },"
							"  { quit: 'hide', mode: 'hide', join: 'dim', part: 'dim' });"];

	XCTAssertEqualObjects([self shapeInContext:context afterScript:
						   @"line(1, 'join', 'alice'); line(2, 'quit', 'bob'); line(3, 'mode'); line(4, 'away', 'carol'); other('message');"
							"line(5, 'join', 'dave'); line(6, 'quit', 'erin'); other('message');"
							"line(7, 'join', 'gina'); line(8, 'part', 'hank'); other('message');"
							"line(9, 'back', 'carol'); line(10, 'back', 'ivan');"
							"_EventGroups.regroupAll();"],
						  @"[alice joined, carol went away] 1- 2 3 4- message "
						   "5 6 message "
						   "[gina joined, hank left] 7- 8- message "
						   "[carol and ivan came back] 9- 10-");

	XCTAssertEqualObjects([context evaluateScript:@"summaryAbove(1).getAttribute('data-dimmed')"].toString, @"false");
	XCTAssertEqualObjects([context evaluateScript:@"summaryAbove(7).getAttribute('data-dimmed')"].toString, @"true");

	XCTAssertNil(context.exception);
}

/* Up to three events name the people; more, or lines saved without names, count them */
- (void)testSmallGroupsNameThePeople
{
	JSContext *context = [self eventGroupsContext];

	XCTAssertEqualObjects([self shapeInContext:context afterScript:
						   @"line(1, 'join', 'alice'); line(2, 'join', 'bob'); line(3, 'nick', 'carol', 'carl'); other('message');"
							"line(4, 'join', 'dave'); line(5, 'join', 'erin'); line(6, 'join', 'frank'); line(7, 'quit', 'gina'); other('message');"
							"line(8, 'part', 'hank'); line(9, 'part', 'ivan'); line(10, 'part', 'jane'); other('message');"
							"line(11, 'quit', 'kyle'); line(12, 'quit');"
							"_EventGroups.regroupAll();"],
						  @"[alice and bob joined, carol is now carl] 1- 2- 3- message "
						   "[3 joined, 1 quit] 4- 5- 6- 7- message "
						   "[hank, ivan and jane left] 8- 9- 10- message "
						   "[2 quit] 11- 12-");
}

/* An opened group stays open when the view regroups; jumping to a hidden line
 opens its group; a run cut down to one line by trimming loses its summary */
- (void)testGroupsOpenAndSurviveTrimming
{
	JSContext *context = [self eventGroupsContext];

	[context evaluateScript:@"line(1, 'privmsg'); line(2, 'join'); line(3, 'join'); line(4, 'quit'); line(5, 'privmsg'); line(6, 'nick'); line(7, 'nick'); _EventGroups.regroupAll();"];

	XCTAssertEqualObjects([self shapeInContext:context afterScript:@"_EventGroups._summaryClicked({ currentTarget: summaryAbove(2) }); _EventGroups.regroupAll();"],
						  @"1 [2 joined, 1 quit] 2 3 4 5 [2 changed nickname] 6- 7-");

	XCTAssertEqualObjects([self shapeInContext:context afterScript:@"_EventGroups.revealElement(document.getElementByLineNumber('7'));"],
						  @"1 [2 joined, 1 quit] 2 3 4 5 [2 changed nickname] 6 7");

	/* Trimming from the top removes the first lines and the summary it passes */
	XCTAssertEqualObjects([self shapeInContext:context afterScript:
						   @"_EventGroups._summaryClicked({ currentTarget: summaryAbove(2) });"
							"['1', '2', '3'].forEach(function(n) { document.getElementByLineNumber(n).remove(); });"
							"buffer.children[0].remove();"
							"_EventGroups.linesRemoved();"],
						  @"4 5 [2 changed nickname] 6 7");
}

@end

NS_ASSUME_NONNULL_END
