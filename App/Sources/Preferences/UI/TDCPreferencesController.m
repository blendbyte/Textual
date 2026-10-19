/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
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

#import "NSViewHelper.h"
#import "THOPluginManagerPrivate.h"
#import "TDCPreferencesPanePrivate.h"
#import "TDCPreferencesControllerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* The tags of toolbar items and of the Advanced and Addons menus' items.
 Items in the Advanced menu select the Advanced toolbar item (as Installed
 Addons and plugins select Addons). */
typedef NS_ENUM(NSInteger, TDCPreferencesPaneTag) {
	TDCPreferencesPaneTagGeneral = 101,
	TDCPreferencesPaneTagBehavior = 102,
	TDCPreferencesPaneTagNotifications = 103,
	TDCPreferencesPaneTagHighlights = 104,
	TDCPreferencesPaneTagInterface = 105,
	TDCPreferencesPaneTagStyle = 106,
	TDCPreferencesPaneTagControls = 107,
	TDCPreferencesPaneTagAdvanced = 108,
	TDCPreferencesPaneTagAddons = 109,
	TDCPreferencesPaneTagHistory = 110,

	TDCPreferencesPaneTagChannelManagement = 108000,
	TDCPreferencesPaneTagCommandScope = 108001,
	TDCPreferencesPaneTagFloodControl = 108002,
	TDCPreferencesPaneTagIncomingData = 108003,
	TDCPreferencesPaneTagFileTransfers = 108005,
	TDCPreferencesPaneTagInlineMedia = 108006,
	TDCPreferencesPaneTagDefaultIdentity = 108008,
	TDCPreferencesPaneTagDefaultIRCopMessages = 108009,
	TDCPreferencesPaneTagHiddenPreferences = 108011, // Help → Advanced → Hidden Preferences (no toolbar item)

	TDCPreferencesPaneTagInstalledAddons = 109000,

	TDCPreferencesPaneTagFirstPlugin = 995 // plus the plugin's index
};

@interface TDCPreferencesController ()
@property (nonatomic, strong) IBOutlet NSToolbar *navigationToolbar;
@property (nonatomic, strong) IBOutlet NSMenu *installedAddonsMenu;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, TDCPreferencesPane *> *panes; // tag → section, once shown

- (IBAction)onPrefPaneSelected:(nullable id)sender;
@end

/* The colour wells' bindings: reads both formats colours are stored in
 (keyed archives, and NSArchiver data in older defaults, as
 -[NSUserDefaults colorForKey:] does) and writes a secure keyed archive */
@interface TDCPreferencesColorTransformer : NSValueTransformer
@end

@implementation TDCPreferencesColorTransformer

+ (Class)transformedValueClass
{
	return [NSColor class];
}

+ (BOOL)allowsReverseTransformation
{
	return YES;
}

- (nullable id)transformedValue:(nullable id)value
{
	if ([value isKindOfClass:[NSData class]] == NO) {
		return nil;
	}

	return [NSKeyedUnarchiver legacyCompatUnarchivedObjectOfClass:[NSColor class] fromData:value];
}

- (nullable id)reverseTransformedValue:(nullable id)value
{
	if ([value isKindOfClass:[NSColor class]] == NO) {
		return nil;
	}

	return [NSKeyedArchiver archivedDataWithRootObject:value requiringSecureCoding:YES error:NULL];
}

@end

@implementation TDCPreferencesController

+ (void)initialize
{
	if (self != [TDCPreferencesController class]) {
		return;
	}

	/* Before the nib, whose colour wells name it */
	[NSValueTransformer setValueTransformer:[TDCPreferencesColorTransformer new]
									forName:@"TDCPreferencesColorTransformer"];
}

- (instancetype)init
{
	if ((self = [super initWithWindowNibName:@"TDCPreferences" owner:self])) {
		(void)self.window; // Loads the nib

		return self;
	}

	return nil;
}


- (void)windowDidLoad
{
	[super windowDidLoad];

	self.panes = [NSMutableDictionary dictionary];

	[self setUpToolbarItemsAndMenus];

	[self restoreWindowFrame];
}

#pragma mark -
#pragma mark Utilities

- (void)show:(TDCPreferencesControllerSelection)selection
{
	switch (selection) {
		case TDCPreferencesControllerSelectionNotifications:
		{
			[self _showPane:[self paneForTag:TDCPreferencesPaneTagNotifications].view selectedItem:TDCPreferencesPaneTagNotifications];

			break;
		}
		case TDCPreferencesControllerSelectionStyle:
		{
			[self _showPane:[self paneForTag:TDCPreferencesPaneTagStyle].view selectedItem:TDCPreferencesPaneTagStyle];

			break;
		}
		case TDCPreferencesControllerSelectionHistory:
		{
			[self _showPane:[self paneForTag:TDCPreferencesPaneTagHistory].view selectedItem:TDCPreferencesPaneTagHistory];

			break;
		}
		case TDCPreferencesControllerSelectionHiddenPreferences:
		{
			[self _showPane:[self paneForTag:TDCPreferencesPaneTagHiddenPreferences].view selectedItem:TDCPreferencesPaneTagAdvanced];

			break;
		}
		default:
		{
			[self _showPane:[self paneForTag:TDCPreferencesPaneTagGeneral].view selectedItem:TDCPreferencesPaneTagGeneral];

			break;
		}
	}
}


- (void)showPaneWithTag:(NSInteger)tag
{
	TDCPreferencesPane *pane = [self paneForTag:tag];

	if (pane == nil) {
		return;
	}

	[self _showPane:pane.view selectedItem:[self toolbarItemForTag:tag]];
}

- (void)_showPane:(NSView *)view selectedItem:(NSInteger)selectedItem
{
	[self firstPane:view selectedItem:selectedItem];

	[self.window makeKeyAndOrderFront:nil];
}


#pragma mark -
#pragma mark NSToolbar Delegates

 - (void)setUpToolbarItemsAndMenus
{
	/* History: the system's clock, which suits the others */
	for (NSToolbarItem *item in self.navigationToolbar.items) {
		if (item.tag != TDCPreferencesPaneTagHistory) {
			continue;
		}

		NSImage *icon = [[NSImage alloc] initWithContentsOfFile:@"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/Clock.icns"];

		if (icon == nil) {
			icon = [NSImage imageWithSystemSymbolName:@"clock" accessibilityDescription:nil];
		}

		item.image = icon;
	}

	NSArray *plugins = sharedPluginManager().pluginsWithPreferencePanes;

	if (plugins.count > 0) {
		[self.installedAddonsMenu addItem:[NSMenuItem separatorItem]];
	}

	[plugins enumerateObjectsUsingBlock:^(THOPluginItem *plugin, NSUInteger index, BOOL *stop) {
		NSUInteger tagIndex = (index + TDCPreferencesPaneTagFirstPlugin);

		NSMenuItem *pluginMenu = [NSMenuItem menuItemWithTitle:plugin.pluginPreferencesPaneMenuItemTitle
														target:self
														action:@selector(onPrefPaneSelected:)];

		pluginMenu.tag = tagIndex;

		[self.installedAddonsMenu addItem:pluginMenu];
	}];
}

 - (void)onPrefPaneSelected:(nullable id)sender
{
	NSInteger tag = [sender tag];

	TDCPreferencesPane *pane = [self paneForTag:tag];

	if (pane) {
		[self firstPane:pane.view selectedItem:[self toolbarItemForTag:tag]];

		return;
	}

	switch (tag) {
		default:
		{
			if (tag < TDCPreferencesPaneTagFirstPlugin) {
				break;
			}

			NSUInteger pluginIndex = (tag - TDCPreferencesPaneTagFirstPlugin);

			THOPluginItem *plugin = sharedPluginManager().pluginsWithPreferencePanes[pluginIndex];

			/* Shared by every Preferences window (the plugin made it once) */
			NSView *preferencesView = plugin.pluginPreferencesPaneView;

			[self firstPane:preferencesView selectedItem:TDCPreferencesPaneTagAddons];

			break;
		}
	}

}

/* The section shown for a tag, made the first time; nil for a plugin's */
- (nullable TDCPreferencesPane *)paneForTag:(TDCPreferencesPaneTag)tag
{
	TDCPreferencesPane *pane = self.panes[@(tag)];

	if (pane) {
		return pane;
	}

#define _nib(_name_)	[[TDCPreferencesPane alloc] initWithNibName:@"TDCPreferences" _name_]

	switch (tag) {
		case TDCPreferencesPaneTagGeneral: { pane = [TDCPreferencesGeneralPane new]; break; }
		case TDCPreferencesPaneTagBehavior: { pane = _nib(@"Behavior"); break; }
		case TDCPreferencesPaneTagControls: { pane = [TDCPreferencesControlsPane new]; break; }
		case TDCPreferencesPaneTagChannelManagement: { pane = _nib(@"ChannelManagement"); break; }
		case TDCPreferencesPaneTagCommandScope: { pane = [TDCPreferencesCommandScopePane new]; break; }
		case TDCPreferencesPaneTagHighlights: { pane = [TDCPreferencesHighlightsPane new]; break; }
		case TDCPreferencesPaneTagNotifications: { pane = [TDCPreferencesNotificationsPane new]; break; }
		case TDCPreferencesPaneTagInterface: { pane = [TDCPreferencesInterfacePane new]; break; }
		case TDCPreferencesPaneTagStyle: { pane = [TDCPreferencesStylePane new]; break; }
		case TDCPreferencesPaneTagFileTransfers: { pane = [TDCPreferencesFileTransfersPane new]; break; }
		case TDCPreferencesPaneTagInlineMedia: { pane = [TDCPreferencesInlineMediaPane new]; break; }
		case TDCPreferencesPaneTagHistory: { pane = [TDCPreferencesHistoryPane new]; break; }
		case TDCPreferencesPaneTagInstalledAddons: { pane = [TDCPreferencesInstalledAddonsPane new]; break; }
		case TDCPreferencesPaneTagHiddenPreferences: { pane = [TDCPreferencesHiddenPane new]; break; }
		case TDCPreferencesPaneTagFloodControl: { pane = _nib(@"FloodControl"); break; }
		case TDCPreferencesPaneTagIncomingData: { pane = _nib(@"IncomingData"); break; }
		case TDCPreferencesPaneTagDefaultIdentity: { pane = _nib(@"DefaultIdentity"); break; }
		case TDCPreferencesPaneTagDefaultIRCopMessages: { pane = _nib(@"DefaultIRCopMessages"); break; }
		default: { return nil; }
	}

#undef _nib

	self.panes[@(tag)] = pane;

	return pane;
}

- (TDCPreferencesPaneTag)toolbarItemForTag:(NSInteger)tag
{
	if (tag == TDCPreferencesPaneTagInstalledAddons) {
		return TDCPreferencesPaneTagAddons;
	} else if (tag >= TDCPreferencesPaneTagChannelManagement && tag < TDCPreferencesPaneTagInstalledAddons) {
		return TDCPreferencesPaneTagAdvanced;
	}

	return tag;
}

- (void)firstPane:(NSView *)view selectedItem:(NSInteger)selectedItem
{
	[self.window replaceContentView:view];

	if (selectedItem >= 0) {
		self.navigationToolbar.selectedItemIdentifier = [NSString stringWithInteger:selectedItem];
	} else {
		self.navigationToolbar.selectedItemIdentifier = nil;
	}
}


- (void)restoreWindowFrame
{
	NSWindow *window = self.window;

	[window saveSizeAsDefault];

	[window restoreWindowStateForClass:self.class];
}


- (void)saveWindowFrame
{
	NSWindow *window = self.window;

	[window restoreDefaultSizeAndDisplay:NO];

	[window saveWindowStateForClass:self.class];
}


- (void)deactivateColorWellsInAllPanes
{
	for (TDCPreferencesPane *pane in self.panes.allValues) {
		[pane deactivateColorWells];
	}
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	/* The window is released when it closes: the colour panel would
	 still send its changes to an active well in it */
	for (TDCPreferencesPane *pane in self.panes.allValues) {
		[pane deactivateColorWells];

		[pane paneWillClose];
	}

	[self saveWindowFrame];

	id delegate = self.delegate;

	if ([delegate respondsToSelector:@selector(preferencesDialogWillClose:)]) {
		[delegate preferencesDialogWillClose:self];
	}
}

@end

NS_ASSUME_NONNULL_END
