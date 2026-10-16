/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

typedef NS_ENUM(NSUInteger, TLOUploadDestinationBody) {
	TLOUploadDestinationBodyMultipart = 0, // a form, the file in fileFieldName
	TLOUploadDestinationBodyBinary // the file itself
};

/* An upload address of the user's own (9.18 B), for networks without one:
 the common part of ShareX's custom uploaders (.sxcu). HTTPS only (plain HTTP
 only to this Mac). Its headers, URL parameters and form fields can hold
 tokens: they are kept in the Keychain, the rest in the preferences. */
@interface TLOUploadDestination : NSObject <NSCopying>
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *requestAddress;
@property (nonatomic, copy) NSString *method; // POST or PUT
@property (nonatomic, assign) TLOUploadDestinationBody body;
@property (nonatomic, copy) NSString *fileFieldName; // "file" unless set
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *parameters; // added to the address
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *arguments; // form fields
@property (nonatomic, copy) NSArray<NSString *> *regexes; // ShareX's RegexList, for $regex:1|1$
@property (nonatomic, copy, nullable) NSString *linkTemplate; // e.g. $json:files[0].url$; nil: Location, else the answer's text
@property (nonatomic, copy, nullable) NSString *errorTemplate;

/* A ShareX custom uploader; nil with why when it can't be used */
+ (nullable instancetype)destinationWithShareXData:(NSData *)data failureReason:(NSString * _Nullable * _Nullable)failureReason;

/* Why it can't be used (no address, not HTTPS…), or nil */
@property (readonly, copy, nullable) NSString *problem;

+ (BOOL)addressIsAllowed:(NSURL *)address; // HTTPS, or HTTP to this Mac

/* Kept: the plain part, and the tokens under an identifier in the Keychain */
@property (readonly, copy) NSDictionary<NSString *, id> *propertyList;
+ (nullable instancetype)destinationWithPropertyList:(NSDictionary<NSString *, id> *)propertyList secretsIdentifier:(nullable NSString *)secretsIdentifier;
- (BOOL)saveSecretsWithIdentifier:(NSString *)identifier;
+ (void)removeSecretsWithIdentifier:(NSString *)identifier;

/* The one in Preferences (nil: none); setting it saves its tokens */
@property (class, nonatomic, copy, nullable) TLOUploadDestination *globalDestination;

/* Hide the paperclip where no upload address applies (an option of the setup) */
@property (class, nonatomic, assign) BOOL hidesUploadButtonWithoutDestination;

/* The request for a file: the body to send is written to folder for a form */
- (nullable NSMutableURLRequest *)requestForFileAtURL:(NSURL *)fileURL
											 fileName:(NSString *)fileName
										  contentType:(NSString *)contentType
									  temporaryFolder:(NSURL *)folder
										   bodyFileURL:(NSURL * _Nullable * _Nonnull)bodyFileURL;

/* The link in the answer, or nil */
- (nullable NSURL *)linkFromResponse:(NSHTTPURLResponse *)response data:(NSData *)data;

/* The server's own words on a failure, if the uploader says where they are */
- (nullable NSString *)errorFromResponse:(NSHTTPURLResponse *)response data:(NSData *)data;

/* ShareX syntax: $json:a.b[0]$ {json:a.b} $response$ $header:Name$ $regex:1|1$ $filename$ */
+ (NSString *)expandTemplate:(NSString *)template response:(nullable NSHTTPURLResponse *)response data:(nullable NSData *)data regexes:(NSArray<NSString *> *)regexes fileName:(nullable NSString *)fileName;
@end

NS_ASSUME_NONNULL_END
