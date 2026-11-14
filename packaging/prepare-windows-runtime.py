#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Prepare a pinned, reduced ARM64 Wine/FEX tree for local integration testing.

Never modify the downloaded original. Exclude optional proprietary assets and
Intel host shims. Keep upstream license texts. Public redistribution additionally
requires the complete corresponding sources and a completed component review.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import tarfile
import os
import subprocess

VERSION = '6.5'
SHA256 = '574199696623371d6c4abfe5d242c86403cc4ba4b4b5643f5e6187a6d5b86d4b'
EXCLUDE = ('share/metalsharp', 'share/wine/shadercompilers', 'share/wine/mono',
           'share/wine/gecko', 'lib/libmetalirconverter.dylib', 'lib/linuxhost')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--archive', type=Path, required=True)
    p.add_argument('--extracted', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    digest = hashlib.sha256()
    with args.archive.open('rb') as source:
        for chunk in iter(lambda: source.read(8*1024*1024), b''):
            digest.update(chunk)
    if digest.hexdigest() != SHA256:
        p.error('Archive does not match the pinned upstream release')
    if args.output.exists():
        p.error('Output already exists; choose a fresh directory')
    # Verify that the inspected extraction is exactly this archive before using it.
    with tarfile.open(args.archive, 'r|xz') as archive:
        for entry in archive:
            if Path(entry.name).name.startswith('._'): continue  # AppleDouble metadata, decoded as xattrs by bsdtar
            path = args.extracted.parent / entry.name
            if entry.isfile():
                if not path.is_file() or path.stat().st_size != entry.size:
                    p.error('Extraction differs from archive: ' + entry.name)
                original = archive.extractfile(entry)
                with path.open('rb') as extracted:
                    while True:
                        chunk = original.read(1024*1024)
                        if extracted.read(len(chunk)) != chunk:
                            p.error('Extraction differs from archive: ' + entry.name)
                        if not chunk: break
            elif entry.issym() and (not path.is_symlink() or os.readlink(path) != entry.linkname):
                p.error('Extraction symlink differs: ' + entry.name)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['/bin/cp', '-cR', str(args.extracted.resolve()), str(args.output.resolve())], check=True)
    excluded = []
    for relative in EXCLUDE:
        target = args.output / relative
        if target.exists():
            excluded.append(relative)
            if target.is_dir(): shutil.rmtree(target)
            else: target.unlink()
    # Preserve a native executable at the path the IDE discovers. The IDE supplies
    # the GStreamer/Vulkan environment formerly supplied by upstream's shell wrapper.
    (args.output / 'bin/wine').unlink()
    (args.output / 'bin/wine').symlink_to('wine-launcher')
    hosts = 0
    for f in args.output.rglob('*'):
        if not f.is_file() or f.is_symlink(): continue
        with f.open('rb') as stream: header = stream.read(16)
        if header[:4] == b'\xcf\xfa\xed\xfe':
            cpu = struct.unpack_from('<I', header, 4)[0]
            if cpu == 0x1000007:
                raise SystemExit('Intel-only host binary remains: ' + str(f))
            if cpu == 0x100000c: hosts += 1
        if any(part.lower() in ('fmod','redist','shadercompilers') for part in f.relative_to(args.output).parts):
            raise SystemExit('Unreviewed optional payload remains: ' + str(f))
    for required in ('bin/wine','bin/wineserver','lib/wine/aarch64-unix/libarm64ecfex.so',
                     'share/licenses/wine/COPYING.LIB','share/licenses/fex/LICENSE'):
        if not (args.output / required).is_file(): p.error('Missing runtime component: ' + required)
    manifest = {'runtime':'Wine 11.20 / MetalSharp Wine 6.5 ARM64 / FEX',
                'upstream':'https://github.com/metalsharp/MetalSharp-Wine/releases/tag/v6.5',
                'archive_sha256':SHA256,'excluded':excluded,'arm64_host_files':hosts,
                'changes':['Native wine alias; optional assets removed; no Apple/Microsoft installer run'],
                'distribution_status':'local integration; public source/compliance review pending'}
    manifest['files'] = {}
    for f in sorted(args.output.rglob('*')):
        if f.is_dir(): continue
        key = str(f.relative_to(args.output))
        if f.is_symlink(): manifest['files'][key] = {'link': str(f.readlink())}
        elif f.is_file():
            digest = hashlib.sha256()
            with f.open('rb') as stream:
                for chunk in iter(lambda:stream.read(4*1024*1024),b''): digest.update(chunk)
            manifest['files'][key] = {'sha256':digest.hexdigest()}
    (args.output / 'penguin-runtime.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({k:v for k,v in manifest.items() if k != 'files'},indent=2))


if __name__ == '__main__': main()
