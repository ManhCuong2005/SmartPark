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
    window.cameraScene = 'far';
    window.testBookingActive = false;
    window.viAnnouncements = [];
    const play = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function(...args) {
      this.addEventListener('ended', () => {
        if (this.currentSrc.includes('_vi.mp3')) window.viAnnouncements.push(this.currentSrc);
      }, {once:true});
      return play.apply(this,args);
    };
    navigator.mediaDevices.enumerateDevices = async () => [
      {deviceId:'front-test',kind:'videoinput',label:'Front test camera',groupId:'test'},
      {deviceId:'usb-test',kind:'videoinput',label:'USB test camera',groupId:'test'},
    ];
    navigator.mediaDevices.getUserMedia = async () => {
      const canvas = document.createElement('canvas'); canvas.width=1280; canvas.height=720;
      const ctx=canvas.getContext('2d');
      function paint() {
        ctx.fillStyle='#6a777e'; ctx.fillRect(0,0,1280,720);
        function plate(text,x,y,size) {
          const factor=size/86;
          ctx.fillStyle='#fff'; ctx.fillRect(x-320*factor,y-110*factor,640*factor,160*factor);
          ctx.fillStyle='#000'; ctx.font=`bold ${size}px Arial`; ctx.textAlign='center'; ctx.fillText(text,x,y);
        }
        if(window.cameraScene==='far') plate('43B-678.90',640,390,22);
        if(window.cameraScene==='ambiguous') {
          plate('43A-123.45',420,320,60); plate('43B-678.90',850,460,60);
        }
        if(window.cameraScene==='near') {
          plate('43B-678.90',920,250,22); plate('43A-123.45',640,430,64);
          ctx.fillStyle='white'; ctx.font='bold 24px Arial'; ctx.fillText('PARKING AREA 2026',640,200);
        }
      }
      paint(); setInterval(paint,100);
      return canvas.captureStream(10);
    };
  });
  const url=`http://127.0.0.1:${server.address().port}`;
  async function openLane(lane) {
    const page=await context.newPage();
    activePage=page;
    page.on('pageerror', error => console.log('PAGE ERROR', error.message));
    const scans=[];
    page.on('console', message => {
      if(message.text().startsWith('KIOSK_SCAN:')) scans.push(JSON.parse(message.text().slice('KIOSK_SCAN:'.length)));
    });
    await page.goto(url);
    await page.getByRole('button',{name:/^Test Parking/}).click();
    await page.getByRole('button',{name:new RegExp('^'+lane)}).click();
    await page.getByRole('button',{name:lane==='Cam vào'?'Camera 1 · Front test camera':'Camera 2 · USB test camera',exact:true}).click();
    await page.getByText(/Tự quét · Đã đọc [3-9]\d* khung/).waitFor({timeout:60000});
    assert.equal(scans.length,0,'far plate must not trigger a scan');
    await page.evaluate(()=>window.cameraScene='ambiguous');
    await page.getByText('Có nhiều biển gần nhau · Chỉ giữ một xe trong vùng quét',{exact:true}).waitFor({timeout:60000});
    assert.equal(scans.length,0,'equal targets must not trigger a scan');
    const firstScanStart = Date.now();
    await page.evaluate(()=>window.cameraScene='near');
    await page.locator('flt-semantics-host').getByText('Xe chưa đăng ký đỗ online hoặc quét nhầm, vui lòng thử lại',{exact:true}).waitFor({timeout:60000});
    assert.equal(scans.length,1,'missing booking is rejected by the running session');
    console.log(`PASS ${lane}: three-frame recognition to backend response ${Date.now()-firstScanStart}ms (test backend)`);
    await page.waitForFunction(()=>window.viAnnouncements.length > 0, {timeout:30000});
    assert.ok((await page.evaluate(()=>window.viAnnouncements[0])).includes('scan_invalid_ticket_vi.mp3'));
    // A booking arrives after rejection. Keep the page and camera session open.
    const start = Date.now();
    await page.evaluate(()=>window.testBookingActive=true);
    await page.locator('flt-semantics-host').getByText('Đã xử lý biển số này · Chờ xe tiếp theo',{exact:true}).waitFor({timeout:60000});
    assert.equal(scans.length,2,'new booking is accepted without reload, then the standing vehicle is blocked');
    assert.ok(Date.now()-start < 15000, 'new booking should be accepted after the five-second cooldown');
    console.log(`PASS ${lane}: new booking without reload, Vietnamese audio completed; retry ${Date.now()-start}ms including 5s cooldown`);
    assert.equal(scans[0].plate,'43A12345');
    assert.equal(scans[0].direction,lane==='Cam vào'?'entry':'exit');
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
  const entry=await openLane('Cam vào');
  const exit=await openLane('Cam ra');
  await entry.reload();
  await entry.getByText('Cam vào · Test Parking',{exact:true}).waitFor({timeout:60000});
  assert.equal(await entry.getByText('Cam ra · Test Parking',{exact:true}).count(),0);
  await exit.reload();
  await exit.getByText('Cam ra · Test Parking',{exact:true}).waitFor({timeout:60000});
  console.log('PASS Flutter browser camera: far plates rejected, ambiguous plates wait, nearest plate auto scanned, duplicates blocked, upright preview, independent lanes');
} catch(error) {
  if(activePage) {
    console.log((await activePage.locator('flt-semantics-host').textContent()).slice(-3000));
    await activePage.screenshot({path:'.smartpark/ui-review/browser-camera-failure.png'});
  }
  throw error;
} finally { await browser?.close(); await new Promise(resolve => server.close(resolve)); }
