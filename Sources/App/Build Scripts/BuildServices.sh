#!/bin/bash

set -e

echo "Building using architecture: ${ARCHS}"

# Start from an empty staging folder so a service that failed to build
# can never be replaced by a stale copy from an earlier build.
rm -rf "${TEXTUAL_WORKSPACE_TEMP_DIR:?}/SharedBuildProducts-XPCServices"

TEXTUAL_PRODUCT_LOCATION="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
TEXTUAL_PRODUCT_BINARY="${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}"

services=(
    'Historic Log File Manager'
    'Inline Content Loader'
    'IRC Remote Connection Manager'
)

for service in "${services[@]}"; do
    cd "${TEXTUAL_WORKSPACE_DIR}/XPC Services/${service}/"

    xcodebuild -target "$service" \
        -configuration "${TEXTUAL_XPC_SERVICE_BUILD_SCHEME}" \
        ARCHS="${ARCHS}" \
        CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY}" \
        DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
        PROVISIONING_PROFILE_SPECIFIER="" \
        TEXTUAL_WORKSPACE_DIR="${TEXTUAL_WORKSPACE_DIR}" \
        TEXTUAL_PRODUCT_LOCATION="${TEXTUAL_PRODUCT_LOCATION}" \
        TEXTUAL_PRODUCT_BINARY="${TEXTUAL_PRODUCT_BINARY}"
done
