/*
 Copyright (c) 2011, Tony Million.
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 */

#import <SystemConfiguration/SystemConfiguration.h>

#import "OELReachability.h"

NS_ASSUME_NONNULL_BEGIN

@interface OELReachability ()
@property (nonatomic, assign) SCNetworkReachabilityRef reachabilityRef;

- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags;
@end

static void TMReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
	OELReachability *reachability = ((__bridge OELReachability *)info);

	[reachability reachabilityChanged:flags];
}

@implementation OELReachability

+ (nullable OELReachability *)reachabilityForInternetConnection
{
	SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, "www.google.com");

	if (ref) {
		return [[self alloc] initWithReachabilityRef:ref];
	}

	return nil;
}

- (OELReachability *)initWithReachabilityRef:(SCNetworkReachabilityRef)ref
{
	if ((self = [super init]))
	{
		self.reachabilityRef = ref;
	}

	return self;
}

- (void)dealloc
{
	[self stopNotifier];

	if (self.reachabilityRef)
	{
		CFRelease(self.reachabilityRef);
				  self.reachabilityRef = nil;
	}

	self.reachableBlock	= nil;
	self.unreachableBlock = nil;
}

- (BOOL)startNotifier
{
	SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};

	if (SCNetworkReachabilitySetCallback(self.reachabilityRef, TMReachabilityCallback, &context)) {
		if (SCNetworkReachabilityScheduleWithRunLoop(self.reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode))
		{
			return YES;
		}
	}

	return NO;
}

- (void)stopNotifier
{
	SCNetworkReachabilitySetCallback(self.reachabilityRef, NULL, NULL);

	SCNetworkReachabilityUnscheduleFromRunLoop(self.reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
}

- (BOOL)isReachableWithFlags:(SCNetworkReachabilityFlags)flags
{
	if ((flags & kSCNetworkReachabilityFlagsReachable) == kSCNetworkReachabilityFlagsReachable) {
		return YES;
	} else {
		return NO;
	}
}

- (BOOL)isReachable
{
	SCNetworkReachabilityFlags flags;

	if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags) == FALSE) {
		return NO;
	}

	return [self isReachableWithFlags:flags];
}

- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags
{
	if ([self isReachableWithFlags:flags]) {
		if (self.reachableBlock) {
			self.reachableBlock(self);
		}
	} else {
		if (self.unreachableBlock) {
			self.unreachableBlock(self);
		}
	}
}

@end

NS_ASSUME_NONNULL_END
