// Assemble a versioned offline-first Flutter Web PWA release for static hosting.
// Run *after* flutter build web --release --pwa-strategy=none.
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { createHash } from 'node:crypto';

const dir = process.argv[2] || 'frontend-flutter/build/web';
if (!existsSync(join(dir, 'index.html')) || !existsSync(join(dir,'main.dart.js'))) {
  throw new Error('Flutter build/web not ready. Build Flutter first.');
}
const exclude = new Set(['hhk-sw.js', 'vercel.json', 'flutter_service_worker.js', '.DS_Store', '.last_build_id']);
const files = [];
function walk(directory) {
  for (const item of readdirSync(directory, { withFileTypes: true })) {
    const p = join(directory, item.name);
    if (item.isDirectory()) walk(p);
    else if (item.isFile()) {
      const name = relative(dir,p).split(sep).join('/');
      if (!exclude.has(item.name) && !name.endsWith('.map')) files.push(name);
    }
  }
}
walk(dir);
files.sort();
const paths = files.map(file=>'/'+file);
const digest = createHash('sha256');
for (const file of files) {
  digest.update(file);
  digest.update(createHash('sha256').update(readFileSync(join(dir,file))).digest());
}
const version = digest.digest('hex').slice(0,20);
const sw = `
'use strict';
const VERSION = ${JSON.stringify(version)};
const CACHE = 'hhk-pwa-' + VERSION;
const URLS = ${JSON.stringify(paths)};
const ALLOWED = new Set(URLS);
const APP_SHELL = '/index.html';
self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    // Fail installation if a packaged asset is unavailable: keep the prior
    // working service worker rather than silently publishing an incomplete app.
    for (const path of URLS) {
      await cache.add(new Request(path, { cache: 'reload' }));
    }
    await self.skipWaiting();
  })());
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(k => k.startsWith('hhk-pwa-') && k !== CACHE)
      .map(k => caches.delete(k)));
    await self.clients.claim();
  })());
});
self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (url.pathname === '/hhk-sw.js') return;
  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      try { return await fetch(request); }
      catch (_) {
        const cache = await caches.open(CACHE);
        return (await cache.match(APP_SHELL)) || Response.error();
      }
    })());
    return;
  }
  if (!ALLOWED.has(url.pathname)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const item = await cache.match(url.pathname);
    if (item) return item;
    return fetch(request);
  })());
});
`;
writeFileSync(join(dir,'hhk-sw.js'), sw.trimStart());
// Read the canonical Vercel config from the Flutter source root.
// A file placed only in build/web is ignored by GitSource Vercel deployments.
const vercelConfig = JSON.parse(readFileSync(join(dir,'..','..','vercel.json'),'utf8'));
if (vercelConfig.git?.deploymentEnabled !== false ||
    !vercelConfig.rewrites?.some(rule => rule.destination === '/index.html')) {
  throw new Error('Canonical Vercel config must disable auto deploy and include SPA fallback');
}
writeFileSync(join(dir,'vercel.json'),JSON.stringify(vercelConfig,null,2)+'\n');
writeFileSync(join(dir,'hhk-build.json'),JSON.stringify({version,kind:'flutter-web-pwa',offlineAssets:paths.length},null,2)+'\n');
console.log('HHK PWA ready', {version,precacheAssets:paths.length});
