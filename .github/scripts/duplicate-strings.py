#!/usr/bin/env python3
"""Fails when a .strings file defines the same key twice.

The later definition silently replaces the earlier one, so the app shows the
wrong text, and a format with other placeholders than the caller passes can
crash. Compiled strings files no longer contain the duplicate, so this reads
the sources.
"""

import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

COMMENT = re.compile(r'/\*.*?\*/|^\s*//[^\n]*', re.DOTALL | re.MULTILINE)
KEY = re.compile(r'^\s*"((?:[^"\\\n]|\\.)+)"\s*=', re.MULTILINE)


def read(path):
    data = path.read_bytes()

    if data.startswith(b'bplist'):
        return None

    for encoding in ('utf-8-sig', 'utf-16'):
        try:
            return data.decode(encoding)
        except UnicodeError:
            pass

    return None


def main():
    listing = subprocess.run(
        ['git', 'ls-files', '-z', '*.strings'],
        cwd=ROOT, check=True, capture_output=True, text=True
    ).stdout

    paths = [ROOT / name for name in listing.split('\0') if name and not name.startswith('Frameworks/Vendor/')]

    failed = False

    for path in paths:
        text = read(path)

        if text is None:
            print(f'{path.relative_to(ROOT)}: can\'t be read as text, skipped')
            continue

        # Blanks out comments but keeps their line breaks, so line numbers stay right
        text = COMMENT.sub(lambda match: re.sub(r'[^\n]', ' ', match.group(0)), text)

        matches = list(KEY.finditer(text))
        counts = Counter(match.group(1) for match in matches)

        for match in matches:
            if counts[match.group(1)] > 1:
                line = text.count('\n', 0, match.start(1)) + 1
                print(f'{path.relative_to(ROOT)}:{line}: "{match.group(1)}" is defined more than once')
                failed = True

    print(f'{len(paths)} strings files checked')

    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
