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

/* Private objects (kept when a template loads this file again) */
var _Textual = (window._Textual || {});

/* Resource management */
/* The core scripts are injected by Textual before the page loads (Textual 8);
templates written for Textual 7 still call this, so it stays, doing nothing. */
Textual.initializeCore = function(resourcesPath)
{
};

/* Only local files: a script or style sheet from the internet would run with the
 chat view's access to the app (R1.8). The content rules block such loads too. */
_Textual.resourceFileIsLocal = function(file)
{
	return (typeof file === "string" && /^[a-z][a-z0-9+.-]*:/i.test(file) === false && file.indexOf("//") !== 0) ||
		   (typeof file === "string" && file.toLowerCase().indexOf("file:") === 0);
};

Textual.includeStyleResourceFile = function(file)
{
	if (_Textual.resourceFileIsLocal(file) === false) {
		console.error("Refused a style sheet that is not a local file: " + file);

		return;
	}

	if (/loaded|complete/.test(document.readyState)) {
		var newFile = document.createElement("link");

		newFile.charset = "UTF-8";
		newFile.href = file;
		newFile.media = "screen";
		newFile.rel = "stylesheet";
		newFile.type = "text/css";

		document.getElementsByTagName("HEAD")[0].appendChild(newFile);
	} else {
		document.write('<link href="' + file + '" media="screen" rel="stylesheet" type="text/css" />');
	}
};

Textual.includeScriptResourceFile = function(file)
{
	if (_Textual.resourceFileIsLocal(file) === false) {
		console.error("Refused a script that is not a local file: " + file);

		return;
	}

	if (/loaded|complete/.test(document.readyState)) {
		var newFile = document.createElement("script");

		newFile.setAttribute("charset", "UTF-8");

		newFile.charset = "UTF-8";
		newFile.src = file;
		newFile.type = "text/javascript";

		document.getElementsByTagName("HEAD")[0].appendChild(newFile);
	} else {
		document.write('<script type="text/javascript" src="' + file + '"></scr' + 'ipt>');
	}
};
