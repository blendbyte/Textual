/* *********************************************************************
 *
 *            Copyright (c) 2023 Codeux Software, LLC
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

@implementation  NSKeyedUnarchiver (CSKeyedUnarchiverHelper)

+ (nullable id)legacyCompatUnarchivedObjectOfClass:(Class)cls fromData:(NSData *)data
{
	NSParameterAssert(cls != NULL);
	NSParameterAssert(data != nil);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	id object = [NSUnarchiver unarchiveObjectWithData:data];

	if (object != nil) {
		if ([object isKindOfClass:cls] == NO) {
			return nil;
		} else {
			return object;
		}
	}
#pragma GCC diagnostic pop

	NSError *error;

	object =
	[NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class]
									  fromData:object
										 error:&error];

	if (error) {
		LogToConsoleErrorWithSubsystem(_CSFrameworkInternalLogSubsystem(),
			"Failed to read contents archived data: %{public}@",
			error.description);
	}

	return object;
}

@end

NS_ASSUME_NONNULL_END
