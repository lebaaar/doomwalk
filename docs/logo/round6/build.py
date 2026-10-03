"""Round 6: the Perspective ticks (round 5, variation 4) with fatter, tighter
bars, in two-colour palettes: one background hue and one glyph colour.
The glyph's lighter ticks are the same colour at lower opacity."""

PALETTES = [  # (file, name, bg top, bg bottom, glyph)
    ('01-glacier', 'Glacier', '#2584B8', '#0E4166', '#FFFFFF'),
    ('02-midnight', 'Midnight', '#1C2738', '#0A0F17', '#A6DCF4'),
    ('03-frost', 'Frost', '#FFFFFF', '#E2F0F8', '#0E4166'),
    ('04-teal', 'Teal', '#1FA396', '#0D5E58', '#FFFFFF'),
    ('05-indigo', 'Indigo', '#6B5BE2', '#3A2B9C', '#FFFFFF'),
    ('06-graphite', 'Graphite', '#3B4048', '#1C1F24', '#FFFFFF'),
    ('07-cyan', 'Cyan', '#12B8CC', '#0A7A92', '#FFFFFF'),
    ('08-forest', 'Forest', '#2E7C5A', '#174A34', '#D2F5E3'),
    ('09-paper', 'Ink on paper', '#FFFFFF', '#EFEFEF', '#141414'),
    ('10-coral', 'Coral', '#FF735E', '#DE4A3C', '#FFFFFF'),
]

def ticks(glyph):
    out, y = '', 40
    for i in range(6):
        w, h = 56 + i * 28, 12 + i * 4
        out += (f'<rect x="{128 - w / 2:.1f}" y="{y:.1f}" width="{w}" height="{h}" rx="{h / 2}" '
                f'fill="{glyph}" opacity="{0.32 + i * 0.136:.2f}"/>')
        y += h + 5 + i * 2
    return out

for f, name, top, bottom, glyph in PALETTES:
    open(f'{f}.svg', 'w').write(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256" role="img" aria-labelledby="title">\n'
        f'  <title id="title">Depth ticks, {name}</title>\n'
        f'  <defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>'
        '<filter id="shadow" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur in="SourceAlpha" stdDeviation="4"/><feOffset dy="4"/>'
        '<feComponentTransfer><feFuncA type="linear" slope="0.22"/></feComponentTransfer><feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>\n'
        f'  <rect width="256" height="256" fill="url(#bg)"/>\n  <g filter="url(#shadow)">{ticks(glyph)}</g>\n</svg>\n')
