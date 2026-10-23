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

/* XRPortablePropertyDict is a subclass of XRPortablePropertyObject
 that assists with making configuration dictionaries more portable. */
/* XRPortablePropertyDict does not actually store a dictionary.
 At least not at the base level. It merely provides an interface for treating
 underlying properties of the subclass as a dictionary. */

@class XRPortablePropertyObject;

typedef NS_ENUM(NSUInteger, XRPortablePropertyDictTarget) {
	/* Dictionary value of configuration object for all uses. */
	XRPortablePropertyDictTargetDefault		= 0,

	/* Dictionary value of configuration object for use during copy. */
	XRPortablePropertyDictTargetCopy		= 1,

	/* Dictionary value of configuration object for use during mutable copy. */
	XRPortablePropertyDictTargetMutableCopy	= 2,

	/* Dictionary value of configuration object for use with iCloud. */
	XRPortablePropertyDictTargetCloud		= 3
};

@protocol XRPortablePropertyDictPrototype <NSObject>
/* Called during init after defaults preflight and before defaults postflight. */
- (void)populateDictionaryValues:(nonnull NSDictionary<NSString *,id> *)dic;

/* Dictionary value of configuration object for use based on target operation. */
/* All internal operations of XRPortablePropertyDict relies on this method. It is required. */
- (NSDictionary<NSString *, id> *)dictionaryValueForTarget:(XRPortablePropertyDictTarget)target;
@end

@interface XRPortablePropertyDict : XRPortablePropertyObject <XRPortablePropertyDictPrototype>
- (instancetype)init NS_DESIGNATED_INITIALIZER; // Returns self. See XRPortablePropertyObject.h
- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dic NS_DESIGNATED_INITIALIZER;

/* Class reference for the immutable version of the class. */
@property (readonly) __kindof XRPortablePropertyDict *immutableClass;

/* Class reference for the mutable version of the class. */
@property (readonly) __kindof XRPortablePropertyDict *mutableClass;

/* Dictionary value of configuration object for all uses. */
/* This property proxies -dictionaryValueForTarget with target: XRPortablePropertyDictTargetDefault */
@property (readonly, copy) NSDictionary<NSString *, id> *dictionaryValue;

/* Dictionary value of configuration object for use with iCloud. */
/* This property proxies -dictionaryValueForTarget with target: XRPortablePropertyDictTargetCloud */
@property (readonly, copy) NSDictionary<NSString *, id> *dictionaryValueForCloud;

/* Dictionary value of configuration object for use during copy. */
/* This property proxies -dictionaryValueForTarget with target: XRPortablePropertyDictTargetCopy */
@property (readonly, copy) NSDictionary<NSString *, id> *dictionaryValueForCopy;
@end

NS_ASSUME_NONNULL_END
