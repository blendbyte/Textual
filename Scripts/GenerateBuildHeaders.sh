#!/bin/sh

set -e

# Generate BuildConfig.h and FeatureFlags.h from the build settings. Each
# file is only replaced when its contents change, so that unchanged builds
# don't recompile what includes them.

mkdir -p "${TEXTUAL_GENERATED_DIR}/Build Headers"

cd "${TEXTUAL_GENERATED_DIR}/Build Headers"

# BuildConfig.h gives the code the build's identity and version without
# reading the Info.plist. The versions come from Configurations/Version.xcconfig.
echo "
/* ANY CHANGES TO THIS FILE WILL NOT BE SAVED AND WILL NOT BE COMMITTED */

#define TXBundleBuildProductName					@\"${PRODUCT_NAME}\"
#define TXBundleBuildProductIdentifier				@\"${PRODUCT_BUNDLE_IDENTIFIER}\"
#define TXBundleBuildProductIdentifierCString		 \"${PRODUCT_BUNDLE_IDENTIFIER}\"
#define TXBundleBuildGroupContainerIdentifier		@\"${TEXTUAL_GROUP_CONTAINER_IDENTIFIER}\"
#define TXBundleBuildVersion						@\"${CURRENT_PROJECT_VERSION}\"
#define TXBundleBuildVersionShort					@\"${MARKETING_VERSION}\"
#define TXBundleBuildScheme							@\"${TEXTUAL_BUILD_SCHEME_TOKEN}\"
" > _BuildConfig.h

if [ -z "$CODE_SIGN_IDENTITY" ]; then
echo "#define TXBundleBuiltWithoutCodeSigning		1" >> _BuildConfig.h
fi

if cmp -s "BuildConfig.h" "_BuildConfig.h"; then
	echo "BuildConfig.h hasn't changed (version ${MARKETING_VERSION}, build ${CURRENT_PROJECT_VERSION})."

	rm "_BuildConfig.h"
else
	echo "Writing BuildConfig.h (version ${MARKETING_VERSION}, build ${CURRENT_PROJECT_VERSION})."

	mv -f "_BuildConfig.h" "BuildConfig.h"
fi

"${TEXTUAL_WORKSPACE_DIR}/Scripts/UpdateFeatureFlags.sh"

exit 0
