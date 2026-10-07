/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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

"use strict";

/* ************************************************** */
/*                                                    */
/* DO NOT OVERRIDE ANYTHING BELOW THIS LINE           */
/*                                                    */
/* ************************************************** */

var TextualScroller = {};
var _TextualScroller = {};

/* ************************************************** */
/*                   State Tracking                   */
/* ************************************************** */

/* Element to scroll */
_TextualScroller._scrolledElement = null;

/* Minimum distance from bottom to be scrolled upwards
before TextualScroller.userScrolled is true. */
_TextualScroller._userScrolledMinimum = 25; /* PRIVATE */

/* Whether or not we are scrolled above the bottom. */
TextualScroller.userScrolled = false; /* PUBLIC */

/* Set to true when scrolled upwards. */
TextualScroller.scrolledUpwards = false; /* PUBLIC */

/* Cached scroll position */
TextualScroller.scrollPositionCurrentValue = 0; /* PUBLIC */
TextualScroller.scrollPositionPreviousValue = 0; /* PUBLIC */

/* Cached scroll height */
TextualScroller.scrollHeightCurrentValue = 0; /* PUBLIC */
TextualScroller.scrollHeightPreviousValue = 0; /* PUBLIC */

_TextualScroller._documentScrolledCallback = function() /* PRIVATE */
{
	/* Fix for scrolling on macOS 27.
	 To quote "ilikepeaches" in the #textual support channel:
	 
	 "FYI I encountered some annoying behavior with Textual on the macOS 27 beta.
	 When the user switches away from a channel and new messages arrive in that
	 background channel, Textual fails to scroll to the bottom of the channel
	 when the user returns to it. The cause here is that WebKit in macOS 27 has
	 changed: it suspends the hidden view and shrinks the client height to zero,
	 confusing the scroll script into thinking the user scrolled up."
	 
	"TextualScroller.documentIsVisible" is not used here in case of a possible
	 unforseen race condition between the callback that sets this and here. */
	if (document.hidden) {
		return;
	}
	
	var scrolledElement = _TextualScroller._scrolledElement;

	/* Height of scrollable area */
	var scrollHeightPrevious = TextualScroller.scrollHeightCurrentValue;

	var scrollHeightCurrent = scrolledElement.scrollHeight;

	/* The current position scrolled to */
	var clientHeight = scrolledElement.clientHeight;

	var scrollPositionCurrent = (scrolledElement.scrollTop + clientHeight);

	var scrollPositionPrevious = TextualScroller.scrollPositionCurrentValue;

	/* If nothing changed, we ignore the event.
	It is possible to receive a scroll event but nothing changes
	because we ignore elastic scrolling. User can reach bottom,
	elastic scroll, then bounce back. We get notification for
	both times we reach bottom, but values do not change. */
	if (scrollHeightPrevious === scrollHeightCurrent &&
		scrollPositionPrevious === scrollPositionCurrent) 
	{
		return;
	}

	/* Even if user is elastic scrolling, we want to record
	the latest scroll height values. */
	TextualScroller.scrollHeightPreviousValue = scrollHeightPrevious;
	TextualScroller.scrollHeightCurrentValue = scrollHeightCurrent;

	/* Ignore elastic scrolling */
	if (scrollPositionCurrent < clientHeight ||
		scrollPositionCurrent > scrollHeightCurrent) 
	{
		return;
	}

	/* Only record scroll position changes if we weren't elastic scrolling. */
	TextualScroller.scrollPositionPreviousValue = scrollPositionPrevious;
	TextualScroller.scrollPositionCurrentValue = scrollPositionCurrent;

	/* Scrolled upwards? */
	var scrolledUpwards = (scrollPositionCurrent < scrollPositionPrevious);

	TextualScroller.scrolledUpwards = scrolledUpwards;

	/* User scrolled above bottom? */
	var userScrolled = ((scrollHeightCurrent - scrollPositionCurrent) > _TextualScroller._userScrolledMinimum);

	TextualScroller.userScrolled = userScrolled;

	/* Post custom scroll event */
	if (scrolledUpwards) {
		document.dispatchEvent(new Event('scrolledUpward'));
	} else {
		document.dispatchEvent(new Event('scrolledDownward'));
	}
};

/* ************************************************** */
/*               Position Restore                     */
/* ************************************************** */

_TextualScroller._restoreScrolledUpwards = undefined; /* PRIVATE */
_TextualScroller._restoreScrollHeightFirstValue = undefined; /* PRIVATE */
_TextualScroller._restoreScrollHeightSecondValue = undefined; /* PRIVATE */

TextualScroller.saveRestorationFirstDataPoint = function() /* PUBLIC */
{
	var scrolledElement = _TextualScroller._scrolledElement;

	_TextualScroller._restoreScrollHeightFirstValue = scrolledElement.scrollHeight;

	_TextualScroller._restoreScrolledUpwards = TextualScroller.scrolledUpwards;
};

TextualScroller.saveRestorationSecondDataPoint = function() /* PUBLIC */
{
	var scrolledElement = _TextualScroller._scrolledElement;

	_TextualScroller._restoreScrollHeightSecondValue = scrolledElement.scrollHeight;
};

TextualScroller.restoreScrollPosition = function() /* PUBLIC */
{
	var scrollHeightDifference = (_TextualScroller._restoreScrollHeightSecondValue - 
								  _TextualScroller._restoreScrollHeightFirstValue);

	if (scrollHeightDifference === 0) {
		return;
	}

	var scrolledElement = _TextualScroller._scrolledElement;

	var scrollTo = 0;

	if (_TextualScroller._restoreScrolledUpwards === false) {
		scrollTo = (scrolledElement.scrollHeight - scrollHeightDifference);
	} else {
		scrollTo = (scrolledElement.scrollHeight + scrollHeightDifference);
	}

	if (scrollTo < 0) {
		scrollTo = 0;
	}

	scrolledElement.scrollTop = scrollTo;

	_TextualScroller._restoreScrollHeightFirstValue = undefined;
	_TextualScroller._restoreScrollHeightSecondValue = undefined;

	_TextualScroller._restoreScrolledUpwards = undefined;
};

TextualScroller.restoreScrolledToBottom = function() /* PUBLIC */
{
	if (TextualScroller.userScrolled === false) {
		TextualScroller.scrollToBottom();
	}
};

/* ************************************************** */
/*              Element Prototypes                    */
/* ************************************************** */

Element.prototype.scrollCenterIn = function(parentElement) /* PUBLIC */
{
	if (this === parentElement) {
		throw "Can't scroll self into center";
	}

	var parentElementRect = parentElement.getBoundingClientRect();
	var parentElementHeight = parentElementRect.height;
	var parentElementTop = parentElement.scrollTop;

	var elementRect = this.getBoundingClientRect();
	var elementTop = (elementRect.top + parentElementTop);
	var elementCenter = (elementTop - (parentElementHeight / 2));

	return elementCenter;
};

Element.prototype.percentScrolled = function() /* PUBLIC */
{
	return (((this.scrollTop + this.clientHeight) / this.scrollHeight) * 100.0);
};

Element.prototype.isScrolledToTop = function() /* PUBLIC */
{
	return (this.scrollTop <= 0);
};

Element.prototype.scrollToTop = function() /* PUBLIC */
{
	this.scrollTop = 0;
};

Element.prototype.scrollIntoViewAlignTop = function() /* PUBLIC */
{
	this.scrollIntoView(true);
};

Element.prototype.scrollIntoViewAlignBottom = function() /* PUBLIC */
{
	this.scrollIntoView(false);
};

Element.prototype.isScrolledToBottom = function() /* PUBLIC */
{
	return ((this.scrollTop + this.clientHeight) >= this.scrollHeight);
};

Element.prototype.scrollToBottom = function() /* PUBLIC */
{
	this.scrollTop = this.scrollHeight;
};

/* ************************************************** */
/*              Element Prototype Proxies             */
/* ************************************************** */

TextualScroller.scrollElementToCenter = function(element) /* PUBLIC */
{
	var scrolledElement = _TextualScroller._scrolledElement;

	var scrollCenter = element.scrollCenterIn(scrolledElement);

	scrolledElement.scrollTop = scrollCenter;
};

TextualScroller.percentScrolled = function() /* PUBLIC */
{
	var scrolledElement = _TextualScroller._scrolledElement;

	return scrolledElement.percentScrolled();
};

TextualScroller.isScrolledToTop = function() /* PUBLIC */
{
	var scrolledElement = _TextualScroller._scrolledElement;

	return scrolledElement.isScrolledToTop();
};

TextualScroller.scrollToTop = function() /* PUBLIC */
{
	var scrolledElement = _TextualScroller._scrolledElement;

	scrolledElement.scrollToTop();
};

TextualScroller.isScrolledToBottom = function() /* PUBLIC */
{
	/* If a timer is set to scroll to the bottom already,
	then we lie about our current position. */
	if (_TextualScroller._performScrollTimeout) {
		return true;
	}

	if (!TextualScroller.userScrolled) {
		return true;
	}

	var scrolledElement = _TextualScroller._scrolledElement;

	return scrolledElement.isScrolledToBottom();
};

TextualScroller.scrollToBottom = function() /* PUBLIC */
{
	var scrolledElement = _TextualScroller._scrolledElement;

	scrolledElement.scrollToBottom();
};

/* ************************************************** */
/*                     Events                         */
/* ************************************************** */

/* This function is public interface which styles are 
allowed to override which we should add extra sanity. */
TextualScroller.bindToElement = function(newElement) /* PUBLIC */
{
	if (!newElement ||
		!newElement.nodeType ||
		 newElement.nodeType !== Node.ELEMENT_NODE) 
	{
		throw "Argument is not an element";
	}

	var oldElement = _TextualScroller._scrolledElement;

	if (oldElement) {
		if (oldElement !== document.body) {
			oldElement.removeEventListener("scroll", _TextualScroller._documentScrolledCallback);
		} else {
			window.removeEventListener("scroll", _TextualScroller._documentScrolledCallback);
		}
	}

	if (newElement !== document.body) {
		newElement.addEventListener("scroll", _TextualScroller._documentScrolledCallback, false);
	} else {
		window.addEventListener("scroll", _TextualScroller._documentScrolledCallback, false);
	}

	_TextualScroller._scrolledElement = newElement;
};

_TextualScroller.bindToBestElement = function()
{
	var bindToElement = (function(element) {
		if (window.getComputedStyle(element).overflowY === "hidden") {
			return false;
		}

		TextualScroller.bindToElement(element);

		return true;
	});

	if (bindToElement(document.body)) {
		console.log("Binding to document body");

		return;
	} else if (bindToElement(Textual.documentBodyElement())) {
		console.log("Binding to #body_home");

		return;
	} else if (bindToElement(MessageBuffer.bufferElement())) {
		console.log("Binding to #message_buffer");

		return;
	}

	console.error("No element to bind to. Manually call TextualScroller.bindToElement()");
};
