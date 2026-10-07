#!/bin/bash

set -e

cd "${TEXTUAL_GENERATED_DIR}/Build Headers/"

echo "
/* ANY CHANGES TO THIS FILE WILL NOT BE SAVED AND WILL NOT BE COMMITTED */
" > _FeatureFlags.h

# TEXTUAL_BUILT_WITH_ADVANCED_ENCRYPTION is always 0 (Off-the-Record Messaging
# was removed). It stays defined for plugins that still test it.
featureNames=("TEXTUAL_BUILT_INSIDE_SANDBOX"
			"TEXTUAL_BUILT_WITH_SPARKLE_ENABLED"
			"TEXTUAL_BUILT_WITH_LICENSE_MANAGER"
			"TEXTUAL_BUILT_WITH_ADVANCED_ENCRYPTION"
			"TEXTUAL_BUILT_FOR_APP_STORE_DISTRIBUTION"
			"TEXTUAL_BUILT_AS_UNIVERSAL_BINARY")

for feature in "${featureNames[@]}"; do
	featureValue="${!feature}"

	if [ -n "${featureValue}" ]; then
		echo "#define ${feature} ${featureValue}" >> _FeatureFlags.h
	else
		echo "#define ${feature} 0" >> _FeatureFlags.h
	fi
done

if cmp -s "FeatureFlags.h" "_FeatureFlags.h"; then
	echo "The feature flags file hasn't changed. Not deploying."

	rm "_FeatureFlags.h"
else
	# Force flag is used on rm to avoid error for missing file
	rm -f "FeatureFlags.h"

	mv "_FeatureFlags.h" "FeatureFlags.h"
fi

# ------ #

# Exit with success
exit 0;
