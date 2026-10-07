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

NS_ASSUME_NONNULL_BEGIN

/* One URL session for every inline media request (the media assessor,
 the JSON lookups, and later the link cards). Ephemeral: no cookies, no
 cache, no credentials. Requests time out after 20 seconds, at most 5
 redirects are followed, and every address, including each redirect, is
 refused if it points at the local network (R1.7): loopback, private,
 link-local, unique local, multicast, .local and single-label names, and
 host names that resolve to any of these. Callbacks and completion blocks
 run on the main thread. Clicking a refused link still opens it. */
@interface ICLURLSession : NSObject
@property (readonly, class) NSURLSession *sharedSession;

/* YES for an HTTP(S) URL whose host is not a local address or name.
 Does not resolve the host name. */
+ (BOOL)URLIsAllowed:(NSURL *)url;

/* +URLIsAllowed: and, for host names, a lookup of their addresses */
+ (void)checkURL:(NSURL *)url completionBlock:(void (^)(BOOL allowed))completionBlock;

/* GET with a response size limit. data is nil when the address is refused,
 the request fails, the status is not 200 or the body exceeds maximumLength. */
+ (void)requestDataFromURL:(NSURL *)url maximumLength:(NSUInteger)maximumLength completionBlock:(void (^)(NSData * _Nullable data))completionBlock;
@end

NS_ASSUME_NONNULL_END
