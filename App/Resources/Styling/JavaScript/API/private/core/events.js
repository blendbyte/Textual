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

Textual.finishedLoadingView = false; /* PUBLIC */
Textual.finishedLoadingHistory = false; /* PUBLIC */

/* State management */
_Textual.notifyDidBecomeVisible = function() /* PRIVATE */
{
	Textual.clearSelection();

	document.body.dataset.visible = "true";
};

_Textual.notifyDidBecomeHidden = function() /* PRIVATE */
{
	Textual.clearSelection();

	document.body.dataset.visible = false;
};

_Textual.notifySelectionChanged = function(isSelected) /* PRIVATE */
{
	/* Changing this attribute may change the height of the body 
	because of the disappearance and reappearance of the topic.
	It is easiest for us to keep a record of where we were before
	changing this attribute, then scroll to that. */
	var scrolledToBottom = TextualScroller.isScrolledToBottom();

	if (isSelected) {
		document.body.dataset.selected = "true";
	} else {
		document.body.dataset.selected = "false";
	}

	if (scrolledToBottom) {
		TextualScroller.scrollToBottom();
	}
};

Textual.viewBodyDidLoadInt = function() /* PRIVATE */
{
	console.warn("Textual.viewBodyDidLoadInt() is deprecated. Use _Textual.viewBodyDidLoad() instead.");

	_Textual.viewBodyDidLoad();
};

_Textual._viewBodyDidLoadAnimationFrame = null; /* PRIVATE */

_Textual.viewBodyDidLoad = function() /* PRIVATE */
{
	/* Wait until element is available before binding to it. */
	_TextualScroller.bindToBestElement();

	/* On styles with a dark background, a white flash occurs because there is a very
	 small delay between the view being created and the background process laying out
	 its contents. To work around this, Textual presents an overlay view that matches
	 the background color of the style. We then request an animation frame that calls
	 app.finishedLayingOutView, instructing Textual that it can destroy the overlay view. */

	_Textual._viewBodyDidLoadAnimationFrame =
	window.requestAnimationFrame(function() {
		_Textual._viewBodyDidLoad();
	});
};

_Textual._viewBodyDidLoad = function() /* PRIVATE */
{
	_Textual._viewBodyDidLoadAnimationFrame = null;

	appPrivate.finishedLayingOutView();

	Textual.viewBodyDidLoad();
};

_Textual.viewFinishedLoading = function(configuration) /* PRIVATE */
{
	var isSelected = configuration.selected;
	var isVisible = configuration.visible;
	var isReloadingTheme = configuration.reloadingTheme;
	var textSizeMultiplier = configuration.textSizeMultiplier;
	var scrollbackLimit = configuration.scrollbackLimit;

	_TextualScroller.createMutationObserver();

	if (isVisible) {
		_Textual.notifyDidBecomeVisible();

		_Textual.notifySelectionChanged(isSelected);
	} else {
		_Textual.notifyDidBecomeHidden();
	}

	if (isReloadingTheme) {
		Textual.viewFinishedReload();
	} else {
		Textual.viewFinishedLoading();
	}

	/* If this view is not visible to the user, then cancel the animation
	 frame set by Textual.viewBodyDidLoadInt() because there is no use for it. */
	if (isVisible === false && isSelected === false) {
		if (_Textual._viewBodyDidLoadAnimationFrame) {
			window.cancelAnimationFrame(_Textual._viewBodyDidLoadAnimationFrame);

			_Textual._viewBodyDidLoad();
		}
	}

	Textual.changeTextSizeMultiplier(textSizeMultiplier);

	if (scrollbackLimit !== 0) { // 0 = use default
		_MessageBuffer.setBufferLimit(scrollbackLimit);
	}
};

_Textual.viewFinishedLoadingHistory = function() /* PRIVATE */
{
	Textual.finishedLoadingHistory = true;

	Textual.viewFinishedLoadingHistory();
};

_Textual.messageAddedToView = function(lineNumber, fromBuffer) /* PRIVATE */
{
	/* Allow lineNumber to be an array of line numbers or a single line number. */
	if (Array.isArray(lineNumber)) {
		for (var i = 0; i < lineNumber.length; i++) {
			Textual.messageAddedToView(lineNumber[i], fromBuffer);
		}
	} else {
		Textual.messageAddedToView(lineNumber, fromBuffer);
	}

	appPrivate.notifyLinesAddedToView(lineNumber);
};

_Textual.messageRemovedFromView = function(lineNumber) /* PRIVATE */
{
	/* Allow lineNumber to be an array of line numbers or a single line number. */
	if (Array.isArray(lineNumber)) {
		for (var i = 0; i < lineNumber.length; i++) {
			Textual.messageRemovedFromView(lineNumber[i]);
		}
	} else {
		Textual.messageRemovedFromView(lineNumber);
	}

	appPrivate.notifyLinesRemovedFromView(lineNumber);
};

/* Events */
_Textual._mouseUpEventCallback = function() /* PRIVATE */
{
	_Textual.copySelectionOnMouseUpEvent();
};

/* Bind to events */
document.addEventListener("mouseup", _Textual._mouseUpEventCallback, false);
