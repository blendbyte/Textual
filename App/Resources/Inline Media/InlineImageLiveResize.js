/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2014 Alex Sørlie.
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

/* ************************************************** */
/*                                                    */
/* DO NOT OVERRIDE ANYTHING BELOW THIS LINE           */
/*                                                    */
/* ************************************************** */

var InlineImageLiveResize = (function () {
	function InlineImageLiveResize() {
	}

	InlineImageLiveResize.dragElement = null;
	InlineImageLiveResize.previousX = null;
	InlineImageLiveResize.previousY = null;
	InlineImageLiveResize.previousMouseActionWasForResizing = false;

	/* When the mouse down event is triggered on an element we set the target and record X,Y coordinates.
	 using preventDefault we halt the default actions taken by the browser, the user can use the shift
	 key to override InlineImageLiveResize behavior. */
	InlineImageLiveResize.onMouseDown = function (e) {
		if (window.event.shiftKey === false) {
			InlineImageLiveResize.dragElement = e.target;

			InlineImageLiveResize.previousX = e.clientX;
			InlineImageLiveResize.previousY = e.clientY;

			var computedSize = window.getComputedStyle(e.target, null);

			InlineImageLiveResize.dragElement.style.height = computedSize.getPropertyValue("height");
			InlineImageLiveResize.dragElement.style.width = computedSize.getPropertyValue("width");

			InlineImageLiveResize.dragElement.style.maxWidth = null;

			e.preventDefault();
		}
	};

	/* The browser has given us a frame to our work on, we will compare the new coordinates of the mouse
	 the old ones and resize the element accordingly */
	InlineImageLiveResize.updateImage = function (x, y) {
		if (InlineImageLiveResize.dragElement === null ||
			InlineImageLiveResize.dragElement === undefined)
		{
			return;
		}

		if (InlineImageLiveResize.previousMouseActionWasForResizing === false) {
			InlineImageLiveResize.previousMouseActionWasForResizing = true;
		}

		if (x > InlineImageLiveResize.previousX && y >= InlineImageLiveResize.previousY) {
			InlineImageLiveResize.dragElement.style.width = (InlineImageLiveResize.dragElement.offsetWidth + (x - InlineImageLiveResize.previousX));
			InlineImageLiveResize.dragElement.style.height = "auto";
		} else if (x < InlineImageLiveResize.previousX && y <= InlineImageLiveResize.previousY) {
			InlineImageLiveResize.dragElement.style.width = (InlineImageLiveResize.dragElement.offsetWidth - (InlineImageLiveResize.previousX - x));
			InlineImageLiveResize.dragElement.style.height = "auto";
		} else if (y > InlineImageLiveResize.previousY && x >= InlineImageLiveResize.previousX) {
			InlineImageLiveResize.dragElement.style.height = (InlineImageLiveResize.dragElement.offsetHeight + (y - InlineImageLiveResize.previousY));
			InlineImageLiveResize.dragElement.style.width = "auto";
		} else if (y < InlineImageLiveResize.previousY && x <= InlineImageLiveResize.previousX) {
			InlineImageLiveResize.dragElement.style.height = (InlineImageLiveResize.dragElement.offsetHeight - (InlineImageLiveResize.previousY - y));
			InlineImageLiveResize.dragElement.style.width = "auto";
		}

		InlineImageLiveResize.previousX = x;
		InlineImageLiveResize.previousY = y;
	};

	/* Document state tracking. */
	InlineImageLiveResize.onMouseDownGeneric = function (e) {
		InlineImageLiveResize.previousMouseActionWasForResizing = false;
	};

	/* When mouse movement is done we check if the user has clicked on an element previously.
	 We then request the next rendering frame of the browser to call our event to limit the
	 amount of resize calculations done to 60fps. */
	InlineImageLiveResize.onMouseMove = function (e) {
		if (InlineImageLiveResize.dragElement) {
			requestAnimationFrame(function () {
				InlineImageLiveResize.updateImage(e.clientX, e.clientY);
			});

			e.preventDefault();
		}
	};

	/* When the user releases their mouse button we abort the drag action and reset all variables */
	InlineImageLiveResize.onMouseUp = function (e) {
		if (InlineImageLiveResize.dragElement) {
			InlineImageLiveResize.dragElement = null;
			InlineImageLiveResize.previousX = null;
			InlineImageLiveResize.previousY = null;

			e.preventDefault();
		}
	};

	/* Called by image anchors to know whether to open link. */
	InlineImageLiveResize.negateAnchorOpen = function () {
		if (InlineImageLiveResize.previousMouseActionWasForResizing === true) {
			return false;
		} else {
			return true;
		}
	};

	return InlineImageLiveResize;
})();

/* Bind to events */
document.addEventListener("mousedown", InlineImageLiveResize.onMouseDownGeneric, false);
document.addEventListener("mousemove", InlineImageLiveResize.onMouseMove, false);
document.addEventListener("mouseup", InlineImageLiveResize.onMouseUp, false);
