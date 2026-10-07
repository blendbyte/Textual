#!/bin/bash
#
# Runs the static analyzer on the XPC services and the bundled plugins.
#
# The app's build scripts build them with nested xcodebuild calls, which an
# "xcodebuild analyze" of the app only builds, never analyzes. Run this after
# the app has been built or analyzed (it needs the app's binary, the shared
# headers in .tmp and the built services).
#
# Usage: analyze-nested.sh <app bundle> <folder for the result bundles>

set -euo pipefail

app="$1"
results="$2"

workspace="$(cd "$(dirname "$0")/../.." && pwd)"
binary="${app}/Contents/MacOS/Textual"

[ -x "${binary}" ] || { echo "No app binary at ${binary}" >&2; exit 1; }

mkdir -p "${results}"

# One architecture is enough for the analyzer, and matches the shared
# frameworks whether they were built universal or for arm64 only
common_settings=(
	-configuration Release
	ARCHS=arm64
	CODE_SIGN_IDENTITY="-"
	CODE_SIGNING_REQUIRED=NO
	CODE_SIGNING_ALLOWED=NO
	DEVELOPMENT_TEAM=""
	PROVISIONING_PROFILE_SPECIFIER=""
	TEXTUAL_WORKSPACE_DIR="${workspace}"
	TEXTUAL_PRODUCT_LOCATION="${app}"
	TEXTUAL_PRODUCT_BINARY="${binary}"
)

analyze() {
	local folder="$1" target="$2" name="$3"
	shift 3

	echo "Analyzing ${target}"

	(cd "${workspace}/${folder}" &&
		xcodebuild analyze -target "${target}" -quiet \
			-resultBundlePath "${results}/${name}.xcresult" \
			"${common_settings[@]}" "$@")
}

analyze "XPC Services/Inline Content Loader" "Inline Content Loader" "inline-content-loader"

loader="${workspace}/.tmp/SharedBuildProducts-XPCServices/Inline Content Loader.xpc"

analyze "XPC Services/Inline Content Loader/Extensions/Core Media" "Inline Content Loader Core Media" "core-media" \
	ICL_PRODUCT_LOCATION="${loader}" \
	ICL_PRODUCT_BINARY="${loader}/Contents/MacOS/Inline Content Loader"

for plugin in 'Caffeine' 'Chat Filter' 'Smiley Converter' 'System Profiler' 'User Insights' 'ZNC Additions'; do
	analyze "Sources/Plugins/${plugin}" "${plugin} Extension" "plugin-$(echo "${plugin}" | tr ' A-Z' '-a-z')"
done
