"""Round 3 logo concepts in the style of Apple app icons: one centred object,
a soft full-bleed gradient background, gentle gradients, a top highlight and a
soft shadow for depth. 256x256 artwork; render with Chromium (render.cjs)."""
import math

def svg(name, title, defs, body):
    open(name, 'w').write(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256" role="img" '
        f'aria-labelledby="title">\n  <title id="title">{title}</title>\n  <defs>{defs}{SHADOW}</defs>\n{body}\n</svg>\n')

def lin(id, stops, x1=0, y1=0, x2=0, y2=1):
    s = ''.join(f'<stop offset="{o}" stop-color="{c}"{f" stop-opacity={chr(34)}{a}{chr(34)}" if a is not None else ""}/>'
                for o, c, *rest in stops for a in [rest[0] if rest else None])
    return f'<linearGradient id="{id}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{s}</linearGradient>'

def rad(id, stops, cx=.5, cy=.5, r=.5, fx=None, fy=None):
    s = ''.join(f'<stop offset="{o}" stop-color="{c}"{f" stop-opacity={chr(34)}{a}{chr(34)}" if a is not None else ""}/>'
                for o, c, *rest in stops for a in [rest[0] if rest else None])
    f = f' fx="{fx}" fy="{fy}"' if fx is not None else ''
    return f'<radialGradient id="{id}" cx="{cx}" cy="{cy}" r="{r}"{f}>{s}</radialGradient>'

SHADOW = ('<filter id="shadow" x="-40%" y="-40%" width="180%" height="180%">'
          '<feGaussianBlur in="SourceAlpha" stdDeviation="7"/><feOffset dy="8"/>'
          '<feComponentTransfer><feFuncA type="linear" slope="0.4"/></feComponentTransfer>'
          '<feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>'
          '<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="10"/></filter>'
          '<filter id="frost" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation="1.6"/></filter>')

HL = lin('hl', [(0, '#FFFFFF', .7), (.45, '#FFFFFF', 0)])  # top highlight overlay

def full(fill):
    return f'<rect width="256" height="256" fill="{fill}"/>'

# 1 Iceberg: the tip above water, the rest glassy and deep below.
d = (lin('sky', [(0, '#D4EFFB'), (1, '#86CBEB')]) + lin('sea', [(0, '#1F7FB0'), (1, '#05213A')]) +
     lin('tip', [(0, '#FFFFFF'), (1, '#CFEAF7')]) + lin('under', [(0, '#BFE6F8', .55), (1, '#BFE6F8', 0)]) + HL)
b = (full('url(#sky)') + '<rect y="116" width="256" height="140" fill="url(#sea)"/>'
     '<path d="M74 116 C66 160 92 222 130 232 C172 222 196 162 184 116 Z" fill="url(#under)"/>'
     '<g filter="url(#shadow)"><path d="M84 116 L110 72 Q114 66 119 71 L128 80 L146 50 Q150 44 155 50 L184 116 Z" fill="url(#tip)"/>'
     '<path d="M146 50 Q150 44 155 50 L184 116 L150 116 L140 84 Z" fill="#A9D9F0" opacity=".8"/></g>'
     '<rect y="114" width="256" height="4" fill="#FFFFFF" opacity=".55"/>')
svg('01-iceberg.svg', 'Iceberg', d, b)

# 2 The lure: a glowing screen dangling into the dark, the angler unseen.
d = (rad('deep', [(0, '#123A5A'), (1, '#030A12')], cy=.62, r=.75) + rad('glow', [(0, '#FFC857', .55), (1, '#FFC857', 0)]) +
     lin('lure', [(0, '#FFE7A3'), (1, '#FFA92E')]) + lin('stalk', [(0, '#3B7FA8'), (1, '#1B4A66')]) + HL)
b = (full('url(#deep)') + '<circle cx="128" cy="150" r="104" fill="url(#glow)"/>'
     '<path d="M236 -8 C220 50 160 40 128 104" fill="none" stroke="url(#stalk)" stroke-width="9" stroke-linecap="round"/>'
     '<g filter="url(#shadow)"><rect x="92" y="100" width="72" height="104" rx="20" fill="url(#lure)"/></g>'
     '<rect x="106" y="120" width="44" height="8" rx="4" fill="#C9781A" opacity=".55"/>'
     '<rect x="106" y="138" width="30" height="8" rx="4" fill="#C9781A" opacity=".55"/>'
     '<rect x="106" y="156" width="40" height="8" rx="4" fill="#C9781A" opacity=".55"/>'
     '<rect x="106" y="174" width="24" height="8" rx="4" fill="#C9781A" opacity=".55"/>'
     '<rect x="92" y="100" width="72" height="104" rx="20" fill="url(#hl)"/>')
svg('02-lure.svg', 'The lure', d, b)

# 3 Diver helmet: polished brass, the feed glowing in the porthole.
d = (lin('bg', [(0, '#15476C'), (1, '#061827')]) + rad('brass', [(0, '#FFEFB8'), (.55, '#F2B54A'), (1, '#B8731E')], cx=.38, cy=.3, r=.8) +
     lin('rim', [(0, '#E9A947'), (1, '#8E5815')]) + lin('glass', [(0, '#1E6A96'), (1, '#05172A')]) + HL)
b = (full('url(#bg)') +
     '<g filter="url(#shadow)"><path d="M70 196 H186 L204 236 Q206 244 196 244 H60 Q50 244 52 236 Z" fill="#C98B2B"/>'
     '<circle cx="128" cy="118" r="88" fill="url(#brass)"/></g>'
     '<circle cx="128" cy="118" r="54" fill="url(#rim)"/><circle cx="128" cy="118" r="42" fill="url(#glass)"/>'
     '<rect x="102" y="98" width="52" height="9" rx="4.5" fill="#7CC4E8"/><rect x="102" y="114" width="36" height="9" rx="4.5" fill="#5FAFD6"/>'
     '<rect x="102" y="130" width="46" height="9" rx="4.5" fill="#3A84AE"/>'
     '<path d="M96 104 A36 36 0 0 1 126 84" fill="none" stroke="#FFFFFF" stroke-width="7" stroke-linecap="round" opacity=".55"/>'
     '<circle cx="48" cy="120" r="15" fill="url(#rim)"/><circle cx="48" cy="120" r="9" fill="url(#glass)"/>'
     '<circle cx="208" cy="120" r="15" fill="url(#rim)"/><circle cx="208" cy="120" r="9" fill="url(#glass)"/>')
svg('03-diver-helmet.svg', 'Diver helmet', d, b)

# 4 Depth gauge: an instrument whose needle is deep in the red zone of scrolling.
ticks = ''
for k in range(24):
    a = math.radians(-90 + k * 15)
    r1 = 64 if k % 2 == 0 else 68
    ticks += (f'<line x1="{128 + r1 * math.cos(a):.1f}" y1="{124 + r1 * math.sin(a):.1f}" x2="{128 + 74 * math.cos(a):.1f}" '
              f'y2="{124 + 74 * math.sin(a):.1f}" stroke="#1B4A66" stroke-width="{4 if k % 2 == 0 else 2.5}" stroke-linecap="round"/>')
def arc(r, a0, a1):
    p = lambda a: (128 + r * math.cos(math.radians(a)), 124 + r * math.sin(math.radians(a)))
    (x0, y0), (x1, y1) = p(a0), p(a1)
    return f'M{x0:.1f} {y0:.1f} A{r} {r} 0 0 1 {x1:.1f} {y1:.1f}'
ang = math.radians(-90 + 150)
d = (lin('bg', [(0, '#1D5F8A'), (1, '#07223A')]) + lin('bezel', [(0, '#F2F8FB'), (1, '#8FAABB')]) +
     lin('face', [(0, '#FFFFFF'), (1, '#DDEBF3')]) + lin('needle', [(0, '#FFD27A'), (1, '#F08A1C')]) + HL)
b = (full('url(#bg)') + '<g filter="url(#shadow)"><circle cx="128" cy="124" r="96" fill="url(#bezel)"/></g>'
     '<circle cx="128" cy="124" r="84" fill="url(#face)"/>'
     f'<path d="{arc(56, -30, 120)}" fill="none" stroke="#7CC4E8" stroke-width="10" stroke-linecap="round" opacity=".55"/>'
     f'<path d="{arc(56, 60, 120)}" fill="none" stroke="#1B4A66" stroke-width="10" stroke-linecap="round" opacity=".8"/>'
     + ticks +
     f'<g filter="url(#shadow)"><path d="M{128 + 62 * math.cos(ang):.1f} {124 + 62 * math.sin(ang):.1f} '
     f'L{128 + 7 * math.cos(ang + 1.57):.1f} {124 + 7 * math.sin(ang + 1.57):.1f} L{128 - 16 * math.cos(ang):.1f} {124 - 16 * math.sin(ang):.1f} '
     f'L{128 + 7 * math.cos(ang - 1.57):.1f} {124 + 7 * math.sin(ang - 1.57):.1f} Z" fill="url(#needle)"/></g>'
     '<circle cx="128" cy="124" r="10" fill="#0B2A40"/><circle cx="128" cy="124" r="84" fill="url(#hl)" opacity=".6"/>')
svg('04-depth-gauge.svg', 'Depth gauge', d, b)

# 5 Ice cube: your phone, frozen solid.
d = (lin('bg', [(0, '#2A86B8'), (1, '#0A2E4A')]) + lin('ice', [(0, '#FFFFFF', .95), (1, '#9FD5EE', .85)]) +
     lin('phone', [(0, '#1B4A66'), (1, '#0B1E2E')]) + HL)
b = (full('url(#bg)') + '<g transform="rotate(-9 128 134)">'
     '<g filter="url(#shadow)"><rect x="48" y="54" width="160" height="160" rx="36" fill="url(#ice)"/></g>'
     '<g filter="url(#frost)" opacity=".85"><rect x="98" y="80" width="60" height="106" rx="14" fill="url(#phone)"/>'
     '<rect x="110" y="98" width="36" height="7" rx="3.5" fill="#7CC4E8"/><rect x="110" y="112" width="26" height="7" rx="3.5" fill="#7CC4E8"/>'
     '<rect x="110" y="126" width="32" height="7" rx="3.5" fill="#7CC4E8"/></g>'
     '<rect x="48" y="54" width="160" height="160" rx="36" fill="url(#hl)"/>'
     '<path d="M66 92 Q66 72 86 70 L132 70" fill="none" stroke="#FFFFFF" stroke-width="7" stroke-linecap="round" opacity=".9"/>'
     '<circle cx="76" cy="178" r="5" fill="#FFFFFF" opacity=".8"/><circle cx="88" cy="192" r="3" fill="#FFFFFF" opacity=".8"/></g>')
svg('05-ice-cube.svg', 'Ice cube', d, b)

# 6 Rabbit hole: something just went down the feed.
d = (lin('bg', [(0, '#F1FAFE'), (1, '#B4DDF1')]) + rad('hole', [(0, '#01060C'), (.7, '#0B2A44'), (1, '#1E5E86')]) +
     lin('ear', [(0, '#FFFFFF'), (1, '#E3ECF2')]) + lin('pink', [(0, '#FBC6D2'), (1, '#E9879F')]))
b = (full('url(#bg)') + '<ellipse cx="128" cy="176" rx="84" ry="34" fill="url(#hole)"/>'
     '<g filter="url(#shadow)"><path d="M104 180 C94 120 90 70 106 56 C122 48 124 110 124 180 Z" fill="url(#ear)"/>'
     '<path d="M134 180 C138 112 150 62 170 58 C186 58 166 120 152 180 Z" fill="url(#ear)"/></g>'
     '<path d="M108 168 C102 124 100 84 108 72 C116 70 117 120 117 168 Z" fill="url(#pink)"/>'
     '<path d="M140 168 C144 120 152 82 166 72 C170 80 158 124 148 168 Z" fill="url(#pink)"/>'
     '<path d="M44 176 A84 34 0 0 0 212 176 L212 186 A84 34 0 0 1 44 186 Z" fill="#B4DDF1"/>'
     '<path d="M48 182 A80 30 0 0 0 208 182" fill="none" stroke="#FFFFFF" stroke-width="4" opacity=".8"/>')
svg('06-rabbit-hole.svg', 'Rabbit hole', d, b)

# 7 Deep feed: glass feed cards receding into the dark, as if the feed had no bottom.
d = (rad('vortex', [(0, '#01060C'), (.45, '#0B3150'), (1, '#2A86B8')], cy=.38, r=.8) +
     lin('card', [(0, '#FFFFFF'), (1, '#B9E1F4')]) + HL)
cards = ''
for k, (w, h, y, o) in enumerate([(176, 50, 176, 1), (136, 38, 128, .8), (100, 28, 92, .6), (70, 20, 66, .42), (46, 13, 48, .28)]):
    cards += f'<rect x="{128 - w / 2}" y="{y}" width="{w}" height="{h}" rx="{h * .32:.1f}" fill="url(#card)" opacity="{o}"/>'
cards += '<rect x="58" y="188" width="70" height="9" rx="4.5" fill="#1B4A66" opacity=".5"/><rect x="58" y="204" width="104" height="9" rx="4.5" fill="#1B4A66" opacity=".35"/>'
svg('07-deep-feed.svg', 'Deep feed', d, full('url(#vortex)') + f'<g filter="url(#shadow)">{cards}</g>')

# 8 Sinking thumb: a glass scroll thumb drifting down through the water.
d = (lin('water', [(0, '#5CC0EA'), (.55, '#16628F'), (1, '#04192C')]) + lin('ray', [(0, '#FFFFFF', .22), (1, '#FFFFFF', 0)]) +
     lin('glassf', [(0, '#FFFFFF', .85), (1, '#CDEBF8', .55)]))
b = (full('url(#water)') + '<path d="M60 0 L96 0 L150 256 L90 256 Z" fill="url(#ray)"/><path d="M150 0 L170 0 L220 256 L188 256 Z" fill="url(#ray)"/>'
     '<g filter="url(#shadow)"><rect x="96" y="92" width="64" height="128" rx="32" fill="url(#glassf)"/></g>'
     '<rect x="104" y="100" width="12" height="60" rx="6" fill="#FFFFFF" opacity=".8"/>'
     '<circle cx="146" cy="70" r="9" fill="none" stroke="#FFFFFF" stroke-width="3.5" opacity=".8"/>'
     '<circle cx="124" cy="48" r="6" fill="none" stroke="#FFFFFF" stroke-width="3" opacity=".7"/>'
     '<circle cx="150" cy="30" r="4" fill="none" stroke="#FFFFFF" stroke-width="2.5" opacity=".6"/>')
svg('08-sinking-thumb.svg', 'Sinking thumb', d, b)

# 9 Penguin dive: one glossy penguin, head first.
d = (lin('water', [(0, '#3AA6D9'), (1, '#062038')]) + lin('body', [(0, '#2C3E52'), (1, '#0A0F16')], 0, 0, 1, 0) +
     lin('belly', [(0, '#FFFFFF'), (1, '#DCE9F1')]) + lin('beak', [(0, '#FFD27A'), (1, '#F08A1C')]))
b = (full('url(#water)') + '<g transform="rotate(16 128 132)"><g filter="url(#shadow)">'
     '<ellipse cx="128" cy="126" rx="44" ry="84" fill="url(#body)"/></g>'
     '<ellipse cx="119" cy="134" rx="27" ry="64" fill="url(#belly)"/>'
     '<path d="M114 204 L142 204 L128 234 Z" fill="url(#beak)"/>'
     '<circle cx="141" cy="182" r="7" fill="#FFFFFF"/><circle cx="142" cy="183" r="3.5" fill="#0A0F16"/>'
     '<path d="M168 104 L204 58 L176 132 Z" fill="url(#body)"/>'
     '<path d="M112 48 L100 22 L124 40 Z" fill="url(#beak)"/><path d="M140 46 L154 20 L150 44 Z" fill="url(#beak)"/></g>'
     '<circle cx="74" cy="64" r="8" fill="none" stroke="#FFFFFF" stroke-width="3" opacity=".8"/>'
     '<circle cx="60" cy="40" r="5" fill="none" stroke="#FFFFFF" stroke-width="2.5" opacity=".7"/>')
svg('09-penguin-dive.svg', 'Penguin dive', d, b)

# 10 Frost crystal: six scroll thumbs make a snowflake; the one pointing down is longer.
d = lin('bg', [(0, '#2A86B8'), (1, '#071F35')]) + lin('arm', [(0, '#FFFFFF'), (1, '#B9E1F4')])
arms = ''
for k in range(6):
    a = -90 + 60 * k
    L = 100 if a == 90 else 80
    arm = f'<rect x="115" y="{124 - L}" width="26" height="{L}" rx="13" fill="url(#arm)"/>'
    for t in (0.55,):
        y = 124 - L * t
        arm += (f'<rect x="125" y="{y - 26}" width="16" height="34" rx="8" fill="url(#arm)" transform="rotate(45 133 {y})"/>'
                f'<rect x="115" y="{y - 26}" width="16" height="34" rx="8" fill="url(#arm)" transform="rotate(-45 123 {y})"/>')
    arms += f'<g transform="rotate({a + 90} 128 124)">{arm}</g>'
svg('10-frost-crystal.svg', 'Frost crystal', d,
    full('url(#bg)') + f'<g filter="url(#shadow)">{arms}<circle cx="128" cy="124" r="18" fill="#DFF2FB"/></g>')
