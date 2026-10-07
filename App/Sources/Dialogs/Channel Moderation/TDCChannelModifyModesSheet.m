/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
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
#import "TLOLocalization.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "IRCChannelMode.h"
#import "IRCISupportInfo.h"
#import "IRCModeInfo.h"
#import "TDCAlert.h"
#import "TDCChannelModifyModesSheetPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCChannelModifyModesSheet () <NSControlTextEditingDelegate>
@property (nonatomic, strong, readwrite) IRCClient *client;
@property (nonatomic, strong, readwrite) IRCChannel *channel;
@property (nonatomic, copy, readwrite) NSString *clientId;
@property (nonatomic, copy, readwrite) NSString *channelId;
@property (nonatomic, strong) IRCChannelModeContainer *modes;
@property (nonatomic, weak) IBOutlet NSButton *sCheck;
@property (nonatomic, weak) IBOutlet NSButton *pCheck;
@property (nonatomic, weak) IBOutlet NSButton *nCheck;
@property (nonatomic, weak) IBOutlet NSButton *tCheck;
@property (nonatomic, weak) IBOutlet NSButton *iCheck;
@property (nonatomic, weak) IBOutlet NSButton *mCheck;
@property (nonatomic, weak) IBOutlet NSButton *kCheck;
@property (nonatomic, weak) IBOutlet NSButton *lCheck;
@property (nonatomic, weak) IBOutlet NSTextField *kText;
@property (nonatomic, weak) IBOutlet NSTextField *lText;
@property (nonatomic, copy) NSString *channelUserLimitMode;
@property (nonatomic, assign) BOOL secretKeyLengthAlertDisplayed;

- (IBAction)onChangeCheck:(id)sender;
@end

@implementation TDCChannelModifyModesSheet

- (instancetype)initWithChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if ((self = [super initWithWindow:nil])) {
		self.client = channel.associatedClient;
		self.clientId = channel.associatedClient.uniqueIdentifier;

		self.channel = channel;
		self.channelId = channel.uniqueIdentifier;

		self.modes = [channel.modeInfo.modes copy];

		[self prepareInitialState];

		[self loadConfig];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCChannelModifyModesSheet" owner:self topLevelObjects:nil];
}

- (void)loadConfig
{
	self.iCheck.state = [self.modes modeInfoFor:@"i"].modeIsSet;
	self.mCheck.state = [self.modes modeInfoFor:@"m"].modeIsSet;
	self.nCheck.state = [self.modes modeInfoFor:@"n"].modeIsSet;
	self.pCheck.state = [self.modes modeInfoFor:@"p"].modeIsSet;
	self.sCheck.state = [self.modes modeInfoFor:@"s"].modeIsSet;
	self.tCheck.state = [self.modes modeInfoFor:@"t"].modeIsSet;

	IRCModeInfo *kModeInfo = [self.modes modeInfoFor:@"k"];

	self.kCheck.state = kModeInfo.modeIsSet;

	if (kModeInfo.modeIsSet) {
		self.kText.stringValue = kModeInfo.modeParameter;
	}

	IRCModeInfo *lModeInfo = [self.modes modeInfoFor:@"l"];

	self.lCheck.state = lModeInfo.modeIsSet;

	if (lModeInfo.modeIsSet) {
		self.channelUserLimitMode = lModeInfo.modeParameter; // Set to local property for validation
	}

	[self updateTextFields];
}

- (void)start
{
	[self startSheet];
}

- (BOOL)validateValue:(inout id *)value forKey:(NSString *)key error:(out NSError **)outError
{
	if ([key isEqualToString:@"channelUserLimitMode"]) {
		NSInteger valueInteger = [*value integerValue];

		if (valueInteger < 0) {
			*value = [NSString stringWithInteger:0];
		} else if (valueInteger > 99999) {
			*value = [NSString stringWithInteger:99999];
		}
	}

	return YES;
}

- (void)updateTextFields
{
	self.kText.enabled = (self.kCheck.state == NSControlStateValueOn);

	self.lText.enabled = (self.lCheck.state == NSControlStateValueOn);
}

- (void)onChangeCheck:(id)sender
{
	[self updateTextFields];

	if (self.sCheck.state == NSControlStateValueOn &&
		self.pCheck.state == NSControlStateValueOn)
	{
		if (sender == self.sCheck) {
			self.pCheck.state = NSControlStateValueOff;
		} else {
			self.sCheck.state = NSControlStateValueOff;
		}
	}
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	if (aNotification.object == self.kText) {
		[self updateSecretKeyLengthAlert];
	}
}

- (void)updateSecretKeyLengthAlert
{
	NSUInteger maximumKeyLength = self.client.supportInfo.maximumKeyLength;

	if (maximumKeyLength == 0) {
		return;
	}

	NSUInteger currentKeyLength = self.kText.stringValue.length;

	if (currentKeyLength <= maximumKeyLength) {
		return;
	}

	if (self.secretKeyLengthAlertDisplayed == NO) {
		self.secretKeyLengthAlertDisplayed = YES;
	} else {
		return;
	}

	[TDCAlert alertSheetWithWindow:self.sheet
							  body:TXTLS(@"TDCChannelModifyModesSheet[lir-ra]")
							 title:TXTLS(@"TDCChannelModifyModesSheet[7m9-39]", self.client.networkNameAlt, maximumKeyLength)
					 defaultButton:TXTLS(@"Prompts[c7s-dq]")
				   alternateButton:nil
					   otherButton:nil
					suppressionKey:@"maximum_secret_key_length"
				   suppressionText:nil
				   completionBlock:nil];
}

- (void)ok:(id)sender
{
	[self.modes changeMode:@"i"
				 modeIsSet:(self.iCheck.state == NSControlStateValueOn)];

	[self.modes changeMode:@"m"
				 modeIsSet:(self.mCheck.state == NSControlStateValueOn)];

	[self.modes changeMode:@"n"
				 modeIsSet:(self.nCheck.state == NSControlStateValueOn)];

	[self.modes changeMode:@"p"
				 modeIsSet:(self.pCheck.state == NSControlStateValueOn)];

	[self.modes changeMode:@"s"
				 modeIsSet:(self.sCheck.state == NSControlStateValueOn)];

	[self.modes changeMode:@"t"
				 modeIsSet:(self.tCheck.state == NSControlStateValueOn)];

	[self.modes changeMode:@"k"
				 modeIsSet:(self.kCheck.state == NSControlStateValueOn)
			 modeParameter:self.kText.stringValue];

	[self.modes changeMode:@"l"
				 modeIsSet:(self.lCheck.state == NSControlStateValueOn)
			 modeParameter:self.lText.stringValue];

	if ([self.delegate respondsToSelector:@selector(channelModifyModesSheet:onOk:)]) {
		[self.delegate channelModifyModesSheet:self onOk:self.modes];
	}

	[super ok:nil];
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	if ([self.delegate respondsToSelector:@selector(channelModifyModesSheetWillClose:)]) {
		[self.delegate channelModifyModesSheetWillClose:self];
	}
}

@end

NS_ASSUME_NONNULL_END
