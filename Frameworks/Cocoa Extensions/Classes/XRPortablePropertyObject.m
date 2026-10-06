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

#import "XRPortablePropertyObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface XRPortablePropertyObject ()
@property (nonatomic, assign, readwrite) BOOL initializedAsCopy;
@end

@implementation XRPortablePropertyObject

#pragma mark -
#pragma mark Initialization

- (instancetype)init
{
	if ((self = [super init])) {
		return self;
	}

	return nil;
}

DESIGNATED_INITIALIZER_EXCEPTION_BODY_BEGIN
- (instancetype)initOnCopy
{
	if ((self = [super init])) {
		return self;
	}

	return nil;
}

- (instancetype)initOnMutate
{
	if ((self = [super init])) {
		return self;
	}

	return nil;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
	NSParameterAssert(coder != nil);

	if ((self = [super init])) {
		[self populateDefaultsPreflight];

		if ([self populateWithDecoder:coder] == NO) {
			return nil;
		}

		[self populateDefaultsPostflight];

		[self initializedClassHealthCheck];

		return self;
	}

	return nil;
}
DESIGNATED_INITIALIZER_EXCEPTION_BODY_END

- (void)encodeWithCoder:(nonnull NSCoder *)coder 
{
	[self doesNotRecognizeSelector:_cmd];
}

- (void)initializedClassHealthCheck
{

}

- (void)populateDefaultsPostflight
{

}

- (void)populateDefaultsPreflight
{

}

- (void)performInitialization
{

}

- (BOOL)populateWithDecoder:(NSCoder *)coder
{
	return NO;
}

- (BOOL)isEqual:(id)object
{
	if (object == nil) {
		return NO;
	}

	return (object == self);
}

#pragma mark -
#pragma mark Getters

- (__kindof XRPortablePropertyObject *)mutableClass
{
	if (self.mutable == NO) {
		NSAssert(NO, @"The default implementation of -mutableClass returns `self`. "
				 "This behavior does not work correctly if this property is not overridden"
				 "in a class that is immutable because it will return a immutable class."
				 "Please override -mutableClass property.");
	}

	return self;
}

- (__kindof XRPortablePropertyObject *)immutableClass
{
	if (self.mutable) {
		NSAssert(NO, @"The default implementation of -immutableClass returns `self`. "
				 "This behavior does not work correctly if this property is not overridden"
				 "in a class that is mutable because it will return a mutable class."
				 "Please override -immutableClass property.");
	}

	return self;
}

- (BOOL)copyByReference
{
	return YES;
}

+ (BOOL)isMutable
{
	return NO;
}

- (BOOL)isMutable
{
	return ((__kindof XRPortablePropertyObject *)self.class).mutable;
}

+ (BOOL)supportsSecureCoding
{
	return NO;
}

#pragma mark -
#pragma mark Copying

- (id)copyWithZone:(nullable NSZone *)zone
{
	if (self.mutable == NO && self.copyByReference) {
		return self;
	}

	return [self copyAsMutable:NO];
}

- (id)mutableCopyWithZone:(nullable NSZone *)zone 
{
	return [self copyAsMutable:YES];
}

- (id)allocForCopyAsMutable:(BOOL)mutableCopy
{
	XRPortablePropertyObject *object =
	((mutableCopy) ? 	 self.mutableClass :
						self.immutableClass);

	Class objectClass = [object class];

	object = [objectClass alloc];

	object.initializedAsCopy = YES;

	return object;
}

- (id)copyAsMutable:(BOOL)mutableCopy
{
	return [self copyAsMutable:mutableCopy uniquing:NO];
}

- (id)copyAsMutable:(BOOL)mutableCopy uniquing:(BOOL)uniquing
{
	XRPortablePropertyObject *object = [self allocForCopyAsMutable:mutableCopy];

	if (uniquing) {
		[self populateDuringUniqueCopy:object mutableCopy:mutableCopy];
	} else {
		[self populateDuringCopy:object mutableCopy:mutableCopy];
	}

	return [object initOnCopy];
}

- (id)uniqueCopyAsMutable:(BOOL)mutableCopy
{
	return [self copyAsMutable:mutableCopy uniquing:YES];
}

- (id)uniqueCopy
{
	return [self uniqueCopyAsMutable:NO];
}

- (id)uniqueCopyMutable
{
	return [self uniqueCopyAsMutable:YES];
}

- (void)populateDuringCopy:(__kindof XRPortablePropertyObject *)newObject mutableCopy:(BOOL)mutableCopy
{
	[self doesNotRecognizeSelector:_cmd];
}

- (void)populateDuringUniqueCopy:(__kindof XRPortablePropertyObject *)newObject mutableCopy:(BOOL)mutableCopy
{
	[self doesNotRecognizeSelector:_cmd];
}

@end

NS_ASSUME_NONNULL_END
