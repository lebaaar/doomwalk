const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const path = require('path');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1200, height: 2000 } });
  await p.goto('file://' + path.resolve(__dirname, 'graphics.html'));
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(300);
  const out = path.resolve(__dirname, '..');
  const names = { s1: 'screenshot-1-today', s2: 'screenshot-2-blocked', s4: 'screenshot-3-tiers', s5: 'screenshot-4-activity', s6: 'screenshot-5-landmarks', feature: 'feature-graphic' };
  for (const [id, n] of Object.entries(names)) {
    await p.locator('#' + id).screenshot({ path: `${out}/${n}.png` });
    console.log(n);
  }
  await b.close();
})();
