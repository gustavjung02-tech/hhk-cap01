import {readFileSync, writeFileSync} from 'node:fs';

const base = 'content/seed/v1/';
const read = (name) => JSON.parse(readFileSync(base + name, 'utf8'));
const manifest = read('manifest.json');
const linked = read('questions.json');
const quarantined = read('quarantine/questions.json');
const all = [
  ...linked.map((record) => ({record, quarantine: null})),
  ...quarantined.map((entry) => ({
    record: entry.record,
    quarantine: entry.reason ?? entry.reasonCode ?? 'editorial_review_required',
  })),
];
if (all.length !== manifest.counts.source_questions) {
  throw new Error('Question source count mismatch');
}

const normalize = (value) => String(value ?? '').trim().toLowerCase();
const validAnswer = (q) => {
  const expected = normalize(q.correctAnswer);
  if (q.questionType === 'true_false') {
    return ['đúng', 'sai', 'true', 'false'].includes(expected);
  }
  if (q.questionType === 'fill_number') {
    return expected !== '' && Number.isFinite(Number(expected.replace(',', '.')));
  }
  if (q.questionType === 'single_choice') {
    try {
      const options = JSON.parse(q.optionsJson ?? '');
      return Array.isArray(options) &&
        options.length >= 2 &&
        options.every((x) => typeof x === 'string' && normalize(x).length > 0) &&
        new Set(options.map(normalize)).size === options.length &&
        options.some((x) => normalize(x) === expected);
    } catch {
      return false;
    }
  }
  return false;
};

const seen = new Set();
const byType = {};
const byGrade = {};
const records = [];
for (const {record: q, quarantine} of all) {
  if (!q || !Number.isInteger(q.id) || seen.has(q.id)) {
    throw new Error('Invalid or duplicated source question ID: ' + q?.id);
  }
  seen.add(q.id);
  const type = q.questionType || '(missing)';
  const supported = validAnswer(q) && quarantine === null;
  byType[type] ??= {total: 0, usable: 0, quarantined: 0, safeToGrade: 0, needsReview: 0};
  byType[type].total++;
  byType[type][quarantine === null ? 'usable' : 'quarantined']++;
  byType[type][supported ? 'safeToGrade' : 'needsReview']++;
  const grade = String(q.grade ?? 'unknown');
  byGrade[grade] ??= 0;
  byGrade[grade]++;
  let optionShape = 'none';
  if (q.optionsJson != null) {
    try {
      const parsed = JSON.parse(q.optionsJson);
      optionShape = Array.isArray(parsed)
        ? 'array:' + (parsed.every((v) => typeof v === 'string') ? 'strings' : 'mixed')
        : typeof parsed;
    } catch {
      optionShape = 'malformed-json';
    }
  }
  records.push({
    id: q.id,
    type,
    grade: q.grade ?? null,
    lessonId: q.lessonId ?? null,
    subjectCode: q.subjectCode ?? null,
    answerShape: q.correctAnswer == null ? 'null' : typeof q.correctAnswer,
    optionShape,
    quarantine,
    safeToGrade: supported,
    editorialDecision: 'PENDING',
  });
}
if (seen.size !== manifest.counts.source_questions) {
  throw new Error('Source question IDs not preserved');
}
const report = {
  sourceCommit: manifest.source_commit,
  sourceQuestions: all.length,
  linkedQuestions: linked.length,
  quarantinedQuestions: quarantined.length,
  byType,
  byGrade,
  records,
  disclaimer: 'Machine classification only; every editorialDecision is PENDING. Quarantine IDs are never auto-remapped or deleted.',
};
writeFileSync('question-audit.json', JSON.stringify(report, null, 2) + '\n');
console.log('Question audit classified ' + all.length + ' IDs. Output: question-audit.json');
console.log(JSON.stringify({byType, byGrade}, null, 2));
