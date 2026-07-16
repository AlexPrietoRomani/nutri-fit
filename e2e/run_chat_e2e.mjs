// E2E UI del chat de IA con Ollama del host.
// Flujo: /#/chat -> abrir Ajustes (gear) -> base_url=Ollama + modelo -> Guardar
//        -> volver al chat -> enviar mensaje -> ver respuesta del asistente.
import { chromium } from '@playwright/test';
import { mkdirSync } from 'node:fs';

const BASE = process.argv[2] || 'http://localhost:8080';
const SHOTS = new URL('./shots/', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
mkdirSync(SHOTS, { recursive: true });
const shot = (p, n) => p.screenshot({ path: `${SHOTS}chat-${n}.png` });

const run = async () => {
  const browser = await chromium.launch({
    channel: 'chrome', headless: true,
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swapchain'],
  });
  const page = await (await browser.newContext({ viewport: { width: 1280, height: 900 } })).newPage();
  page.on('pageerror', (e) => console.log('  [pageerror]', String(e).slice(0, 160)));

  console.log('> goto /#/chat');
  await page.goto(`${BASE}/#/chat`, { waitUntil: 'load', timeout: 60000 });
  await page.waitForSelector('flt-glass-pane, flutter-view, canvas', { timeout: 60000 });
  await page.waitForTimeout(3000);
  await shot(page, '02-chat-sin-config');

  // Abrir Ajustes con el engranaje (esquina superior derecha del AppBar).
  await page.mouse.click(1240, 28);
  await page.waitForTimeout(2000);
  await shot(page, '03-ajustes');

  // Rellenar base_url (campo ~y251) apuntando a Ollama del host.
  await page.mouse.click(640, 251);
  await page.waitForTimeout(400);
  await page.keyboard.type('http://host.docker.internal:11434/v1', { delay: 15 });

  // Reemplazar el modelo (campo ~y316, trae 'gpt-4o-mini' por defecto).
  await page.mouse.click(640, 316);
  await page.waitForTimeout(400);
  await page.keyboard.press('Control+A');
  await page.keyboard.type('llama3.2:latest', { delay: 15 });
  await shot(page, '04-ajustes-lleno');

  // Guardar (botón ~y380) -> vuelve al chat.
  await page.mouse.click(640, 380);
  await page.waitForTimeout(2000);
  await shot(page, '05-tras-guardar');

  // Escribir un mensaje en el input del chat (parte inferior) y enviar.
  await page.mouse.click(600, 850);
  await page.waitForTimeout(400);
  await page.keyboard.type('Dame una recomendacion corta de desayuno alto en proteina', { delay: 10 });
  await page.keyboard.press('Enter');
  console.log('> mensaje enviado, esperando respuesta de Ollama...');

  // Esperar la respuesta (Ollama). Sondear hasta ~90s tomando screenshots.
  await page.waitForTimeout(90000);
  await shot(page, '06-respuesta');
  console.log('> screenshot 06-respuesta listo');

  await browser.close();
};
run().catch((e) => { console.error('FALLO:', e); process.exit(1); });
