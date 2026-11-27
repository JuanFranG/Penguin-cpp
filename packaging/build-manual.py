#!/usr/bin/env python3
"""Render the static window reference from editable descriptions and real PNG dimensions."""
import json, struct, html
from pathlib import Path
root = Path(__file__).resolve().parent.parent
manual = root/'Manual'
e = html.escape
cards = []
for item in json.loads((manual/'windows.json').read_text()):
    image = manual/'assets/windows'/item['image']
    data = image.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', image
    width, height = struct.unpack('>II', data[16:24])
    controls = ''.join('<dt translate="no">'+e(k)+'</dt><dd>'+e(v)+'</dd>' for k,v in item['controls'])
    src = 'assets/windows/'+item['image']
    alt = item['title']+' in Penguin cpp 0.5.6 on macOS, with the English interface.'
    note = '<p class="window-note">'+e(item['note'])+'</p>' if item['note'] else ''
    cards.append(f'''<article class="window-card" id="window-{e(item['id'])}"><header class="window-title"><h3>{e(item['title'])}</h3><span class="window-group">{e(item['group'])}</span></header><div class="window-layout"><figure class="screenshot"><a href="{src}" data-viewer><img src="{src}" width="{width}" height="{height}" loading="lazy" decoding="async" alt="{e(alt)}"></a><figcaption><a href="{src}" data-full-image>Open full-size screenshot</a> · English UI</figcaption></figure><div class="window-text"><p class="open-path"><strong>Open:</strong> <span translate="no">{e(item['open'])}</span></p><p>{e(item['purpose'])}</p><dl class="control-list">{controls}</dl><p class="outcome">{e(item['result'])}</p>{note}</div></div></article>''')
p = manual/'index.html'
text = p.read_text(); start='<!-- START WINDOWS -->'; end='<!-- END WINDOWS -->'
a, tail = text.split(start,1); _, b = tail.split(end,1)
p.write_text(a+start+'\n'+'\n'.join(cards)+'\n'+end+b)
print(f'Rendered {len(cards)} illustrated window views')
