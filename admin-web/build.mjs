import {mkdir, copyFile, stat} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';

// Only static frontend files enter the public output. Do not publish
// api/, lib/, node_modules/, tests/, environment values or package.json.
const STATIC_FILES=['index.html','styles.css','app.js'];
for (const file of STATIC_FILES) {
  execFileSync(process.execPath,['--check',file],{stdio:'inherit'});
}
await mkdir('public',{recursive:true});
for (const file of STATIC_FILES) {
  await copyFile(file,'public/'+file);
  const info=await stat('public/'+file);
  if (info.size===0) throw new Error('Empty public asset: '+file);
}
console.log('Admin static public/ ready; API code remains server-only.');
