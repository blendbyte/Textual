#!/bin/bash

set -euo pipefail

# The download disk image: Textual.app and an Applications link on the
# background picture, compressed and signed. Used by Release.sh; can be run on
# its own to try the layout.
#
#   Scripts/release/MakeDMG.sh <Textual.app> <version> <output.dmg> [<signing identity>]
#
# The window settings (.DS_Store) are written by dmgbuild, not by Finder:
# Finder through AppleScript saved them only sometimes on macOS 27, and needs
# a logged-in session and permission to be controlled.

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

source "${ROOT}/Scripts/release/ReleaseTools.sh"

app="$1"
version="$2"
dmg="$3"
identity="${4:-}"

BACKGROUND="${ROOT}/Packaging/DMGBackground.png"

work="$(mktemp -d -t TextualDMG)"

trap 'rm -rf "${work}"' EXIT

python="$(release_python)"

# The picture is 1000 × 800 pixels for a 500 × 400 point window: dmgbuild
# makes a two-size TIFF of it and its @2x partner, sharp on both kinds of screen
sips -z 400 500 "${BACKGROUND}" --out "${work}/background.png" > /dev/null
cp "${BACKGROUND}" "${work}/background@2x.png"

cat > "${work}/settings.py" <<EOF
import os.path

application = defines["app"]

files = [application]
symlinks = {"Applications": "/Applications"}

icon_locations = {
	os.path.basename(application): (120, 238),
	"Applications": (380, 238),
}

background = defines["background"]

window_rect = ((200, 120), (500, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False

arrange_by = None
icon_size = 112
text_size = 13
label_pos = "bottom"

format = "ULFO"
filesystem = "HFS+"
EOF

rm -f "${dmg}"

"${python}" -m dmgbuild \
	-s "${work}/settings.py" \
	-D app="${app}" \
	-D background="${work}/background.png" \
	"Textual ${version}" \
	"${dmg}" > "${work}/dmgbuild.log" 2>&1 || { cat "${work}/dmgbuild.log" >&2; echo "error: dmgbuild failed" >&2; exit 1; }

if [ -n "${identity}" ]; then
	codesign --sign "${identity}" --timestamp "${dmg}"
fi
