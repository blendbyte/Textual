#!/bin/bash

set -euo pipefail

# Builds a release of the direct-download Textual and everything the website
# needs for it, in one go:
#
#   1. raises the build number (Configurations/Version.xcconfig)
#   2. archives the Release build and exports it signed with Developer ID and
#      the "Textual Developer ID" provisioning profile
#   3. notarizes and staples the app
#   4. the Sparkle zip (ditto), signed with the update key (sign_update)
#   5. the DMG (MakeDMG.sh, dmgbuild), signed, notarized and stapled
#   6. release.json, the handover for the website's appcast generator
#   7. commits the build number and tags the release (locally; push yourself)
#
#   Scripts/release/Release.sh [--beta] [--license-manager on|off] [--test]
#
#   --beta              the update is offered only to "Enable beta updates"
#   --license-manager   build with or without the licence manager (default:
#                       as configured in Configurations/)
#   --test              a trial run: no new build number, no notarization, no
#                       commit, and a dirty working tree is allowed
#
# Needs, on this Mac: the "Developer ID Application: Blendbyte GmbH"
# certificate, the "Textual Developer ID" provisioning profile, the notarytool
# profile "Textual Notary" and the Sparkle update key in the login Keychain
# (account "textual"). Output goes to "$TEXTUAL_RELEASE_DIR" (default
# ~/Textual Releases).

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

TEAM_ID="FANJ7JNLP5"
BUNDLE_ID="com.textualapp.app"
SIGNING_IDENTITY="Developer ID Application: Blendbyte GmbH (${TEAM_ID})"
PROFILE_NAME="Textual Developer ID"
NOTARY_PROFILE="Textual Notary"
SPARKLE_ACCOUNT="textual"
SIGN_UPDATE="${ROOT}/Frameworks/Vendor/Sparkle/bin/sign_update"
VERSION_FILE="${ROOT}/Configurations/Version.xcconfig"

channel=""
licenseManager=""
testRun=0

while [ $# -gt 0 ]; do
	case "$1" in
		--beta) channel="beta" ;;
		--license-manager) shift; licenseManager="${1:-}" ;;
		--test) testRun=1 ;;
		*) echo "Usage: $0 [--beta] [--license-manager on|off] [--test]" >&2; exit 2 ;;
	esac

	shift
done

step() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nerror: %s\n' "$*" >&2; exit 1; }

cd "${ROOT}"

# Preconditions

step "Checking what the release needs"

security find-identity -v -p codesigning | grep -qF "${SIGNING_IDENTITY}" ||
	fail "The certificate \"${SIGNING_IDENTITY}\" is not in the Keychain"

profileFound=0

for profile in "${HOME}/Library/Developer/Xcode/UserData/Provisioning Profiles/"*.provisionprofile; do
	[ -f "${profile}" ] || continue

	if security cms -D -i "${profile}" 2> /dev/null | plutil -extract Name raw -o - - 2> /dev/null | grep -qxF "${PROFILE_NAME}"; then
		profileFound=1
	fi
done

[ "${profileFound}" = 1 ] || fail "The provisioning profile \"${PROFILE_NAME}\" is not installed (~/Library/Developer/Xcode/UserData/Provisioning Profiles)"

[ -x "${SIGN_UPDATE}" ] || fail "${SIGN_UPDATE} is missing"

if [ "${testRun}" = 0 ]; then
	xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" > /dev/null 2>&1 ||
		fail "The notarytool profile \"${NOTARY_PROFILE}\" is missing (xcrun notarytool store-credentials)"

	[ -z "$(git status --porcelain)" ] || fail "The working tree has uncommitted changes"
fi

# Build number

currentBuild=$(sed -n 's/^CURRENT_PROJECT_VERSION = //p' "${VERSION_FILE}")
version=$(sed -n 's/^MARKETING_VERSION = //p' "${VERSION_FILE}")

[[ "${currentBuild}" =~ ^[0-9]+$ ]] || fail "No CURRENT_PROJECT_VERSION in ${VERSION_FILE}"
[ -n "${version}" ] || fail "No MARKETING_VERSION in ${VERSION_FILE}"

if [ "${testRun}" = 1 ]; then
	build="${currentBuild}"
else
	build=$((currentBuild + 1))

	sed -i '' "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = ${build}/" "${VERSION_FILE}"
fi

name="Textual-${version}-${build}"

output="${TEXTUAL_RELEASE_DIR:-${HOME}/Textual Releases}/${version} (${build})"

[ "${testRun}" = 1 ] && output="${output} test"

rm -rf "${output}"
mkdir -p "${output}"

work="$(mktemp -d -t TextualRelease)"

released=0

# A failed release leaves the build number as it was; the work folder goes
cleanUp() {
	if [ "${testRun}" = 0 ] && [ "${released}" = 0 ]; then
		git -C "${ROOT}" checkout -- "${VERSION_FILE}"
	fi

	rm -rf "${work}"
}

trap cleanUp EXIT

echo "Textual ${version} (${build})${channel:+, ${channel} channel} → ${output}"

# Archive

step "Archiving the Release build"

buildSettings=()

case "${licenseManager}" in
	on) buildSettings+=("TEXTUAL_BUILT_WITH_LICENSE_MANAGER=1") ;;
	off) buildSettings+=("TEXTUAL_BUILT_WITH_LICENSE_MANAGER=0") ;;
	"") ;;
	*) fail "--license-manager takes on or off" ;;
esac

xcodebuild archive \
	-workspace "${ROOT}/Textual.xcworkspace" \
	-scheme "Textual (Release)" \
	-configuration Release \
	-destination "generic/platform=macOS" \
	-archivePath "${work}/Textual.xcarchive" \
	-derivedDataPath "${work}/DerivedData" \
	-quiet \
	${buildSettings[@]+"${buildSettings[@]}"} > "${output}/archive.log" 2>&1 ||
	fail "The archive failed; see ${output}/archive.log"

# Export with Developer ID

step "Exporting with Developer ID"

cat > "${work}/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>signingCertificate</key>
	<string>Developer ID Application</string>
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

app="${work}/Export/Textual.app"

[ -d "${app}" ] || fail "The export has no Textual.app"

codesign --verify --deep --strict "${app}" || fail "The exported app's signature does not verify"

# (PlistBuddy: plutil reads the dots in the key as a path)
codesign -d --entitlements - --xml "${app}" > "${work}/entitlements.plist" 2> /dev/null || true

appIdentifier=$(/usr/libexec/PlistBuddy -c "Print :com.apple.application-identifier" "${work}/entitlements.plist" 2> /dev/null || true)

[ "${appIdentifier}" = "${TEAM_ID}.${BUNDLE_ID}" ] ||
	fail "The app is not signed with the provisioning profile (application identifier \"${appIdentifier}\")"

exportedBuild=$(plutil -extract CFBundleVersion raw -o - "${app}/Contents/Info.plist")
minimumSystem=$(plutil -extract LSMinimumSystemVersion raw -o - "${app}/Contents/Info.plist")

[ "${exportedBuild}" = "${build}" ] || fail "The app has build ${exportedBuild}, expected ${build}"

# Notarize the app

notarize() {
	local file="$1"

	xcrun notarytool submit "${file}" --keychain-profile "${NOTARY_PROFILE}" --wait --output-format json > "${work}/notary.json" ||
		fail "Notarization of $(basename "${file}") failed"

	local status

	status=$(plutil -extract status raw -o - "${work}/notary.json" 2> /dev/null || echo "unknown")

	if [ "${status}" != "Accepted" ]; then
		local submission

		submission=$(plutil -extract id raw -o - "${work}/notary.json" 2> /dev/null || echo "")

		[ -n "${submission}" ] && xcrun notarytool log "${submission}" --keychain-profile "${NOTARY_PROFILE}" "${output}/notary-$(basename "${file}").log" > /dev/null 2>&1 || true

		fail "Notarization of $(basename "${file}") returned \"${status}\" (log in ${output})"
	fi
}

if [ "${testRun}" = 0 ]; then
	step "Notarizing the app"

	ditto -c -k --keepParent "${app}" "${work}/notarize.zip"

	notarize "${work}/notarize.zip"

	xcrun stapler staple "${app}" > /dev/null || fail "Stapling the app failed"

	spctl --assess --type execute "${app}" || fail "Gatekeeper does not accept the notarized app"
else
	step "Skipping notarization (--test)"
fi

# The Sparkle zip: made once, signed once, never changed afterwards

step "Making and signing the update zip"

zip="${output}/${name}.zip"

ditto -c -k --sequesterRsrc --keepParent "${app}" "${zip}"

signature=$("${SIGN_UPDATE}" --account "${SPARKLE_ACCOUNT}" -p "${zip}") ||
	fail "Signing the zip with the Sparkle key failed (Keychain account \"${SPARKLE_ACCOUNT}\")"

"${SIGN_UPDATE}" --account "${SPARKLE_ACCOUNT}" --verify "${zip}" "${signature}" > /dev/null 2>&1 ||
	fail "The zip's Sparkle signature does not verify"

zipSize=$(stat -f %z "${zip}")

# The DMG: the app and an Applications link on the background picture

step "Making the disk image"

dmg="${output}/${name}.dmg"

"${ROOT}/Scripts/release/MakeDMG.sh" "${app}" "${version}" "${dmg}" "${SIGNING_IDENTITY}" ||
	fail "Making the disk image failed"

if [ "${testRun}" = 0 ]; then
	step "Notarizing the disk image"

	notarize "${dmg}"

	xcrun stapler staple "${dmg}" > /dev/null || fail "Stapling the disk image failed"
fi

# Handover for the website's appcast generator

step "Writing release.json"

publishedDate=$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")

cat > "${output}/release.json" <<EOF
{
	"version": "${build}",
	"shortVersionString": "${version}",
	"channel": "${channel}",
	"minimumSystemVersion": "${minimumSystem}",
	"pubDate": "${publishedDate}",
	"zip": {
		"file": "$(basename "${zip}")",
		"length": ${zipSize},
		"edSignature": "${signature}",
		"sha256": "$(shasum -a 256 "${zip}" | cut -d ' ' -f 1)"
	},
	"dmg": {
		"file": "$(basename "${dmg}")",
		"length": $(stat -f %z "${dmg}"),
		"sha256": "$(shasum -a 256 "${dmg}" | cut -d ' ' -f 1)"
	},
	"notarized": $([ "${testRun}" = 0 ] && echo true || echo false),
	"commit": "$(git -C "${ROOT}" rev-parse HEAD)"
}
EOF

plutil -convert xml1 -o /dev/null "${output}/release.json" || fail "release.json is not valid JSON"

# Build number and tag

if [ "${testRun}" = 0 ]; then
	released=1

	step "Committing build ${build} and tagging v${version}-${build}"

	git -C "${ROOT}" commit -q -m "Build ${build} (${version}${channel:+ ${channel}})" -- "${VERSION_FILE}"
	git -C "${ROOT}" tag "v${version}-${build}"

	echo "Push when the release is published: git push && git push origin v${version}-${build}"
fi

step "Done"

echo "${output}"
ls -1 "${output}"
