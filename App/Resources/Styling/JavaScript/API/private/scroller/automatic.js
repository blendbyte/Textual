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

/* ************************************************** */
/*                     Visibility                     */
/* ************************************************** */

TextualScroller.documentIsVisible = undefined; /* PUBLIC */

_TextualScroller._documentVisibilityChangedCallback = function() /* PRIVATE */
{
	var documentHidden = document.hidden;

	if (documentHidden) {
		TextualScroller.documentIsVisible = false;
	} else {
		TextualScroller.documentIsVisible = true;

		TextualScroller.restoreScrolledToBottom();
	}
};

_TextualScroller._documentResizedCallback = function()
{
	TextualScroller.restoreScrolledToBottom();
};

/* ************************************************** */
/*                 Automatic Scroller                 */
/* ************************************************** */

_TextualScroller._performScrollTimeout = null; /* PRIVATE */
_TextualScroller._performScrollNextPass = undefined; /* PRIVATE */

_TextualScroller.performScrollPreflight = function() /* PRIVATE */
{
	/* Do nothing if we are already planning to scroll. */
	if (_TextualScroller._performScrollTimeout) {
		return;
	}

	if (_TextualScroller._performScrollNextPass) {
		return;
	}

	/* Are we at the bottom? */
	_TextualScroller._performScrollNextPass =
	TextualScroller.isScrolledToBottom();
};

_TextualScroller.performScrollCancel = function() /* PRIVATE */
{
	if (_TextualScroller._performScrollTimeout) {
		clearTimeout(_TextualScroller._performScrollTimeout);

		_TextualScroller._performScrollTimeout = null;
	}

	_TextualScroller._performScrollNextPass = undefined;
};

TextualScroller.performScroll = function() /* PUBLIC */
{
	/* Do nothing if we are already planning to scroll. */
	if (_TextualScroller._performScrollTimeout) {
		return;
	}

	/* Do not perform automatic scroll if we weren't at bottom. */
	if (!_TextualScroller._performScrollNextPass) {
		return;
	}

	var performAutomaticScroll = (function() {
		_TextualScroller._performScrollTimeout = null;
		_TextualScroller._performScrollNextPass = undefined;

		_TextualScroller.performScroll();
	});

	_TextualScroller._performScrollTimeout = 
	setTimeout(performAutomaticScroll, 0);
};

_TextualScroller.performScroll = function() /* PRIVATE */
{	
	/* Do not perform automatic scroll if is disabled. */
	if (!TextualScroller.automaticScrollingEnabled) {
		return;
	}

	/* Do not perform automatic scroll if the document is not visible. */
	if (!TextualScroller.documentIsVisible) {
		return;
	}

	/* Scroll to bottom */
	TextualScroller.scrollToBottom();
};

/* This function sets a flag that tells the scroller not to do anything,
regardless of whether it is visible or not. Visibility will control whether
the timer itself is activate, not this function. */
TextualScroller.automaticScrollingEnabled = true; /* PRIVATE */

TextualScroller.setAutomaticScrollingEnabled = function(enabled) /* PUBLIC */
{
	TextualScroller.automaticScrollingEnabled = enabled;
};

/* ************************************************** */
/*              Mutation Observer Helpers             */
/* ************************************************** */

HTMLDocument.prototype.prepareForMutation = function() /* PUBLIC */
{
	_TextualScroller.prepareForMutation();
};

HTMLDocument.prototype.cancelMutation = function() /* PUBLIC */
{
	_TextualScroller.cancelMutation();
};

Element.prototype.prepareForMutation = function() /* PUBLIC */
{
	document.prepareForMutation();
};

Element.prototype.cancelMutation = function() /* PUBLIC */
{
	document.cancelMutation();
};

_TextualScroller.prepareForMutation = function()
{
	_TextualScroller.performScrollPreflight();
};

_TextualScroller.cancelMutation = function()
{
	_TextualScroller.performScrollCancel();
};

/* ************************************************** */
/*                 Mutation Observer                  */
/* ************************************************** */

_TextualScroller._mutationObserver = null; /* PRIVATE */

_TextualScroller._mutationObserverCallback = function(mutations) /* PRIVATE */
{
	TextualScroller.performScroll();
};

_TextualScroller.createMutationObserver = function() /* PRIVATE */
{
	var buffer = MessageBuffer.bufferElement();

	var observer = new MutationObserver(_TextualScroller._mutationObserverCallback);

	observer.observe(
		buffer, 

		{
			childList: true,
			attributes: true,
			attributeFilter: ["wants-reveal", "style"], // for inline media
			subtree: true
		}
	);

	_TextualScroller._mutationObserver = observer;
};

/* ************************************************** */
/*                      Events                        */
/* ************************************************** */

window.addEventListener("resize", _TextualScroller._documentResizedCallback, false);

document.addEventListener("visibilitychange", _TextualScroller._documentVisibilityChangedCallback, false);

/* Populate initial visibility state and maybe create timer */
_TextualScroller._documentVisibilityChangedCallback();
