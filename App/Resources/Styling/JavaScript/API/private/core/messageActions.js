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

/* Replies, reactions and deleting (9.15). Lines with the server's message ID
 (data-msgid) get a small set of actions while the pointer is over them, and a
 reply (data-reply-to) a quote of the message it answers: who and what, from
 the app when it knew them (data-reply-nickname, data-reply-excerpt,
 data-reply-line), otherwise from that message if it is in the view. A click
 on the quote goes to that message. Works with every style: the markup is
 added here and the look is a stylesheet of :where() defaults. */

var _MessageActions = {};

/* From the app: which actions are offered here ("reply"), and labels */
_MessageActions.available = {}; /* PRIVATE */
_MessageActions.strings = {}; /* PRIVATE */

_MessageActions._toolbar = null; /* PRIVATE */
_MessageActions._toolbarLine = null; /* PRIVATE */

_MessageActions._excerptLength = 120; /* PRIVATE */

_MessageActions.configure = function(available, strings) /* PRIVATE */
{
	_MessageActions.available = (available || {});

	_MessageActions.strings = (strings || {});

	_MessageActions._applyStyles();

	_MessageActions.decorateAll();
};

_MessageActions.setAvailable = function(available) /* PRIVATE */
{
	_MessageActions.available = (available || {});

	_MessageActions._hideToolbar();
};

/* ************************************************** */
/*                       Look                         */
/* ************************************************** */

_MessageActions._applyStyles = function() /* PRIVATE */
{
	if (!document.head || document.getElementById("messageActionRules")) {
		return;
	}

	var rules = [
		":where(div.line .replyQuote) { display: block; margin: 0 0 0.15em 0; font-size: 0.85em; opacity: 0.7; cursor: pointer; " +
			"white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }",
		":where(div.line .replyQuote:hover) { opacity: 1; }",
		":where(div.line .replyQuote .replySender) { font-weight: 600; }",
		":where(div.line.replyFlash) { animation: textualReplyFlash 1.6s ease-out; }",
		"@keyframes textualReplyFlash { from { background-color: rgba(255, 196, 0, 0.35); } to { background-color: transparent; } }",
		"#messageActions { position: fixed; z-index: 10000; display: flex; padding: 1px; border-radius: 6px; " +
			"background: Canvas; color: CanvasText; border: 1px solid rgba(128, 128, 128, 0.35); " +
			"box-shadow: 0 1px 4px rgba(0, 0, 0, 0.15); font: 12px -apple-system, system-ui; }",
		"#messageActions[hidden] { display: none; }",
		"#messageActions button { appearance: none; border: 0; margin: 0; padding: 2px 7px; border-radius: 5px; " +
			"background: transparent; color: inherit; font: inherit; cursor: pointer; }",
		"#messageActions button:hover { background: rgba(128, 128, 128, 0.2); }"
	];

	var style = document.createElement("style");

	style.id = "messageActionRules";

	style.textContent = rules.join("\n");

	document.head.appendChild(style);
};

/* ************************************************** */
/*                      Replies                       */
/* ************************************************** */

_MessageActions.linesAdded = function(lineNumbers) /* PRIVATE */
{
	if (!Array.isArray(lineNumbers)) {
		lineNumbers = [lineNumbers];
	}

	var addedMessages = false;

	for (var i = 0; i < lineNumbers.length; i++) {
		var line = document.getElementByLineNumber(lineNumbers[i]);

		if (!line) {
			continue;
		}

		if (line.dataset.msgid) {
			addedMessages = true;
		}

		_MessageActions.decorateLine(line);
	}

	/* An older message loaded later may be what an earlier quote waited for */
	if (addedMessages) {
		_MessageActions.resolvePendingQuotes();
	}
};

_MessageActions.decorateAll = function() /* PRIVATE */
{
	var replies = document.querySelectorAll("div.line[data-reply-to]");

	for (var i = 0; i < replies.length; i++) {
		_MessageActions.decorateLine(replies[i]);
	}
};

_MessageActions.decorateLine = function(line) /* PRIVATE */
{
	if (!line.dataset.replyTo || line.querySelector(":scope > .replyQuote")) {
		return;
	}

	var quote = document.createElement("div");

	quote.className = "replyQuote";

	quote.setAttribute("role", "button");

	quote.addEventListener("click", _MessageActions._quoteClicked);

	_MessageActions._fillQuote(quote, line);

	line.insertBefore(quote, line.firstChild);
};

_MessageActions.resolvePendingQuotes = function() /* PRIVATE */
{
	var quotes = document.querySelectorAll("div.line > .replyQuote[data-pending]");

	for (var i = 0; i < quotes.length; i++) {
		_MessageActions._fillQuote(quotes[i], quotes[i].parentNode);
	}
};

_MessageActions._lineWithMessageIdentifier = function(msgid) /* PRIVATE */
{
	return document.querySelector("div.line[data-msgid=\"" + CSS.escape(msgid) + "\"]");
};

_MessageActions._excerptOfLine = function(line) /* PRIVATE */
{
	var message = (line.querySelector(".innerMessage") || line.querySelector(".message"));

	var text = ((message) ? message.textContent : "").replace(/\s+/g, " ").trim();

	if (text.length > _MessageActions._excerptLength) {
		text = text.substring(0, _MessageActions._excerptLength) + "…";
	}

	return text;
};

_MessageActions._senderOfLine = function(line) /* PRIVATE */
{
	var sender = line.querySelector(".sender[data-nickname]");

	return ((sender) ? sender.dataset.nickname : "");
};

/* ↩ alice: the message… (or "an earlier message" until it is found) */
_MessageActions._fillQuote = function(quote, line) /* PRIVATE */
{
	var nickname = line.dataset.replyNickname;
	var excerpt = line.dataset.replyExcerpt;

	if (!nickname) {
		var parent = _MessageActions._lineWithMessageIdentifier(line.dataset.replyTo);

		if (parent) {
			nickname = _MessageActions._senderOfLine(parent);

			excerpt = _MessageActions._excerptOfLine(parent);
		}
	}

	quote.textContent = "↩ ";

	if (nickname) {
		var sender = document.createElement("span");

		sender.className = "replySender";

		sender.textContent = nickname;

		quote.appendChild(sender);

		if (excerpt) {
			quote.appendChild(document.createTextNode(": " + excerpt));
		}

		quote.removeAttribute("data-pending");
	} else {
		quote.appendChild(document.createTextNode(_MessageActions.strings.earlierMessage || ""));

		quote.setAttribute("data-pending", "true");
	}
};

/* To the message answered: in the view, or loaded from history by its line number */
_MessageActions._quoteClicked = function(event) /* PRIVATE */
{
	var line = event.currentTarget.parentNode;

	var parent = _MessageActions._lineWithMessageIdentifier(line.dataset.replyTo);

	if (parent) {
		_MessageActions._showLine(parent);

		return;
	}

	var lineNumber = line.dataset.replyLine;

	if (!lineNumber) {
		return;
	}

	MessageBuffer.jumpToLine(lineNumber, function(success) {
		var loaded = document.getElementByLineNumber(lineNumber);

		if (success && loaded) {
			_MessageActions._showLine(loaded);
		}
	});
};

_MessageActions._showLine = function(line) /* PRIVATE */
{
	line.scrollIntoView({block: "center"});

	line.classList.remove("replyFlash");

	void line.offsetWidth; // restart the animation

	line.classList.add("replyFlash");
};

/* ************************************************** */
/*                     Actions                        */
/* ************************************************** */

/* The message under the pointer: a line with an ID, not an event */
_MessageActions._messageLineForElement = function(element) /* PRIVATE */
{
	var line = ((element && element.closest) ? element.closest("div.line.text[data-msgid]") : null);

	return line;
};

_MessageActions._createToolbar = function() /* PRIVATE */
{
	var toolbar = document.createElement("div");

	toolbar.id = "messageActions";

	toolbar.hidden = true;

	toolbar.setAttribute("role", "toolbar");

	document.body.appendChild(toolbar);

	_MessageActions._toolbar = toolbar;

	return toolbar;
};

_MessageActions._showToolbar = function(line) /* PRIVATE */
{
	var buttons = [];

	if (_MessageActions.available.reply) {
		buttons.push({label: "↩ " + (_MessageActions.strings.reply || ""), action: _MessageActions.replyToLine});
	}

	if (buttons.length === 0) {
		_MessageActions._hideToolbar();

		return;
	}

	var toolbar = (_MessageActions._toolbar || _MessageActions._createToolbar());

	toolbar.replaceChildren();

	buttons.forEach(function(item) {
		var button = document.createElement("button");

		button.type = "button";

		button.textContent = item.label;

		button.addEventListener("click", function(event) {
			event.preventDefault();

			var target = _MessageActions._toolbarLine;

			_MessageActions._hideToolbar();

			if (target) {
				item.action(target);
			}
		});

		toolbar.appendChild(button);
	});

	_MessageActions._toolbarLine = line;

	toolbar.hidden = false;

	/* Over the line's top right corner, inside the window */
	var lineRect = line.getBoundingClientRect();

	var toolbarRect = toolbar.getBoundingClientRect();

	var top = Math.max(0, lineRect.top - (toolbarRect.height / 2));

	toolbar.style.top = top + "px";
	toolbar.style.right = Math.max(4, (document.documentElement.clientWidth - lineRect.right) + 8) + "px";
};

_MessageActions._hideToolbar = function() /* PRIVATE */
{
	if (_MessageActions._toolbar) {
		_MessageActions._toolbar.hidden = true;
	}

	_MessageActions._toolbarLine = null;
};

_MessageActions._mouseOver = function(event) /* PRIVATE */
{
	var toolbar = _MessageActions._toolbar;

	if (toolbar && toolbar.contains(event.target)) {
		return;
	}

	var line = _MessageActions._messageLineForElement(event.target);

	if (line === _MessageActions._toolbarLine) {
		return;
	}

	if (line) {
		_MessageActions._showToolbar(line);
	} else {
		_MessageActions._hideToolbar();
	}
};

_MessageActions.replyToLine = function(line) /* PRIVATE */
{
	var msgid = line.dataset.msgid;

	if (!msgid) {
		return;
	}

	appPrivate.replyToMessage(msgid, _MessageActions._senderOfLine(line), _MessageActions._excerptOfLine(line));
};

/* Bind to events */
document.addEventListener("mouseover", _MessageActions._mouseOver, false);
document.addEventListener("mouseout", function(event) {
	/* The pointer left the view */
	if (event.relatedTarget === null) {
		_MessageActions._hideToolbar();
	}
}, false);
document.addEventListener("scroll", _MessageActions._hideToolbar, true);
window.addEventListener("blur", _MessageActions._hideToolbar, false);
