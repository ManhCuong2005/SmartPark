// Real Flutter camera_web + Tesseract; synthetic video and a test-only backend.
// SQL authorization and settlement are exercised separately by test_backend.mjs.
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile, mkdir} from 'node:fs/promises';
import {resolve, extname} from 'node:path';
import {chromium} from '../admin-web/node_modules/playwright/index.mjs';
const root = resolve('build/camera-probe');
const server = createServer(async (request, response) => {
  try {
    const path = resolve(root, '.' + new URL(request.url, 'http://localhost').pathname);
    if (!path.startsWith(root + '/') && !path.startsWith(root + '\\') && path !== root) throw Error('Path');
    const file = path === root ? resolve(root, 'index.html') : path;
    response.setHeader('Content-Type', ({'.js':'application/javascript','.wasm':'application/wasm','.html':'text/html','.json':'application/json'})[extname(file)] ?? 'application/octet-stream');
    response.end(await readFile(file));
  } catch { response.statusCode = 404; response.end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
let activePage;
try {
  browser = await chromium.launch({channel:'chrome', headless:true});
  const context = await browser.newContext({viewport:{width:1280,height:900}});
  await context.addInitScript(() => {
    navigator.mediaDevices.enumerateDevices = async () => [
      {deviceId:'front-test',kind:'videoinput',label:'Front test camera',groupId:'test'},
      {deviceId:'usb-test',kind:'videoinput',label:'USB test camera',groupId:'test'},
    ];
    navigator.mediaDevices.getUserMedia = async () => {
      const canvas = document.createElement('canvas'); canvas.width=1280; canvas.height=720;
      const ctx=canvas.getContext('2d');
      function paint() {
        ctx.fillStyle='#6a777e'; ctx.fillRect(0,0,1280,720);
        ctx.fillStyle='#fff'; ctx.fillRect(320,280,640,160);
        ctx.fillStyle='#000'; ctx.font='bold 86px Arial'; ctx.textAlign='center'; ctx.fillText('43A-123.45',640,390);
      }
      paint(); setInterval(paint,100);
      return canvas.captureStream(10);
    };
  });
  const url=`http://127.0.0.1:${server.address().port}`;
  async function openLane(lane, expected) {
    const page=await context.newPage();
    activePage=page;
    page.on('pageerror', error => console.log('PAGE ERROR', error.message));
    await page.goto(url);
    await page.getByRole('button',{name:/^Test Parking/}).click();
    await page.getByRole('button',{name:new RegExp('^'+lane)}).click();
    await page.getByRole('button',{name:lane==='Cam vào'?'Camera 1 · Front test camera':'Camera 2 · USB test camera',exact:true}).click();
    await page.locator('flt-semantics-host').getByText(expected,{exact:true}).waitFor({timeout:90000});
    const video=page.locator('video').first(); await video.waitFor({state:'attached'});
    const orientation=await video.evaluate(video => {
      let scale=1;
      for(let el=video;el;el=el.assignedSlot ?? el.parentElement ?? el.getRootNode().host) {
        const t=getComputedStyle(el).transform;
        if(t!=='none') scale*=new DOMMatrix(t).m11;
      }
      return scale;
    });
    assert.ok(orientation>0, `${lane}: preview still mirrored (${orientation})`);
    await mkdir('.smartpark/ui-review',{recursive:true});
    await page.screenshot({path:`.smartpark/ui-review/${lane==='Cam vào'?'entry':'exit'}-browser-camera.png`});
    return page;
  }
  const entry=await openLane('Cam vào','Xe vào hợp lệ');
  const exit=await openLane('Cam ra','Đã thanh toán · Xe ra hợp lệ');
  await entry.reload();
  await entry.getByText('Cam vào · Test Parking',{exact:true}).waitFor({timeout:60000});
  assert.equal(await entry.getByText('Cam ra · Test Parking',{exact:true}).count(),0);
  await exit.reload();
  await exit.getByText('Cam ra · Test Parking',{exact:true}).waitFor({timeout:60000});
  console.log('PASS Flutter browser camera: upright preview, automatic entry/exit recognition, independent lane restore across tabs');
} catch(error) {
  if(activePage) {
    console.log((await activePage.locator('flt-semantics-host').textContent()).slice(-3000));
    await activePage.screenshot({path:'.smartpark/ui-review/browser-camera-failure.png'});
  }
  throw error;
} finally { await browser?.close(); await new Promise(resolve => server.close(resolve)); }
