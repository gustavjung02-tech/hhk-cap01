import {readdirSync,statSync} from 'node:fs';import {join} from 'node:path';
const forbidden=['src/','electron/','backend/','public/sw.js','vite.config.ts','package-lock.json','node_modules/','dist/','build/'];
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
