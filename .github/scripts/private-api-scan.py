#!/usr/bin/env python3
#
# Lists the private Apple interfaces the built app refers to (D11: public API
# only, both builds; App Store guideline 2.5.1) and fails on any that are not
# in the baseline:
#
#   selector   an Objective-C method name beginning with "_" that the app calls
#              but none of its own binaries define
#   string     such a name written as text (swizzles, NSSelectorFromString)
#   class      a class the app links against that no SDK header declares
#   framework  a link to a private framework
#
#   private-api-scan.py <Textual.app> <baseline file>
#
# The app's own binaries are the app, its frameworks and the bundled plugins;
# Sparkle (not in the App Store build) is skipped. Needs local symbols, which
# Works on stripped builds (the runtime metadata names the app's own methods).

import pathlib
import re
import subprocess
import sys

app, baseline_file = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])

# Emitted by Apple's compilers and runtime, not called by our code
COMPILER_SELECTORS = {"_swift_localizedKey:bundle:"}
COMPILER_CLASSES = {"NSConstantArray", "NSConstantDictionary", "NSConstantDoubleNumber", "NSConstantIntegerNumber", "NSConstantFloatNumber", "OS_dispatch_queue", "OS_dispatch_data", "OS_dispatch_source", "OS_dispatch_group", "OS_dispatch_semaphore", "OS_os_log", "OS_xpc_object"}

sdk = pathlib.Path(subprocess.run(["xcrun", "--sdk", "macosx", "--show-sdk-path"], capture_output=True, text=True, check=True).stdout.strip())


def run(*arguments):
	return subprocess.run(arguments, capture_output=True, text=True).stdout


def section_strings(binary, segment, section):
	"""Address → string of a C string section"""
	strings = {}

	for line in run("otool", "-arch", "arm64", "-v", "-s", segment, section, str(binary)).splitlines()[1:]:
		address, _, text = line.partition(" ")

		if re.fullmatch(r"[0-9a-f]+", address):
			strings[int(address, 16)] = text.lstrip(" ")

	return strings


def text_base(binary):
	match = re.search(r"segname __TEXT\n\s+vmaddr (0x[0-9a-f]+)", run("otool", "-arch", "arm64", "-l", str(binary)))

	return int(match.group(1), 16) if match else 0


def selector_references(binary):
	"""The method names the binary calls (its selector references; the
	method name section also holds the names it defines and its ivars)"""
	names = section_strings(binary, "__TEXT", "__objc_methname")
	base = text_base(binary)
	selectors = set()

	for segment in ("__DATA", "__DATA_CONST"):
		for line in run("otool", "-arch", "arm64", "-v", "-s", segment, "__objc_selrefs", str(binary)).splitlines()[1:]:
			fields = line.split()

			if len(fields) < 2 or not fields[1].startswith("0x"):
				continue

			# Chained fixups store the target as an offset in the low 36 bits
			target = int(fields[1], 16) & 0xFFFFFFFFF

			if target < base:
				target += base

			if target in names:
				selectors.add(names[target])

	return selectors


binaries = []

for path in sorted(app.rglob("*")):
	if path.is_symlink() or not path.is_file() or "Sparkle.framework" in path.parts:
		continue

	if "Mach-O" in run("file", "-b", str(path)):
		binaries.append(path)

ours = set()
our_classes = set()
used = {}
strings = {}
classes = {}
findings = set()

for binary in binaries:
	name = binary.relative_to(app).as_posix()

	# The app's own methods and classes, from the runtime metadata (kept in stripped builds)
	for line in run("dyld_info", "-arch", "arm64", "-objc", str(binary)).splitlines():
		method = re.search(r"[-+]\[\S+ ([^]]+)\]$", line)
		defined_class = re.match(r"\s*@interface (\w+)\s*(:|$)", line) # not a category: "@interface NSString(…)"

		if method:
			ours.add(method.group(1))
		elif defined_class:
			our_classes.add(defined_class.group(1))

	for selector in selector_references(binary):
		used.setdefault(selector, name)

	for text in section_strings(binary, "__TEXT", "__cstring").values():
		if re.fullmatch(r"_[A-Za-z][A-Za-z0-9_]*(:[A-Za-z0-9_]*)*", text):
			strings.setdefault(text, name)

	for line in run("nm", "-arch", "arm64", "-u", str(binary)).splitlines():
		referenced_class = re.search(r"_OBJC_CLASS_\$_(\S+)$", line)

		if referenced_class and not referenced_class.group(1).startswith("_Tt"):
			classes.setdefault(referenced_class.group(1), name)

	for line in run("otool", "-L", str(binary)).splitlines():
		if "/PrivateFrameworks/" in line:
			findings.add(f"framework {line.split()[0]}")

for selector, name in used.items():
	if selector.startswith("_") and selector not in ours and selector not in COMPILER_SELECTORS:
		findings.add(f"selector {selector}")

for text, name in strings.items():
	if text not in ours and text[1:] not in our_classes and text not in COMPILER_SELECTORS:
		findings.add(f"string {text}")

# Classes declared in the SDK's headers (Objective-C) or interfaces (Swift)
declared = set()

for header in sdk.glob("System/Library/Frameworks/*.framework/**/*.h"):
	declared.update(re.findall(r"@interface\s+(\w+)", header.read_text(errors="ignore")))

for interface in sdk.glob("System/Library/Frameworks/*.framework/**/*.swiftinterface"):
	declared.update(re.findall(r"@objc\(([A-Za-z_]\w*)\)", interface.read_text(errors="ignore")))

for referenced_class in classes:
	if referenced_class not in declared and referenced_class not in our_classes and referenced_class not in COMPILER_CLASSES:
		findings.add(f"class {referenced_class}")

baseline = {line.strip() for line in baseline_file.read_text().splitlines() if line.strip() and not line.startswith("#")} if baseline_file.exists() else set()

new = sorted(findings - baseline)
gone = sorted(baseline - findings)

print(f"::group::Private API ({len(findings)})")
for finding in sorted(findings):
	print(finding)
print("::endgroup::")

for finding in gone:
	print(f"::notice::{finding} is no longer used. Remove it from {baseline_file}.")

for finding in new:
	print(f"::error::New private API: {finding}. Use public API instead (D11).")

print(f"Private API: {len(findings)} (baseline {len(baseline)})")

sys.exit(1 if new else 0)
