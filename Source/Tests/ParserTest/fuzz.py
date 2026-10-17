# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp
"""Feed broken C/C++ to the parser and check that it survives.

The IDE parses every file the user opens, with its headers, so malformed
input must not crash it, hang it or leak memory. This builds parsertest with
runtime checks (range, overflow, stack, objects) and heaptrc, then runs it on:
  - hand-written nasty cases (unterminated comments and strings, includes of
    themselves, recursive macros, deep nesting, huge lines, binary data...)
  - random mutations of the test's sample files (fixed seed, reproducible)
A case fails when parsertest exits with an error, reports that the parser
stopped early, takes longer than the time limit, or leaks memory.
Failing inputs are kept in build/fuzz-failures/.

usage: python3 fuzz.py [--mutations N] [--seed S] [--timeout SECONDS] [--no-build]
"""
import argparse
import os
import random
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, 'build')
BINARY = os.path.join(BUILD, 'parsertest')
CHECKS = '-Cr -Co -Ct -CR -Sa -gh -gl'


def nasty_cases():
    """(name, {file: content}) pairs; the first file is the one parsed."""
    deep = 3000
    yield 'empty', {'main.cpp': b''}
    yield 'only-hash', {'main.cpp': b'#'}
    yield 'unterminated-comment', {'main.cpp': b'int a; /* never closed\nint b;'}
    yield 'unterminated-string', {'main.cpp': b'const char *s = "never closed\nint b;'}
    yield 'unterminated-char', {'main.cpp': b"char c = '\nint b;"}
    yield 'unterminated-raw-string', {'main.cpp': b'auto s = R"x(never closed\nint b;'}
    yield 'backslash-at-eof', {'main.cpp': b'#define A 1 \\'}
    yield 'if-without-endif', {'main.cpp': b'#if 1\nint a;\n#if 0\nint b;'}
    yield 'endif-without-if', {'main.cpp': b'#endif\n#else\n#elif 1\nint a;'}
    yield 'include-nothing', {'main.cpp': b'#include\n#include <\n#include "\n#include <>\n#include ""'}
    yield 'include-self', {'main.cpp': b'#include "main.cpp"\nint a;'}
    yield 'include-cycle', {'main.cpp': b'#include "a.h"\nint m;', 'a.h': b'#include "b.h"\nint a;',
                            'b.h': b'#include "a.h"\nint b;'}
    yield 'include-missing', {'main.cpp': b'#include "does/not/exist.h"\n#include <nope.h>\nint a;'}
    yield 'macro-self', {'main.cpp': b'#define A A\nint A;\n#if A\nint b;\n#endif'}
    yield 'macro-cycle', {'main.cpp': b'#define A B\n#define B A\nint A;\n#if A == B\nint c;\n#endif'}
    yield 'macro-malformed', {'main.cpp': b'#define\n#define F(\n#define G(a,\n#define H(a) a##\nint F(1);'}
    yield 'macro-many-args', {'main.cpp': b'#define M(' + b','.join(b'a%d' % i for i in range(2000)) + b') a0\nint x = M(1);'}
    yield 'if-garbage', {'main.cpp': b'#if )(\n#elif ((\n#elif && ||\n#elif 1 / 0\n#elif 0 % 0\n#endif\nint a;'}
    yield 'if-overflow', {'main.cpp': b'#if 9223372036854775807 + 1\nint a;\n#endif\n'
                                       b'#if -9223372036854775807 - 2\nint b;\n#endif\n'
                                       b'#if 4611686018427387904 * 4\nint c;\n#endif\n'
                                       b'#if 99999999999999999999999\nint d;\n#endif'}
    yield 'if-deep-parens', {'main.cpp': b'#if ' + b'(' * deep + b'1' + b')' * deep + b'\nint a;\n#endif'}
    yield 'deep-braces', {'main.cpp': b'void f() ' + b'{' * deep + b'}' * deep}
    yield 'deep-unclosed-braces', {'main.cpp': b'class A ' + b'{' * deep}
    yield 'deep-close-braces', {'main.cpp': b'}' * deep + b'int a;'}
    yield 'deep-templates', {'main.cpp': b'A' + b'<A' * deep + b'>' * deep + b' x;'}
    yield 'deep-parens', {'main.cpp': b'int x = ' + b'(' * deep + b'1' + b')' * deep + b';'}
    yield 'deep-namespaces', {'main.cpp': b'namespace a {' * 500 + b'int x;' + b'}' * 500}
    yield 'huge-line', {'main.cpp': b'int a = ' + b'1 + ' * 250000 + b'1;'}
    yield 'huge-identifier', {'main.cpp': b'int ' + b'x' * 1000000 + b';'}
    yield 'many-lines', {'main.cpp': b'int a;\n' * 200000}
    yield 'binary', {'main.cpp': bytes(random.Random(1).randrange(256) for _ in range(200000))}
    yield 'nul-bytes', {'main.cpp': b'int a;\0\0\0class B {\0};\0'}
    yield 'utf8-and-bom', {'main.cpp': '﻿int año = 1; // ñandú 🐧\nclass Ünïcode { int ß; };'.encode()}
    yield 'invalid-utf8', {'main.cpp': b'int a\xff\xfe = 1; class \xc3 { };'}
    yield 'line-endings', {'main.cpp': b'int a;\r\nint b;\rint c;\n\r\n#define X 1\r#if X\rint d;\r#endif'}
    yield 'operators-only', {'main.cpp': b':: :: ::; operator operator; template template; ->*.* ... &&& |||'}
    yield 'keywords-only', {'main.cpp': b'class struct union enum typedef template typename using namespace public: '
                                        b'private: protected: virtual static const inline friend operator'}
    yield 'class-garbage', {'main.cpp': b'class { ; struct ; enum { , , }; typedef ; template <> class; '
                                        b'class A : public { }; class B : , , { }; using = ;'}
    yield 'function-garbage', {'main.cpp': b'int f(,,,); int g(int a, ...; void h() -> ; auto i() -> int -> int;'}
    yield 'unbalanced-mix', {'main.cpp': b'class A { void f( { int x[ ; } ); }; ] ) }'}


TOKENS = [b'{', b'}', b'(', b')', b'<', b'>', b'[', b']', b';', b',', b'::', b'#', b'"', b"'", b'/*', b'*/', b'//',
          b'\\', b'\n', b'\t', b' ', b'#if 1\n', b'#if 0\n', b'#else\n', b'#endif\n', b'#define X(a) a\n',
          b'#include "x.h"\n', b'template', b'class', b'struct', b'operator', b'const', b'&&', b'...', b'=']


def mutate(rnd, data):
    data = bytearray(data)
    for _ in range(rnd.randint(1, 12)):
        op = rnd.randrange(4)
        pos = rnd.randrange(len(data) + 1)
        if op == 0 and data:  # delete a chunk
            del data[pos:pos + rnd.randint(1, 40)]
        elif op == 1:  # insert a token
            data[pos:pos] = rnd.choice(TOKENS)
        elif op == 2 and data:  # duplicate a chunk
            start = rnd.randrange(len(data))
            data[pos:pos] = data[start:start + rnd.randint(1, 200)]
        else:  # random bytes
            data[pos:pos] = bytes(rnd.randrange(256) for _ in range(rnd.randint(1, 8)))
    return bytes(data)


def run_case(name, files, workdir, timeout, failures):
    if os.path.isdir(workdir):
        shutil.rmtree(workdir)
    os.makedirs(workdir)
    for f, content in files.items():
        with open(os.path.join(workdir, f), 'wb') as o:
            o.write(content)
    main = os.path.join(workdir, next(iter(files)))
    problem = None
    try:
        p = subprocess.run([BINARY, '--no-system', main], capture_output=True, timeout=timeout, cwd=workdir)
        out = p.stdout.decode('latin-1') + p.stderr.decode('latin-1')
        leaks = re.search(r'(\d+) unfreed memory blocks', out)
        stopped = re.search(r'Parser stopped early: (.*)', out)
        runtime = re.search(r'Runtime error \d+|An unhandled exception[^\n]*', out)
        if stopped:
            problem = 'parser stopped early: ' + stopped.group(1).strip()
        elif runtime:
            problem = runtime.group(0)
        elif p.returncode != 0:
            problem = f'exit code {p.returncode}'
        elif leaks and leaks.group(1) != '0':
            problem = f'{leaks.group(1)} unfreed memory blocks'
    except subprocess.TimeoutExpired:
        problem = f'no result after {timeout} s (hang or too slow)'
    if problem:
        keep = os.path.join(BUILD, 'fuzz-failures', name)
        if os.path.isdir(keep):
            shutil.rmtree(keep)
        shutil.copytree(workdir, keep)
        failures.append((name, problem))
        print(f'  FAIL {name}: {problem}')
    return problem is None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--mutations', type=int, default=300)
    ap.add_argument('--seed', type=int, default=2026)
    ap.add_argument('--timeout', type=float, default=20)
    ap.add_argument('--no-build', action='store_true')
    args = ap.parse_args()

    if not args.no_build:
        env = dict(os.environ, FPCFLAGS=CHECKS)
        shutil.rmtree(BUILD, ignore_errors=True)
        b = subprocess.run(['sh', os.path.join(HERE, 'build.sh')], env=env, capture_output=True, text=True)
        if b.returncode != 0:
            print(b.stdout[-3000:], b.stderr[-3000:])
            sys.exit('parsertest did not build')
    shutil.rmtree(os.path.join(BUILD, 'fuzz-failures'), ignore_errors=True)
    workdir = os.path.join(BUILD, 'fuzz-work')
    failures = []

    cases = list(nasty_cases())
    print(f'Hand-written cases: {len(cases)}')
    passed = sum(run_case(name, files, workdir, args.timeout, failures) for name, files in cases)

    rnd = random.Random(args.seed)
    seeds = [open(os.path.join(HERE, f), 'rb').read() for f in ('sample.cpp', 'preprocessor.cpp')]
    print(f'Mutations: {args.mutations} (seed {args.seed})')
    for i in range(args.mutations):
        data = mutate(rnd, rnd.choice(seeds))
        passed += run_case(f'mutation-{i:04d}', {'main.cpp': data, 'x.h': b'int fromheader;'},
                           workdir, args.timeout, failures)

    total = len(cases) + args.mutations
    print(f'\n{passed} of {total} cases passed')
    if failures:
        print(f'failing inputs: {os.path.join(BUILD, "fuzz-failures")}')
    sys.exit(1 if failures else 0)


main()
