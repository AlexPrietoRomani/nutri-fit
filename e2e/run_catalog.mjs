// E2E: navega al catálogo de ejercicios (F7) y captura los thumbnails.
// Deep-link a /training -> Iniciar entrenamiento vacío -> Agregar Ejercicio (modal).
import { chromium } from '@playwright/test';
import { mkdirSync } from 'node:fs';

const BASE = process.argv[2] || 'http://localhost:8080';
const SHOTS = new URL('./shots/', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
mkdirSync(SHOTS, { recursive: true });
const shot = (page, name) => page.screenshot({ path: `${SHOTS}catalog-${name}.png` });

const run = async () => {
  const browser = await chromium.launch({
    channel: 'chrome', headless: true,
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swapchain'],
  });
  const page = await (await browser.newContext({ viewport: { width: 1280, height: 900 } })).newPage();
  const imgReqs = [];
  page.on('request', (r) => { if (/free-exercise-db.*\.jpg/.test(r.url())) imgReqs.push(r.url()); });

  // Deep-link con hash routing (Flutter web por defecto usa #/)
  const url = `${BASE}/#/training`;
  console.log('> goto', url);
  await page.goto(url, { waitUntil: 'load', timeout: 60000 });
  await page.waitForSelector('flt-glass-pane, flutter-view, canvas', { timeout: 60000 });
  await page.waitForTimeout(4000);
  await shot(page, '01-training');

  // "Iniciar Entrenamiento Vacío": card superior.
  await page.mouse.click(640, 130);
  await page.waitForTimeout(2500);
  await shot(page, '02-active');

  // "Agregar Ejercicio": botón inferior.
  await page.mouse.click(640, 856);
  await page.waitForTimeout(3500); // dar tiempo a cargar thumbnails desde GitHub
  await shot(page, '03-modal-exercises');
  // scroll dentro del modal para ver más
  await page.mouse.wheel(0, 400);
  await page.waitForTimeout(2500);
  await shot(page, '04-modal-scrolled');

  console.log('> Requests de imágenes de ejercicio detectadas:', imgReqs.length);
  imgReqs.slice(0, 3).forEach((u) => console.log('   ', u));
  await browser.close();
  console.log('> OK');
};
run().catch((e) => { console.error('FALLO:', e); process.exit(1); });
