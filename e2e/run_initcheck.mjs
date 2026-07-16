// Verifica el gate inicial: cargar la raíz '/' con un perfil existente debe
// llevar al Dashboard (no al Onboarding).
import { chromium } from '@playwright/test';
import { mkdirSync } from 'node:fs';

const BASE = process.argv[2] || 'http://localhost:8080';
const SHOTS = new URL('./shots/', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
mkdirSync(SHOTS, { recursive: true });

const run = async () => {
  const browser = await chromium.launch({
    channel: 'chrome', headless: true,
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swapchain'],
  });
  const page = await (await browser.newContext({ viewport: { width: 1280, height: 900 } })).newPage();
  console.log('> goto raíz', BASE);
  await page.goto(BASE, { waitUntil: 'load', timeout: 60000 });
  await page.waitForSelector('flt-glass-pane, flutter-view, canvas', { timeout: 60000 });
  await page.waitForTimeout(4000); // dar tiempo al check de perfil + primer frame
  await page.screenshot({ path: `${SHOTS}initcheck-root.png` });
  console.log('> screenshot initcheck-root listo');
  await browser.close();
};
run().catch((e) => { console.error('FALLO:', e); process.exit(1); });
