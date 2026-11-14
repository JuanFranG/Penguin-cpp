#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Collect pinned upstream source archives for review; never build or execute them.

Creates a source inventory, not an automatic redistribution approval.
GitHub submodule revisions are read from each exact tree, including nested ones.
"""
import argparse,configparser,concurrent.futures,hashlib,json,subprocess,tarfile,time,urllib.request
from pathlib import Path
from urllib.parse import urlparse

ROOT_REPO='metalsharp/MetalSharp-Wine'
ROOT_REV='c06b0d2c4d58d51e4f2f4367089792b9051673ba'

def api(path):
    return json.loads(subprocess.check_output(['gh','api',path],text=True))

def fetch_unlocked(url,path):
    if not path.exists():
        partial=path.with_name(path.name+'.part')
        for attempt in range(3):
            try:
                with urllib.request.urlopen(url,timeout=90) as response,partial.open('wb') as stream:
                    while True:
                        block=response.read(1024*1024)
                        if not block: break
                        stream.write(block)
                partial.replace(path);break
            except Exception:
                if attempt==2: raise
                time.sleep(1)
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''):h.update(block)
    return h.hexdigest()

def fetch(url,path):
    import fcntl
    with path.with_name(path.name+'.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        return fetch_unlocked(url,path)

def github_repo(url,parent):
    if url.startswith('../'):
        url='https://github.com/'+parent+'/'+url
        # Normalize Git's relative sibling URL.
        import posixpath
        url='https://github.com/'+posixpath.normpath(url.removeprefix('https://github.com/'))
    if url.startswith('git@github.com:'):url='https://github.com/'+url.split(':',1)[1]
    if not url.startswith('https://github.com/'):raise ValueError('Review non-GitHub submodule URL: '+url)
    return url.removeprefix('https://github.com/').removesuffix('.git').rstrip('/')

def collect_one(item,out):
    repo,rev,location=item
    name=repo.replace('/','--')+'--'+rev+'.tar.gz'
    url='https://codeload.github.com/'+repo+'/tar.gz/'+rev
    path=out/'archives'/name
    checksum=fetch(url,path)
    tree=api('repos/'+repo+'/git/trees/'+rev+'?recursive=1')
    if tree.get('truncated'):raise ValueError('Truncated git tree: '+repo+' '+rev)
    children=[e for e in tree['tree'] if e['type']=='commit']
    modules={}
    with tarfile.open(path,'r:gz') as archive:
        members=archive.getmembers()
        gm=next((m for m in members if m.name.count('/')==1 and m.name.endswith('/.gitmodules')),None)
        if gm:
            cfg=configparser.ConfigParser();cfg.read_string(archive.extractfile(gm).read().decode())
            modules={cfg[s]['path']:cfg[s]['url'] for s in cfg.sections()}
    nested=[]
    for e in children:
        if e['path'] not in modules:raise ValueError('Submodule URL absent: '+repo+' '+e['path'])
        if repo==ROOT_REPO and e['path']=='src/wine-x86_64':continue
        nested.append((github_repo(modules[e['path']],repo),e['sha'],location+'/'+e['path']))
    print('Collected',location,repo,rev[:12],flush=True)
    return {'repository':repo,'revision':rev,'location':location,'url':url,'archive':name,'sha256':checksum,'bytes':path.stat().st_size},nested

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=Path,required=True)
    p.add_argument('--additional',type=Path,help='Additional reviewed pinned git source entries')
    p.add_argument('--resume',action='store_true',help='Reuse previously collected source records')
    a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);(a.out/'archives').mkdir(exist_ok=True)
    pending=[(ROOT_REPO,ROOT_REV,'MetalSharp-Wine')]
    if a.additional:
        pending.extend((x['repository'],x['revision'],x['location']) for x in json.loads(a.additional.read_text()))
    seen=set();records=[];errors=[]
    previous=a.out/'git-sources.json'
    if a.resume and previous.exists():
        cached=json.loads(previous.read_text())
        records=[x for x in cached['sources'] if (a.out/'archives'/x['archive']).is_file()]
        seen={(x['repository'],x['revision'],x['location']) for x in records}
    while pending:
        batch=[]
        for item in pending:
            if item not in seen:seen.add(item);batch.append(item)
        pending=[]
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            futures={pool.submit(collect_one,x,a.out):x for x in batch}
            for f in concurrent.futures.as_completed(futures):
                try:
                    record,children=f.result();records.append(record);pending.extend(children)
                except Exception as e:errors.append({'item':futures[f],'error':str(e)});print('REVIEW BLOCKER',futures[f],str(e),flush=True)
        (a.out/'git-sources.json').write_text(json.dumps({'root_revision':ROOT_REV,'sources':records,'errors':errors},indent=2)+'\n')
    if errors:raise SystemExit(1)
if __name__=='__main__':main()
