#!/bin/bash

set -e

echo "Building using architecture: ${ARCHS}"

TEXTUAL_PRODUCT_LOCATION="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
TEXTUAL_PRODUCT_BINARY="${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}"

# Folder names and the bundles they build
plugins=(
    'Chat Filter:Chat Filters'
    'Smiley Converter:Smiley Converter'
    'System Profiler:System Info'
    'User Insights:User Insights'
    'ZNC Additions:ZNC Additions'
)

# The plugins build into the app's products folder, where they find the
# frameworks and the generated headers and where the Copy Extensions phase
# picks them up. Their intermediates stay in the app's build folder.
# Remove the old bundles first, so a plugin that failed to build can never
# be replaced by a stale copy from an earlier build.
for entry in "${plugins[@]}"; do
    rm -rf "${BUILT_PRODUCTS_DIR:?}/${entry#*:}.bundle"
done

for entry in "${plugins[@]}"; do
    plugin="${entry%%:*}"

    cd "${TEXTUAL_WORKSPACE_DIR}/Plugins/${plugin}"
    xcodebuild -target "$plugin Extension" \
        -configuration "${CONFIGURATION}" \
        ARCHS="${ARCHS}" \
        CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY}" \
        DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
        PROVISIONING_PROFILE_SPECIFIER="" \
        SYMROOT="${TARGET_TEMP_DIR}/Extensions" \
        OBJROOT="${TARGET_TEMP_DIR}/Extensions" \
        CONFIGURATION_BUILD_DIR="${BUILT_PRODUCTS_DIR}" \
        TEXTUAL_WORKSPACE_DIR="${TEXTUAL_WORKSPACE_DIR}" \
        TEXTUAL_PRODUCT_LOCATION="${TEXTUAL_PRODUCT_LOCATION}" \
        TEXTUAL_PRODUCT_BINARY="${TEXTUAL_PRODUCT_BINARY}"

done

exit 0
