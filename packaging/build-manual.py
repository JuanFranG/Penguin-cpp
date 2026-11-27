#!/usr/bin/env python3
"""Render both window references from descriptions and shared English screenshots."""
import json, struct, html
from pathlib import Path
root = Path(__file__).resolve().parent.parent
manual = root/'Manual'
e = html.escape
rows = json.loads((manual/'windows.json').read_text())
spanish = json.loads((manual/'windows.es.json').read_text())
assert set(spanish) == {item['id'] for item in rows}
groups = {'Basics':'General', 'Projects':'Proyectos', 'Settings':'Opciones', 'Tools':'Herramientas', 'Windows':'Windows'}
for language, page, prefix in [('en', manual/'index.html', ''), ('es', manual/'es/index.html', '../')]:
    cards = []
    for original in rows:
        item = dict(original)
        if language == 'es':
            translation = dict(spanish[item['id']])
            assert {'title', 'purpose', 'controls', 'result'} <= translation.keys(), item['id']
            descriptions = translation.pop('controls')
            assert len(descriptions) == len(item['controls']), item['id']
            item.update(translation)
            item['group'] = groups[item['group']]
            item['controls'] = [(label, text) for (label, _), text in zip(original['controls'], descriptions)]
            assert not original['note'] or 'note' in translation, item['id']
        image = manual/'assets/windows'/item['image']
        data = image.read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n', image
        width, height = struct.unpack('>II', data[16:24])
        controls = ''.join('<dt translate="no">'+e(k)+'</dt><dd>'+e(v)+'</dd>' for k,v in item['controls'])
        src = prefix+'assets/windows/'+item['image']
        alt = item['title'] + (' en Penguin cpp 0.5.6 para macOS, con la interfaz en inglés.' if language == 'es' else ' in Penguin cpp 0.5.6 on macOS, with the English interface.')
        caption = 'Abrir captura a tamaño completo' if language == 'es' else 'Open full-size screenshot'
        interface = 'Interfaz en inglés' if language == 'es' else 'English UI'
        open_label = 'Abrir:' if language == 'es' else 'Open:'
        note = '<p class="window-note">'+e(item['note'])+'</p>' if item['note'] else ''
        cards.append(f'''<article class="window-card" id="window-{e(item['id'])}"><header class="window-title"><h3>{e(item['title'])}</h3><span class="window-group">{e(item['group'])}</span></header><div class="window-layout"><figure class="screenshot"><a href="{src}" data-viewer><img src="{src}" width="{width}" height="{height}" loading="lazy" decoding="async" alt="{e(alt)}"></a><figcaption><a href="{src}" data-full-image>{caption}</a> · {interface}</figcaption></figure><div class="window-text"><p class="open-path"><strong>{open_label}</strong> <span translate="no">{e(item['open'])}</span></p><p>{e(item['purpose'])}</p><dl class="control-list">{controls}</dl><p class="outcome">{e(item['result'])}</p>{note}</div></div></article>''')
    text = page.read_text(); start='<!-- START WINDOWS -->'; end='<!-- END WINDOWS -->'
    a, tail = text.split(start,1); _, b = tail.split(end,1)
    page.write_text(a+start+'\n'+'\n'.join(cards)+'\n'+end+b)
    print(f'Rendered {len(cards)} illustrated window views ({language})')
