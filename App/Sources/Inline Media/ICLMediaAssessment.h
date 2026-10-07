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

#import "ICLMediaType.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Immutable Object

@interface ICLMediaAssessment : XRPortablePropertyObject
- (instancetype)init NS_UNAVAILABLE;

/**
 Designated initializer
 */
- (instancetype)initWithURL:(NSURL *)url asType:(ICLMediaType)type NS_DESIGNATED_INITIALIZER;

/**
 The final URL that was assessed.

 This URL may be different when compared to that passed
 to the assessor due to HTTP redirects.
 */
@property (readonly, copy) NSURL *url;

/**
 The type of the media.

 The type is determined by the Content-Type header.
 */
@property (readonly) ICLMediaType type;

/**
 Value of the Content-Type header
 */
@property (readonly, copy) NSString *contentType;

/**
 Value of the Content-Length header
 */
@property (readonly) unsigned long long contentLength;
@end

#pragma mark -
#pragma mark Mutable Object

@interface ICLMediaAssessmentMutable : ICLMediaAssessment
@property (nonatomic, assign, readwrite) ICLMediaType type;
@property (nonatomic, copy, readwrite) NSString *contentType; // Defaults to "application/binary"
@property (nonatomic, assign, readwrite) unsigned long long contentLength;
@end

NS_ASSUME_NONNULL_END
