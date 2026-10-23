/*
Disclaimer: IMPORTANT:  This Apple software is supplied to you by 
Apple Inc. ("Apple") in consideration of your agreement to the
following terms, and your use, installation, modification or
redistribution of this Apple software constitutes acceptance of these
terms.  If you do not agree with these terms, please do not use,
install, modify or redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. 
may be used to endorse or promote products derived from the Apple
Software without specific prior written permission from Apple.  Except
as expressly stated in this notice, no other rights or licenses, express
or implied, are granted by Apple herein, including but not limited to
any patent rights that may be infringed by your derivative works or by
other works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright © 2007 Apple Inc. All Rights Reserved.
*/

#import <dns_sd.h>
#import <sys/types.h>
#import <sys/socket.h>
#import <net/if.h>
#import <netinet/in.h>
#import <ifaddrs.h>

NS_ASSUME_NONNULL_BEGIN

NSString * const XRPortMapperDidChangedNotification = @"XRPortMapperDidChangedNotification";

/** Converts a raw IPv4 address to an NSString in dotted-quad notation */
static NSString * _Nullable StringFromIPv4Addr(UInt32 ipv4Addr)
{
	if (ipv4Addr != 0) {
		const UInt8 *addrBytes = (const UInt8 *)&ipv4Addr;

		return [NSString stringWithFormat: @"%u.%u.%u.%u",
				(unsigned)addrBytes[0],
				(unsigned)addrBytes[1],
				(unsigned)addrBytes[2],
				(unsigned)addrBytes[3]];
	} else {
		return nil;
	}
}

// Redeclare these properties as settable, internally:
@interface XRPortMapper ()
@property (assign) BOOL serviceIsRunning;
@property (assign) UInt16 port;
@property (assign, readwrite) SInt32 error;
@property (assign, readwrite) unsigned short publicPort;
@property (assign) UInt32 rawPublicAddress;
@property (copy, readwrite, nullable) NSString *publicAddress;
@property (readonly, nullable) void *service;
@end

#pragma mark -

@implementation XRPortMapper

- (instancetype)init
{
	return [self initWithPort:0];
}

- (instancetype)initWithPort:(UInt16)port
{
	if ((self = [super init])) {
		self.port = port;

		self.mapTCP = YES;
		self.mapUDP = NO;

		return self;
	}

	return nil;
}

- (void)dealloc
{
	if (self.serviceIsRunning) {
		[self _disconnect];
	}
}

- (BOOL)isMapped
{
	return ( self.rawPublicAddress != 0 &&
			 self.rawPublicAddress != [[self class] rawLocalAddress]);
}

/** Called whenever the port mapping changes (see comment for callback, below.) */
- (void)_portMapStatus:(DNSServiceErrorType)errorCode
		 publicAddress:(UInt32)rawPublicAddress
			publicPort:(UInt16)publicPort
{
	/* Maybe define our own error if there is none set. */
	if (errorCode) {
		LogToConsoleErrorWithSubsystem(_CSFrameworkInternalLogSubsystem(),
			"Port-mapping resulted in error: %{public}i",
			errorCode);
	} else {
		if (publicPort == 0 && self.desiredPublicPort > 0) {
			errorCode = kDNSServiceErr_NATPortMappingUnsupported;
		}
	}

	/* Populate properties with relevant information. */
	self.error = errorCode;

	self.rawPublicAddress = rawPublicAddress;

	self.publicAddress = StringFromIPv4Addr(rawPublicAddress);
	self.publicPort = publicPort;

	/* Post notice of change. */
	[[NSNotificationCenter defaultCenter] postNotificationName:XRPortMapperDidChangedNotification
														object:self];
}

/** Asynchronous callback from DNSServiceNATPortMappingCreate.
 This is invoked whenever the status of the port mapping changes. */
static void portMapCallback (
		DNSServiceRef                    sdRef,
		DNSServiceFlags                  flags,
		uint32_t                         interfaceIndex,
		DNSServiceErrorType              errorCode,
		uint32_t                         publicAddress,    /* four byte IPv4 address in network byte order */
		DNSServiceProtocol               protocol,
		uint16_t                         privatePort,
		uint16_t                         publicPort,       /* may be different than the requested port */
		uint32_t                         ttl,              /* may be different than the requested ttl */
		void                             *context)
{
	[(__bridge XRPortMapper *)context _portMapStatus:errorCode
									   publicAddress:publicAddress
										  publicPort:ntohs(publicPort)];  // port #s in network byte order!
}

- (BOOL)open
{
	/* Do not continue if we are already doing something. */
	if (self.serviceIsRunning == NO) {
		self.serviceIsRunning = YES;
	} else {
		NSAssert(NO, @"Port mapping already in progress.");
	}

	/* Create the DNS service. */
	DNSServiceProtocol protocol = 0;

	if (self.mapTCP) {
		protocol |= kDNSServiceProtocol_TCP;
	}

	if (self.mapUDP) {
		protocol |= kDNSServiceProtocol_UDP;
	}

	DNSServiceErrorType status = kDNSServiceErr_NoError;

	status = DNSServiceNATPortMappingCreate(
				(DNSServiceRef *)&self->_service,
				0 /* flags */,
				0 /* interfaceIndex */,
				protocol,
				htons([self port]),
				htons([self desiredPublicPort]),
				0 /* ttl */,
				&portMapCallback,
				(__bridge void *)(self));


	if (status == kDNSServiceErr_NoError) {
		(void)DNSServiceSetDispatchQueue(self->_service, dispatch_get_main_queue());

		return YES;
	} else {
		[self close];

		self.error = kDNSServiceErr_Unknown;

		return NO;
	}
}

- (BOOL)waitUntilOpened
{
	if (self.serviceIsRunning == NO) {
		if ([self open] == NO) {
			return NO;
		}
	}

	while (self.error == 0 && self.publicAddress == nil) {
		if ([[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]] == NO) {
			break;
		}
	}

	return (self.error == 0);
}

// Close down, but _without_ clearing the 'error' property
- (void)_disconnect
{
	/* Close the service. */
	if (self->_service) {
		DNSServiceRefDeallocate(self->_service);

		self->_service = NULL;

		self.rawPublicAddress = 0;

		self.publicAddress = nil;
		self.publicPort = 0;
	}

	self.serviceIsRunning = NO;
}

- (void)close
{
	[self _disconnect];

	self.error = 0;
}

#pragma mark -

+ (UInt32)rawLocalAddress
{
	// getifaddrs returns a linked list of interface entries;
	// find the first active non-loopback interface with IPv4:
	UInt32 address = 0;

	struct ifaddrs *interfaces;

	if (getifaddrs(&interfaces) == 0) {
		struct ifaddrs *interface;

		for (interface = interfaces; interface; interface = interface->ifa_next) {
			if ((interface->ifa_flags & IFF_UP) && (interface->ifa_flags & IFF_LOOPBACK) == NO) {
				const struct sockaddr_in *_address = (const struct sockaddr_in *)interface->ifa_addr;

				if (_address && _address->sin_family == AF_INET ) {
					address = _address->sin_addr.s_addr;

					break;
				}
			}
		}

		freeifaddrs(interfaces);
	}

	return address;
}

+ (nullable NSString *)localAddress
{
	return StringFromIPv4Addr([self rawLocalAddress]);
}

// Private IP address ranges. See RFC 3330.
static const struct {UInt32 mask, value;} kPrivateRanges[] = {
	{0xFF000000, 0x00000000},       // 0.x.x.x (hosts on "this" network)
	{0xFF000000, 0x0A000000},       // 10.x.x.x (private address range)
	{0xFF000000, 0x7F000000},       // 127.x.x.x (loopback)
	{0xFFFF0000, 0xA9FE0000},       // 169.254.x.x (link-local self-configured addresses)
	{0xFFF00000, 0xAC100000},       // 172.(16-31).x.x (private address range)
	{0xFFFF0000, 0xC0A80000},       // 192.168.x.x (private address range)
	{0,0}
};

+ (BOOL)localAddressIsPrivate
{
	UInt32 address = ntohl([self rawLocalAddress]);

	for (NSUInteger i = 0; kPrivateRanges[i].mask; i++) {
		if ((address & kPrivateRanges[i].mask) == kPrivateRanges[i].value) {
			return YES;
		}
	}

	return NO;
}

+ (nullable NSString *)findPublicAddress
{
	// To find our public IP address, open a port mapper with no port or protocols.
	// This will cause the DNSService to look up our public address without creating a mapping.
	NSString *address = nil;

	XRPortMapper *mapper = [[[self class] alloc] initWithPort:0];

	[mapper setMapTCP:NO];
	[mapper setMapUDP:NO];

	if ([mapper waitUntilOpened]) {
		address = mapper.publicAddress;
	}
	
	[mapper close];
	
	return address;
}

@end

NS_ASSUME_NONNULL_END
