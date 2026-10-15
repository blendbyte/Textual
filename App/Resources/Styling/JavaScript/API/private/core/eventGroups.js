/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
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

"use strict";

/* Collapsed join, part, quit, nickname and away change runs: two or more such
 lines in a row get a summary line above them ("▸ 3 joined, 1 quit") that shows
 or hides them on a click. The lines themselves stay where they are, so styles,
 trimming and line lookups see them as before; only the summary is added
 (a div.line without an id, data-line-type="event-group").

 Each kind of event is also shown, dimmed or hidden (Preferences → Style →
 Events): a stylesheet added here does that by line type, so it works with every
 style, and a hidden line is passed over by the runs as if it weren't there. */

var _EventGroups = {};

_EventGroups.enabled = false; /* PRIVATE */

/* From the app: joined, left, quit, nickname ("%@" is the count or the names),
 separator, nicknameChange, listPair, listMore ("%1$@" and "%2$@") */
_EventGroups.strings = null; /* PRIVATE */

/* Line type → "show", "dim" or "hide" (missing: show) */
_EventGroups.display = {}; /* PRIVATE */

_EventGroups._collapsibleLineTypes = ["join", "part", "quit", "nick", "away", "back"]; /* PRIVATE */

_EventGroups._summaryStringKeys = { /* PRIVATE */
	"join" : "joined",
	"part" : "left",
	"quit" : "quit",
	"nick" : "nickname",
	"away" : "away",
	"back" : "back"
};

_EventGroups.configure = function(enabled, strings, display) /* PRIVATE */
{
	_EventGroups.enabled = ((enabled) ? true : false); // the app may send 1

	_EventGroups.strings = strings;

	_EventGroups.display = (display || {});

	_EventGroups._applyDisplay();

	/* Lines added before the view finished loading */
	if (_EventGroups.enabled) {
		_EventGroups.regroupAll();
	}
};

/* ************************************************** */
/*                Shown, dimmed, hidden               */
/* ************************************************** */

_EventGroups._applyDisplay = function() /* PRIVATE */
{
	if (!document.head) {
		return;
	}

	var rules = [];

	for (var lineType in _EventGroups.display) {
		var selector = "div.line[id][data-line-type=\"" + lineType + "\"]";

		if (_EventGroups.display[lineType] === "hide") {
			rules.push(selector + " { display: none !important; }");
		} else if (_EventGroups.display[lineType] === "dim") {
			rules.push(":where(" + selector + ") { opacity: 0.5; }");
		}
	}

	rules.push(":where(div.line.eventGroupSummary[data-dimmed=\"true\"]) { opacity: 0.5; }");

	var style = document.getElementById("eventDisplayRules");

	if (!style) {
		style = document.createElement("style");

		style.id = "eventDisplayRules";

		document.head.appendChild(style);
	}

	style.textContent = rules.join("\n");
};

/* ************************************************** */
/*                     Elements                       */
/* ************************************************** */

_EventGroups._isLine = function(element) /* PRIVATE */
{
	return Boolean(element && element.id && element.id.indexOf("line-") === 0);
};

/* Hidden by its kind: not part of any count, and no gap in a run either */
_EventGroups.isHiddenLine = function(element) /* PRIVATE */
{
	return (_EventGroups._isLine(element) && _EventGroups.display[element.getAttribute("data-line-type")] === "hide");
};

_EventGroups.isCollapsibleLine = function(element) /* PRIVATE */
{
	if (_EventGroups._isLine(element) === false || _EventGroups.isHiddenLine(element)) {
		return false;
	}

	return (_EventGroups._collapsibleLineTypes.indexOf(element.getAttribute("data-line-type")) >= 0);
};

_EventGroups.isSummary = function(element) /* PRIVATE */
{
	return (element && element.classList && element.classList.contains("eventGroupSummary"));
};

_EventGroups._isPartOfRun = function(element) /* PRIVATE */
{
	return (_EventGroups.isCollapsibleLine(element) || _EventGroups.isSummary(element) || _EventGroups.isHiddenLine(element));
};

/* The summary above a line it hides, if any */
_EventGroups._summaryOfLine = function(line) /* PRIVATE */
{
	var element = line.previousElementSibling;

	while (element) {
		if (_EventGroups.isSummary(element)) {
			return element;
		}

		if (_EventGroups.isCollapsibleLine(element) === false && _EventGroups.isHiddenLine(element) === false) {
			return null;
		}

		element = element.previousElementSibling;
	}

	return null;
};

_EventGroups._linesOfSummary = function(summary) /* PRIVATE */
{
	var lines = [];

	var element = summary.nextElementSibling;

	while (_EventGroups.isCollapsibleLine(element) || _EventGroups.isHiddenLine(element)) {
		if (_EventGroups.isCollapsibleLine(element)) {
			lines.push(element);
		}

		element = element.nextElementSibling;
	}

	return lines;
};

/* ************************************************** */
/*                     Grouping                       */
/* ************************************************** */

/* Runs as they are now: collapsible lines and the summaries among them */
_EventGroups.regroupAll = function() /* PRIVATE */
{
	if (_EventGroups.enabled === false) {
		return;
	}

	var element = MessageBuffer.bufferElement().firstElementChild;

	while (element) {
		if (_EventGroups._isPartOfRun(element)) {
			element = _EventGroups._regroupRunStartingAt(element);
		} else {
			element = element.nextElementSibling;
		}
	}
};

/* A line just added at the bottom joins the run above it */
_EventGroups.regroupAroundLine = function(line) /* PRIVATE */
{
	if (_EventGroups.enabled === false || _EventGroups._isPartOfRun(line) === false) {
		return;
	}

	var first = line;

	while (_EventGroups._isPartOfRun(first.previousElementSibling)) {
		first = first.previousElementSibling;
	}

	_EventGroups._regroupRunStartingAt(first);
};

/* Returns the element after the run */
_EventGroups._regroupRunStartingAt = function(first) /* PRIVATE */
{
	var lines = [];
	var summaries = [];

	var element = first;

	while (_EventGroups._isPartOfRun(element)) {
		if (_EventGroups.isSummary(element)) {
			summaries.push(element);
		} else if (_EventGroups.isCollapsibleLine(element)) {
			lines.push(element);
		}

		element = element.nextElementSibling;
	}

	_EventGroups._applyRun(lines, summaries);

	return element;
};

_EventGroups._applyRun = function(lines, summaries) /* PRIVATE */
{
	/* An open group stays open when it grows or two groups meet */
	var expanded = false;

	for (var i = 0; i < summaries.length; i++) {
		if (summaries[i].getAttribute("data-expanded") === "true") {
			expanded = true;
		}
	}

	/* One summary is kept (and moved above the run), the rest go */
	var summary = null;

	if (lines.length >= 2 && summaries.length > 0) {
		summary = summaries.shift();
	}

	for (var i = 0; i < summaries.length; i++) {
		summaries[i].remove();
	}

	if (lines.length < 2) {
		for (var i = 0; i < lines.length; i++) {
			_EventGroups._setLineHidden(lines[i], false);
		}

		return;
	}

	if (summary === null) {
		summary = _EventGroups._createSummary();
	}

	if (summary.nextElementSibling !== lines[0]) {
		lines[0].parentNode.insertBefore(summary, lines[0]);
	}

	_EventGroups._updateSummary(summary, lines);

	_EventGroups._setExpanded(summary, lines, expanded);
};

/* ************************************************** */
/*                     Summary                        */
/* ************************************************** */

/* "%@", "%1$@" and "%2$@" filled in */
_EventGroups._format = function(format, values) /* PRIVATE */
{
	return format.replace(/%([12])\$@/g, function(match, position) {
		return values[position - 1];
	}).replace("%@", function() {
		return values[0];
	});
};

/* "alice", "alice and bob", "alice, bob and carol" */
_EventGroups._listOfNames = function(names, strings) /* PRIVATE */
{
	var list = names[0];

	for (var i = 1; i < names.length; i++) {
		var format = ((i === (names.length - 1)) ? strings.listPair : strings.listMore);

		list = _EventGroups._format(format, [list, names[i]]);
	}

	return list;
};

/* Up to three events, all with their nicknames (lines saved before Textual
 kept them have none): "alice and bob joined, carol is now carl" */
_EventGroups._summaryTextWithNames = function(lines, strings) /* PRIVATE */
{
	if (lines.length > 3 || !strings.nicknameChange || !strings.listPair || !strings.listMore) {
		return null;
	}

	var names = {};
	var nicknameChanges = [];

	for (var i = 0; i < lines.length; i++) {
		var lineType = lines[i].getAttribute("data-line-type");

		var nickname = lines[i].getAttribute("data-event-nickname");

		if (!nickname) {
			return null;
		}

		if (lineType === "nick") {
			var newNickname = lines[i].getAttribute("data-event-new-nickname");

			if (!newNickname) {
				return null;
			}

			nicknameChanges.push(_EventGroups._format(strings.nicknameChange, [nickname, newNickname]));

			continue;
		}

		names[lineType] = (names[lineType] || []);

		if (names[lineType].indexOf(nickname) < 0) {
			names[lineType].push(nickname);
		}
	}

	var parts = [];

	for (var i = 0; i < _EventGroups._collapsibleLineTypes.length; i++) {
		var lineType = _EventGroups._collapsibleLineTypes[i];

		if (names[lineType]) {
			var format = strings[_EventGroups._summaryStringKeys[lineType]];

			parts.push(_EventGroups._format(format, [_EventGroups._listOfNames(names[lineType], strings)]));
		}
	}

	return parts.concat(nicknameChanges).join(strings.separator);
};

_EventGroups.summaryText = function(lines, strings) /* PRIVATE */
{
	var textWithNames = _EventGroups._summaryTextWithNames(lines, strings);

	if (textWithNames !== null) {
		return textWithNames;
	}

	var counts = {};

	for (var i = 0; i < lines.length; i++) {
		var lineType = lines[i].getAttribute("data-line-type");

		counts[lineType] = ((counts[lineType] || 0) + 1);
	}

	var parts = [];

	for (var i = 0; i < _EventGroups._collapsibleLineTypes.length; i++) {
		var lineType = _EventGroups._collapsibleLineTypes[i];

		if (counts[lineType]) {
			var format = strings[_EventGroups._summaryStringKeys[lineType]];

			parts.push(_EventGroups._format(format, [counts[lineType]]));
		}
	}

	return parts.join(strings.separator);
};

_EventGroups._createSummary = function() /* PRIVATE */
{
	var summary = document.createElement("div");

	summary.className = "line event eventGroupSummary";

	summary.setAttribute("data-line-type", "event-group");
	summary.setAttribute("data-expanded", "false");
	summary.setAttribute("role", "button");
	summary.setAttribute("aria-expanded", "false");

	summary.addEventListener("click", _EventGroups._summaryClicked);

	return summary;
};

/* The counts (no time: the opening arrow comes first) */
_EventGroups._updateSummary = function(summary, lines) /* PRIVATE */
{
	var text = _EventGroups.summaryText(lines, _EventGroups.strings);

	var firstLineId = lines[0].id;

	if (summary.getAttribute("data-first-line") === firstLineId &&
		summary.getAttribute("data-summary") === text)
	{
		return;
	}

	summary.setAttribute("data-first-line", firstLineId);
	summary.setAttribute("data-summary", text);

	/* Dimmed with its lines when they all are */
	var dimmed = lines.every(function(line) {
		return (_EventGroups.display[line.getAttribute("data-line-type")] === "dim");
	});

	summary.setAttribute("data-dimmed", ((dimmed) ? "true" : "false"));

	var paragraph = document.createElement("p");

	var message = document.createElement("span");

	message.className = "message";

	message.textContent = text;

	paragraph.appendChild(message);

	summary.replaceChildren(paragraph);
};

_EventGroups._setLineHidden = function(line, hidden) /* PRIVATE */
{
	/* Only real changes: a style change is a mutation the scroller follows */
	var display = ((hidden) ? "none" : "");

	if (line.style.display !== display) {
		line.style.display = display;
	}
};

_EventGroups._setExpanded = function(summary, lines, expanded) /* PRIVATE */
{
	summary.setAttribute("data-expanded", ((expanded) ? "true" : "false"));
	summary.setAttribute("aria-expanded", ((expanded) ? "true" : "false"));

	for (var i = 0; i < lines.length; i++) {
		_EventGroups._setLineHidden(lines[i], (expanded === false));
	}
};

_EventGroups._summaryClicked = function(event) /* PRIVATE */
{
	var summary = event.currentTarget;

	/* Opening the group at the bottom keeps the view at the bottom */
	document.prepareForMutation();

	_EventGroups._setExpanded(summary, _EventGroups._linesOfSummary(summary), (summary.getAttribute("data-expanded") !== "true"));
};

/* ************************************************** */
/*                  Showing a line                    */
/* ************************************************** */

/* Before jumping to a line (search, unread marker, jump to line), its group opens */
_EventGroups.revealElement = function(element) /* PRIVATE */
{
	if (_EventGroups.isCollapsibleLine(element) === false || element.style.display !== "none") {
		return;
	}

	var summary = _EventGroups._summaryOfLine(element);

	if (summary) {
		_EventGroups._setExpanded(summary, _EventGroups._linesOfSummary(summary), true);
	}
};

/* What to scroll to for a line: its summary while the group is closed */
_EventGroups.visibleElementForLine = function(line) /* PRIVATE */
{
	if (_EventGroups.isCollapsibleLine(line) === false || line.style.display !== "none") {
		return line;
	}

	var summary = _EventGroups._summaryOfLine(line);

	return ((summary) ? summary : line);
};

/* ************************************************** */
/*                   Notifications                    */
/* ************************************************** */

_EventGroups.linesAdded = function(lineNumbers, fromBuffer) /* PRIVATE */
{
	if (_EventGroups.enabled === false) {
		return;
	}

	/* One new line at the bottom: only its run changes */
	if (fromBuffer === false && Array.isArray(lineNumbers) && lineNumbers.length === 1) {
		var line = document.getElementByLineNumber(lineNumbers[0]);

		if (line) {
			_EventGroups.regroupAroundLine(line);
		}

		return;
	}

	_EventGroups.regroupAll();
};

_EventGroups.linesRemoved = function() /* PRIVATE */
{
	/* Trimming removes summaries as it passes them and can cut a run */
	_EventGroups.regroupAll();
};
