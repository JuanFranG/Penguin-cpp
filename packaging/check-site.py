#!/usr/bin/env python3
"""Check the static page and the resources copied into the APT website."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote

root = Path(__file__).resolve().parent
class Page(HTMLParser):
    def __init__(self):
        super().__init__(); self.ids = set(); self.refs = []; self.tabs = []; self.images = 0
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if 'id' in a:
            assert a['id'] not in self.ids, 'Duplicate id: ' + a['id']
            self.ids.add(a['id'])
        for attr in ('src', 'href'):
            if attr in a: self.refs.append(a[attr])
        if a.get('role') == 'tab': self.tabs.append(a['aria-controls'])
        if tag == 'img':
            assert 'alt' in a and a.get('width') and a.get('height'), 'Image lacks alt or dimensions'
            self.images += 1
page = Page(); page.feed((root/'apt-repo-index.html').read_text())
for ref in page.refs:
    u = urlsplit(ref)
    if u.scheme or u.netloc: continue
    if not u.path:
        assert unquote(u.fragment) in page.ids, 'Missing anchor: ' + ref
    else:
        target = root/'site'/u.path
        if u.path.startswith('manual/'): target = root.parent/'Manual'/u.path.removeprefix('manual/')
        assert target.exists(), 'Missing resource: ' + ref
for panel in page.tabs: assert panel in page.ids, 'Missing tab panel: ' + panel
assert page.images >= 4
css = (root/'site/site.css').read_text()
assert 'prefers-reduced-motion' in css and 'prefers-color-scheme' in css
assert ':focus-visible' in css
assert 'localStorage' not in (root/'site/site.js').read_text()
assert 'data-theme' not in (root/'apt-repo-index.html').read_text()
assert 'cp -R "$HERE/site/." ./' in (root/'update-apt-repo.sh').read_text()
print('OK: page anchors, images, tab panels, themes and deployment resources')
