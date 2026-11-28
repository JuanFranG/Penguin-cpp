import argparse, pathlib, tempfile, subprocess, json, re, time, struct
parser = argparse.ArgumentParser(description="Capture English welcome/editor views from an isolated installed Penguin cpp instance.")
parser.add_argument("fixture", type=pathlib.Path, help="Disposable fixture produced by manualcapture")
parser.add_argument("--app", default="/Applications/Penguin cpp.app/Contents/MacOS/penguin-cpp")
args = parser.parse_args()
root=pathlib.Path.cwd();work=pathlib.Path(tempfile.mkdtemp(prefix='penguin-manual-main-'));base=args.fixture.resolve()
config=(base/'config.ini').read_text();config=re.sub(r'(?m)^AutoOpen=.*$','AutoOpen=0',config);(work/'penguin-cpp.ini').write_text(config)
for name in ['main.cpp','calculator.cpp','calculator.h','Tutorial.dev']:(work/name).write_bytes((base/name).read_bytes())
app=args.app;log=open(work/'capture.log','wb');p=subprocess.Popen([app,'-c',str(work)],cwd=work,stdout=log,stderr=log)
js='''ObjC.import('CoreGraphics'); function run(argv) { var a=ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(1,0))); return JSON.stringify(a.filter(w=>w.kCGWindowOwnerPID===Number(argv[0]) && w.kCGWindowLayer===0 && w.kCGWindowBounds.Width>500).map(w=>({id:w.kCGWindowNumber,name:w.kCGWindowName}))); }'''
def capture(name):
 for _ in range(40):
  wins=json.loads(subprocess.check_output(['osascript','-l','JavaScript','-e',js,str(p.pid)],text=True))
  if wins:break
  time.sleep(.25)
 assert wins,'No visible main window'
 subprocess.run(['osascript','-e',f'tell application "System Events" to set frontmost of (first application process whose unix id is {p.pid}) to true'],check=True)
 time.sleep(.4)
 path=root/'Manual/assets/windows'/f'{name}.png'
 subprocess.run(['/usr/sbin/screencapture','-x','-o','-l',str(wins[0]['id']),str(path)],check=True)
 width,height=struct.unpack('>II',path.read_bytes()[16:24]);print(name,width,height)
 cat=root/'Manual/assets/windows/captures.tsv';lines=cat.read_text().splitlines();cat.write_text('\n'.join(f'{name}\tTMainForm\t{wins[0].get("name",name)}\t{width}\t{height}' if l.startswith(name+'\t') else l for l in lines)+'\n')
try:
 time.sleep(2);capture('welcome')
 subprocess.run([app,'-c',str(work),str(work/'Tutorial.dev'),str(work/'main.cpp')],cwd=work,timeout=15,check=True,stdout=log,stderr=log)
 time.sleep(1);capture('workspace')
 subprocess.run([app,'-c',str(work),str(work/'calculator.h')],cwd=work,timeout=15,check=True,stdout=log,stderr=log)
 time.sleep(.5);capture('header')
finally:
 p.terminate()
 try:p.wait(timeout=10)
 except subprocess.TimeoutExpired:p.kill();p.wait()
