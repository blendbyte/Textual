/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2017, 2018 Codeux Software, LLC & respective contributors.
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

#import "NSObjectHelperPrivate.h"
#import "ICLMediaAssessment.h"

NS_ASSUME_NONNULL_BEGIN

@interface ICLMediaAssessment ()
{
@protected
	NSURL *_url;
	ICLMediaType _type;
	NSString *_contentType;
	unsigned long long _contentLength;
}

@end

@implementation ICLMediaAssessment

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithURL:(NSURL *)url asType:(ICLMediaType)type
{
	NSParameterAssert(url != nil);

	if ((self = [super init])) {
		self->_url = [url copy];

		self->_type = type;

		[self populateDefaultsPostflight];

		return self;
	}

	return nil;
}

- (void)populateDefaultsPostflight
{
	SetVariableIfNil(self->_contentType, @"application/binary");
}

- (void)initializedClassHealthCheck
{
	NSParameterAssert(self->_url != nil);
	NSParameterAssert(self->_contentType != nil);
}

- (id)copyAsMutable:(BOOL)mutableCopy uniquing:(BOOL)uniquing
{
	ICLMediaAssessment *object = [self allocForCopyAsMutable:mutableCopy];

	object->_url = self->_url;

	object->_type = self->_type;

	object->_contentType = self->_contentType;
	object->_contentLength = self->_contentLength;

	return [object initOnCopy];
}

- (__kindof XRPortablePropertyObject *)mutableClass
{
	return [ICLMediaAssessmentMutable self];
}

@end

#pragma mark -

@implementation ICLMediaAssessmentMutable

@dynamic type;
@dynamic contentType;
@dynamic contentLength;

+ (BOOL)isMutable
{
	return YES;
}

- (__kindof XRPortablePropertyObject *)immutableClass
{
	return [ICLMediaAssessment self];
}

- (void)setType:(ICLMediaType)type
{
	if (self->_type != type) {
		self->_type = type;
	}
}

- (void)setContentType:(NSString *)contentType
{
	if (self->_contentType != contentType) {
		self->_contentType = [contentType copy];
	}
}

- (void)setContentLength:(unsigned long long)contentLength
{
	if (self->_contentLength != contentLength) {
		self->_contentLength = contentLength;
	}
}

@end

NS_ASSUME_NONNULL_END
