"""Actual MinGW + Wine console contract, run in a private 120x40 PTY.
Usage: console_test.py --cc PATH --cxx PATH --runner PATH --prefix ISOLATED_PREFIX
Requires consolecommand built by build.sh. No changes to the user's Wine prefix.
"""
import argparse
import errno
import fcntl
import json
import os
from pathlib import Path
import pty
import re
import select
import signal
import struct
import subprocess
import tempfile
import termios
import time

parser = argparse.ArgumentParser()
for name in ('cc', 'cxx', 'runner', 'prefix'):
    parser.add_argument('--' + name, required=True)
args = parser.parse_args()
here = Path(__file__).resolve().parent
root = here.parents[2]
support = root / 'Compat/windows/console-startup.c'
def visible_text(data):
    text = data.decode('utf-8', errors='replace')
    # Wine's terminal driver emits cursor controls even between letters.
    text = re.sub(r'\x1b\[(\d*)C', lambda m: ' ' * int(m[1] or 1), text)
    return re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', text).replace('\r', '')

results = []
with tempfile.TemporaryDirectory(prefix='penguin-console-') as temporary:
    directory = Path(temporary)
    for cp, marker in [(65001, 'PRINTF_UTF8:Español: áéíóú ñ'), (437, 'PRINTF_BOX:┌─┐ █'), (1252, 'PRINTF_ANSI:Español á')]:
        obj = directory / ('startup-' + str(cp) + '.o')
        subprocess.run([args.cc, '-std=c11', '-c', str(support), '-DPENGUIN_CONSOLE_CP=' + str(cp), '-o', str(obj)], check=True)
        for compiler, language in [(args.cc, 'c'), (args.cxx, 'c++')]:
            program = directory / ('program with spaces $ literal-' + str(cp) + '-' + language.replace('+','p') + '.exe')
            subprocess.run([compiler, '-x', language, '-static', str(here / 'console_contract.c'), '-x', 'none', str(obj), '-o', str(program)], check=True)
            command = json.loads(subprocess.check_output([str(here / 'build/consolecommand'), args.runner, args.prefix, str(program), str(cp)], text=True))
            master, slave = pty.openpty()
            fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 120, 0, 0))
            state_file = directory / ('terminal-' + str(cp) + '-' + language.replace('+','p'))
            env = dict(os.environ, TERM='xterm-256color', PENGUIN_TERM_STATE=str(state_file))
            command = ['/bin/sh', '-c', 'stty -g > "$PENGUIN_TERM_STATE.before"; "$@"; result=$?; stty -g > "$PENGUIN_TERM_STATE"; exit "$result"', 'pty-holder', *command]
            def own_terminal():
                os.setsid()
                fcntl.ioctl(0, termios.TIOCSCTTY, 0)
            process = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave, env=env, preexec_fn=own_terminal)
            data = b''
            sent = False
            deadline = time.monotonic() + 30
            try:
                while time.monotonic() < deadline:
                    if select.select([master], [], [], .1)[0]:
                        try:
                            block = os.read(master, 65536)
                        except OSError as error:
                            if error.errno == errno.EIO: break
                            raise
                        if not block: break
                        data += block
                        (here/'build/console-live.log').write_bytes(data)
                        if 'INPUT_READY' in visible_text(data) and not sent:
                            os.write(master, 'niño\r'.encode('utf-8')); sent = True
                    if process.poll() is not None and not select.select([master], [], [], .05)[0]: break
                if process.poll() is None: raise AssertionError('console test timeout')
                text = data.decode('utf-8', errors='replace')
                (here / 'build' / ('console-' + str(cp) + '-' + language.replace('+', 'p') + '.log')).write_bytes(data)
                assert process.returncode == 0, (cp, language, process.returncode, text)
                # Ignore terminal control sequences when checking visible text.
                visible = visible_text(data)
                assert marker in visible, (marker, visible)
                for expected in ('WIDE: Español ┌─┐', 'EXPLICIT: Español', 'NUMBER:1.5', 'INPUT_OK:niño', 'CONSOLE_CONTRACT_OK'):
                    assert expected in visible, (expected, visible)
                if language == 'c++': assert 'CPP_UTF8:Español' in visible, visible
                assert b'\x1b[91m' in data and b'\x1b[44m' in data, ('foreground/background attributes', text)
                assert data.rstrip().endswith(b'\x1b[0m'), ('launcher restores style', text)
                before = Path(str(state_file) + '.before').read_text().strip()
                after = state_file.read_text().strip()
                def stable_mode(value):
                    # BSD sets PENDIN when returning to canonical input; it is queue state.
                    return re.sub(r'lflag=([0-9a-f]+)', lambda match: 'lflag=' + format(int(match[1], 16) & ~getattr(termios, 'PENDIN', 0), 'x'), value)
                assert stable_mode(after) == stable_mode(before), ('launcher restores keyboard mode', before, after)
                results.append(dict(codepage=cp, language=language, result='passed', crt_utf8_available='CRT_UTF8_AVAILABLE:1' in visible))
                print('[OK]', cp, language, 'characters, input, cursor, colors, explicit override and terminal restoration', flush=True)
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGKILL); process.wait()
                os.close(master); os.close(slave)
(here / 'build/console-results.json').write_text(json.dumps(results, indent=2))
