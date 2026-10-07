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

var MessageBuffer = {};
var _MessageBuffer = {};

/* ************************************************** */
/*                   State Tracking                   */
/* ************************************************** */

/* The number of elements in the buffer. 
This count only includes lines (messages). Not other
items that the style may insert into the buffer. */
_MessageBuffer._bufferCurrentSize = 0; /* PRIVATE */

/* When old messages are NOT being loaded, this 
is the number of elements we want to keep. */
_MessageBuffer._bufferSizeSoftLimitDefault = 200; /* PRIVATE */
_MessageBuffer._bufferSizeSoftLimit = _MessageBuffer._bufferSizeSoftLimitDefault; /* PRIVATE */

/* When old messages are being loaded, this 
is the number of elements we want to keep. */
_MessageBuffer._bufferSizeHardLimitDefault = 1000; /* PRIVATE */
_MessageBuffer._bufferSizeHardLimit = _MessageBuffer._bufferSizeHardLimitDefault; /* PRIVATE */

/* The number of lines to fetch when loading old messages.
When old lines are fetched, the number of lines returned 
are also removed from the relevant buffer. */
_MessageBuffer._loadMessagesBatchSize = 200; /* PRIVATE */

/* _MessageBuffer._loadMessages() sets the following properties
when it performs an action. These properties are not used for
anything other than state tracking. If false, new messages are
loaded, else the event is ignored. */
/* The user can scroll downward while messages are still being
loaded from scrolling upward. Therefore, we use a separate 
property to keep track of each type of load. */ 
_MessageBuffer._loadingMessagesBeforeLineDuringScroll = false; /* PRIVATE */
_MessageBuffer._loadingMessagesAfterLineDuringScroll = false; /* PRIVATE */

/* Set to true once we have loaded all old messages. */
_MessageBuffer._bufferTopIsComplete = false; /* PRIVATE */
_MessageBuffer._bufferBottomIsComplete = true; /* PRIVATE */

/* _MessageBuffer._jumpToLine() sets the following property
when it performs an action. */
_MessageBuffer._loadingMessagesDuringJump = false; /* PRIVATE */

/* ************************************************** */
/*                  Line Management                   */
/* ************************************************** */

MessageBuffer.firstLineInBuffer = function(buffer) /* PUBLIC */
{
	var lines = buffer.querySelectorAll("div.line[id^='line-']");

	return lines[0];
};

MessageBuffer.lastLineInBuffer = function(buffer) /* PUBLIC */
{
	var lines = buffer.querySelectorAll("div.line[id^='line-']");

	return lines[(lines.length - 1)];
};

/* ************************************************** */
/*                  Main Buffer                       */
/* ************************************************** */

_MessageBuffer._bufferElementReference = null; /* PRIVATE */

MessageBuffer.bufferElement = function() /* PUBLIC */
{
	if (_MessageBuffer._bufferElementReference === null) {
		_MessageBuffer._bufferElementReference = document.getElementById("messageBuffer");
	}

	return _MessageBuffer._bufferElementReference;
};

MessageBuffer.bufferElementPrepend = function(html, lineNumbers) /* PUBLIC */
{
	_MessageBuffer.bufferElementInsert("afterbegin", html, lineNumbers);
};

MessageBuffer.bufferElementAppend = function(html, lineNumbers) /* PUBLIC */
{
	_MessageBuffer.bufferElementInsert("beforeend", html, lineNumbers);
};

_MessageBuffer.bufferElementInsert = function(placement, html, lineNumbers) /* PRIVATE */
{
	/* Do not append to bottom if bottom does not reflect
	the most recent state of the buffer. */
	if (_MessageBuffer._bufferBottomIsComplete === false) {
		return;
	}

	var buffer = MessageBuffer.bufferElement();

	buffer.prepareForMutation();

	buffer.insertAdjacentHTML(placement, html);

	if (lineNumbers) {
		_MessageBuffer._bufferCurrentSize += lineNumbers.length;

		_MessageBuffer.resizeBufferIfNeeded();

		try {
			_Textual.messageAddedToView(lineNumbers, false);
		} catch (error) {
			console.error(error);			
		}
	}
};

/* ************************************************** */
/*               Buffer Size Management               */
/* ************************************************** */

MessageBuffer.noteMessageRemovedFromBuffer = function()
{
	_MessageBuffer._adjustCurrentBufferSize(-1);
};

MessageBuffer.noteMessagesRemovedFromBuffer = function(numberRemoved)
{
	_MessageBuffer._adjustCurrentBufferSize(-1 * numberRemoved);
};

_MessageBuffer._adjustCurrentBufferSize = function(byHowMuch)
{
	console.log("Adjusting buffer by: " + byHowMuch);
	
	var newSize = (_MessageBuffer._bufferCurrentSize + byHowMuch);

	if (newSize < 0) {
		newSize = 0;
	} else if (newSize > _MessageBuffer._bufferSizeHardLimit) {
		newSize = _MessageBuffer._bufferSizeHardLimit;
	}

	_MessageBuffer._bufferCurrentSize = newSize;
	
	console.log("Buffer adjusted to: " + newSize);
};

/* Allow user to set a custom buffer limit */
_MessageBuffer.setBufferLimit = function(limit) /* PRIVATE */
{
	if (limit < 100 || limit > 50000) {
		_MessageBuffer._bufferSizeSoftLimit = _MessageBuffer._bufferSizeSoftLimitDefault;
		_MessageBuffer._bufferSizeHardLimit = _MessageBuffer._bufferSizeHardLimitDefault;
	} else {
		_MessageBuffer._bufferSizeSoftLimit = limit;
		_MessageBuffer._bufferSizeHardLimit = limit;
	}
};

/* Determine whether buffer should be resized depending on status. */
_MessageBuffer.resizeBufferIfNeeded = function() /* PRIVATE */
{
	/* We remove lines under the conditions:
	1. Size limit must be exceeded. 
	2. When user is not scrolled, we remove from the top of the buffer.
	3. When user is scrolled below 50% of the scrollable area, then we
	   remove from the bottom of the buffer.
	4. When user is scrolled above 50% of the scrollable area, then we
	   remove form the top of the buffer. */

	/* Enforce soft limit for #2 */
	if (_MessageBuffer.scrolledToBottomOfBuffer()) {
		_MessageBuffer.enforceSoftLimit(true);

		return;
	}

	/* Enforce hard limit for #3 and #4 */
	var scrollPercent = TextualScroller.percentScrolled();

	var removeFromTop = (scrollPercent > 50.0);

	_MessageBuffer.enforceHardLimit(removeFromTop);
};

/* Given number of lines added: enforce limit and remove from top or bottom. */
_MessageBuffer.enforceSoftLimit = function(fromTop) /* PRIVATE */
{
	_MessageBuffer.enforceLimit(_MessageBuffer._bufferSizeSoftLimit, fromTop);
};

_MessageBuffer.enforceHardLimit = function(fromTop) /* PRIVATE */
{
	_MessageBuffer.enforceLimit(_MessageBuffer._bufferSizeHardLimit, fromTop);
};

_MessageBuffer.enforceLimit = function(limit, fromTop) /* PRIVATE */
{
	var numberToRemove = (_MessageBuffer._bufferCurrentSize - limit);

	if (numberToRemove <= 0) {
		return;
	}

	_MessageBuffer.resizeBuffer(numberToRemove, fromTop);
};

_MessageBuffer.resizeBuffer = function(numberToRemove, fromTop) /* PRIVATE */
{
	if (numberToRemove <= 0) {
		throw "Silly number to remove";
	}

	var lineNumbers = new Array();

	var buffer = MessageBuffer.bufferElement();

	buffer.prepareForMutation();

	var numberRemoved = 0;

	/* To avoid an infinite loop by never having a 
	firstChild or lastChild that is a line, we use
	siblings and break when there are none left. */
	var currentElement = null;
	var nextElement = null;

	do {
		if (currentElement === null) {
			if (fromTop) {
				currentElement = buffer.firstChild;
			} else {
				currentElement = buffer.lastChild;
			}
		} else {
			currentElement = nextElement;
		}

		if (currentElement === null) {
			break;
		}

		if (fromTop) {
			nextElement = currentElement.nextElementSibling;
		} else {
			nextElement = currentElement.previousElementSibling;
		}

		var elementId = currentElement.id;

		if (elementId && elementId.indexOf("line-") === 0) {
			/* We wait until the next line element before 
			exiting loop so that we can remove markers or
			anything related to lines that were removed. */
			if (numberRemoved >= numberToRemove) {
				break;
			}

			lineNumbers.push(elementId);

			numberRemoved += 1;
		}

		currentElement.remove();
	} while (true); // lol, I know.

	if (fromTop) {
		_MessageBuffer._bufferTopIsComplete = false;
	} else {
		_MessageBuffer._bufferBottomIsComplete = false;
	}

	var lineNumbersCount = lineNumbers.length;

	if (lineNumbersCount > 0) {
		_MessageBuffer._bufferCurrentSize -= lineNumbersCount;

		_Textual.messageRemovedFromView(lineNumbers);
	}

	console.log("Removed " + lineNumbersCount + " lines from buffer");
};

/* Timer set once user scrolls back to the bottom. */
/* Timer is used in case user scrolls back up shortly after. */
_MessageBuffer._bufferHardLimitResizeTimer = null; /* PRIVATE */

_MessageBuffer.cancelHardLimitResize = function() /* PRIVATE */
{
	if (_MessageBuffer._bufferHardLimitResizeTimer === null) {
		return;
	}

	clearTimeout(_MessageBuffer._bufferHardLimitResizeTimer);

	_MessageBuffer._bufferHardLimitResizeTimer = null;
};

_MessageBuffer.scheduleHardLimitResize = function() /* PRIVATE */
{
	if (_MessageBuffer._bufferHardLimitResizeTimer !== null) {
		return;
	}

	/* Do not create timer if we are scrolling programmatically */
	if (_MessageBuffer._loadingMessagesDuringJump) {
		return;
	}

	/* No need to create timer if we haven't exceeded hard limit. */
	if (_MessageBuffer._bufferCurrentSize <= _MessageBuffer._bufferSizeSoftLimit) {
		return;
	}

	/* Do not create timer if we aren't at the true bottom. */
	if (_MessageBuffer.scrolledToBottomOfBuffer() === false) {
		return;
	}

	/* Create timer */
	_MessageBuffer._bufferHardLimitResizeTimer =
	setTimeout(function() {
		console.log("Buffer hard limit resize timer fired");

		var numberToRemove = (_MessageBuffer._bufferCurrentSize - _MessageBuffer._bufferSizeSoftLimit);

		if (numberToRemove <= 0) {
			return;
		}

		_MessageBuffer.resizeBuffer(numberToRemove, true);

		_MessageBuffer._bufferHardLimitResizeTimer = null;
	}, 5000);

	console.log("Buffer hard limit resize timer started");
};

/* ************************************************** */
/*                  Load Messages                     */
/* ************************************************** */

/* This function picks the best line to load old messages next to. */
_MessageBuffer.loadMessagesDuringScroll = function(before) /* PRIVATE */
{
	/* _MessageBuffer._loadMessages() is only called during scroll events by
	the user. We keep track of a request is already active then so that we
	do not keep sending them out while the user waits for one to finish. */
	if (_MessageBuffer._loadingMessagesDuringJump) {
		console.log("Cancelled request to load messages because another request is active");

		return;
	}

	if (before) 
	{
		if (Textual.finishedLoadingHistory === false) {
			console.log("Cancelled request to load messages above line because history isn't loaded");

			return;
		}

		if (_MessageBuffer._loadingMessagesBeforeLineDuringScroll) {
			console.log("Cancelled request to load messages above line because another request is active");

			return;
		}

		if (_MessageBuffer._bufferTopIsComplete) {
			console.log("Cancelled request to load messages because there is nothing new to load");

			return;
		}
	}
	else // before
	{
		if (_MessageBuffer._loadingMessagesAfterLineDuringScroll) {
			console.log("Cancelled request to load messages below line because another request is active");

			return;
		}

		if (_MessageBuffer._bufferBottomIsComplete) {
			console.log("Cancelled request to load messages because there is nothing new to load");

			return;
		}
	}

	/* Find first line */	
	var buffer = MessageBuffer.bufferElement();

	var line = null;

	if (before) {
		line = MessageBuffer.firstLineInBuffer(buffer);
	} else {
		line = MessageBuffer.lastLineInBuffer(buffer);
	}

	/* There is nothing in either buffer */
	if (line === null) {
		console.log("No line to load from");

		return;
	}

	/* Load messages */
	if (before) {
		_MessageBuffer._loadingMessagesBeforeLineDuringScroll = true;
	} else {
		_MessageBuffer._loadingMessagesAfterLineDuringScroll = true;
	}

	var lineNumberContents = line.id.lineNumberContents();

	_MessageBuffer.loadMessagesDuringScrollWithPayload(
		{
			"before" : before,
			"line" : line,
			"lineNumberContents" : lineNumberContents
		}
	);
};

/* Given a line we want to load old messages next to, we do so. */
_MessageBuffer.loadMessagesDuringScrollWithPayload = function(requestPayload) /* PRIVATE */
{
	var before = requestPayload.before;
	var line = requestPayload.line;
	var lineNumberContents = requestPayload.lineNumberContents;

	/* Define logic that will be performed when 
	are are ready to load the messages. */
	var loadMessagesLogic = (function() {
		var postflightCallback = (function(renderedMessages) {
			requestPayload.renderedMessages = renderedMessages;

			_MessageBuffer.loadMessagesDuringScrollWithPayloadPostflight(requestPayload);

			_MessageBuffer.removeLoadingIndicator(line);
		});

		console.log("Loading messages before (" + before  + ") line " + lineNumberContents);

		if (before) {
			appPrivate.renderMessagesBefore(
				lineNumberContents, 
				_MessageBuffer._loadMessagesBatchSize, 
				postflightCallback
			);
		} else {
			appPrivate.renderMessagesAfter(
				lineNumberContents, 
				_MessageBuffer._loadMessagesBatchSize, 
				postflightCallback
			);
		}
	});

	/* Present loading indicator then trigger logic. */
	_MessageBuffer.addLoadingIndicator(before, line, loadMessagesLogic);
};

/* Postflight for loading old messages */
_MessageBuffer.loadMessagesDuringScrollWithPayloadPostflight = function(requestPayload) /* PRIVATE */
{
	/* Payload state */
	var before = requestPayload.before;
	var line = requestPayload.line;
	var renderedMessages = requestPayload.renderedMessages;

	var lineNumbers = null;
	var html = null;

	/* Perform logging */
	var renderedMessagesCount = renderedMessages.length;

	console.log("Request to load messages for " + line.id + " returned " + renderedMessagesCount + " results");

	if (renderedMessagesCount > 0) {
		/* Array which will house every line number that was loaded. 
		The style needs this information so it can perform whatever action. */
		lineNumbers = new Array();

		/* Array which will house every segment of HTML to append. */
		html = new Array();

		/* Process result */
		for (var i = 0; i < renderedMessagesCount; i++) {
			var renderedMessage = renderedMessages[i];

			var lineNumber = renderedMessage.lineNumber;

			if (lineNumber) {
				lineNumbers.push(renderedMessage.lineNumber);
			}

			html.push(renderedMessage.html);
		}

		/* Append HTML */
		var htmlString = html.join("");

		if (before) {
			line.prepareForMutation();

			line.insertAdjacentHTML('beforebegin', htmlString);
		} else {
			line.insertAdjacentHTML('afterend', htmlString);
		}

		_MessageBuffer._bufferCurrentSize += lineNumbers.length;
	} // renderedMessagesCount > 0

	/* If the number of results is less than our batch size,
	then we can probably make a best guess that we have loaded
	all the old messages that are available. */
	if (renderedMessagesCount < _MessageBuffer._loadMessagesBatchSize) {
		if (before) {
			_MessageBuffer._bufferTopIsComplete = true;
		} else {
			_MessageBuffer._bufferBottomIsComplete = true;
		}
	}

	if (renderedMessagesCount > 0) {
		/* Enforce size limit. This function expects the count to already be 
		incremented which is why we call it AFTER the append. */
		/* Value of before is reversed because we want to remove from the
		opposite of where we added. */
		_MessageBuffer.enforceHardLimit(!before);

		/* Cancel any mutations already queued so that we don't scroll. */
		/* Place after resizeBuffer() because that triggers a mutation. */
		line.cancelMutation();

		/* Post line numbers so style can do something with them. */
		try {
			_Textual.messageAddedToView(lineNumbers, true);
		} catch (error) {
			console.error(error);			
		}

		/* Scroll line into view */
		if (before) {
			line.scrollIntoViewAlignTop();
		} else {
			line.scrollIntoViewAlignBottom();
		}
	} // renderedMessagesCount > 0

	/* Toggle automatic scrolling */
	/* Call after resize so that it has latest state of bottom. */
	_MessageBuffer.toggleAutomaticScrolling();

	/* Flush state */
	if (before) {
		_MessageBuffer._loadingMessagesBeforeLineDuringScroll = false;
	} else {
		_MessageBuffer._loadingMessagesAfterLineDuringScroll = false;
	}
};

_MessageBuffer.loadMessagesWithJump = function(lineNumber, callbackFunction) /* PRIVATE */
{
	/* Safety checks */
	if (_MessageBuffer._loadingMessagesDuringJump) {
		console.log("Cancelled request to load messages because another request is active");

		return;
	}

	if (Textual.finishedLoadingHistory === false) {
		console.log("Cancelled request to load messages because history isn't loaded");

		return;
	}

	if (_MessageBuffer._loadingMessagesBeforeLineDuringScroll ||
		_MessageBuffer._loadingMessagesAfterLineDuringScroll) 
	{
		console.log("Cancelled request to load messages because another request is active");

		return;
	}

	if (_MessageBuffer._bufferTopIsComplete &&
		_MessageBuffer._bufferBottomIsComplete) 
	{
		console.log("Cancelled request to load messages because there is nothing new to load");

		return;
	}

	/* This function may be called without scrolling which means we
	should cancel the resize timer. */
	_MessageBuffer.cancelHardLimitResize();

	/* The line does not exist in the buffer, which means we have to 
	load it. When we load the message, we also load X number of messages
	above it and X number of messages below it. */
	/* When jumping, we do not use the message buffer loading indicator
	because the user does not require a visual indicator. */
	_MessageBuffer._loadingMessagesDuringJump = true;

	var lineNumberContents = lineNumber.lineNumberContents();

	var requestPayload = {
		"lineNumberContents" : lineNumberContents,
		"lineNumberStandardized" : lineNumber,
		"callbackFunction" : callbackFunction
	};

	console.log("Loading line " + lineNumberContents);

	appPrivate.renderMessageWithSiblings(
		lineNumberContents,

		_MessageBuffer._loadMessagesBatchSize, // load X above
		_MessageBuffer._loadMessagesBatchSize, // load X below

		(function(renderedMessages) {
			requestPayload.renderedMessages = renderedMessages;

			_MessageBuffer.loadMessagesWithJumpPostflight(requestPayload);
		})
	);
};

_MessageBuffer.loadMessagesWithJumpPostflight = function(requestPayload) /* PRIVATE */
{
	/* Payload state */
	var callbackFunction = requestPayload.callbackFunction;
	var lineNumberContents = requestPayload.lineNumberContents;
	var lineNumberStandardized = requestPayload.lineNumberStandardized;
	var renderedMessages = requestPayload.renderedMessages;

	var lineNumbers = null;
	var html = null;

	/* Perform logging */
	var renderedMessagesCount = renderedMessages.length;

	console.log("Request to load messages for " + lineNumberContents + " returned " + renderedMessagesCount + " results");

	if (renderedMessagesCount > 0) {
		/* Array which will house every line number that was loaded. 
		The style needs this information so it can perform whatever action. */
		lineNumbers = new Array();

		/* Array which will house every segment of HTML to append. */
		html = new Array();

		/* Process result */
		for (var i = 0; i < renderedMessagesCount; i++) {
			var renderedMessage = renderedMessages[i];

			var lineNumber = renderedMessage.lineNumber;

			if (lineNumber) {
				lineNumbers.push(renderedMessage.lineNumber);
			}

			html.push(renderedMessage.html);
		}

		/* When we jump to a line that is not visible, we replace 
		the entire buffer with the rendered messages. This avoids 
		the hassle of having to navigate the DOM merging lines. 
		This may change in the future based on user feedback,
		but for now this is acceptable. */

		/* Append HTML */
		var htmlString = html.join("");

		var buffer = MessageBuffer.bufferElement();

		buffer.insertAdjacentHTML('afterbegin', htmlString);

		/* Resize the buffer by removing messages from the bottom
		so that the only lines that remain are those appended. */
		_MessageBuffer.resizeBuffer(_MessageBuffer._bufferCurrentSize, false);

		/* Cancel any mutations already queued so that we don't scroll. */
		/* Place after resizeBuffer() because that triggers a mutation. */
		buffer.cancelMutation();

		/* Update buffer size to include appended lines. */
		_MessageBuffer._bufferCurrentSize += lineNumbers.length;

		/* Post line numbers so style can do something with them. */
		try {
			_Textual.messageAddedToView(lineNumbers, true);
		} catch (error) {
			console.error(error);			
		}

		/* Toggle automatic scrolling */
		/* Call after resize so that it has latest state of bottom. */
		_MessageBuffer.toggleAutomaticScrolling();
	} // renderedMessagesCount > 0

	/* Try jumping to line and inform callback of result. */
	callbackFunction( 
		Textual.scrollToElement(lineNumberStandardized) 
	);

	/* Flush state */
	_MessageBuffer._loadingMessagesDuringJump = false;
};

/* ************************************************** */
/*                Loading Indicator                   */
/* ************************************************** */

_MessageBuffer.addLoadingIndicator = function(before, toLine, callbackFunction) /* PRIVATE */
{
	callbackFunction();
};

_MessageBuffer.removeLoadingIndicator = function(fromLine) /* PRIVATE */
{

};

/* ************************************************** */
/*                  Scrolling                         */
/* ************************************************** */

/* Scrolling */
_MessageBuffer._documentScrolledCallback = function(scrolledUpward) /* PRIVATE */
{
	if (scrolledUpward) {
		if (TextualScroller.isScrolledToTop()) {
			_MessageBuffer.loadMessagesDuringScroll(true);
		}

		_MessageBuffer.cancelHardLimitResize();
	}

	if (scrolledUpward === false && TextualScroller.isScrolledToBottom()) {
		_MessageBuffer.loadMessagesDuringScroll(false);

		_MessageBuffer.scheduleHardLimitResize();
	}
};

_MessageBuffer._documentScrolledUpwardCallback = function() /* PRIVATE */
{
	_MessageBuffer._documentScrolledCallback(true);
};

_MessageBuffer._documentScrolledDownwardCallback = function() /* PRIVATE */
{
	_MessageBuffer._documentScrolledCallback(false);
};

_MessageBuffer._automaticScrollingEnabled = true; /* PRIVATE */

_MessageBuffer.toggleAutomaticScrollingOn = function(turnOn) /* PRIVATE */
{
	if (_MessageBuffer._automaticScrollingEnabled !== turnOn) {
		_MessageBuffer._automaticScrollingEnabled = turnOn;
	} else {
		return;
	}

	if (turnOn) {
		appPrivate.setAutomaticScrollingEnabled(true);
	} else {
		appPrivate.setAutomaticScrollingEnabled(false);
	}
};

_MessageBuffer.toggleAutomaticScrolling = function() /* PRIVATE */
{
	_MessageBuffer.toggleAutomaticScrollingOn(_MessageBuffer._bufferBottomIsComplete);
};

_MessageBuffer.scrolledToBottomOfBuffer = function() /* PRIVATE */
{
	return (_MessageBuffer._bufferBottomIsComplete &&
			TextualScroller.isScrolledToBottom());
};

MessageBuffer.jumpToLine = function(lineNumber, callbackFunction) /* PUBLIC */
{
	var lineNumberStandardized = lineNumber.standardizedLineNumber();

	if (Textual.scrollToElement(lineNumberStandardized)) {
		callbackFunction(true);

		return;
	}

	_MessageBuffer.loadMessagesWithJump(lineNumberStandardized, callbackFunction);
};

/* Bind to events */
document.addEventListener("scrolledUpward", _MessageBuffer._documentScrolledUpwardCallback, false);
document.addEventListener("scrolledDownward", _MessageBuffer._documentScrolledDownwardCallback, false);
