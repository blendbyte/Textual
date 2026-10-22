/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 *    Copyright (c) 2018 Codeux Software, LLC & respective contributors.
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

#import "IRCCommandIndex.h"

NS_ASSUME_NONNULL_BEGIN

/* The response of some commands are shown and hidden depending
 on who sent the command. IRCClientRequestedCommands is used by
 IRCClient internally to keep track of what commands have been
 requested so that it can determine how to treat the response. */
/* IRCClientRequestedCommands works in conjunction with IRCClient
 by balancing all calls to a command. */

@interface IRCClientRequestedCommands : NSObject
- (void)removeCommands;
@end

#pragma mark -

@interface IRCClientRequestedCommands (Helpers)
#pragma mark -
#pragma mark ISON Command (Default: hidden)

@property (readonly, getter=inVisibleIsonRequest) BOOL visibleIsonRequest;
- (void)recordIsonRequestOpenedWithCount:(NSUInteger)count; // hidden, one reply per line sent
- (void)recordIsonRequestOpenedAsVisible;
- (void)recordIsonRequestClosed;
- (BOOL)recordIsonReplyReceived; // YES once every line of a hidden request was answered

#pragma mark -
#pragma mark WHO Command (Default: hidden)

@property (readonly, getter=inVisibleWhoRequest) BOOL visibleWhoRequest;
- (void)recordWhoRequestOpened;
- (void)recordWhoRequestOpenedAsVisible;
- (void)recordWhoRequestClosed;
@end

NS_ASSUME_NONNULL_END
