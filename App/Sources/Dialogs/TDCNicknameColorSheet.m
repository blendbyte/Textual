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

#import "NSObjectHelperPrivate.h"
#import "IRCUserNicknameColorStyleGeneratorPrivate.h"
#import "TDCNicknameColorSheetPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCNicknameColorSheet ()
@property (nonatomic, copy) NSString *nickname;
@property (nonatomic, weak) IBOutlet NSColorWell *nicknameColorWell;

- (IBAction)resetNicknameColor:(id)sender;
@end

@implementation TDCNicknameColorSheet

- (instancetype)initWithNickname:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	if ((self = [super initWithWindow:nil])) {
		self.nickname = nickname;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCNicknameColorSheet" owner:self topLevelObjects:nil];

	NSColor *nicknameColor =
	[IRCUserNicknameColorStyleGenerator nicknameColorStyleOverrideForKey:self.nickname];

	if (nicknameColor == nil) {
		nicknameColor = [NSColor whiteColor];
	}

	self.nicknameColorWell.color = nicknameColor;
}

- (void)start
{
	[self startSheet];
}

- (void)ok:(id)sender
{
	NSColor *nicknameColor = self.nicknameColorWell.color;

	if ([nicknameColor isEqual:[NSColor whiteColor]]) {
		 nicknameColor = nil;
	}

	[IRCUserNicknameColorStyleGenerator setNicknameColorStyleOverride:nicknameColor forKey:self.nickname];

	if ([self.delegate respondsToSelector:@selector(nicknameColorSheetOnOk:)]) {
		[self.delegate nicknameColorSheetOnOk:self];
	}

	[super ok:nil];
}

- (void)resetNicknameColor:(id)sender
{
	if ([NSColorPanel sharedColorPanelExists]) {
		[[NSColorPanel sharedColorPanel] close];
	}

	self.nicknameColorWell.color = [NSColor whiteColor];
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	if ([self.delegate respondsToSelector:@selector(nicknameColorSheetWillClose:)]) {
		[self.delegate nicknameColorSheetWillClose:self];
	}
}

@end

NS_ASSUME_NONNULL_END
