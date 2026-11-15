import { readFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';

const dir = process.argv[2] || 'frontend-flutter/build/web';
const get = p => readFileSync(join(dir, p), 'utf8');
const manifest = JSON.parse(get('manifest.json'));
const config = JSON.parse(get('vercel.json'));
const sw = get('hhk-sw.js');
const html = get('index.html');
const build = JSON.parse(get('hhk-build.json'));
if (manifest.display !== 'standalone' || manifest.lang !== 'vi' || manifest.start_url !== '/') {
  throw Error('PWA manifest invalid');
}
if (!html.includes('apple-mobile-web-app-capable') || !html.includes('/hhk-sw.js')) {
  throw Error('iOS PWA not registered');
}
if (!sw.includes("self.addEventListener('fetch'") ||
    !sw.includes("self.addEventListener('install'")) {
  throw Error('Offline service worker missing');
}
if (!config.rewrites.some(x => x.destination === '/index.html')) {
  throw Error('SPA fallback missing');
}
if (config.git?.deploymentEnabled !== false) {
  throw Error('Vercel auto-deploy not disabled');
}
if (!config.headers?.some(item => item.source === '/hhk-sw.js' &&
    item.headers?.some(header => header.key === 'Cache-Control' &&
      header.value === 'no-cache, no-store, must-revalidate'))) {
  throw Error('Missing mandatory service-worker no-cache header');
}
for (const name of ['main.dart.js','flutter_bootstrap.js','icons/Icon-192.png','icons/Icon-512.png']) {
  if (!existsSync(join(dir, name))) throw Error('Missing Flutter build asset ' + name);
}
const match = sw.match(/const URLS = (\[[^\n]*\]);/);
if (!match) throw Error('Offline asset list missing');
const urls = JSON.parse(match[1]);
if (urls.length !== build.offlineAssets || urls.length < 10 ||
    new Set(urls).size !== urls.length) {
  throw Error('Offline cache count or uniqueness mismatch');
}
const root = resolve(dir);
for (const url of urls) {
  if (!url.startsWith('/') || url.startsWith('//') || url.includes('?') ||
      url.includes('#') || url.includes('\\')) {
    throw Error('Unsafe offline cache path: ' + url);
  }
  const relative = url.slice(1);
  const abs = resolve(dir, relative);
  if (!abs.startsWith(root + '/') || !existsSync(abs)) {
    throw Error('Offline asset absent in release package: ' + url);
  }
}
if (urls.includes('/.last_build_id')) {
  throw Error('Volatile Flutter build ID must not be cached or packaged');
}
console.log('PASS complete PWA package:', urls.length, 'offline files; version', build.version);
