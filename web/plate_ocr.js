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
      await Promise.all([loadRuntime(), SmartParkDetector.prepare()]);
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
  function plateRegions(source) {
    const probe = document.createElement('canvas');
    probe.width = Math.min(640, source.width);
    probe.height = Math.round(source.height * probe.width / source.width);
    const ctx = probe.getContext('2d', {willReadFrequently: true});
    ctx.drawImage(source, 0, 0, probe.width, probe.height);
    const {data} = ctx.getImageData(0, 0, probe.width, probe.height);
    const width = probe.width, height = probe.height;
    const mask = new Uint8Array(width * height);
    for (let i = 0; i < mask.length; i++) {
      const r = data[i * 4], g = data[i * 4 + 1], b = data[i * 4 + 2];
      // White and yellow plates. Dark lettering becomes holes in a bright region.
      mask[i] = (.299 * r + .587 * g + .114 * b > 155 &&
        (Math.max(r, g, b) - Math.min(r, g, b) < 95 || (r > 150 && g > 130 && b < g))) ? 1 : 0;
    }
    const queue = new Int32Array(mask.length), regions = [];
    for (let start = 0; start < mask.length; start++) {
      if (!mask[start]) continue;
      let head = 0, tail = 1, left = width, top = height, right = 0, bottom = 0;
      queue[0] = start; mask[start] = 0;
      while (head < tail) {
        const index = queue[head++], x = index % width, y = Math.floor(index / width);
        left = Math.min(left, x); right = Math.max(right, x);
        top = Math.min(top, y); bottom = Math.max(bottom, y);
        for (const next of [x > 0 ? index - 1 : -1, x + 1 < width ? index + 1 : -1,
          y > 0 ? index - width : -1, y + 1 < height ? index + width : -1]) {
          if (next >= 0 && mask[next]) { mask[next] = 0; queue[tail++] = next; }
        }
      }
      const regionWidth = right - left + 1, regionHeight = bottom - top + 1;
      const ratio = regionWidth / regionHeight, fill = tail / (regionWidth * regionHeight);
      if (regionWidth < width * .17 || regionHeight < height * .08 ||
          ratio < 1.05 || ratio > 7 || fill < .35 ||
          (regionWidth > width * .96 && regionHeight > height * .96)) continue;
      const padX = -regionWidth * .01, padY = -regionHeight * .01;
      regions.push({left: Math.max(0, (left - padX) / width), top: Math.max(0, (top - padY) / height),
        right: Math.min(1, (right + 1 + padX) / width), bottom: Math.min(1, (bottom + 1 + padY) / height),
        area: regionWidth * regionHeight});
    }
    // shortcut: bright-region proposals need calibration for plates merged into a bright car body; OCR falls back to the guide.
    return regions.sort((a, b) => b.area - a.area).slice(0, 4);
  }

  function binarize(canvas) {
    const ctx = canvas.getContext('2d', {willReadFrequently: true});
    const pixels = ctx.getImageData(0, 0, canvas.width, canvas.height);
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
  }

  function textLines(data, region) {
    const lines = [];
    for (const block of data.blocks ?? []) for (const paragraph of block.paragraphs ?? []) {
      for (const line of paragraph.lines ?? []) {
        if (line.confidence < 70) continue;
        const b = line.bbox;
        lines.push({text: line.text,
          left: .1 + (region.left + b.x0 / region.width * (region.right - region.left)) * .8,
          top: .25 + (region.top + b.y0 / region.height * (region.bottom - region.top)) * .5,
          right: .1 + (region.left + b.x1 / region.width * (region.right - region.left)) * .8,
          bottom: .25 + (region.top + b.y1 / region.height * (region.bottom - region.top)) * .5});
      }
    }
    return lines;
  }

  function hasPlateText(lines) {
    return /\d{2}[A-Z]{1,2}\d{4,6}/.test(lines.map(line => line.text).join('').replace(/[^A-Z0-9]/g, ''));
  }

  async function readRegion(source, region) {
    const canvas = document.createElement('canvas');
    const sourceWidth = source.width * (region.right - region.left);
    const sourceHeight = source.height * (region.bottom - region.top);
    const scale = Math.min(2, 960 / sourceWidth);
    const border = 20;
    const contentWidth = Math.round(sourceWidth * scale), contentHeight = Math.round(sourceHeight * scale);
    canvas.width = contentWidth + border * 2; canvas.height = contentHeight + border * 2;
    const ctx = canvas.getContext('2d', {willReadFrequently: true});
    ctx.fillStyle = 'white'; ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(source, source.width * region.left, source.height * region.top,
      sourceWidth, sourceHeight, border, border, contentWidth, contentHeight);
    const padX = border / contentWidth * (region.right - region.left);
    const padY = border / contentHeight * (region.bottom - region.top);
    const coordinates = {left: region.left - padX, top: region.top - padY,
      right: region.right + padX, bottom: region.bottom + padY, width: canvas.width, height: canvas.height};
    await worker.setParameters({tessedit_pageseg_mode: '6'});
    let {data} = await worker.recognize(canvas, {}, {blocks: true});
    let lines = textLines(data, coordinates);
    if (hasPlateText(lines)) return lines;
    binarize(canvas);
    ({data} = await worker.recognize(canvas, {}, {blocks: true}));
    lines = textLines(data, coordinates);
    if (hasPlateText(lines)) return lines;
    await worker.setParameters({tessedit_pageseg_mode: '11'});
    ({data} = await worker.recognize(canvas, {}, {blocks: true}));
    return textLines(data, coordinates);
  }

  async function read(bytes, mirrored = false) {
    await ensureReady();
    const bitmap = await createImageBitmap(new Blob([bytes]));
    try {
      const canvas = document.createElement('canvas');
      const cropWidth = bitmap.width * .8, cropHeight = bitmap.height * .5;
      const scale = Math.min(1, 1600 / cropWidth);
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
      const lines = [];
      const detected = await SmartParkDetector.detect(canvas);
      const regions = detected.length ? detected : plateRegions(canvas);
      for (const region of regions) lines.push(...await readRegion(canvas, region));

      // shortcut: fall back to the existing OCR for unfamiliar/printed plate shapes.
      if (!hasPlateText(lines) && detected.length) {
        for (const region of plateRegions(canvas)) lines.push(...await readRegion(canvas, region));
      }
      if (!hasPlateText(lines)) {
        lines.push(...await readRegion(canvas, {left:0, top:0, right:1, bottom:1}));
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
    await SmartParkDetector.close();
  }
  globalThis.SmartParkOCR = {prepare, read, close};
})();
