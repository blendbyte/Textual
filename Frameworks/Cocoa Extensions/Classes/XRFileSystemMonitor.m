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

@interface XRFileSystemEvent ()
@property (nonatomic, readwrite, copy) NSURL *url;
@property (nonatomic, readwrite, assign) FSEventStreamEventFlags flags;
@property (nonatomic, readwrite, assign) FSEventStreamEventId identifier;
@property (nonatomic, readwrite, strong, nullable) id context;
@end

@interface XRFileSystemMonitor ()
@property (nonatomic, copy) NSArray<NSURL *> *urls;
@property (nonatomic, copy) XRFileSystemMonitorCallbackBlock callbackBlock;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *contextObjects; // URLs of context objects mapped to their file resource identifier
@property (nonatomic, assign, nullable) FSEventStreamRef eventStreamRef;
@end

@implementation XRFileSystemMonitor

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)init
{
	return nil;
}

- (instancetype)initWithFileURL:(NSURL *)url callbackBlock:(XRFileSystemMonitorCallbackBlock)callbackBlock
{
	return [self initWithFileURLs:@[url] context:nil callbackBlock:callbackBlock];
}

- (instancetype)initWithFileURL:(NSURL *)url context:(nullable id)contextObject callbackBlock:(XRFileSystemMonitorCallbackBlock)callbackBlock
{
	NSDictionary<NSURL *, id> *contextObjects = nil;

	if (contextObject) {
		contextObjects = @{url : contextObject};
	}

	return [self initWithFileURLs:@[url] context:contextObjects callbackBlock:callbackBlock];
}

- (instancetype)initWithFileURLs:(NSArray<NSURL *> *)urls callbackBlock:(XRFileSystemMonitorCallbackBlock)callbackBlock
{
	return [self initWithFileURLs:urls context:nil callbackBlock:callbackBlock];
}
#pragma clang diagnostic pop

- (instancetype)initWithFileURLs:(NSArray<NSURL *> *)urls context:(nullable NSDictionary<NSURL *, id> *)contextObjects callbackBlock:(XRFileSystemMonitorCallbackBlock)callbackBlock
{
	NSParameterAssert(callbackBlock != nil);
	NSParameterAssert(urls != nil);
	NSParameterAssert(urls.count > 0);

	if ((self = [super init])) {
		self.urls = urls;

		self.callbackBlock = callbackBlock;

		if (contextObjects) {
			self.contextObjects = [self remapContextObjects:contextObjects];
		}

		return self;
	}

	return nil;
}

- (void)dealloc
{
	[self stopMonitoring];
}

- (void)startMonitoring
{
	[self startMonitoringWithLatency:0.0];
}

- (void)startMonitoringWithLatency:(NSTimeInterval)latency
{
	[self stopMonitoring]; // Stop existing monitoring

	NSArray *urlsToWatch = self.urls;

	NSArray *pathsToWatch = [NSArray pathsArrayForFileURLs:urlsToWatch standardizingPaths:YES];

	CFArrayRef pathsToWatchRef = (__bridge CFArrayRef)pathsToWatch;

	FSEventStreamContext context;

	context.version = 0;
	context.info = (__bridge void *)(self);
	context.retain = NULL;
	context.release = NULL;
	context.copyDescription = NULL;

	FSEventStreamRef stream = FSEventStreamCreate(NULL,
												  &_monitorCallback,
												  &context,
												  pathsToWatchRef,
												  kFSEventStreamEventIdSinceNow,
												  latency,
												  (kFSEventStreamCreateFlagFileEvents |
												   kFSEventStreamCreateFlagNoDefer |
												   kFSEventStreamCreateFlagUseCFTypes));

	FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

	FSEventStreamStart(stream);

	self.eventStreamRef = stream;
}

- (void)stopMonitoring
{
	FSEventStreamRef eventStreamRef = self.eventStreamRef;

	if (eventStreamRef == NULL) {
		return;
	}

	FSEventStreamStop(eventStreamRef);
	FSEventStreamInvalidate(eventStreamRef);
	FSEventStreamRelease(eventStreamRef);

	self.eventStreamRef = NULL;
}

void _monitorCallback(ConstFSEventStreamRef streamRef,
					  void *clientCallBackInfo,
					  size_t numEvents,
					  void *eventPathsRef,
					  const FSEventStreamEventFlags eventFlags[],
					  const FSEventStreamEventId eventIds[])
{
	@autoreleasepool {
		XRFileSystemMonitor *monitor = (__bridge XRFileSystemMonitor *)(clientCallBackInfo);

		NSMutableArray<XRFileSystemEvent *> *events = [NSMutableArray arrayWithCapacity:numEvents];

		NSArray *eventPaths = (__bridge NSArray *)(eventPathsRef);

		for (NSUInteger i = 0; i < numEvents; i++) {
			FSEventStreamEventFlags flags = eventFlags[i];
			FSEventStreamEventId identifier = eventIds[i];

			NSString *filePath = eventPaths[i];

			NSURL *fileURL = [NSURL fileURLWithPath:filePath];

			id context = [monitor contextObjectForURL:fileURL];

			XRFileSystemEvent *event = [XRFileSystemEvent new];

			event.url = fileURL;
			event.flags = flags;
			event.identifier = identifier;
			event.context = context;

			[events addObject:event];
		} // for

		monitor.callbackBlock([events copy]);
	} // autorelease
}

- (BOOL)isMonitoring
{
	return (self.eventStreamRef != nil);
}

- (NSDictionary<NSString *, id> *)remapContextObjects:(NSDictionary<NSURL *, id> *)contextObjectsIn
{
	NSParameterAssert(contextObjectsIn != nil);

	NSMutableDictionary<NSString *, id> *contextObjectsOut = [NSMutableDictionary dictionaryWithCapacity:contextObjectsIn.count];

	[contextObjectsIn enumerateKeysAndObjectsUsingBlock:^(NSURL *urlIn, id object, BOOL *stop) {
		NSURL *urlOut = urlIn.URLByStandardizingPath;

		NSString *key = urlOut.filesystemRepresentationString;

		contextObjectsOut[key] = object;
	}];

	return [contextObjectsOut copy];
}

- (nullable id)contextObjectForURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSDictionary *contextObjects = self.contextObjects;

	if (contextObjects == nil) {
		return nil;
	}

	NSString *key = url.filesystemRepresentationString;

	return contextObjects[key];
}

@end

#pragma mark -

@implementation XRFileSystemEvent
@end

NS_ASSUME_NONNULL_END
