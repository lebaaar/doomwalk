"""Round 5: variations on Depth ticks (round 4, I), and colour schemes.
variants/ = ten shapes in Glacier blue; colors/ = one shape in ten palettes."""

PALETTES = {  # name: (bg top, bg bottom, glyph top, glyph bottom, accent top, accent bottom)
    'glacier':  ('#2A86B8', '#0B2F4C', '#FFFFFF', '#D3ECF8', '#FFD98A', '#FFA92E'),
    'midnight': ('#22324A', '#06090F', '#BFE6F8', '#7CC4E8', '#FFD98A', '#FFA92E'),
    'frost':    ('#FFFFFF', '#CBE7F5', '#1E5F8A', '#0B2F4C', '#FFC261', '#F08A1C'),
    'teal':     ('#26B3A6', '#0A4F55', '#FFFFFF', '#D2F3EE', '#FFB199', '#FF6F5B'),
    'indigo':   ('#7B6CF0', '#2B1D7A', '#FFFFFF', '#E1DCFF', '#9BF2D2', '#3FD6A4'),
    'sunset':   ('#FF8A5C', '#C9334F', '#FFFFFF', '#FFE1D6', '#2B1D47', '#160F2A'),
    'mint':     ('#F2FFFA', '#BDEFE0', '#0F6B5E', '#0A4740', '#FFB25C', '#F07A1C'),
    'graphite': ('#454B55', '#14171C', '#FFFFFF', '#D9DDE3', '#D8FF5C', '#A6E019'),
    'amber':    ('#FFD36B', '#F08A1C', '#2B2410', '#140F05', '#FFFFFF', '#FFF1D6'),
    'ocean':    ('#00C2D1', '#005B8C', '#FFFFFF', '#D6F7FA', '#FFE066', '#FFC21A'),
}


def defs(p):
    bt, bb, gt, gb, at, ab = PALETTES[p]
    return (f'<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{bt}"/><stop offset="1" stop-color="{bb}"/></linearGradient>'
            f'<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{gt}"/><stop offset="1" stop-color="{gb}"/></linearGradient>'
            f'<linearGradient id="a" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{at}"/><stop offset="1" stop-color="{ab}"/></linearGradient>'
            '<filter id="shadow" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur in="SourceAlpha" stdDeviation="5"/>'
            '<feOffset dy="5"/><feComponentTransfer><feFuncA type="linear" slope="0.28"/></feComponentTransfer>'
            '<feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>')


def write(path, title, body, palette):
    open(path, 'w').write(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256" role="img" '
        f'aria-labelledby="title">\n  <title id="title">{title}</title>\n  <defs>{defs(palette)}</defs>\n'
        f'  <rect width="256" height="256" fill="url(#bg)"/>\n  <g filter="url(#shadow)">{body}</g>\n</svg>\n')


def bar(x, y, w, h, fill='url(#g)', op=1):
    return f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{h / 2:.1f}" fill="{fill}" opacity="{op:.2f}"/>'


def v_original():  # round 4, I: centred, growing, brightening
    return ''.join(bar(128 - (40 + i * 24) / 2, 40 + i * 32, 40 + i * 24, 10 + i * 2, op=0.35 + i * 0.13) for i in range(6))

def v_marker():  # one tick is you, in the accent colour
    return ''.join(bar(128 - (40 + i * 24) / 2, 40 + i * 32, 40 + i * 24, 10 + i * 2,
                       fill='url(#a)' if i == 4 else 'url(#g)', op=1 if i == 4 else 0.35 + i * 0.13) for i in range(6))

def v_ruler():  # a ruler on the left edge, long and short marks, deeper ones longer
    out = ''
    for i in range(9):
        long = i % 2 == 0
        w = (64 if long else 36) + i * 10
        out += bar(56, 36 + i * 22, w, 10 if long else 8, op=0.4 + i * 0.075)
    return out

def v_perspective():  # spacing opens up as it comes towards you: depth by perspective
    out, y = '', 34
    for i in range(6):
        w, h = 44 + i * 26, 6 + i * 3.4
        out += bar(128 - w / 2, y, w, h, op=0.3 + i * 0.14)
        y += h + 8 + i * 5
    return out

def v_funnel():  # narrowing down to a point: going deeper
    return ''.join(bar(128 - (176 - i * 30) / 2, 44 + i * 30, 176 - i * 30, 16 - i * 1.5, op=1 - i * 0.14) for i in range(6))

def v_axis():  # a scale with a centre line, like a sounding line through the marks
    out = bar(122, 32, 12, 192, op=0.9)
    for i in range(6):
        w = 40 + i * 24
        out += bar(128 - w / 2, 44 + i * 32, w, 10, op=0.35 + i * 0.13)
    return out

def v_chevron():  # the ticks step inwards to draw a downward arrow
    ws = [176, 176, 176, 132, 88, 44]
    return ''.join(bar(128 - w / 2, 40 + i * 32, w, 16, op=0.45 + i * 0.11) for i, w in enumerate(ws))

def v_fade():  # bright at the top, fading into the deep
    return ''.join(bar(128 - (176 - i * 8) / 2, 40 + i * 32, 176 - i * 8, 14, op=1 - i * 0.16) for i in range(6))

def v_stagger():  # alternating sides, like a scroll that keeps going back and forth on its way down
    out = ''
    for i in range(6):
        w = 60 + i * 18
        x = 48 if i % 2 == 0 else 208 - w
        out += bar(x, 40 + i * 32, w, 12, op=0.35 + i * 0.13)
    return out

def v_level():  # a fill level: marks above the line are faint, the line is accent, marks below are solid
    out = ''
    for i in range(7):
        w = 64 + i * 18
        y = 36 + i * 28
        out += bar(128 - w / 2, y, w, 10, fill='url(#a)' if i == 3 else 'url(#g)', op=0.3 if i < 3 else 1)
    return out

VARIANTS = [
    ('01-original', 'Original', v_original), ('02-marker', 'You are here', v_marker), ('03-ruler', 'Ruler', v_ruler),
    ('04-perspective', 'Perspective', v_perspective), ('05-funnel', 'Funnel', v_funnel), ('06-axis', 'Sounding line', v_axis),
    ('07-chevron', 'Chevron', v_chevron), ('08-fade', 'Into the deep', v_fade), ('09-stagger', 'Zigzag', v_stagger),
    ('10-level', 'Waterline', v_level),
]
for f, t, fn in VARIANTS:
    write(f'variants/{f}.svg', t, fn(), 'glacier')
for i, p in enumerate(PALETTES):
    write(f'colors/{i + 1:02d}-{p}.svg', f'You are here, {p}', v_marker(), p)
