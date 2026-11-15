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
const quarantinedCards=read('quarantine/cards.json'),quarantinedQuestions=read('quarantine/questions.json');
if(cards.length+quarantinedCards.length!==manifest.counts.source_cards
 ||questions.length+quarantinedQuestions.length!==manifest.counts.source_questions)throw Error('Source item count loss');
if(quarantinedCards.length!==manifest.counts.quarantined_cards
 ||quarantinedQuestions.length!==manifest.counts.quarantined_questions)throw Error('Quarantine counts mismatch');
const allCardIds=new Set([...cards.map(x=>x.id),...quarantinedCards.map(x=>x.record.id)]);
const allQuestionIds=new Set([...questions.map(x=>x.id),...quarantinedQuestions.map(x=>x.record.id)]);
if(allCardIds.size!==manifest.counts.source_cards||allQuestionIds.size!==manifest.counts.source_questions)throw Error('Dropped or duplicate source ID');
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
console.log('PASS content integrity: '+lessons.length+' lessons; '+questions.length+' usable questions; '+quarantinedQuestions.length+' quarantined questions requiring editorial review');
