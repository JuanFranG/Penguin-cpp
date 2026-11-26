"""Run the actual macOS Terminal shell script in a private pseudo-terminal.
The mock open starts an independent session, as Terminal/LaunchServices does.
No user Terminal windows or AppleScript permissions are used.
"""
import os
import pathlib
import re
import signal
import subprocess
import sys
import tempfile
import time

if sys.platform != 'darwin':
    print('SKIP: macOS Terminal runner')
    raise SystemExit(0)

source = pathlib.Path(__file__).resolve().parents[2] / 'devPlatform.pas'
constant = source.read_text().split('  MacRunScript =', 1)[1].split('{$ENDIF}', 1)[0]
script = '\n'.join(s.replace("''", "'") for s in re.findall(r"'((?:[^']|'')*)'", constant))
with tempfile.TemporaryDirectory(prefix='penguin-terminal-test-') as temp:
    root = pathlib.Path(temp)

    runner = root / 'runner.py'
    runner.write_text('''import os, pty, sys, time
pid, fd = pty.fork()
if pid == 0: os.execv('/bin/zsh', ['zsh', '-f', sys.argv[1]])
time.sleep(.3)
os.write(fd, b'hello\\n')
try:
 while True:
  data = os.read(fd, 8192)
  if not data: break
  with open(sys.argv[1]+".log", "ab") as log: log.write(data)
except OSError: pass
os.waitpid(pid, 0)
''')
    mock_open = root / 'open'
    mock_open.write_text('#!' + sys.executable + '\nimport subprocess,sys\n' +
                        'subprocess.Popen([' + repr(sys.executable) + ', ' + repr(str(runner)) +
                        ', sys.argv[-1]], start_new_session=True, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n')
    mock_open.chmod(0o755)
    mock_osascript = root / 'osascript'
    mock_osascript.write_text('#!/bin/sh\nexit 0\n')
    mock_osascript.chmod(0o755)
    env = dict(os.environ, PATH=str(root) + ':' + os.environ['PATH'], TMPDIR=temp)
    def wait_file(path):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if path.exists(): return
            time.sleep(.02)
        raise AssertionError('timeout: ' + str(path))
    # Verify foreground input still works with job control enabled.
    output = root / 'input.txt'
    command = 'read -r line; echo "$line" > "' + str(output) + '"'
    try:
        subprocess.run(['/bin/zsh', '-f', '-c', script, 'penguin', '0', '%s %s', '', '/bin/sh', '-c', command], env=env, check=True, timeout=8)
    except Exception:
        for path in root.glob('**/run.command*'):
            print(path, path.read_text(), flush=True)
        raise
    assert output.read_text().strip() == 'hello', output.read_text()
    print('[OK] Terminal runner preserves keyboard input')
    child_file = root / 'child.pid'
    command = 'sleep 30 & echo $! > "' + str(child_file) + '"; wait'
    process = subprocess.Popen(['/bin/zsh', '-f', '-c', script, 'penguin', '0', '%s %s', '', '/bin/sh', '-c', command], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    child = None
    try:
        wait_file(child_file)
        child = int(child_file.read_text())
        process.terminate()
        process.communicate(timeout=5)
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            try: os.kill(child, 0)
            except ProcessLookupError: break
            time.sleep(.02)
        else: raise AssertionError('Terminal descendant survived Stop')
        print('[OK] Terminal runner stops descendants across LaunchServices session boundary')
    finally:
        if process.poll() is None: process.kill(); process.wait()
        if child:
            try: os.kill(child, signal.SIGKILL)
            except ProcessLookupError: pass
