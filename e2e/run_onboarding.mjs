// E2E: simula el arranque de un usuario en la app web (Flutter CanvasKit).
// Conduce el onboarding: escribe nombre -> avanza los 8 pasos (defaults) ->
// "Calcular y Registrar", capturando screenshots y los logs de Supabase.
// Uso: node run_onboarding.mjs [baseUrl] [device]
import { chromium, devices } from '@playwright/test';
import { mkdirSync } from 'node:fs';

const BASE = process.argv[2] || 'http://localhost:8080';
const MODE = process.argv[3] || 'desktop';
const SHOTS = new URL('./shots/', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
mkdirSync(SHOTS, { recursive: true });
const shot = (page, name) => page.screenshot({ path: `${SHOTS}${MODE}-${name}.png` });

const run = async () => {
  const browser = await chromium.launch({
    channel: 'chrome',
    headless: true,
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swapchain'],
  });
  const size = MODE === 'mobile' ? { width: 412, height: 915 } : { width: 1280, height: 900 };
  const ctx = await browser.newContext({ viewport: size, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  const logs = [];
  page.on('console', (m) => logs.push(`${m.type()}: ${m.text()}`));
  page.on('pageerror', (e) => logs.push(`pageerror: ${String(e)}`));

  console.log(`> Cargando ${BASE} (${MODE} ${size.width}x${size.height})`);
  await page.goto(BASE, { waitUntil: 'load', timeout: 60000 });
  await page.waitForSelector('flt-glass-pane, flutter-view, canvas', { timeout: 60000 });
  await page.waitForTimeout(3000);
  await shot(page, '01-nombre');

  // Paso 1: enfocar el campo por coordenadas (Flutter crea el <input> al enfocar) y teclear.
  const fieldX = Math.round(size.width / 2);
  const fieldY = MODE === 'mobile' ? 470 : 489;
  await page.mouse.click(fieldX, fieldY);
  await page.waitForTimeout(500);
  await page.keyboard.type('Playwright Tester', { delay: 40 });
  console.log('> Nombre tecleado.');
  await shot(page, '02-nombre-lleno');

  // Botón inferior-derecha (Siguiente / Calcular y Registrar), posición estable.
  const btnX = size.width - 90;
  const btnY = size.height - 44;

  // Avanzar los pasos aceptando los valores por defecto del provider.
  for (let step = 2; step <= 8; step++) {
    await page.mouse.click(btnX, btnY);
    await page.waitForTimeout(900);
    await shot(page, `step-${step}`);
    console.log(`> Avanzado a paso ${step}`);
  }

  // Último clic: "Calcular y Registrar" -> dispara INSERT a Supabase.
  await page.mouse.click(btnX, btnY);
  await page.waitForTimeout(4000);
  await shot(page, '09-post-registro');
  console.log('> Registro disparado.');

  console.log('> LOGS navegador (filtrados supabase/error):');
  logs.filter((l) => /supabase|error|insert|post|goal|user/i.test(l))
    .slice(-25).forEach((l) => console.log('   ', l.slice(0, 220)));

  await browser.close();
  console.log('> OK');
};

run().catch((e) => { console.error('FALLO E2E:', e); process.exit(1); });
