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

#import "ICLMediaViewer.h"

NS_ASSUME_NONNULL_BEGIN

/* Clicking an image in the chat view: the image at its own
 size up to the screen, pinch to zoom; Open in Browser, Copy Link and Save
 to Downloads. WebKit decodes it, never Textual; saving writes the bytes
 as they were fetched, with the same checks. */
@interface ICLImageViewer : ICLMediaViewer
/* mediaURL is the image's textual-media: address in the chat view, so only
 an image Textual fetched with its checks can be opened; imageSize is its
 size as WebKit decoded it. An open viewer of the same image comes forward. */
+ (void)showImageAtMediaURL:(NSURL *)mediaURL linkURL:(NSURL *)linkURL imageSize:(NSSize)imageSize;

/* The name a saved image gets: the address's file name (path characters
 replaced, no leading dot) with the extension of its content type added
 unless it already has one of that type's, so the file opens as what it is */
+ (NSString *)fileNameForImageAtURL:(NSURL *)url contentType:(nullable NSString *)contentType;
@end

NS_ASSUME_NONNULL_END
