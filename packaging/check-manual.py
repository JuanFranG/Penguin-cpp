#!/usr/bin/env python3
"""Check manual links, screenshot metadata and the rendered window inventory."""
import json, struct
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote
root=Path(__file__).resolve().parent.parent
manual=root/'Manual'
class Page(HTMLParser):
    def __init__(self):
        super().__init__();self.ids=set();self.refs=[];self.images=[];self.lang=None
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if tag=='html':self.lang=a.get('lang')
        if 'id' in a:
            assert a['id'] not in self.ids,a['id'];self.ids.add(a['id'])
        for key in ['src','href']:
            if key in a:self.refs.append(a[key])
        if tag=='img':self.images.append(a)
pages={}
for f in [manual/'index.html',manual/'en/index.html']:
    p=Page();p.feed(f.read_text());assert p.lang=='en';pages[f.resolve()]=p
for f,p in pages.items():
    for ref in p.refs:
        u=urlsplit(ref)
        if u.scheme or u.netloc:continue
        if ref=='#':continue
        target=(f.parent/unquote(u.path)).resolve() if u.path else f
        if target.is_dir():target/= 'index.html'
        assert target.exists(),(f,ref)
        if u.fragment and target in pages:assert unquote(u.fragment) in pages[target].ids,(f,ref)
    for a in p.images:
        assert a.get('alt') is not None,a
        if 'src' not in a:
            assert a.get('id')=='viewer-image';continue
        assert a.get('width') and a.get('height'),a
        target=f.parent/a['src']
        if target.suffix=='.png' and target.parent.name=='windows':
            w,h=struct.unpack('>II',target.read_bytes()[16:24]);assert (w,h)==(int(a['width']),int(a['height'])),a['src']
rows=json.loads((manual/'windows.json').read_text());p=pages[(manual/'index.html').resolve()]
assert len(rows)>=30 and len({x['id'] for x in rows})==len(rows)
for row in rows:
    assert 'window-'+row['id'] in p.ids,row['id']
    assert (manual/'assets/windows'/row['image']).is_file(),row['image']
css=(manual/'manual.css').read_text();js=(manual/'manual.js').read_text()
assert 'prefers-color-scheme' in css and 'prefers-reduced-motion' in css and ':focus-visible' in css
assert 'localStorage' not in js
assert 'manual.js' in (manual/'index.html').read_text()
print(f'OK: English manual, {len(rows)} illustrated views, real PNG dimensions, links and automatic theme')
