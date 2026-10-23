
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

NS_ASSUME_NONNULL_BEGIN

@interface XRPortMapper : NSObject
/** Initializes a copy of XRPortMapper that will map the given local (private) port.
    By default it will map TCP and not UDP, and will not suggest a desired public port,
    but this can be configured by setting properties before opening the port mapper.
 */
- (instancetype)initWithPort:(UInt16)port NS_DESIGNATED_INITIALIZER;

/** Should the TCP or UDP port, or both, be mapped? By default, TCP only.
    These properties have no effect if changed while the port mapper is open. */
@property (assign) BOOL mapTCP;
@property (assign) BOOL mapUDP;

/** You can set this to the public port number you'd like to get.
    It defaults to 0, which means "no preference".
    This property has no effect if changed while the port mapper is open. */
@property UInt16 desiredPublicPort;

/** Opens the port mapper, using the current settings of the above properties.
    Returns immediately; you can find out when the mapping is created or fails
    by observing the error/publicAddress/publicPort properties, or by listening
    for the XRPortMapperDidChangedNotification.
    It's very unlikely that this call will fail (return NO). If it does, it
    probably means that the mDNSResponder process isn't working. */
- (BOOL)open;

/** Closes the port mapper, terminating any open port mapping. */
- (void)close;

/** The following properties are valid only while the port mapper is open.
    They are all KV-observable, or you can listen for a XRPortMapperDidChangedNotification.
    If error is non-zero, none of the other properties are valid (they'll all be zero/nil.) */
@property (readonly) SInt32 error;                  // Really DNSServiceErrorType
@property (readonly, copy, nullable) NSString *publicAddress;  // IPv4 dotted-quad string
@property (readonly) unsigned short publicPort;

/** Returns YES if a non-null port mapping is in effect: 
    that is, if the public address differs from the local one. */
@property (readonly) BOOL isMapped;

#pragma mark -

/** Determine the main interface's public IP address, without mapping any ports. */
+ (nullable NSString *)findPublicAddress;

/** Returns this computer's local IPv4 address. */
+ (nullable NSString *)localAddress;

/** Is +localAddress in a private address range (like 10.0.1.X)? */
+ (BOOL)localAddressIsPrivate;
@end

/** This notification is posted asynchronously when the status of a 
    port mapping (its error, publicAddress or publicPort) changes. */
COCOA_EXTENSIONS_EXTERN NSString * const XRPortMapperDidChangedNotification;

NS_ASSUME_NONNULL_END
