/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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

#import "TLOLocalization.h"

NS_ASSUME_NONNULL_BEGIN

/* Extension declared by TLOLocalization.swift */
@interface NSString (LocalizationPrivate)
+ (NSString *)_swift_localizedKey:(NSString *)string bundle:(NSBundle *)bundle;
@end

NSString *TXTLS(NSString *key, ...)
{
	NSCParameterAssert(key != nil);

	va_list arguments;
	va_start(arguments, key);

	NSString *result = TXLocalizedString(RZMainBundle(), key, arguments);

	va_end(arguments);

	return result;
}

NSString *TXLocalizedString(NSBundle *bundle, NSString *key, va_list arguments)
{
	NSCParameterAssert(bundle != nil);
	NSCParameterAssert(key != nil);
	NSCParameterAssert(arguments != NULL);

	NSString *localValue = [NSString _swift_localizedKey:key bundle:bundle];

	return [[NSString alloc] initWithFormat:localValue arguments:arguments];
}

NSString *TXLocalizedStringAlternative(NSBundle *bundle, NSString *key, ...)
{
	NSCParameterAssert(bundle != nil);
	NSCParameterAssert(key != nil);

	va_list arguments;
	va_start(arguments, key);

	NSString *result = TXLocalizedString(bundle, key, arguments);

	va_end(arguments);

	return result;
}

NS_ASSUME_NONNULL_END
