// OCR executes in this browser worker. No image data is posted to the app
// backend or a third-party OCR API.
importScripts('https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js');

self.onmessage = async (event) => {
  const { bytes, languages } = event.data;
  let worker;
  try {
    worker = await Tesseract.createWorker(languages || 'mya+eng', 1, {
      logger: (entry) => self.postMessage({
        type: 'progress',
        status: entry.status || 'Processing',
        progress: Number(entry.progress || 0),
      }),
    });
    await worker.setParameters({ preserve_interword_spaces: '1' });
    const result = await worker.recognize(new Blob([bytes]));
    self.postMessage({
      type: 'result',
      text: result.data.text || '',
      confidence: Number(result.data.confidence || 0),
    });
  } catch (error) {
    self.postMessage({ type: 'error', message: error?.message || String(error) });
  } finally {
    if (worker) await worker.terminate();
  }
};
