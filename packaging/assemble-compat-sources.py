#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Verify collected source inputs and assemble the reviewed source/notice bundle.

This implements a recorded inventory; it does not infer licenses from filenames.
The component decisions and exclusions are documented in Compat/REDISTRIBUTION.md.
"""
import argparse,hashlib,json,os,re,shutil,subprocess,tarfile
from pathlib import Path

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
    return h.hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--inputs',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();repo=Path(__file__).resolve().parent.parent
    if a.out.exists():p.error('Choose a new output directory')
    git=json.loads((a.inputs/'git-sources.json').read_text())
    deps=json.loads((a.inputs/'dependency-sources.json').read_text())
    local=json.loads((a.inputs/'local-source-inputs.json').read_text())
    if git['errors'] or deps['errors']:p.error('Source collection is incomplete')
    excluded=[];records=[]
    for x in git['sources']:
        if x['location'].endswith(('src/linuxhost','External/fex-gcc-target-tests-bins','External/fex-posixtest-bins')):
            excluded.append(dict(x,reason='Unshipped optional Linux anticheat host, or unneeded prebuilt test inputs'));continue
        records.append(dict(x,component=x['repository'],kind='git'))
    records += [dict(x,archive=x['filename'],kind='dependency') for x in deps['sources']]
    records += [dict(x,kind='project') for x in local]
    for x in records:
        src=a.inputs/'archives'/x['archive']
        if not src.is_file() or sha(src)!=x['sha256']:p.error('Invalid source input: '+str(src))
    make=repo/'build/compat-sources/make-4.4.1.tar.gz'
    if sha(make)!='dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3':p.error('Unpinned Make source')
    a.out.mkdir(parents=True);archives=a.out/'archives';archives.mkdir();notices=a.out/'NOTICES';notices.mkdir()
    copies={}
    for x in records:
        src=a.inputs/'archives'/x['archive'];dest=archives/x['archive']
        if not dest.exists():shutil.copy2(src,dest)
        copies[x['archive']]=x
    shutil.copy2(make,archives/make.name)
    records.append({'component':'GNU Make','version':'4.4.1','kind':'dependency','archive':make.name,'sha256':sha(make),'bytes':make.stat().st_size})
    astyle=repo/'build/release-0.5.0/astyle-3.6.20.tar.bz2'
    if sha(astyle)!='b058f3e176334dba65477fd126105d3df4eab9e954eab1c76b568cd5370cfbe9':p.error('Unpinned AStyle source')
    shutil.copy2(astyle,archives/astyle.name)
    records.append({'component':'AStyle','version':'3.6.20','kind':'dependency','archive':astyle.name,'sha256':sha(astyle),'bytes':astyle.stat().st_size})
    notice_index=[]
    for path in sorted(archives.iterdir()):
        directory=notices/path.name.replace('.tar.gz','').replace('.tar.xz','').replace('.tar.bz2','')
        directory.mkdir()
        with tarfile.open(path,'r:*') as t:
            for m in t.getmembers():
                base=Path(m.name).name.lower()
                is_notice=('licen' in base or base.startswith(('copying','copyright','notice')) or base in ('authors','authors.txt','ftl.txt','gplv2.txt'))
                # Preserve NVIDIA's header copyright/permission notices as well.
                if path.name.startswith('NVIDIA--nvapi--') and base.endswith('.h'):is_notice=True
                if not (m.isfile() and is_notice):continue
                if m.size>8*1024*1024:raise ValueError('Unexpectedly large notice: '+m.name)
                rel=m.name.split('/',1)[-1]
                parts=Path(rel).parts
                if '..' in parts or Path(rel).is_absolute():raise ValueError('Unsafe archive notice path')
                dst=directory/rel;dst.parent.mkdir(parents=True,exist_ok=True)
                dst.write_bytes(t.extractfile(m).read())
                notice_index.append({'archive':path.name,'source_path':m.name,'notice':str(dst.relative_to(a.out)),'sha256':sha(dst)})
    shutil.copy2(a.inputs/'fpc-generated-revision.patch',a.out/'fpc-generated-revision.patch')
    build=a.out/'penguin-packaging';build.mkdir()
    for file in ['prepare-windows-runtime.py','build-compat-make.sh','build-macos-pkg.py','collect-runtime-sources.py','assemble-compat-sources.py']:
        shutil.copy2(repo/'packaging'/file,build/file)
    shutil.copy2(repo/'packaging/bootstrap-macos-ci.sh',build/'bootstrap-macos-ci.sh')
    shutil.copy2(repo/'packaging/install-macos.sh',build/'install-macos.sh')
    shutil.copy2(repo/'Compat/REDISTRIBUTION.md',a.out/'REDISTRIBUTION.md')
    inventory={'schema':1,'profile':'penguin-windows-foss-1','upstream_runtime_sha256':'574199696623371d6c4abfe5d242c86403cc4ba4b4b5643f5e6187a6d5b86d4b','sources':records,'excluded_source_inputs':excluded,'notices':notice_index,
               'binary_exclusions':['share/metalsharp','share/wine/shadercompilers','share/wine/mono','share/wine/gecko','lib/libmetalirconverter.dylib','lib/linuxhost']}
    (a.out/'SOURCE-INDEX.json').write_text(json.dumps(inventory,indent=2)+'\n')
    (a.out/'README.md').write_text('''# Penguin cpp 0.5.0 — corresponding sources and build inputs

This archive accompanies the COMPLETE binary packages. SOURCE-INDEX.json lists
source archives, exact revisions/checksums and their original locations. Every
archive checksum was verified before assembly. NOTICES/ preserves license,
copyright and attribution files; each component retains its own license.

The Penguin executable source is the v0.5.0 tag (2877c1f). Its native build uses
Lazarus 3.8 (57e899e4), FPC 3.2.4 rc2 (2a105860); the only FPC source-tree change
was the generated revision string, included as fpc-generated-revision.patch.
The archive also includes the pinned Make/AStyle sources and packaging recipes.

## Source layout and building

For each git entry, extract its archive with the top directory stripped into
its `location` in a fresh directory. Populate nested locations the same way.
The Wine/FEX/Mullion/WineMetalGL/WFDXCompat trees already contain their fork
changes. For VKD3D-Proton-MacOS, apply the patches recorded by its supplied
scripts/fetch-sources.sh to the listed sources; this includes MoltenVK and
its modified SPIRV-Cross revision. The per-source recipes, configuration flags,
patches, font rename script and staging code are supplied in the source trees.

Dependency release archives and versions match MetalSharp-Wine/scripts/build-deps.sh.
Place its cached downloads under downloads/<component>-<upstream-basename>.
The special cabextract, innoextract/Boost/xz and Liberation downloads are placed
as their supplied scripts describe. LLVM 15.0.7 is the static shader-conversion
build input; its recipe is scripts/build-llvm15.sh. LLVM-MinGW 20261104's builder
and MinGW-w64 ee9bd876 sources cover its gendef/widl tools and CRT. The compilers,
CMake, Meson, Ninja, zsh and Apple's officially installed SDK are build tools;
no Apple SDK or proprietary redistributable is supplied here.

Do not run upstream download/staging scripts indiscriminately: the original
project also supports optional proprietary components. Our binary profile
omits them. Rebuild the selected free components using the provided recipes,
then apply prepare-windows-runtime.py's exclusions and notice/source inventory.
Ad-hoc re-signing is recorded by the packager. Users may rebuild, replace and
re-sign these free components with their own changes; our package adds no
vendor signing requirement. Rebuilt output need not have identical signatures
or metadata to the downloaded binaries.

The optional linuxhost DLL is not shipped because its pinned source branch
has no explicit license notice. Unused prebuilt FEX test inputs are omitted.
Consequently this package does not promise Linux-module anticheat support.
The existing exclusions also omit Apple Metal Shader Converter/GPTK, FMOD,
Microsoft optional installers/shader SDKs and Mono/Gecko downloads. Microsoft
DirectXShaderCompiler's *open-source* DXBC converter is separate: its pinned
source/patches and NCSA/LLVM notices are provided.

Some shader/game paths depend on excluded optional components. This is an
experimental Windows x64 development environment, not full Windows/game API
compatibility. See the project's README and redistribution review for scope.
''')
    sums=[]
    for path in sorted(archives.iterdir()):sums.append(sha(path)+'  archives/'+path.name)
    (a.out/'SHA256SUMS').write_text('\n'.join(sums)+'\n')
    print('Verified source records:',len(records),'unique archives:',len(list(archives.iterdir())),'notice files:',len(notice_index),flush=True)

if __name__=='__main__':main()
