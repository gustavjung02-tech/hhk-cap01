import {test} from 'node:test';
import assert from 'node:assert/strict';
import JSZip from 'jszip';
import {TOKEN_RE, CODE_RE,checkedTokens,checkedBatchCode,csvForBatch,allowedOrigin} from '../lib/shared.js';
import issue from '../api/issue.js';
import qr from '../api/qr.js';
import exporter from '../api/export.js';

const t1='qr_'+ 'A'.repeat(32);
const t2='qr_'+ 'B'.repeat(32);
function response() {
  return {
    headers:{}, statusCode:200,body:null,
    setHeader(k,v){this.headers[k.toLowerCase()]=v;return this;},
    status(v){this.statusCode=v;return this;},
    json(v){this.body=v;return this;},
    send(v){this.body=v;return this;}
  };
}
const request=(method,body,url='/api/issue?action=batch',auth='Bearer '+'k'.repeat(32))=>({
  url,method,body,headers:{host:'hhk-cap01-admin.vercel.app',
    origin:'https://hhk-cap01-admin.vercel.app',authorization:auth}
});

test('claim QR validation never permits URL/HTML/duplicate tokens',()=>{
  assert.ok(TOKEN_RE.test(t1));
  assert.ok(CODE_RE.test('BATCH_TEST_01'));
  assert.deepEqual(checkedTokens([t1,t2]),[t1,t2]);
  assert.throws(()=>checkedTokens([t1,t1]));
  assert.throws(()=>checkedTokens(['https://fake.example/?token='+t1]));
  assert.throws(()=>checkedTokens([t1,'<script>']));
  assert.throws(()=>checkedTokens(Array(101).fill(t1)));
  assert.throws(()=>checkedBatchCode('test/evil'));
  assert.ok(csvForBatch('BATCH_01',[t1]).startsWith('\uFEFFindex,batch_code,qr_token'));
});
test('origin protection rejects cross-site issuer requests',()=>{
  assert.equal(allowedOrigin(request('POST',{})),true);
  const forged=request('POST',{});
  forged.headers.origin='https://evil.example';
  assert.equal(allowedOrigin(forged),false);
});
test('issuer forwards only allowlisted backend calls and refuses absent key',async()=>{
  delete process.env.HHK_ADMIN_PANEL_KEY;
  const notConfigured=response();
  await issue(request('POST',{},'/api/issue?action=campaign'),notConfigured);
  assert.equal(notConfigured.statusCode,503);
  process.env.HHK_ADMIN_PANEL_KEY='TEST_PANEL_CREDENTIAL_ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const unknown=response();
  await issue(request('POST',{},'/api/issue?action=delete'),unknown);
  assert.equal(unknown.statusCode,404);
  const original=globalThis.fetch;
  const calls=[];
  globalThis.fetch=async(url,options)=>{
    calls.push({url,options});
    return {status:200,json:async()=>({ok:true,qrTokens:[t1]})};
  };
  try {
    const res=response();
    await issue(request('POST',{batchCode:'BATCH_01',
      campaignCode:'CAMP_01',quantityTokens:1}),res);
    assert.equal(res.statusCode,200);
    assert.equal(res.body.qrTokens[0],t1);
    assert.equal(res.headers['cache-control'].includes('no-store'),true);
    assert.equal(calls[0].url,
      'https://hhk-cap01-license-staging-gustavjung02-techs-projects.vercel.app/api/v1/admin/batches');
    assert.equal(calls[0].options.headers.authorization,
      'Bearer TEST_PANEL_CREDENTIAL_ABCDEFGHIJKLMNOPQRSTUVWXYZ');
    const list=response();
    await issue(request('GET',null,'/api/issue?action=list'),list);
    assert.equal(calls[1].options.method,'GET');
  } finally {
    globalThis.fetch=original;
  }
});
test('rendered SVG is valid local QR artwork',async()=>{
  const res=response();
  await qr(request('POST',{tokens:[t1,t2]}),res);
  assert.equal(res.statusCode,200);
  assert.equal(res.body.svgs.length,2);
  assert.match(res.body.svgs[0],/<svg/);
  assert.match(res.body.svgs[0],/<path/);
  const invalid=response();
  await qr(request('POST',{tokens:['HELLO']}),invalid);
  assert.equal(invalid.statusCode,400);
});
test('ZIP contains each QR SVG plus CSV without upstream network',async()=>{
  const res=response();
  await exporter(request('POST',{tokens:[t1,t2],batchCode:'BATCH_01'}),res);
  assert.equal(res.statusCode,200);
  assert.equal(res.headers['content-type'],'application/zip');
  const zip=await JSZip.loadAsync(res.body);
  const csv=await zip.file('QR_CLAIM_TOKENS.csv').async('string');
  assert.ok(csv.includes(t1)&&csv.includes(t2));
  assert.match(await zip.file('qr/001.svg').async('string'),/<svg/);
  assert.match(await zip.file('qr/002.svg').async('string'),/<svg/);
});
