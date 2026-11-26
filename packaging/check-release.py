#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Require matching version, release notes and changelog before shipping."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
version = re.search(r"DEVCPP_VERSION\s*=\s*'([^']+)'", (root/'Source/Version.pas').read_text()).group(1)
assert re.fullmatch(r'\d+\.\d+\.\d+', version), 'Invalid release version'
notes = root / f'RELEASE_NOTES_{version}.md'
text = notes.read_text()
assert text.startswith(f'# Penguin cpp {version}\n'), 'Release note title must match the code'
for heading in ('## Cambios y adiciones', '## Validación', '## Límites y pendientes'):
    assert heading in text, f'Missing release note section: {heading}'
    body = text.split(heading, 1)[1].split('\n## ', 1)[0].strip()
    assert len(body) >= 40, f'Empty release note section: {heading}'
assert (root/'packaging/changelog').read_text().startswith(f'penguin-cpp ({version})'), 'Changelog version differs'
print(f'OK: {version}: changes, validation and known limits documented')
