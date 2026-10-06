#!/usr/bin/env python3
"""Fails when a build has more warnings than the committed baseline.

Usage: warning-ratchet.py <baseline file> <description> <warnings|analyzerWarnings> <result bundle>...

Reads Xcode's structured build results (.xcresult bundles) rather than the
text log, whose lines can interleave when files compile in parallel. Each
warning counts once per file, line and message, so the per-architecture
copies collapse while a second occurrence of the same message elsewhere in
a file still counts.

Warnings from the nested xcodebuild calls in the build scripts reach the
result bundle as parsed text: the same warning then appears with and without
its "[-W…]" flag, a line cut off in the output can produce a truncated copy,
and a copy may lack its line number. All are folded into the full warning.
"""

import json
import os
import re
import subprocess
import sys
import urllib.parse

baseline_file, description, kind = sys.argv[1:4]
bundles = sys.argv[4:]

if not bundles:
	sys.exit("warning-ratchet.py: no result bundles given")

checkout = os.path.realpath(os.getcwd()) + "/"

# (path, line) -> messages; line is None when the copy has no line number
messages_by_location = {}

for bundle in bundles:
	results = json.loads(subprocess.run(
		["xcrun", "xcresulttool", "get", "build-results", "--path", bundle],
		check=True, capture_output=True, text=True).stdout)

	if kind not in results:
		sys.exit(f"::error::{bundle} has no '{kind}' in its build results; has xcresulttool's format changed?")

	for issue in results[kind]:
		url, _, fragment = issue.get("sourceURL", "").partition("#")
		path = urllib.parse.unquote(url.removeprefix("file://")).removeprefix(checkout)
		line = urllib.parse.parse_qs(fragment).get("StartingLineNumber", [None])[0]
		message = re.sub(r"\s*\[-W[^\]]+\]$", "", issue.get("message", ""))
		messages_by_location.setdefault((path, line), set()).add(message)

def is_truncated_copy(message, messages):
	return any(other != message and other.startswith(message) for other in messages)

unique = set()

for (path, line), messages in messages_by_location.items():
	for message in messages:
		if is_truncated_copy(message, messages):
			continue

		# A copy without a line number of a warning that has one elsewhere in the file
		if line is None and any(
			other_path == path and other_line is not None and
			any(other == message or other.startswith(message) for other in other_messages)
			for (other_path, other_line), other_messages in messages_by_location.items()):
			continue

		unique.add((path, line or "", message))

count = len(unique)

with open(baseline_file) as file:
	baseline = int("".join(character for character in file.read() if character.isdigit()))

print(f"::group::{description} ({count})")
for path, line, message in sorted(unique):
	print(f"{path or '(no file)'}{':' + line if line else ''}: {message}")
print("::endgroup::")

print(f"{description}: {count} (baseline {baseline})")

if count > baseline:
	print(f"::error::{description} rose from {baseline} to {count}. Fix the new ones; raise {baseline_file} only with a reason.")
	sys.exit(1)

if count < baseline:
	print(f"::notice::{description} dropped from {baseline} to {count}. Lower {baseline_file} to {count} to keep the improvement.")
