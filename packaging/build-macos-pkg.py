#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Build a local, unsigned macOS 26 ARM64 installer validation artifact.

Does not install, publish, download dependencies, or accept third-party terms.
Optional curated runtime/tools form a complete local test environment. Public distribution still requires corresponding sources, signing and compliance review.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET


def run(*args):
    subprocess.run([str(x) for x in args], check=True)


def capture(*args):
    return subprocess.check_output([str(x) for x in args], text=True)


def fail(message):
    raise SystemExit(message)


def validate_links(root):
    for directory, dirs, files in os.walk(root, followlinks=False):
        for name in dirs + files:
            path = Path(directory) / name
            if path.is_symlink():
                target = path.resolve()
                if not target.exists() or root.resolve() not in target.parents:
                    fail('External or broken toolchain link: ' + str(path))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, default=Path('build/macos/Penguin cpp.app'))
    parser.add_argument('--native-only', action='store_true', help='Explicitly build only the native IDE; no complete Windows environment')
    parser.add_argument('--toolchain', type=Path, help='Existing LLVM-MinGW distribution, copied with its notices')
    parser.add_argument('--output', type=Path, default=Path('build/macos/Penguin-cpp-arm64-UNSIGNED-VALIDATION.pkg'))
    parser.add_argument('--runtime', type=Path, help='Curated ARM64 Wine/FEX tree from prepare-windows-runtime.py')
    parser.add_argument('--tools', type=Path, help='Pinned GNU Make tree from build-compat-make.sh')
    parser.add_argument('--stage-app', type=Path, help='Prepare a review/test app instead of producing a pkg; destination must not exist')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    if args.native_only:
        if args.runtime or args.tools:
            fail('--native-only cannot include a runtime or bundled Make.')
    else:
        args.toolchain = args.toolchain or repo/'build/windows-game-tools/llvm-mingw-20261104-ucrt-macos-universal'
        args.runtime = args.runtime or repo/'build/compat-bundle/runtime'
        args.tools = args.tools or repo/'build/compat-bundle/tools'
        for name, directory in (('toolchain',args.toolchain),('runtime',args.runtime),('GNU Make',args.tools)):
            if not directory.is_dir():
                fail('Complete package requires the pinned ' + name + ': ' + str(directory) +
                     '. Supply the prepared component, or use --native-only for an explicitly native validation build.')
    if args.stage_app and args.stage_app.exists(): fail('Stage destination already exists.')
    if bool(args.runtime) != bool(args.tools):
        fail('The curated runtime and GNU Make must be supplied together.')
    if args.runtime and not args.toolchain:
        fail('A complete environment also requires --toolchain.')
    app = args.app.resolve()
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if info.get('LSMinimumSystemVersion') != '26.0':
        fail('The app must declare macOS 26.0 as its minimum.')
    binary = app / 'Contents/MacOS' / info['CFBundleExecutable']
    run('lipo', '-verify_arch', 'arm64', binary)
    load_commands = capture('otool', '-arch', 'arm64', '-l', binary)
    if not re.search(r'\bminos\s+26\.0(?:\s|$)', load_commands):
        fail('The app binary must be linked for macOS 26.0; changing Info.plist alone is insufficient.')
    if (app / 'Contents/Resources/Compat/windows/runtime').exists():
        fail('The runtime redistribution audit is not complete; do not package this app wholesale.')
    if args.toolchain:
        toolchain = args.toolchain.resolve()
        for relative in ('LICENSE.TXT', 'bin/clang', 'bin/x86_64-w64-mingw32-clang++',
                         'x86_64-w64-mingw32/share/mingw32/COPYING.MinGW-w64-runtime.txt'):
            if not (toolchain / relative).is_file():
                fail('Missing LLVM-MinGW file: ' + relative)
        validate_links(toolchain)
        run('lipo', '-verify_arch', 'arm64', toolchain / 'bin/clang')
    runtime_info = None
    if args.runtime:
        runtime_info = json.loads((args.runtime / 'penguin-runtime.json').read_text())
        if runtime_info['archive_sha256'] != '574199696623371d6c4abfe5d242c86403cc4ba4b4b5643f5e6187a6d5b86d4b':
            fail('Unpinned Wine/FEX runtime.')
        listed = runtime_info.get('files',{})
        if not listed: fail('Curated runtime manifest has no file hashes.')
        actual = {str(f.relative_to(args.runtime)) for f in args.runtime.rglob('*') if (f.is_file() or f.is_symlink()) and f.name != 'penguin-runtime.json'}
        if actual != set(listed): fail('Curated runtime file list has changed.')
        for relative, stamp in listed.items():
            path = args.runtime / relative
            if 'link' in stamp:
                if not path.is_symlink() or str(path.readlink()) != stamp['link']: fail('Runtime link changed: '+relative)
            else:
                digest = hashlib.sha256()
                with path.open('rb') as stream:
                    for chunk in iter(lambda:stream.read(4*1024*1024),b''):digest.update(chunk)
                if digest.hexdigest() != stamp['sha256']: fail('Runtime file changed: '+relative)
        for excluded in ('share/metalsharp','share/wine/shadercompilers','share/wine/mono','share/wine/gecko','lib/libmetalirconverter.dylib'):
            if (args.runtime / excluded).exists(): fail('Excluded payload has returned: ' + excluded)
        for required in ('bin/wine','bin/wineserver','share/licenses/wine/COPYING.LIB','share/licenses/fex/LICENSE'):
            if not (args.runtime / required).is_file(): fail('Missing runtime file: ' + required)
        if not (args.tools / 'share/licenses/make/make-4.4.1.tar.gz').is_file():
            fail('Include the exact GNU Make source archive and its GPL notices.')
        make_source = args.tools / 'share/licenses/make/make-4.4.1.tar.gz'
        if hashlib.sha256(make_source.read_bytes()).hexdigest() != 'dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3':
            fail('Unpinned GNU Make source.')
        validate_links(args.runtime); validate_links(args.tools)
        for binary in (args.runtime/'bin/wine',args.runtime/'bin/wineserver',args.tools/'bin/make'):
            run('lipo','-verify_arch','arm64',binary)
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    if not args.stage_app and output.exists():
        fail('Choose a new output path; refusing to overwrite an existing installer.')
    with tempfile.TemporaryDirectory(prefix='penguin-pkg-', dir=str(output.parent)) as temporary:
        work = Path(temporary)
        payload = work / 'payload'
        payload.mkdir()
        staged = payload / app.name
        run('/bin/cp', '-cR', app, staged)
        resources = staged / 'Contents/Resources'
        if args.toolchain:
            target = resources / 'Compat/windows/toolchain'
            if target.exists():
                fail('The input app already contains a toolchain; use a clean app.')
            target.parent.mkdir(parents=True, exist_ok=True)
            run('/bin/cp', '-cR', toolchain, target)
            # Permissively licensed tools can be re-signed in this local validation copy.
            # Keep every upstream notice, and leave the downloaded originals unchanged.
            for directory, _, files in os.walk(target):
                for name in files:
                    path = Path(directory) / name
                    if path.is_symlink():
                        continue
                    with path.open('rb') as stream:
                        magic = stream.read(4)
                    if magic in (b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf'):
                        run('codesign', '--force', '--sign', '-', path)
        shutil.copytree(repo/'Compat/common', resources/'Compat/common', dirs_exist_ok=True)
        for name in ('self-test.cpp','LICENSE'):
            target = resources/'Compat/windows'/name
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(repo/'Compat/windows'/name,target)
        if args.runtime:
            for name, source in (('runtime',args.runtime),('tools',args.tools)):
                target = resources/'Compat/windows'/name
                run('/bin/cp','-cR',source.resolve(),target)
                for directory, _, files in os.walk(target):
                    for name in files:
                        path = Path(directory)/name
                        if path.is_symlink(): continue
                        with path.open('rb') as stream: magic = stream.read(4)
                        if magic in (b'\xcf\xfa\xed\xfe',b'\xfe\xed\xfa\xcf',b'\xca\xfe\xba\xbe',b'\xca\xfe\xba\xbf'):
                            run('lipo','-verify_arch','arm64',path)
                            run('codesign','--force','--sign','-',path)
            environment = {'schema':1,'toolchain':'llvm-mingw-20261104-ucrt','make':'4.4.1',
                           'runtime':runtime_info,'self_test_sha256':hashlib.sha256((resources/'Compat/windows/self-test.cpp').read_bytes()).hexdigest()}
            (resources/'Compat/windows/environment.json').write_text(json.dumps(environment,indent=2)+'\n')
        (resources / 'PKG-CONTENT.txt').write_text(
            'Complete included Windows environment\n' if args.runtime else 'Native IDE only; Windows tools are not bundled\n')
        (resources / 'PKG-VALIDATION.txt').write_text(
            'LOCAL VALIDATION BUILD — not a published release.\n'
            'Minimum: macOS 26.0, Apple Silicon.\n'
            'Tools retain their upstream licenses; LLVM-MinGW Mach-O files are re-signed ad hoc in this copy.\n'
            'Optional curated Wine/FEX and GNU Make are described in Compat/windows/environment.json when present.\n'
            'No Microsoft redistributable installer, FMOD, Apple SDK, GPTK or Metal Shader Converter is included.\n'
            'Apple Command Line Tools remain a separate prerequisite for native macOS builds and debugging.\n'
            'Before public redistribution: complete corresponding sources/compliance, Developer ID signing and notarization.\n')
        # No --deep re-signing: do not rewrite third-party nested code implicitly.
        run('codesign', '--force', '--sign', '-', staged)
        run('codesign', '--verify', '--deep', '--strict', staged)
        if args.stage_app:
            run('/bin/cp','-cR',staged,args.stage_app.resolve())
            print('Prepared local integration app:',args.stage_app)
            return
        component_plist = work / 'components.plist'
        run('pkgbuild', '--analyze', '--root', payload, component_plist)
        components = plistlib.loads(component_plist.read_bytes())
        for component in components:
            component['BundleIsRelocatable'] = False
            component['BundleOverwriteAction'] = 'upgrade'
        component_plist.write_bytes(plistlib.dumps(components))
        scripts = work / 'scripts'
        scripts.mkdir()
        preinstall = scripts / 'preinstall'
        preinstall.write_text('''#!/bin/sh
set -eu
[ "${3:-/}" = / ] || { echo 'Install Penguin on the current system volume.' >&2; exit 1; }
major=$(/usr/bin/sw_vers -productVersion); major=${major%%.*}
[ "$major" -ge 26 ] || { echo 'Penguin cpp requires macOS 26 or later.' >&2; exit 1; }
[ "$(/usr/sbin/sysctl -n hw.optional.arm64)" = 1 ] || { echo 'Penguin cpp requires Apple Silicon.' >&2; exit 1; }
if /usr/bin/pgrep -x penguin-cpp >/dev/null; then
  echo 'Close Penguin cpp before installing or updating.' >&2; exit 1
fi
exit 0
''')
        preinstall.chmod(0o755)
        component_pkg = work / 'penguin.pkg'
        run('pkgbuild', '--root', payload, '--component-plist', component_plist,
            '--install-location', '/Applications', '--identifier', 'io.github.juanfrang.penguin-cpp',
            '--version', info['CFBundleVersion'], '--ownership', 'recommended',
            '--scripts', scripts, component_pkg)
        distribution = ET.Element('installer-gui-script', {'minSpecVersion': '2'})
        ET.SubElement(distribution, 'title').text = 'Penguin cpp — local validation'
        ET.SubElement(distribution, 'options', {'customize': 'never', 'require-scripts': 'true', 'hostArchitectures': 'arm64'})
        ET.SubElement(distribution, 'domains', {'enable_localSystem': 'true', 'enable_currentUserHome': 'false', 'enable_anywhere': 'false'})
        volumes = ET.SubElement(distribution, 'volume-check')
        versions = ET.SubElement(volumes, 'allowed-os-versions')
        ET.SubElement(versions, 'os-version', {'min': '26.0'})
        outline = ET.SubElement(distribution, 'choices-outline')
        ET.SubElement(outline, 'line', {'choice': 'penguin'})
        choice = ET.SubElement(distribution, 'choice', {'id': 'penguin', 'visible': 'false'})
        package_id = 'io.github.juanfrang.penguin-cpp'
        ET.SubElement(choice, 'pkg-ref', {'id': package_id})
        ET.SubElement(distribution, 'pkg-ref', {'id': package_id, 'version': info['CFBundleVersion'], 'onConclusion': 'none'}).text = 'penguin.pkg'
        distribution_file = work / 'Distribution.xml'
        ET.ElementTree(distribution).write(distribution_file, encoding='utf-8', xml_declaration=True)
        run('productbuild', '--distribution', distribution_file, '--package-path', work, output)
    print('Built local validation package:', output)
    print('Unsigned and not notarized. Not installed or published.')


if __name__ == '__main__':
    main()
