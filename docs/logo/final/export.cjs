// Renders the final logo PNGs and the Android legacy mipmaps with Chromium.
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const fs = require('fs');
const uri = f => 'data:image/svg+xml;base64,' + fs.readFileSync(f).toString('base64');
const jobs = [];
for (const s of [16, 32, 48, 64, 128, 180, 192, 256, 512, 1024]) jobs.push(['icon.svg', `png/icon-${s}.png`, s, 0]);
for (const s of [512, 1024]) jobs.push(['icon-dark.svg', `png/icon-dark-${s}.png`, s, 0]);
for (const s of [64, 128, 256, 512, 1024]) {
  jobs.push(['symbol.svg', `png/symbol-${s}.png`, s, 0]);
  jobs.push(['symbol-white.svg', `png/symbol-white-${s}.png`, s, 0]);
}
jobs.push(['icon.svg', 'png/play-store-512.png', 512, 0]);
const res = '../../../android/app/src/main/res';
for (const [d, s] of [['mdpi', 48], ['hdpi', 72], ['xhdpi', 96], ['xxhdpi', 144], ['xxxhdpi', 192]])
  jobs.push(['icon.svg', `${res}/mipmap-${d}/ic_launcher.png`, s, 0.18]);
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' }).catch(() => chromium.launch());
  const p = await b.newPage();
  for (const [src, out, size, radius] of jobs) {
    await p.setViewportSize({ width: size, height: size });
    // Symbols keep their aspect ratio inside the square.
    await p.setContent(`<body style="margin:0;background:transparent"><img src="${uri(src)}"
      style="width:${size}px;height:${size}px;object-fit:contain;display:block;border-radius:${radius * 100}%">`);
    await p.screenshot({ path: out, omitBackground: true });
  }
  // Review sheet: app icon in masks, themed icon, notification icon, dark variant.
  const t = '/tmp/claude-0/logo-r/';
  await p.setViewportSize({ width: 1200, height: 520 });
  await p.setContent(`<body style="margin:0;padding:28px;background:#F2F2F7;font:500 15px Roboto,sans-serif;color:#1C1C1E">
   <h2 style="margin:0 0 18px">Scroll Debt, final icon</h2><div style="display:flex;gap:28px;align-items:flex-end">
   ${[['icon.svg', '40px', 'Rounded square'], [t + 'adaptive-clean.svg', '50%', 'Android circle'], [t + 'adaptive-clean.svg', '30%', 'Android squircle'],
      [t + 'themed.svg', '50%', 'Themed (Android 13)'], ['icon-dark.svg', '40px', 'Dark variant'], [t + 'adaptive.svg', '0', 'Safe zone (red)']]
     .map(([f, r, l]) => `<figure style="margin:0"><img src="${uri(f)}" style="width:160px;height:160px;border-radius:${r};display:block;box-shadow:0 4px 14px rgba(0,0,0,.15)"><figcaption style="margin-top:8px">${l}</figcaption></figure>`).join('')}
   </div><div style="display:flex;gap:22px;align-items:center;margin-top:26px">
   ${[48, 36, 24, 16].map(s => `<img src="${uri('icon.svg')}" style="width:${s}px;height:${s}px;border-radius:22%">`).join('')}
   <span style="margin-left:20px">Status bar:</span><img src="${uri(t + 'stat.svg')}" style="width:48px;height:48px"><img src="${uri(t + 'stat.svg')}" style="width:24px;height:24px">
   <span style="margin-left:20px">Symbol:</span><img src="${uri('symbol.svg')}" style="height:60px"><img src="${uri('symbol-small.svg')}" style="height:24px">
   </div>`);
  await p.screenshot({ path: '../final-icon.png' });
  await b.close();
})();
