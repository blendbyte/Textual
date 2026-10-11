#!/bin/bash

set -e

# Builds Acknowledgements.plist, which the app's Acknowledgements window shows,
# from Acknowledgements/Components.txt, and fails when something that needs a
# notice has no entry there:
#
#   - a licence or copyright file under Frameworks/, App/Resources/ or Plugins/
#   - a file in App/Sources/Vendor/
#   - a bundled style
#   - a third-party component (kind "code") missing from README.md
#
#   GenerateAcknowledgements.sh            build phase: writes the plist into the app
#   GenerateAcknowledgements.sh --check    only the checks (CI, or by hand)

ROOT="${TEXTUAL_WORKSPACE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
MANIFEST="${ROOT}/Acknowledgements/Components.txt"

cd "${ROOT}"

fail() {
	echo "error: Acknowledgements: $1" >&2

	exit 1
}

trim() {
	local value="$1"

	value="${value#"${value%%[![:space:]]*}"}"
	value="${value%"${value##*[![:space:]]}"}"

	printf '%s' "${value}"
}

kinds=()
titles=()
noticeFiles=()
builds=()

referenced=$'\n'

while IFS='|' read -r kind title files build covers; do
	kind=$(trim "${kind}")

	[ -z "${kind}" ] && continue
	[ "${kind:0:1}" = "#" ] && continue

	title=$(trim "${title}")
	build=$(trim "${build}")

	case "${kind}" in
		textual|code|style|assets) ;;
		*) fail "unknown kind \"${kind}\" for ${title}" ;;
	esac

	case "${build}" in
		all|direct) ;;
		*) fail "unknown build \"${build}\" for ${title}" ;;
	esac

	entryFiles=""

	IFS=';' read -ra parts <<< "${files}"

	for part in "${parts[@]}"; do
		part=$(trim "${part}")

		[ -z "${part}" ] && continue

		[ -f "${part}" ] || fail "${title}: ${part} does not exist"

		entryFiles+="${part}"$'\n'
		referenced+="${part}"$'\n'
	done

	[ -n "${entryFiles}" ] || fail "${title} has no notice file"

	IFS=';' read -ra parts <<< "${covers}"

	for part in "${parts[@]}"; do
		part=$(trim "${part}")

		[ -z "${part}" ] && continue

		[ -f "${part}" ] || fail "${title}: covered file ${part} does not exist"

		referenced+="${part}"$'\n'
	done

	if [ "${kind}" = "code" ] && ! grep -qF "${title}" README.md; then
		fail "${title} is missing from the third-party table in README.md"
	fi

	kinds+=("${kind}")
	titles+=("${title}")
	noticeFiles+=("${entryFiles}")
	builds+=("${build}")
done < "${MANIFEST}"

isReferenced() {
	[[ "${referenced}" == *$'\n'"$1"$'\n'* ]]
}

# Licence and copyright files
while IFS= read -r path; do
	isReferenced "${path#./}" || fail "${path#./} has no entry in Acknowledgements/Components.txt"
done < <(find ./LICENSE ./Frameworks ./App/Resources ./Plugins \
	-path '*.framework' -prune -o \
	-type f \( -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname 'NOTICE*' -o -iname 'COPYRIGHT*' -o -iname 'ACKNOWLEDGEMENT*' \) -print)

# Vendored source files
while IFS= read -r path; do
	isReferenced "${path#./}" || fail "${path#./} (vendored) has no entry in Acknowledgements/Components.txt"
done < <(find ./App/Sources/Vendor -type f)

# Bundled styles
for style in "App/Resources/Styling/Bundled Styles/"*/; do
	[[ "${referenced}" == *$'\n'"${style}"* ]] || fail "the bundled style ${style} has no entry in Acknowledgements/Components.txt"
done

if [ "$1" = "--check" ]; then
	echo "Acknowledgements: ${#titles[@]} entries, nothing missing."

	exit 0
fi

# A notice file as shown: notices copied from source code lose their comment
# markers ("/*", " * ", "*/" and lines of asterisks), the wording stays
notice() {
	if grep -q '^[[:space:]]*/\*' "$1"; then
		sed -E 's#^[[:space:]*/]+$##; s#^/\*+ ?##; s#^ ?\* ?##' "$1" | cat -s
	else
		cat "$1"
	fi
}

# Acknowledgements.plist: { entries = ( { title, text }, … ) }
output="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/Acknowledgements.plist"

temporary=$(mktemp -t Acknowledgements)

plutil -create xml1 "${temporary}"
plutil -insert entries -array "${temporary}"

index=0

for i in "${!titles[@]}"; do
	# Sparkle is not in the App Store build
	if [ "${builds[$i]}" = "direct" ] && [ "${TEXTUAL_BUILD_SCHEME_TOKEN}" = "appstore" ]; then
		continue
	fi

	text=""

	while IFS= read -r path; do
		[ -z "${path}" ] && continue

		[ -n "${text}" ] && text+=$'\n\n'

		text+="$(notice "${path}")"
	done <<< "${noticeFiles[$i]}"

	plutil -insert entries -dictionary -append "${temporary}"
	plutil -insert "entries.${index}.title" -string "${titles[$i]}" "${temporary}"
	plutil -insert "entries.${index}.text" -string "${text}" "${temporary}"

	index=$((index + 1))
done

# mktemp makes it readable by its owner only
chmod 644 "${temporary}"

mkdir -p "$(dirname "${output}")"

mv -f "${temporary}" "${output}"

echo "Acknowledgements: wrote ${index} entries to Acknowledgements.plist."
