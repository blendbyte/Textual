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

#import "NSStringHelper.h"
#import "TXMasterController.h"
#import "TXMenuController.h"
#import "TVCMainWindow.h"
#import "TPCApplicationInfo.h"
#import "TPCPreferencesLocal.h"
#import "TLOLocalization.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCFileTransferDialogTransferControllerPrivate.h"
#import "IRCClientPrivate.h"
#import "IRCChannel.h"
#import "IRCWorld.h"
#import "TLONotificationControllerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const TXNotificationUserInfoClientIdentifierKey		= @"clientId";
NSString * const TXNotificationUserInfoChannelIdentifierKey		= @"channelId";

NSString * const TXNotificationDialogStandardNicknameFormat		= @"%@ %@";
NSString * const TXNotificationDialogActionNicknameFormat		= @"\u2022 %@: %@";

NSString * const TXNotificationHighlightLogStandardActionFormat			= @"\u2022 %@: %@";
NSString * const TXNotificationHighlightLogStandardMessageFormat		= @"%@ %@";

NSString * const TXNotificationCategoryIdentifierFileTransfer = @"TXNotificationCategoryIdentifierFileTransfer";
NSString * const TXNotificationActionIdentifierFileTransferAccept = @"TXNotificationActionIdentifierFileTransferAccept";

NSString * const TXNotificationCategoryIdentifierPrivateMessage = @"TXNotificationCategoryIdentifierPrivateMessage";
NSString * const TXNotificationActionIdentifierPrivateMessageReply = @"TXNotificationActionIdentifierPrivateMessageReply";

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
NSString * const TXNotificationCategoryIdentifierLicenseManager = @"TXNotificationCategoryIdentifierLicenseManager";
NSString * const TXNotificationActionIdentifierLicenseManagerMoreInfo = @"TXNotificationActionIdentifierLicenseManagerMoreInfo";
#endif

@interface TLONotificationController () <UNUserNotificationCenterDelegate>
@end

@implementation TLONotificationController

- (instancetype)init
{
	if ((self = [super init])) {
		[self prepareInitialState];

		return self;
	}

	return self;
}

- (void)prepareInitialState
{
	RZUserNotificationCenter().delegate = (id)self;

	[RZNotificationCenter() addObserver:self selector:@selector(mainWindowSelectionChanged:) name:TVCMainWindowSelectionChangedNotification object:nil];

	[RZUserNotificationCenter() requestAuthorizationWithOptions:(UNAuthorizationOptionAlert |
																 UNAuthorizationOptionProvidesAppNotificationSettings)
											  completionHandler:^(BOOL granted, NSError * _Nullable error) {
		if (error) {
			LogToConsoleError("Notifications failed to authorize: %{public}@", error.localizedDescription);
		}

		LogToConsoleInfo("Notification permission: %{public}@", StringFromBOOL(granted));
	}];

	[self registerCategories];
}

- (NSSet<UNNotificationCategory *> *)categoriesToRegister
{
	/* File Transfers */
	UNNotificationAction *ftAcceptAction =
	[UNNotificationAction actionWithIdentifier:TXNotificationActionIdentifierFileTransferAccept
										 title:TXTLS(@"Prompts[qpv-go]")
									   options:0];

	UNNotificationCategory *ftCategory =
	[UNNotificationCategory categoryWithIdentifier:TXNotificationCategoryIdentifierFileTransfer
										   actions:@[ftAcceptAction]
								 intentIdentifiers:@[]
										   options:UNNotificationCategoryOptionCustomDismissAction];

	/* Private Message */
	UNTextInputNotificationAction *pmReplyAction =
	[UNTextInputNotificationAction actionWithIdentifier:TXNotificationActionIdentifierPrivateMessageReply
												  title:TXTLS(@"Notifications[3t4-kl]")
												options:0
								   textInputButtonTitle:TXTLS(@"Notifications[bhn-uo]")
								   textInputPlaceholder:TXTLS(@"Notifications[do4-2e]")];

	UNNotificationCategory *pmCategory =
	[UNNotificationCategory categoryWithIdentifier:TXNotificationCategoryIdentifierPrivateMessage
										   actions:@[pmReplyAction]
								 intentIdentifiers:@[]
										   options:UNNotificationCategoryOptionCustomDismissAction];

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
	UNNotificationAction *lmMoreInfoAction =
	[UNNotificationAction actionWithIdentifier:TXNotificationActionIdentifierLicenseManagerMoreInfo
										 title:TXTLS(@"TLOLicenseManager[b8b-sg]")
									   options:0];

	UNNotificationCategory *lmCategory =
	[UNNotificationCategory categoryWithIdentifier:TXNotificationCategoryIdentifierLicenseManager
										   actions:@[lmMoreInfoAction]
								 intentIdentifiers:@[]
										   options:UNNotificationCategoryOptionCustomDismissAction];

	NSSet *categories = [NSSet setWithObjects:ftCategory, pmCategory, lmCategory, nil];
#else
	NSSet *categories = [NSSet setWithObjects:ftCategory, pmCategory, nil];
#endif

	return categories;
}

- (void)registerCategories
{
	NSSet *categories = [self categoriesToRegister];

	[RZUserNotificationCenter() setNotificationCategories:categories];
}

- (void)mainWindowSelectionChanged:(NSNotification *)notification
{
	TVCMainWindow *mainWindow = mainWindow();

	[self dismissNotificationsForChannel:mainWindow.selectedChannel
								onClient:mainWindow.selectedClient];
}

- (NSString *)titleForEvent:(TXNotificationType)event
{
#define _df(key, num)			case (key): { return TXTLS((num)); }

	switch (event) {
			_df(TXNotificationTypeAddressBookMatch, @"Notifications[kx3-xk]")
			_df(TXNotificationTypeChannelMessage, @"Notifications[qnz-k4]")
			_df(TXNotificationTypeChannelNotice, @"Notifications[vuq-jp]")
			_df(TXNotificationTypeConnect, @"Notifications[4lr-ej]")
			_df(TXNotificationTypeDisconnect, @"Notifications[wjv-yb]")
			_df(TXNotificationTypeInvite, @"Notifications[eiu-8q]")
			_df(TXNotificationTypeKick, @"Notifications[2nk-lg]")
			_df(TXNotificationTypeNewPrivateMessage, @"Notifications[5yi-gu]")
			_df(TXNotificationTypePrivateMessage, @"Notifications[00b-nx]")
			_df(TXNotificationTypePrivateNotice, @"Notifications[nhz-io]")
			_df(TXNotificationTypeHighlight, @"Notifications[cs4-x9]")
			_df(TXNotificationTypeFileTransferSendSuccessful, @"Notifications[0x2-3h]")
			_df(TXNotificationTypeFileTransferReceiveSuccessful, @"Notifications[qle-7v]")
			_df(TXNotificationTypeFileTransferSendFailed, @"Notifications[sc0-1n]")
			_df(TXNotificationTypeFileTransferReceiveFailed, @"Notifications[we9-1b]")
			_df(TXNotificationTypeFileTransferReceiveRequested, @"Notifications[st5-0n]")
			_df(TXNotificationTypeUserJoined, @"Notifications[25q-af]")
			_df(TXNotificationTypeUserParted, @"Notifications[k3s-by]")
			_df(TXNotificationTypeUserDisconnected, @"Notifications[0fo-bt]")
	}

#undef _df

	return nil;
}

- (void)notify:(TXNotificationType)eventType title:(nullable NSString *)eventTitle description:(nullable NSString *)eventDescription userInfo:(nullable NSDictionary<NSString *,id> *)eventContext
{
	switch (eventType) {
		case TXNotificationTypeHighlight:
		{
			eventTitle = TXTLS(@"Notifications[qka-f3]", eventTitle);

			break;
		}
		case TXNotificationTypeNewPrivateMessage:
		{
			eventTitle = TXTLS(@"Notifications[ltn-hf]");

			break;
		}
		case TXNotificationTypeChannelMessage:
		{
			eventTitle = TXTLS(@"Notifications[ep5-de]", eventTitle);

			break;
		}
		case TXNotificationTypeChannelNotice:
		{
			eventTitle = TXTLS(@"Notifications[chi-km]", eventTitle);

			break;
		}
		case TXNotificationTypePrivateMessage:
		{
			eventTitle = TXTLS(@"Notifications[69i-dy]");

			break;
		}
		case TXNotificationTypePrivateNotice:
		{
			eventTitle = TXTLS(@"Notifications[7hn-dg]");

			break;
		}
		case TXNotificationTypeKick:
		{
			eventTitle = TXTLS(@"Notifications[u30-ia]", eventTitle);

			break;
		}
		case TXNotificationTypeInvite:
		{
			eventTitle = TXTLS(@"Notifications[g4s-cq]", eventTitle);

			break;
		}
		case TXNotificationTypeConnect:
		{
			eventTitle = TXTLS(@"Notifications[mo1-vn]", eventTitle);

			eventDescription = TXTLS(@"Notifications[88k-kl]");

			break;
		}
		case TXNotificationTypeDisconnect:
		{
			eventTitle = TXTLS(@"Notifications[7xe-ig]", eventTitle);

			eventDescription = TXTLS(@"Notifications[bif-2c]");

			break;
		}
		case TXNotificationTypeAddressBookMatch:
		{
			eventTitle = TXTLS(@"Notifications[niq-32]");

			break;
		}
		case TXNotificationTypeFileTransferSendSuccessful:
		{
			eventTitle = TXTLS(@"Notifications[l5y-sx]", eventTitle);

			break;
		}
		case TXNotificationTypeFileTransferReceiveSuccessful:
		{
			eventTitle = TXTLS(@"Notifications[hc9-7n]", eventTitle);

			break;
		}
		case TXNotificationTypeFileTransferSendFailed:
		{
			eventTitle = TXTLS(@"Notifications[het-vh]", eventTitle);

			break;
		}
		case TXNotificationTypeFileTransferReceiveFailed:
		{
			eventTitle = TXTLS(@"Notifications[hm4-ze]", eventTitle);

			break;
		}
		case TXNotificationTypeFileTransferReceiveRequested:
		{
			eventTitle = TXTLS(@"Notifications[nqz-7v]", eventTitle);

			break;
		}
		case TXNotificationTypeUserJoined:
		{
			eventTitle = TXTLS(@"Notifications[keq-ts]", eventTitle);

			break;
		}
		case TXNotificationTypeUserParted:
		{
			eventTitle = TXTLS(@"Notifications[im4-p0]", eventTitle);

			break;
		}
		case TXNotificationTypeUserDisconnected:
		{
			eventTitle = TXTLS(@"Notifications[20x-32]", eventTitle);

			break;
		}
	}

	if ([TPCPreferences removeAllFormatting] == NO) {
		eventDescription = eventDescription.stripIRCEffects;
	}

	NSString *categoryIdentifier = nil;

	if (eventType == TXNotificationTypeFileTransferReceiveRequested) {
		categoryIdentifier = TXNotificationCategoryIdentifierFileTransfer;
	} else if (eventType == TXNotificationTypeNewPrivateMessage ||
			   eventType == TXNotificationTypePrivateMessage)
	{
		categoryIdentifier = TXNotificationCategoryIdentifierPrivateMessage;
	}

	NSString *clientId = eventContext[TXNotificationUserInfoClientIdentifierKey];
	NSString *channelId = eventContext[TXNotificationUserInfoChannelIdentifierKey];

	NSString *threadIdentifier = [self threadIdentifierForClient:clientId channel:channelId];

	[self scheduleNotificationWithTitle:eventTitle
								message:eventDescription
							   userInfo:eventContext
				 notificationIdentifier:nil
					   threadIdentifier:threadIdentifier
					 categoryIdentifier:categoryIdentifier];
}

- (nullable NSString *)threadIdentifierForClient:(nullable NSString *)clientIdentifier channel:(nullable NSString *)channelIdentifier
{
	if (clientIdentifier == nil) {
		return nil;
	}

	if (channelIdentifier) {
		return [clientIdentifier stringByAppendingFormat:@"-%@", channelIdentifier];
	}

	return clientIdentifier;
}

- (void)scheduleNotificationWithTitle:(NSString *)title
							  message:(NSString *)message
							 userInfo:(nullable NSDictionary<NSString *, id> *)userInfo
{
	NSParameterAssert(title != nil);
	NSParameterAssert(message != nil);

	[self scheduleNotificationWithTitle:title
								message:message
							   userInfo:userInfo
				 notificationIdentifier:nil
					   threadIdentifier:nil
					 categoryIdentifier:nil];
}

- (void)scheduleNotificationWithTitle:(NSString *)title
							  message:(NSString *)message
							 userInfo:(nullable NSDictionary<NSString *, id> *)userInfo
					 threadIdentifier:(NSString *)threadIdentifier
{
	NSParameterAssert(title != nil);
	NSParameterAssert(message != nil);
	NSParameterAssert(threadIdentifier != nil);

	[self scheduleNotificationWithTitle:title
								message:message
							   userInfo:userInfo
				 notificationIdentifier:nil
					   threadIdentifier:threadIdentifier
					 categoryIdentifier:nil];
}

- (void)scheduleNotificationWithTitle:(NSString *)title
							  message:(NSString *)message
						   forChannel:(IRCChannel *)channel
{
	NSParameterAssert(title != nil);
	NSParameterAssert(message != nil);
	NSParameterAssert(channel != nil);

	IRCClient *client = channel.associatedClient;

	[self scheduleNotificationWithTitle:title
								message:message
							 forChannel:channel
							   onClient:client];
}

- (void)scheduleNotificationWithTitle:(NSString *)title
							  message:(NSString *)message
							 onClient:(IRCClient *)client
{
	NSParameterAssert(title != nil);
	NSParameterAssert(message != nil);
	NSParameterAssert(client != nil);

	[self scheduleNotificationWithTitle:title
								message:message
							 forChannel:nil
							   onClient:client];
}

- (void)scheduleNotificationWithTitle:(NSString *)title
							  message:(NSString *)message
						   forChannel:(nullable IRCChannel *)channel
							 onClient:(IRCClient *)client
{
	NSParameterAssert(title != nil);
	NSParameterAssert(message != nil);
	NSParameterAssert(client != nil);

	NSString *clientId = client.uniqueIdentifier;
	NSString *channelId = channel.uniqueIdentifier;

	NSString *threadIdentifier = [self threadIdentifierForClient:clientId channel:channelId];

	NSDictionary *userInfo = nil;

	if (channelId) {
		userInfo = @{TXNotificationUserInfoClientIdentifierKey : clientId,
					 TXNotificationUserInfoChannelIdentifierKey : channelId};
	} else {
		userInfo = @{TXNotificationUserInfoClientIdentifierKey : clientId};
	}

	[self scheduleNotificationWithTitle:title
								message:message
							   userInfo:userInfo
				 notificationIdentifier:nil
					   threadIdentifier:threadIdentifier
					 categoryIdentifier:nil];
}

- (void)scheduleNotificationWithTitle:(NSString *)title
							  message:(NSString *)message
							 userInfo:(nullable NSDictionary<NSString *, id> *)userInfo
			   notificationIdentifier:(nullable NSString *)notificationIdentifier
					 threadIdentifier:(nullable NSString *)threadIdentifier
				   categoryIdentifier:(nullable NSString *)categoryIdentifier
{
	NSParameterAssert(title != nil);
	NSParameterAssert(message != nil);

	UNMutableNotificationContent *notificationContent = [UNMutableNotificationContent new];

	notificationContent.title = title;
	notificationContent.body = message;

	if (userInfo) {
		notificationContent.userInfo = userInfo;
	}

	if (categoryIdentifier) {
		notificationContent.categoryIdentifier = categoryIdentifier;
	}

	if (threadIdentifier) {
		notificationContent.threadIdentifier = threadIdentifier;
	}

	/* The notification identifier should be unique to the specific notification
	 because otherwise the system will replace existing notifications of the
	 same identifier. That's not a bad behavior. Just not one we want. */
	/* Textual will format the identifier as such:
	 TXNotification[-<clientID>[-<channelId>]]-<eventTitle hash>-<eventDescription hash> */
	if (notificationIdentifier == nil) {
		notificationIdentifier = [NSString stringWithFormat:@"TXNotification-%@-%ld-%ld",
			((threadIdentifier) ?: @"<No Thread>"), title.hash, message.hash];;
	}

	[self scheduleNotificationWithContent:notificationContent
							   identifier:notificationIdentifier];
}

- (void)scheduleNotificationWithContent:(UNNotificationContent *)notificationContent identifier:(nullable NSString *)notificationIdentifier
{
	NSParameterAssert(notificationContent != nil);
	NSParameterAssert(notificationIdentifier != nil);

	UNNotificationRequest *notificationRequest =
	[UNNotificationRequest requestWithIdentifier:notificationIdentifier
										 content:notificationContent
										 trigger:nil];

	[self scheduleNotificationRequest:notificationRequest];
}

- (void)scheduleNotificationRequest:(UNNotificationRequest *)request
{
	NSParameterAssert(request != nil);

	[RZUserNotificationCenter() addNotificationRequest:request
								 withCompletionHandler:^(NSError * _Nullable error) {
		if (error) {
			LogToConsoleError("Failed to post notification '%{private}@': %{public}@",
				request.content.title, error.localizedDescription);
		}
	}];
}

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
- (void)scheduleLicenseManagerNotificationWithTitle:(NSString *)title
											message:(NSString *)message
{
	NSParameterAssert(title != nil);
	NSParameterAssert(message != nil);

	[self scheduleNotificationWithTitle:title
								message:message
							   userInfo:nil
				 notificationIdentifier:nil
					   threadIdentifier:nil
					 categoryIdentifier:TXNotificationCategoryIdentifierLicenseManager];
}
#endif

#pragma mark -
#pragma mark Notification Center Delegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center openSettingsForNotification:(nullable UNNotification *)notification
{
	[menuController() showNotificationPreferences:nil];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
	completionHandler(UNNotificationPresentationOptionList |
					  UNNotificationPresentationOptionBanner);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)(void))completionHandler
{
	NSString *message = nil;

	if ([response isKindOfClass:[UNTextInputNotificationResponse class]]) {
		message = [((UNTextInputNotificationResponse *)response) userText];
	}

	/* Now that is what you call chaining... */
	NSDictionary *userInfo = response.notification.request.content.userInfo;

	[self notificationResponseReceived:response context:userInfo withReplyMessage:message];
}

- (void)dismissNotificationsForChannel:(nullable IRCChannel *)channel onClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	NSString *clientId = client.uniqueIdentifier;
	NSString *channelId = channel.uniqueIdentifier;

	LogToConsoleDebug("Dismissing notifications for '%{public}@' on '%{public}@'",
		((channelId) ?: @"<No Channel>"), clientId);

	/* Pending Notifications */
	[RZUserNotificationCenter() getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *requests) {
		NSMutableArray<NSString *> *notificationIdentifiers = [NSMutableArray array];

		[requests enumerateObjectsUsingBlock:^(UNNotificationRequest *request, NSUInteger index, BOOL *stop) {
			if ([self isNotificationRequest:request inScopeOfChannel:channel onClient:client]) {
				[notificationIdentifiers addObject:request.identifier];
			}
		}];

		if (notificationIdentifiers.count == 0) {
			return;
		}

		[RZUserNotificationCenter() removePendingNotificationRequestsWithIdentifiers:notificationIdentifiers];

		LogToConsoleDebug("Dismissed %{public}ld pending notifications",
			notificationIdentifiers.count);
	}];

	/* Delivered Notifications */
	[RZUserNotificationCenter() getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> *notifications) {
		NSMutableArray<NSString *> *notificationIdentifiers = [NSMutableArray array];

		[notifications enumerateObjectsUsingBlock:^(UNNotification *notification, NSUInteger index, BOOL *stop) {
			UNNotificationRequest *request = notification.request;

			if ([self isNotificationRequest:request inScopeOfChannel:channel onClient:client]) {
				[notificationIdentifiers addObject:request.identifier];
			}
		}];

		if (notificationIdentifiers.count == 0) {
			return;
		}

		[RZUserNotificationCenter() removeDeliveredNotificationsWithIdentifiers:notificationIdentifiers];

		LogToConsoleDebug("Dismissed %{public}ld delivered notifications",
			notificationIdentifiers.count);
	}];
}

- (BOOL)isNotificationRequest:(UNNotificationRequest *)request inScopeOfChannel:(nullable IRCChannel *)channel onClient:(IRCClient *)client
{
	NSParameterAssert(request != nil);
	NSParameterAssert(client != nil);

	NSString *clientIdLeft = client.uniqueIdentifier;
	NSString *channelIdLeft = channel.uniqueIdentifier;

	NSDictionary *userInfo = request.content.userInfo;

	NSString *clientIdRight = userInfo[TXNotificationUserInfoClientIdentifierKey];
	NSString *channelIdRight = userInfo[TXNotificationUserInfoChannelIdentifierKey];

	/* NSObjectsAreEqual() checks for equality of nil so it is valid
	 if channel ID left and right are both nil. */
	return (NSObjectsAreEqual(clientIdLeft, clientIdRight) &&
			NSObjectsAreEqual(channelIdLeft, channelIdRight));
}

#pragma mark -
#pragma mark Notification Callback

- (void)notificationResponseReceived:(UNNotificationResponse *)response context:(NSDictionary<NSString *, id> *)context withReplyMessage:(nullable NSString *)message
{
	NSParameterAssert(context != nil);

	NSString *actionIdentifier = [response actionIdentifier];

	if ([actionIdentifier isEqualToString:UNNotificationDismissActionIdentifier]) {
		LogToConsoleDebug("Dismissed notification: '%{private}@'", response);

		return;
	}

	/* If we ever expand beyond a few different actions, then revisit
	 this so that we aren't just declaring a bunch of booleans.
	 This was just the easier solution at the time. */
	BOOL isFileTransferAction = [actionIdentifier isEqualToString:TXNotificationActionIdentifierFileTransferAccept];
	BOOL isPrivateMessageAction = [actionIdentifier isEqualToString:TXNotificationActionIdentifierPrivateMessageReply];
	BOOL isLicenseManagerAction = NO;

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
	if ([actionIdentifier isEqualToString:TXNotificationActionIdentifierLicenseManagerMoreInfo]) {
		isLicenseManagerAction = YES;
	}
#endif

	BOOL activateApp 	= (isPrivateMessageAction == NO);
	BOOL keyMainWindow 	= (isPrivateMessageAction == NO &&
						   isFileTransferAction == NO &&
						   isLicenseManagerAction == NO);

	if (activateApp) {
		[NSApp activateIgnoringOtherApps:YES];
	}

	if (keyMainWindow) {
		[mainWindow() makeKeyAndOrderFront:nil];
	}

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
	/* Handle a notification that was clicked related to a warnings about
	 the trial of Textual preparing to expire. */
	if (isLicenseManagerAction)
	{
		[menuController() manageLicense:nil];
	}
	else
#endif

	/* Handle file transfer notifications allowing the user to start a
	 file transfer directly through the notification's action button. */
	if (isFileTransferAction)
	{
		[[TXSharedApplication sharedFileTransferDialog] show:YES restorePosition:NO];

		NSInteger alertType = [context integerForKey:@"fileTransferNotificationType"];

		if (alertType != TXNotificationTypeFileTransferReceiveRequested) {
			return;
		}

		NSString *uniqueIdentifier = context[@"fileTransferUniqueIdentifier"];

		TDCFileTransferDialogTransferController *fileTransfer = [[TXSharedApplication sharedFileTransferDialog] fileTransferWithUniqueIdentifier:uniqueIdentifier];

		if (fileTransfer == nil) {
			return;
		}

		TDCFileTransferDialogTransferStatus transferStatus = fileTransfer.transferStatus;

		if (transferStatus != TDCFileTransferDialogTransferStatusStopped) {
			return;
		}

		[fileTransfer openWithPathOrUserDownloads];
	}

	/* Handle all other IRC related notifications. */
	else
	{
		NSString *clientId = context[TXNotificationUserInfoClientIdentifierKey];
		NSString *channelId = context[TXNotificationUserInfoChannelIdentifierKey];

		if (clientId == nil) {
			return;
		}

		IRCClient *client = nil;
		IRCChannel *channel = nil;

		if (channelId) {
			channel = [worldController() findChannelWithId:channelId onClientWithId:clientId];
		} else {
			client = [worldController() findClientWithId:clientId];
		}

		if (channel) {
			[mainWindow() select:channel];
		} else if (client) {
			[mainWindow() select:client];
		}

		if (channel == nil) {
			return;
		}

		if (message.length == 0) {
			return;
		}

		[channel.associatedClient inputText:message destination:channel];
	}
}

@end

#pragma mark -

@implementation TLONotificationController (Preferences)

- (nullable NSString *)soundForEvent:(TXNotificationType)event inChannel:(nullable IRCChannel *)channel
{
	if (channel) {
		NSString *channelValue = [channel.config soundForEvent:event];

		if (channelValue != nil) {
			return channelValue;
		}
	}

	return [TPCPreferences soundForEvent:event];
}

- (BOOL)speakEvent:(TXNotificationType)event inChannel:(nullable IRCChannel *)channel
{
	if (channel) {
		NSUInteger channelValue = [channel.config speakEvent:event];

		if (channelValue != NSControlStateValueMixed) {
			return (channelValue == NSControlStateValueOn);
		}
	}

	return [TPCPreferences speakEvent:event];
}

- (BOOL)notificationEnabledForEvent:(TXNotificationType)event inChannel:(nullable IRCChannel *)channel
{
	if (channel) {
		NSUInteger channelValue = [channel.config notificationEnabledForEvent:event];

		if (channelValue != NSControlStateValueMixed) {
			return (channelValue == NSControlStateValueOn);
		}
	}

	return [TPCPreferences notificationEnabledForEvent:event];
}

- (BOOL)disabledWhileAwayForEvent:(TXNotificationType)event inChannel:(nullable IRCChannel *)channel
{
	if (channel) {
		NSUInteger channelValue = [channel.config disabledWhileAwayForEvent:event];

		if (channelValue != NSControlStateValueMixed) {
			return (channelValue == NSControlStateValueOn);
		}
	}

	return [TPCPreferences disabledWhileAwayForEvent:event];
}

- (BOOL)bounceDockIconForEvent:(TXNotificationType)event inChannel:(nullable IRCChannel *)channel
{
	if (channel) {
		NSUInteger channelValue = [channel.config bounceDockIconForEvent:event];

		if (channelValue != NSControlStateValueMixed) {
			return (channelValue == NSControlStateValueOn);
		}
	}

	return [TPCPreferences bounceDockIconForEvent:event];
}

- (BOOL)bounceDockIconRepeatedlyForEvent:(TXNotificationType)event inChannel:(nullable IRCChannel *)channel
{
	if (channel) {
		NSUInteger channelValue = [channel.config bounceDockIconRepeatedlyForEvent:event];

		if (channelValue != NSControlStateValueMixed) {
			return (channelValue == NSControlStateValueOn);
		}
	}

	return [TPCPreferences bounceDockIconRepeatedlyForEvent:event];
}

@end

NS_ASSUME_NONNULL_END
