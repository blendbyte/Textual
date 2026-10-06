#!/bin/bash
#
# Fails when a build log has more warnings than the committed baseline.
# Usage: warning-ratchet.sh <build log> <baseline file> <description> [extended grep pattern]
#
# Only diagnostics that start with a file path count (not Swift's multi-line
# notes or tool messages), once per file and message: line numbers and the
# checkout path are ignored, so moving code around does not change the count.
# Baselines must come from a clean build, as CI builds from scratch.

set -eo pipefail

log="$1"
baseline_file="$2"
description="$3"
pattern="${4:- warning:}"

count=$(grep -E '^/.+: warning: ' "$log" | grep -E -- "$pattern" | sed -E "s#^${PWD}/##; s/:[0-9]+:[0-9]+:/:/" | sort -u | wc -l | tr -d ' ')
baseline=$(tr -dc '0-9' < "$baseline_file")

echo "$description: $count (baseline $baseline)"

if [ "$count" -gt "$baseline" ]; then
	echo "::error::$description rose from $baseline to $count. Fix the new ones; raise $baseline_file only with a reason."
	exit 1
fi

if [ "$count" -lt "$baseline" ]; then
	echo "::notice::$description dropped from $baseline to $count. Lower $baseline_file to $count to keep the improvement."
fi
