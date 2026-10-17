# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp
"""Turn the IDE's text forms (.lfm) into input for the lfmcheck program.

usage: python3 lfmparse.py OUT_DIR SOURCE_DIR FILE.lfm...
  (FILE paths relative to SOURCE_DIR)

Writes to OUT_DIR:
  checks.tsv   one check per line (format described in LfmChecks.pas);
               problems found here (image data the LCL can't read) are
               passed on as X rows
  units.inc    the IDE's units, so lfmcheck links every form class
  classes.inc  every component class named in the forms, to register them
"""
import os
import re
import sys

# Units that declare component classes used by the forms but are not
# listed in penguin-cpp.lpr (they are used indirectly)
EXTRA_UNITS = ['CodeCompletionForm', 'devShortcutsEditorForm', 'ClassBrowser', 'CodeCompletion', 'CppParser',
               'CppPreprocessor', 'CppTokenizer', 'CompOptionsList', 'devFileMonitor', 'devShortcuts']
# Units lfmcheck.lpr already uses
SKIP_UNITS = {'cthreads', 'Interfaces', 'Forms', 'SysUtils', 'Classes'}


# Graphic classes TPicture can stream in the LCL; all are raster images
LCL_GRAPHICS = {'TBitmap', 'TPixmap', 'TPortableNetworkGraphic', 'TPortableAnyMapGraphic', 'TJPEGImage',
                'TGIFImage', 'TIcon', 'TCursorImage', 'TTiffImage', 'TIcnsIcon'}


def check_image_data(prop, data):
    """Return a problem with streamed image data, or None.

    The LCL writes a raster image as a 4-byte little-endian size followed by
    the file data; Delphi omits the size for icons and PNG images (TPngImage).
    """
    def sized(body):
        return len(body) >= 4 and int.from_bytes(body[:4], 'little') == len(body) - 4
    if prop == 'Picture.Data' or prop.endswith('.Picture.Data'):
        n = data[0] if data else 0
        cls = data[1:1 + n].decode('latin-1')
        if cls not in LCL_GRAPHICS:
            return f'{prop}: graphic class {cls} is not available in the LCL'
        if not sized(data[1 + n:]):
            return f'{prop}: {cls} data has no size prefix (Delphi format)'
    elif prop in ('Icon.Data', 'Glyph.Data') or prop.endswith(('.Icon.Data', '.Glyph.Data')):
        if not sized(data):
            return f'{prop}: image data has no size prefix (Delphi format)'
    elif prop == 'Bitmap':
        # TImageList data; Delphi's comctl32 stream ('IL') is misread by the LCL
        if data[:2] not in (b'Li', b'Lz', b'li', b'\x01\x00'):
            return f'{prop}: image list data is not in an LCL format (starts with {data[:2]!r})'
    return None


def binary_value(lines, i, first):
    """Bytes of a {...} value starting on line i."""
    parts = [first.strip().lstrip('{')]
    while not parts[-1].rstrip().endswith('}'):
        i += 1
        parts.append(lines[i].strip())
    return bytes.fromhex(''.join(parts).replace('}', ''))


def skip_value(lines, i, first):
    """Return the index after a (possibly multi-line) value starting on line i."""
    n = len(lines)
    v = first.strip()
    if v == '':  # value continues on next lines (string concatenation)
        i += 1
        while i < n and (lines[i].strip().startswith("'") or lines[i].strip().startswith('#')):
            cont = lines[i].rstrip().endswith('+')
            i += 1
            if not cont:
                break
        return i
    if v.startswith('{') and not v.endswith('}'):
        while i < n and '}' not in lines[i]:
            i += 1
        return i + 1
    if v.startswith('(') and not v.endswith(')'):
        depth = 0
        while i < n:
            depth += lines[i].count('(') - lines[i].count(')')
            if depth <= 0 and lines[i].rstrip().endswith(')'):
                break
            i += 1
        return i + 1
    if v.endswith('+'):
        i += 1
        while i < n and lines[i].rstrip().endswith('+'):
            i += 1
        return i + 1
    return i + 1


def parse(path, name):
    lines = open(path, 'rb').read().decode('latin-1').replace('\r\n', '\n').split('\n')
    out = []
    stack = []  # component classes, innermost last
    root = None
    i = 0
    n = len(lines)
    while i < n:
        s = lines[i].strip()
        if not s:
            i += 1
            continue
        m = re.match(r'(object|inherited|inline)\s+(\w*)\s*:\s*(\w+)', s)
        if m:
            cls = m.group(3)
            if root is None:
                root = cls
            out.append(('C', name, i + 1, cls))
            stack.append(cls)
            i += 1
            continue
        if s == 'end':
            if stack:
                stack.pop()
            i += 1
            continue
        pm = re.match(r'([\w.]+)\s*=\s*(.*)$', s)
        if pm and stack:
            prop, val = pm.group(1), pm.group(2).strip()
            cls = stack[-1]
            if val == '<' or (val.startswith('<') and not val.endswith('>')):
                # collection: items until the closing '>'
                i += 1
                while i < n:
                    t = lines[i].strip()
                    if t == 'item':
                        i += 1
                        continue
                    if t in ('end', 'end>'):
                        i += 1
                        if t == 'end>':
                            break
                        continue
                    im = re.match(r'([\w.]+)\s*=\s*(.*)$', t)
                    if im:
                        out.append(('I', name, i + 1, root, cls, prop, im.group(1), im.group(2).strip()))
                        i = skip_value(lines, i, im.group(2))
                        continue
                    i += 1
                continue
            out.append(('P', name, i + 1, root, cls, prop, val))
            if val.startswith('{'):
                problem = check_image_data(prop, binary_value(lines, i, val))
                if problem:
                    out.append(('X', name, i + 1, problem))
            i = skip_value(lines, i, val)
            continue
        i += 1
    return out


def ide_units(src):
    lpr = open(os.path.join(src, 'penguin-cpp.lpr'), 'rb').read().decode('latin-1')
    lpr = re.sub(r'//[^\n]*', '', lpr)
    uses = re.search(r'(?s)\buses\b(.*?);', lpr).group(1)
    uses = re.sub(r'\{\$[^}]*\}', '', uses)
    units = [u.strip().split()[0] for u in uses.split(',') if u.strip()]
    units += [u for u in EXTRA_UNITS if u not in units]
    return [u for u in units if u not in SKIP_UNITS]


def main():
    out_dir, src, files = sys.argv[1], sys.argv[2], sys.argv[3:]
    rows = []
    for f in files:
        rows += parse(os.path.join(src, f), f)
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, 'checks.tsv'), 'w') as o:
        for r in rows:
            o.write('\t'.join(str(x) for x in r) + '\n')
    with open(os.path.join(out_dir, 'units.inc'), 'w') as o:
        o.write('  ' + ',\n  '.join(ide_units(src)) + ',\n')
    classes = sorted({r[3] for r in rows if r[0] == 'C'})
    with open(os.path.join(out_dir, 'classes.inc'), 'w') as o:
        o.write(',\n'.join('    ' + c for c in classes) + '\n')
    print(f'{len(rows)} checks, {len(classes)} classes, {len(files)} forms')


main()
