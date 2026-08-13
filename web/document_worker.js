// Local browser worker for document images. No file leaves the device.
// A bounded number of these workers is created by the Flutter batch service.
self.onmessage = async (event) => {
  const { id, buffer, mode, outputType } = event.data;
  try {
    const bitmap = await createImageBitmap(new Blob([buffer]));
    const canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
    const context = canvas.getContext('2d', { willReadFrequently: true });
    context.drawImage(bitmap, 0, 0);
    bitmap.close();
    const image = context.getImageData(0, 0, canvas.width, canvas.height);
    enhance(image.data, canvas.width, canvas.height, mode || 'quality');
    context.putImageData(image, 0, 0);
    const blob = await canvas.convertToBlob({
      type: outputType || 'image/jpeg',
      quality: outputType === 'image/png' ? undefined : 0.94,
    });
    const resultBuffer = await blob.arrayBuffer();
    self.postMessage({ id, buffer: resultBuffer }, [resultBuffer]);
  } catch (error) {
    self.postMessage({ id, error: error?.message || String(error) });
  }
};

function enhance(data, width, height, mode) {
  const maxSide = mode === 'fast' ? 520 : mode === 'quality' ? 1100 : 800;
  const scale = Math.min(1, maxSide / Math.max(width, height));
  const sw = Math.max(1, Math.round(width * scale));
  const sh = Math.max(1, Math.round(height * scale));
  const luma = new Float32Array(sw * sh);
  for (let y = 0; y < sh; y++) for (let x = 0; x < sw; x++) {
    const sx = Math.min(width - 1, Math.floor(x / scale));
    const sy = Math.min(height - 1, Math.floor(y / scale));
    const i = (sy * width + sx) * 4;
    luma[y * sw + x] = .2126 * data[i] + .7152 * data[i + 1] + .0722 * data[i + 2];
  }
  const radius = mode === 'fast' ? 18 : mode === 'quality' ? 40 : 28;
  const local = blur(luma, sw, sh, radius);
  const broad = blur(luma, sw, sh, radius * 3);
  const paper = new Float32Array(luma.length);
  for (let i = 0; i < paper.length; i++) paper[i] = Math.max(local[i], broad[i] * .96);
  const config = mode === 'fast' ? [246, .92, .055] : mode === 'quality' ? [252, .72, .035] : [250, .82, .045];
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const i = (y * width + x) * 4;
    const bg = sample(paper, sw, sh, x * (sw - 1) / Math.max(1, width - 1), y * (sh - 1) / Math.max(1, height - 1));
    const lum = .2126 * data[i] + .7152 * data[i + 1] + .0722 * data[i + 2];
    const reflectance = ((lum / Math.max(18, bg)) - config[2]) / (1 - config[2]);
    const corrected = config[0] * Math.pow(Math.max(0, Math.min(1.08, reflectance)), config[1]);
    const keep = Math.pow(Math.max(0, Math.min(1, 1 - corrected / config[0])), .58);
    const factor = corrected / Math.max(1, lum);
    data[i] = channel(data[i], lum, corrected, factor, keep);
    data[i + 1] = channel(data[i + 1], lum, corrected, factor, keep);
    data[i + 2] = channel(data[i + 2], lum, corrected, factor, keep);
  }
}

function channel(v, l, corrected, factor, keep) { return Math.max(0, Math.min(255, Math.round(corrected + (v - l) * factor * keep))); }
function blur(values, w, h, r) {
  const integral = new Float64Array((w + 1) * (h + 1));
  for (let y = 1; y <= h; y++) { let row = 0; for (let x = 1; x <= w; x++) { row += values[(y - 1) * w + x - 1]; integral[y * (w + 1) + x] = integral[(y - 1) * (w + 1) + x] + row; } }
  const out = new Float32Array(values.length);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const t = Math.max(0, y - r), b = Math.min(h - 1, y + r), l = Math.max(0, x - r), q = Math.min(w - 1, x + r); out[y * w + x] = (integral[(b + 1) * (w + 1) + q + 1] - integral[t * (w + 1) + q + 1] - integral[(b + 1) * (w + 1) + l] + integral[t * (w + 1) + l]) / ((q - l + 1) * (b - t + 1)); }
  return out;
}
function sample(values, w, h, x, y) { const x0 = Math.max(0, Math.min(w - 1, Math.floor(x))), y0 = Math.max(0, Math.min(h - 1, Math.floor(y))), x1 = Math.min(w - 1, x0 + 1), y1 = Math.min(h - 1, y0 + 1), dx = x - x0, dy = y - y0; return values[y0 * w + x0] * (1-dx)*(1-dy) + values[y0*w+x1]*dx*(1-dy) + values[y1*w+x0]*(1-dx)*dy + values[y1*w+x1]*dx*dy; }
