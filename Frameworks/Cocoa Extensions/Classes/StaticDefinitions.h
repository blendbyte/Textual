/* *********************************************************************
 *
 *         Copyright (c) 2015 - 2018 Codeux Software, LLC
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

/* Macros can't carry the deprecated attribute: these warn where they're used */
#define COCOA_EXTENSIONS_PRAGMA_STRING(x)			_Pragma(#x)
#define COCOA_EXTENSIONS_DEPRECATED_MACRO(message)		COCOA_EXTENSIONS_PRAGMA_STRING(GCC warning message)

#define NSAssertReturn(c)								if ((c) == NO) { return; }
#define NSAssertReturnR(c, r)							if ((c) == NO) { return (r); }
#define NSAssertReturnLoopContinue(c)					COCOA_EXTENSIONS_DEPRECATED_MACRO("NSAssertReturnLoopContinue is unused and will be removed in a future version") if ((c) == NO) { continue; }
#define NSAssertReturnLoopBreak(c)						COCOA_EXTENSIONS_DEPRECATED_MACRO("NSAssertReturnLoopBreak is unused and will be removed in a future version") if ((c) == NO) { break; }

#define NSObjectIsEmptyAssert(o)						COCOA_EXTENSIONS_DEPRECATED_MACRO("NSObjectIsEmptyAssert is unused and will be removed in a future version") if (NSObjectIsEmpty(o)) { return; }
#define NSObjectIsEmptyAssertReturn(o, r)				COCOA_EXTENSIONS_DEPRECATED_MACRO("NSObjectIsEmptyAssertReturn is unused and will be removed in a future version") if (NSObjectIsEmpty(o)) { return (r); }
#define NSObjectIsEmptyAssertLoopContinue(o)			COCOA_EXTENSIONS_DEPRECATED_MACRO("NSObjectIsEmptyAssertLoopContinue is unused and will be removed in a future version") if (NSObjectIsEmpty(o)) { continue; }
#define NSObjectIsEmptyAssertLoopBreak(o)				COCOA_EXTENSIONS_DEPRECATED_MACRO("NSObjectIsEmptyAssertLoopBreak is unused and will be removed in a future version") if (NSObjectIsEmpty(o)) { break; }

#define NSObjectIsNotEmptyAssert(o)						COCOA_EXTENSIONS_DEPRECATED_MACRO("NSObjectIsNotEmptyAssert is unused and will be removed in a future version") if (NSObjectIsNotEmpty(o)) { return; }
#define NSObjectIsNotEmptyAssertReturn(o, r)			COCOA_EXTENSIONS_DEPRECATED_MACRO("NSObjectIsNotEmptyAssertReturn is unused and will be removed in a future version") if (NSObjectIsNotEmpty(o)) { return (r); }
#define NSObjectIsNotEmptyAssertLoopContinue(o)			COCOA_EXTENSIONS_DEPRECATED_MACRO("NSObjectIsNotEmptyAssertLoopContinue is unused and will be removed in a future version") if (NSObjectIsNotEmpty(o)) { continue; }
#define NSObjectIsNotEmptyAssertLoopBreak(o)			COCOA_EXTENSIONS_DEPRECATED_MACRO("NSObjectIsNotEmptyAssertLoopBreak is unused and will be removed in a future version") if (NSObjectIsNotEmpty(o)) { break; }

#define NSObjectIsKindOfClassAssert(o,c)				COCOA_EXTENSIONS_DEPRECATED_MACRO("NSObjectIsKindOfClassAssert is unused and will be removed in a future version") if ([(o) isKindOfClass:[c class]] == NO) { return; }
#define NSObjectIsKindOfClassAssertReturn(o, c, r)		COCOA_EXTENSIONS_DEPRECATED_MACRO("NSObjectIsKindOfClassAssertReturn is unused and will be removed in a future version") if ([(o) isKindOfClass:[c class]] == NO) { return (r); }
#define NSObjectIsKindOfClassAssertContinue(o, c)		COCOA_EXTENSIONS_DEPRECATED_MACRO("NSObjectIsKindOfClassAssertContinue is unused and will be removed in a future version") if ([(o) isKindOfClass:[c class]] == NO) { continue; }
#define NSObjectIsKindOfClassAssertBreak(o,c)			COCOA_EXTENSIONS_DEPRECATED_MACRO("NSObjectIsKindOfClassAssertBreak is unused and will be removed in a future version") if ([(o) isKindOfClass:[c class]] == NO) { break; }

#define COCOA_EXTENSIONS_EXTERN							extern

#define COCOA_EXTENSIONS_INLINE							static __inline__ __attribute__((always_inline))

#define COCOA_EXTENSIONS_DEPRECATED(reason)				__attribute__((deprecated((reason))))

#define COCOA_EXTENSIONS_DEPRECATED_ASSERT				NSAssert1(NO, @"Deprecated Method: %s", __PRETTY_FUNCTION__);
#define COCOA_EXTENSIONS_DEPRECATED_ASSERT_C			NSCAssert1(NO, @"Deprecated Method: %s", __PRETTY_FUNCTION__);

#define COCOA_EXTENSIONS_IGNORE_DEPRECATION_BEGIN		_Pragma("clang diagnostic push")									\
														_Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")	\
														_Pragma("clang diagnostic ignored \"-Wdeprecated-implementations\"")

#define COCOA_EXTENSIONS_IGNORE_DEPRECATION_END			_Pragma("clang diagnostic pop")

#define COCOA_EXTENSIONS_DEPRECATED_WARNING				NSLog(@"DEPRECATED: Use of the method named %s is deprecated. This method will cease to exist in a future version of this framework.\n\nCurrent Stack: %@", __PRETTY_FUNCTION__, [NSThread callStackSymbols]);

#define DESIGNATED_INITIALIZER_EXCEPTION_BODY_BEGIN							\
	_Pragma("clang diagnostic push")										\
	_Pragma("clang diagnostic ignored \"-Wobjc-designated-initializers\"")

#define DESIGNATED_INITIALIZER_EXCEPTION_BODY_END	\
	_Pragma("clang diagnostic pop")

#ifndef DISPATCH_NOESCAPE
	#if __has_attribute(noescape)
		#define DISPATCH_NOESCAPE __attribute__((__noescape__))
	#else
		#define DISPATCH_NOESCAPE
	#endif
#endif

#ifndef NS_NOESCAPE
	#if __has_attribute(noescape)
		#define NS_NOESCAPE __attribute__((noescape))
	#else
		#define NS_NOESCAPE
	#endif
#endif

/* XRRunningOnOSX<name>OrLater(), usable in any expression (@available
 only works in an if or guard condition) */
#if defined(COCOA_EXTENSIONS_ENABLE_AVAILABLE_EXTENSION)
	#define COCOA_EXTENSIONS_RUNNING_ON(_version_, _name_)		\
		@available(macos _version_, *)
#else
	#define COCOA_EXTENSIONS_RUNNING_ON(_version_, _name_)		\
		XRRunningOnOSX##_name_##OrLater()
#endif

