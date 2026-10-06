#!/bin/bash

set -e

# Sign with the identity Xcode resolved for this build (a certificate hash).
# The configured name can match several certificates, e.g. Apple Development
# certificates of more than one team. Unsigned builds fall back to the name.
SIGNING_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-$CODE_SIGN_IDENTITY}"

echo "Performing postprocessing on Sparkle framework"

cd "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

rm -rf Sparkle.framework/Versions/B/XPCServices/Downloader.xpc

codesign -f -s "$SIGNING_IDENTITY" -o runtime Sparkle.framework/Versions/B/XPCServices/Installer.xpc

codesign -f -s "$SIGNING_IDENTITY" -o runtime Sparkle.framework/Versions/B/Autoupdate
codesign -f -s "$SIGNING_IDENTITY" -o runtime Sparkle.framework/Versions/B/Updater.app

codesign -f -s "$SIGNING_IDENTITY" -o runtime Sparkle.framework

exit 0
