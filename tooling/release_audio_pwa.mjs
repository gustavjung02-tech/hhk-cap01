// Repeatable manual release: CI-green Flutter Web artifact + original, verified
// ZIPs copied from authorized Drive to immutable same-origin MP3 resources.
// No account secrets or signed Drive links appear in dist/.
import { createHash } from 'node:crypto';
import { existsSync, mkdtempSync, mkdirSync, readFileSync,
  rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const buildSha = process.env.HHK_PWA_SHA256;
const buildUrl = process.env.HHK_PWA_ARTIFACT_URL;
const audioUrls = JSON.parse(process.env.HHK_AUDIO_URLS_JSON || '[]');
const catalog = JSON.parse(readFileSync(
  'frontend-flutter/assets/content/audio/catalog.json', 'utf8'));
if (catalog.schema !== 'hhk-audio-v1' ||
    catalog.contentVersion !== '2026-04-27-v1' ||
    !/^[0-9a-f]{64}$/.test(buildSha || '') ||
    !buildUrl?.startsWith('https://') ||
    !Array.isArray(audioUrls) || audioUrls.length !== 5) {
  throw new Error('Missing audited PWA/audio release inputs');
}
const sources = new Map(audioUrls.map(({grade, fileName, downloadUrl}) =>
  [grade, {fileName, downloadUrl}]));
if (sources.size !== 5) throw new Error('Duplicate audio grades in release');

const temp = mkdtempSync(path.join(os.tmpdir(), 'hhk-source-audio-'));
async function downloadVerified(url, expected, filePath, sizeBounds) {
  if (typeof url !== 'string' || !url.startsWith('https://') ||
      !/^[0-9a-f]{64}$/.test(expected)) {
    throw new Error('Invalid source URI or SHA256');
  }
  const response = await fetch(url, {
    redirect: 'follow', signal: AbortSignal.timeout(180000),
  });
  if (!response.ok) throw new Error('Source fetch failed HTTP '+response.status);
  const bytes = Buffer.from(await response.arrayBuffer());
  if (bytes.length < sizeBounds[0] || bytes.length > sizeBounds[1]) {
    throw new Error('Downloaded source size mismatch');
  }
  const digest = createHash('sha256').update(bytes).digest('hex');
  if (digest !== expected) throw new Error('Downloaded source SHA256 mismatch');
  writeFileSync(filePath, bytes);
  return bytes.length;
}

try {
  await downloadVerified(buildUrl, buildSha, path.join(temp, 'pwa.zip'),
    [10000000, 30000000]);
  mkdirSync('dist', {recursive:true});
  execFileSync('unzip', ['-q', path.join(temp, 'pwa.zip'), '-d', 'dist'],
    {stdio:'inherit'});
  for (const asset of ['index.html','main.dart.js','manifest.json',
    'hhk-sw.js','hhk-build.json']) {
    if (!existsSync('dist/'+asset)) throw new Error('PWA artifact missing '+asset);
  }
  console.log('CI Flutter artifact SHA256 verified: '+buildSha);
  for (const row of catalog.grades) {
    const origin = sources.get(row.grade);
    if (!origin || origin.fileName !== row.fileName) {
      throw new Error('Missing original Drive ZIP grade '+row.grade);
    }
    await downloadVerified(origin.downloadUrl, row.sha256,
      path.join(temp, row.fileName), [row.sizeBytes, row.sizeBytes]);
    console.log('Original Drive audio ZIP verified: grade '+row.grade+
      ' '+row.assetCount+' cards');
  }
  execFileSync('python3', [
    'tooling/publish_verified_tts.py',
    '--catalog', 'frontend-flutter/assets/content/audio/catalog.json',
    '--source-dir', temp,
    '--output-dir', 'dist'
  ], {stdio:'inherit'});
  console.log('HHK offline audio prepared: 5 verified grade ZIPs + 4200 MP3 files.');
} finally {
  rmSync(temp, {recursive:true, force:true});
}
