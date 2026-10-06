#!/bin/sh

set -e

mkdir -p "${TEXTUAL_WORKSPACE_TEMP_DIR}"

cd "${TEXTUAL_WORKSPACE_TEMP_DIR}/"

# Make a copy of the Info.plist file in the .tmp folder
# This will be the Info.plist file manipulated with the version
# information that is generated below.

infoPlistSource="${PROJECT_DIR}/Resources/Property Lists/Application Properties/Info.plist"

infoPlistTarget="${TEXTUAL_WORKSPACE_TEMP_DIR}/Info.plist"

if [ ! -f "${infoPlistTarget}" ] || [ "${infoPlistTarget}" -ot "${infoPlistSource}" ]; then
	echo "Step 1: Info.plist file doesn't exist and/or is oudated. Performing copy."

	# Copy with -p flag to preserve modification time
	cp -p "${infoPlistSource}" "${infoPlistTarget}"
else
	echo "Step 1: Info.plist file hasn't changed."
fi

# Write the version information to the Info.plist file.
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

bundleVersionOld=$(/usr/libexec/PlistBuddy -c "Print \"CFBundleVersion\"" Info.plist)

if [ "${bundleVersionOld}" != "${bundleVersionNew}" ]; then
	echo "Step 2: Writing version: New ('${bundleVersionNew}'), Old ('${bundleVersionOld}')"

	/usr/libexec/PlistBuddy -c "Set \"CFBundleVersion\" \"${bundleVersionNew}\"" Info.plist
else
	echo "Step 2: The version hasn't changed."
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
