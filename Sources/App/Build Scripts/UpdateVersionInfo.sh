#!/bin/sh

set -e

mkdir -p "${TEXTUAL_WORKSPACE_TEMP_DIR}"

cd "${TEXTUAL_WORKSPACE_TEMP_DIR}/"

# Generate the Info.plist used by the build in the .tmp folder. It is
# regenerated from the source on every build because .tmp is shared by
# all build configurations, and only replaced when its contents change
# so that unchanged builds do not reprocess it.

infoPlistSource="${PROJECT_DIR}/Resources/Property Lists/Application Properties/Info.plist"

cp "${infoPlistSource}" _Info.plist

# The build version is the date of the last commit in git.
# Without git, or outside a git checkout (e.g. a downloaded archive),
# fall back to a placeholder version instead of failing.
gitDateOfLastCommit=""

if command -v git > /dev/null 2>&1; then
	gitDateOfLastCommit=$(git -C "${TEXTUAL_WORKSPACE_DIR}" log -n1 --format="%at" 2> /dev/null || true)
fi

if [ -z "${gitDateOfLastCommit}" ]; then
	echo "warning: No git history available; using placeholder build version 000000.00"

	bundleVersionNew="000000.00"
else
	bundleVersionNew=$(/bin/date -u -r "${gitDateOfLastCommit}" "+%y%m%d.%H")
fi

/usr/libexec/PlistBuddy -c "Set \"CFBundleVersion\" \"${bundleVersionNew}\"" _Info.plist

# Builds without Sparkle (the App Store build) carry no Sparkle settings.
if [ "${TEXTUAL_BUILT_WITH_SPARKLE_ENABLED}" != "1" ]; then
	for key in $(/usr/libexec/PlistBuddy -c "Print" _Info.plist | sed -n 's/^    \(SU[A-Za-z]*\) = .*/\1/p'); do
		/usr/libexec/PlistBuddy -c "Delete \"${key}\"" _Info.plist
	done
fi

if cmp -s "Info.plist" "_Info.plist"; then
	echo "Step 1: Info.plist hasn't changed (version '${bundleVersionNew}')."

	rm "_Info.plist"
else
	echo "Step 1: Writing Info.plist (version '${bundleVersionNew}')."

	mv -f "_Info.plist" "Info.plist"
fi

# ------ #

# Gather the information necessary for building Textual's BuildConfig.h
# header. This header file gives various section of the code base version
# information so it does not need to constantly access the Info.plist file.
bundleVersionShort=$(/usr/libexec/PlistBuddy -c "Print \"CFBundleShortVersionString\"" Info.plist)

mkdir -p "./Build Headers"

cd "./Build Headers"

echo "
/* ANY CHANGES TO THIS FILE WILL NOT BE SAVED AND WILL NOT BE COMMITTED */

#define TXBundleBuildProductName					@\"${PRODUCT_NAME}\"
#define TXBundleBuildProductIdentifier				@\"${PRODUCT_BUNDLE_IDENTIFIER}\"
#define TXBundleBuildProductIdentifierCString		 \"${PRODUCT_BUNDLE_IDENTIFIER}\"
#define TXBundleBuildGroupContainerIdentifier		@\"${TEXTUAL_GROUP_CONTAINER_IDENTIFIER}\"
#define TXBundleBuildVersion						@\"${bundleVersionNew}\"
#define TXBundleBuildVersionShort					@\"${bundleVersionShort}\"
#define TXBundleBuildScheme							@\"${TEXTUAL_BUILD_SCHEME_TOKEN}\"
" > _BuildConfig.h

if [ -z "$CODE_SIGN_IDENTITY" ]; then
echo "#define TXBundleBuiltWithoutCodeSigning		1" >> _BuildConfig.h
fi

if cmp -s "BuildConfig.h" "_BuildConfig.h"; then
	echo "Step 3: The build configuration file hasn't changed. Not deploying."

	rm "_BuildConfig.h"
else
	# Force flag is used on rm to avoid error for missing file
	rm -f "BuildConfig.h"

	mv "_BuildConfig.h" "BuildConfig.h"
fi

# ------ #

# Compile list of enabled features
"${PROJECT_DIR}/Build Scripts/UpdateFeatureFlags.sh"

# ------ #

# Exit with success
exit 0;
