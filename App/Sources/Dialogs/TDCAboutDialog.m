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

#import "TXMasterController.h"
#import "TXMenuController.h"
#import "TLOLocalization.h"
#import "TPCApplicationInfo.h"
#import "TDCAboutDialogPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCAboutDialog ()
@property (nonatomic, weak) IBOutlet NSTextField *versionInfoTextField;

- (IBAction)displayAcknowledgements:(id)sender;
@end

@implementation TDCAboutDialog

- (instancetype)init
{
	if ((self = [super init])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCAboutDialog" owner:self topLevelObjects:nil];

	NSString *bundleVersion = [TPCApplicationInfo applicationVersionShort];

	self.versionInfoTextField.stringValue = TXTLS(@"TDCAboutDialog[zjd-al]", bundleVersion);
}

- (void)show
{
	[self.window restoreWindowStateForClass:self.class];

	[super show];
}

- (void)displayAcknowledgements:(id)sender
{
	[menuController() openAcknowledgements:sender];
}

- (void)windowWillClose:(NSNotification *)note
{
	[self.window saveWindowStateForClass:self.class];

	if ([self.delegate respondsToSelector:@selector(aboutDialogWillClose:)]) {
		[self.delegate aboutDialogWillClose:self];
	}
}

@end

NS_ASSUME_NONNULL_END
