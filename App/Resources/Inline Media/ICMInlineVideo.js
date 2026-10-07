/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2017, 2018 Codeux Software, LLC & respective contributors.
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

var _ICMInlineVideoPrototypeParent = InlineMediaPrototype;

var _ICMInlineVideoPrototype = function() {  
	_ICMInlineVideoPrototypeParent.call(this);
}

_ICMInlineVideoPrototype.prototype = Object.create(InlineMediaPrototype.prototype);
_ICMInlineVideoPrototype.prototype.constructor = _ICMInlineVideoPrototype;
_ICMInlineVideoPrototype.prototype.superClass = _ICMInlineVideoPrototypeParent.prototype;

var _ICMInlineVideo = new _ICMInlineVideoPrototype();

_ICMInlineVideo.metadataLoadedCallback = function()
{
	var video = event.target;

	/* Video start time */
	var startTime = parseFloat(video.dataset.start);

	if (startTime > 0.0) {
		video.currentTime = startTime;
	}

	/* Video playback speed (rate) */
	var playbackSpeed = parseFloat(video.dataset.speed);

	if (playbackSpeed !== 1.0) {
		video.playbackRate = playbackSpeed;
	}
};

_ICMInlineVideo.dataLoadedCallback = function()
{
	/* Loading data can change the height of the video once 
	we know what it truly will be. We therefore have to tell
	the scroller to restore the scroll position. */

	TextualScroller.restoreScrolledToBottom();
};
