import { readFileSync, existsSync } from 'node:fs';
const dir=process.argv[2] || 'frontend-flutter/build/web';
const get=(p)=>readFileSync(dir+'/'+p,'utf8');
const manifest=JSON.parse(get('manifest.json'));
const config=JSON.parse(get('vercel.json'));
const sw=get('hhk-sw.js');
const html=get('index.html');
const build=JSON.parse(get('hhk-build.json'));
if(manifest.display!=='standalone'||manifest.lang!=='vi'||manifest.start_url!=='/')throw Error('PWA manifest invalid');
if(!html.includes('apple-mobile-web-app-capable')||!html.includes('/hhk-sw.js'))throw Error('iOS PWA not registered');
if(!sw.includes('self.addEventListener(\'fetch\'')||!sw.includes('self.addEventListener(\'install\''))throw Error('Offline service worker missing');
if(!config.rewrites.some(x=>x.destination==='/index.html'))throw Error('SPA fallback missing');
if(config.git?.deploymentEnabled!==false)throw Error('Vercel auto-deploy not disabled');
for(const name of ['main.dart.js','flutter_bootstrap.js','icons/Icon-192.png','icons/Icon-512.png']){
 if(!existsSync(dir+'/'+name))throw Error('Missing Flutter build asset '+name);
}
if(build.offlineAssets < 10)throw Error('Incomplete offline assets list');
console.log('PASS iPhone PWA metadata, offline worker, assets and Vercel rewrites',build);
