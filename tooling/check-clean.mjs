import {readdirSync,statSync,readFileSync} from 'node:fs';import {join} from 'node:path';
const forbidden=['src/','electron/','backend/','public/sw.js','vite.config.ts','package-lock.json','node_modules/','dist/','build/','db-neon/','license-api/'];
const bad=[];
for(const path of forbidden){try{statSync(path);bad.push(path)}catch{}}
function scan(dir){
 for(const file of readdirSync(dir,{withFileTypes:true})){
  const p=join(dir,file.name);
  if(file.isDirectory()){if(!['.git','.dart_tool','node_modules','build'].includes(file.name))scan(p)}
  else if(/\.(jsx|tsx)$/.test(file.name))bad.push(p);
 }
}
scan('.');
if(bad.length)throw Error('Legacy runtime files forbidden: '+bad.join(', '));
console.log('PASS clean Flutter-first repo; no React/Electron/Express runtime');

// Release safety: GitHub Actions may build static PWA artifacts, but must never
// automatically deploy to Vercel. Deployment is a deliberate plugin action.
for (const file of readdirSync('.github/workflows').filter(name => /\.ya?ml$/.test(name))) {
  const yaml = readFileSync(join('.github/workflows',file),'utf8');
  if (/VERCEL_TOKEN|\bvercel\s+(?:deploy\b|--prod\b|promote\b)|vercel-action|create_deployment/i.test(yaml)) {
    throw Error('Automatic Vercel deployment is forbidden: ' + file);
  }
}
console.log('PASS Vercel deployment disabled in all GitHub workflows');
