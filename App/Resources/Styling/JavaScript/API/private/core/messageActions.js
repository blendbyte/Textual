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
		"#messageActions button:hover { background: rgba(128, 128, 128, 0.2); }",
		"#messageActions button.reactionChoice { padding: 1px 4px; font-size: 15px; }",
		":where(div.line .reactions) { display: flex; flex-wrap: wrap; gap: 4px; margin: 3px 0 1px 0; }",
		":where(div.line .reaction) { appearance: none; margin: 0; padding: 0 6px; border-radius: 10px; font: inherit; font-size: 0.85em; " +
			"line-height: 1.6; color: inherit; cursor: pointer; border: 1px solid rgba(128, 128, 128, 0.35); background: rgba(128, 128, 128, 0.08); }",
		":where(div.line .reactions.inline) { display: inline-flex; flex-wrap: nowrap; gap: 3px; margin: 0 0 0 0.5em; vertical-align: baseline; }",
		":where(div.line .reactions.inline .reaction) { font-size: 0.8em; line-height: 1.35; padding: 0 5px; }",
		":where(div.line.redacted .redactedNote, div.line.redacted .innerMessage) { font-style: italic; opacity: 0.6; }",
		":where(div.line .reaction.mine) { border-color: rgba(0, 122, 255, 0.6); background: rgba(0, 122, 255, 0.14); }",
		":where(div.line .reaction .reactionCount) { margin-left: 0.3em; font-variant-numeric: tabular-nums; }"
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
	var lines = document.querySelectorAll("div.line[data-reply-to], div.line[data-reactions]");

	for (var i = 0; i < lines.length; i++) {
		_MessageActions.decorateLine(lines[i]);
	}
};

_MessageActions.decorateLine = function(line) /* PRIVATE */
{
	_MessageActions._decorateReply(line);

	_MessageActions._renderReactions(line);
};

_MessageActions._decorateReply = function(line) /* PRIVATE */
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

	if (!message) {
		return "";
	}

	/* The text alone: not the reactions after it or a preview card */
	var copy = message.cloneNode(true);

	copy.querySelectorAll(".reactions, .replyQuote, .inlineMediaContainer").forEach(function(element) {
		element.remove();
	});

	var text = copy.textContent.replace(/\s+/g, " ").trim();

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
/*                    Reactions                       */
/* ************************************************** */

/* From the app: [{emoji, count, nicknames, mine}, …] for a message */
_MessageActions.setReactions = function(msgid, reactions) /* PRIVATE */
{
	var lines = document.querySelectorAll("div.line[data-msgid=\"" + CSS.escape(msgid) + "\"]");

	for (var i = 0; i < lines.length; i++) {
		if (reactions && reactions.length > 0) {
			lines[i].dataset.reactions = JSON.stringify(reactions);
		} else {
			delete lines[i].dataset.reactions;
		}

		_MessageActions._renderReactions(lines[i]);
	}
};

_MessageActions._reactionsOfLine = function(line) /* PRIVATE */
{
	if (!line.dataset.reactions) {
		return [];
	}

	try {
		var reactions = JSON.parse(line.dataset.reactions);

		return ((Array.isArray(reactions)) ? reactions : []);
	} catch (error) {
		return [];
	}
};

/* 👍 2  ❤️ 1 under the message (Chat) or after its text (Classic): yours
 marked, a click takes yours back or adds it */
_MessageActions._renderReactions = function(line) /* PRIVATE */
{
	var existing = line.querySelector(".reactions");

	if (existing) {
		existing.remove();
	}

	var reactions = _MessageActions._reactionsOfLine(line);

	if (reactions.length === 0) {
		return;
	}

	/* Classic: one line, so they go at the end of the text, before any preview */
	var inlineText = null;

	if (!line.querySelector(".messageBody")) {
		inlineText = (line.querySelector(".innerMessage") || line.querySelector(".message"));
	}

	var container = document.createElement((inlineText) ? "span" : "div");

	container.className = ((inlineText) ? "reactions inline" : "reactions");

	reactions.forEach(function(reaction) {
		var chip = document.createElement("button");

		chip.type = "button";

		chip.className = ((reaction.mine) ? "reaction mine" : "reaction");

		chip.title = (reaction.nicknames || "");

		chip.setAttribute("aria-label", reaction.emoji + " " + reaction.count + ": " + (reaction.nicknames || ""));

		chip.setAttribute("aria-pressed", ((reaction.mine) ? "true" : "false"));

		chip.appendChild(document.createTextNode(reaction.emoji));

		var count = document.createElement("span");

		count.className = "reactionCount";

		count.textContent = reaction.count;

		chip.appendChild(count);

		chip.addEventListener("click", function(event) {
			event.preventDefault();

			if (!_MessageActions.available.react) {
				return;
			}

			appPrivate.toggleReaction(line.dataset.msgid, reaction.emoji, ((reaction.mine) ? 1 : 0));
		});

		container.appendChild(chip);
	});

	if (inlineText) {
		var media = inlineText.querySelector(":scope > .inlineMediaContainer");

		inlineText.insertBefore(container, media);
	} else {
		line.appendChild(container);
	}
};

/* The six quick choices, or ours taken back if already given */
_MessageActions._quickReactions = ["👍", "❤️", "😂", "😮", "😢", "🙏"]; /* PRIVATE */

_MessageActions.reactToLine = function(line, emoji) /* PRIVATE */
{
	var msgid = line.dataset.msgid;

	if (!msgid) {
		return;
	}

	var mine = _MessageActions._reactionsOfLine(line).some(function(reaction) {
		return (reaction.emoji === emoji && reaction.mine);
	});

	appPrivate.toggleReaction(msgid, emoji, ((mine) ? 1 : 0));
};

_MessageActions._showReactionChoices = function(line) /* PRIVATE */
{
	var buttons = _MessageActions._quickReactions.map(function(emoji) {
		return {label: emoji, className: "reactionChoice", action: function(target) {
			_MessageActions.reactToLine(target, emoji);
		}};
	});

	buttons.push({label: (_MessageActions.strings.moreReactions || "…"), action: function(target) {
		if (target.dataset.msgid) {
			appPrivate.pickReaction(target.dataset.msgid);
		}
	}});

	_MessageActions._fillToolbar(line, buttons);
};

/* ************************************************** */
/*                     Deleting                       */
/* ************************************************** */

/* From the app: the message's text becomes the note ("Message deleted…");
 its reactions go, and replies quoting it say so too */
_MessageActions.deleteMessage = function(msgid, note) /* PRIVATE */
{
	var lines = document.querySelectorAll("div.line[data-msgid=\"" + CSS.escape(msgid) + "\"]");

	for (var i = 0; i < lines.length; i++) {
		var line = lines[i];

		if (line === _MessageActions._toolbarLine) {
			_MessageActions._hideToolbar();
		}

		line.classList.add("redacted");

		delete line.dataset.reactions;

		var reactions = line.querySelector(".reactions");

		if (reactions) {
			reactions.remove();
		}

		var text = (line.querySelector(".innerMessage") || line.querySelector(".message"));

		if (text) {
			var noteElement = document.createElement("span");

			noteElement.className = "redactedNote";

			noteElement.textContent = note;

			text.replaceChildren(noteElement);
		}
	}

	var replies = document.querySelectorAll("div.line[data-reply-to=\"" + CSS.escape(msgid) + "\"]");

	for (var j = 0; j < replies.length; j++) {
		var reply = replies[j];

		var quote = reply.querySelector(":scope > .replyQuote");

		var parent = _MessageActions._lineWithMessageIdentifier(msgid);

		if (!reply.dataset.replyNickname && parent) {
			reply.dataset.replyNickname = _MessageActions._senderOfLine(parent);
		}

		reply.dataset.replyExcerpt = note;

		if (quote) {
			_MessageActions._fillQuote(quote, reply);
		}
	}
};

/* ************************************************** */
/*                     Actions                        */
/* ************************************************** */

/* The message under the pointer: a line with an ID, not an event or a deleted one */
_MessageActions._messageLineForElement = function(element) /* PRIVATE */
{
	var line = ((element && element.closest) ? element.closest("div.line.text[data-msgid]:not(.redacted)") : null);

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

	if (_MessageActions.available.react) {
		buttons.push({label: "☺ " + (_MessageActions.strings.react || ""), keepOpen: true, action: _MessageActions._showReactionChoices});
	}

	/* Ours, or anyone's for an operator (the server decides) */
	var mine = (line.dataset.memberType === "myself");

	if (_MessageActions.available.delete && (mine || _MessageActions.available.deleteOthers)) {
		buttons.push({label: "🗑 " + (_MessageActions.strings.delete || ""), action: function(target) {
			appPrivate.deleteMessage(target.dataset.msgid);
		}});
	}

	if (buttons.length === 0) {
		_MessageActions._hideToolbar();

		return;
	}

	_MessageActions._fillToolbar(line, buttons);
};

/* Buttons over the line; an action with keepOpen changes the toolbar instead of closing it */
_MessageActions._fillToolbar = function(line, buttons) /* PRIVATE */
{
	var toolbar = (_MessageActions._toolbar || _MessageActions._createToolbar());

	toolbar.replaceChildren();

	buttons.forEach(function(item) {
		var button = document.createElement("button");

		button.type = "button";

		button.textContent = item.label;

		if (item.className) {
			button.className = item.className;
		}

		button.addEventListener("click", function(event) {
			event.preventDefault();

			var target = _MessageActions._toolbarLine;

			if (!item.keepOpen) {
				_MessageActions._hideToolbar();
			}

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
