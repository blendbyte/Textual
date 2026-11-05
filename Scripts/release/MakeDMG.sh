#!/bin/bash

set -euo pipefail

# The download disk image: Textual.app and an Applications link on the
# background picture, with a Read Me and two links below them, the app's icon
# on the volume, the agreement shown before it opens, compressed and signed.
# Used by Release.sh; can be run on its own to try the layout.
#
#   Scripts/release/MakeDMG.sh <Textual.app> <version> <output.dmg> <terms.rtf> [<signing identity>]
#
# FetchTerms.sh makes the terms file.
#
# The window settings (.DS_Store) are written by dmgbuild, not by Finder:
# Finder through AppleScript saved them only sometimes on macOS 27, and needs
# a logged-in session and permission to be controlled.

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

source "${ROOT}/Scripts/release/ReleaseTools.sh"

app="$1"
version="$2"
dmg="$3"
terms="$4"
identity="${5:-}"

BACKGROUND="${ROOT}/Packaging/DMGBackground.png"
READ_ME="${ROOT}/Packaging/Read Me.txt"

work="$(mktemp -d -t TextualDMG)"

trap 'rm -rf "${work}"' EXIT

python="$(release_python)"

# The picture (Packaging/DMGBackground.swift draws it) is 1000 × 960 pixels for
# a 500 × 480 point window: dmgbuild makes a two-size TIFF of it and its @2x
# partner, sharp on both kinds of screen
sips -z 480 500 "${BACKGROUND}" --out "${work}/background.png" > /dev/null
cp "${BACKGROUND}" "${work}/background@2x.png"

# Links open in the browser; the same addresses as TXWebsiteLinks.h
make_link() {
	plutil -create xml1 "$1"
	plutil -insert URL -string "$2" "$1"
}

whats_new="${work}/What's New in Textual 8.webloc"
website="${work}/Textual Website.webloc"

make_link "${whats_new}" "https://www.textualapp.com/docs/release-notes/textual-8"
make_link "${website}" "https://www.textualapp.com"

cat > "${work}/settings.py" <<EOF
import os.path

application = defines["app"]

files = [application, defines["read_me"], defines["whats_new"], defines["website"]]
hide_extensions = [os.path.basename(defines["whats_new"]), os.path.basename(defines["website"])]
symlinks = {"Applications": "/Applications"}

icon = os.path.join(application, "Contents/Resources/applicationIcon.icns")

icon_locations = {
	os.path.basename(application): (120, 238),
	"Applications": (380, 238),
	os.path.basename(defines["read_me"]): (120, 392),
	os.path.basename(defines["whats_new"]): (250, 392),
	os.path.basename(defines["website"]): (380, 392),
}

background = defines["background"]

window_rect = ((200, 300), (500, 512)) # From the screen's bottom left; the title bar takes 32 of the height
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False

arrange_by = None
icon_size = 96
text_size = 13
label_pos = "bottom"

format = "ULFO"
filesystem = "HFS+"

license = {"default-language": "en_US", "licenses": {"en_US": defines["terms"]}}
EOF

rm -f "${dmg}"

"${python}" -m dmgbuild \
	-s "${work}/settings.py" \
	-D app="${app}" \
	-D background="${work}/background.png" \
	-D read_me="${READ_ME}" \
	-D whats_new="${whats_new}" \
	-D website="${website}" \
	-D terms="${terms}" \
	"Textual ${version}" \
	"${dmg}" > "${work}/dmgbuild.log" 2>&1 || { cat "${work}/dmgbuild.log" >&2; echo "error: dmgbuild failed" >&2; exit 1; }

if [ -n "${identity}" ]; then
	codesign --sign "${identity}" --timestamp "${dmg}"
fi
