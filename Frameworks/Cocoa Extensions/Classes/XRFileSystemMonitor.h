/* *********************************************************************
 *
 *           Copyright (c) 2020 Codeux Software, LLC
 *     Please see ACKNOWLEDGEMENT for additional information.
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
 *  * Neither the name of "Codeux Software, LLC", nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
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

/*
 XRFileSystemMonitor can be used to monitor changes to one or more
 directories or files by abstracting away interactions with FSEvents.

 The following flags are set for monitoring:
 • kFSEventStreamCreateFlagFileEvents
 • kFSEventStreamCreateFlagNoDefer

 A context object of any type can be assigned to specific URLs.
*/
@class XRFileSystemEvent;

typedef void (^XRFileSystemMonitorCallbackBlock)(NSArray<XRFileSystemEvent *> *events);

@interface XRFileSystemMonitor : NSObject
@property (nonatomic, readonly, getter=isMonitoring) BOOL monitoring;

- (instancetype)initWithFileURL:(NSURL *)url callbackBlock:(XRFileSystemMonitorCallbackBlock)callbackBlock NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFileURL:(NSURL *)url context:(nullable id)contextObject callbackBlock:(XRFileSystemMonitorCallbackBlock)callbackBlock NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithFileURLs:(NSArray<NSURL *> *)urls callbackBlock:(XRFileSystemMonitorCallbackBlock)callbackBlock NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFileURLs:(NSArray<NSURL *> *)urls context:(nullable NSDictionary<NSURL *, id> *)contextObjects callbackBlock:(XRFileSystemMonitorCallbackBlock)callbackBlock NS_DESIGNATED_INITIALIZER;

- (void)startMonitoring; // latency = 0.0
- (void)startMonitoringWithLatency:(NSTimeInterval)latency; // Will replace monitor if one is active

- (void)stopMonitoring;

- (nullable id)contextObjectForURL:(NSURL *)url;
@end

@interface XRFileSystemEvent : NSObject
@property (nonatomic, readonly, copy) NSURL *url;
@property (nonatomic, readonly) FSEventStreamEventFlags flags;
@property (nonatomic, readonly) FSEventStreamEventId identifier;
@property (nonatomic, readonly, strong, nullable) id context;
@end

NS_ASSUME_NONNULL_END
