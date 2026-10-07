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
- (void)recordIsonRequestOpened;
- (void)recordIsonRequestOpenedAsVisible;
- (void)recordIsonRequestClosed;

#pragma mark -
#pragma mark MONITOR Command (Default: hidden)

#if 0
/* The MONITOR command can perform multiple actions which means its results
 do not always have a predetermined number of results or an end numeric. */
/* To work around this, we feed IRCClientRequestedCommands an estimate
 of the number of responses to expect. We then decrement that by calling
 the *ClosedOne for each response received. When the count reaches zero,
 the request is automatically closed without calling *Closed. */
/* If we encounter an error, we instead call *Closed which ends the request there. */
@property (readonly, getter=inVisibleMonitorRequest) BOOL visibleMonitorRequest;
- (void)recordMonitorRequestOpened; // No limit on count
- (void)recordMonitorRequestOpenedWithCount:(NSUInteger)count;
- (void)recordMonitorRequestOpenedAsVisible; // No limit on count
- (void)recordMonitorRequestOpenedAsVisibleWithCount:(NSUInteger)count;
- (void)recordMonitorRequestClosedOne; // Does nothing if no count is specified
- (void)recordMonitorRequestClosed;

#pragma mark -
#pragma mark NAMES Command (Default: hidden)

@property (readonly, getter=inVisibleNamesRequest) BOOL visibleNamesRequest;
- (void)recordNamesRequestOpened;
- (void)recordNamesRequestOpenedAsVisible;
- (void)recordNamesRequestClosed;

#pragma mark -
#pragma mark WATCH Command (Default: hidden)

@property (readonly, getter=inVisibleWatchRequest) BOOL visibleWatchRequest;
- (void)recordWatchRequestOpened; // No limit on count
- (void)recordWatchRequestOpenedWithCount:(NSUInteger)count;
- (void)recordWatchRequestOpenedAsVisible; // No limit on count
- (void)recordWatchRequestOpenedAsVisibleWithCount:(NSUInteger)count;
- (void)recordWatchRequestClosedOne; // Does nothing if no count is specified
- (void)recordWatchRequestClosed;
#endif

#pragma mark -
#pragma mark WHO Command (Default: hidden)

@property (readonly, getter=inVisibleWhoRequest) BOOL visibleWhoRequest;
- (void)recordWhoRequestOpened;
- (void)recordWhoRequestOpenedAsVisible;
- (void)recordWhoRequestClosed;
@end

NS_ASSUME_NONNULL_END
