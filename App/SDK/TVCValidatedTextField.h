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

NS_ASSUME_NONNULL_BEGIN

/* Keep the validation block as fast as possible as it is called every time 
 that the value of the text field is changed. */
/* Validation block returns nil on success or a string that can be presented
 to the user as an error description. */
typedef NSString * _Nullable (^TVCValidatedTextFieldValidationBlock)(NSString *currentValue);

@interface TVCValidatedTextField : NSTextField
@property (nonatomic, copy, nullable) TVCValidatedTextFieldValidationBlock validationBlock;
@property (nonatomic, assign) BOOL stringValueUsesOnlyFirstToken; // Only use everything before first space (" ") as value.
@property (nonatomic, assign) BOOL stringValueIsTrimmed; // Returned value is trimmed of whitespaces and newlines when returned. The value is returned trimmed by -value. It is also sent to the validation block as trimmed.
@property (nonatomic, assign) BOOL stringValueIsInvalidOnEmpty; // Is an empty string considered invalid?
@property (nonatomic, assign) BOOL performValidationWhenEmpty;
@property (nonatomic, weak) id textDidChangeCallback; // Calls method "-(void)validatedTextFieldTextDidChange:(id)sender" whereas "sender" is the text field.
@property (nonatomic, copy, nullable) NSString *defaultValue; // A value to return from -value if the text field is empty. Only used if stringValueIsInvalidOnEmpty = NO

@property (readonly, copy) NSString *value; /* The current value. */
@property (readonly, copy) NSString *lowercaseValue;
@property (readonly, copy) NSString *uppercaseValue;

@property (readonly) BOOL valueIsEmpty;
@property (readonly) BOOL valueIsValid;

@property (readonly, copy, nullable) NSString *lastValidationErrorDescription;

- (BOOL)showValidationErrorPopover;
- (void)closeValidationErrorPopover;

- (void)performValidation; /* Force the text field to clear cache and validate value */
@end

@interface TVCValidatedTextFieldCell : NSTextFieldCell
@end

NS_ASSUME_NONNULL_END
