#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build the opt-in prototype; never install compatibility headers globally."""
import argparse
import os
from pathlib import Path
import platform
import shlex
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--sdl-framework', type=Path,
                    help='macOS directory containing SDL3.framework')
parser.add_argument('--out', type=Path, default=Path('build/native-compat'))
parser.add_argument('--run-tests', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parent
out = args.out.resolve()
out.mkdir(parents=True, exist_ok=True)
compiler = shlex.split(os.environ.get('CXX', 'c++'))
warnings = ['-Wall', '-Wextra', '-Werror', '-I' + str(root / 'include')]
flags = ['-std=c++17'] + warnings
if platform.system() == 'Darwin':
    if not args.sdl_framework:
        parser.error('--sdl-framework must contain SDL3.framework')
    framework = args.sdl_framework.resolve()
    if not (framework / 'SDL3.framework').is_dir():
        parser.error('SDL3.framework not found')
    flags += ['-F' + str(framework)]
    libraries = ['-framework', 'SDL3', '-Wl,-rpath,' + str(framework)]
else:
    try:
        flags += shlex.split(subprocess.check_output(
            ['pkg-config', '--cflags', 'sdl3'], text=True))
        libraries = shlex.split(subprocess.check_output(
            ['pkg-config', '--libs', 'sdl3'], text=True))
    except (FileNotFoundError, subprocess.CalledProcessError):
        parser.error('SDL3 development files and pkg-config are required')
for name, source in [('legacy_demo', 'examples/legacy_demo.cpp'),
                     ('console_test', 'tests/console.cpp')]:
    subprocess.run(compiler + flags + [str(root / 'src/compat.cpp'),
                   str(root / source), '-o', str(out / name)] + libraries,
                   check=True)
    print('Built', out / name, flush=True)
c_compiler = shlex.split(os.environ.get('CC', 'cc'))
subprocess.run(c_compiler + ['-std=c11'] + warnings + [
    '-c', str(root / 'tests/c_api.c'), '-o', str(out / 'c_api.o')], check=True)
subprocess.run(compiler + flags + [str(root / 'src/compat.cpp'),
               str(out / 'c_api.o'), '-o', str(out / 'c_api')] + libraries,
               check=True)
print('Built', out / 'c_api', flush=True)
if args.run_tests:
    subprocess.run([str(out / 'legacy_demo'), '--verify'], check=True)
    subprocess.run([str(out / 'c_api')], check=True)
    subprocess.run([sys.executable, str(root / 'tests/terminal_test.py'),
                    str(out / 'console_test')], check=True)
