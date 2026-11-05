#!/bin/bash

set -euo pipefail

# The agreement the download disk image shows: the website's current terms, as
# rich text. Fails rather than let a release go out with something else. Used
# by Release.sh; can be run on its own to look at the result.
#
#   Scripts/release/FetchTerms.sh <output.rtf>

TERMS_URL="https://www.textualapp.com/terms"

output="$1"

work="$(mktemp -d -t TextualTerms)"

trap 'rm -rf "${work}"' EXIT

fail() { echo "error: $*" >&2; exit 1; }

curl --fail --silent --show-error --location --max-time 60 --output "${work}/terms.html" "${TERMS_URL}" ||
	fail "Could not fetch the terms from ${TERMS_URL}"

# Only the page's text, without its header, menus and footer, in the Mac's look
# rather than the converter's Times
{
	cat <<'STYLE'
<style>
body { font-family: "Helvetica Neue", Helvetica, Arial, sans-serif; font-size: 12px; }
h1 { font-size: 18px; }
h2 { font-size: 14px; }
h3 { font-size: 12px; }
</style>
STYLE
	sed -n '/<article/,/<\/article>/p' "${work}/terms.html"
} > "${work}/article.html"

textutil -format html -inputencoding UTF-8 -convert rtf -output "${output}" "${work}/article.html" ||
	fail "Could not convert the terms to rich text"

textutil -convert txt -stdout "${output}" > "${work}/terms.txt"

# The page changing shape shouldn't put a menu or an error page in the disk image
for expected in "Terms & conditions" "Blendbyte GmbH" "Who these terms apply to" "Liability"; do
	grep -qF "${expected}" "${work}/terms.txt" || fail "The terms from ${TERMS_URL} don't mention \"${expected}\""
done

[ "$(wc -c < "${work}/terms.txt")" -ge 2000 ] || fail "The terms from ${TERMS_URL} are too short"
