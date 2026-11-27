#!/usr/bin/env python3
"""Repackage pinned WineHQ 11 for Penguin's private x64 runtime (no root install)."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import urllib.request

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--strip', required=True, help='verified LLVM-MinGW llvm-strip executable')
args = parser.parse_args()
ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / 'build/linux-runtime'
OUT = ROOT / 'build/deb'
LOCK = json.loads((ROOT / 'packaging/linux-runtime-lock.json').read_text())
VERSION = LOCK['version']
BASE = LOCK['base_url']
INPUTS = LOCK['files']
CACHE.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
for name, expected in INPUTS.items():
    path = CACHE / name
    if not path.exists():
        temporary = path.with_suffix(path.suffix + '.part')
        with urllib.request.urlopen(BASE + name, timeout=120) as response, temporary.open('wb') as target:
            shutil.copyfileobj(response, target)
        temporary.replace(path)
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    if digest.hexdigest() != expected:
        raise SystemExit('SHA-256 mismatch: ' + name)
    print('Verified', name, flush=True)

extracted = CACHE / 'extracted'
shutil.rmtree(extracted, ignore_errors=True)
extracted.mkdir()
for name in INPUTS:
    if name.endswith('.deb'):
        subprocess.run(['dpkg-deb', '-x', str(CACHE / name), str(extracted)], check=True)

stage = CACHE / 'stage'
shutil.rmtree(stage, ignore_errors=True)
runtime = stage / 'usr/lib/penguin-cpp/windows-runtime'
runtime.parent.mkdir(parents=True)
shutil.copytree(extracted / 'opt/wine-stable', runtime, symlinks=True)
# Penguin invokes the runtime and builtins, not Wine's development toolchain.
for path in (runtime / 'bin').iterdir():
    if (path.is_symlink() and path.readlink().name != 'wine') or (not path.is_symlink() and path.name not in ('wine', 'wineserver')):
        path.unlink()
# Wine's development import archives are not needed to execute programs.
for path in runtime.rglob('*.a'):
    path.unlink()
# Preserve executable code, resources and unwind data; omit PE debug sections.
pe_files = []
for path in (runtime / 'lib/wine/x86_64-windows').iterdir():
    if path.is_file():
        with path.open('rb') as candidate:
            if candidate.read(2) == b'MZ':
                pe_files.append(str(path))
for start in range(0, len(pe_files), 100):
    subprocess.run([args.strip, '--strip-debug', *pe_files[start:start + 100]], check=True)
doc = stage / 'usr/share/doc/penguin-windows-runtime'
shutil.copytree(extracted / 'usr/share/doc/wine-stable-amd64', doc, symlinks=True)
(doc / 'PENGUIN-SOURCES.txt').write_text(
    'WineHQ 11.0, Ubuntu noble build. Executable code and resources are preserved; files are relocated.\n'
    'Only unused build tools and PE debug sections are omitted. Original licenses remain installed.\n'
    'Exact upstream source + Debian recipes: WineHQ-11.0.0.0-noble-SOURCES.tar.gz\n'
    'https://github.com/JuanFranG/Penguin-cpp/releases/tag/v0.5.5\n'
    'Repackaging recipe: packaging/build-linux-runtime.py in the Penguin tag.\n'
    + '\n'.join(sha + '  ' + BASE + name for name, sha in INPUTS.items()) + '\n')
control_text = subprocess.check_output(['dpkg-deb', '-f', str(CACHE / 'wine-stable-amd64_11.0.0.0~noble-1_amd64.deb')], text=True)
fields = dict(line.split(': ', 1) for line in control_text.splitlines() if ': ' in line and not line.startswith(' '))
size = subprocess.check_output(['du', '-sk', '--apparent-size', str(stage / 'usr')], text=True).split()[0]
control = stage / 'DEBIAN'
control.mkdir()
(control / 'control').write_text(
    'Package: penguin-windows-runtime\nVersion: ' + VERSION + '\nArchitecture: amd64\n'
    'Maintainer: Juan Francisco Gonzalez Pacheco <jfgonzalez@unimagdalena.edu.co>\n'
    'Installed-Size: ' + size + '\nDepends: ' + fields['Depends'] + '\n'
    'Recommends: ' + fields['Recommends'] + '\nSection: otherosfs\nPriority: optional\n'
    'Homepage: https://www.winehq.org/\n'
    'Description: private Wine 11 x64 runtime for Penguin cpp\n'
    ' Pinned WineHQ binaries and notices, relocated for Penguin compatibility.\n'
    ' This package does not replace system Wine or register global alternatives.\n')
package = OUT / ('penguin-windows-runtime_' + VERSION + '_amd64.deb')
subprocess.run(['dpkg-deb', '--root-owner-group', '-Zxz', '-z9', '--threads-max=2', '--build', str(stage), str(package)], check=True)
# GitHub Pages' repository cannot contain individual files above 100 MiB.
if package.stat().st_size >= 100 * 1024 * 1024:
    raise SystemExit('Runtime package exceeds the APT hosting file limit')
archive = OUT / 'WineHQ-11.0.0.0-noble-SOURCES.tar.gz'
with tarfile.open(archive, 'w:gz') as target:
    for name in INPUTS:
        if not name.endswith('.deb'):
            target.add(CACHE / name, arcname=name)
    target.add(doc / 'PENGUIN-SOURCES.txt', arcname='PENGUIN-SOURCES.txt')
subprocess.run(['lintian', '--fail-on', 'error', str(package)], check=True)
print('Built', package, package.stat().st_size, flush=True)
