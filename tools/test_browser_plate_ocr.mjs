// Integration smoke test with synthetic plates, not an accuracy benchmark.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createServer} from 'node:http';
import {chromium} from '../admin-web/node_modules/playwright/index.mjs';

const manifest=JSON.parse(await readFile('assets/models/manifest.json','utf8'));
assert.equal(createHash('sha256').update(await readFile('assets/models/plate_detector.onnx')).digest('hex'),manifest.sha256);

// Public upstream examples are test data only, cached outside the shipped assets.
await mkdir('.smartpark/onnx-fixtures',{recursive:true});
for (const [name,url] of [
 ['alpr-example.png','https://raw.githubusercontent.com/ankandrew/fast-alpr/master/assets/test_image.png'],
 ['vietnam-camera.mp4','https://raw.githubusercontent.com/ddkhoa2605/LicensePlateDetection/main/Video_Test/video1.mp4'],
]) {
 try { await readFile('.smartpark/onnx-fixtures/'+name); }
 catch {
  const response=await fetch(url);assert.ok(response.ok,`fixture download: ${url}`);
  await writeFile('.smartpark/onnx-fixtures/'+name,new Uint8Array(await response.arrayBuffer()));
 }
}

const server = createServer(async (request, response) => {
 try {
  const path = new URL(request.url, 'http://localhost').pathname;
  if(path === '/') {
   response.setHeader('Content-Type','text/html');
   response.end('<!doctype html><html><head><meta charset="utf-8"></head><body><script src="/onnx/ort.wasm.min.js"></script><script src="/plate_detector.js"></script><script src="/plate_ocr.js"></script></body></html>');
   return;
  }
  const relative = path.startsWith('/fixtures/') ? '.smartpark/onnx-fixtures/'+path.slice(10)
   : path.startsWith('/assets/assets/') ? path.slice('/assets/'.length) : 'web'+path;
  if(relative.includes('..')) throw Error('Path');
  const mime=path.endsWith('.wasm')?'application/wasm':path.endsWith('.js')||path.endsWith('.mjs')?'application/javascript':'application/octet-stream';
  response.setHeader('Content-Type',mime);
  response.end(await readFile(new URL('../'+relative,import.meta.url)));
 } catch {response.statusCode=404;response.end();}
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
 browser = await chromium.launch({channel: 'chrome', headless: true});
 const page = await browser.newPage();
 page.setDefaultTimeout(60000);
 await page.goto(`http://127.0.0.1:${server.address().port}`);
 const real = await page.evaluate(async () => {
  await SmartParkOCR.prepare();
  const image = await createImageBitmap(await (await fetch('/fixtures/alpr-example.png')).blob());
  const canvas = document.createElement('canvas'); canvas.width=230; canvas.height=150;
  canvas.getContext('2d').drawImage(image,220,120,230,150,0,0,230,150); image.close();
  const boxes = await SmartParkDetector.detect(canvas);
  const blank = document.createElement('canvas'); blank.width=640;blank.height=360;
  blank.getContext('2d').fillRect(0,0,640,360);
  const empty = await SmartParkDetector.detect(blank);
  const video=document.createElement('video');video.muted=true;video.src=URL.createObjectURL(await (await fetch('/fixtures/vietnam-camera.mp4')).blob());
  await new Promise((resolve,reject)=>{video.onloadedmetadata=resolve;video.onerror=reject;});
  const frames=[]; let preview, plateLines;
  for(const second of [1,3,6,9]) {
   video.currentTime=Math.min(second,video.duration-.1);
   await new Promise(resolve=>video.onseeked=resolve);
   const frame=document.createElement('canvas');frame.width=video.videoWidth;frame.height=video.videoHeight;
   frame.getContext('2d').drawImage(video,0,0);
   if(!preview) preview=frame.toDataURL('image/png');
   {
    const scene=document.createElement('canvas');scene.width=1280;scene.height=720;
    const ctx=scene.getContext('2d');ctx.fillStyle='#69757b';ctx.fillRect(0,0,1280,720);
    ctx.drawImage(frame,224,126,832,468);
    const blob=await new Promise(resolve=>scene.toBlob(resolve,'image/jpeg'));
    plateLines=JSON.parse(await SmartParkOCR.read(new Uint8Array(await blob.arrayBuffer()))).lines;
   }
   const start=performance.now();
   frames.push({second, boxes:await SmartParkDetector.detect(frame), milliseconds:performance.now()-start,plateLines});
  }
  URL.revokeObjectURL(video.src);video.removeAttribute('src');video.load();
  return {boxes,empty,frames,preview,plateLines};
 });
 await writeFile('.smartpark/onnx-fixtures/vietnam-frame.png',Buffer.from(real.preview.split(',')[1],'base64'));
 delete real.preview;
 console.log('REAL_DETECTOR',JSON.stringify(real));
 assert.ok(real.boxes.some(b=>b.left < .6 && b.right > .6 && b.top < .6 && b.bottom > .5),'real plate should be localized');
 assert.equal(real.empty.length,0,'empty scene must not propose a plate');
 assert.ok(real.frames.every(f=>f.boxes.length),'model must detect the close plate in each sampled Vietnamese frame');
 for(const frame of real.frames) {
  const text=frame.plateLines.map(l=>l.text).join('').replace(/[^A-Z0-9]/g,'');
  const plate=text.match(/[0-9]{2}[A-Z]{1,2}[0-9]{4,6}/)?.[0];
  assert.ok(!plate || plate==='59V184625','low-confidence real OCR must not invent another valid plate');
 }
 // This skewed real sample localizes correctly but Tesseract may reject its text.
 // It is a detector/safe-rejection test, not evidence of full-plate OCR accuracy.


 const results = await page.evaluate(async () => {
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
 console.log(JSON.stringify(results));
 for (const result of results) {
  if (result.name === 'blank frame') { assert.equal(result.usable, false); continue; }
  assert.equal(result.usable, true);
  const plate = result.lines.map(line => line.text).join('').replace(/[^A-Z0-9]/g, '');
  assert.equal(plate, result.name.startsWith('motorcycle') ? '59X112345' : '43A12345', result.name);
  assert.ok(result.lines.every(line => line.left >= .1 && line.right <= .9 && line.top >= .25 && line.bottom <= .75));
 }
 console.log('PASS browser OCR: one row, two rows, mirrored webcam, plates on darker car backgrounds, blank-frame rejection');
} finally {
 await browser?.close();
 await new Promise(resolve => server.close(resolve));
}
