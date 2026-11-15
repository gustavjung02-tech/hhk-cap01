import {readFileSync,existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
const base='content/seed/v1/';
if(!existsSync(base+'manifest.json')) {
 console.log('CONTENT PENDING: import workflow has not finished');
 process.exit(0);
}
const read=p=>JSON.parse(readFileSync(base+p,'utf8'));
const manifest=read('manifest.json');
const lock=JSON.parse(readFileSync('content/source-lock.json','utf8'));
if(manifest.source_commit!==lock.commit) throw Error('Source SHA mismatch');
for(const [path,v] of Object.entries(manifest.contentFiles)) {
 const b=readFileSync(base+path);
 const hash=createHash('sha256').update(b).digest('hex');
 if(hash!==v.sha256 || b.byteLength!==v.bytes) throw Error('Checksum mismatch: '+path);
}
const lessons=read('lessons.json'),cards=read('lesson_cards.json'),questions=read('questions.json');
const lids=new Set(lessons.map(x=>x.id));
for(const [name,a] of [['lessons',lessons],['cards',cards],['questions',questions]]) {
 if(new Set(a.map(x=>x.id)).size!==a.length) throw Error('Duplicate '+name);
}
for(const c of cards)if(!lids.has(c.lessonId))throw Error('Orphan card: '+c.id);
for(const q of questions)if(!lids.has(q.lessonId))throw Error('Orphan question: '+q.id);
for(let g=0;g<=5;g++){
 const p=read('grades/grade-'+g+'.json');
 if(p.lessons.length!==manifest.counts.grades[g].lessons)throw Error('Grade pack mismatch '+g);
}
if(questions.length===0 || lessons.length===0) throw Error('Empty curriculum');
console.log('PASS content: '+lessons.length+' lessons; '+questions.length+' questions');
