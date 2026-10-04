const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const path = require('path');
(async () => {
  const b = await chromium.launch();
  // 2x: screenshots come out 2160x3840 (Play's max is 3840 per side)
  const p = await b.newPage({ viewport: { width: 1200, height: 2000 }, deviceScaleFactor: 2 });
  await p.goto('file://' + path.resolve(__dirname, 'graphics.html'));
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(300);
  const out = path.resolve(__dirname, '..');
  const names = { s1: 'screenshot-1-today', s2: 'screenshot-2-blocked', s4: 'screenshot-3-tiers', s5: 'screenshot-4-activity', s6: 'screenshot-5-landmarks' };
  for (const [id, n] of Object.entries(names)) {
    await p.locator('#' + id).screenshot({ path: `${out}/${n}.png` });
    console.log(n);
  }
  // Feature graphic must be exactly 1024x500 with no alpha: render at 2x,
  // downscale on a canvas in a 1x page, then screenshot that page
  // (the 2x one is kept as feature-graphic-2x.png for the README banner)
  const big = (await p.locator('#feature').screenshot({ path: `${out}/feature-graphic-2x.png` })).toString('base64');
  const p1 = await b.newPage({ viewport: { width: 1024, height: 500 } });
  await p1.setContent('<body style="margin:0"><canvas width="1024" height="500"></canvas></body>');
  await p1.evaluate(async (src) => {
    const img = new Image();
    img.src = 'data:image/png;base64,' + src;
    await img.decode();
    const ctx = document.querySelector('canvas').getContext('2d');
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(img, 0, 0, 1024, 500);
  }, big);
  await p1.screenshot({ path: `${out}/feature-graphic.png` });
  console.log('feature-graphic');
  await b.close();
})();
