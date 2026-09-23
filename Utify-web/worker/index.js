/**
 * Utify YouTube Proxy Worker
 *
 * Proxies requests to YouTube's InnerTube API to avoid CORS restrictions
 * in production. Deployed on Cloudflare Workers (free tier).
 *
 * Routes:
 *   POST /youtubei/v1/*  → https://www.youtube.com/youtubei/v1/*
 *   GET  /youtubei/*     → https://www.youtube.com/youtubei/*  (captions, etc.)
 *
 * Deploy:
 *   npm install -g wrangler
 *   wrangler login
 *   wrangler deploy
 */

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url)

    // Only proxy /youtubei/* and /api/* paths
    if (!url.pathname.startsWith('/youtubei') && !url.pathname.startsWith('/api')) {
      return new Response('Not found', { status: 404 })
    }

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin':  '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, X-YouTube-Client-Name, X-YouTube-Client-Version',
          'Access-Control-Max-Age':       '86400',
        },
      })
    }

    // Build the target YouTube URL
    const targetUrl = 'https://www.youtube.com' + url.pathname + url.search

    // Forward the request with YouTube-compatible headers
    const headers = new Headers({
      'Content-Type':             request.headers.get('Content-Type') || 'application/json',
      'User-Agent':               'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
      'Origin':                   'https://www.youtube.com',
      'Referer':                  'https://www.youtube.com/',
      'X-YouTube-Client-Name':    request.headers.get('X-YouTube-Client-Name')    || '1',
      'X-YouTube-Client-Version': request.headers.get('X-YouTube-Client-Version') || '2.20240101.00.00',
    })

    const upstream = await fetch(targetUrl, {
      method:  request.method,
      headers,
      body:    request.method !== 'GET' && request.method !== 'HEAD'
               ? request.body
               : undefined,
    })

    // Return with CORS headers so the browser allows it
    const response = new Response(upstream.body, {
      status:  upstream.status,
      headers: {
        'Content-Type':                upstream.headers.get('Content-Type') || 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods':'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers':'Content-Type, X-YouTube-Client-Name, X-YouTube-Client-Version',
      },
    })

    return response
  },
}
