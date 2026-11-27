#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Create a small, hash-anchored restoration of the reviewed runtime's original signatures."""
import argparse
import base64
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--base-pkg', type=Path, required=True)
parser.add_argument('--reviewed-runtime', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
base_sha = 'a2f17e5aec2764908824b7162f2b2ecfcaa2242609fee46380b13329c98dd786'
def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''): h.update(block)
    return h.hexdigest()
assert sha(args.base_pkg) == base_sha, 'Unreviewed base package'
result = {'base_pkg_sha256': base_sha, 'block_size': 4096, 'files': {}}
with tempfile.TemporaryDirectory(prefix='penguin-runtime-restore-') as temporary:
    work = Path(temporary)
    subprocess.run(['pkgutil', '--expand-full', str(args.base_pkg), str(work/'base')], check=True)
    old = work/'base/penguin.pkg/Payload/Penguin cpp.app/Contents/Resources/Compat/windows/runtime'
    manifest = json.loads((old/'penguin-runtime.json').read_text())
    for relative, stamp in manifest['files'].items():
        if 'sha256' not in stamp: continue
        original = args.reviewed_runtime / relative
        assert sha(original) == stamp['sha256'], 'Reviewed input changed: ' + relative
        before = old / relative
        before_sha = sha(before)
        if before_sha == stamp['sha256']: continue
        target = original.read_bytes()
        previous = before.read_bytes()
        assert target[:4] == b'\xcf\xfa\xed\xfe', 'Unexpected changed non-Mach-O: ' + relative
        # Removing signatures must leave identical executable code and data.
        normalized = []
        for index, source in enumerate([before, original]):
            clone = work/('normalized-'+str(index))
            subprocess.run(['/bin/cp', '-c', str(source), str(clone)], check=True)
            removed = subprocess.run(['codesign', '--remove-signature', str(clone)], capture_output=True)
            assert removed.returncode == 0 or b'not signed at all' in removed.stderr, removed.stderr
            normalized.append(sha(clone)); clone.unlink()
        assert normalized[0] == normalized[1], 'Executable bytes changed: ' + relative
        blocks = []
        for offset in range(0, len(target), 4096):
            block = target[offset:offset+4096]
            if block != previous[offset:offset+len(block)]:
                blocks.append([offset, base64.b64encode(block).decode('ascii')])
        reconstructed = bytearray(previous[:len(target)])
        reconstructed.extend(b'\0' * (len(target) - len(reconstructed)))
        for offset, encoded in blocks:
            block = base64.b64decode(encoded)
            reconstructed[offset:offset+len(block)] = block
        assert bytes(reconstructed) == target, 'Restoration round-trip failed: ' + relative
        result['files'][relative] = {'from_sha256': before_sha, 'to_sha256': stamp['sha256'],
            'size': len(target), 'unsigned_sha256': normalized[0], 'blocks': blocks}
        print('Verified signature-only restoration:', relative, flush=True)
args.output.write_bytes(gzip.compress(json.dumps(result, separators=(',',':')).encode(), mtime=0))
print('Restored files:', len(result['files']), 'patch bytes:', args.output.stat().st_size, 'sha256:', sha(args.output))
