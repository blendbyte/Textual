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

@class IRCCapabilityNegotiator;

@protocol IRCCapabilityNegotiatorDelegate <NSObject>
/* Whether to request a capability the server offers (CAP LS or NEW);
 value is what follows the first "=", e.g. "PLAIN,EXTERNAL" for sasl */
- (BOOL)capabilityNegotiator:(IRCCapabilityNegotiator *)negotiator shouldRequestCapability:(NSString *)capability value:(nullable NSString *)value;

/* The server enabled (CAP ACK) or removed (CAP ACK of "-name", CAP DEL)
 a capability; a refused request (CAP NAK) reports each as disabled */
- (void)capabilityNegotiator:(IRCCapabilityNegotiator *)negotiator didEnableCapability:(NSString *)capability;
- (void)capabilityNegotiator:(IRCCapabilityNegotiator *)negotiator didDisableCapability:(NSString *)capability;

- (void)capabilityNegotiator:(IRCCapabilityNegotiator *)negotiator sendCapabilityCommand:(NSString *)subcommand data:(nullable NSString *)data;
@end

/* IRCv3 capability negotiation (CAP LS 302): collects the capabilities of
 a multi-line LS, requests the wanted ones in as few REQ lines as fit,
 and ends negotiation (CAP END) once every request was answered and SASL,
 which pauses it, is done. After registration it only requests (NEW). */
@interface IRCCapabilityNegotiator : NSObject
@property (nonatomic, weak, nullable) id <IRCCapabilityNegotiatorDelegate> delegate;

@property (readonly) BOOL isPaused;

/* A CAP reply from the server: the subcommand (LS, ACK, NAK, NEW, DEL…)
 and the parameters after it */
- (void)receiveCapabilityReply:(NSString *)subcommand parameters:(NSArray<NSString *> *)parameters;

/* While SASL authenticates; resuming ends negotiation if nothing else is open */
- (void)pause;
- (void)resume;

/* After RPL_WELCOME: no CAP END any more */
- (void)registrationCompleted;

/* For a new connection */
- (void)reset;

/* "name=value" split at the first "=" only (sts=port=6697,duration=300) */
+ (NSString *)capabilityName:(NSString *)capability value:(NSString * _Nullable * _Nullable)value;

/* Capability names joined into REQ data of at most maximumLength characters each */
+ (NSArray<NSString *> *)requestDataForCapabilities:(NSArray<NSString *> *)capabilities maximumLength:(NSUInteger)maximumLength;
@end

NS_ASSUME_NONNULL_END
