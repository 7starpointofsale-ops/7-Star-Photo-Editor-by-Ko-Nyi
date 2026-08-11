import { createServer } from 'node:http';

const upstream = 'https://fileconv.online';
const port = Number(process.env.FILECONV_PROXY_PORT || 8788);
const allowedPaths = new Set([
  '/api/remove-bg/upload',
  '/api/remove-bg/status',
  '/api/remove-bg/download',
]);

function corsFor(request) {
  const origin = request.headers.origin || '';
  const allowedOrigin = /^http:\/\/localhost(?::\d+)?$/.test(origin) ? origin : 'http://localhost:50787';
  return {
  'Access-Control-Allow-Origin': allowedOrigin,
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'content-type',
  'Access-Control-Max-Age': '600',
  };
}

createServer(async (request, response) => {
  const cors = corsFor(request);
  const localUrl = new URL(request.url, `http://${request.headers.host}`);
  // Accept both the documented /fileconv/api/... base and /api/... when a
  // developer supplies the proxy origin without the optional /fileconv suffix.
  // Repeated separators are normalised before the strict allow-list check.
  const path = localUrl.pathname
    .replace(/^\/fileconv(?:\/|$)/, '/')
    .replace(/\/{2,}/g, '/');
  if (request.method === 'OPTIONS') {
    response.writeHead(204, cors).end();
    return;
  }
  if (!allowedPaths.has(path) || !['GET', 'POST'].includes(request.method)) {
    response.writeHead(404, { ...cors, 'Content-Type': 'application/json' });
    response.end(JSON.stringify({ error: 'Unsupported FileConv route', path }));
    return;
  }
  if (Number(request.headers['content-length'] || 0) > 15 * 1024 * 1024) {
    response.writeHead(413, { ...cors, 'Content-Type': 'application/json' });
    response.end(JSON.stringify({ error: 'Image exceeds the 15 MB limit' }));
    return;
  }
  try {
    const target = new URL(`${upstream}${path}`);
    target.search = localUrl.search;
    const headers = {};
    if (request.headers['content-type']) headers['content-type'] = request.headers['content-type'];
    const body = request.method === 'POST'
      ? await new Promise((resolve, reject) => {
          const chunks = [];
          request.on('data', (chunk) => chunks.push(chunk));
          request.on('end', () => resolve(Buffer.concat(chunks)));
          request.on('error', reject);
        })
      : undefined;
    const upstreamResponse = await fetch(target, {
      method: request.method,
      headers,
      body,
    });
    const responseBody = Buffer.from(await upstreamResponse.arrayBuffer());
    response.writeHead(upstreamResponse.status, {
      ...cors,
      'Content-Type': upstreamResponse.headers.get('content-type') || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    response.end(responseBody);
  } catch (_) {
    response.writeHead(502, { ...cors, 'Content-Type': 'application/json' });
    response.end(JSON.stringify({ error: 'Could not reach FileConv' }));
  }
}).listen(port, () => {
  console.log(`FileConv local proxy: http://localhost:${port}/fileconv`);
});
