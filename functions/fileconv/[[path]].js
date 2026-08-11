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
  // Re-create the multipart request instead of streaming the incoming body.
  // FileConv's multipart parser rejects a chunked stream from the edge, while
  // Workers serializes a FormData body with a valid boundary and file part.
  let body;
  if (context.request.method === 'POST') {
    const incoming = await context.request.formData();
    const file = incoming.get('file');
    if (!(file instanceof File)) {
      return Response.json({ error: 'A multipart file field is required.' }, { status: 400 });
    }
    body = new FormData();
    body.append('file', file, file.name || 'photo.png');
  }
  const response = await fetch(target, {
    method: context.request.method,
    body,
  });
  const outputHeaders = new Headers();
  const outputType = response.headers.get('content-type');
  if (outputType) outputHeaders.set('content-type', outputType);
  outputHeaders.set('Cache-Control', 'no-store');
  return new Response(response.body, { status: response.status, headers: outputHeaders });
}
