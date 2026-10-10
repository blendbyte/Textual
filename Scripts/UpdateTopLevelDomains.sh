#!/bin/sh
# Refreshes the top-level domains Auto Hyperlinks accepts in addresses without
# a scheme, from IANA's list. Run it before a release and commit the result.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIST="${ROOT}/Frameworks/Auto Hyperlinks/Resources/tlds-alpha-by-domain.txt"
TEMP="$(mktemp)"

curl -fsSL https://data.iana.org/TLD/tlds-alpha-by-domain.txt -o "${TEMP}"

# A sanity check before replacing the list: a version line and over 1000 entries
head -1 "${TEMP}" | grep -q '^# Version' || { echo "Unexpected format" >&2; rm -f "${TEMP}"; exit 1; }
[ "$(grep -vc '^#' "${TEMP}")" -gt 1000 ] || { echo "List too short" >&2; rm -f "${TEMP}"; exit 1; }

mv "${TEMP}" "${LIST}"

echo "Updated: $(head -1 "${LIST}")"
