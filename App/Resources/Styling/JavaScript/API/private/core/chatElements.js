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

/* Chat elements: the date and session lines and the floating labels at the
 top of the chat (the date of what is shown while scrolling, loading earlier
 messages). Their look is baseLayout.css's; this keeps them right:
 - a date line says "Today", "Yesterday" or the weekday and date, and is
   relabelled after midnight;
 - a date line repeating the date before it is hidden, and a session line
   with nothing shown between it and a date line joins that date line
   ("Today · since 09:41"), so separators never stack up. */

var _ChatElements = {};

/* From the app: today, yesterday, loadingEarlier */
_ChatElements.strings = {}; /* PRIVATE */

_ChatElements._observer = null; /* PRIVATE */
_ChatElements._tidyScheduled = false; /* PRIVATE */
_ChatElements._midnightTimer = null; /* PRIVATE */
_ChatElements._dateFloatTimer = null; /* PRIVATE */
_ChatElements._loadingCount = 0; /* PRIVATE */
_ChatElements._loadingTimer = null; /* PRIVATE */

_ChatElements.configure = function(strings) /* PRIVATE */
{
	_ChatElements.strings = (strings || {});

	var buffer = document.getElementById("messageBuffer");

	if (buffer === null) {
		return;
	}

	/* Lines come and go as direct children of the buffer */
	if (_ChatElements._observer === null) {
		_ChatElements._observer = new MutationObserver(_ChatElements.scheduleTidy);

		_ChatElements._observer.observe(buffer, {childList: true});
	}

	_ChatElements._setUpFloats();

	_ChatElements._scheduleMidnight();

	_ChatElements.tidy();
};

/* ************************************************** */
/*                Date and session lines              */
/* ************************************************** */

_ChatElements.scheduleTidy = function() /* PRIVATE */
{
	if (_ChatElements._tidyScheduled) {
		return;
	}

	_ChatElements._tidyScheduled = true;

	requestAnimationFrame(_ChatElements.tidy);
};

/* Days since the date line's day (data-day, year-month-day), or null */
_ChatElements._daysAgo = function(day) /* PRIVATE */
{
	var parts = (day || "").split("-");

	if (parts.length !== 3) {
		return null;
	}

	var date = new Date(Number(parts[0]), (Number(parts[1]) - 1), Number(parts[2]));

	var today = new Date();

	today.setHours(0, 0, 0, 0);

	return Math.round((today - date) / 86400000);
};

_ChatElements._labelOfDay = function(element) /* PRIVATE */
{
	var daysAgo = _ChatElements._daysAgo(element.getAttribute("data-day"));

	var strings = _ChatElements.strings;

	if (daysAgo === 0 && strings.today) {
		return strings.today;
	} else if (daysAgo === 1 && strings.yesterday) {
		return strings.yesterday;
	}

	return element.getAttribute("data-label");
};

/* The date line's text: its label, and "since 09:41" when a session line joined it */
_ChatElements._renderDate = function(element) /* PRIVATE */
{
	var label = element._chatElementLabel;

	var span = element.querySelector(":scope > span");

	if (span === null || !label) {
		return;
	}

	span.textContent = label;

	var since = element._chatElementSince;

	if (since) {
		var sinceSpan = document.createElement("span");

		sinceSpan.className = "sessionSince";

		sinceSpan.textContent = (" · " + since);

		span.appendChild(sinceSpan);
	}

	element.setAttribute("aria-label", span.textContent);
};

_ChatElements._join = function(dateElement, sessionElement) /* PRIVATE */
{
	sessionElement.hidden = true;

	dateElement._chatElementSince = sessionElement.getAttribute("data-since");

	_ChatElements._renderDate(dateElement);
};

_ChatElements._isSeparator = function(element) /* PRIVATE */
{
	return (element.classList.contains("date_indicator") || element.classList.contains("session_indicator"));
};

_ChatElements.tidy = function() /* PRIVATE */
{
	_ChatElements._tidyScheduled = false;

	var buffer = document.getElementById("messageBuffer");

	if (buffer === null) {
		return;
	}

	var lastDay = null;

	/* A separator shown with nothing shown after it yet */
	var open = null;

	for (var element = buffer.firstElementChild; element !== null; element = element.nextElementSibling) {
		if (element.classList.contains("date_indicator")) {
			var day = element.getAttribute("data-day");

			/* Only date lines from the template that has data-day */
			if (!day) {
				open = element;

				continue;
			}

			element._chatElementSince = null;

			if (day === lastDay) {
				element.hidden = true;

				continue;
			}

			element.hidden = false;

			lastDay = day;

			element._chatElementLabel = _ChatElements._labelOfDay(element);

			if (open !== null && open.classList.contains("session_indicator") && open.hasAttribute("data-since")) {
				_ChatElements._join(element, open);
			} else {
				_ChatElements._renderDate(element);
			}

			open = element;
		} else if (element.classList.contains("session_indicator")) {
			element.hidden = false;

			if (open !== null && open.classList.contains("date_indicator") && open._chatElementLabel && !open._chatElementSince && element.hasAttribute("data-since")) {
				_ChatElements._join(open, element);

				continue;
			}

			open = element;
		} else if (open !== null && element.id !== "mark" && element.id !== "typing-indicator") {
			/* Something shown: the next separator stands on its own */
			if (element.getClientRects().length > 0) {
				open = null;
			}
		}
	}

	_ChatElements._placeMark(buffer);
};

/* The unread marker is added at the end while the view is in the background,
 and the next message brings its date line below it: it goes below the date
 and session lines that follow it ("Today", then "New") */
_ChatElements._placeMark = function(buffer) /* PRIVATE */
{
	var mark = document.getElementById("mark");

	if (mark === null || mark.parentNode !== buffer) {
		return;
	}

	var lastSeparator = null;

	for (var next = mark.nextElementSibling; next !== null; next = next.nextElementSibling) {
		var shown = (next.getClientRects().length > 0);

		if (next.classList.contains("date_indicator") || next.classList.contains("session_indicator")) {
			if (shown) {
				lastSeparator = next;
			}
		} else if (shown) {
			break;
		}
	}

	if (lastSeparator !== null) {
		lastSeparator.insertAdjacentElement("afterend", mark);
	}
};

/* Relabels the date lines after midnight ("Today" becomes "Yesterday") */
_ChatElements._scheduleMidnight = function() /* PRIVATE */
{
	if (_ChatElements._midnightTimer !== null) {
		clearTimeout(_ChatElements._midnightTimer);
	}

	var now = new Date();

	var midnight = new Date(now.getFullYear(), now.getMonth(), (now.getDate() + 1), 0, 0, 1);

	_ChatElements._midnightTimer = setTimeout(function() {
		_ChatElements._midnightTimer = null;

		_ChatElements.tidy();

		_ChatElements._scheduleMidnight();
	}, (midnight - now));
};

/* ************************************************** */
/*                  Floating labels                   */
/* ************************************************** */

_ChatElements._setUpFloats = function() /* PRIVATE */
{
	if (document.getElementById("chatElementFloats")) {
		return;
	}

	var body = document.getElementById("body");

	if (body === null) {
		return;
	}

	var floats = document.createElement("div");

	floats.id = "chatElementFloats";

	floats.setAttribute("aria-hidden", "true");

	var dateFloat = document.createElement("div");

	dateFloat.id = "chatElementDate";

	dateFloat.className = "chatElementFloat";

	var loadingFloat = document.createElement("div");

	loadingFloat.id = "chatElementLoading";

	loadingFloat.className = "chatElementFloat";

	var spinner = document.createElement("span");

	spinner.className = "chatElementSpinner";

	var loadingText = document.createElement("span");

	loadingText.textContent = (_ChatElements.strings.loadingEarlier || "");

	loadingFloat.appendChild(spinner);
	loadingFloat.appendChild(loadingText);

	floats.appendChild(dateFloat);
	floats.appendChild(loadingFloat);

	body.insertBefore(floats, body.firstChild);

	/* On the page, for the typing indicator too */
	document.body.style.setProperty("--textual-float-background", _ChatElements._backgroundColor(body));

	/* The chat scrolls in #body in most styles, in the page in others */
	document.addEventListener("scroll", _ChatElements._scrolled, {capture: true, passive: true});
};

/* The colour behind the chat, for the floating labels */
_ChatElements._backgroundColor = function(element) /* PRIVATE */
{
	for (var e = element; e !== null; e = e.parentElement) {
		var color = getComputedStyle(e).backgroundColor;

		if (color && color !== "transparent" && !/rgba\([^)]*,\s*0\)$/.test(color)) {
			return color;
		}
	}

	return ((document.body.getAttribute("data-appearance") === "dark") ? "#1e1e1e" : "#ffffff");
};

/* While scrolling back, the date of what is shown, at the top */
_ChatElements._scrolled = function(event) /* PRIVATE */
{
	var scroller = ((event.target === document) ? document.scrollingElement : event.target);

	var buffer = document.getElementById("messageBuffer");

	var dateFloat = document.getElementById("chatElementDate");

	if (!scroller || buffer === null || dateFloat === null || scroller.contains(buffer) === false) {
		return;
	}

	var atBottom = ((scroller.scrollHeight - scroller.scrollTop - scroller.clientHeight) < 40);

	var label = ((atBottom) ? null : _ChatElements._dateAboveTop(scroller, buffer));

	if (label === null) {
		dateFloat.removeAttribute("data-shown");

		return;
	}

	dateFloat.textContent = label;

	dateFloat.setAttribute("data-shown", "true");

	if (_ChatElements._dateFloatTimer !== null) {
		clearTimeout(_ChatElements._dateFloatTimer);
	}

	_ChatElements._dateFloatTimer = setTimeout(function() {
		_ChatElements._dateFloatTimer = null;

		dateFloat.removeAttribute("data-shown");
	}, 1500);
};

/* The label of the last date line scrolled out of sight at the top; none
 while a date line is in sight near the top (it says it already) */
_ChatElements._dateAboveTop = function(scroller, buffer) /* PRIVATE */
{
	var top = ((scroller === document.scrollingElement) ? 0 : scroller.getBoundingClientRect().top);

	var dates = buffer.querySelectorAll(".date_indicator:not([hidden])");

	var label = null;

	for (var i = 0; i < dates.length; i++) {
		var rect = dates[i].getBoundingClientRect();

		if (rect.bottom <= (top + 2)) {
			label = (dates[i]._chatElementLabel || null);
		} else {
			if (rect.top < (top + 40)) {
				return null;
			}

			break;
		}
	}

	return label;
};

/* Loading earlier messages: shown when it takes a moment */
_ChatElements.loadingStarted = function() /* PRIVATE */
{
	_ChatElements._loadingCount += 1;

	if (_ChatElements._loadingTimer !== null) {
		return;
	}

	_ChatElements._loadingTimer = setTimeout(function() {
		_ChatElements._loadingTimer = null;

		var loadingFloat = document.getElementById("chatElementLoading");

		if (loadingFloat && _ChatElements._loadingCount > 0) {
			loadingFloat.setAttribute("data-shown", "true");
		}
	}, 300);
};

_ChatElements.loadingFinished = function() /* PRIVATE */
{
	_ChatElements._loadingCount = Math.max(0, (_ChatElements._loadingCount - 1));

	if (_ChatElements._loadingCount > 0) {
		return;
	}

	if (_ChatElements._loadingTimer !== null) {
		clearTimeout(_ChatElements._loadingTimer);

		_ChatElements._loadingTimer = null;
	}

	var loadingFloat = document.getElementById("chatElementLoading");

	if (loadingFloat) {
		loadingFloat.removeAttribute("data-shown");
	}
};
