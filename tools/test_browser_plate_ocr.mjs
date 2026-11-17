// Integration smoke test with synthetic plates, not an accuracy benchmark.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createServer} from 'node:http';
import {chromium} from '../admin-web/node_modules/playwright/index.mjs';

const script = await readFile(new URL('../web/plate_ocr.js', import.meta.url));
const server = createServer((request, response) => {
 if (request.url === '/plate_ocr.js') {
  response.writeHead(200, {'Content-Type': 'application/javascript'}); response.end(script);
 } else {
  response.writeHead(200, {'Content-Type': 'text/html'});
  response.end('<!doctype html><html><head><meta charset="utf-8"></head><body><script src="/plate_ocr.js"></script></body></html>');
 }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
 browser = await chromium.launch({channel: 'chrome', headless: true});
 const page = await browser.newPage();
 page.setDefaultTimeout(60000);
 await page.goto(`http://127.0.0.1:${server.address().port}`);
 const results = await page.evaluate(async () => {
  await SmartParkOCR.prepare();
  const output = [];
  for (const [name, texts, mirrored, fontSize = 86] of [
   ['single row', ['43A-123.45'], false],
   ['motorcycle', ['59-X1', '123.45'], false],
   ['front webcam', ['43A-123.45'], true],
   ['plate on car', ['43A-123.45'], false],
   ['small plate on car', ['43A-123.45'], false, 36],
   ['yellow plate on car', ['43A-123.45'], false],
   ['motorcycle plate on car', ['59-X1', '123.45'], false, 60],
   ['clutter around plate on car', ['43A-123.45'], false, 60],
   ['blank frame', [], false],
  ]) {
   const canvas = document.createElement('canvas'); canvas.width = 1280; canvas.height = 720;
   const context = canvas.getContext('2d');
   context.fillStyle = 'white'; context.fillRect(0, 0, 1280, 720);
   if (name.includes('plate on car')) {
    context.fillStyle='#6a777e'; context.fillRect(0,0,1280,720);
    const factor=fontSize/86;
    const twoRows=texts.length===2;
    context.fillStyle=name.startsWith('yellow')?'#ffdf3a':'white';
    context.fillRect(640-320*factor,twoRows?250:390-110*factor,640*factor,twoRows?210:160*factor);
    if(name.startsWith('clutter')){
     context.fillStyle='white'; context.font='bold 30px Arial'; context.textAlign='center';
     context.fillText('SMARTPARK 2026',640,220); context.fillText('PARKING AREA',640,490);
    }
   }
   if (mirrored) { context.translate(1280, 0); context.scale(-1, 1); }
   context.fillStyle = 'black'; context.font = `bold ${fontSize}px Arial`; context.textAlign = 'center';
   texts.forEach((text, i) => context.fillText(text, 640, texts.length === 1 ? 390 : 320 + i * 110));
   const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/jpeg'));
   const start = performance.now();
   const result = JSON.parse(await SmartParkOCR.read(new Uint8Array(await blob.arrayBuffer()), mirrored));
   output.push({name, milliseconds: Math.round(performance.now() - start), ...result});
  }
  await SmartParkOCR.close();
  return output;
 });
 for (const result of results) {
  if (result.name === 'blank frame') { assert.equal(result.usable, false); continue; }
  assert.equal(result.usable, true);
  const plate = result.lines.map(line => line.text).join('').replace(/[^A-Z0-9]/g, '');
  assert.equal(plate, result.name.startsWith('motorcycle') ? '59X112345' : '43A12345', result.name);
  assert.ok(result.lines.every(line => line.left >= .1 && line.right <= .9 && line.top >= .25 && line.bottom <= .75));
 }
 console.log(JSON.stringify(results));
 console.log('PASS browser OCR: one row, two rows, mirrored webcam, plates on darker car backgrounds, blank-frame rejection');
} finally {
 await browser?.close();
 await new Promise(resolve => server.close(resolve));
}
