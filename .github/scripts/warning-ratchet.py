#!/usr/bin/env python3
"""Fails when a build has more warnings than the committed baseline.

Usage: warning-ratchet.py <result bundle> <baseline file> <description> <warnings|analyzerWarnings>

Reads Xcode's structured build results (the .xcresult bundle) rather than the
text log, whose lines can interleave when files compile in parallel. Each
warning counts once per file and message, so the per-architecture copies and
line numbers do not matter and moving code around does not change the count.
"""

import json
import os
import subprocess
import sys
import urllib.parse

bundle, baseline_file, description, kind = sys.argv[1:5]

results = json.loads(subprocess.run(
	["xcrun", "xcresulttool", "get", "build-results", "--path", bundle],
	check=True, capture_output=True, text=True).stdout)

checkout = os.path.realpath(os.getcwd()) + "/"

unique = set()

for issue in results.get(kind, []):
	path = urllib.parse.unquote(issue.get("sourceURL", "").split("#")[0].removeprefix("file://"))
	unique.add((path.removeprefix(checkout), issue.get("message", "")))

count = len(unique)

with open(baseline_file) as file:
	baseline = int("".join(character for character in file.read() if character.isdigit()))

print(f"::group::{description} ({count})")
for path, message in sorted(unique):
	print(f"{path or '(no file)'}: {message}")
print("::endgroup::")

print(f"{description}: {count} (baseline {baseline})")

if count > baseline:
	print(f"::error::{description} rose from {baseline} to {count}. Fix the new ones; raise {baseline_file} only with a reason.")
	sys.exit(1)

if count < baseline:
	print(f"::notice::{description} dropped from {baseline} to {count}. Lower {baseline_file} to {count} to keep the improvement.")
