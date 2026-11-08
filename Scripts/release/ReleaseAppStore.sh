#!/bin/bash

set -euo pipefail

# Builds the Mac App Store edition of the release Release.sh just made, from
# the same commit and with the same build number, and uploads it:
#
#   1. archives the "Textual (App Store)" scheme
#   2. exports an installer package with the "Textual 8 App Store" profile
#   3. checks the package: installer signature, application identifier,
#      build number, no Sparkle
#   4. uploads it to App Store Connect (with --upload)
#
#   Scripts/release/ReleaseAppStore.sh [--upload]
#
# Needs, on this Mac: the Apple Distribution and Mac Installer Distribution
# certificates and the "Textual 8 App Store" provisioning profile. --upload
# also needs an App Store Connect API key, given by TEXTUAL_ASC_KEY_ID,
# TEXTUAL_ASC_ISSUER_ID and TEXTUAL_ASC_KEY_FILE. Run it on the commit Release.sh
# tagged. Output goes to "$TEXTUAL_RELEASE_DIR" (default ~/Textual Releases).

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

TEAM_ID="FANJ7JNLP5"
BUNDLE_ID="com.textualapp.app"
APP_IDENTITY="Apple Distribution: Blendbyte GmbH (${TEAM_ID})"
INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Blendbyte GmbH (${TEAM_ID})"
PROFILE_NAME="Textual 8 App Store"
VERSION_FILE="${ROOT}/Configurations/Version.xcconfig"

upload=0

while [ $# -gt 0 ]; do
	case "$1" in
		--upload) upload=1 ;;
		*) echo "Usage: $0 [--upload]" >&2; exit 2 ;;
	esac

	shift
done

step() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nerror: %s\n' "$*" >&2; exit 1; }

cd "${ROOT}"

step "Checking what the App Store build needs"

security find-identity -v | grep -qF "${APP_IDENTITY}" ||
	fail "The certificate \"${APP_IDENTITY}\" is not in the Keychain"

security find-identity -v | grep -qF "${INSTALLER_IDENTITY}" ||
	fail "The certificate \"${INSTALLER_IDENTITY}\" is not in the Keychain"

profileFound=0

for profile in "${HOME}/Library/Developer/Xcode/UserData/Provisioning Profiles/"*.provisionprofile; do
	[ -f "${profile}" ] || continue

	if security cms -D -i "${profile}" 2> /dev/null | plutil -extract Name raw -o - - 2> /dev/null | grep -qxF "${PROFILE_NAME}"; then
		profileFound=1
	fi
done

[ "${profileFound}" = 1 ] || fail "The provisioning profile \"${PROFILE_NAME}\" is not installed (~/Library/Developer/Xcode/UserData/Provisioning Profiles)"

if [ "${upload}" = 1 ]; then
	[ -n "${TEXTUAL_ASC_KEY_ID:-}" ] && [ -n "${TEXTUAL_ASC_ISSUER_ID:-}" ] && [ -f "${TEXTUAL_ASC_KEY_FILE:-}" ] ||
		fail "--upload needs TEXTUAL_ASC_KEY_ID, TEXTUAL_ASC_ISSUER_ID and TEXTUAL_ASC_KEY_FILE"
fi

[ -z "$(git status --porcelain)" ] || fail "The working tree has uncommitted changes"

build=$(sed -n 's/^CURRENT_PROJECT_VERSION = //p' "${VERSION_FILE}")
version=$(sed -n 's/^MARKETING_VERSION = //p' "${VERSION_FILE}")
tag="v${version}-${build}"

# Later changes to the release scripts themselves don't matter
git rev-parse -q --verify "refs/tags/${tag}" > /dev/null || fail "There is no tag ${tag}; run Release.sh first"

git diff --quiet "${tag}" HEAD -- . ':(exclude)Scripts/release' || fail "HEAD differs from the release ${tag}"

output="${TEXTUAL_RELEASE_DIR:-${HOME}/Textual Releases}/${version} (${build})/App Store"

rm -rf "${output}"
mkdir -p "${output}"

work="$(mktemp -d -t TextualAppStore)"

trap 'rm -rf "${work}"' EXIT

echo "Textual ${version} (${build}), App Store → ${output}"

step "Archiving the App Store build"

xcodebuild archive \
	-workspace "${ROOT}/Textual.xcworkspace" \
	-scheme "Textual (App Store)" \
	-configuration "App Store" \
	-destination "generic/platform=macOS" \
	-archivePath "${work}/Textual.xcarchive" \
	-derivedDataPath "${work}/DerivedData" \
	-quiet > "${output}/archive.log" 2>&1 ||
	fail "The archive failed; see ${output}/archive.log"

step "Exporting the installer package"

cat > "${work}/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>export</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>signingCertificate</key>
	<string>Apple Distribution</string>
	<key>installerSigningCertificate</key>
	<string>${INSTALLER_IDENTITY}</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>${BUNDLE_ID}</key>
		<string>${PROFILE_NAME}</string>
	</dict>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
	-archivePath "${work}/Textual.xcarchive" \
	-exportOptionsPlist "${work}/ExportOptions.plist" \
	-exportPath "${work}/Export" > "${output}/export.log" 2>&1 ||
	fail "The export failed; see ${output}/export.log"

package="${work}/Export/Textual.pkg"

[ -f "${package}" ] || fail "The export has no Textual.pkg"

step "Checking the package"

pkgutil --check-signature "${package}" | grep -qF "${INSTALLER_IDENTITY}" ||
	fail "The package is not signed with \"${INSTALLER_IDENTITY}\""

pkgutil --expand-full "${package}" "${work}/Expanded" > /dev/null

app=$(find "${work}/Expanded" -type d -name Textual.app -prune | head -n 1)

[ -n "${app}" ] || fail "The package has no Textual.app"

codesign --verify --deep --strict "${app}" || fail "The app's signature does not verify"

# (PlistBuddy: plutil reads the dots in the key as a path)
codesign -d --entitlements - --xml "${app}" > "${work}/entitlements.plist" 2> /dev/null || true

appIdentifier=$(/usr/libexec/PlistBuddy -c "Print :com.apple.application-identifier" "${work}/entitlements.plist" 2> /dev/null || true)

[ "${appIdentifier}" = "${TEAM_ID}.${BUNDLE_ID}" ] ||
	fail "The app is not signed with the provisioning profile (application identifier \"${appIdentifier}\")"

[ "$(plutil -extract CFBundleVersion raw -o - "${app}/Contents/Info.plist")" = "${build}" ] ||
	fail "The app does not have build ${build}"

[ ! -e "${app}/Contents/Frameworks/Sparkle.framework" ] || fail "The App Store build contains Sparkle"

cp "${package}" "${output}/Textual-${version}-${build}.pkg"

if [ "${upload}" = 1 ]; then
	step "Uploading to App Store Connect"

	xcrun altool --upload-package "${output}/Textual-${version}-${build}.pkg" \
		--api-key "${TEXTUAL_ASC_KEY_ID}" \
		--api-issuer "${TEXTUAL_ASC_ISSUER_ID}" \
		--p8-file-path "${TEXTUAL_ASC_KEY_FILE}" > "${output}/upload.log" 2>&1 ||
		fail "The upload failed; see ${output}/upload.log"
fi

step "Done"

ls -1 "${output}"
