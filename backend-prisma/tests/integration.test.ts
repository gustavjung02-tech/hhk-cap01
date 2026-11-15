import {before, beforeEach, after, test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createPublicKey, generateKeyPairSync, randomBytes, sign, verify} from 'node:crypto';
import {Pool} from 'pg';
import {createApp} from '../src/app.js';
import {LicenseService, proofMessage} from '../src/license.js';

const url = process.env.TEST_DATABASE_URL;
if (!url) {
  test('PostgreSQL integration requires TEST_DATABASE_URL', {skip:true}, () => {});
} else {
  const pool = new Pool({connectionString:url, max:6});
  const secret = 'TEST_ONLY_ADMIN_SECRET_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456';
  process.env.ADMIN_API_KEY = secret;
  const pair = generateKeyPairSync('ed25519');
  const service = new LicenseService({pool, adminKey:secret, privateKey:pair.privateKey});
  const app = createApp(service);
  let n = 0;

  const json = async (route:string, body:unknown, admin=false) => {
    const response = await app.request(route, {
      method:'POST',
      headers:{
        'content-type':'application/json',
        ...(admin ? {authorization:'Bearer ' + secret} : {})
      },
      body:JSON.stringify(body)
    });
    return {status:response.status, body:await response.json() as Record<string,any>};
  };
  const campaign = async (maxDevices=1) => {
    const code = 'CAMP_' + ++n;
    const result = await json('/api/v1/admin/campaigns', {
      campaignCode:code, active:true,
      policy:{grades:[1,3], maxDevices, validDays:30}
    }, true);
    assert.equal(result.status,200,JSON.stringify(result.body));
    return code;
  };
  const batch = async (campaignCode:string, quantityPacks=1) => {
    const result = await json('/api/v1/admin/batches', {
      batchCode:'BATCH_' + ++n,campaignCode,quantityPacks
    }, true);
    assert.equal(result.status,200,JSON.stringify(result.body));
    assert.equal(result.body.notebooksPerPack,20);
    assert.equal(result.body.qrTokens.length,quantityPacks);
    return result.body.qrTokens as string[];
  };
  const redeem = (token:string) => json('/api/v1/claims/redeem',{token});
  const device = (licenseKey:string,action:'activate'|'verify'|'transfer',
                  keypair=generateKeyPairSync('ed25519')) => {
    const devicePublicKey = keypair.publicKey.export({type:'spki',format:'der'})
      .subarray(-32).toString('base64url');
    const nonce=randomBytes(18).toString('base64url');
    const signedAt=Date.now();
    const proof=sign(null,Buffer.from(proofMessage(action,licenseKey,devicePublicKey,nonce,signedAt)),
                     keypair.privateKey).toString('base64url');
    return {licenseKey,devicePublicKey,nonce,signedAt,proof};
  };

  before(async () => {
    const sql=readFileSync(new URL('../../db-prisma/migrations/0001_license_only.sql',
                                   import.meta.url),'utf8');
    await pool.query(sql);
  });
  beforeEach(async () => {
    await pool.query('TRUNCATE TABLE license_audit,device_activations,licenses,claim_tokens,reward_campaigns,print_batches RESTART IDENTITY CASCADE');
  });
  after(async () => {await pool.end();});

  test('live PostgreSQL schema and readiness',async () => {
    const response=await app.request('/api/v1/health');
    assert.equal(response.status,200);
    assert.equal((await response.json()).status,'ready');
    const q=await pool.query("SELECT count(*)::int AS n FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('print_batches','reward_campaigns','claim_tokens','licenses','device_activations','license_audit')");
    assert.equal(q.rows[0].n,6);
  });

  test('admin authorization and explicit campaign policy',async () => {
    assert.equal((await json('/api/v1/admin/campaigns',{
      campaignCode:'ABC',active:true,policy:{grades:[1],maxDevices:1,validDays:30}
    })).status,401);
    assert.equal((await json('/api/v1/admin/campaigns',{
      campaignCode:'ABC',active:true,policy:{grades:[],maxDevices:1,validDays:30}
    },true)).body.code,'INVALID_CAMPAIGN');
    const code=await campaign();
    assert.equal((await json('/api/v1/admin/batches',{
      batchCode:'PACK_ONE',campaignCode:code,quantityPacks:2
    },true)).status,200);
    assert.equal((await json('/api/v1/admin/batches',{
      batchCode:'PACK_TWO',campaignCode:code,quantityPacks:101
    },true)).status,400);
  });

  test('same QR concurrently redeems exactly once',async () => {
    const [token]=await batch(await campaign());
    const attempts=await Promise.all([redeem(token),redeem(token)]);
    assert.deepEqual(attempts.map(x=>x.status).sort(),[200,409]);
    assert.deepEqual(attempts.find(x=>x.status===200)!.body.grades,[1,3]);
    assert.equal((await redeem(token)).body.code,'TOKEN_ALREADY_USED');
    const licenses=await pool.query('SELECT count(*)::int AS n FROM licenses');
    assert.equal(licenses.rows[0].n,1);
    const audit=await pool.query("SELECT count(*)::int AS n FROM license_audit WHERE operation='redeem'");
    assert.equal(audit.rows[0].n,1);
  });

  test('valid signed device gets offline lease; concurrency obeys quota',async () => {
    const [token]=await batch(await campaign());
    const licenseKey=(await redeem(token)).body.licenseKey as string;
    const firstPair=generateKeyPairSync('ed25519');
    const result=await json('/api/v1/licenses/activate',device(licenseKey,'activate',firstPair));
    assert.equal(result.status,200,JSON.stringify(result.body));
    assert.deepEqual(result.body.grades,[1,3]);
    const [payload,signature]=(result.body.lease as string).split('.');
    const response=await app.request('/api/v1/public-key');
    const key=(await response.json()).publicKey;
    assert.equal(verify(null,Buffer.from(payload),
      createPublicKey({key:Buffer.from(key,'base64url'),format:'der',type:'spki'}),
      Buffer.from(signature,'base64url')),true);
    assert.equal((JSON.parse(Buffer.from(payload,'base64url').toString())).kind,
      'hhk-offline-license-v1');
    assert.equal((await json('/api/v1/licenses/activate',
      device(licenseKey,'activate',firstPair))).status,200);
    assert.equal((await json('/api/v1/licenses/activate',
      device(licenseKey,'activate'))).body.code,'DEVICE_LIMIT_REACHED');
    assert.equal((await json('/api/v1/licenses/verify',
      device(licenseKey,'verify',firstPair))).status,200);
    const bad=device(licenseKey,'verify',firstPair);
    bad.proof=randomBytes(64).toString('base64url');
    assert.equal((await json('/api/v1/licenses/verify',bad)).status,401);
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM device_activations')).rows[0].n,1);
  });

  test('two different devices racing cannot exceed max_devices',async () => {
    const [token]=await batch(await campaign());
    const key=(await redeem(token)).body.licenseKey as string;
    const attempts=await Promise.all([
      json('/api/v1/licenses/activate',device(key,'activate')),
      json('/api/v1/licenses/activate',device(key,'activate'))
    ]);
    assert.deepEqual(attempts.map(x=>x.status).sort(),[200,409]);
    const count=await pool.query('SELECT count(*)::int AS n FROM device_activations WHERE active=true');
    assert.equal(count.rows[0].n,1);
  });

  test('authorized device transfer and license revocation',async () => {
    const [token]=await batch(await campaign());
    const claim=await redeem(token), key=claim.body.licenseKey as string;
    const oldPair=generateKeyPairSync('ed25519');
    const old=device(key,'activate',oldPair);
    assert.equal((await json('/api/v1/licenses/activate',old)).status,200);
    const newPair=generateKeyPairSync('ed25519');
    const request={...device(key,'transfer',newPair),fromDevicePublicKey:old.devicePublicKey};
    assert.equal((await json('/api/v1/licenses/transfer',request)).status,401);
    assert.equal((await json('/api/v1/licenses/transfer',request,true)).status,200);
    assert.equal((await json('/api/v1/licenses/verify',device(key,'verify',oldPair))).status,403);
    assert.equal((await json('/api/v1/licenses/verify',device(key,'verify',newPair))).status,200);
    const revoke=await json('/api/v1/licenses/revoke',{licenseId:claim.body.licenseId},true);
    assert.equal(revoke.status,200);
    assert.equal((await json('/api/v1/licenses/verify',
      device(key,'verify',newPair))).body.code,'LICENSE_REVOKED');
    assert.equal((await json('/api/v1/licenses/revoke',
      {licenseId:claim.body.licenseId},true)).status,200);
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM device_activations WHERE active=true')).rows[0].n,0);
  });
}
