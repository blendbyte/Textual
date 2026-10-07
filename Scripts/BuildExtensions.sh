#!/bin/bash

set -e

echo "Building using architecture: ${ARCHS}"

TEXTUAL_PRODUCT_LOCATION="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
TEXTUAL_PRODUCT_BINARY="${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}"

# The plugins link against the app's binary (BUNDLE_LOADER), so they are
# built here, after the app has been linked, with one xcodebuild call that
# builds the "Bundled Extensions" scheme's five targets in parallel.
#
# They build into the app's products folder, where they find the frameworks
# and the generated headers and where the Copy Extensions phase picks them
# up; their intermediates stay in the app target's temp folder. The build is
# incremental: unchanged plugins are not relinked, so the copy phase skips
# them. A plugin that fails to build fails this phase and the whole build,
# so a stale bundle never ends up in a finished build.
xcodebuild -workspace "${TEXTUAL_WORKSPACE_DIR}/Textual.xcworkspace" \
    -scheme "Bundled Extensions" \
    -configuration "${CONFIGURATION}" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "${TARGET_TEMP_DIR}/Extensions" \
    ARCHS="${ARCHS}" \
    CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY}" \
    DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    CONFIGURATION_BUILD_DIR="${BUILT_PRODUCTS_DIR}" \
    TEXTUAL_WORKSPACE_DIR="${TEXTUAL_WORKSPACE_DIR}" \
    TEXTUAL_PRODUCT_LOCATION="${TEXTUAL_PRODUCT_LOCATION}" \
    TEXTUAL_PRODUCT_BINARY="${TEXTUAL_PRODUCT_BINARY}" \
    build

exit 0
