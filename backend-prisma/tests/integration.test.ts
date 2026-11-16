import {before, beforeEach, after, test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash, createPublicKey, generateKeyPairSync, randomBytes, sign, verify} from 'node:crypto';
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
  const sentMail: Array<{to:string;subject:string;url:string}> = [];
  const app = createApp(service, async (to,subject,actionUrl) => {
    sentMail.push({to,subject,url:actionUrl});
  });
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
    const quotaSql=readFileSync(new URL('../../db-prisma/migrations/0002_device_limit.sql',
                                       import.meta.url),'utf8');
    await pool.query(quotaSql);
    const accountSql = readFileSync(new URL('../../db-prisma/migrations/0003_accounts.sql',
                                          import.meta.url), 'utf8');
    await pool.query(accountSql);
    const securitySql = readFileSync(new URL('../../db-prisma/migrations/0004_account_security.sql',
                                           import.meta.url),'utf8');
    await pool.query(securitySql);
  });
  beforeEach(async () => {
    await pool.query('TRUNCATE TABLE license_audit,device_activations,licenses,claim_tokens,reward_campaigns,print_batches,account_security_audit,account_action_tokens,account_sessions,app_accounts,account_action_throttle RESTART IDENTITY CASCADE');
    sentMail.length = 0;
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

  test('database rejects direct quota bypass and unsafe limit reduction',async () => {
    const [qr]=await batch(await campaign());
    const claim=await redeem(qr);
    const key=claim.body.licenseKey as string;
    assert.equal((await json('/api/v1/licenses/activate',device(key,'activate'))).status,200);
    await assert.rejects(
      pool.query(
        'INSERT INTO device_activations (id,license_id,device_public_key_hash) VALUES (gen_random_uuid(),$1,$2)',
        [claim.body.licenseId,randomBytes(32)]
      ),
      (err:any) => err.code === '23514'
    );
    const active=await pool.query('SELECT count(*)::int AS n FROM device_activations WHERE active=true');
    assert.equal(active.rows[0].n,1);
    const registry=await pool.query("SELECT version FROM hhk_schema_migrations ORDER BY version");
    assert.deepEqual(registry.rows.map(row => row.version),['0001','0002','0003']);
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

  test('real user accounts own the key inventory and QR redemption; keys never appear in list', async () => {
    const email = 'test.user@example.test';
    const password = 'staging_only_secure_passphrase_123';
    const register = await json('/api/v1/accounts/register', {email: ' Test.User@Example.Test ', password});
    assert.equal(register.status, 200, JSON.stringify(register.body));
    assert.equal(register.body.account.email, email);
    assert.equal((await json('/api/v1/accounts/register', {email, password})).body.code,
      'ACCOUNT_EXISTS');
    const denied = await json('/api/v1/account/claims/redeem', {token: 'invalid'});
    assert.equal(denied.status, 401);
    assert.equal((await json('/api/v1/accounts/login', {email, password: 'bad-password'})).status, 401);
    const logged = await json('/api/v1/accounts/login', {email, password});
    assert.equal(logged.status, 200);
    assert.match(logged.body.sessionToken, /^sess_[A-Za-z0-9_-]{43}$/);
    const bearer = logged.body.sessionToken as string;
    const call = async (route: string, payload: unknown) => {
      const response = await app.request(route, {method: 'POST', headers: {
        authorization: 'Bearer ' + bearer, 'content-type': 'application/json'
      }, body: JSON.stringify(payload)});
      return {status: response.status, body: await response.json() as Record<string,any>};
    };
    const get = async (route: string) => {
      const response = await app.request(route, {headers: {authorization: 'Bearer ' + bearer}});
      return {status:response.status, body:await response.json() as Record<string,any>};
    };
    assert.equal((await get('/api/v1/account/me')).body.account.email, email);
    const tokens = await batch(await campaign());
    const claimed = await call('/api/v1/account/claims/redeem', {token: tokens[0]});
    assert.equal(claimed.status, 200, JSON.stringify(claimed.body));
    assert.equal((await call('/api/v1/account/claims/redeem', {token: tokens[0]})).status, 409);
    const inventory = await get('/api/v1/account/keys');
    assert.equal(inventory.status, 200);
    assert.equal(inventory.body.keys.length, 1);
    assert.equal(inventory.body.keys[0].id, claimed.body.licenseId);
    assert.deepEqual(inventory.body.keys[0].grades, [1,3]);
    assert.equal(inventory.body.keys[0].activeDevices, 0);
    assert.equal(JSON.stringify(inventory.body).includes('lic_'), false,
      'Account inventory must never disclose raw license bearer keys');
    // Linking an old unclaimed license is permitted exactly once for its owner.
    const oldToken = (await batch(await campaign()))[0];
    const old = await redeem(oldToken);
    assert.equal(old.status, 200);
    assert.equal((await call('/api/v1/account/keys/link',
      {licenseKey:old.body.licenseKey})).status, 200);
    assert.equal((await call('/api/v1/account/keys/link',
      {licenseKey:old.body.licenseKey})).status, 200);
    assert.equal((await get('/api/v1/account/keys')).body.keys.length, 2);
    await json('/api/v1/accounts/register',
      {email:'another@example.test', password: 'another-secure-passphrase-123'});
    const other = await json('/api/v1/accounts/login',
      {email:'another@example.test', password: 'another-secure-passphrase-123'});
    const otherToken = other.body.sessionToken as string;
    const otherList = await app.request('/api/v1/account/keys',
      {headers:{authorization:'Bearer '+otherToken}});
    assert.deepEqual((await otherList.json()).keys, []);
    const otherLink = await app.request('/api/v1/account/keys/link', {method:'POST',
      headers:{authorization:'Bearer '+otherToken,'content-type':'application/json'},
      body:JSON.stringify({licenseKey:old.body.licenseKey})});
    assert.equal(otherLink.status, 409);
    assert.equal((await otherLink.json()).code, 'KEY_ALREADY_LINKED');
    assert.equal((await call('/api/v1/account/logout', {})).status, 200);
    assert.equal((await get('/api/v1/account/keys')).status, 401);
  });

  test('account input validation, password hashing, login lockout and CORS policy', async () => {
    assert.equal((await json('/api/v1/accounts/register',
      {email:'bad-email',password:'valid-password-1234'})).body.code,'INVALID_EMAIL');
    assert.equal((await json('/api/v1/accounts/register',
      {email:'safe@example.test',password:'short'})).body.code,'WEAK_PASSWORD');
    assert.equal((await json('/api/v1/accounts/register',
      {email:'safe@example.test',password:'valid-password-1234'})).status,200);
    const row = await pool.query('SELECT password_hash,password_salt FROM app_accounts WHERE email=$1',
      ['safe@example.test']);
    assert.equal(row.rows[0].password_hash.length,64);
    assert.equal(row.rows[0].password_salt.length,16);
    for (let i=0;i<5;i++) {
      assert.equal((await json('/api/v1/accounts/login',
        {email:'safe@example.test',password:'incorrect-password'})).status,401);
    }
    assert.equal((await json('/api/v1/accounts/login',
      {email:'safe@example.test',password:'valid-password-1234'})).body.code,'ACCOUNT_LOCKED');
    const untrusted = await app.request('/api/v1/account/keys', {method:'OPTIONS',
      headers:{origin:'https://attacker.example', 'access-control-request-method':'GET'}});
    assert.notEqual(untrusted.headers.get('access-control-allow-origin'),
      'https://attacker.example');
  });


  test('account-owned license activates without raw key and verifies signed offline lease', async () => {
    const pwd = 'secure-account-password-123';
    const email = 'account-device@example.test';
    assert.equal((await json('/api/v1/accounts/register', {email, password:pwd})).status,200);
    const signedIn = await json('/api/v1/accounts/login', {email,password:pwd});
    const token = signedIn.body.sessionToken as string;
    const withAuth = async (route: string, body: unknown, sessionToken = token) => {
      const response = await app.request(route,{method:'POST',
        headers:{'content-type':'application/json',authorization:'Bearer '+sessionToken},
        body: JSON.stringify(body)});
      return {status:response.status, body:await response.json() as Record<string,any>};
    };
    const [qrToken] = await batch(await campaign());
    const redeemed = await withAuth('/api/v1/account/claims/redeem', {token:qrToken});
    assert.equal(redeemed.status,200);
    const licenseId = redeemed.body.licenseId as string;
    const pair = generateKeyPairSync('ed25519');
    const otherPair = generateKeyPairSync('ed25519');
    const proof = (keyPair: typeof pair, action: 'account-activate'|'account-verify') => {
      const devicePublicKey = keyPair.publicKey.export({type:'spki',format:'der'})
        .subarray(-32).toString('base64url');
      const signedAt = Date.now();
      const nonce = randomBytes(18).toString('base64url');
      const proof = sign(null, Buffer.from(proofMessage(
        action, licenseId, devicePublicKey, nonce, signedAt)),keyPair.privateKey).toString('base64url');
      return {licenseId,devicePublicKey,nonce,signedAt,proof};
    };
    const activated = await withAuth('/api/v1/account/keys/activate',
      proof(pair,'account-activate'));
    assert.equal(activated.status,200,JSON.stringify(activated.body));
    const [payload, sig] = (activated.body.lease as string).split('.');
    const publicKey = createPublicKey({key:Buffer.from(service.publicKey(),'base64url'),
      format:'der', type:'spki'});
    assert.equal(verify(null,Buffer.from(payload),publicKey,Buffer.from(sig,'base64url')),true);
    const lease = JSON.parse(Buffer.from(payload,'base64url').toString());
    assert.equal(lease.licenseId,licenseId);
    assert.deepEqual(lease.grades,[1,3]);
    assert.equal((await withAuth('/api/v1/account/keys/verify',
      proof(pair,'account-verify'))).status,200);
    const limit = await withAuth('/api/v1/account/keys/activate',
      proof(otherPair,'account-activate'));
    assert.equal(limit.status,409);
    assert.equal(limit.body.code,'DEVICE_LIMIT_REACHED');
    const forged = proof(pair,'account-activate');
    forged.proof = randomBytes(64).toString('base64url');
    assert.equal((await withAuth('/api/v1/account/keys/activate',forged)).status,401);
    // A different account must not borrow the license ID even with a valid signed device.
    assert.equal((await json('/api/v1/accounts/register',
      {email:'stranger@example.test',password:pwd})).status,200);
    const stranger = await json('/api/v1/accounts/login',
      {email:'stranger@example.test',password:pwd});
    const unauthorized = await withAuth('/api/v1/account/keys/activate',
      proof(otherPair,'account-activate'),stranger.body.sessionToken);
    assert.equal(unauthorized.status,404);
    const revoked = await json('/api/v1/licenses/revoke',{licenseId},true);
    assert.equal(revoked.status,200);
    assert.equal((await withAuth('/api/v1/account/keys/verify',
      proof(pair,'account-verify'))).body.code,'LICENSE_REVOKED');
  });

  test('account session is deliberately persistent until explicit logout', async () => {
    const email='persistent@example.test';
    const password='sufficiently-long-secret-123';
    assert.equal((await json('/api/v1/accounts/register',{email,password})).status,200);
    const logged=await json('/api/v1/accounts/login',{email,password});
    assert.equal(logged.status,200);
    const token=logged.body.sessionToken as string;
    const session=await pool.query(
      'SELECT expires_at,revoked_at FROM account_sessions WHERE token_hash=$1',
      [createHash('sha256').update(token).digest()]);
    assert.equal(session.rows[0].expires_at,null);
    assert.equal(session.rows[0].revoked_at,null);
    const me=await app.request('/api/v1/account/me', {
      headers:{authorization:'Bearer '+token}});
    assert.equal(me.status,200);
    const logout=await app.request('/api/v1/account/logout', {
      method:'POST',headers:{authorization:'Bearer '+token}});
    assert.equal(logout.status,200);
    const after=await app.request('/api/v1/account/me', {
      headers:{authorization:'Bearer '+token}});
    assert.equal(after.status,401);
  });


  test('verified email recovery is one-use and revokes all sessions',async()=>{
    const email='recover@example.test',password='original-recover-pass123';
    assert.equal((await json('/api/v1/accounts/register',{email,password})).status,200);
    const one=await json('/api/v1/accounts/login',{email,password,deviceLabel:'iPhone'});
    const two=await json('/api/v1/accounts/login',{email,password,deviceLabel:'Android'});
    const sessionOne=one.body.sessionToken as string;
    const sessionTwo=two.body.sessionToken as string;
    const call = async (route:string,body:unknown, token=sessionOne) => {
      const r=await app.request(route,{method:'POST',headers:{authorization:'Bearer '+token,
        'content-type':'application/json'},body:JSON.stringify(body)});
      return {status:r.status, body:await r.json() as Record<string,any>};
    };
    const forgotBefore=await json('/api/v1/accounts/password/forgot',{email});
    assert.equal(forgotBefore.status,200);
    assert.equal(sentMail.length,0,'Cannot reset unverified email');
    assert.equal((await json('/api/v1/accounts/email/verification/request',{email})).status,200);
    assert.equal(sentMail.length,1);
    const verification=new URL(sentMail[0].url).searchParams.get('token')!;
    assert.equal((await json('/api/v1/accounts/email/verify',{token:verification})).status,200);
    assert.equal((await json('/api/v1/accounts/email/verify',{token:verification})).body.code,
      'INVALID_ACTION_TOKEN');
    assert.equal((await json('/api/v1/accounts/password/forgot',{email})).status,200);
    assert.equal(sentMail.length,2);
    const resetToken=new URL(sentMail[1].url).searchParams.get('token')!;
    const stored=await pool.query(
      "SELECT token_hash FROM account_action_tokens WHERE kind='reset'");
    assert.notEqual(stored.rows[0].token_hash.toString('hex'),resetToken);
    const reset=await json('/api/v1/accounts/password/reset',
      {token:resetToken,newPassword:'new-reset-password-456'});
    assert.equal(reset.status,200,JSON.stringify(reset.body));
    assert.equal((await json('/api/v1/accounts/password/reset',
      {token:resetToken,newPassword:'repeat-reset-password-456'})).body.code,'INVALID_ACTION_TOKEN');
    for (const t of [sessionOne,sessionTwo]) {
      const old=await app.request('/api/v1/account/me',
        {headers:{authorization:'Bearer '+t}});
      assert.equal(old.status,401);
    }
    assert.equal((await json('/api/v1/accounts/login',{email,password})).status,401);
    assert.equal((await json('/api/v1/accounts/login',
      {email,password:'new-reset-password-456'})).status,200);
    assert.equal((await json('/api/v1/accounts/password/forgot',
      {email:'unknown@example.test'})).status,200);
    await pool.query("UPDATE account_action_tokens SET expires_at=now()-interval '1 second' WHERE kind='reset'");
    // Expired tokens are rejected even if hash is otherwise valid.
    assert.equal((await call('/api/v1/account/password/change',
      {currentPassword:'wrong',newPassword:'other-new-password-789'},sessionTwo)).status,401);
  });

  test('password change rotates only current session; session management is scoped',async()=>{
    const email='change@example.test',password='original-password-123';
    await json('/api/v1/accounts/register',{email,password});
    const first=await json('/api/v1/accounts/login',{email,password,deviceLabel:'Máy chính'});
    const second=await json('/api/v1/accounts/login',{email,password,deviceLabel:'Máy khác'});
    const token=first.body.sessionToken as string, other=second.body.sessionToken as string;
    const call=async (path:string,body:unknown,t=token) => {
      const r=await app.request(path,{method:'POST',
        headers:{authorization:'Bearer '+t,'content-type':'application/json'},
        body:JSON.stringify(body)});
      return {status:r.status,body:await r.json() as Record<string,any>};
    };
    const sessions=await app.request('/api/v1/account/sessions',
      {headers:{authorization:'Bearer '+token}});
    const list=await sessions.json() as any;
    assert.equal(list.sessions.length,2);
    assert.equal(list.sessions.filter((s:any)=>s.current).length,1);
    assert.equal(list.sessions.find((s:any)=>s.current).label,'Máy chính');
    assert.equal((await call('/api/v1/account/password/change',
      {currentPassword:'wrong-password',newPassword:'new-account-password-789'})).status,401);
    assert.equal((await call('/api/v1/account/password/change',
      {currentPassword:password,newPassword:'short'})).body.code,'WEAK_PASSWORD');
    assert.equal((await call('/api/v1/account/password/change',
      {currentPassword:password,newPassword:password})).body.code,'PASSWORD_UNCHANGED');
    const changed=await call('/api/v1/account/password/change',
      {currentPassword:password,newPassword:'new-account-password-789'});
    assert.equal(changed.status,200,JSON.stringify(changed.body));
    const fresh=changed.body.sessionToken as string;
    assert.match(fresh,/^sess_[A-Za-z0-9_-]{43}$/);
    assert.notEqual(fresh,token);
    for(const old of [token,other]){
      const r=await app.request('/api/v1/account/me',{headers:{authorization:'Bearer '+old}});
      assert.equal(r.status,401);
    }
    assert.equal((await app.request('/api/v1/account/me',
      {headers:{authorization:'Bearer '+fresh}})).status,200);
    assert.equal((await json('/api/v1/accounts/login',{email,password})).status,401);
    const next=await json('/api/v1/accounts/login',
      {email,password:'new-account-password-789',deviceLabel:'Thiết bị thứ ba'});
    assert.equal(next.status,200);
    const otherId=(await (await app.request('/api/v1/account/sessions',
      {headers:{authorization:'Bearer '+fresh}})).json() as any).sessions
      .find((s:any)=>!s.current).id;
    assert.equal((await call('/api/v1/account/sessions/revoke',
      {sessionId:otherId},fresh)).status,200);
    assert.equal((await app.request('/api/v1/account/me',
      {headers:{authorization:'Bearer '+next.body.sessionToken}})).status,401);
    assert.equal((await call('/api/v1/account/logout-all',{},fresh)).status,200);
    assert.equal((await app.request('/api/v1/account/me',
      {headers:{authorization:'Bearer '+fresh}})).status,401);
  });

  test('expired reset and wrong-kind tokens fail without password or session changes',async()=>{
    const email='expire@example.test',password='expire-original-pass-123';
    await json('/api/v1/accounts/register',{email,password});
    await json('/api/v1/accounts/email/verification/request',{email});
    const verification=new URL(sentMail[0].url).searchParams.get('token')!;
    await json('/api/v1/accounts/email/verify',{token:verification});
    await json('/api/v1/accounts/password/forgot',{email});
    const expired=new URL(sentMail[1].url).searchParams.get('token')!;
    await pool.query("UPDATE account_action_tokens SET expires_at=now()-interval '1 second' WHERE kind='reset'");
    assert.equal((await json('/api/v1/accounts/password/reset',
      {token:expired,newPassword:'new-expire-password-456'})).body.code,'INVALID_ACTION_TOKEN');
    assert.equal((await json('/api/v1/accounts/password/reset',
      {token:verification,newPassword:'new-expire-password-456'})).body.code,'INVALID_ACTION_TOKEN');
    assert.equal((await json('/api/v1/accounts/login',{email,password})).status,200);
    const unknown=await json('/api/v1/accounts/password/forgot',{email:'nobody@example.test'});
    assert.deepEqual(unknown.body,{ok:true,requested:true});
    assert.deepEqual((await json('/api/v1/accounts/password/forgot',{email})).body,
      {ok:true,requested:true});
  });

}
