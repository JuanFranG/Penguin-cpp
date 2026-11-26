"""macOS: real bundle replacement; only GitHub transport is supplied locally.
Usage: --old-app COMPLETE_APP --complete-dmg DMG --native-dmg DMG --version VERSION
Uses real hdiutil, codesign, ditto and mv against disposable app copies.
"""
import argparse
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile

parser = argparse.ArgumentParser()
for name in ('old-app', 'complete-dmg', 'native-dmg', 'version'):
    parser.add_argument('--'+name, required=True)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[3]
old = Path(args.old_app).resolve()
old_version = plistlib.loads((old/'Contents/Info.plist').read_bytes())['CFBundleShortVersionString']
for name, success in [('complete', True), ('native', False)]:
    with tempfile.TemporaryDirectory(prefix='penguin-real-update-') as temp:
        root = Path(temp)
        dest = root/'Applications with spaces'
        dest.mkdir()
        app = dest/"Penguin's QA.app"
        subprocess.run(['/bin/cp', '-cR', str(old), str(app)], check=True)
        data = root/'private-user-data'
        data.mkdir()
        (data/'keep.txt').write_text('previous project and prefix data')
        tools = root/'bin'
        tools.mkdir()
        curl = tools/'curl'
        curl.write_text('''#!/usr/bin/python3
import os, subprocess, sys
args=sys.argv[1:]
if '--write-out' in args or '-w' in args:
    print('https://github.com/JuanFranG/Penguin-cpp/releases/tag/v'+os.environ['QA_VERSION'],end='')
else:
    expected='Penguin-cpp-'+os.environ['QA_VERSION']+'-COMPLETE-UNSIGNED.dmg'
    assert args[-1].endswith(expected), args
    output=args[args.index('-o')+1]
    subprocess.run(['/bin/cp','-c',os.environ['QA_DMG'],output],check=True)
''')
        curl.chmod(0o700)
        dmg = args.complete_dmg if success else args.native_dmg
        env = dict(os.environ, PATH=str(tools)+':/usr/bin:/bin:/usr/sbin:/sbin',
                   INSTALL_DIR=str(dest), INSTALL_APP_NAME=app.name,
                   QA_VERSION=args.version, QA_DMG=str(Path(dmg).resolve()))
        result = subprocess.run(['/bin/bash', str(repo/'packaging/install-macos.sh')],
                                env=env, capture_output=True, text=True, timeout=240)
        assert (result.returncode == 0) == success, result.stdout+result.stderr
        version = plistlib.loads((app/'Contents/Info.plist').read_bytes())['CFBundleShortVersionString']
        assert version == (args.version if success else old_version), version
        assert (app/'Contents/Resources/Compat/windows/environment.json').is_file()
        assert (data/'keep.txt').read_text() == 'previous project and prefix data'
        assert not list(dest.glob('.penguin-cpp-update.*'))
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
        if success:
            assert (app/'Contents/Resources/Compat/windows/console-startup.c').read_bytes() == (repo/'Compat/windows/console-startup.c').read_bytes()
        print('[OK]', name, ': real replacement' if success else ': real native downgrade rejected',
              old_version, '->', version, flush=True)
