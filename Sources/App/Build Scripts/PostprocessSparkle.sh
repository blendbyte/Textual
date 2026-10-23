#!/bin/bash

set -e

echo "Performing postprocessing on Sparkle framework"

cd "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

# The identity Xcode resolved for this build. A generic name such as
# "Mac Developer" can also match an installer certificate, which can't
# sign code, and Sparkle's seal is then left broken.
SIGNING_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-$CODE_SIGN_IDENTITY}"

rm -rf Sparkle.framework/Versions/B/XPCServices/Downloader.xpc

codesign -f -s "$SIGNING_IDENTITY" -o runtime Sparkle.framework/Versions/B/XPCServices/Installer.xpc

codesign -f -s "$SIGNING_IDENTITY" -o runtime Sparkle.framework/Versions/B/Autoupdate
codesign -f -s "$SIGNING_IDENTITY" -o runtime Sparkle.framework/Versions/B/Updater.app

codesign -f -s "$SIGNING_IDENTITY" -o runtime Sparkle.framework

exit 0
