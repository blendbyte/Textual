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

#import "XRPortablePropertyDict.h"

NS_ASSUME_NONNULL_BEGIN

@interface XRPortablePropertyObject ()
@property (nonatomic, assign, readwrite) BOOL initializedAsCopy;
@end

@implementation XRPortablePropertyDict

#pragma mark -
#pragma mark Initialization

- (instancetype)init
{
	return [super init];
}

DESIGNATED_INITIALIZER_EXCEPTION_BODY_BEGIN
- (instancetype)initOnCopy
{
	return [super initOnCopy];
}

- (instancetype)initOnMutate
{
	return [super initOnMutate];
}
DESIGNATED_INITIALIZER_EXCEPTION_BODY_END

- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dic
{
	if ((self = [super init])) {
		[self populateDefaultsPreflight];

		[self populateDictionaryValues:dic];

		[self populateDefaultsPostflight];

		[self initializedClassHealthCheck];

		return self;
	}

	return nil;
}

- (void)populateDictionaryValues:(nonnull NSDictionary<NSString *,id> *)dic
{

}

- (BOOL)isEqual:(id)object
{
	if (object == nil) {
		return NO;
	}

	if (object == self) {
		return YES;
	}

	if ([object isKindOfClass:[XRPortablePropertyDict class]] == NO) {
		return NO;
	}

	NSDictionary *s1 = ((XRPortablePropertyDict *)object).dictionaryValue;

	NSDictionary *s2 = self.dictionaryValue;

	return [s1 isEqualToDictionary:s2];
}

#pragma mark -
#pragma mark Getters

- (NSDictionary<NSString *, id> *)dictionaryValue
{
	return [self dictionaryValueForTarget:XRPortablePropertyDictTargetDefault];
}

- (NSDictionary<NSString *, id> *)dictionaryValueForCloud
{
	return [self dictionaryValueForTarget:XRPortablePropertyDictTargetCloud];
}

- (NSDictionary<NSString *, id> *)dictionaryValueForCopy
{
	return [self dictionaryValueForTarget:XRPortablePropertyDictTargetCopy];
}

- (NSDictionary<NSString *, id> *)dictionaryValueForTarget:(XRPortablePropertyDictTarget)target
{
	return @{};
}

- (__kindof XRPortablePropertyDict *)immutableClass
{
	return [super immutableClass];
}

- (__kindof XRPortablePropertyDict *)mutableClass
{
	return [super mutableClass];
}

#pragma mark -
#pragma mark Copying

- (id)copyAsMutable:(BOOL)mutableCopy uniquing:(BOOL)uniquing
{
	XRPortablePropertyDict *object =
	((mutableCopy) ? 	 self.mutableClass :
						self.immutableClass);

	Class objectClass = [object class];

	object = [objectClass alloc];

	/* Always define first because it is common for some subclasses
	 to skip certain work in defaults pre/post flight when copying. */
	object.initializedAsCopy = YES;

	NSDictionary *dictionaryValue = nil;

	if (mutableCopy) {
		dictionaryValue = [self dictionaryValueForTarget:XRPortablePropertyDictTargetMutableCopy];
	} else {
		dictionaryValue = [self dictionaryValueForTarget:XRPortablePropertyDictTargetCopy];
	}

	return [object initWithDictionary:dictionaryValue];
}

@end

NS_ASSUME_NONNULL_END
