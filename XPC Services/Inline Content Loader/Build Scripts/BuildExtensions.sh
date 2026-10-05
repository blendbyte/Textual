#!/bin/sh

set -e

# Start from an empty staging folder so an extension that failed to build
# can never be replaced by a stale copy from an earlier build.
rm -rf "${TEXTUAL_WORKSPACE_TEMP_DIR:?}/SharedBuildProducts-ICLExtension"

ICL_PRODUCT_LOCATION="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
ICL_PRODUCT_BINARY="${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}"

# Core Media
cd "${PROJECT_DIR}/Extensions/Core Media/"

xcodebuild -target "Inline Content Loader Core Media" \
 -configuration "${ICL_EXTENSION_BUILD_SCHEME}" \
 ARCHS="${ARCHS}" \
 CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY}" \
 DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
 PROVISIONING_PROFILE_SPECIFIER="" \
 TEXTUAL_WORKSPACE_DIR="${TEXTUAL_WORKSPACE_DIR}" \
 TEXTUAL_PRODUCT_LOCATION="${TEXTUAL_PRODUCT_LOCATION}" \
 ICL_PRODUCT_LOCATION="${ICL_PRODUCT_LOCATION}" \
 ICL_PRODUCT_BINARY="${ICL_PRODUCT_BINARY}"

exit 0;
