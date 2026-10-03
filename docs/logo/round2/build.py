"""Round 2 logo concepts: characterful, full colour, stepped depth. Each SVG is
full-bleed 256x256 artwork for an app icon; key content stays inside the
central circle so Android's adaptive masks don't cut it."""
import math

NIGHT, DEEP, NAVY, MID, ICE, FROST, WHITE = '#0B0F14', '#0E2233', '#132F45', '#1B4A66', '#7CC4E8', '#D6F0FB', '#F7FBFE'
AMBER, AMBER_D, AMBER_L = '#FFC857', '#D9922B', '#FFE3A1'


def svg(name, title, body):
    open(name, 'w').write(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256" role="img" '
        f'aria-labelledby="title">\n  <title id="title">{title}</title>\n{body}\n</svg>\n')


def rr(x, y, w, h, r, fill, extra=''):
    return f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{r:.1f}" fill="{fill}" {extra}/>'


def poly(pts, fill, extra=''):
    return f'<polygon points="{" ".join(f"{x:.1f},{y:.1f}" for x, y in pts)}" fill="{fill}" {extra}/>'


def circ(cx, cy, r, fill, extra=''):
    return f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{fill}" {extra}/>'


bg = lambda c: f'<rect width="256" height="256" fill="{c}"/>'

# 1 Iceberg feed: the visible tip is small; under the waterline the feed goes deep.
b = bg(NIGHT)
for i, c in enumerate(['#10273A', '#0D2031', '#0A1928']):
    b += f'<rect y="{112 + i * 48}" width="256" height="{48 if i < 2 else 48}" fill="{c}"/>'
b += poly([(100, 112), (118, 74), (130, 84), (146, 58), (166, 112)], WHITE)
b += poly([(146, 58), (166, 112), (140, 112), (136, 90)], '#BFE3F5')
cards = [(118, 116, ICE), (142, 150, '#5FAFD6'), (166, 168, '#4A9AC4'), (190, 150, '#3A84AE'), (214, 104, '#2D6E95')]
for y, w, c in cards:
    b += rr(128 - w / 2, y, w, 18, 9, c)
b += '<path d="M24 112 Q40 106 56 112 T88 112 M168 112 Q184 106 200 112 T232 112" fill="none" stroke="#7CC4E8" stroke-width="3" stroke-linecap="round" opacity=".7"/>'
svg('01-iceberg-feed.svg', 'Iceberg feed', b)

# 2 Anglerfish: the feed is the glowing lure of the deep.
b = bg('#081420')
b += circ(78, 66, 46, AMBER, 'opacity=".10"') + circ(78, 66, 30, AMBER, 'opacity=".18"')
b += '<path d="M150 104 Q144 48 92 58" fill="none" stroke="#2E5F80" stroke-width="5" stroke-linecap="round"/>'
b += rr(62, 42, 32, 50, 7, AMBER)
b += rr(68, 50, 20, 5, 2.5, AMBER_D) + rr(68, 60, 14, 5, 2.5, AMBER_D) + rr(68, 70, 20, 5, 2.5, AMBER_D) + rr(68, 80, 10, 5, 2.5, AMBER_D)
b += poly([(214, 160), (246, 128), (246, 200)], '#1E4561')
b += '<ellipse cx="150" cy="164" rx="76" ry="64" fill="#1E4561"/>'
b += '<ellipse cx="164" cy="186" rx="50" ry="34" fill="#285A7C"/>'
b += '<path d="M74 146 L140 170 L80 204 Q66 176 74 146 Z" fill="#050B11"/>'
for x in (86, 100, 114, 128):
    y = 146 + (x - 74) * 24 / 66
    b += poly([(x - 5, y - 2), (x + 5, y + 2), (x + 1, y + 14)], WHITE)
for x in (92, 108, 124):
    y = 204 - (x - 80) * 34 / 60
    b += poly([(x - 5, y + 2), (x + 5, y - 2), (x, y - 13)], WHITE)
b += circ(156, 130, 15, WHITE) + circ(151, 125, 8, NIGHT) + circ(148, 122, 2.5, WHITE)
b += '<path d="M138 108 Q156 100 172 112" fill="none" stroke="#0B1A26" stroke-width="5" stroke-linecap="round"/>'
svg('02-anglerfish.svg', 'Anglerfish', b)

# 3 Rabbit hole: a phone whose screen is a hole, ears disappearing into it.
b = bg(NIGHT)
b += rr(66, 24, 124, 208, 26, NAVY) + rr(66, 24, 124, 208, 26, 'none', f'stroke="{ICE}" stroke-width="6"')
for i, (rx, ry, c) in enumerate([(50, 24, '#2A6488'), (40, 18, '#1B4A66'), (30, 13, '#0F2C40'), (20, 8, '#050B11')]):
    b += f'<ellipse cx="128" cy="{166 + i * 4}" rx="{rx}" ry="{ry}" fill="{c}"/>'
b += f'<path d="M110 168 C102 120 96 84 108 70 C120 60 124 100 122 168 Z" fill="{WHITE}"/>'
b += f'<path d="M112 160 C107 124 104 96 110 84 C116 80 117 110 117 160 Z" fill="#F4B9C4"/>'
b += f'<path d="M134 168 C138 118 148 82 164 76 C176 74 160 120 148 168 Z" fill="{WHITE}"/>'
b += f'<path d="M139 160 C143 124 150 98 160 90 C164 94 154 126 145 160 Z" fill="#F4B9C4"/>'
b += '<ellipse cx="128" cy="174" rx="40" ry="12" fill="#050B11"/>'
b += rr(178, 60, 5, 40, 2.5, ICE)
svg('03-rabbit-hole.svg', 'Rabbit hole', b)

# 4 Frozen phone: a worried phone frozen in an ice cube.
b = bg(DEEP)
b += '<g transform="rotate(-8 128 132)">'
b += rr(40, 44, 176, 176, 30, '#9FD5EE') + rr(40, 44, 176, 176, 30, 'none', f'stroke="{FROST}" stroke-width="5"')
b += f'<path d="M58 70 Q60 58 72 56 L150 56" fill="none" stroke="{WHITE}" stroke-width="8" stroke-linecap="round" opacity=".8"/>'
b += f'<path d="M200 120 L200 196 Q198 206 188 206 L130 206" fill="none" stroke="#6FB5D9" stroke-width="7" stroke-linecap="round"/>'
b += '</g>'
b += '<g transform="rotate(6 128 136)">'
b += rr(94, 78, 68, 116, 14, NIGHT) + rr(100, 86, 56, 98, 9, MID)
b += circ(116, 126, 9, WHITE) + circ(140, 126, 9, WHITE) + circ(117, 129, 4.5, NIGHT) + circ(141, 129, 4.5, NIGHT)
b += f'<path d="M106 114 L122 108 M150 114 L134 108" stroke="{WHITE}" stroke-width="4" stroke-linecap="round"/>'
b += f'<ellipse cx="128" cy="154" rx="7" ry="9" fill="{NIGHT}"/>'
b += '</g>'
for x, y, r in [(70, 182, 5), (82, 196, 3), (184, 80, 4), (194, 92, 2.5)]:
    b += circ(x, y, r, WHITE, 'opacity=".85"')
def spark(x, y, s, c):
    return f'<path d="M{x} {y-s} Q{x} {y} {x+s} {y} Q{x} {y} {x} {y+s} Q{x} {y} {x-s} {y} Q{x} {y} {x} {y-s} Z" fill="{c}"/>'
b += spark(196, 62, 13, WHITE) + spark(62, 196, 9, FROST)
svg('04-frozen-phone.svg', 'Frozen phone', b)

# 5 Yeti: the abominable scroller, hypnotised by the phone in its paws.
b = bg('#0C1C2B')

fur = ''
for k in range(18):
    a = 2 * math.pi * k / 18
    fur += circ(128 + 74 * math.cos(a), 116 + 74 * math.sin(a), 18, WHITE)
b += fur + circ(128, 116, 76, WHITE)
b += rr(78, 84, 100, 84, 40, ICE)
b += circ(108, 116, 12, WHITE) + circ(148, 116, 12, WHITE) + circ(108, 122, 6.5, NIGHT) + circ(148, 122, 6.5, NIGHT)
b += f'<path d="M96 100 L118 98 M160 100 L138 98" stroke="#2B5573" stroke-width="6" stroke-linecap="round"/>'
b += f'<ellipse cx="128" cy="150" rx="12" ry="7" fill="#2B5573"/>'
b += poly([(119, 146), (125, 146), (122, 154)], WHITE) + poly([(131, 146), (137, 146), (134, 154)], WHITE)
b += f'<path d="M84 160 Q128 176 172 160" fill="none" stroke="{AMBER_L}" stroke-width="6" stroke-linecap="round" opacity=".7"/>'
b += rr(100, 178, 56, 40, 9, NIGHT) + rr(105, 183, 46, 30, 5, AMBER)
b += rr(111, 189, 26, 4, 2, AMBER_D) + rr(111, 197, 18, 4, 2, AMBER_D) + rr(111, 205, 30, 4, 2, AMBER_D)
b += circ(98, 198, 14, WHITE) + circ(158, 198, 14, WHITE)
svg('05-yeti.svg', 'Yeti', b)

# 6 Penguin dive: head first into the deep, bubbles trailing up.
b = bg('#0A1928')
for i, c in enumerate(['#1B4A66', '#163E57', '#113248', '#0D2639']):
    b += f'<rect y="{i * 64}" width="256" height="64" fill="{c}"/>'
b += '<g transform="rotate(14 128 136)">'
b += f'<ellipse cx="128" cy="132" rx="38" ry="76" fill="{NIGHT}"/>'
b += f'<ellipse cx="120" cy="140" rx="24" ry="58" fill="{WHITE}"/>'
b += poly([(116, 204), (140, 204), (128, 230)], AMBER)
b += circ(140, 184, 6, WHITE) + circ(141, 185, 3, NIGHT)
b += poly([(162, 116), (196, 66), (170, 140)], NIGHT)
b += poly([(116, 58), (104, 34), (126, 50)], AMBER) + poly([(136, 58), (150, 32), (146, 54)], AMBER)
b += '</g>'
for x, y, r in [(92, 50, 7), (80, 28, 5), (100, 20, 4), (70, 70, 4)]:
    b += circ(x, y, r, 'none', f'stroke="{FROST}" stroke-width="3"')
svg('06-penguin-dive.svg', 'Penguin dive', b)

# 7 Diver helmet: brass and glass, the feed glowing in the porthole.
b = bg('#0B1A27')
b += poly([(76, 200), (180, 200), (204, 246), (52, 246)], AMBER_D)
for x in (70, 100, 128, 156, 186):
    b += circ(x, 222, 5, AMBER_L)
b += circ(128, 120, 92, AMBER) + f'<path d="M50 150 A92 92 0 0 0 206 150 Z" fill="{AMBER_D}" opacity=".55"/>'
b += circ(40, 122, 18, AMBER_D) + circ(40, 122, 10, MID) + circ(216, 122, 18, AMBER_D) + circ(216, 122, 10, MID)
b += circ(128, 120, 56, AMBER_D) + circ(128, 120, 44, '#0E2233')
b += rr(100, 96, 56, 10, 5, ICE) + rr(100, 114, 40, 10, 5, '#5FAFD6') + rr(100, 132, 50, 10, 5, '#3A84AE')
b += f'<path d="M98 90 A40 40 0 0 1 132 78" fill="none" stroke="{WHITE}" stroke-width="6" stroke-linecap="round" opacity=".7"/>'
for a in range(0, 360, 45):
    r = math.radians(a)
    b += circ(128 + 50 * math.cos(r), 120 + 50 * math.sin(r), 3.5, AMBER_L)
svg('07-diver-helmet.svg', 'Diver helmet', b)

# 8 Depth sounder: a sonar beam fans down the feed and pings something deep.
b = bg(NIGHT) + rr(20, 20, 216, 216, 40, '#0D2031')
cx, cy = 128, 34
def wedge(r, a0, a1):
    p0 = (cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0)))
    p1 = (cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1)))
    return f'M{cx} {cy} L{p0[0]:.1f} {p0[1]:.1f} A{r} {r} 0 0 1 {p1[0]:.1f} {p1[1]:.1f} Z'
b += f'<path d="{wedge(196, 58, 122)}" fill="{ICE}" opacity=".10"/>'
b += f'<path d="{wedge(196, 72, 108)}" fill="{ICE}" opacity=".14"/>'
for r in (56, 96, 136, 176):
    a0, a1 = math.radians(58), math.radians(122)
    b += (f'<path d="M{cx + r * math.cos(a0):.1f} {cy + r * math.sin(a0):.1f} A{r} {r} 0 0 1 '
          f'{cx + r * math.cos(a1):.1f} {cy + r * math.sin(a1):.1f}" fill="none" stroke="{ICE}" stroke-width="4" '
          f'stroke-linecap="round" opacity="{0.9 - r / 300:.2f}"/>')
b += circ(cx, cy, 10, ICE)
b += circ(146, 186, 16, AMBER, 'opacity=".25"') + circ(146, 186, 8, AMBER)
for i, y in enumerate((60, 100, 140, 180, 220)):
    b += rr(34, y - 2, 16 if i % 2 else 24, 4, 2, FROST, 'opacity=".6"')
svg('08-depth-sounder.svg', 'Depth sounder', b)

# 9 Sloth: hanging off the scrollbar, in no hurry to walk anywhere.
FUR, FUR_D, CREAM = '#9C7E66', '#7A604C', '#F1E4D3'
b = bg(DEEP)
b += rr(112, 14, 32, 120, 16, 'none', f'stroke="{MID}" stroke-width="6"')
b += rr(116, 30, 24, 44, 12, ICE)
b += f'<path d="M98 150 C92 110 104 70 118 56 M158 150 C164 110 152 70 138 56" fill="none" stroke="{FUR_D}" stroke-width="18" stroke-linecap="round"/>'
for x in (113, 119, 137, 143):
    b += rr(x - 2, 48, 4, 14, 2, CREAM)
b += '<ellipse cx="128" cy="176" rx="58" ry="54" fill="#9C7E66"/>'
b += f'<ellipse cx="128" cy="160" rx="40" ry="31" fill="{CREAM}"/>'
b += '<ellipse cx="111" cy="157" rx="15" ry="9" fill="#5B4535" transform="rotate(-18 111 157)"/>'
b += '<ellipse cx="145" cy="157" rx="15" ry="9" fill="#5B4535" transform="rotate(18 145 157)"/>'
b += f'<path d="M104 157 Q111 162 118 157 M138 157 Q145 162 152 157" fill="none" stroke="{CREAM}" stroke-width="3.5" stroke-linecap="round"/>'
b += '<ellipse cx="128" cy="170" rx="7" ry="5" fill="#3A2A20"/>'
b += '<path d="M118 180 Q128 188 138 180" fill="none" stroke="#3A2A20" stroke-width="3.5" stroke-linecap="round"/>'
svg('09-sloth.svg', 'Sloth', b)

# 10 Crevasse S: an ice block with an S cut deep into it.
b = bg(NIGHT)
top = [(128, 40), (216, 90), (128, 140), (40, 90)]
b += poly([(40, 90), (128, 140), (128, 226), (40, 176)], '#5FAFD6')
b += poly([(216, 90), (128, 140), (128, 226), (216, 176)], '#2F7AA5')
b += poly(top, FROST)
S = 'M74 16 C44 4 16 22 34 40 C48 54 74 46 78 64 C82 84 50 94 24 84'
face = 'matrix(0.88 0.5 -0.88 0.5 128 40)'
b += f'<g transform="translate(0 7)"><path d="{S}" transform="{face}" fill="none" stroke="#1B4A66" stroke-width="20" stroke-linecap="round"/></g>'
b += f'<path d="{S}" transform="{face}" fill="none" stroke="#0B1A27" stroke-width="17" stroke-linecap="round"/>'
b += f'<path d="M128 140 L128 226" stroke="{FROST}" stroke-width="2" opacity=".5"/>'
b += f'<path d="M58 160 L58 120 M74 150 L74 128" stroke="{FROST}" stroke-width="5" stroke-linecap="round" opacity=".6"/>'
svg('10-crevasse-s.svg', 'Crevasse S', b)
