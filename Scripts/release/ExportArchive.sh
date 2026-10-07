#!/bin/sh

set -e

WORKING_PATH="${TEXTUAL_WORKSPACE_TEMP_DIR}/ArchiveTan"

mkdir -p "${WORKING_PATH}"

cd "${WORKING_PATH}"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

xcodebuild -exportArchive \
-exportOptionsPlist "${TEXTUAL_WORKSPACE_DIR}/Packaging/ExportArchiveConfiguration.plist" \
-archivePath "${ARCHIVE_PATH}" \
-exportPath "${WORKING_PATH}"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Zip product and send to notary
#
# Format to add notary to keychain:
#
# xcrun notarytool store-credentials "Textual Notary"
#	--apple-id "<e-mail address>"
#	--team-id <team id>
#	--password "<password>"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

WORKING_ZIP_PATH="./${FULL_PRODUCT_NAME}.zip"

zip -y -r -X "${WORKING_ZIP_PATH}" "./${FULL_PRODUCT_NAME}/"

xcrun notarytool submit "${WORKING_ZIP_PATH}" \
                   --keychain-profile "Textual Notary" \
                   --wait \
                   --verbose \
                   --progress

# Remove uploaded product
rm "${WORKING_ZIP_PATH}"

# Stable app
xcrun stapler staple --verbose "./${FULL_PRODUCT_NAME}/"

# Create new zip with stapled app

zip -y -r -X "${WORKING_ZIP_PATH}" "./${FULL_PRODUCT_NAME}/"

WORKING_ZIP_FILE_SIZE=$(stat -f%z "${WORKING_ZIP_PATH}")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

# Call `git` after `cd` into working path to make
# sure we are in a directory of a git repository.
GIT_COMMIT_HASH=`git rev-parse --short HEAD`

EXPORT_PATH_NAME="Textual-${GIT_COMMIT_HASH}"
EXPORT_PATH="${HOME}/Desktop/${EXPORT_PATH_NAME}"

mkdir -p "${EXPORT_PATH}"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

if [ "${TEXTUAL_BUILT_AS_UNIVERSAL_BINARY}" == "1" ]; then
	ARCHSPEC_TITLE="unviersal"
else
	ARCHSPEC_TITLE="intel"
fi

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

ARCHSPEC_PATH="${EXPORT_PATH}/${ARCHSPEC_TITLE}"
	
mkdir -p "${ARCHSPEC_PATH}"

ZIP_EXPORT_PATH="${ARCHSPEC_PATH}/Textual.zip"

mv "${WORKING_ZIP_PATH}" "${ZIP_EXPORT_PATH}"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

ONLINE_PATH_BASE="${EXPORT_PATH_NAME}/${ARCHSPEC_TITLE}/Textual"

ONLINE_DMG_PATH_STABLE="/textual/downloads/builds/stable/${ONLINE_PATH_BASE}.dmg"
ONLINE_ZIP_PATH_STABLE="/textual/downloads/builds/stable/${ONLINE_PATH_BASE}.zip"
ONLINE_ZIP_PATH_BETA="/textual/downloads/builds/beta/${ONLINE_PATH_BASE}.zip"

ONLINE_EXPORTER="cached.codeux.com"
ONLINE_EXPORTER_DMG_PATH_STABLE="https://${ONLINE_EXPORTER}${ONLINE_DMG_PATH_STABLE}"
ONLINE_EXPORTER_ZIP_PATH_STABLE="https://${ONLINE_EXPORTER}${ONLINE_ZIP_PATH_STABLE}"
ONLINE_EXPORTER_ZIP_PATH_BETA="https://${ONLINE_EXPORTER}${ONLINE_ZIP_PATH_BETA}"

BUNDLE_VERSION_LONG=$(/usr/libexec/PlistBuddy -c "Print \"CFBundleVersion\"" "./${FULL_PRODUCT_NAME}/Contents/Info.plist")
BUNDLE_VERSION_SHORT=$(/usr/libexec/PlistBuddy -c "Print \"CFBundleShortVersionString\"" "./${FULL_PRODUCT_NAME}/Contents/Info.plist")
BUNDLE_MINIMUM_TARGET=$(/usr/libexec/PlistBuddy -c "Print \"LSMinimumSystemVersion\"" "./${FULL_PRODUCT_NAME}/Contents/Info.plist")

ARCHIVE_DATE=$(date -R -u)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

echo "
# Stable
rewrite ^/textual/downloads/Textual\.zip$ /${ONLINE_ZIP_PATH_STABLE} break;
rewrite ^/textual/downloads/Textual\.dmg$ ${ONLINE_DMG_PATH_STABLE} break;
rewrite ^/textual/downloads/Textual-Universal\.dmg$ ${ONLINE_DMG_PATH_STABLE} break;
rewrite ^/textual/downloads/Textual7\.dmg$ ${ONLINE_DMG_PATH_STABLE} break;

# Stable Beta
rewrite ^/textual/downloads/Textual-Beta\.zip$ ${ONLINE_ZIP_PATH_STABLE} break;
rewrite ^/textual/downloads/Textual-Beta-Universal\.zip$ ${ONLINE_ZIP_PATH_STABLE} break;

# Beta
rewrite ^/textual/downloads/Textual-Beta\.zip$ ${ONLINE_ZIP_PATH_BETA} break;
rewrite ^/textual/downloads/Textual-Beta-Universal\.zip$ ${ONLINE_ZIP_PATH_BETA} break;
" > redirect.txt

mv "./redirect.txt" "${EXPORT_PATH}"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

echo "
		<!-- STABLE -->

		<item>
			<title>Version ${BUNDLE_VERSION_LONG}</title>
			<sparkle:releaseNotesLink>https://updates.textualapp.com/sparkle/release-notes/v7/feed-one.html</sparkle:releaseNotesLink>
			<sparkle:fullReleaseNotesLink>https://help.codeux.com/textual/Release-Notes.kb</sparkle:fullReleaseNotesLink>
			<pubDate>${ARCHIVE_DATE}</pubDate>
			<enclosure  url=\"${ONLINE_EXPORTER_ZIP_PATH_STABLE}\"
						sparkle:version=\"${BUNDLE_VERSION_LONG}\"
						sparkle:shortVersionString=\"${BUNDLE_VERSION_SHORT}\"
						length=\"${WORKING_ZIP_FILE_SIZE}\"
						type=\"application/octet-stream\" />
			<sparkle:minimumSystemVersion>${BUNDLE_MINIMUM_TARGET}</sparkle:minimumSystemVersion>
		</item>
		
		<!-- BETA -->

		<item>
			<title>Version ${BUNDLE_VERSION_LONG}</title>
			<sparkle:releaseNotesLink>https://updates.textualapp.com/sparkle/release-notes/v7/feed-one-beta.html</sparkle:releaseNotesLink>
			<sparkle:fullReleaseNotesLink>https://help.codeux.com/textual/Release-Notes.kb</sparkle:fullReleaseNotesLink>
			<sparkle:channel>beta</sparkle:channel>
			<pubDate>${ARCHIVE_DATE}</pubDate>
			<enclosure  url=\"${ONLINE_EXPORTER_ZIP_PATH_BETA}\"
						sparkle:version=\"${BUNDLE_VERSION_LONG}\"
						sparkle:shortVersionString=\"${BUNDLE_VERSION_SHORT}\"
						length=\"${WORKING_ZIP_FILE_SIZE}\"
						type=\"application/octet-stream\" />
			<sparkle:minimumSystemVersion>${BUNDLE_MINIMUM_TARGET}</sparkle:minimumSystemVersion>
		</item>
" > sparkle.txt

mv "./sparkle.txt" "${EXPORT_PATH}"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

echo "<section class=\"main\">
	<section class=\"header\">Release Notes for ${BUNDLE_VERSION_LONG}</section>

	<section class=\"body\">

		<ul>" > ./buildLog.txt

git log --since='48 hours ago' --pretty=format:'			<li>%s</li>' >> ./buildLog.txt

echo "
		</ul>

	</section>
</section>

<!-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ -->" >> ./buildLog.txt

mv "./buildLog.txt" "${EXPORT_PATH}"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

cd "${DWARF_DSYM_FOLDER_PATH}"

DYSM_EXPORT_PATH="${ARCHSPEC_PATH}/Debug symbols.zip"

zip -y -r -X "${DYSM_EXPORT_PATH}" *

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

rm -rf "${WORKING_PATH}"

exit 0;
