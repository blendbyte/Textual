/* *********************************************************************
 *
 *           Copyright (c) 2024 Codeux Software, LLC
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

/* XRPortablePropertyObject as a base class for objects that 
 typically come in immutable and mutable pairs. It helps manages more
 common tasks such as maintaining defaults for mutable properties,
 performing health checks after init, and different levels of copying. */
/* XRPortablePropertyObject is designed to be as customizable
 and portable as possible. */

@class XRPortablePropertyObject;

@protocol XRPortablePropertyObjectPrototype <NSObject>
/* Called first during init to populate defaults. */
/* This method is not called during a copy operation. */
- (void)populateDefaultsPreflight;

/* Called second during init to populate any defaults that
 are more appropriately set after populating properties. */
/* This method is not called during a copy operation. */
- (void)populateDefaultsPostflight;

/* Called third during init to perform state checking. */
/* This method is not called during a copy operation. */
- (void)initializedClassHealthCheck;

/* Called after alloc and before init during a regular copy to allow properties
 to be populated as needed. Default implementation does nothing. */
- (void)populateDuringCopy:(__kindof XRPortablePropertyObject *)newObject mutableCopy:(BOOL)mutableCopy;

/* Called after alloc and before init during a unique copy to allow properties
 to be populated as needed. Default implementation does nothing. */
- (void)populateDuringUniqueCopy:(__kindof XRPortablePropertyObject *)newObject mutableCopy:(BOOL)mutableCopy;

/* Called during -initWithCoder: to allow properties to be populated. */
/* Return YES on success, NO on failure. On failure, nil is immediately
 returned by --initWithCoder:. This method is called after defaults preflight
 and before defaults postflight. Default implementation returns NO. */
- (BOOL)populateWithDecoder:(NSCoder *)aDecoder;
@end

/* Depending on the value type of this class, the object returned
 from -copy may be a reference to the original object instead of
 an actual new copy when said object is already immutable.
 This behavior is on by default for most subclasses. */
@interface XRPortablePropertyObject : NSObject <NSCopying, NSMutableCopying, NSCoding, NSSecureCoding, XRPortablePropertyObjectPrototype>
/* -init returns self. It does not perform calls to prototype methods.
 It is expected subclasses will replace -init or mark unavailable. */
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/* Initializer called by copy operations. Returns self similar to -init. */
- (instancetype)initOnCopy;

/* Not called by any methods expressed by XRPortablePropertyObject.
 Used as a convenience initializer if a subclass wants to expose -init
 to a mutable class while leaving -init unavailable in immutable class. */
- (instancetype)initOnMutate;

/* Class reference for the immutable version of the class. */
/* Returns self by default */
@property (readonly) __kindof XRPortablePropertyObject *immutableClass;

/* Class reference for the mutable version of the class. */
/* Returns self by default */
@property (readonly) __kindof XRPortablePropertyObject *mutableClass;

/* Defines whether the class we are in is mutable. */
/* This property defaults to NO. */
@property (readonly, getter=isMutable, class) BOOL mutable;
@property (readonly, getter=isMutable) BOOL mutable; // Mirrors [Class mutable] by default

/* When -copy or -copyWithZone: is called on an immutable class,
 does the class want a reference to the original object returned
 instead of a new instance? No other copy operation methods will
 return by reference. */
/* This property defaults to YES. */
@property (readonly) BOOL copyByReference;

/* YES if object is a copy. Not original. */
@property (readonly) BOOL initializedAsCopy;

/* Default implementation creates an instance of -immutableClass
 or -mutableClass depending on value of mutableCopy and calls
 -alloc on it. No other work is performed. The returned object
 is not yet initialized. Only staged. */
- (id)allocForCopyAsMutable:(BOOL)mutableCopy;

/* Default implementation creates an instance of -immutableClass
 or -mutableClass depending on value of mutableCopy and performs
 initialization on it using -populateDuring[Unique]Copy: and
 related methods. */
- (id)copyAsMutable:(BOOL)mutableCopy;
- (id)copyAsMutable:(BOOL)mutableCopy uniquing:(BOOL)uniquing;

/* Default implementation defers to -copyAsMutable: */
/* This method is only called by -uniqueCopy and -uniqueCopyMutable.
 This allows a subclass to have one entry for uniquing. */
- (id)uniqueCopyAsMutable:(BOOL)mutableCopy;

/* What defines a unique copy is for a subclass to decide.
 Default implementation creates a guaranteed unique copy of
 the instance regardless of whether -copy would otherwise
 return a reference. Some subclasses may change other
 properties such as unique identifier properties. */
- (id)uniqueCopy;
- (id)uniqueCopyMutable;
@end

NS_ASSUME_NONNULL_END
