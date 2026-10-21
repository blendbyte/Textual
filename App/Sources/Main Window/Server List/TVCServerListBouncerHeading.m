/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

#import "IRCBouncerAccountPrivate.h"
#import "IRCClientConfigPrivate.h"
#import "IRCClientPrivate.h"
#import "IRCWorldPrivate.h"
#import "TLOLocalization.h"
#import "TXGlobalModels.h"
#import "TXMasterControllerPrivate.h"
#import "TVCServerListBouncerHeadingPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TVCServerListBouncerHeading

- (instancetype)initWithAccountIdentifier:(NSString *)accountIdentifier
{
	NSParameterAssert(accountIdentifier != nil);

	if ((self = [super init])) {
		self->_accountIdentifier = [accountIdentifier copy];

		return self;
	}

	return nil;
}

- (nullable IRCBouncerAccount *)account
{
	return [worldController() findBouncerAccountWithId:self.accountIdentifier];
}

- (NSArray<IRCClient *> *)clients
{
	NSMutableArray *clients = [NSMutableArray array];

	for (IRCClient *client in worldController().clientList) {
		if ([client.config.bouncerAccountIdentifier isEqualToString:self.accountIdentifier]) {
			[clients addObject:client];
		}
	}

	return [clients copy];
}

- (BOOL)isClient
{
	return NO;
}

- (BOOL)isChannel
{
	return NO;
}

- (BOOL)isPrivateMessage
{
	return NO;
}

- (NSUInteger)numberOfChildren
{
	return 0;
}

@end

#pragma mark -

@implementation TVCServerListSectionGap

- (BOOL)isClient
{
	return NO;
}

- (BOOL)isChannel
{
	return NO;
}

- (BOOL)isPrivateMessage
{
	return NO;
}

- (NSUInteger)numberOfChildren
{
	return 0;
}

@end

BOOL TVCServerListItemIsDecoration(id _Nullable item)
{
	return ([item isKindOfClass:[TVCServerListBouncerHeading class]] || [item isKindOfClass:[TVCServerListSectionGap class]]);
}

#pragma mark -

@interface TVCServerListBouncerHeadingView ()
@property (nonatomic, strong) NSTextField *titleField;
@property (nonatomic, strong) NSTextField *kindField;
@property (nonatomic, strong) NSButton *chevronButton;
@property (nonatomic, assign) BOOL folded;
@end

@implementation TVCServerListBouncerHeadingView

+ (NSString *)viewIdentifier
{
	return @"BouncerHeadingView";
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect])) {
		self.identifier = [self.class viewIdentifier];

		[self setUpSubviews];

		return self;
	}

	return nil;
}

/* As Finder's sidebar sections: small, bold, grey; the kind lighter after the name */
- (void)setUpSubviews
{
	NSTextField *titleField = [NSTextField labelWithString:@""];

	titleField.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold];
	titleField.textColor = [NSColor secondaryLabelColor];
	titleField.lineBreakMode = NSLineBreakByTruncatingTail;
	titleField.translatesAutoresizingMaskIntoConstraints = NO;

	[titleField setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

	NSTextField *kindField = [NSTextField labelWithString:@""];

	kindField.font = [NSFont systemFontOfSize:10.0];
	kindField.textColor = [NSColor tertiaryLabelColor];
	kindField.translatesAutoresizingMaskIntoConstraints = NO;

	[kindField setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];

	NSButton *chevronButton = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"chevron.down" accessibilityDescription:nil]
												 target:self
												 action:@selector(chevronClicked:)];

	chevronButton.bordered = NO;
	chevronButton.contentTintColor = [NSColor tertiaryLabelColor];
	chevronButton.imageScaling = NSImageScaleProportionallyDown;
	chevronButton.translatesAutoresizingMaskIntoConstraints = NO;

	chevronButton.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:9.0 weight:NSFontWeightSemibold];

	[self addSubview:titleField];
	[self addSubview:kindField];
	[self addSubview:chevronButton];

	self.titleField = titleField;
	self.kindField = kindField;
	self.chevronButton = chevronButton;

	/* The name where a server's name starts, near the bottom (space above the section) */
	[NSLayoutConstraint activateConstraints:@[
		[titleField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:5.0],
		[titleField.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4.0],
		[kindField.leadingAnchor constraintEqualToAnchor:titleField.trailingAnchor constant:5.0],
		[kindField.firstBaselineAnchor constraintEqualToAnchor:titleField.firstBaselineAnchor],
		[kindField.trailingAnchor constraintLessThanOrEqualToAnchor:chevronButton.leadingAnchor constant:-4.0],
		[chevronButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8.0],
		[chevronButton.centerYAnchor constraintEqualToAnchor:titleField.centerYAnchor],
		[chevronButton.widthAnchor constraintEqualToConstant:14.0],
		[chevronButton.heightAnchor constraintEqualToConstant:14.0]
	]];
}

- (void)showHeading:(TVCServerListBouncerHeading *)heading folded:(BOOL)folded
{
	NSParameterAssert(heading != nil);

	IRCBouncerAccount *account = heading.account;

	NSString *title = account.displayName;
	NSString *kind = [self.class nameOfKind:account.kind];

	self.folded = folded;

	self.titleField.stringValue = (title ?: @"");
	self.kindField.stringValue = (kind ?: @"");

	self.chevronButton.image = [NSImage imageWithSystemSymbolName:((folded) ? @"chevron.right" : @"chevron.down") accessibilityDescription:nil];

	/* VoiceOver: one element, a group with its bouncer, folded or not */
	NSString *description = ((kind) ? TXTLS(@"BasicLanguage[bnc-h1]", title, kind) : title);

	if (folded) {
		description = TXTLS(@"BasicLanguage[bnc-h2]", description);
	}

	self.chevronButton.accessibilityLabel = TXTLS((folded) ? @"BasicLanguage[bnc-h3]" : @"BasicLanguage[bnc-h4]");

	self.accessibilityLabel = description;
	self.accessibilityRole = NSAccessibilityGroupRole;
}

+ (nullable NSString *)nameOfKind:(IRCBouncerKind)kind
{
	switch (kind) {
		case IRCBouncerKindSoju:
			return TXTLS(@"BasicLanguage[bnc-k1]");
		case IRCBouncerKindZNC:
			return TXTLS(@"BasicLanguage[bnc-k2]");
		default:
			return nil;
	}
}

- (void)chevronClicked:(id)sender
{
	if (self.toggleFolding) {
		self.toggleFolding();
	}
}

@end

NS_ASSUME_NONNULL_END
