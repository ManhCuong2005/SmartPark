/* Images stay in the browser. The pinned OCR runtime/model loads on first use. */
(() => {
  let ready;
  let worker;
  let scriptReady;
  let users = 0;
  function loadRuntime() {
    if (globalThis.Tesseract) return Promise.resolve();
    return scriptReady ??= new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://cdn.jsdelivr.net/npm/tesseract.js@6.0.1/dist/tesseract.min.js';
      script.onload = resolve;
      script.onerror = () => { scriptReady = null; script.remove(); reject(new Error('Không tải được bộ OCR. Kiểm tra kết nối mạng.')); };
      document.head.appendChild(script);
    });
  }
  async function ensureReady() {
    return ready ??= (async () => {
      await loadRuntime();
      worker = await Tesseract.createWorker('eng', 1, {
        workerPath: 'https://cdn.jsdelivr.net/npm/tesseract.js@6.0.1/dist/worker.min.js',
        corePath: 'https://cdn.jsdelivr.net/npm/tesseract.js-core@6.0.0',
        langPath: 'https://tessdata.projectnaptha.com/4.0.0',
      });
      await worker.setParameters({
        tessedit_char_whitelist: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.',
        tessedit_pageseg_mode: '6',
      });
    })().catch(async error => {
      if (worker) await worker.terminate();
      worker = null;
      ready = null;
      throw error;
    });
  }
  async function prepare() {
    users++;
    try { await ensureReady(); } catch (error) { users--; throw error; }
  }
  async function read(bytes, mirrored = false) {
    await ensureReady();
    const bitmap = await createImageBitmap(new Blob([bytes]));
    try {
      const canvas = document.createElement('canvas');
      // shortcut: OCR reads the center guide; add a plate detector after camera calibration if distant plates must work.
      const cropWidth = bitmap.width * .8, cropHeight = bitmap.height * .5;
      // Enlarge small webcam text; cap large images to keep automatic reads responsive.
      const scale = Math.min(2, 1600 / cropWidth);
      canvas.width = Math.round(cropWidth * scale);
      canvas.height = Math.round(cropHeight * scale);
      const ctx = canvas.getContext('2d', {willReadFrequently: true});
      if (mirrored) { ctx.translate(canvas.width, 0); ctx.scale(-1, 1); }
      ctx.drawImage(bitmap, bitmap.width * .1, bitmap.height * .25,
        bitmap.width * .8, bitmap.height * .5, 0, 0, canvas.width, canvas.height);
      const pixels = ctx.getImageData(0, 0, canvas.width, canvas.height);
      let sum = 0, squares = 0, n = 0;
      for (let i = 0; i < pixels.data.length; i += 64) {
        const gray = .299 * pixels.data[i] + .587 * pixels.data[i + 1] + .114 * pixels.data[i + 2];
        sum += gray; squares += gray * gray; n++;
      }
      const mean = sum / n;
      if (!n || mean < 18 || squares / n - mean * mean < 8) {
        return JSON.stringify({usable: false, lines: []});
      }
      // Local thresholding keeps a bright plate readable against a darker car.
      const width = canvas.width, height = canvas.height, stride = width + 1;
      const integral = new Float64Array(stride * (height + 1));
      const gray = new Uint8Array(width * height);
      for (let y = 0; y < height; y++) {
        let rowSum = 0;
        for (let x = 0; x < width; x++) {
          const i = y * width + x, p = i * 4;
          gray[i] = Math.round(.299 * pixels.data[p] + .587 * pixels.data[p + 1] + .114 * pixels.data[p + 2]);
          rowSum += gray[i];
          integral[(y + 1) * stride + x + 1] = integral[y * stride + x + 1] + rowSum;
        }
      }
      const radius = Math.max(16, Math.round(height * .08));
      for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
        const left = Math.max(0, x - radius), right = Math.min(width, x + radius + 1);
        const top = Math.max(0, y - radius), bottom = Math.min(height, y + radius + 1);
        const localMean = (integral[bottom * stride + right] - integral[top * stride + right]
          - integral[bottom * stride + left] + integral[top * stride + left]) / ((right - left) * (bottom - top));
        const i = y * width + x, value = gray[i] < localMean - 12 ? 0 : 255;
        pixels.data[i * 4] = pixels.data[i * 4 + 1] = pixels.data[i * 4 + 2] = value;
      }
      ctx.putImageData(pixels, 0, 0);
      const {data} = await worker.recognize(canvas, {}, {blocks: true});
      const lines = [];
      for (const block of data.blocks ?? []) for (const paragraph of block.paragraphs ?? []) {
        for (const line of paragraph.lines ?? []) {
          const b = line.bbox;
          if (line.confidence < 70 || (b.y1 - b.y0) / scale < 12) continue;
          lines.push({text: line.text, left: .1 + b.x0 / canvas.width * .8,
            top: .25 + b.y0 / canvas.height * .5, right: .1 + b.x1 / canvas.width * .8,
            bottom: .25 + b.y1 / canvas.height * .5});
        }
      }
      return JSON.stringify({usable: true, lines});
    } finally { bitmap.close(); }
  }
  async function close() {
    users = Math.max(0, users - 1);
    try { await ready; } catch (_) { /* Initialization already reported the error. */ }
    if (users > 0) return;
    const previous = worker;
    worker = null;
    ready = null;
    if (previous) await previous.terminate();
  }
  globalThis.SmartParkOCR = {prepare, read, close};
})();
