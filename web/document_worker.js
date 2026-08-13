// Local browser worker for document images. No file leaves the device.
// A bounded number of these workers is created by the Flutter batch service.
self.onmessage = async (event) => {
  const { id, buffer, mode, outputType, autoCrop } = event.data;
  try {
    const bitmap = await createImageBitmap(new Blob([buffer]));
    let canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
    let context = canvas.getContext('2d', { willReadFrequently: true });
    context.drawImage(bitmap, 0, 0);
    bitmap.close();
    if (autoCrop) {
      const detected = detectDocumentQuad(context.getImageData(0, 0, canvas.width, canvas.height));
      if (detected) {
        canvas = perspectiveWarp(context.getImageData(0, 0, canvas.width, canvas.height), detected);
        context = canvas.getContext('2d', { willReadFrequently: true });
      }
    }
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

// Detects a high-confidence, visible four-sided page. The output is null when
// a border is absent: cropping a partially photographed or curled document is
// worse than preserving the source geometry.
function detectDocumentQuad(image) {
  const { data, width, height } = image;
  if (width < 160 || height < 160) return null;
  const max = 360, scale = Math.min(1, max / Math.max(width, height));
  const w = Math.max(80, Math.round(width * scale)), h = Math.max(80, Math.round(height * scale));
  const gray = new Float32Array(w * h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const sx = Math.min(width - 1, Math.round(x / scale)), sy = Math.min(height - 1, Math.round(y / scale));
    const i = (sy * width + sx) * 4;
    gray[y * w + x] = .2126 * data[i] + .7152 * data[i + 1] + .0722 * data[i + 2];
  }
  const top = fitBoundary([.12, .44, .76], w, x => verticalEdge(gray, w, h, x), h, .03, .47);
  const bottom = fitBoundary([.12, .44, .76], w, x => verticalEdge(gray, w, h, x), h, .53, .97);
  const left = fitBoundary([.12, .44, .76], h, y => horizontalEdge(gray, w, h, y), w, .03, .47);
  const right = fitBoundary([.12, .44, .76], h, y => horizontalEdge(gray, w, h, y), w, .53, .97);
  if (!top || !bottom || !left || !right) return null;
  const tl = intersect(top, left), tr = intersect(top, right), br = intersect(bottom, right), bl = intersect(bottom, left);
  const quad = [tl, tr, br, bl].map(p => ({ x: p.x / scale, y: p.y / scale }));
  if (!quad.every(p => p.x >= 0 && p.y >= 0 && p.x < width && p.y < height)) return null;
  const area = polygonArea(quad);
  if (area < width * height * .18) return null;
  return quad;
}

function verticalEdge(gray, w, h, x) {
  return y => Math.abs(gray[Math.min(h-1,y+1)*w+x] - gray[Math.max(0,y-1)*w+x]);
}
function horizontalEdge(gray, w, h, y) {
  return x => Math.abs(gray[y*w+Math.min(w-1,x+1)] - gray[y*w+Math.max(0,x-1)]);
}
// Fits a boundary line from three evenly distributed scans. A candidate must
// have a pronounced gradient, preventing arbitrary text strokes becoming page edges.
function fitBoundary(samples, scanLength, gradient, length, minFraction, maxFraction) {
  const points = [];
  for (const fraction of samples) {
    const scan = Math.max(1, Math.min(scanLength - 2, Math.round(fraction * (scanLength - 1))));
    let best = -1, bestAt = -1;
    const start = Math.round(length * minFraction), end = Math.round(length * maxFraction);
    for (let p = start; p < end; p++) { const value = gradient(scan)(p); if (value > best) { best = value; bestAt = p; } }
    if (best < 18) return null;
    points.push([scan, bestAt]);
  }
  // p = a*scan + b. For horizontal edges scan=x/p=y; callers orient values.
  const mx = points.reduce((s,p)=>s+p[0],0)/points.length, my = points.reduce((s,p)=>s+p[1],0)/points.length;
  const denominator = points.reduce((s,p)=>s+(p[0]-mx)*(p[0]-mx),0);
  if (!denominator) return null;
  const a = points.reduce((s,p)=>s+(p[0]-mx)*(p[1]-my),0)/denominator;
  return { a, b: my - a * mx };
}
function intersect(horizontal, vertical) {
  // horizontal: y=a*x+b, vertical: x=a*y+b
  const denominator = 1 - horizontal.a * vertical.a;
  if (Math.abs(denominator) < .05) return { x: -1, y: -1 };
  const y = (horizontal.a * vertical.b + horizontal.b) / denominator;
  return { x: vertical.a * y + vertical.b, y };
}
function polygonArea(p) { let sum=0; for(let i=0;i<4;i++) { const q=p[(i+1)%4]; sum += p[i].x*q.y-q.x*p[i].y; } return Math.abs(sum/2); }

function perspectiveWarp(image, quad) {
  const width = Math.max(1, Math.round((distance(quad[0],quad[1])+distance(quad[3],quad[2]))/2));
  const height = Math.max(1, Math.round((distance(quad[0],quad[3])+distance(quad[1],quad[2]))/2));
  const output = new OffscreenCanvas(width, height), context = output.getContext('2d');
  const result = context.createImageData(width, height), h = solveHomography(width, height, quad);
  for (let y=0;y<height;y++) for(let x=0;x<width;x++) {
    const divisor=h[6]*x+h[7]*y+1, sx=(h[0]*x+h[1]*y+h[2])/divisor, sy=(h[3]*x+h[4]*y+h[5])/divisor;
    sampleRgba(image.data, image.width, image.height, sx, sy, result.data, (y*width+x)*4);
  }
  context.putImageData(result,0,0); return output;
}
function distance(a,b) { return Math.hypot(a.x-b.x,a.y-b.y); }
function solveHomography(w,h,q) {
  const dst=[[0,0],[w-1,0],[w-1,h-1],[0,h-1]], rows=[];
  for(let i=0;i<4;i++) { const [x,y]=dst[i], {x:X,y:Y}=q[i]; rows.push([x,y,1,0,0,0,-x*X,-y*X,X]); rows.push([0,0,0,x,y,1,-x*Y,-y*Y,Y]); }
  for(let c=0;c<8;c++) { let pivot=c; for(let r=c+1;r<8;r++) if(Math.abs(rows[r][c])>Math.abs(rows[pivot][c])) pivot=r; [rows[c],rows[pivot]]=[rows[pivot],rows[c]]; const d=rows[c][c]; for(let j=c;j<=8;j++) rows[c][j]/=d; for(let r=0;r<8;r++) if(r!==c) { const f=rows[r][c]; for(let j=c;j<=8;j++) rows[r][j]-=f*rows[c][j]; } }
  return rows.map(row=>row[8]);
}
function sampleRgba(source,w,h,x,y,target,i) { const x0=Math.max(0,Math.min(w-1,Math.floor(x))), y0=Math.max(0,Math.min(h-1,Math.floor(y))), x1=Math.min(w-1,x0+1), y1=Math.min(h-1,y0+1), dx=x-x0, dy=y-y0; for(let c=0;c<4;c++) { const a=source[(y0*w+x0)*4+c]*(1-dx)+source[(y0*w+x1)*4+c]*dx, b=source[(y1*w+x0)*4+c]*(1-dx)+source[(y1*w+x1)*4+c]*dx; target[i+c]=a*(1-dy)+b*dy; } }

function channel(v, l, corrected, factor, keep) { return Math.max(0, Math.min(255, Math.round(corrected + (v - l) * factor * keep))); }
function blur(values, w, h, r) {
  const integral = new Float64Array((w + 1) * (h + 1));
  for (let y = 1; y <= h; y++) { let row = 0; for (let x = 1; x <= w; x++) { row += values[(y - 1) * w + x - 1]; integral[y * (w + 1) + x] = integral[(y - 1) * (w + 1) + x] + row; } }
  const out = new Float32Array(values.length);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const t = Math.max(0, y - r), b = Math.min(h - 1, y + r), l = Math.max(0, x - r), q = Math.min(w - 1, x + r); out[y * w + x] = (integral[(b + 1) * (w + 1) + q + 1] - integral[t * (w + 1) + q + 1] - integral[(b + 1) * (w + 1) + l] + integral[t * (w + 1) + l]) / ((q - l + 1) * (b - t + 1)); }
  return out;
}
function sample(values, w, h, x, y) { const x0 = Math.max(0, Math.min(w - 1, Math.floor(x))), y0 = Math.max(0, Math.min(h - 1, Math.floor(y))), x1 = Math.min(w - 1, x0 + 1), y1 = Math.min(h - 1, y0 + 1), dx = x - x0, dy = y - y0; return values[y0 * w + x0] * (1-dx)*(1-dy) + values[y0*w+x1]*dx*(1-dy) + values[y1*w+x0]*(1-dx)*dy + values[y1*w+x1]*dx*dy; }
