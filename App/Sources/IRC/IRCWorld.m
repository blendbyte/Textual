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
 *	* Redistributions of source code must retain the above copyright
 *	  notice, this list of conditions and the following disclaimer.
 *	* Redistributions in binary form must reproduce the above copyright
 *	  notice, this list of conditions and the following disclaimer in the
 *	  documentation and/or other materials provided with the distribution.
 *  * Neither the name of Textual and/or Codeux Software, nor the names of
 *    its contributors may be used to endorse or promote products derived
 * 	  from this software without specific prior written permission.
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
#import "TXMasterController.h"
#import "TXMenuControllerPrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCMainWindowPrivate.h"
#import "TVCServerListPrivate.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCThemeController.h"
#import "TPCTheme.h"
#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCServer.h"
#import "IRCTreeItemPrivate.h"
#import "IRCWorldPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _autoConnectDelay				1

#define _reconnectAfterWakeupDelay		8

#define _savePeriodicallyThreshold		300

NSString * const IRCWorldClientListDefaultsKey = @"World Controller Client Configurations";

NSString * const IRCWorldClientListWasModifiedNotification = @"IRCWorldClientListWasModifiedNotification";

NSString * const IRCWorldDateHasChangedNotification = @"IRCWorldDateHasChangedNotification";

NSString * const IRCWorldWillDestroyClientNotification = @"IRCWorldWillDestroyClientNotification";
NSString * const IRCWorldWillDestroyChannelNotification = @"IRCWorldWillDestroyChannelNotification";

@interface IRCWorld ()
@property (nonatomic, strong) NSMutableArray<IRCClient *> *clients;
@property (nonatomic, assign) BOOL preferencesDidChangeTimerIsActive;
@property (nonatomic, assign) CFAbsoluteTime savePeriodicallyLastSave;
@property (nonatomic, copy) NSDate *lastDateHasChangedDate;
@end

@implementation IRCWorld

#pragma mark -
#pragma mark Initialization

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
	self.clients = [NSMutableArray new];

	self.preferencesDidChangeTimerIsActive = NO;

	self.savePeriodicallyLastSave = CFAbsoluteTimeGetCurrent();
}

- (void)dealloc
{
	[self cancelPerformRequests];
}

#pragma mark -
#pragma mark Configuration

- (void)setupConfiguration
{
	self.isImportingConfiguration = YES;

	[mainWindowServerList() beginUpdates];

	NSArray *clientList = [TPCPreferences clientList];

	for (NSDictionary *client in clientList) {
		IRCClientConfig *e = [[IRCClientConfig alloc] initWithDictionary:client];

		[self createClientWithConfig:e reload:YES];
	}

	[mainWindowServerList() endUpdates];

	self.isImportingConfiguration = NO;

	[self setupOtherServices];
}

- (void)setupOtherServices
{
	[self setupMidnightTimer];

	[RZNotificationCenter() addObserver:self selector:@selector(dateChanged:) name:NSSystemClockDidChangeNotification object:nil];

	[RZNotificationCenter() addObserver:self selector:@selector(userDefaultsDidChange:) name:TPCPreferencesUserDefaultsDidChangeNotification object:nil];

	[RZNotificationCenter() addObserver:self selector:@selector(mainWindowAppearanceChanged:) name:TVCMainWindowAppearanceChangedNotification object:nil];
}

- (NSArray *)clientConfigurations
{
	NSMutableArray *configurations = [NSMutableArray array];

	for (IRCClient *u in self.clientList) {
		[configurations addObject:[u configurationDictionary]];
	}

	return [configurations copy];
}

- (void)save
{
	NSArray *clientList = [self clientConfigurations];

	[TPCPreferences setClientList:clientList];
}

- (void)savePeriodically
{
	CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();

	if ((self.savePeriodicallyLastSave + _savePeriodicallyThreshold) < now) {
		 self.savePeriodicallyLastSave = now;

		[self save];
	}
}

- (void)prepareForApplicationTermination
{
	LogToConsoleTerminationProgress("Preparing IRC world");

	LogToConsoleTerminationProgress("Removing IRC world observers");

	[RZNotificationCenter() removeObserver:self];

	LogToConsoleTerminationProgress("Preparing clients: %{public}ld", self.clientCount);

	for (IRCClient *u in self.clientList) {
		[u prepareForApplicationTermination];
	}
}

- (void)userDefaultsDidChange:(NSNotification *)notification
{
	if (themeSettings().js_postPreferencesDidChangesNotifications == NO) {
		return; // Cancel operation...
	}

	if (self.preferencesDidChangeTimerIsActive == NO) {
		self.preferencesDidChangeTimerIsActive = YES;

		[self performSelectorInCommonModes:@selector(informAllViewsUserDefaultsDidChange) withObject:nil afterDelay:1.0];
	}
}

- (void)informAllViewsUserDefaultsDidChange
{
	self.preferencesDidChangeTimerIsActive = NO;

	[self evaluateFunctionOnAllViews:@"Textual.preferencesDidChange" arguments:nil onQueue:YES];
}

- (void)mainWindowAppearanceChanged:(NSNotification *)notification
{
	if (themeSettings().js_postAppearanceChangesNotification == NO) {
		return;
	}

	[self informAllViewsMainWindowAppearanceChanged];
}

- (void)informAllViewsMainWindowAppearanceChanged
{
	TVCMainWindowAppearance *appearance = mainWindow().userInterfaceObjects;

	[self evaluateFunctionOnAllViews:@"Textual.appearanceDidChange" arguments:@[appearance.shortAppearanceDescription] onQueue:YES];
}

#pragma mark -
#pragma mark Properties

- (NSArray<IRCClient *> *)clientList
{
	@synchronized(self.clients) {
		return [self.clients copy];
	}
}

- (void)setClientList:(NSArray<IRCClient *> *)clientList
{
	@synchronized(self.clients) {
		[self.clients removeAllObjects];

		[self.clients addObjectsFromArray:clientList];

		[self postClientListWasModifiedNotification];
	}
}

- (NSUInteger)clientCount
{
	@synchronized(self.clients) {
		return self.clients.count;
	}
}

#pragma mark -
#pragma mark Utilities

- (void)postClientListWasModifiedNotification
{
	[RZNotificationCenter() postNotificationName:IRCWorldClientListWasModifiedNotification object:self];
}

- (void)autoConnectAfterWakeup:(BOOL)afterWakeUp
{
	if (masterController().ghostModeIsOn && afterWakeUp == NO) {
		return;
	}

	NSUInteger delay = 0;

	if (afterWakeUp) {
		delay += _reconnectAfterWakeupDelay;
	}

#define _isAutoConnecting		(afterWakeUp == NO && u.config.autoConnect)
#define _isWakingFromSleep		(afterWakeUp	   && u.config.autoSleepModeDisconnect && u.disconnectType == IRCClientDisconnectModeComputerSleep)

	for (IRCClient *u in self.clientList) {
		if (_isWakingFromSleep == NO && _isAutoConnecting == NO) {
			continue;
		}

		[u autoConnectWithDelay:delay afterWakeUp:afterWakeUp];

		delay += _autoConnectDelay;
	}

#undef _isWakingFromSleep
#undef _isAutoConnecting
}

- (void)prepareForSleep
{
	if ([TPCPreferences disconnectOnSleep] == NO) {
		return;
	}

	for (IRCClient *u in self.clientList) {
		if (u.isConnected == NO) {
			continue;
		}

		u.disconnectType = IRCClientDisconnectModeComputerSleep;

		[u quit];
	}
}

- (void)prepareForScreenSleep
{
	if ([TPCPreferences setAwayOnScreenSleep] == NO) {
		return;
	}

	for (IRCClient *u in self.clientList) {
		[u toggleAwayStatus:YES];
	}
}

- (void)wakeFromScreenSleep
{
	if ([TPCPreferences setAwayOnScreenSleep] == NO) {
		return;
	}

	for (IRCClient *u in self.clientList) {
		[u toggleAwayStatus:NO];
	}
}

- (void)noteReachabilityChanged:(BOOL)reachable
{
	for (IRCClient *u in self.clientList) {
		[u noteReachabilityChanged:reachable];
	}
}

- (void)preferencesChanged
{
	[menuController() preferencesChanged];

	for (IRCClient *u in self.clientList) {
		[u preferencesChanged];
	}
}

- (void)setupMidnightTimer
{
	[self setupMidnightTimerWithNotification:NO];
}

- (void)setupMidnightTimerWithNotification:(BOOL)fireNotification
{
	/* Ask for the day, month, and year from the current calendar. */
	/* We are not asking for time which means that it will default to zero. */
	NSDateComponents *currentDayComponents = [RZCurrentCalendar() components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:[NSDate date]];

	NSDate *lastMidnight = [RZCurrentCalendar() dateFromComponents:currentDayComponents];

	/* Create date components one day in the future. */
	/* All other values default to zero. */
	NSDateComponents *futureDayComponents = [NSDateComponents new];

	futureDayComponents.day = 1;

	/* With the current date and future components, calculate
	 the date on which our midnight timer will land. */
	NSDate *nextMidnight = [RZCurrentCalendar() dateByAddingComponents:futureDayComponents toDate:lastMidnight options:0];

	/* Create timer for midnight in future. */
	/* We set the tolerance for the timer to absolute zero so that
	 we are confident that OS X will not reschedule it. */
	NSTimer *midnightTimer = [[NSTimer alloc]
				initWithFireDate:nextMidnight
						interval:0.0
						  target:self
						selector:@selector(dateChanged:)
						userInfo:nil
						 repeats:NO];

	midnightTimer.tolerance = 0.0;

	/* Schedule the timer on the run loop which will retain reference. */
	[RZMainRunLoop() addTimer:midnightTimer forMode:NSDefaultRunLoopMode];

	/* Do not fire notification if day hasn't changed. 
	 This check is down here, instead of at top, because we still want to
	 reschedule timer when the system date changes. */
	if (self.lastDateHasChangedDate != nil) {
		if ([self.lastDateHasChangedDate isInSameDayAsDate:lastMidnight]) {
			LogToConsoleFault("Date changed event received but the day hasn't changed");

			return;
		}
	}

	self.lastDateHasChangedDate = lastMidnight;

	/* Post notification if needed. */
	if (fireNotification) {
		[RZNotificationCenter() postNotificationName:IRCWorldDateHasChangedNotification object:nil userInfo:nil];

		[self evaluateFunctionOnAllViews:@"Textual.dateChanged"
							   arguments:@[@(currentDayComponents.year),
										   @(currentDayComponents.month),
										   @(currentDayComponents.day)]
								 onQueue:NO];
	}
}

- (void)dateChanged:(id)sender
{
	/* We call the notifications in the timer so we do not have to
	 ask for the current day components two times. */

	[self setupMidnightTimerWithNotification:YES];
}

#pragma mark -
#pragma mark Tree Items

- (NSArray<__kindof IRCTreeItem *> *)findItemsWithIds:(NSArray<NSString *> *)itemIds
{
	NSParameterAssert(itemIds != nil);

	NSMutableArray<__kindof IRCTreeItem *> *items = [NSMutableArray array];

	for (IRCClient *u in self.clientList) {
		if ([itemIds containsObject:u.uniqueIdentifier]) {
			[items addObject:u];
		}

		for (IRCChannel *c in u.channelList) {
			if ([itemIds containsObject:c.uniqueIdentifier]) {
				[items addObject:c];
			}
		}
	}

	return [items copy];
}

- (nullable IRCTreeItem *)findItemWithId:(NSString *)itemId
{
	if (itemId == nil) {
		return nil;
	}

	for (IRCClient *u in self.clientList) {
		if ([itemId isEqualToString:u.uniqueIdentifier]) {
			return u;
		}

		for (IRCChannel *c in u.channelList) {
			if ([itemId isEqualToString:c.uniqueIdentifier]) {
				return c;
			}
		}
	}

	return nil;
}

- (nullable IRCClient *)findClientWithId:(NSString *)clientId
{
	return (IRCClient *)[self findItemWithId:clientId];
}

- (nullable IRCChannel *)findChannelWithId:(NSString *)channelId onClientWithId:(NSString *)clientId
{
	return (IRCChannel *)[self findItemWithId:channelId];
}

- (nullable IRCTreeItem *)findItemWithPasteboardString:(NSString *)string
{
	return [self findItemWithId:string];
}

- (NSString *)pasteboardStringForItem:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	return item.uniqueIdentifier;
}

- (nullable IRCClient *)findClientWithServerAddress:(NSString *)serverAddress
{
	for (IRCClient *u in self.clientList) {
		for (IRCServer *s in u.config.serverList) {
			if ([s.serverAddress isEqualToStringIgnoringCase:serverAddress]) {
				return u;
			}
		}
	}

	return nil;
}

#pragma mark -
#pragma mark JavaScript

- (void)evaluateFunctionOnAllViews:(NSString *)function arguments:(nullable NSArray *)arguments
{
	[self evaluateFunctionOnAllViews:function arguments:arguments onQueue:YES];
}

- (void)evaluateFunctionOnAllViews:(NSString *)function arguments:(nullable NSArray *)arguments onQueue:(BOOL)onQueue
{
	NSParameterAssert(function != nil);

	if (masterController().applicationIsTerminating) {
		return;
	}

	for (IRCClient *u in self.clientList) {
		[u.viewController evaluateFunction:function withArguments:arguments onQueue:onQueue];

		for (IRCChannel *c in u.channelList) {
			[c.viewController evaluateFunction:function withArguments:arguments onQueue:onQueue];
		}
	}
}

#pragma mark -
#pragma mark Factory

- (IRCClient *)createClientWithConfig:(IRCClientConfig *)config
{
	return [self createClientWithConfig:config reload:YES];
}

- (IRCClient *)createClientWithConfig:(IRCClientConfig *)config reload:(BOOL)reload
{
	NSParameterAssert(config != nil);

	IRCClient *client = [[IRCClient alloc] initWithConfig:config];

	client.viewController = [self createViewControllerWithClient:client channel:nil];

	NSMutableArray<IRCChannel *> *channelList = [NSMutableArray array];

	for (IRCChannelConfig *channelConfig in client.config.channelList) {
		IRCChannel *channel =
		[self createChannelWithConfig:channelConfig onClient:client add:NO adjust:NO reload:NO];

		[channelList addObject:channel];
	}

	client.channelList = channelList;

	@synchronized(self.clients) {
		[self.clients addObject:client];

		if (reload) {
			NSInteger index = [self.clients indexOfObject:client];

			[mainWindowServerList() addItemToList:index inParent:nil];
		}

		if (self.clients.count == 1) {
			[mainWindow() select:client];
		}
	}

	[mainWindow() reloadLoadingScreen];

	[menuController() populateNavigationChannelList];

	[self postClientListWasModifiedNotification];

	return client;
}

- (IRCChannel *)createChannelWithConfig:(IRCChannelConfig *)config onClient:(IRCClient *)client
{
	return [self createChannelWithConfig:config onClient:client add:YES adjust:YES reload:YES];
}

- (IRCChannel *)createChannelWithConfig:(IRCChannelConfig *)config onClient:(IRCClient *)client add:(BOOL)add adjust:(BOOL)adjust reload:(BOOL)reload
{
	NSParameterAssert(config != nil);
	NSParameterAssert(client != nil);

	IRCChannel *channel = [[IRCChannel alloc] initWithConfig:config];

	channel.associatedClient = client;

	channel.viewController = [self createViewControllerWithClient:client channel:channel];

	if (add) {
		[client addChannel:channel];
	}

	if (reload) {
		NSInteger index = [client.channelList indexOfObject:channel];

		[mainWindowServerList() addItemToList:index inParent:client];
	}

	if (adjust) {
		[mainWindow() adjustSelection];

		[menuController() populateNavigationChannelList];
	}

	return channel;
}

- (IRCChannel *)createPrivateMessage:(NSString *)nickname onClient:(IRCClient *)client
{
	return [self createPrivateMessage:nickname onClient:client asType:IRCChannelTypePrivateMessage];
}

- (IRCChannel *)createPrivateMessage:(NSString *)nickname onClient:(IRCClient *)client asType:(IRCChannelType)type
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(client != nil);
	NSParameterAssert(type == IRCChannelTypePrivateMessage ||
					  type == IRCChannelTypeUtility);

	IRCChannelConfigMutable *config = [IRCChannelConfigMutable new];

	config.channelName = nickname;

	config.type = type;

	IRCChannel *channel = [self createChannelWithConfig:config onClient:client add:YES adjust:YES reload:YES];

	if (client.isLoggedIn && channel.isPrivateMessage) {
		[channel activate];
	}

	return channel;
}

- (TVCLogController *)createViewControllerWithClient:(IRCClient *)client channel:(nullable IRCChannel *)channel
{
	NSParameterAssert(client != nil);

	TVCLogController *viewController = nil;

	if (channel == nil) {
		viewController = [[TVCLogController alloc] initWithClient:client inWindow:mainWindow()];
	} else {
		viewController = [[TVCLogController alloc] initWithChannel:channel inWindow:mainWindow()];
	}

	return viewController;
}

- (void)selectOtherBeforeDestroy:(IRCTreeItem *)target
{
	NSParameterAssert(target != nil);

	if (target.isClient) {
		[mainWindow() deselectGroup:target];
	} else {
		[mainWindow() deselect:target];
	}
}

- (void)destroyClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	/* It is not safe to destroy the client while connected. */
	if (client.isConnecting || client.isConnected) {
		__weak IRCWorld *weakSelf = self;

		__weak IRCClient *weakClient = client;

		client.disconnectCallback = ^{
			[weakSelf destroyClient:weakClient];
		};

		[client quit];

		return;
	}

	[RZNotificationCenter() postNotificationName:IRCWorldWillDestroyClientNotification object:client];

	[self selectOtherBeforeDestroy:client];

	[client prepareForPermanentDestruction];

	@try {
		[mainWindowServerList() removeItemFromList:client];
	}
	@catch (NSException *exception) {
		LogToConsoleError("Caught exception: %{public}@", exception.reason);
		LogStackTrace();
	}

	@synchronized(self.clients) {
		[self.clients removeObjectIdenticalTo:client];
	}

	[self postClientListWasModifiedNotification];

	[mainWindow() reloadLoadingScreen];

	[menuController() populateNavigationChannelList];
}

- (void)destroyChannel:(IRCChannel *)channel
{
	[self destroyChannel:channel reload:YES part:YES];
}

- (void)destroyChannel:(IRCChannel *)channel reload:(BOOL)reload
{
	[self destroyChannel:channel reload:reload part:YES];
}

- (void)destroyChannel:(IRCChannel *)channel reload:(BOOL)reload part:(BOOL)partChannel
{
	NSParameterAssert(channel != nil);

	[RZNotificationCenter() postNotificationName:IRCWorldWillDestroyChannelNotification object:channel];

	IRCClient *client = channel.associatedClient;

	if (partChannel) {
		[client partChannel:channel];
	}

	if (reload) {
		[self selectOtherBeforeDestroy:channel];
	}

	[channel prepareForPermanentDestruction];

	if (client.lastSelectedChannel == channel) {
		client.lastSelectedChannel = nil;
	}

	if (reload) {
		@try {
			[mainWindowServerList() removeItemFromList:channel];
		}
		@catch (NSException *exception) {
			LogToConsoleError("Caught exception: %{public}@", exception.reason);
			LogStackTrace();
		}

		[client removeChannel:channel];

		[mainWindow() adjustSelection];

		[menuController() populateNavigationChannelList];
	}
}

@end

NS_ASSUME_NONNULL_END
