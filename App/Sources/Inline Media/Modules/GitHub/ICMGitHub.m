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

#import "TLOLocalization.h"
#import "ICLHelpers.h"
#import "ICMGitHub.h"

NS_ASSUME_NONNULL_BEGIN

/* Page cards for GitHub repositories, issues, pull requests and commits, from
 GitHub's public REST API (no account; 60 lookups an hour per address, which
 the 30-minute cache stretches) */
@implementation ICMGitHub

+ (NSString *)_formattedCount:(NSUInteger)count
{
	if (count >= 1000000) {
		return [NSString stringWithFormat:@"%.1fM", (count / 1000000.0)];
	} else if (count >= 1000) {
		return [NSString stringWithFormat:@"%.1fk", (count / 1000.0)];
	}

	return [NSString stringWithFormat:@"%lu", count];
}

- (void)_performActionForRepository:(NSString *)repository
{
	NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.github.com/repos/%@", repository]];

	[ICLHelpers requestJSONDataFromURL:requestURL session:self.payload.session completionBlock:^(BOOL success, NSDictionary<NSString *, id> * _Nullable data) {
		NSString *fullName = [data stringForKey:@"full_name"];

		if (fullName == nil) {
			[self notifyUnableToPresentCard];

			return;
		}

		ICMPreviewCardContent *card = [ICMPreviewCardContent new];

		card.style = ICMPreviewCardStylePage;
		card.targetURL = self.payload.url;
		card.title = fullName;
		card.text = [data stringForKey:@"description"];

		NSString *avatar = [[data dictionaryForKey:@"owner"] stringForKey:@"avatar_url"];

		if (avatar) {
			card.imageURL = [ICLHelpers URLWithString:avatar];
		}

		NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:@"GitHub"];

		NSString *language = [data stringForKey:@"language"];

		if (language) {
			[details addObject:language];
		}

		[details addObject:[@"★ " stringByAppendingString:[self.class _formattedCount:[data unsignedIntegerForKey:@"stargazers_count"]]]];

		card.details = details;

		[self performActionForCard:card];
	}];
}

- (void)_performActionForIssue:(NSString *)number inRepository:(NSString *)repository
{
	NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.github.com/repos/%@/issues/%@", repository, number]];

	[ICLHelpers requestJSONDataFromURL:requestURL session:self.payload.session completionBlock:^(BOOL success, NSDictionary<NSString *, id> * _Nullable data) {
		NSString *title = [data stringForKey:@"title"];

		if (title == nil) {
			[self notifyUnableToPresentCard];

			return;
		}

		NSDictionary *pullRequest = [data dictionaryForKey:@"pull_request"];

		NSString *state = [data stringForKey:@"state"];

		if ([pullRequest stringForKey:@"merged_at"]) {
			state = @"merged";
		}

		ICMPreviewCardContent *card = [ICMPreviewCardContent new];

		card.style = ICMPreviewCardStylePage;
		card.targetURL = self.payload.url;
		card.title = title;

		NSDictionary *user = [data dictionaryForKey:@"user"];

		NSString *avatar = [user stringForKey:@"avatar_url"];

		if (avatar) {
			card.imageURL = [ICLHelpers URLWithString:avatar];
		}

		NSString *kind = ((pullRequest) ? @"Pull request" : @"Issue");

		NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObjects:@"GitHub", repository, [NSString stringWithFormat:@"%@ #%@", kind, number], nil];

		if (state.length > 0) {
			[details addObject:state.capitalizedString];
		}

		NSString *login = [user stringForKey:@"login"];

		if (login) {
			[details addObject:login];
		}

		card.details = details;

		[self performActionForCard:card];
	}];
}

- (void)_performActionForCommit:(NSString *)commit inRepository:(NSString *)repository
{
	NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.github.com/repos/%@/commits/%@", repository, commit]];

	[ICLHelpers requestJSONDataFromURL:requestURL session:self.payload.session completionBlock:^(BOOL success, NSDictionary<NSString *, id> * _Nullable data) {
		NSString *message = [[data dictionaryForKey:@"commit"] stringForKey:@"message"];

		if (message == nil) {
			[self notifyUnableToPresentCard];

			return;
		}

		ICMPreviewCardContent *card = [ICMPreviewCardContent new];

		card.style = ICMPreviewCardStylePage;
		card.targetURL = self.payload.url;

		/* The first line is the summary; the rest the description */
		NSRange lineBreak = [message rangeOfString:@"\n"];

		if (lineBreak.location == NSNotFound) {
			card.title = message;
		} else {
			card.title = [message substringToIndex:lineBreak.location];
			card.text = [message substringFromIndex:NSMaxRange(lineBreak)];
		}

		NSDictionary *author = [data dictionaryForKey:@"author"];

		NSString *avatar = [author stringForKey:@"avatar_url"];

		if (avatar) {
			card.imageURL = [ICLHelpers URLWithString:avatar];
		}

		NSString *sha = [data stringForKey:@"sha"];

		NSString *shortSha = ((sha.length >= 7) ? [sha substringToIndex:7] : commit);

		NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObjects:@"GitHub", repository, [@"Commit " stringByAppendingString:shortSha], nil];

		NSString *login = [author stringForKey:@"login"];

		if (login) {
			[details addObject:login];
		}

		card.details = details;

		[self performActionForCard:card];
	}];
}

#pragma mark -
#pragma mark Action Block

+ (nullable ICLInlineContentModuleActionBlock)actionBlockForURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSArray<NSString *> *components = [[url.path.percentEncodedURLPath trimCharacters:@"/"] componentsSeparatedByString:@"/"];

	if (components.count < 2) {
		return nil;
	}

	NSString *owner = components[0];
	NSString *name = components[1];

	NSCharacterSet *nameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_."];

	if (owner.length == 0 || name.length == 0 ||
		[owner onlyContainsCharactersFromCharacterSet:nameCharacters] == NO ||
		[name onlyContainsCharactersFromCharacterSet:nameCharacters] == NO ||
		[self.reservedPaths containsObject:owner.lowercaseString])
	{
		return nil;
	}

	NSString *repository = [NSString stringWithFormat:@"%@/%@", owner, name];

	if (components.count >= 4) {
		NSString *kind = components[2];
		NSString *value = components[3];

		if (([kind isEqualToString:@"issues"] || [kind isEqualToString:@"pull"]) && value.isNumericOnly) {
			return [^(ICLInlineContentModule *module) {
				[(ICMGitHub *)module _performActionForIssue:value inRepository:repository];
			} copy];
		}

		if ([kind isEqualToString:@"commit"] && value.length >= 7 && value.length <= 40 &&
			[value onlyContainsCharactersFromCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"]])
		{
			return [^(ICLInlineContentModule *module) {
				[(ICMGitHub *)module _performActionForCommit:value inRepository:repository];
			} copy];
		}
	}

	return [^(ICLInlineContentModule *module) {
		[(ICMGitHub *)module _performActionForRepository:repository];
	} copy];
}

/* github.com/<these>/… are GitHub's own pages, not owners */
+ (NSArray<NSString *> *)reservedPaths
{
	static NSArray<NSString *> *reservedPaths = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		reservedPaths =
		@[@"about", @"apps", @"codespaces", @"collections", @"customer-stories", @"enterprise",
		  @"events", @"explore", @"features", @"issues", @"login", @"marketplace", @"new",
		  @"notifications", @"orgs", @"pricing", @"pulls", @"search", @"security", @"settings",
		  @"site", @"sponsors", @"topics", @"trending", @"users"];
	});

	return reservedPaths;
}

+ (nullable NSArray<NSString *> *)domains
{
	return @[@"github.com", @"www.github.com"];
}

+ (nullable NSString *)serviceName
{
	return TXLocalizationNotNeeded(@"GitHub");
}

+ (nullable NSArray<NSString *> *)serviceHosts
{
	return @[@"githubusercontent.com"];
}

@end

NS_ASSUME_NONNULL_END
