// Renders round 3 into a review sheet: each icon in an Apple-style rounded
// square at 180 px, plus 60 px and 29 px, and as an Android circle.
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const fs = require('fs');
const names = ['Deep m','Falling thumb','Contour thumb','Sinking minus','Sinker','Long S','Below the surface','Through the floor','Depth ticks','Endless'];
const files = fs.readdirSync('.').filter(f => f.endsWith('.svg')).sort();
const uri = f => 'data:image/svg+xml;base64,' + fs.readFileSync(f).toString('base64');
const cards = files.map((f, i) => `
  <figure>
    <img class="big" src="${uri(f)}">
    <div class="row"><img class="m" src="${uri(f)}"><img class="s" src="${uri(f)}"><img class="c" src="${uri(f)}"></div>
    <figcaption><b>${String.fromCharCode(65 + i)}</b> ${names[i]}</figcaption>
  </figure>`).join('');
const html = `<!doctype html><meta charset="utf-8"><style>
  body{margin:0;padding:32px;background:#F2F2F7;font:500 17px -apple-system,Roboto,sans-serif;color:#1C1C1E}
  h1{font-size:26px;margin:0 0 4px} p{margin:0 0 24px;color:#6C6C70;font-size:15px}
  .grid{display:grid;grid-template-columns:repeat(5,200px);gap:28px}
  figure{margin:0} img{display:block}
  .big{width:180px;height:180px;border-radius:40px;box-shadow:0 6px 18px rgba(0,0,0,.18)}
  .row{display:flex;align-items:center;gap:14px;margin:14px 0 8px}
  .m{width:60px;height:60px;border-radius:13.5px}.s{width:29px;height:29px;border-radius:6.5px}
  .c{width:48px;height:48px;border-radius:50%}
  b{display:inline-block;width:22px}
</style><h1>Scroll Debt, logo concepts</h1><p>Round 4: simpler, new ideas. 180, 60 and 29 px rounded squares, then the Android circle.</p>
<div class="grid">${cards}</div>`;
fs.writeFileSync('/tmp/claude-0/logo-r/r4.html', html);
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' }).catch(() => chromium.launch());
  const p = await b.newPage({ viewport: { width: 1200, height: 800 }, deviceScaleFactor: 2 });
  await p.goto('file:///tmp/claude-0/logo-r/r4.html');
  await p.screenshot({ path: '../concepts-round4.png', fullPage: true });
  for (const f of files) {
    await p.setContent(`<body style="margin:0"><img src="${uri(f)}" width="512" height="512">`);
    await p.setViewportSize({ width: 512, height: 512 });
    await p.screenshot({ path: `/tmp/claude-0/logo-r/${f.replace('.svg', '.png')}`, omitBackground: true });
  }
  await b.close();
})();
