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

#include "BuildConfig.h"

#import "TDCAlert.h"
#import "TLOLocalization.h"
#import "TPCLegacyImportPrivate.h"
#import "TDCLegacyImportAssistantPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _windowWidth		600.0
#define _sideMargin			44.0
#define _bodyWidth			(_windowWidth - (_sideMargin * 2))
#define _headerTopSpacing	40.0
#define _headerBodySpacing	24.0
#define _bodyFooterSpacing	28.0
#define _footerBottomSpacing	22.0
#define _noteTextWidth		(_bodyWidth - 170)

typedef NS_ENUM(NSUInteger, TDCLegacyImportAssistantStep) {
	TDCLegacyImportAssistantStepWelcome,
	TDCLegacyImportAssistantStepAccess,
	TDCLegacyImportAssistantStepImporting,
	TDCLegacyImportAssistantStepLicense,
	TDCLegacyImportAssistantStepDone
};

@interface TDCLegacyImportAssistant () <NSWindowDelegate, NSOpenSavePanelDelegate>
@property (nonatomic, assign) BOOL fromMenu;
@property (nonatomic, assign) TDCLegacyImportAssistantStep step;
@property (nonatomic, copy) NSArray<TPCLegacyImportSource *> *sources;
@property (nonatomic, strong) TPCLegacyImportSource *source;
@property (nonatomic, strong, nullable) TPCLegacyImport *import;
@property (nonatomic, copy, nullable) NSURL *groupURL;
@property (nonatomic, copy, nullable) NSURL *preferencesURL;
@property (nonatomic, copy, nullable) NSString *accessProblem;
@property (nonatomic, assign) BOOL nothingToImport;
@property (nonatomic, assign) BOOL grantingPreferencesFile;
@property (nonatomic, copy, nullable) NSURL *panelItemURL;
@property (nonatomic, assign) BOOL deleteEarlierData;
@property (nonatomic, strong, nullable) NSTimer *runningTimer;

@property (nonatomic, strong) NSStackView *headerStack;
@property (nonatomic, strong) NSStackView *footerStack;
@property (nonatomic, strong) NSImageView *headerImageView;
@property (nonatomic, strong) NSTextField *titleField;
@property (nonatomic, strong) NSTextField *subtitleField;
@property (nonatomic, strong) NSView *bodyContainer;
@property (nonatomic, strong) NSButton *primaryButton;
@property (nonatomic, strong) NSButton *secondaryButton;
@property (nonatomic, strong) NSButton *checkbox;

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSStackView *> *progressRows;
@end

@implementation TDCLegacyImportAssistant

#pragma mark -
#pragma mark Entry Points

+ (void)offerImportAtLaunchThen:(dispatch_block_t)completion
{
	NSParameterAssert(completion != nil);

	if ([TPCLegacyImport shouldOfferAtLaunch] == NO) {
		completion();

		return;
	}

	/* Not before the app has finished launching: a modal session started
	 earlier finishes launching early, and the main window ordered in after
	 it never appears on screen. Started from the run loop, not the main
	 queue, which the import needs while the assistant is open. */
	[[NSRunLoop mainRunLoop] performInModes:@[NSDefaultRunLoopMode] block:^{
		[[[self alloc] initFromMenu:NO] _runModal];

		completion();
	}];
}

+ (void)importFromMenu
{
	if ([TPCLegacyImport availableSources].count == 0) {
		[TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[1nk-dm]")
								  title:TXTLS(@"Prompts[2e4-mp]")
						  defaultButton:TXTLS(@"Prompts[oxy-im]")
						alternateButton:nil];

		return;
	}

	[[[self alloc] initFromMenu:YES] _runModal];
}

- (instancetype)initFromMenu:(BOOL)fromMenu
{
	NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, _windowWidth, 400)
												   styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskFullSizeContentView)
													 backing:NSBackingStoreBuffered
													   defer:NO];

	if ((self = [super initWithWindow:window])) {
		self.fromMenu = fromMenu;
		self.sources = [TPCLegacyImport availableSources];
		self.source = self.sources.firstObject;
		self.progressRows = [NSMutableDictionary dictionary];

		window.title = (fromMenu ? TXTLS(@"Prompts[k3w-q8]") : TXTLS(@"Prompts[cfi-p6]"));
		window.titlebarAppearsTransparent = YES;
		window.titleVisibility = NSWindowTitleHidden;
		window.movableByWindowBackground = YES;
		window.delegate = self;

		[window standardWindowButton:NSWindowMiniaturizeButton].hidden = YES;
		[window standardWindowButton:NSWindowZoomButton].hidden = YES;

		[self _buildWindow];

		[self _showStep:TDCLegacyImportAssistantStepWelcome];
	}

	return self;
}

- (void)_runModal
{
	[self.window center];

	[NSApp runModalForWindow:self.window];

	[self.runningTimer invalidate];

	[self.window orderOut:nil];
}

- (void)_finish
{
	[NSApp stopModal];
}

- (BOOL)windowShouldClose:(NSWindow *)sender
{
	/* Not while files are being copied */
	if (self.step == TDCLegacyImportAssistantStepImporting) {
		return NO;
	}

	/* Closing at launch is "not now": offered again next time. After an
	 import from the menu, Textual still has to restart. */
	if (self.step == TDCLegacyImportAssistantStepDone) {
		[self _primaryClicked:nil];

		return NO;
	}

	[self _finish];

	return NO;
}

#pragma mark -
#pragma mark Layout

- (NSTextField *)_labelWithString:(NSString *)string font:(NSFont *)font color:(NSColor *)color width:(CGFloat)width
{
	NSTextField *label = [NSTextField wrappingLabelWithString:string];

	label.font = font;
	label.textColor = color;
	label.preferredMaxLayoutWidth = width;
	label.selectable = NO;

	return label;
}

- (NSImageView *)_symbol:(NSString *)name size:(CGFloat)size color:(nullable NSColor *)color
{
	NSImageView *imageView = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:name accessibilityDescription:nil]];

	imageView.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:size weight:NSFontWeightRegular];
	imageView.contentTintColor = color;
	imageView.translatesAutoresizingMaskIntoConstraints = NO;

	[imageView.widthAnchor constraintEqualToConstant:(size + 6)].active = YES;

	return imageView;
}

/* A symbol and a line of text */
- (NSStackView *)_rowWithSymbol:(NSString *)symbol color:(nullable NSColor *)color text:(NSString *)text
{
	NSTextField *label = [self _labelWithString:text font:[NSFont systemFontOfSize:13] color:[NSColor labelColor] width:(_bodyWidth - 30)];

	NSStackView *row = [NSStackView stackViewWithViews:@[[self _symbol:symbol size:15 color:color], label]];

	row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
	row.alignment = NSLayoutAttributeFirstBaseline;
	row.spacing = 8;

	return row;
}

- (void)_buildWindow
{
	NSView *contentView = self.window.contentView;

	self.headerImageView = [NSImageView new];
	self.headerImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
	self.headerImageView.translatesAutoresizingMaskIntoConstraints = NO;

	self.titleField = [self _labelWithString:@"" font:[NSFont systemFontOfSize:22 weight:NSFontWeightSemibold] color:[NSColor labelColor] width:_bodyWidth];
	self.titleField.alignment = NSTextAlignmentCenter;

	self.subtitleField = [self _labelWithString:@"" font:[NSFont systemFontOfSize:13] color:[NSColor secondaryLabelColor] width:_bodyWidth];
	self.subtitleField.alignment = NSTextAlignmentCenter;

	NSStackView *header = [NSStackView stackViewWithViews:@[self.headerImageView, self.titleField, self.subtitleField]];

	header.orientation = NSUserInterfaceLayoutOrientationVertical;
	header.alignment = NSLayoutAttributeCenterX;
	header.spacing = 8;
	header.translatesAutoresizingMaskIntoConstraints = NO;

	[header setCustomSpacing:14 afterView:self.headerImageView];

	self.headerStack = header;

	self.bodyContainer = [NSView new];
	self.bodyContainer.translatesAutoresizingMaskIntoConstraints = NO;

	self.checkbox = [NSButton checkboxWithTitle:@"" target:self action:@selector(_checkboxClicked:)];

	self.secondaryButton = [NSButton buttonWithTitle:@"" target:self action:@selector(_secondaryClicked:)];
	self.secondaryButton.keyEquivalent = @"\e";

	self.primaryButton = [NSButton buttonWithTitle:@"" target:self action:@selector(_primaryClicked:)];
	self.primaryButton.keyEquivalent = @"\r";

	NSView *spacer = [NSView new];

	[spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

	NSStackView *footer = [NSStackView stackViewWithViews:@[self.checkbox, spacer, self.secondaryButton, self.primaryButton]];

	footer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
	footer.spacing = 12;
	footer.translatesAutoresizingMaskIntoConstraints = NO;

	self.footerStack = footer;

	[contentView addSubview:header];
	[contentView addSubview:self.bodyContainer];
	[contentView addSubview:footer];

	[NSLayoutConstraint activateConstraints:@[
		[self.headerImageView.widthAnchor constraintEqualToConstant:72],
		[self.headerImageView.heightAnchor constraintEqualToConstant:72],

		[header.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:_headerTopSpacing],
		[header.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:_sideMargin],
		[header.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-_sideMargin],

		[self.bodyContainer.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:_headerBodySpacing],
		[self.bodyContainer.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:_sideMargin],
		[self.bodyContainer.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-_sideMargin],
		[self.bodyContainer.bottomAnchor constraintLessThanOrEqualToAnchor:footer.topAnchor constant:-_bodyFooterSpacing],

		[footer.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24],
		[footer.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24],
		[footer.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-_footerBottomSpacing]
	]];
}

- (void)_setBody:(NSView *)body
{
	for (NSView *subview in self.bodyContainer.subviews.copy) {
		[subview removeFromSuperview];
	}

	body.translatesAutoresizingMaskIntoConstraints = NO;

	[self.bodyContainer addSubview:body];

	[NSLayoutConstraint activateConstraints:@[
		[body.topAnchor constraintEqualToAnchor:self.bodyContainer.topAnchor],
		[body.leadingAnchor constraintEqualToAnchor:self.bodyContainer.leadingAnchor],
		[body.trailingAnchor constraintLessThanOrEqualToAnchor:self.bodyContainer.trailingAnchor],
		[body.bottomAnchor constraintEqualToAnchor:self.bodyContainer.bottomAnchor]
	]];
}

- (NSStackView *)_verticalStackWithViews:(NSArray<NSView *> *)views
{
	NSStackView *stack = [NSStackView stackViewWithViews:views];

	stack.orientation = NSUserInterfaceLayoutOrientationVertical;
	stack.alignment = NSLayoutAttributeLeading;
	stack.spacing = 10;

	return stack;
}

- (void)_setHeaderSymbol:(nullable NSString *)symbol color:(nullable NSColor *)color title:(NSString *)title subtitle:(NSString *)subtitle
{
	if (symbol) {
		self.headerImageView.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
		self.headerImageView.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:52 weight:NSFontWeightLight];
		self.headerImageView.contentTintColor = color;
	} else {
		self.headerImageView.image = [NSApp applicationIconImage];
		self.headerImageView.symbolConfiguration = nil;
		self.headerImageView.contentTintColor = nil;
	}

	self.titleField.stringValue = title;
	self.subtitleField.stringValue = subtitle;
}

- (void)_setPrimary:(nullable NSString *)primary secondary:(nullable NSString *)secondary checkbox:(nullable NSString *)checkbox
{
	self.primaryButton.title = (primary ?: @"");
	self.primaryButton.hidden = (primary == nil);
	self.primaryButton.enabled = YES;

	self.secondaryButton.title = (secondary ?: @"");
	self.secondaryButton.hidden = (secondary == nil);

	self.checkbox.title = (checkbox ?: @"");
	self.checkbox.hidden = (checkbox == nil);
	self.checkbox.state = NSControlStateValueOff;

	self.deleteEarlierData = NO;
}

#pragma mark -
#pragma mark Steps

- (void)_showStep:(TDCLegacyImportAssistantStep)step
{
	self.step = step;

	[self.runningTimer invalidate];
	self.runningTimer = nil;

	switch (step) {
		case TDCLegacyImportAssistantStepWelcome:
			[self _showWelcome];
			break;
		case TDCLegacyImportAssistantStepAccess:
			[self _showAccess];
			break;
		case TDCLegacyImportAssistantStepImporting:
			[self _showImporting];
			break;
		case TDCLegacyImportAssistantStepLicense:
			[self _showLicense];
			break;
		case TDCLegacyImportAssistantStepDone:
			[self _showDone];
			break;
	}

	[self _resizeToFit];
}

/* Each step is as tall as its content; the window grows or shrinks
 downwards from its title bar */
- (void)_resizeToFit
{
	CGFloat height = (_headerTopSpacing + self.headerStack.fittingSize.height +
					  _headerBodySpacing + self.bodyContainer.subviews.firstObject.fittingSize.height +
					  _bodyFooterSpacing + self.footerStack.fittingSize.height + _footerBottomSpacing);

	NSWindow *window = self.window;

	NSRect oldFrame = window.frame;

	NSRect newFrame = [window frameRectForContentRect:NSMakeRect(0, 0, _windowWidth, ceil(height))];

	newFrame.origin.x = NSMinX(oldFrame);
	newFrame.origin.y = (NSMaxY(oldFrame) - NSHeight(newFrame));

	[window setFrame:newFrame display:YES animate:window.visible];
}

#pragma mark Welcome

- (void)_showWelcome
{
	NSString *name = self.source.displayName;

	/* From the menu, Textual 8 is already in use: no welcome */
	if (self.fromMenu) {
		[self _setHeaderSymbol:nil color:nil
						 title:TXTLS(@"Prompts[r7d-m2]")
					  subtitle:TXTLS(@"Prompts[x5p-v9]", name)];
	} else {
		[self _setHeaderSymbol:nil color:nil
						 title:TXTLS(@"Prompts[nzb-35]")
					  subtitle:TXTLS(@"Prompts[3y5-mz]", name)];
	}

	NSMutableArray<NSView *> *views = [NSMutableArray array];

	NSColor *green = [NSColor systemGreenColor];

	[views addObject:[self _rowWithSymbol:@"checkmark.circle.fill" color:green text:TXTLS(@"Prompts[f5o-br]")]];
	[views addObject:[self _rowWithSymbol:@"checkmark.circle.fill" color:green text:TXTLS(@"Prompts[704-yh]")]];
	[views addObject:[self _rowWithSymbol:@"checkmark.circle.fill" color:green text:TXTLS(@"Prompts[qge-yy]")]];
	[views addObject:[self _rowWithSymbol:@"checkmark.circle.fill" color:green text:TXTLS(@"Prompts[gdv-pf]")]];

	if (self.source.licenseFolderURL) {
		[views addObject:[self _rowWithSymbol:@"checkmark.circle.fill" color:green text:TXTLS(@"Prompts[57n-je]")]];
	}

	NSView *lastItem = views.lastObject;

	/* More than one earlier version: choose */
	if (self.sources.count > 1) {
		NSTextField *chooseLabel = [self _labelWithString:TXTLS(@"Prompts[8c5-mj]") font:[NSFont systemFontOfSize:13] color:[NSColor secondaryLabelColor] width:_bodyWidth];

		[views addObject:chooseLabel];

		NSMutableArray<NSView *> *radios = [NSMutableArray array];

		[self.sources enumerateObjectsUsingBlock:^(TPCLegacyImportSource *candidate, NSUInteger index, BOOL *stop) {
			NSButton *radio = [NSButton radioButtonWithTitle:[self _descriptionOfSource:candidate capitalized:YES] target:self action:@selector(_sourceChosen:)];

			radio.tag = (NSInteger)index;
			radio.state = ((candidate == self.source) ? NSControlStateValueOn : NSControlStateValueOff);

			[radios addObject:radio];
		}];

		NSStackView *radioStack = [self _verticalStackWithViews:radios];

		radioStack.spacing = 6;

		[views addObject:radioStack];
	} else {
		[views addObject:[self _rowWithSymbol:@"magnifyingglass" color:[NSColor secondaryLabelColor] text:TXTLS(@"Prompts[32s-9w]", [self _descriptionOfSource:self.source capitalized:NO])]];
	}

	BOOL replacing = [TPCLegacyImport hasServers];

	if (replacing) {
		[views addObject:[self _rowWithSymbol:@"exclamationmark.triangle.fill" color:[NSColor systemOrangeColor] text:TXTLS(@"Prompts[1ik-g8]")]];
	} else {
		[views addObject:[self _rowWithSymbol:@"lock.fill" color:[NSColor secondaryLabelColor] text:TXTLS(@"Prompts[uw5-6m]", name)]];
	}

	NSStackView *runningRow = [self _rowWithSymbol:@"xmark.octagon.fill" color:[NSColor systemRedColor] text:TXTLS(@"Prompts[tjw-7s]")];

	[views addObject:runningRow];

	NSStackView *body = [self _verticalStackWithViews:views];

	[body setCustomSpacing:18 afterView:lastItem];

	[self _setBody:body];

	[self _setPrimary:(replacing ? TXTLS(@"Prompts[6e6-8o]") : TXTLS(@"Prompts[zjw-bd]"))
			secondary:(self.fromMenu ? TXTLS(@"Prompts[qso-2g]") : TXTLS(@"Prompts[wpa-sv]"))
			 checkbox:nil];

	/* Textual 7 must not change its files while they are copied: the button
	 waits until it has quit */
	void (^updateRunning)(void) = ^{
		BOOL running = [TPCLegacyImport earlierVersionIsRunning];

		runningRow.hidden = (running == NO);

		self.primaryButton.enabled = (running == NO);
	};

	updateRunning();

	self.runningTimer = [NSTimer timerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
		updateRunning();
	}];

	[[NSRunLoop currentRunLoop] addTimer:self.runningTimer forMode:NSRunLoopCommonModes];
}

- (NSString *)_descriptionOfSource:(TPCLegacyImportSource *)source capitalized:(BOOL)capitalized
{
	NSString *name = source.displayName;

	if (capitalized) {
		name = [[name substringToIndex:1].localizedUppercaseString stringByAppendingString:[name substringFromIndex:1]];
	}

	NSDate *lastUsed = source.lastUsedDate;

	if (lastUsed == nil) {
		return name;
	}

	NSRelativeDateTimeFormatter *formatter = [NSRelativeDateTimeFormatter new];

	formatter.unitsStyle = NSRelativeDateTimeFormatterUnitsStyleFull;

	return TXTLS(@"Prompts[orc-1q]", name, [formatter localizedStringForDate:lastUsed relativeToDate:[NSDate date]]);
}

- (void)_sourceChosen:(NSButton *)sender
{
	self.source = self.sources[sender.tag];

	[self _showStep:TDCLegacyImportAssistantStepWelcome];
}

#pragma mark Access

- (void)_showAccess
{
	NSString *name = self.source.displayName;

	/* Readable, but no settings in it: only Back makes sense */
	if (self.nothingToImport) {
		[self _setHeaderSymbol:@"tray" color:[NSColor secondaryLabelColor]
						 title:TXTLS(@"Prompts[q8n-t4]")
					  subtitle:TXTLS(@"Prompts[v12-hf]", name)];

		[self _setBody:[self _verticalStackWithViews:@[]]];

		[self _setPrimary:TXTLS(@"Prompts[ivy-ht]") secondary:nil checkbox:nil];

		return;
	}

	if (self.grantingPreferencesFile) {
		[self _setHeaderSymbol:@"doc.badge.gearshape" color:[NSColor controlAccentColor]
						 title:TXTLS(@"Prompts[yt0-lz]")
					  subtitle:TXTLS(@"Prompts[hkb-mk]", name)];
	} else {
		[self _setHeaderSymbol:@"lock.shield" color:[NSColor controlAccentColor]
						 title:TXTLS(@"Prompts[tha-yv]")
					  subtitle:TXTLS(@"Prompts[k1o-i0]", name)];
	}

	NSMutableArray<NSView *> *views = [NSMutableArray array];

	[views addObject:[self _rowWithSymbol:@"1.circle.fill" color:[NSColor controlAccentColor] text:TXTLS(@"Prompts[200-fe]")]];
	[views addObject:[self _rowWithSymbol:@"2.circle.fill" color:[NSColor controlAccentColor] text:TXTLS(@"Prompts[sgc-fg]")]];
	[views addObject:[self _rowWithSymbol:@"eye.fill" color:[NSColor secondaryLabelColor] text:TXTLS(@"Prompts[77x-j6]")]];

	if (self.accessProblem) {
		[views addObject:[self _rowWithSymbol:@"exclamationmark.triangle.fill" color:[NSColor systemOrangeColor] text:self.accessProblem]];
	}

	[self _setBody:[self _verticalStackWithViews:views]];

	[self _setPrimary:TXTLS(@"Prompts[5je-mb]") secondary:TXTLS(@"Prompts[ivy-ht]") checkbox:nil];
}

- (void)_requestAccess
{
	TPCLegacyImportSource *source = self.source;

	if (self.grantingPreferencesFile) {
		NSURL *fileURL = source.outsidePreferencesURL;

		NSOpenPanel *panel = [self _panelSelectingItemAtURL:fileURL isFolder:NO message:TXTLS(@"Prompts[fh6-zg]", source.displayName)];

		[panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
			if (response != NSModalResponseOK || panel.URL == nil) {
				return;
			}

			self.preferencesURL = panel.URL;

			[self _readPreferences];
		}];

		return;
	}

	NSOpenPanel *panel = [self _panelSelectingItemAtURL:source.groupURL isFolder:YES message:TXTLS(@"Prompts[qsc-uk]", source.displayName)];

	[panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
		if (response != NSModalResponseOK || panel.URL == nil) {
			return;
		}

		[TPCLegacyImport rememberGrantedURL:panel.URL];

		[self _useGroupURL:panel.URL];
	}];
}

/* macOS only lets Textual read another app's files once the user picked
 them in an open panel, so the panel opens with the item selected: one click
 on Grant Access. Everything else is greyed out, and choosing anything else
 explains itself and keeps the panel open. (The panel runs outside the app,
 so it can't be moved back to the item once it is open.) */
- (NSOpenPanel *)_panelSelectingItemAtURL:(NSURL *)itemURL isFolder:(BOOL)isFolder message:(NSString *)message
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];

	panel.canChooseDirectories = isFolder;
	panel.canChooseFiles = (isFolder == NO);
	panel.allowsMultipleSelection = NO;
	panel.canCreateDirectories = NO;
	panel.directoryURL = itemURL;
	panel.message = message;
	panel.prompt = TXTLS(@"Prompts[5wl-b5]");
	panel.delegate = self;

	self.panelItemURL = itemURL;

	return panel;
}

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url
{
	NSString *itemPath = self.panelItemURL.URLByStandardizingPath.path;

	if (itemPath == nil) {
		return YES;
	}

	NSString *path = url.URLByStandardizingPath.path;

	/* The item and the folders leading to it */
	return ([path isEqualToString:itemPath] ||
			[itemPath hasPrefix:[path stringByAppendingString:@"/"]]);
}

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError
{
	NSURL *itemURL = self.panelItemURL;

	if (itemURL == nil || [url.URLByStandardizingPath.path isEqualToString:itemURL.URLByStandardizingPath.path]) {
		return YES;
	}

	if (outError) {
		/* Not NSUserCancelledError: the panel doesn't show those */
		*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoPermissionError userInfo:@{
			NSLocalizedDescriptionKey : TXTLS(@"Prompts[mzr-ak]", itemURL.lastPathComponent),
			NSLocalizedRecoverySuggestionErrorKey : TXTLS(@"Prompts[wux-a5]")
		}];
	}

	return NO;
}

- (void)_useGroupURL:(NSURL *)groupURL
{
	self.groupURL = groupURL;

	[groupURL startAccessingSecurityScopedResource];

	/* Before the sandbox, the preferences were outside the folder */
	if (self.source.outsidePreferencesURL) {
		self.grantingPreferencesFile = YES;
		self.accessProblem = nil;

		[self _showStep:TDCLegacyImportAssistantStepAccess];

		return;
	}

	self.preferencesURL = [self.import preferencesURLInGroupURL:groupURL];

	[self _readPreferences];
}

- (void)_readPreferences
{
	BOOL outside = (self.source.outsidePreferencesURL != nil);

	if (outside) {
		[self.preferencesURL startAccessingSecurityScopedResource];
	}

	TPCLegacyImportReadError error = [self.import readPreferencesAtURL:self.preferencesURL];

	if (outside) {
		[self.preferencesURL stopAccessingSecurityScopedResource];
	}

	if (error == TPCLegacyImportReadErrorUnreadable) {
		self.accessProblem = TXTLS(@"Prompts[ndc-ll]");

		[self _showStep:TDCLegacyImportAssistantStepAccess];

		return;
	} else if (error == TPCLegacyImportReadErrorEmpty) {
		self.nothingToImport = YES;

		[self _showStep:TDCLegacyImportAssistantStepAccess];

		return;
	}

	[self _showStep:TDCLegacyImportAssistantStepImporting];
}

#pragma mark Importing

- (NSStackView *)_progressRowWithKey:(NSString *)key text:(NSString *)text
{
	NSProgressIndicator *spinner = [NSProgressIndicator new];

	spinner.style = NSProgressIndicatorStyleSpinning;
	spinner.controlSize = NSControlSizeSmall;
	spinner.translatesAutoresizingMaskIntoConstraints = NO;

	[spinner.widthAnchor constraintEqualToConstant:21].active = YES;

	[spinner startAnimation:nil];

	NSTextField *label = [self _labelWithString:text font:[NSFont systemFontOfSize:13] color:[NSColor labelColor] width:240];

	NSTextField *detail = [self _labelWithString:@"" font:[NSFont systemFontOfSize:13] color:[NSColor secondaryLabelColor] width:220];

	NSStackView *row = [NSStackView stackViewWithViews:@[spinner, label, detail]];

	row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
	row.spacing = 8;

	self.progressRows[key] = row;

	return row;
}

- (void)_finishProgressRowWithKey:(NSString *)key detail:(nullable NSString *)detail done:(BOOL)done
{
	NSStackView *row = self.progressRows[key];

	NSView *spinner = row.arrangedSubviews.firstObject;

	NSImageView *image = [self _symbol:(done ? @"checkmark.circle.fill" : @"minus.circle") size:15 color:(done ? [NSColor systemGreenColor] : [NSColor tertiaryLabelColor])];

	[row insertArrangedSubview:image atIndex:0];

	[spinner removeFromSuperview];

	((NSTextField *)row.arrangedSubviews.lastObject).stringValue = (detail ?: @"");
}

- (void)_showImporting
{
	[self _setHeaderSymbol:@"arrow.down.circle" color:[NSColor controlAccentColor]
					 title:TXTLS(@"Prompts[mo5-4j]")
				  subtitle:TXTLS(@"Prompts[yhg-2i]", self.source.displayName)];

	NSStackView *body = [self _verticalStackWithViews:@[
		[self _progressRowWithKey:@"servers" text:TXTLS(@"Prompts[26f-4z]")],
		[self _progressRowWithKey:@"styles" text:TXTLS(@"Prompts[x3o-dm]")],
		[self _progressRowWithKey:@"extensions" text:TXTLS(@"Prompts[d2h-gn]")],
		[self _progressRowWithKey:@"scrollback" text:TXTLS(@"Prompts[abx-17]")],
		[self _progressRowWithKey:@"preferences" text:TXTLS(@"Prompts[f6m-6o]")]
	]];

	body.spacing = 12;

	[self _setBody:body];

	[self _setPrimary:nil secondary:nil checkbox:nil];

	TPCLegacyImport *import = self.import;
	NSURL *groupURL = self.groupURL;

	/* The copies run in the background; each row ticks off as its part
	 finishes, with a short pause so the steps can be followed */
	void (^step)(dispatch_block_t, dispatch_block_t) = ^(dispatch_block_t work, dispatch_block_t done) {
		work();

		[NSThread sleepForTimeInterval:0.35];

		dispatch_sync(dispatch_get_main_queue(), done);
	};

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		step(^{}, ^{
			[self _finishProgressRowWithKey:@"servers" detail:TXTLS(@"Prompts[u7y-7m]", import.serverCount) done:YES];
		});

		step(^{
			[import importStylesFromGroupURL:groupURL];
		}, ^{
			[self _finishProgressRowWithKey:@"styles" detail:[self _countDetail:import.result.styles.count] done:(import.result.styles.count > 0)];
		});

		step(^{
			[import importExtensionsFromGroupURL:groupURL];
		}, ^{
			[self _finishProgressRowWithKey:@"extensions" detail:[self _countDetail:import.result.extensions.count] done:(import.result.extensions.count > 0)];
		});

		step(^{
			[import importScrollbackFromGroupURL:groupURL];
			[import noteOtherContentOfGroupURL:groupURL];
		}, ^{
			[self _finishProgressRowWithKey:@"scrollback" detail:(import.result.importedScrollback ? nil : TXTLS(@"Prompts[ass-fu]")) done:import.result.importedScrollback];
		});

		/* Preferences last and on the main thread: they replace this copy's
		 settings, and the user interface may observe them */
		step(^{}, ^{
			[import importPreferences];

			[self _finishProgressRowWithKey:@"preferences" detail:nil done:YES];
		});

		[NSThread sleepForTimeInterval:0.4];

		dispatch_async(dispatch_get_main_queue(), ^{
			[groupURL stopAccessingSecurityScopedResource];

			[self _showStep:(self.source.licenseFolderURL ? TDCLegacyImportAssistantStepLicense : TDCLegacyImportAssistantStepDone)];
		});
	});
}

- (NSString *)_countDetail:(NSUInteger)count
{
	if (count == 0) {
		return TXTLS(@"Prompts[ass-fu]");
	}

	return TXTLS(@"Prompts[zos-f9]", count);
}

#pragma mark Licence

- (void)_showLicense
{
	NSString *name = self.source.displayName;

	[self _setHeaderSymbol:@"key.fill" color:[NSColor systemYellowColor]
					 title:TXTLS(@"Prompts[0xu-7t]")
				  subtitle:TXTLS(@"Prompts[wsg-m5]", name)];

	NSStackView *body = [self _verticalStackWithViews:@[
		[self _rowWithSymbol:@"1.circle.fill" color:[NSColor controlAccentColor] text:TXTLS(@"Prompts[200-fe]")],
		[self _rowWithSymbol:@"2.circle.fill" color:[NSColor controlAccentColor] text:TXTLS(@"Prompts[sgc-fg]")]
	]];

	[self _setBody:body];

	[self _setPrimary:TXTLS(@"Prompts[5je-mb]") secondary:TXTLS(@"Prompts[xyt-ns]") checkbox:nil];
}

- (void)_requestLicenseAccess
{
	NSURL *folderURL = self.source.licenseFolderURL;

	if (folderURL == nil) {
		[self _showStep:TDCLegacyImportAssistantStepDone];

		return;
	}

	NSURL *rememberedURL = [TPCLegacyImport rememberedURLForFolder:folderURL];

	if (rememberedURL) {
		[self _importLicenseFromFolderURL:rememberedURL];

		return;
	}

	NSOpenPanel *panel = [self _panelSelectingItemAtURL:folderURL isFolder:YES message:TXTLS(@"Prompts[4l1-08]")];

	[panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
		if (response != NSModalResponseOK || panel.URL == nil) {
			return;
		}

		[TPCLegacyImport rememberGrantedURL:panel.URL];

		[self _importLicenseFromFolderURL:panel.URL];
	}];
}

- (void)_importLicenseFromFolderURL:(NSURL *)folderURL
{
	[folderURL startAccessingSecurityScopedResource];

	[self.import importLicenseFromFolderURL:folderURL];

	[folderURL stopAccessingSecurityScopedResource];

	[self _showStep:TDCLegacyImportAssistantStepDone];
}

#pragma mark Done

- (void)_showDone
{
	TPCLegacyImportResult *result = self.import.result;

	NSString *name = self.source.displayName;

	[self _setHeaderSymbol:@"checkmark.seal.fill" color:[NSColor systemGreenColor]
					 title:TXTLS(@"Prompts[zy7-wx]")
				  subtitle:(self.fromMenu ? TXTLS(@"Prompts[1m5-76]", name) : TXTLS(@"Prompts[frk-e5]", name))];

	NSMutableArray<NSView *> *views = [NSMutableArray array];

	NSColor *green = [NSColor systemGreenColor];

	[views addObject:[self _rowWithSymbol:@"checkmark.circle.fill" color:green text:TXTLS(@"Prompts[r0h-rs]", result.serverCount)]];

	if (result.styles.count > 0) {
		[views addObject:[self _rowWithSymbol:@"checkmark.circle.fill" color:green text:TXTLS(@"Prompts[k7h-z8]", [result.styles componentsJoinedByString:@", "])]];
	}

	if (result.extensions.count > 0) {
		[views addObject:[self _rowWithSymbol:@"checkmark.circle.fill" color:green text:TXTLS(@"Prompts[iy3-3h]", [result.extensions componentsJoinedByString:@", "])]];
	}

	if (result.importedScrollback) {
		[views addObject:[self _rowWithSymbol:@"checkmark.circle.fill" color:green text:TXTLS(@"Prompts[r6r-r0]")]];
	}

	if (result.importedLicense) {
		[views addObject:[self _rowWithSymbol:@"checkmark.circle.fill" color:green text:TXTLS(@"Prompts[pxp-p6]")]];
	}

	NSView *lastImported = views.lastObject;

	/* Worth a look: what wasn't imported, with a button where Textual can help */
	NSMutableArray<NSView *> *notes = [NSMutableArray array];

	NSColor *orange = [NSColor systemOrangeColor];
	NSColor *grey = [NSColor secondaryLabelColor];

	if (result.triedLicense && result.importedLicense == NO) {
		[notes addObject:[self _rowWithSymbol:@"key" color:orange text:TXTLS(@"Prompts[3jr-s5]")]];
	}

	if (result.encryptionComponentsURL) {
		[notes addObject:[self _noteRowWithSymbol:@"lock.doc" text:TXTLS(@"Prompts[3po-7m]") button:TXTLS(@"Prompts[x5g-hy]") action:@selector(_saveKeysClicked:)]];
	}

	if (result.scriptsURL) {
		[notes addObject:[self _noteRowWithSymbol:@"applescript" text:TXTLS(@"Prompts[fk1-ci]", name) button:TXTLS(@"Prompts[gt5-wm]") action:@selector(_showScriptsClicked:)]];
	}

	if (result.hadTranscriptFolder) {
		[notes addObject:[self _rowWithSymbol:@"folder" color:grey text:TXTLS(@"Prompts[2zf-mn]")]];
	}

	if (result.hadDownloadFolder) {
		[notes addObject:[self _rowWithSymbol:@"arrow.down.to.line" color:grey text:TXTLS(@"Prompts[voq-wj]")]];
	}

	if (result.inlineMediaModules.count > 0) {
		[notes addObject:[self _rowWithSymbol:@"photo" color:grey text:TXTLS(@"Prompts[pjp-bp]", [result.inlineMediaModules componentsJoinedByString:@", "])]];
	}

	if (result.failureCount > 0) {
		[notes addObject:[self _rowWithSymbol:@"exclamationmark.triangle" color:orange text:TXTLS(@"Prompts[to7-nt]", result.failureCount)]];
	}

	if (notes.count > 0) {
		NSTextField *heading = [self _labelWithString:TXTLS(@"Prompts[bmq-fg]") font:[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold] color:[NSColor labelColor] width:_bodyWidth];

		[views addObject:heading];
		[views addObjectsFromArray:notes];
	}

	NSStackView *body = [self _verticalStackWithViews:views];

	if (notes.count > 0) {
		[body setCustomSpacing:20 afterView:lastImported];
	}

	[self _setBody:body];

	[self _setPrimary:(self.fromMenu ? TXTLS(@"Prompts[33s-fi]") : TXTLS(@"Prompts[weu-cf]"))
			secondary:nil
			 checkbox:TXTLS(@"Prompts[ixe-oc]", name)];
}

/* A note with a button on the right */
- (NSView *)_noteRowWithSymbol:(NSString *)symbol text:(NSString *)text button:(NSString *)buttonTitle action:(SEL)action
{
	NSTextField *label = [self _labelWithString:text font:[NSFont systemFontOfSize:13] color:[NSColor labelColor] width:_noteTextWidth];

	[label.widthAnchor constraintEqualToConstant:_noteTextWidth].active = YES;

	NSButton *button = [NSButton buttonWithTitle:buttonTitle target:self action:action];

	button.controlSize = NSControlSizeSmall;
	button.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];

	NSStackView *row = [NSStackView stackViewWithViews:@[[self _symbol:symbol size:15 color:[NSColor systemOrangeColor]], label, button]];

	row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
	row.alignment = NSLayoutAttributeCenterY;
	row.spacing = 8;

	return row;
}

- (void)_saveKeysClicked:(nullable id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];

	panel.canChooseDirectories = YES;
	panel.canChooseFiles = NO;
	panel.canCreateDirectories = YES;
	panel.message = TXTLS(@"Prompts[mqc-bj]");
	panel.prompt = TXTLS(@"Prompts[iud-uj]");

	[panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
		if (response != NSModalResponseOK || panel.URL == nil) {
			return;
		}

		if ([self.import saveEncryptionComponentsToFolderURL:panel.URL groupURL:self.groupURL] && [sender isKindOfClass:[NSButton class]]) {
			NSButton *button = sender;

			button.title = TXTLS(@"Prompts[uos-wu]");
			button.enabled = NO;
		}
	}];
}

/* Finder only opens another app's folder for Textual once the user granted
 access to it */
- (void)_showScriptsClicked:(nullable id)sender
{
	NSURL *scriptsURL = self.import.result.scriptsURL;

	void (^show)(NSURL *) = ^(NSURL *grantedURL) {
		[grantedURL startAccessingSecurityScopedResource];

		[RZWorkspace() openURL:grantedURL];

		[grantedURL stopAccessingSecurityScopedResource];

		NSURL *newScriptsURL = [RZFileManager() URLForDirectory:NSApplicationScriptsDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];

		if (newScriptsURL) {
			[RZWorkspace() openURL:newScriptsURL];
		}
	};

	NSURL *rememberedURL = [TPCLegacyImport rememberedURLForFolder:scriptsURL];

	if (rememberedURL) {
		show(rememberedURL);

		return;
	}

	NSOpenPanel *panel = [self _panelSelectingItemAtURL:scriptsURL isFolder:YES message:TXTLS(@"Prompts[q3o-j2]")];

	[panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
		if (response != NSModalResponseOK || panel.URL == nil) {
			return;
		}

		[TPCLegacyImport rememberGrantedURL:panel.URL];

		show(panel.URL);
	}];
}

#pragma mark -
#pragma mark Buttons

- (void)_checkboxClicked:(NSButton *)sender
{
	self.deleteEarlierData = (sender.state == NSControlStateValueOn);
}

- (void)_secondaryClicked:(nullable id)sender
{
	switch (self.step) {
		case TDCLegacyImportAssistantStepWelcome:
		{
			/* Start fresh: not offered again (the menu item still works) */
			if (self.fromMenu == NO) {
				[TPCLegacyImport markOffered];
			}

			[self _finish];

			break;
		}
		case TDCLegacyImportAssistantStepAccess:
		{
			self.accessProblem = nil;
			self.nothingToImport = NO;
			self.grantingPreferencesFile = NO;

			[self.groupURL stopAccessingSecurityScopedResource];

			self.groupURL = nil;

			[self _showStep:TDCLegacyImportAssistantStepWelcome];

			break;
		}
		case TDCLegacyImportAssistantStepLicense:
		{
			[self _showStep:TDCLegacyImportAssistantStepDone];

			break;
		}
		default:
		{
			break;
		}
	}
}

- (void)_primaryClicked:(nullable id)sender
{
	switch (self.step) {
		case TDCLegacyImportAssistantStepWelcome:
		{
			self.import = [[TPCLegacyImport alloc] initWithSource:self.source];
			self.accessProblem = nil;
			self.nothingToImport = NO;
			self.grantingPreferencesFile = NO;

			/* Granted before: no panel */
			NSURL *rememberedURL = [TPCLegacyImport rememberedURLForFolder:self.source.groupURL];

			if (rememberedURL) {
				[self _useGroupURL:rememberedURL];

				break;
			}

			[self _showStep:TDCLegacyImportAssistantStepAccess];

			break;
		}
		case TDCLegacyImportAssistantStepAccess:
		{
			if (self.nothingToImport) {
				[self _secondaryClicked:nil];

				break;
			}

			[self _requestAccess];

			break;
		}
		case TDCLegacyImportAssistantStepLicense:
		{
			[self _requestLicenseAccess];

			break;
		}
		case TDCLegacyImportAssistantStepDone:
		{
			if (self.deleteEarlierData) {
				[self _confirmDeletion];

				break;
			}

			[self _done];

			break;
		}
		default:
		{
			break;
		}
	}
}

- (void)_confirmDeletion
{
	NSString *name = self.source.displayName;

	NSAlert *alert = [NSAlert new];

	alert.alertStyle = NSAlertStyleWarning;
	alert.messageText = TXTLS(@"Prompts[e7h-w1]", name);
	alert.informativeText = TXTLS(@"Prompts[19s-28]", name);

	[alert addButtonWithTitle:TXTLS(@"Prompts[hqr-xy]")];
	[alert addButtonWithTitle:TXTLS(@"Prompts[fbm-cu]")];

	alert.buttons.firstObject.hasDestructiveAction = YES;

	[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
		if (response == NSAlertFirstButtonReturn) {
			[self.import deleteEarlierDataInGroupURL:self.groupURL];
		}

		[self _done];
	}];
}

- (void)_done
{
	if (self.fromMenu) {
		[TPCLegacyImport restart];

		return;
	}

	[self _finish];
}

@end

NS_ASSUME_NONNULL_END
