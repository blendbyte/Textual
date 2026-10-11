/* *********************************************************************
 *
 *            Copyright (c) 2024 Codeux Software, LLC
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

@interface RCMTrustPanelContext : NSObject
@property (nonatomic, assign) SecTrustRef trustRef;
@property (nonatomic, copy) RCMTrustPanelCompletionBlock completionBlock;
@property (nonatomic, strong, nullable) id contextInfo;
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, weak, nullable) NSWindow *hostWindow;
@end

@implementation RCMTrustPanel

/* Panels waiting for an answer → their context (kept alive here, so a panel
 closed without its callback leaks nothing). Main thread only. */
+ (NSMapTable<SFCertificateTrustPanel *, RCMTrustPanelContext *> *)_openPanels
{
	static NSMapTable *openPanels = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		openPanels = [NSMapTable strongToStrongObjectsMapTable];
	});

	return openPanels;
}

+ (SFCertificateTrustPanel *)presentTrustPanelInWindow:(nullable NSWindow *)window
												  body:(NSString *)bodyText
												 title:(NSString *)titleText
										 defaultButton:(NSString *)buttonDefault
									   alternateButton:(nullable NSString *)buttonAlternate
											  trustRef:(SecTrustRef)trustRef
									   completionBlock:(RCMTrustPanelCompletionBlock)completionBlock
{
	return
	[self presentTrustPanelInWindow:window
							   body:bodyText
							  title:titleText
					  defaultButton:buttonDefault
					alternateButton:buttonAlternate
						   trustRef:trustRef
					completionBlock:completionBlock
						contextInfo:nil];
}

+ (SFCertificateTrustPanel *)presentTrustPanelInWindow:(nullable NSWindow *)window
												  body:(NSString *)bodyText
												 title:(NSString *)titleText
										 defaultButton:(NSString *)buttonDefault
									   alternateButton:(nullable NSString *)buttonAlternate
											  trustRef:(SecTrustRef)trustRef
									   completionBlock:(RCMTrustPanelCompletionBlock)completionBlock
										   contextInfo:(nullable id)contextInfo
{
	NSParameterAssert(bodyText != nil);
	NSParameterAssert(titleText != nil);
	NSParameterAssert(buttonDefault != nil);
	NSParameterAssert(trustRef != nil);
	NSParameterAssert(completionBlock != nil);

	/* Always work on the main thread */
	if ([NSThread isMainThread] == NO) {
		__block SFCertificateTrustPanel *panel = nil;

		XRPerformBlockSynchronouslyOnQueue(dispatch_get_main_queue(), ^{
			panel =
			[self presentTrustPanelInWindow:window
									   body:bodyText
									  title:titleText
							  defaultButton:buttonDefault
							alternateButton:buttonAlternate
								   trustRef:trustRef
							completionBlock:completionBlock
								contextInfo:contextInfo];
		});

		return panel;
	}

	/* Retain the trust so that it is not released from underneath us. */
	CFRetain(trustRef);

	/* Crate context for callback selector */
	RCMTrustPanelContext *promptObject = [RCMTrustPanelContext new];

	promptObject.trustRef = trustRef;

	promptObject.completionBlock = completionBlock;

	promptObject.contextInfo = contextInfo;

	/* Construct panel and present */
	SFCertificateTrustPanel *panel = [SFCertificateTrustPanel new];

	[panel setDefaultButtonTitle:buttonDefault];
	[panel setAlternateButtonTitle:buttonAlternate];

	[panel setInformativeText:bodyText];

	[[self _openPanels] setObject:promptObject forKey:panel];

	NSWindow *modalWindowBefore = NSApp.modalWindow;

	NSArray<NSWindow *> *sheetsBefore = window.sheets;

	[panel beginSheetForWindow:window
				 modalDelegate:[self class]
				didEndSelector:@selector(_trustPanelCallback:returnCode:contextInfo:)
				   contextInfo:NULL
						 trust:trustRef
					   message:titleText];

	/* Shown on its own (no window, which the API doesn't allow), the panel
	 stays hidden and its content runs in a modal window of its own: closing
	 that from here is best effort (Textual always passes a window) */
	NSWindow *modalWindowAfter = NSApp.modalWindow;

	if (window == nil && modalWindowAfter != nil && modalWindowAfter != modalWindowBefore) {
		promptObject.hostWindow = modalWindowAfter;
	}

	/* On a window, the sheet is a window AppKit makes around the panel
	 (the panel itself is never attached), remembered so it can be ended */
	for (NSWindow *sheet in window.sheets) {
		if ([sheetsBefore containsObject:sheet] == NO) {
			promptObject.hostWindow = sheet;
		}
	}

	return panel;
}

/* Found through the panel: a panel closed by -dismissTrustPanel: is no
 longer listed, so a late callback for it does nothing */
+ (void)_trustPanelCallback:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	SFCertificateTrustPanel *panel = (SFCertificateTrustPanel *)sheet;

	RCMTrustPanelContext *context = [[self _openPanels] objectForKey:panel];

	if (context == nil) {
		return;
	}

	[self _finishPanel:panel context:context trusted:(returnCode == NSModalResponseOK)];
}

+ (void)_finishPanel:(SFCertificateTrustPanel *)panel context:(RCMTrustPanelContext *)context trusted:(BOOL)trusted
{
	/* Answered once: a dismissed panel's late callback is ignored */
	if (context.finished) {
		return;
	}

	context.finished = YES;

	[[self _openPanels] removeObjectForKey:panel];

	SecTrustRef trustRef = context.trustRef;

	context.completionBlock(trustRef, trusted, context.contextInfo);

	CFRelease(trustRef);
}

+ (void)dismissTrustPanel:(SFCertificateTrustPanel *)panel
{
	NSParameterAssert(panel != nil);

	RCMTrustPanelContext *context = [[self _openPanels] objectForKey:panel];

	if (context == nil) {
		return;
	}

	NSWindow *hostWindow = context.hostWindow;

	if (panel.sheetParent) {
		[panel.sheetParent endSheet:panel returnCode:NSModalResponseCancel];
	} else if (hostWindow.sheetParent) {
		[hostWindow.sheetParent endSheet:hostWindow returnCode:NSModalResponseCancel];
	} else if (hostWindow != nil && NSApp.modalWindow == hostWindow) {
		[NSApp stopModalWithCode:NSModalResponseCancel];

		[hostWindow orderOut:nil];
	} else {
		[panel orderOut:nil];
	}

	[self _finishPanel:panel context:context trusted:NO];
}

@end

#pragma mark -

@implementation RCMTrustPanelContext
@end

NS_ASSUME_NONNULL_END
