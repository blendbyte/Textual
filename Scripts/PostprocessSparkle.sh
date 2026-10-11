#!/bin/bash

set -e

# Sign with the identity Xcode resolved for this build (a certificate hash).
# The configured name can match several certificates, e.g. Apple Development
# certificates of more than one team. Unsigned builds fall back to the name.
SIGNING_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-$CODE_SIGN_IDENTITY}"

if [ "${TEXTUAL_BUILT_WITH_SPARKLE_ENABLED}" != "1" ]; then
	echo "Sparkle is not part of this build; nothing to postprocess"

	exit 0
fi

echo "Performing postprocessing on Sparkle framework"

cd "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

# The framework's current version folder ("B" since Sparkle 2), not hard-coded
VERSION_PATH="Sparkle.framework/Versions/$(readlink Sparkle.framework/Versions/Current)"

[ -d "${VERSION_PATH}" ] || { echo "error: Sparkle.framework has no current version"; exit 1; }

# Notarization needs a secure timestamp; local builds (ad-hoc or development
# signatures) sign without one so they work offline
TIMESTAMP_OPTION="--timestamp=none"

if [ "${CONFIGURATION}" != "Debug" ] && [ -n "${SIGNING_IDENTITY}" ] && [ "${SIGNING_IDENTITY}" != "-" ]; then
	TIMESTAMP_OPTION="--timestamp"
fi

# Textual has network access itself; Sparkle's downloader service is only for
# sandboxed apps without it (SUEnableDownloaderService is off)
rm -rf "${VERSION_PATH}/XPCServices/Downloader.xpc"

codesign -f -s "${SIGNING_IDENTITY}" -o runtime ${TIMESTAMP_OPTION} "${VERSION_PATH}/XPCServices/Installer.xpc"

codesign -f -s "${SIGNING_IDENTITY}" -o runtime ${TIMESTAMP_OPTION} "${VERSION_PATH}/Autoupdate"
codesign -f -s "${SIGNING_IDENTITY}" -o runtime ${TIMESTAMP_OPTION} "${VERSION_PATH}/Updater.app"

codesign -f -s "${SIGNING_IDENTITY}" -o runtime ${TIMESTAMP_OPTION} Sparkle.framework

exit 0
