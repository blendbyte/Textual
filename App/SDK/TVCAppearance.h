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

#import "TXAppearance.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCAppearance : NSObject
- (instancetype)init NS_UNAVAILABLE;

/* Top level group */
/* Nonnull until -flushAppearanceProperties is called. */
@property (readonly, copy, nullable) NSDictionary<NSString *, id> *appearanceProperties;

/* Properties */
@property (readonly) BOOL isHighResolutionAppearance;

/* Stateless Accessors */
- (nullable NSColor *)colorForKey:(NSString *)key;
- (nullable NSColor *)colorInGroup:(NSDictionary<NSString *, id> *)group withKey:(NSString *)key;

- (nullable NSGradient *)gradientForKey:(NSString *)key;
- (nullable NSGradient *)gradientInGroup:(NSDictionary<NSString *, id> *)group withKey:(NSString *)key;

- (nullable NSFont *)fontForKey:(NSString *)key;
- (nullable NSFont *)fontInGroup:(NSDictionary<NSString *, id> *)group withKey:(NSString *)key;

- (nullable NSImage *)imageForKey:(NSString *)key;
- (nullable NSImage *)imageInGroup:(NSDictionary<NSString *, id> *)group withKey:(NSString *)key;

- (NSSize)sizeForKey:(NSString *)key;
- (NSSize)sizeInGroup:(NSDictionary<NSString *, id> *)group withKey:(NSString *)key;

- (CGFloat)measurementForKey:(NSString *)key;
- (CGFloat)measurementInGroup:(NSDictionary<NSString *, id> *)group withKey:(NSString *)key;

/* Stateful Accessors */
/* Stateful appearance properties require the properties to have a
 "activeWindow" and "inactiveWindow" dictionary value which contains
 the value of the property itself. */
/*
 Example:

 <key>exampleStatefulColor</key>
 <dict>
	 <key>activeWindow</key>
	 <dict>
		 <key>type</key>
		 <integer>1</integer>
		 <key>value</key>
		 <string>0.0 0.3</string>
	 </dict>
	 <key>inactiveWindow</key>
	 <dict>
		 <key>type</key>
		 <integer>1</integer>
		 <key>value</key>
		 <string>1.0</string>
	 </dict>
 </dict>
*/
- (nullable NSColor *)colorForKey:(NSString *)key forActiveWindow:(BOOL)forActiveWindow;
- (nullable NSColor *)colorInGroup:(NSDictionary<NSString *, id> *)group withKey:(NSString *)key forActiveWindow:(BOOL)forActiveWindow;

- (nullable NSGradient *)gradientForKey:(NSString *)key forActiveWindow:(BOOL)forActiveWindow;
- (nullable NSGradient *)gradientInGroup:(NSDictionary<NSString *, id> *)group withKey:(NSString *)key forActiveWindow:(BOOL)forActiveWindow;

- (nullable NSFont *)fontForKey:(NSString *)key forActiveWindow:(BOOL)forActiveWindow;
- (nullable NSFont *)fontInGroup:(NSDictionary<NSString *, id> *)group withKey:(NSString *)key forActiveWindow:(BOOL)forActiveWindow;

- (nullable NSImage *)imageForKey:(NSString *)key forActiveWindow:(BOOL)forActiveWindow;
- (nullable NSImage *)imageInGroup:(NSDictionary<NSString *, id> *)group withKey:(NSString *)key forActiveWindow:(BOOL)forActiveWindow;
@end

/* TVCApplicationAppearance keeps a copy of TXAppearance properties.
 The properties it keeps are those that were set when the object was created.
 To update to the latest properties, create a new instance of the object. */
@interface TVCApplicationAppearance : TVCAppearance <TXAppearanceProperties>
@end

NS_ASSUME_NONNULL_END
