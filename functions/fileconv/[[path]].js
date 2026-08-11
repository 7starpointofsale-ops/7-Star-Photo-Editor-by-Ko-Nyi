const upstream = 'https://fileconv.online';
const allowedPaths = new Set([
  '/api/remove-bg/upload',
  '/api/remove-bg/status',
  '/api/remove-bg/download',
]);

/**
 * Cloudflare Pages Function used only because FileConv's API does not expose
 * browser CORS headers. It stores nothing and cannot proxy arbitrary URLs.
 */
export async function onRequest(context) {
  const requestUrl = new URL(context.request.url);
  const segments = Array.isArray(context.params.path)
    ? context.params.path
    : String(context.params.path || '').split('/');
  const suffix = `/${segments.join('/')}`.replace(/\/{2,}/g, '/');
  if (!allowedPaths.has(suffix)) {
    return new Response('Not found', { status: 404 });
  }
  if (!['GET', 'POST'].includes(context.request.method)) {
    return new Response('Method not allowed', { status: 405, headers: { Allow: 'GET, POST' } });
  }

  const target = new URL(`${upstream}${suffix}`);
  target.search = requestUrl.search;
  const headers = new Headers();
  const contentType = context.request.headers.get('content-type');
  if (contentType) headers.set('content-type', contentType);
  const response = await fetch(target, {
    method: context.request.method,
    headers,
    body: context.request.method === 'POST' ? context.request.body : undefined,
  });
  const outputHeaders = new Headers();
  const outputType = response.headers.get('content-type');
  if (outputType) outputHeaders.set('content-type', outputType);
  outputHeaders.set('Cache-Control', 'no-store');
  return new Response(response.body, { status: response.status, headers: outputHeaders });
}
