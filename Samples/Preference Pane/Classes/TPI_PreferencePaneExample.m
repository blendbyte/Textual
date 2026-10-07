
#import "TPI_PreferencePaneExample.h"

@implementation TPI_PreferencePaneExample

- (NSView *)pluginPreferencesPaneView
{
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		if ([[NSBundle bundleForClass:self.class] loadNibNamed:@"PreferencePane" owner:self topLevelObjects:nil] == NO) {
			NSAssert(NO, @"TPI_PreferencePaneExample: Failed to load view");
		}
	});

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
