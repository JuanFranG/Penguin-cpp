# SPDX-License-Identifier: MIT
import errno, os, pty, select, subprocess, sys, termios, time
master, slave = pty.openpty()
original = termios.tcgetattr(slave)
process = subprocess.Popen([sys.argv[1]],stdin=slave,stdout=slave,stderr=slave,close_fds=True)
output = b''
try:
    deadline=time.monotonic()+10
    sent=False
    while time.monotonic()<deadline:
        if select.select([master],[],[],0.05)[0]:
            try: chunk=os.read(master,4096)
            except OSError as error:
                if error.errno==errno.EIO: break
                raise
            if not chunk: break
            output+=chunk
            if b'READY 0' in output and not sent:
                os.write(master,b'Q');sent=True
        if process.poll() is not None: break
    code=process.wait(timeout=2)
    assert code==0,(code,output)
    assert b'READY 0' in output and b'KEY 81' in output,output
    restored=termios.tcgetattr(slave)
    # Darwin sets PENDIN when returning to canonical mode. It is pending
    # input state maintained by the kernel, not a caller-controlled setting.
    pending=getattr(termios,'PENDIN',0)
    expected=list(original);actual=list(restored)
    expected[3]&=~pending;actual[3]&=~pending
    assert actual==expected,('terminal settings were not restored',expected,actual)
    print('PASS: bits/STL, kbhit, _getch without Enter, terminal settings restored')
finally:
    if process.poll() is None: process.kill();process.wait()
    os.close(master);os.close(slave)
