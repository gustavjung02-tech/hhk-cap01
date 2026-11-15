// Executed inside pinned legacy checkout; output JSON only, NEVER source React/Electron.
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { seedLessons, seedLessonCards, seedQuestions } from './src/data/seedData.ts';
import { allSubjects } from './src/data/subjects.ts';

const EXPECTED = '7ab83326db4ab3141e2d42aeefe2ea182f13452b';
const rev = execFileSync('git', ['rev-parse', 'HEAD'], {encoding:'utf8'}).trim();
if (rev !== EXPECTED) throw Error('Unexpected source revision: ' + rev);
const out = process.argv[2];
if (!out) throw Error('Usage: tsx export-legacy-content.mts DESTINATION');
const destination = resolve(out);
const labels = {source_repo:'gustavjung01/cap-01',source_commit:rev,schema:'hhk-content-v1'};

function assertUnique(label: string, items: Array<{id: number}>) {
 const ids = new Set();
 for (const item of items) {
   if (!Number.isSafeInteger(item.id) || ids.has(item.id)) throw Error(label + ': invalid or duplicate ID ' + item.id);
   ids.add(item.id);
 }
}
assertUnique('lessons',seedLessons);
assertUnique('lesson_cards',seedLessonCards);
assertUnique('questions',seedQuestions);
const lessonIds = new Set(seedLessons.map(x => x.id));
for (const row of seedLessonCards) if (!lessonIds.has(row.lessonId)) throw Error('Orphan lesson card: ' + row.id);
for (const row of seedQuestions) if (!lessonIds.has(row.lessonId)) throw Error('Orphan question: ' + row.id);
const subjectCodes = new Set(allSubjects.map(s => s.code));
for (const row of seedLessons) if (!subjectCodes.has(row.subjectCode)) throw Error('Unknown lesson subject ' + row.subjectCode);
for (const row of seedQuestions) if (!subjectCodes.has(row.subjectCode)) throw Error('Unknown question subject ' + row.subjectCode);

const lessons = seedLessons.map(row => ({...row,textbook:null})); // legacy round-robin is not verified
const subjects = allSubjects;
const cards = seedLessonCards;
const questions = seedQuestions;
const files: Record<string, unknown> = {
 'subjects.json':subjects,
 'lessons.json':lessons,
 'lesson_cards.json':cards,
 'questions.json':questions,
};
mkdirSync(destination,{recursive:true});
mkdirSync(resolve(destination,'grades'),{recursive:true});
const hashes: Record<string,{sha256:string,bytes:number}> = {};
function store(filename:string,value:unknown) {
 const json = JSON.stringify(value) + '\n';
 const file = resolve(destination,filename);
 writeFileSync(file,json,'utf8');
 const hash = createHash('sha256').update(json).digest('hex');
 hashes[filename] = {sha256:hash,bytes:Buffer.byteLength(json)};
}
for (const [p,data] of Object.entries(files)) store(p,data);
const countsByGrade: Record<string,{lessons:number,cards:number,questions:number}> = {};
for (let g=0;g<=5;g++) {
 const ll = lessons.filter(x=>x.grade===g);
 const lids = new Set(ll.map(x=>x.id));
 const cc = cards.filter(x=>lids.has(x.lessonId));
 const qq = questions.filter(x=>x.grade===g);
 for(const q of qq) if (!lids.has(q.lessonId)) throw Error('Grade mismatch for question ' + q.id);
 store('grades/grade-'+g+'.json',{schema:'hhk-grade-v1',grade:g,subjects:subjects.filter(s=>s.grades.includes(g)),lessons:ll,cards:cc,questions:qq});
 countsByGrade[String(g)]={lessons:ll.length,cards:cc.length,questions:qq.length};
}
store('manifest.json',{
 ...labels,
 counts:{subjects:subjects.length,lessons:lessons.length,cards:cards.length,questions:questions.length,grades:countsByGrade},
 editorial:{textbookVerified:false,answersReviewed:false,audioObjectsVerified:false},
 contentFiles:hashes,
});
console.log(JSON.stringify({counts:{subjects:subjects.length,lessons:lessons.length,cards:cards.length,questions:questions.length},grades:countsByGrade}));
