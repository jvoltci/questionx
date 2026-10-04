/**
 * Cloudflare Worker for padhai.altrusian.com
 * Handles:
 * 1. Serving /.well-known/assetlinks.json directly (since CF asset uploader skips dotfolders)
 * 2. Caching headers for encrypted chunks (/data/*.bin.enc), diagrams, and hashed assets
 * 3. Security and SPA fallback routing via env.ASSETS
 */

interface Env {
  ASSETS: {
    fetch: (request: Request) => Promise<Response>;
  };
}

const ASSET_LINKS = [
  {
    relation: ['delegate_permission/common.handle_all_urls'],
    target: {
      namespace: 'android_app',
      package_name: 'com.northmountain.questionx',
      sha256_cert_fingerprints: [
        '5A:36:9F:46:C1:0B:77:DA:53:9C:98:15:29:2B:4E:93:5C:65:D1:27:0A:E2:E6:E8:C1:3E:08:8A:C1:AB:CF:AF',
      ],
    },
  },
];

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // TWA Digital Asset Links verification
    if (url.pathname === '/.well-known/assetlinks.json') {
      return new Response(JSON.stringify(ASSET_LINKS, null, 2), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Cache-Control': 'public, max-age=86400',
        },
      });
    }

    // Health check endpoint
    if (url.pathname === '/healthz') {
      return new Response('OK', { status: 200 });
    }

    const response = await env.ASSETS.fetch(request);

    // Immutable caching for content-addressed datasets and diagrams
    if (
      url.pathname.startsWith('/data/') ||
      url.pathname.startsWith('/diagrams/') ||
      url.pathname.startsWith('/assets/')
    ) {
      const headers = new Headers(response.headers);
      headers.set('Cache-Control', 'public, max-age=31536000, immutable');
      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers,
      });
    }

    return response;
  },
};
