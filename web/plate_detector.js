/* YOLOv9 plate detector; ONNX Runtime and weights are bundled, not a cloud API. */
(() => {
  let ready, session;
  const size = 384;
  async function prepare() {
    return ready ??= (async () => {
      ort.env.wasm.numThreads = 1;
      ort.env.wasm.wasmPaths = new URL('onnx/', document.baseURI).href;
      session = await ort.InferenceSession.create('assets/assets/models/plate_detector.onnx', {
        executionProviders: ['wasm'], graphOptimizationLevel: 'all',
      });
    })().catch(error => { ready = null; throw error; });
  }
  async function detect(source) {
    await prepare();
    const scale = Math.min(size / source.width, size / source.height);
    const width = Math.round(source.width * scale), height = Math.round(source.height * scale);
    const dx = (size - width) / 2, dy = (size - height) / 2;
    const canvas = document.createElement('canvas'); canvas.width = canvas.height = size;
    const ctx = canvas.getContext('2d', {willReadFrequently:true});
    ctx.fillStyle = 'rgb(114,114,114)'; ctx.fillRect(0, 0, size, size);
    ctx.drawImage(source, Math.round(dx - .1), Math.round(dy - .1), width, height);
    const pixels = ctx.getImageData(0, 0, size, size).data;
    const plane = size * size, input = new Float32Array(plane * 3);
    for (let i = 0; i < plane; i++) for (let c = 0; c < 3; c++) input[c * plane + i] = pixels[i * 4 + c] / 255;
    const tensor = new ort.Tensor('float32', input, [1, 3, size, size]);
    let output;
    try {
      output = await session.run({[session.inputNames[0]]: tensor});
      const predictions = output[session.outputNames[0]];
      if (predictions.dims.at(-1) !== 7) throw Error('Đầu ra model biển số không hợp lệ.');
      const data = predictions.data, regions = [];
      for (let i = 0; i < data.length; i += 7) {
        if (data[i] !== 0 || data[i + 5] !== 0 || data[i + 6] < .5) continue;
        const left = (data[i + 1] - dx) / scale / source.width;
        const top = (data[i + 2] - dy) / scale / source.height;
        const right = (data[i + 3] - dx) / scale / source.width;
        const bottom = (data[i + 4] - dy) / scale / source.height;
        if (![left, top, right, bottom].every(Number.isFinite) ||
            left < -.02 || top < -.02 || right > 1.02 || bottom > 1.02 ||
            right - left < .15 || bottom - top < .07) continue;
        const padX = (right - left) * .04, padY = (bottom - top) * .08;
        regions.push({left:Math.max(0,left-padX), top:Math.max(0,top-padY),
          right:Math.min(1,right+padX), bottom:Math.min(1,bottom+padY),
          confidence:data[i+6], area:(right-left)*(bottom-top)});
      }
      return regions.sort((a,b)=>b.area-a.area).slice(0,4);
    } finally {
      tensor.dispose();
      if (output) for (const value of Object.values(output)) value.dispose();
    }
  }
  async function close() {
    try { await ready; } catch (_) { return; }
    await session?.release(); session = null; ready = null;
  }
  globalThis.SmartParkDetector = {prepare, detect, close};
})();
