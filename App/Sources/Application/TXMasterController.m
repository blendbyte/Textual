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

#import "BuildConfig.h"

#import "NSObjectHelperPrivate.h"
#import "OELReachability.h"
#import "TDCAlert.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLOLocalization.h"
#import "TLOSpeechSynthesizerPrivate.h"
#import "THOPluginManagerPrivate.h"
#import "TDCLegacyImportAssistantPrivate.h"
#import "TDCLicenseManagerDialogPrivate.h"
#import "HLSHistoricLogManagerPrivate.h"
#import "TVCLogControllerInlineMediaServicePrivate.h"
#import "TVCLogControllerOperationQueuePrivate.h"
#import "TVCMainWindowPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCCommandIndexPrivate.h"
#import "IRCExtrasPrivate.h"
#import "IRCWorldPrivate.h"
#import "TPCApplicationInfoPrivate.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCResourceManagerPrivate.h"
#import "TPCThemeControllerPrivate.h"
#import "TXMenuControllerPrivate.h"
#import "TXWindowControllerPrivate.h"
#import "TXMasterControllerPrivate.h"
#import "IRCClient.h"

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
#import <Sparkle/Sparkle.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface TXMasterController ()
@property (nonatomic, strong, readwrite) IRCWorld *world;
@property (nonatomic, assign, readwrite) BOOL debugModeIsOn;
@property (nonatomic, assign, readwrite) BOOL ghostModeIsOn;
@property (nonatomic, assign, readwrite) BOOL applicationIsActive;
@property (nonatomic, assign, readwrite) BOOL applicationIsLaunched;
@property (nonatomic, assign, readwrite) BOOL applicationIsTerminating;
@property (nonatomic, assign, readwrite) BOOL applicationIsChangingActiveState;
@property (readonly) BOOL isSafeToPerformApplicationTermination;
@property (nonatomic, assign, readwrite) BOOL terminateHistoricLogSaveFinished;
@property (nonatomic, strong, readwrite) IBOutlet TVCMainWindow *mainWindow;
@property (nonatomic, weak, readwrite) IBOutlet TXMenuController *menuController;
@property (nonatomic, assign) NSUInteger applicationLaunchRemainder;

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
@property (nonatomic, strong, readwrite) SPUStandardUpdaterController *updateController;
#endif
@end

@implementation TXMasterController

#pragma mark -
#pragma mark Initialization

- (instancetype)init
{
	if ((self = [super init])) {
		[NSObject setGlobalMasterControllerClassReference:self];

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	LogToConsoleSetDefaultSubsystemToMainBundle(@"General");

	NSUInteger keyboardKeys = ([NSEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask);

	if ((keyboardKeys & NSEventModifierFlagControl) == NSEventModifierFlagControl) {
		self.debugModeIsOn = YES;

		LogToConsoleInfo("Launching in debug mode");
	}

#if defined(DEBUG)
	self.ghostModeIsOn = YES; // Do not use auto connect during debug
#else
	if ((keyboardKeys & NSEventModifierFlagShift) == NSEventModifierFlagShift) {
		self.ghostModeIsOn = YES;

		LogToConsoleInfo("Launching without auto connecting to the configured servers");
	}
#endif
}

- (void)awakeFromNib
{
	static BOOL _awakeFromNibCalled = NO;

	if (_awakeFromNibCalled == NO) {
		_awakeFromNibCalled = YES;

		[self _awakeFromNib];
	}
}

- (void)_awakeFromNib
{
	/* When the app hosts unit tests, only set up preferences and appearance.
	 Migration and the main window (which creates the IRC world, loads plugins
	 and connects) would act on the user's real data and servers. */
	BOOL hostingUnitTests = (NSProcessInfo.processInfo.environment[@"XCTestConfigurationFilePath"] != nil ||
							 NSProcessInfo.processInfo.environment[@"XCTestSessionIdentifier"] != nil);

	if (hostingUnitTests) {
		[self _loadPreferencesAndMainWindow:NO];

		return;
	}

	/* Offer to import Textual 7's settings before preferences load, so that
	 a first-launch import needs no restart. Development builds ("Textual
	 Dev") only offer it when asked to. */
	[TDCLegacyImportAssistant offerImportAtLaunchThen:^{
		[self _loadPreferencesAndMainWindow:YES];
	}];
}

- (void)_loadPreferencesAndMainWindow:(BOOL)loadMainWindow
{
	/* Initialize preferences */
	[TPCPreferences initPreferences];

	/* Call shared instance to warm it */
	[TXSharedApplication sharedAppearance];

	if (loadMainWindow == NO) {
		return;
	}

	/* We wait until -awakeFromNib to wake the window so that the menu
	 controller created by the main nib has time to load. */
	[RZMainBundle() loadNibNamed:@"TVCMainWindow" owner:self topLevelObjects:nil];
}

- (void)applicationWakeStepOne
{
	self.world = [IRCWorld new];
}

- (void)applicationWakeStepTwo
{
	[IRCCommandIndex populateCommandIndex];

	[self prepareNetworkReachabilityNotifier];

	[RZWorkspaceNotificationCenter() addObserver:self selector:@selector(computerDidWakeUp:) name:NSWorkspaceDidWakeNotification object:nil];
	[RZWorkspaceNotificationCenter() addObserver:self selector:@selector(computerWillSleep:) name:NSWorkspaceWillSleepNotification object:nil];
	[RZWorkspaceNotificationCenter() addObserver:self selector:@selector(computerWillPowerOff:) name:NSWorkspaceWillPowerOffNotification object:nil];
	[RZWorkspaceNotificationCenter() addObserver:self selector:@selector(computerScreenDidWake:) name:NSWorkspaceScreensDidWakeNotification object:nil];
	[RZWorkspaceNotificationCenter() addObserver:self selector:@selector(computerScreenWillSleep:) name:NSWorkspaceScreensDidSleepNotification object:nil];

	[RZNotificationCenter() addObserver:self selector:@selector(pluginsFinishedLoading:) name:THOPluginManagerFinishedLoadingPluginsNotification object:nil];

	[RZAppleEventManager() setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];

	[NSColorPanel setPickerMask:(NSColorPanelRGBModeMask | NSColorPanelGrayModeMask | NSColorPanelColorListModeMask | NSColorPanelWheelModeMask | NSColorPanelCrayonModeMask)];

	[[NSColorPanel sharedColorPanel] setShowsAlpha:YES];

	XRPerformBlockAsynchronouslyOnGlobalQueueWithPriority(^{
		[TPCResourceManager copyResourcesToApplicationSupportFolder];
	}, DISPATCH_QUEUE_PRIORITY_BACKGROUND);

	/* We want to guarantee some specific things happen before the
	 app is considered "launched" and ready to use. This property
	 counts down once each task completes and once it reaches 0,
	 then the app is considered launched. */
	/* 1 is default value because we want plugins to be loaded
	 before we are finished launching. */
	[self addObserver:self forKeyPath:@"applicationLaunchRemainder" options:NSKeyValueObservingOptionNew context:NULL];

	self.applicationLaunchRemainder = 1;

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
	[self prepareLicenseManager];
#endif

	[self prepareThirdPartyServices];

	/* Load plugins last so that -applicationDidFinishLaunching is posted
	 only once they have loaded and everything else has been setup. */
	[sharedPluginManager() loadPlugins];
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSString *, id> *)change context:(nullable void *)context
{
	if ([keyPath isEqualToString:@"applicationLaunchRemainder"]) {
		if (self.applicationLaunchRemainder == 0) {
			[self applicationDidFinishLaunching];
		}
	}
}

- (void)pluginsFinishedLoading:(NSNotification *)notification
{
	self.applicationLaunchRemainder -= 1;
}

#pragma mark -
#pragma mark Services

- (void)prepareThirdPartyServiceSparkleFramework
{
#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	  SPUStandardUpdaterController *controller =
	[[SPUStandardUpdaterController alloc] initWithStartingUpdater:NO
												  updaterDelegate:(id <SPUUpdaterDelegate>)self
											   userDriverDelegate:nil];

	self.updateController = controller;

	SPUUpdater *updater = controller.updater;

	if ([updater respondsToSelector:@selector(clearFeedURLFromUserDefaults)]) {
		[updater performSelector:@selector(clearFeedURLFromUserDefaults)];
	} else {
		[RZUserDefaults() removeObjectForKey:@"SUFeedURL"];
	}

	NSError *error;

	(void)[updater startUpdater:&error];

	if (error) {
		LogToConsoleError("Sparkle failed to start updater: %{public}@", error.description);
	}
#endif
}

- (void)prepareThirdPartyServices
{
	[self prepareThirdPartyServiceSparkleFramework];
}

- (void)prepareNetworkReachabilityNotifier
{
	OELReachability *notifier = [TXSharedApplication sharedNetworkReachabilityNotifier];

	notifier.reachableBlock = ^(OELReachability *reachability) {
		[self.world noteReachabilityChanged:YES];
	};

	notifier.unreachableBlock = ^(OELReachability *reachability) {
		[self.world noteReachabilityChanged:NO];
	};

	[notifier startNotifier];
}

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
- (void)prepareLicenseManager
{
	TLOLicenseManagerSetup();

	[[TXSharedApplication sharedLicenseManagerDialog] applicationDidFinishLaunching];
}
#endif

#pragma mark -
#pragma mark NSApplication Delegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	/* UserNotifications.framework wants delegation set before app has
	 finished launching. A simple access to the singleton will set this
	 for us which we can just do here. */
	LogToConsoleDebug("Preparing notification controller singeton: %@",
			sharedNotificationController().description);
}

- (void)applicationDidFinishLaunching
{
	[self removeObserver:self forKeyPath:@"applicationLaunchRemainder"];

	self.applicationIsLaunched = YES;

	if ([self.mainWindow reloadLoadingScreen]) {
		[self.world autoConnectAfterWakeup:NO];
	}

	[self.mainWindow maybeToggleFullscreenAfterLaunch];
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
	self.applicationIsChangingActiveState = YES;
}

- (void)applicationWillBecomeActive:(NSNotification *)notification
{
	self.applicationIsChangingActiveState = YES;
}

- (void)applicationDidResignActive:(NSNotification *)notification
{
	self.applicationIsActive = NO;
	self.applicationIsChangingActiveState = NO;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
	self.applicationIsActive = YES;
	self.applicationIsChangingActiveState = NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
	if (self.applicationIsTerminating) {
		return NO;
	}

	[self.mainWindow makeKeyAndOrderFront:nil];

	return YES;
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	if (self.applicationIsTerminating) {
		return NO;
	}

	[self.mainWindow makeKeyAndOrderFront:nil];

	return YES;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)sender
{
	/* This will have no effect on our app. Implement to suppress warning in console. */
	return YES;
}

#pragma mark -
#pragma mark NSApplication Terminate Procedure

- (NSMenu *)applicationDockMenu:(NSApplication *)sender
{
	return self.menuController.dockMenu;
}

- (BOOL)queryTerminate
{
	if (self.applicationIsTerminating) {
		LogToConsoleTerminationProgress("Termination is already in progress");

		return YES;
	}

	if ([TPCPreferences confirmQuit] == NO) {
		return YES;
	}

	BOOL stillConnected = NO;

	for (IRCClient *u in worldController().clientList) {
		if (u.isConnecting || u.isConnected) {
			stillConnected = YES;
		}
	}

	if (stillConnected) {
		BOOL result = [TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[77u-vp]")
												title:TXTLS(@"Prompts[6vj-2p]")
										defaultButton:TXTLS(@"Prompts[1bf-k0]")
									  alternateButton:TXTLS(@"Prompts[qso-2g]")];

		LogToConsoleTerminationProgress("Perform termination: %{BOOL}d", result);

		return result;
	}

	return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	if ([self queryTerminate] == NO) {
		return NSTerminateCancel;
	}

	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self performApplicationTerminationStepOne];
	});

	return NSTerminateLater;
}

- (BOOL)isSafeToPerformApplicationTermination
{
	/* Clients are still disconnecting */
	BOOL condition1 = (self.terminatingClientCount == 0);

	/* Core Data is saving */
	BOOL condition2 = (sharedHistoricLog().isSaving == NO &&
							self.terminateHistoricLogSaveFinished);

	LogToConsoleTerminationProgress("Conditions: %{BOOL}d %{BOOL}d", condition1, condition2);

	return (condition1 && condition2);
}

- (void)performApplicationTerminationStepOne
{
	LogToConsoleTerminationProgress("Step one entry");

	self.applicationIsTerminating = YES;

	[[TXSharedApplication sharedAppearance] prepareForApplicationTermination];

	[self.mainWindow prepareForApplicationTermination];

	LogToConsoleTerminationProgress("Giving up shared application delegation");

	[[NSApplication sharedApplication] setDelegate:nil];

	LogToConsoleTerminationProgress("Removing workspace notification center observer");

	[RZWorkspaceNotificationCenter() removeObserver:self];

	LogToConsoleTerminationProgress("Removing shared notification center observer");

	[RZNotificationCenter() removeObserver:self];

	LogToConsoleTerminationProgress("Removing AppleScript event observer");

	[RZAppleEventManager() removeEventHandlerForEventClass:kInternetEventClass andEventID:kAEGetURL];

	LogToConsoleTerminationProgress("Stopping reachability notifier");

	[[TXSharedApplication sharedNetworkReachabilityNotifier] stopNotifier];

	LogToConsoleTerminationProgress("Stopping speech synthesizer");

	[[TXSharedApplication sharedSpeechSynthesizer] setIsStopped:YES];

	[TVCLogControllerInlineMediaSharedInstance() prepareForApplicationTermination];

	[self.menuController prepareForApplicationTermination];

	[self performApplicationTerminationStepTwo];
}

- (void)performApplicationTerminationStepTwo
{
	if (self.applicationIsTerminating == NO) {
		return;
	}

	LogToConsoleTerminationProgress("Step two entry");

	self.terminatingClientCount = worldController().clientCount;

	[self.world prepareForApplicationTermination];

	if (self.isSafeToPerformApplicationTermination) {
		[self performApplicationTerminationStepThree];

		return;
	}

	/* Leaving IRC gracefully and saving the history have to finish first */
	[self performApplicationTerminationStepTwoWhenSafe];
}

/* Checked on the main thread every half second: a background loop read
 these values unsynchronized and started a new history save on every pass */
- (void)performApplicationTerminationStepTwoWhenSafe
{
	/* The view controllers have had their chance to change the history */
	if (self.terminatingClientCount == 0 && self.terminateHistoricLogSaveFinished == NO) {
		[sharedHistoricLog() prepareForApplicationTermination];

		self.terminateHistoricLogSaveFinished = YES;
	}

	if (self.isSafeToPerformApplicationTermination) {
		[self performApplicationTerminationStepThree];

		return;
	}

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self performApplicationTerminationStepTwoWhenSafe];
	});
}

- (void)performApplicationTerminationStepThree
{
	if (self.applicationIsTerminating == NO) {
		return;
	}

	LogToConsoleTerminationProgress("Step three entry");

	if (self.skipTerminateSave == NO) {
		LogToConsoleTerminationProgress("Saving IRC world");

		[self.world save];
	}

	LogToConsoleTerminationProgress("Unloading plugins");

	[sharedPluginManager() unloadPlugins];

	[windowController() prepareForApplicationTermination];

	[themeController() prepareForApplicationTermination];

	LogToConsoleTerminationProgress("Saving running internal");

	[TPCApplicationInfo saveTimeIntervalSinceApplicationInstall];

	LogToConsoleTerminationProgress("Terminate");

	[NSApp replyToApplicationShouldTerminate:YES];
}

- (void)terminateGracefully
{
	self.applicationIsTerminating = YES;

	[RZSharedApplication() terminate:nil];
}

#pragma mark -
#pragma mark NSWorkspace Notifications

- (void)handleURLEvent:(NSAppleEventDescriptor *)event
		withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	NSAppleEventDescriptor *description = [event descriptorAtIndex:1];

	NSString *stringValue = description.stringValue;

	[IRCExtras parseIRCProtocolURI:stringValue withDescriptor:event];
}

- (void)computerScreenWillSleep:(NSNotification *)note
{
	LogToConsole("Preparing for screen sleep");

	[self.world prepareForScreenSleep];
}

- (void)computerScreenDidWake:(NSNotification *)note
{
	LogToConsole("Waking from screen sleep");

	[self.world wakeFromScreenSleep];
}

- (void)computerWillSleep:(NSNotification *)note
{
	LogToConsole("Preparing for sleep");

	[self.world prepareForSleep];

	[[TXSharedApplication sharedSpeechSynthesizer] setIsStopped:YES];
	[[TXSharedApplication sharedSpeechSynthesizer] clearQueue];

	[[TXSharedApplication sharedNetworkReachabilityNotifier] stopNotifier];
}

- (void)computerDidWakeUp:(NSNotification *)note
{
	LogToConsole("Waking from sleep");

	[[TXSharedApplication sharedSpeechSynthesizer] setIsStopped:NO];

	[[TXSharedApplication sharedNetworkReachabilityNotifier] startNotifier];

	[self.world autoConnectAfterWakeup:YES];
}

- (void)computerWillPowerOff:(NSNotification *)note
{
	[self terminateGracefully];
}

#pragma mark -
#pragma mark Sparkle Delegate

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
- (void)updaterWillRelaunchApplication:(SPUUpdater *)updater
{
	self.applicationIsTerminating = YES;
}

- (NSSet<NSString *> *)allowedChannelsForUpdater:(SPUUpdater *)updater
{
	BOOL receiveBetaUpdates = [TPCPreferences receiveBetaUpdates];

	if (receiveBetaUpdates) {
		return [NSSet setWithObject:@"beta"];
	}

	return [NSSet set];
}
#endif

@end

NS_ASSUME_NONNULL_END
