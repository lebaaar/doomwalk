"""Round 4: simpler, new ideas. One bold white glyph on a calm blue gradient,
a soft shadow, at most one amber accent. 256x256; render with render.cjs."""
import math

BG = ('<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2A86B8"/>'
      '<stop offset="1" stop-color="#0B2F4C"/></linearGradient>'
      '<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/>'
      '<stop offset="1" stop-color="#D3ECF8"/></linearGradient>'
      '<linearGradient id="amber" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFD98A"/>'
      '<stop offset="1" stop-color="#FFA92E"/></linearGradient>'
      '<filter id="shadow" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur in="SourceAlpha" stdDeviation="5"/>'
      '<feOffset dy="5"/><feComponentTransfer><feFuncA type="linear" slope="0.3"/></feComponentTransfer>'
      '<feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>')


def svg(name, title, body, extra=''):
    open(name, 'w').write(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256" role="img" '
        f'aria-labelledby="title">\n  <title id="title">{title}</title>\n  <defs>{BG}{extra}</defs>\n'
        f'  <rect width="256" height="256" fill="url(#bg)"/>\n  <g filter="url(#shadow)">{body}</g>\n</svg>\n')


W = 'url(#g)'
stroke = lambda w: f'fill="none" stroke="{W}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"'

# A Deep m: a lowercase m (metres) whose last stem keeps going down, like a long scroll.
svg('01-deep-m.svg', 'Deep m',
    f'<path d="M68 172 V112 A26 26 0 0 1 120 112 V172 M120 112 A26 26 0 0 1 172 112 V214" {stroke(28)}/>'
    '<circle cx="172" cy="214" r="14" fill="url(#amber)"/>')

# B Falling thumb: a scroll thumb in motion, its echoes fading above it.
svg('02-falling-thumb.svg', 'Falling thumb',
    '<rect x="104" y="40" width="48" height="56" rx="24" fill="#FFFFFF" opacity=".18"/>'
    '<rect x="104" y="72" width="48" height="72" rx="24" fill="#FFFFFF" opacity=".35"/>'
    '<rect x="104" y="112" width="48" height="104" rx="24" fill="url(#g)"/>')

# C Contour thumb: a thumbprint drawn as the contour lines of a hollow, deepest point low.
arcs = ''
for i, (rx, ry, cy) in enumerate([(84, 96, 124), (62, 72, 140), (40, 48, 156), (18, 22, 170)]):
    arcs += f'<ellipse cx="128" cy="{cy}" rx="{rx}" ry="{ry}" {stroke(12)} opacity="{1 - i * 0.1:.2f}"/>'
svg('03-contour-thumb.svg', 'Contour thumb', arcs + '<circle cx="128" cy="172" r="7" fill="url(#amber)"/>')

# D Sinking minus: debt is a minus, and it sinks.
svg('04-sinking-minus.svg', 'Sinking minus',
    '<rect x="48" y="72" width="160" height="36" rx="18" fill="url(#g)"/>'
    '<rect x="76" y="132" width="104" height="24" rx="12" fill="#FFFFFF" opacity=".45"/>'
    '<rect x="100" y="178" width="56" height="14" rx="7" fill="#FFFFFF" opacity=".22"/>')

# E Sinker: one weight going down, three bubbles coming up.
svg('05-sinker.svg', 'Sinker',
    '<circle cx="128" cy="176" r="50" fill="url(#g)"/>'
    '<circle cx="146" cy="96" r="14" fill="none" stroke="#FFFFFF" stroke-width="7" opacity=".85"/>'
    '<circle cx="118" cy="62" r="10" fill="none" stroke="#FFFFFF" stroke-width="6" opacity=".65"/>'
    '<circle cx="140" cy="34" r="6" fill="none" stroke="#FFFFFF" stroke-width="5" opacity=".45"/>')

# F Long S: an S whose lower end keeps scrolling down instead of curling up.
svg('06-long-s.svg', 'Long S',
    f'<path d="M170 58 C150 34 86 36 86 74 C86 112 170 102 170 146 C170 176 140 186 120 186 C104 186 96 196 96 222" {stroke(28)}/>')

# G Below the surface: a waterline, and you, far below it.
svg('07-below-the-surface.svg', 'Below the surface',
    '<rect x="32" y="70" width="192" height="14" rx="7" fill="url(#g)"/>'
    '<rect x="32" y="84" width="192" height="140" rx="0" fill="#FFFFFF" opacity=".06"/>'
    '<circle cx="128" cy="188" r="20" fill="url(#amber)"/>')

# H Through the floor: a down arrow that has already gone through the line.
svg('08-through-the-floor.svg', 'Through the floor',
    f'<path d="M128 36 V206 M84 164 L128 208 L172 164" {stroke(28)}/>'
    '<rect x="40" y="104" width="64" height="14" rx="7" fill="#FFFFFF" opacity=".6"/>'
    '<rect x="152" y="104" width="64" height="14" rx="7" fill="#FFFFFF" opacity=".6"/>')

# I Depth ticks: a scale whose marks grow as it goes down.
ticks = ''
for i in range(6):
    w = 40 + i * 24
    ticks += f'<rect x="{128 - w / 2}" y="{40 + i * 32}" width="{w}" height="{10 + i * 2}" rx="{5 + i}" fill="url(#g)" opacity="{0.35 + i * 0.13:.2f}"/>'
svg('09-depth-ticks.svg', 'Depth ticks', ticks)

# J Endless: a loop that never closes; the feed goes round and down again.
svg('10-endless.svg', 'Endless',
    f'<path d="M128 132 C80 100 84 38 128 38 C172 38 176 100 128 132 C84 162 88 212 128 224" {stroke(26)}/>')
