#!/usr/bin/env python3
"""Repackage pinned WineHQ 11 for Penguin's private x64 runtime (no root install)."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / 'build/linux-runtime'
OUT = ROOT / 'build/deb'
VERSION = '11.0.0.0~noble-1+penguin1'
BASE = 'https://dl.winehq.org/wine-builds/ubuntu/pool/main/w/wine/'
INPUTS = {
    'wine-stable_11.0.0.0~noble-1_amd64.deb': '04e7b4b995262c734019099d93277d8f219f7d180ebb65b5ccb3df7f97be1078',
    'wine-stable-amd64_11.0.0.0~noble-1_amd64.deb': '6cb835e2171b5572b17f1c06729735c2c7e40178239d7fa6c29ef14bd9b40d16',
    'wine_11.0.0.0~noble.orig.tar.gz': '00c6ac20e94f0786ca946410b2da6034699b1c977821039fbb21d5dc958f793a',
    'wine_11.0.0.0~noble-1.debian.tar.xz': '24e5d80b9f8a7ac3cf0a75b353b86af01266fa27debbbe4e858ce4b000a82b61',
    'wine_11.0.0.0~noble-1.dsc': 'd4f051ed91151ef263beaa3a0c26157b22067c615f6831c264581cd6949977d4',
}
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
doc = stage / 'usr/share/doc/penguin-windows-runtime'
shutil.copytree(extracted / 'usr/share/doc/wine-stable-amd64', doc, symlinks=True)
(doc / 'PENGUIN-SOURCES.txt').write_text(
    'WineHQ 11.0, Ubuntu noble build. Binary files are unchanged and relocated.\n'
    'Only unused build tools are omitted. Original licenses remain installed.\n'
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
