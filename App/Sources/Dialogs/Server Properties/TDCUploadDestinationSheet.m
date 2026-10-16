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

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "TLOLocalization.h"
#import "TLOUploadDestinationPrivate.h"
#import "TVCMainWindowPrivate.h"
#import "TXMasterControllerPrivate.h"
#import "TDCUploadDestinationSheetPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCUploadDestinationSheet ()
@property (nonatomic, strong) NSPanel *panel;
@property (nonatomic, weak) NSWindow *parentWindow;
@property (nonatomic, strong) NSTextField *nameField;
@property (nonatomic, strong) NSTextField *addressField;
@property (nonatomic, strong) NSPopUpButton *methodButton;
@property (nonatomic, strong) NSPopUpButton *bodyButton;
@property (nonatomic, strong) NSTextField *fileFieldNameField;
@property (nonatomic, strong) NSTextView *headersView;
@property (nonatomic, strong) NSTextView *argumentsView;
@property (nonatomic, strong) NSTextView *parametersView;
@property (nonatomic, strong) NSTextField *linkTemplateField;
@property (nonatomic, strong, nullable) NSButton *hideButtonCheckbox;
@property (nonatomic, copy) NSArray<NSString *> *regexes; // from an import, kept
@property (nonatomic, copy, nullable) NSString *errorTemplate;
@property (nonatomic, copy) void (^completionBlock)(TLOUploadDestination * _Nullable destination);
@property (nonatomic, strong, nullable) TDCUploadDestinationSheet *selfReference; // while shown
@end

@implementation TDCUploadDestinationSheet

+ (void)editDestination:(nullable TLOUploadDestination *)destination
			   inWindow:(NSWindow *)window
		showsHideOption:(BOOL)showsHideOption
		completionBlock:(void (^)(TLOUploadDestination * _Nullable destination))completionBlock
{
	NSParameterAssert(window != nil);
	NSParameterAssert(completionBlock != nil);

	TDCUploadDestinationSheet *sheet = [TDCUploadDestinationSheet new];

	sheet.parentWindow = window;
	sheet.completionBlock = completionBlock;
	sheet.regexes = @[];

	[sheet buildPanelWithHideOption:showsHideOption canRemove:(destination != nil)];

	[sheet showDestination:(destination ?: [TLOUploadDestination new])];

	sheet.selfReference = sheet;

	[window beginSheet:sheet.panel completionHandler:nil];
}

+ (void)editGlobalDestinationInWindow:(NSWindow *)window completionBlock:(nullable dispatch_block_t)completionBlock
{
	NSParameterAssert(window != nil);

	[self editDestination:[TLOUploadDestination globalDestination]
				 inWindow:window
		  showsHideOption:YES
		  completionBlock:^(TLOUploadDestination * _Nullable destination) {
			  [TLOUploadDestination setGlobalDestination:destination];

			  [TVCMainWindow updateUploadButton];

			  if (completionBlock) {
				  completionBlock();
			  }
		  }];
}

#pragma mark -
#pragma mark Building

- (NSTextField *)labelWithKey:(NSString *)key
{
	NSTextField *label = [NSTextField labelWithString:TXTLS(key)];

	label.alignment = NSTextAlignmentRight;

	return label;
}

- (NSTextField *)fieldWithPlaceholderKey:(nullable NSString *)placeholderKey
{
	NSTextField *field = [NSTextField textFieldWithString:@""];

	if (placeholderKey) {
		field.placeholderString = TXTLS(placeholderKey);
	}

	[field.widthAnchor constraintGreaterThanOrEqualToConstant:340].active = YES;

	return field;
}

- (NSScrollView *)textAreaWithTextView:(NSTextView * _Nonnull * _Nonnull)textView
{
	NSScrollView *scrollView = [NSTextView scrollableTextView];

	scrollView.borderType = NSBezelBorder;
	scrollView.hasVerticalScroller = YES;

	[scrollView.heightAnchor constraintEqualToConstant:52].active = YES;
	[scrollView.widthAnchor constraintGreaterThanOrEqualToConstant:340].active = YES;

	NSTextView *view = (NSTextView *)scrollView.documentView;

	view.font = [NSFont userFixedPitchFontOfSize:11];
	view.automaticQuoteSubstitutionEnabled = NO;
	view.automaticDashSubstitutionEnabled = NO;
	view.automaticTextReplacementEnabled = NO;
	view.automaticSpellingCorrectionEnabled = NO;
	view.richText = NO;

	*textView = view;

	return scrollView;
}

- (NSTextField *)noteWithKey:(NSString *)key
{
	NSTextField *note = [NSTextField wrappingLabelWithString:TXTLS(key)];

	note.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	note.textColor = [NSColor secondaryLabelColor];

	[note.widthAnchor constraintLessThanOrEqualToConstant:360].active = YES;

	return note;
}

- (void)buildPanelWithHideOption:(BOOL)showsHideOption canRemove:(BOOL)canRemove
{
	NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 560, 480)
												styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskDocModalWindow)
												  backing:NSBackingStoreBuffered
													defer:YES];

	NSView *content = panel.contentView;

	/* Introduction */
	NSTextField *intro = [NSTextField wrappingLabelWithString:TXTLS(@"Prompts[upd-s1]")];

	intro.translatesAutoresizingMaskIntoConstraints = NO;

	[content addSubview:intro];

	/* The parts of an uploader */
	self.nameField = [self fieldWithPlaceholderKey:@"Prompts[upd-f1]"];
	self.addressField = [self fieldWithPlaceholderKey:@"Prompts[upd-f2]"];

	self.methodButton = [NSPopUpButton new];

	[self.methodButton addItemsWithTitles:@[@"POST", @"PUT"]];

	self.bodyButton = [NSPopUpButton new];

	[self.bodyButton addItemsWithTitles:@[TXTLS(@"Prompts[upd-b1]"), TXTLS(@"Prompts[upd-b2]")]];

	self.bodyButton.target = self;
	self.bodyButton.action = @selector(bodyChanged:);

	self.fileFieldNameField = [self fieldWithPlaceholderKey:@"Prompts[upd-f4]"];

	NSTextView *headersView = nil;
	NSTextView *argumentsView = nil;
	NSTextView *parametersView = nil;

	NSScrollView *headersArea = [self textAreaWithTextView:&headersView];
	NSScrollView *argumentsArea = [self textAreaWithTextView:&argumentsView];
	NSScrollView *parametersArea = [self textAreaWithTextView:&parametersView];

	self.headersView = headersView;
	self.argumentsView = argumentsView;
	self.parametersView = parametersView;

	self.linkTemplateField = [self fieldWithPlaceholderKey:@"Prompts[upd-f3]"];

	NSGridView *grid = [NSGridView gridViewWithViews:@[
		@[[self labelWithKey:@"Prompts[upd-l1]"], self.nameField],
		@[[self labelWithKey:@"Prompts[upd-l2]"], self.addressField],
		@[[self labelWithKey:@"Prompts[upd-l3]"], self.methodButton],
		@[[self labelWithKey:@"Prompts[upd-l4]"], self.bodyButton],
		@[[self labelWithKey:@"Prompts[upd-l5]"], self.fileFieldNameField],
		@[[self labelWithKey:@"Prompts[upd-l6]"], headersArea],
		@[[NSGridCell emptyContentView], [self noteWithKey:@"Prompts[upd-n1]"]],
		@[[self labelWithKey:@"Prompts[upd-l7]"], argumentsArea],
		@[[self labelWithKey:@"Prompts[upd-l8]"], parametersArea],
		@[[NSGridCell emptyContentView], [self noteWithKey:@"Prompts[upd-n2]"]],
		@[[self labelWithKey:@"Prompts[upd-l9]"], self.linkTemplateField],
		@[[NSGridCell emptyContentView], [self noteWithKey:@"Prompts[upd-n3]"]]
	]];

	grid.translatesAutoresizingMaskIntoConstraints = NO;
	grid.rowSpacing = 8;
	grid.columnSpacing = 8;
	grid.rowAlignment = NSGridRowAlignmentFirstBaseline;

	[grid columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;

	[content addSubview:grid];

	/* Hide the paperclip where no address applies (Preferences only) */
	NSView *lastView = grid;

	if (showsHideOption) {
		NSButton *checkbox = [NSButton checkboxWithTitle:TXTLS(@"Prompts[upd-h1]") target:nil action:nil];

		checkbox.translatesAutoresizingMaskIntoConstraints = NO;

		checkbox.state = (([TLOUploadDestination hidesUploadButtonWithoutDestination]) ? NSControlStateValueOn : NSControlStateValueOff);

		[content addSubview:checkbox];

		[NSLayoutConstraint activateConstraints:@[
			[checkbox.topAnchor constraintEqualToAnchor:grid.bottomAnchor constant:14],
			[checkbox.leadingAnchor constraintEqualToAnchor:self.nameField.leadingAnchor]
		]];

		self.hideButtonCheckbox = checkbox;

		lastView = checkbox;
	}

	/* Import…            Remove   Cancel   Save */
	NSButton *importButton = [NSButton buttonWithTitle:TXTLS(@"Prompts[upd-i1]") target:self action:@selector(import:)];
	NSButton *cancelButton = [NSButton buttonWithTitle:TXTLS(@"Prompts[d7f-c4]") target:self action:@selector(cancel:)];
	NSButton *saveButton = [NSButton buttonWithTitle:TXTLS(@"Prompts[upd-v1]") target:self action:@selector(save:)];

	cancelButton.keyEquivalent = @"\e";
	saveButton.keyEquivalent = @"\r";

	NSMutableArray *rightButtons = [NSMutableArray array];

	if (canRemove) {
		[rightButtons addObject:[NSButton buttonWithTitle:TXTLS(@"Prompts[upd-r1]") target:self action:@selector(remove:)]];
	}

	[rightButtons addObjectsFromArray:@[cancelButton, saveButton]];

	NSStackView *buttons = [NSStackView stackViewWithViews:[@[importButton] arrayByAddingObjectsFromArray:rightButtons]];

	buttons.translatesAutoresizingMaskIntoConstraints = NO;
	buttons.spacing = 10;

	[buttons setCustomSpacing:40 afterView:importButton];

	[content addSubview:buttons];

	[NSLayoutConstraint activateConstraints:@[
		[intro.topAnchor constraintEqualToAnchor:content.topAnchor constant:18],
		[intro.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
		[intro.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],

		[grid.topAnchor constraintEqualToAnchor:intro.bottomAnchor constant:14],
		[grid.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
		[grid.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],

		[buttons.topAnchor constraintEqualToAnchor:lastView.bottomAnchor constant:18],
		[buttons.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
		[buttons.leadingAnchor constraintGreaterThanOrEqualToAnchor:content.leadingAnchor constant:20],
		[buttons.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-18]
	]];

	self.panel = panel;
}

- (void)bodyChanged:(nullable id)sender
{
	self.fileFieldNameField.enabled = (self.bodyButton.indexOfSelectedItem == TLOUploadDestinationBodyMultipart);
}

#pragma mark -
#pragma mark Values

/* "Name: value" (headers) or "name=value" lines */
+ (NSString *)linesForDictionary:(NSDictionary<NSString *, NSString *> *)dictionary separator:(NSString *)separator
{
	NSMutableArray *lines = [NSMutableArray arrayWithCapacity:dictionary.count];

	for (NSString *key in [dictionary.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
		[lines addObject:[NSString stringWithFormat:@"%@%@%@", key, separator, dictionary[key]]];
	}

	return [lines componentsJoinedByString:@"\n"];
}

+ (NSDictionary<NSString *, NSString *> *)dictionaryForLines:(NSString *)text separator:(NSString *)separator
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

	for (NSString *line in [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
		NSRange separatorRange = [line rangeOfString:separator];

		if (separatorRange.location == NSNotFound) {
			continue;
		}

		NSString *key = [[line substringToIndex:separatorRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSString *value = [[line substringFromIndex:NSMaxRange(separatorRange)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

		if (key.length > 0) {
			dictionary[key] = value;
		}
	}

	return [dictionary copy];
}

- (void)showDestination:(TLOUploadDestination *)destination
{
	NSParameterAssert(destination != nil);

	self.nameField.stringValue = destination.name;
	self.addressField.stringValue = destination.requestAddress;

	[self.methodButton selectItemWithTitle:destination.method];

	[self.bodyButton selectItemAtIndex:destination.body];

	self.fileFieldNameField.stringValue = (([destination.fileFieldName isEqualToString:@"file"]) ? @"" : destination.fileFieldName);

	self.headersView.string = [self.class linesForDictionary:destination.headers separator:@": "];
	self.argumentsView.string = [self.class linesForDictionary:destination.arguments separator:@"="];
	self.parametersView.string = [self.class linesForDictionary:destination.parameters separator:@"="];

	self.linkTemplateField.stringValue = (destination.linkTemplate ?: @"");

	self.regexes = destination.regexes;
	self.errorTemplate = destination.errorTemplate;

	[self bodyChanged:nil];
}

- (TLOUploadDestination *)destinationFromFields
{
	TLOUploadDestination *destination = [TLOUploadDestination new];

	NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];

	destination.requestAddress = [self.addressField.stringValue stringByTrimmingCharactersInSet:whitespace];

	NSString *name = [self.nameField.stringValue stringByTrimmingCharactersInSet:whitespace];

	destination.name = ((name.length > 0) ? name : ([NSURL URLWithString:destination.requestAddress].host ?: destination.requestAddress));

	destination.method = (self.methodButton.titleOfSelectedItem ?: @"POST");
	destination.body = ((self.bodyButton.indexOfSelectedItem == TLOUploadDestinationBodyBinary) ? TLOUploadDestinationBodyBinary : TLOUploadDestinationBodyMultipart);

	NSString *fileFieldName = [self.fileFieldNameField.stringValue stringByTrimmingCharactersInSet:whitespace];

	destination.fileFieldName = ((fileFieldName.length > 0) ? fileFieldName : @"file");

	destination.headers = [self.class dictionaryForLines:self.headersView.string separator:@":"];
	destination.arguments = [self.class dictionaryForLines:self.argumentsView.string separator:@"="];
	destination.parameters = [self.class dictionaryForLines:self.parametersView.string separator:@"="];

	NSString *linkTemplate = [self.linkTemplateField.stringValue stringByTrimmingCharactersInSet:whitespace];

	destination.linkTemplate = ((linkTemplate.length > 0) ? linkTemplate : nil);

	destination.regexes = self.regexes;
	destination.errorTemplate = self.errorTemplate;

	return destination;
}

#pragma mark -
#pragma mark Actions

- (void)showProblem:(NSString *)problem title:(NSString *)title
{
	NSAlert *alert = [NSAlert new];

	alert.messageText = title;
	alert.informativeText = problem;

	[alert beginSheetModalForWindow:self.panel completionHandler:nil];
}

- (void)import:(nullable id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];

	openPanel.canChooseFiles = YES;
	openPanel.canChooseDirectories = NO;
	openPanel.allowsMultipleSelection = NO;

	UTType *sxcuType = [UTType typeWithFilenameExtension:@"sxcu"];

	openPanel.allowedContentTypes = ((sxcuType) ? @[sxcuType, UTTypeJSON] : @[UTTypeJSON]);

	[openPanel beginSheetModalForWindow:self.panel completionHandler:^(NSModalResponse returnCode) {
		if (returnCode != NSModalResponseOK || openPanel.URL == nil) {
			return;
		}

		NSData *data = [NSData dataWithContentsOfURL:openPanel.URL];

		NSString *failureReason = nil;

		TLOUploadDestination *destination = ((data) ? [TLOUploadDestination destinationWithShareXData:data failureReason:&failureReason] : nil);

		if (destination == nil) {
			[self showProblem:(failureReason ?: TXTLS(@"Prompts[upd-x1]")) title:TXTLS(@"Prompts[upd-e1]", openPanel.URL.lastPathComponent)];

			return;
		}

		[self showDestination:destination];
	}];
}

- (void)save:(nullable id)sender
{
	TLOUploadDestination *destination = [self destinationFromFields];

	/* No address, only the option to hide the paperclip: none */
	if (destination.requestAddress.length == 0 && self.hideButtonCheckbox) {
		[self remove:nil];

		return;
	}

	NSString *problem = destination.problem;

	if (problem) {
		[self showProblem:problem title:TXTLS(@"Prompts[upd-e2]")];

		return;
	}

	if (self.hideButtonCheckbox) {
		[TLOUploadDestination setHidesUploadButtonWithoutDestination:(self.hideButtonCheckbox.state == NSControlStateValueOn)];
	}

	[self finishWithDestination:destination];
}

- (void)remove:(nullable id)sender
{
	if (self.hideButtonCheckbox) {
		[TLOUploadDestination setHidesUploadButtonWithoutDestination:(self.hideButtonCheckbox.state == NSControlStateValueOn)];
	}

	[self finishWithDestination:nil];
}

- (void)cancel:(nullable id)sender
{
	[self.parentWindow endSheet:self.panel];

	self.selfReference = nil;
}

- (void)finishWithDestination:(nullable TLOUploadDestination *)destination
{
	[self.parentWindow endSheet:self.panel];

	self.completionBlock(destination);

	self.selfReference = nil;
}

@end

NS_ASSUME_NONNULL_END
