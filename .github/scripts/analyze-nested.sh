#!/bin/bash
#
# Runs the static analyzer on the bundled plugins.
#
# The app's build scripts build them with a nested xcodebuild call, which an
# "xcodebuild analyze" of the app only builds, never analyzes. Run this after
# the app has been built or analyzed: it needs the app's binary, and the
# frameworks and generated headers in the app's products folder.
#
# Usage: analyze-nested.sh <app bundle> <folder for the result bundles>

set -euo pipefail

app="$1"
results="$2"

workspace="$(cd "$(dirname "$0")/../.." && pwd)"
binary="${app}/Contents/MacOS/Textual"
products="$(cd "$(dirname "${app}")" && pwd)"

[ -x "${binary}" ] || { echo "No app binary at ${binary}" >&2; exit 1; }

mkdir -p "${results}"

# The "Bundled Extensions" scheme, as the app's build scripts build it.
# One architecture is enough for the analyzer, and matches the shared
# frameworks whether they were built universal or for arm64 only.
xcodebuild analyze \
	-workspace "${workspace}/Textual.xcworkspace" \
	-scheme "Bundled Extensions" \
	-configuration Release \
	-destination "generic/platform=macOS" \
	-derivedDataPath "${results}/DerivedData" \
	-resultBundlePath "${results}/plugins.xcresult" \
	-quiet \
	ARCHS=arm64 \
	CODE_SIGN_IDENTITY="-" \
	CODE_SIGNING_REQUIRED=NO \
	CODE_SIGNING_ALLOWED=NO \
	DEVELOPMENT_TEAM="" \
	PROVISIONING_PROFILE_SPECIFIER="" \
	CONFIGURATION_BUILD_DIR="${products}" \
	TEXTUAL_WORKSPACE_DIR="${workspace}" \
	TEXTUAL_PRODUCT_LOCATION="${app}" \
	TEXTUAL_PRODUCT_BINARY="${binary}"
