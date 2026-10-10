
#import "TPI_PreferencePaneExample.h"

@implementation TPI_PreferencePaneExample

/* Nibs are user interface: loaded on the main thread, when the plugin loads */
- (void)pluginLoadedIntoMemory
{
	dispatch_block_t loadView = ^{
		if ([[NSBundle bundleForClass:self.class] loadNibNamed:@"PreferencePane" owner:self topLevelObjects:nil] == NO) {
			NSAssert(NO, @"TPI_PreferencePaneExample: Failed to load view");
		}
	};

	if ([NSThread isMainThread]) {
		loadView();
	} else {
		dispatch_sync(dispatch_get_main_queue(), loadView);
	}
}

- (NSView *)pluginPreferencesPaneView
{
	return self.ourView;
}

- (NSString *)pluginPreferencesPaneMenuItemName
{
	return @"My Test Plugin";
}

- (void)doSomethingWithPreferences
{
	BOOL isSomethingChecked = [[NSUserDefaults standardUserDefaults] boolForKey:@"TPI_PreferencesSomethingCheckboxIsChecked"];
	
	if (isSomethingChecked) {
		NSLog(@"Checkbox is checked");
	} else {
		NSLog(@"Checkbox is not checked");
	}
}

- (IBAction)preferenceChanged:(id)sender
{
	[self doSomethingWithPreferences];
}

@end
