// E2E UI de VISIÓN: simula a un usuario real registrando su comida por foto.
// Flujo: /#/ai-settings -> base_url=Ollama del host + modelo gemma4:e4b -> Guardar
//        -> nav in-app a /#/diary (hash change, conserva la config en memoria)
//        -> botón cámara -> file picker (sube food.jpg real) -> /analyze-meal (gemma)
//        -> borrador "Borrador detectado" -> Guardar -> INSERT en nutrition.food_logs.
// Modos: 'probe' (para en el borrador y saca screenshot), 'save' (clic en Guardar).
import { chromium } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const BASE = process.argv[2] || 'http://localhost:8080';
const MODE = process.argv[3] || 'save';
const SHOTS = fileURLToPath(new URL('./shots/', import.meta.url));
const FOOD = fileURLToPath(new URL('./fixtures/food.jpg', import.meta.url));
mkdirSync(SHOTS, { recursive: true });
const shot = (p, n) => p.screenshot({ path: `${SHOTS}vision-${n}.png` });

const run = async () => {
  const browser = await chromium.launch({
    channel: 'chrome', headless: true,
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swapchain'],
  });
  const page = await (await browser.newContext({ viewport: { width: 1280, height: 900 } })).newPage();
  page.on('pageerror', (e) => console.log('  [pageerror]', String(e).slice(0, 160)));

  // 1) Ajustes de IA: override base_url a Ollama del host + modelo de visión.
  console.log('> goto /#/ai-settings');
  await page.goto(`${BASE}/#/ai-settings`, { waitUntil: 'load', timeout: 60000 });
  await page.waitForSelector('flt-glass-pane, flutter-view, canvas', { timeout: 60000 });
  await page.waitForTimeout(3000);
  await shot(page, '01-ajustes');

  await page.mouse.click(640, 251); // base_url
  await page.waitForTimeout(300);
  await page.keyboard.type('http://host.docker.internal:11434/v1', { delay: 12 });

  await page.mouse.click(640, 316); // modelo (trae sugerido por defecto -> limpiar)
  await page.waitForTimeout(300);
  await page.keyboard.press('Control+A');
  await page.keyboard.type('gemma4:e4b', { delay: 15 });
  await shot(page, '02-ajustes-lleno');

  await page.mouse.click(640, 380); // Guardar
  await page.waitForTimeout(2000);
  await shot(page, '03-tras-guardar');

  // 2) Navegación in-app al Diario (cambiar el hash NO recarga Dart -> conserva la config).
  console.log('> nav in-app a /#/diary');
  await page.evaluate(() => { window.location.hash = '#/diary'; });
  await page.waitForTimeout(4000);
  await shot(page, '04-diary');

  // 3) Preparar el file picker ANTES de pulsar la cámara.
  page.on('filechooser', async (fc) => {
    console.log('> filechooser -> subiendo', FOOD);
    await fc.setFiles(FOOD);
  });

  // Botón cámara (primera acción del AppBar, esquina superior derecha).
  console.log('> clic cámara');
  await page.mouse.click(1208, 30);
  await page.waitForTimeout(1500);
  await shot(page, '05-tras-camara');

  // 4) Esperar el borrador (gemma puede tardar; sondeo con screenshots cada 15s).
  console.log('> esperando /analyze-meal (gemma)...');
  for (let s = 15; s <= 90; s += 15) {
    await page.waitForTimeout(15000);
    await shot(page, `06-espera-${s}s`);
    console.log(`  ...${s}s`);
  }
  await shot(page, '07-borrador');

  if (MODE === 'probe') {
    console.log('> MODE=probe: no pulso Guardar. Revisa shots/vision-07-borrador.png');
    await browser.close();
    return;
  }

  // 5) Guardar el borrador -> INSERT en food_logs.
  // El ancho del diálogo varía con el largo del texto de gemma, así que el botón
  // "Guardar" se mueve; (820,541) cae dentro del botón para los anchos observados.
  console.log('> clic Guardar (borrador)');
  await page.mouse.click(Number(process.argv[4] || 820), Number(process.argv[5] || 541));
  await page.waitForTimeout(4000);
  await shot(page, '08-tras-guardar-borrador');

  await browser.close();
};
run().catch((e) => { console.error('FALLO:', e); process.exit(1); });
