#!/usr/bin/env python3
"""Assemble complete macOS assets on a hosted runner from the reviewed dependency profile."""
import argparse
import base64
import gzip
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--version', required=True)
args = parser.parse_args()
version = args.version
if not re.fullmatch(r'\d+\.\d+\.\d+', version):
    raise SystemExit('Expected a release version such as 0.5.5')
repo = 'JuanFranG/Penguin-cpp'
tag = 'v' + version
root = Path(__file__).resolve().parents[1]
work = Path(os.environ['RUNNER_TEMP']) / 'complete-release'
work.mkdir()
out = work / 'assets'
out.mkdir()

def run(*command, **kwargs):
    return subprocess.run([str(value) for value in command], check=True, timeout=900, **kwargs)

def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()

def release():
    url = json.loads(subprocess.check_output(['gh', 'release', 'view', tag, '--repo', repo, '--json', 'apiUrl'], text=True))['apiUrl']
    return json.loads(subprocess.check_output(['gh', 'api', url], text=True))

info = release()
if not info['draft']:
    raise SystemExit('Only a draft release may be assembled')
# The workflow itself may be newer, but all application inputs must match the release tag.
run('git', 'fetch', '--depth=1', 'origin', 'tag', tag)
run('git', 'diff', '--exit-code', tag, '--', 'Source', 'Compat', 'Lang', 'Templates',
    'packaging/build-macos-pkg.py', 'packaging/install-macos.sh')
native_name = f'Penguin-cpp-{version}-arm64.dmg'
native_asset = next(asset for asset in info['assets'] if asset['name'] == native_name)
run('gh', 'release', 'download', tag, '--repo', repo, '--pattern', native_name, '--dir', out)
assert 'sha256:' + sha(out / native_name) == native_asset['digest'], 'Native asset digest mismatch'
base_name = 'Penguin-cpp-0.5.0-COMPLETE-UNSIGNED.pkg'
source_name = 'Penguin-cpp-0.5.0-COMPAT-SOURCES.tar.gz'
run('gh', 'release', 'download', 'v0.5.0', '--repo', repo, '--pattern', base_name, '--pattern', source_name, '--dir', work)
assert sha(work / base_name) == 'a2f17e5aec2764908824b7162f2b2ecfcaa2242609fee46380b13329c98dd786', 'Base package mismatch'
assert sha(work / source_name) == 'f493ab0bc203e3b219e03458e4a863906965527f94bbbada54417e59ab0075fe', 'Corresponding sources mismatch'
run('pkgutil', '--expand-full', work / base_name, work / 'old')
old_resources = work / 'old/penguin.pkg/Payload/Penguin cpp.app/Contents/Resources'
# Recover the exact reviewed pre-packaging bytes; the normal integrity gate stays unchanged.
patch_name = 'macOS-runtime-signatures-foss-1.json.gz'
run('gh', 'release', 'download', 'v0.5.5', '--repo', repo, '--pattern', patch_name, '--dir', work)
assert sha(work / patch_name) == '18e3226e6e9dc365a0bc025bcfda6985c4483351b68831ed68cc2a77408310a6'
patch = json.loads(gzip.decompress((work / patch_name).read_bytes()))
assert patch['base_pkg_sha256'] == sha(work / base_name)
runtime_root = old_resources / 'Compat/windows/runtime'
runtime_manifest = json.loads((runtime_root / 'penguin-runtime.json').read_text())
for relative, stamp in patch['files'].items():
    path = runtime_root / relative
    assert not path.is_symlink() and runtime_root.resolve() in path.resolve().parents
    assert sha(path) == stamp['from_sha256']
    assert runtime_manifest['files'][relative]['sha256'] == stamp['to_sha256']
    data = bytearray(path.read_bytes()[:stamp['size']])
    data.extend(b'\0' * (stamp['size'] - len(data)))
    for offset, encoded in stamp['blocks']:
        block = base64.b64decode(encoded, validate=True)
        assert 0 <= offset and offset + len(block) <= len(data)
        data[offset:offset + len(block)] = block
    assert hashlib.sha256(data).hexdigest() == stamp['to_sha256']
    path.write_bytes(data)
    print('Restored original reviewed signature:', relative, flush=True)

mount = work / 'native'
mount.mkdir()
run('hdiutil', 'attach', '-readonly', '-nobrowse', '-mountpoint', mount, out / native_name)
try:
    app = mount / 'Penguin cpp.app'
    native_info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    assert native_info['CFBundleVersion'] == version
    package = out / f'Penguin-cpp-{version}-COMPLETE-UNSIGNED.pkg'
    run('python3', root / 'packaging/build-macos-pkg.py', '--app', app,
        '--toolchain', old_resources / 'Compat/windows/toolchain',
        '--runtime', old_resources / 'Compat/windows/runtime',
        '--tools', old_resources / 'Compat/windows/tools', '--publishable',
        '--source-bundle', work / source_name, '--output', package)
finally:
    run('hdiutil', 'detach', mount)
# Keep peak disk use below the hosted runner's limit.
shutil.rmtree(work / 'old')
(work / base_name).unlink()
run('pkgutil', '--expand-full', package, work / 'complete')
complete = work / 'complete/penguin.pkg/Payload/Penguin cpp.app'
resources = complete / 'Contents/Resources'
for relative in ['Compat/windows/console-startup.c', 'Compat/windows/self-test.cpp']:
    assert (resources / relative).read_bytes() == (root / relative).read_bytes(), relative
run('codesign', '--verify', '--deep', '--strict', complete)
# Build and run the same startup/self-test sources used by first launch.
compiler = resources / 'Compat/windows/toolchain/bin'
startup = work / 'console-startup.o'
probe = work / 'self-test.exe'
run(compiler / 'x86_64-w64-mingw32-clang', '-c', resources / 'Compat/windows/console-startup.c',
    '-DPENGUIN_CONSOLE_CP=65001', '-o', startup)
run(compiler / 'x86_64-w64-mingw32-clang++', '-static', '-DPENGUIN_CONSOLE_CP=65001',
    '-I' + str(resources / 'Compat/common/include'), resources / 'Compat/windows/self-test.cpp',
    startup, '-lgdi32', '-o', probe)
env = {key: value for key, value in os.environ.items() if key not in ('GH_TOKEN', 'GITHUB_TOKEN')}
env.update(WINEPREFIX=str(work / 'prefix'), WINEDEBUG='-all', WINEDLLOVERRIDES='mscoree,mshtml=')
wine = resources / 'Compat/windows/runtime/bin/wine'
server = wine.parent / 'wineserver'
try:
    result = subprocess.run([str(wine), 'wineboot', '-u'], env=env, capture_output=True, timeout=180)
    (out / 'macOS-complete-self-test.log').write_bytes(result.stdout + result.stderr)
    assert result.returncode == 0, 'Runtime initialization failed'
    # As in the app's setup worker, an already stopped server is valid.
    subprocess.run([str(server), '-k'], env=env, timeout=30)
    subprocess.run([str(server), '-w'], env=env, check=True, timeout=30)
    result = subprocess.run([str(wine), str(probe)], env=env, capture_output=True, timeout=120)
    with (out / 'macOS-complete-self-test.log').open('ab') as log:
        log.write(result.stdout + result.stderr)
    assert result.returncode == 0 and b'PENGUIN_WINDOWS_READY' in result.stdout, 'Complete runtime self-test failed'
finally:
    subprocess.run([str(server), '-k'], env=env, timeout=30)
run('codesign', '--verify', '--deep', '--strict', complete)
stage = work / 'dmg-stage'
stage.mkdir()
run('ditto', complete, stage / complete.name)
(stage / 'Applications').symlink_to('/Applications')
(stage / 'LEEME.txt').write_text(
    f'Penguin cpp {version}, macOS 26+ / Apple Silicon. Complete experimental edition.\n'
    'Incluye LLVM-MinGW/UCRT, GNU Make y Wine ARM64/FEX; no requiere Rosetta.\n'
    'Arrastra Penguin cpp a Aplicaciones. Al abrirse prepara el entorno Windows privado.\n'
    'Las Command Line Tools de Apple solo son necesarias para desarrollo nativo de macOS.\n'
    'Sin Developer ID/notarizacion: abrir y autorizar en Ajustes > Privacidad y seguridad.\n'
    'Includes the complete Windows environment; Apple tools are needed for native macOS development.\n')
(stage / 'SOURCES-AND-LICENSES.md').write_text(
    'Reviewed profile: penguin-windows-foss-1. Individual component licenses are retained.\n'
    f'Corresponding dependency sources: {source_name}, unchanged from v0.5.0.\n'
    f'Penguin source and packaging: https://github.com/{repo}/tree/{tag}\n')
dmg = out / f'Penguin-cpp-{version}-COMPLETE-UNSIGNED.dmg'
run('hdiutil', 'create', '-volname', f'Penguin cpp {version} Complete', '-srcfolder', stage, '-format', 'UDZO', dmg)
run('hdiutil', 'verify', dmg)
shutil.move(work / source_name, out / source_name)
for name in ['COMPATIBILITY-REVIEW.json', 'REDISTRIBUTION.md']:
    run('gh', 'release', 'download', tag, '--repo', repo, '--pattern', name, '--dir', out)
files = [out / name for name in [native_name, package.name, dmg.name, source_name, 'COMPATIBILITY-REVIEW.json', 'REDISTRIBUTION.md']]
(out / 'SHA256SUMS-COMPLETE.txt').write_text(''.join(sha(path) + '  ' + path.name + '\n' for path in files))
manifest = {'version': version, 'profile': 'penguin-windows-foss-1', 'native_asset_sha256': sha(out / native_name),
            'self_test': 'passed', 'source_tag': tag,
            'assets': {path.name: {'sha256': sha(path), 'size': path.stat().st_size} for path in files}}
(out / 'macOS-complete-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
assert release()['draft'], 'Release was published during assembly; refusing to replace assets'
run('gh', 'release', 'upload', tag, '--repo', repo, '--clobber', package, dmg, out / source_name,
    out / 'SHA256SUMS-COMPLETE.txt', out / 'macOS-complete-manifest.json', out / 'macOS-complete-self-test.log')
print('Complete macOS assets validated and uploaded; release remains a draft.', flush=True)
