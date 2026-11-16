import {createHash, randomBytes, randomUUID, scrypt, timingSafeEqual} from 'node:crypto';
import {promisify} from 'node:util';
import type {Pool, PoolClient} from 'pg';
import {ApiFault} from './license.js';
import {normalizeEmail} from './account.js';

const derive = promisify(scrypt);
const hash = (s: string) => createHash('sha256').update(s).digest();
const tokenPattern = /^act_[A-Za-z0-9_-]{43}$/;
const sessionPattern = /^sess_[A-Za-z0-9_-]{43}$/;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
type Action = 'verify' | 'reset' | 'email_change';
type ActionRow = {
  id: string; account_id: string; kind: Action;
  target_email: string | null; expires_at: Date;
  used_at: Date | null; email_verified_at: Date | null;
};

export type AccountMailer = (to: string, subject: string, actionUrl: string) => Promise<void>;

export async function sendAccountEmail(to: string, subject: string, actionUrl: string) {
  const apiKey = process.env.RESEND_API_KEY;
  const from = process.env.HHK_MAIL_FROM;
  if (!apiKey || !from) throw new ApiFault(503, 'EMAIL_NOT_CONFIGURED');
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {'Authorization': 'Bearer ' + apiKey, 'Content-Type': 'application/json'},
    body: JSON.stringify({
      from, to: [to], subject,
      text: subject + '\n\nMở liên kết bảo mật sau (chỉ sử dụng một lần):\n' +
        actionUrl + '\n\nNếu không yêu cầu, bạn có thể bỏ qua email này.'
    }),
    signal: AbortSignal.timeout(10000)
  });
  if (!response.ok) throw new ApiFault(503, 'EMAIL_DELIVERY_FAILED');
}

function validPassword(value: unknown): value is string {
  return typeof value === 'string' && value.length >= 12 &&
    Buffer.byteLength(value, 'utf8') <= 256;
}
function bearer(header: string | undefined) {
  const token = header?.startsWith('Bearer ') ? header.slice(7) : '';
  if (!sessionPattern.test(token)) throw new ApiFault(401, 'UNAUTHORIZED');
  return token;
}
async function txn<T>(pool: Pool, work: (c: PoolClient) => Promise<T>): Promise<T> {
  const c = await pool.connect();
  try {
    await c.query('BEGIN');
    const result = await work(c);
    await c.query('COMMIT');
    return result;
  } catch (e) {
    await c.query('ROLLBACK');
    throw e;
  } finally { c.release(); }
}
function actionUrl(kind: Action, token: string) {
  const origin = process.env.HHK_PUBLIC_APP_URL ?? 'https://hhk-cap01-pwa.vercel.app';
  const url = new URL(origin);
  if (url.protocol !== 'https:' || url.username || url.password ||
      url.search || url.hash) throw new ApiFault(503, 'EMAIL_NOT_CONFIGURED');
  url.searchParams.set('accountAction', kind);
  url.searchParams.set('token', token);
  return url.toString();
}

export class AccountSecurityService {
  constructor(private readonly pool: Pool, private readonly mailer: AccountMailer = sendAccountEmail) {}

  private async throttle(kind: string, identifier: string, max: number): Promise<boolean> {
    // Anonymous unknown addresses consume the same quota as registered ones.
    const key = hash(kind + ':' + identifier).toString('hex');
    const result = await this.pool.query<{hits:number}>(
      `INSERT INTO account_action_throttle(key,hits,window_started)
       VALUES($1,1,now())
       ON CONFLICT(key) DO UPDATE SET
         hits=CASE WHEN account_action_throttle.window_started < now() - interval '15 minutes'
           THEN 1 ELSE account_action_throttle.hits+1 END,
         window_started=CASE WHEN account_action_throttle.window_started < now() - interval '15 minutes'
           THEN now() ELSE account_action_throttle.window_started END
       RETURNING hits`, [key]);
    return result.rows[0].hits <= max;
  }

  private async sendToken(accountId: string, to: string, kind: Action, targetEmail?: string) {
    const token = 'act_' + randomBytes(32).toString('base64url');
    const url = actionUrl(kind, token);
    const title = kind === 'reset' ? 'HHK - Đặt lại mật khẩu'
      : kind === 'verify' ? 'HHK - Xác minh email' : 'HHK - Xác minh email mới';
    await txn(this.pool, async c => {
      await c.query('SELECT id FROM app_accounts WHERE id=$1 FOR UPDATE', [accountId]);
      await c.query(
        'UPDATE account_action_tokens SET used_at=now() WHERE account_id=$1 AND kind=$2 AND used_at IS NULL',
        [accountId,kind]
      );
      await c.query(
        `INSERT INTO account_action_tokens(id,account_id,kind,token_hash,target_email,expires_at)
         VALUES ($1,$2,$3,$4,$5,now()+interval '20 minutes')`,
        [randomUUID(),accountId,kind,hash(token),targetEmail ?? null]
      );
    });
    await this.mailer(to,title,url);
  }

  async requestVerification(body: unknown, ip: string) {
    const p=body as Record<string,unknown>|null;
    const email=normalizeEmail(p?.email);
    const allowed = await this.throttle('email-verify',email,3);
    const allowedIp = await this.throttle('email-verify-ip',ip,15);
    if (!allowed || !allowedIp) return {requested:true};
    const result = await this.pool.query<{id:string; email_verified_at:Date|null}>(
      'SELECT id,email_verified_at FROM app_accounts WHERE email=$1',[email]);
    const account = result.rows[0];
    if (account && !account.email_verified_at) await this.sendToken(account.id,email,'verify');
    return {requested:true};
  }

  async verifyEmail(body: unknown) {
    return this.consumeAction(body,'verify');
  }

  async forgot(body: unknown, ip: string) {
    const p=body as Record<string,unknown>|null;
    const email=normalizeEmail(p?.email);
    const allowed = await this.throttle('forgot',email,3);
    const allowedIp = await this.throttle('forgot-ip',ip,15);
    if (!allowed || !allowedIp) return {requested:true};
    const found=await this.pool.query<{id:string}>(
      'SELECT id FROM app_accounts WHERE email=$1 AND email_verified_at IS NOT NULL',[email]);
    if (found.rows[0]) await this.sendToken(found.rows[0].id,email,'reset');
    return {requested:true};
  }

  private async consumeAction(body: unknown, expected: 'verify'|'email_change') {
    const p=body as Record<string,unknown>|null;
    const raw=p?.token;
    if (typeof raw !== 'string' || !tokenPattern.test(raw)) {
      throw new ApiFault(400,'INVALID_ACTION_TOKEN');
    }
    return txn(this.pool, async c => {
      const owner=await c.query<{account_id:string}>(
        'SELECT account_id FROM account_action_tokens WHERE token_hash=$1',[hash(raw)]);
      if (!owner.rows[0]) throw new ApiFault(400,'INVALID_ACTION_TOKEN');
      await c.query('SELECT id FROM app_accounts WHERE id=$1 FOR UPDATE',[owner.rows[0].account_id]);
      const found=await c.query<ActionRow>(
        `SELECT id,account_id,kind,target_email,expires_at,used_at
           FROM account_action_tokens WHERE token_hash=$1 FOR UPDATE`,[hash(raw)]);
      const item=found.rows[0];
      if (!item || item.kind !== expected || item.used_at ||
          item.expires_at.getTime() <= Date.now()) throw new ApiFault(400,'INVALID_ACTION_TOKEN');
      if (expected === 'email_change') {
        if (!item.target_email) throw new ApiFault(400,'INVALID_ACTION_TOKEN');
        const existing=await c.query('SELECT id FROM app_accounts WHERE email=$1', [item.target_email]);
        if (existing.rows.length) throw new ApiFault(409,'ACCOUNT_EXISTS');
        await c.query('UPDATE app_accounts SET email=$2,email_verified_at=now() WHERE id=$1',
          [item.account_id,item.target_email]);
      } else {
        await c.query('UPDATE app_accounts SET email_verified_at=now() WHERE id=$1',[item.account_id]);
      }
      await c.query('UPDATE account_action_tokens SET used_at=now() WHERE id=$1',[item.id]);
      await c.query(`INSERT INTO account_security_audit(account_id,event)
        VALUES($1,$2)`,[item.account_id,expected]);
      return {verified:true};
    });
  }

  async reset(body: unknown) {
    const p=body as Record<string,unknown>|null;
    const raw=p?.token;
    if (typeof raw !== 'string' || !tokenPattern.test(raw)) throw new ApiFault(400,'INVALID_ACTION_TOKEN');
    if (!validPassword(p?.newPassword)) throw new ApiFault(400,'WEAK_PASSWORD');
    const salt=randomBytes(16);
    const passwordHash=await derive(p.newPassword,salt,64) as Buffer;
    return txn(this.pool,async c=>{
      const owner=await c.query<{account_id:string}>(
        'SELECT account_id FROM account_action_tokens WHERE token_hash=$1',[hash(raw)]);
      if (!owner.rows[0]) throw new ApiFault(400,'INVALID_ACTION_TOKEN');
      const row=await c.query<{email_verified_at:Date|null}>(
        'SELECT email_verified_at FROM app_accounts WHERE id=$1 FOR UPDATE',[owner.rows[0].account_id]);
      const result=await c.query<ActionRow>(
        'SELECT id,account_id,kind,target_email,expires_at,used_at FROM account_action_tokens WHERE token_hash=$1 FOR UPDATE',
        [hash(raw)]);
      const action=result.rows[0];
      if (!action || action.kind!=='reset' || action.used_at ||
          action.expires_at.getTime()<=Date.now() || !row.rows[0]?.email_verified_at) {
        throw new ApiFault(400,'INVALID_ACTION_TOKEN');
      }
      await c.query(
        `UPDATE app_accounts SET password_salt=$2,password_hash=$3,
         failed_logins=0,locked_until=NULL WHERE id=$1`,
        [action.account_id,salt,passwordHash]);
      await c.query('UPDATE account_sessions SET revoked_at=now() WHERE account_id=$1 AND revoked_at IS NULL',
        [action.account_id]);
      await c.query('UPDATE account_action_tokens SET used_at=now() WHERE account_id=$1 AND used_at IS NULL',
        [action.account_id]);
      await c.query('INSERT INTO account_security_audit(account_id,event) VALUES($1,$2)',
        [action.account_id,'password_reset']);
      return {reset:true};
    });
  }

  async changePassword(accountId: string, header: string|undefined, body: unknown) {
    const p=body as Record<string,unknown>|null;
    if (typeof p?.currentPassword!=='string' || p.currentPassword.length>256) {
      throw new ApiFault(400,'INVALID_CREDENTIALS');
    }
    if (!validPassword(p?.newPassword)) throw new ApiFault(400,'WEAK_PASSWORD');
    const token=bearer(header);
    const salt=randomBytes(16);
    const nextHash=await derive(p.newPassword,salt,64) as Buffer;
    const response=await txn(this.pool,async c=>{
      const account=await c.query<{
        password_salt:Buffer;password_hash:Buffer;failed_logins:number;locked_until:Date|null
      }>(
        `SELECT password_salt,password_hash,failed_logins,locked_until
           FROM app_accounts WHERE id=$1 FOR UPDATE`,[accountId]);
      const a=account.rows[0];
      const active=await c.query<{id:string}>(
        `SELECT id FROM account_sessions WHERE account_id=$1 AND token_hash=$2
           AND revoked_at IS NULL AND (expires_at IS NULL OR expires_at>now()) FOR UPDATE`,
        [accountId,hash(token)]);
      if (!a || !active.rows[0]) throw new ApiFault(401,'UNAUTHORIZED');
      if (a.locked_until && a.locked_until.getTime()>Date.now()) throw new ApiFault(403,'ACCOUNT_LOCKED');
      const prior=await derive(p.currentPassword,a.password_salt,64) as Buffer;
      if (!timingSafeEqual(prior,a.password_hash)) {
        const n=a.failed_logins+1;
        await c.query('UPDATE app_accounts SET failed_logins=$2,locked_until=$3 WHERE id=$1',
          [accountId,n>=5?0:n,n>=5?new Date(Date.now()+15*60000):null]);
        await c.query('INSERT INTO account_security_audit(account_id,event) VALUES($1,$2)',
          [accountId,'password_change_rejected']);
        return {error:'INVALID_CREDENTIALS'};
      }
      const duplicate=await derive(p.newPassword,a.password_salt,64) as Buffer;
      if (timingSafeEqual(duplicate,a.password_hash)) return {error:'PASSWORD_UNCHANGED'};
      const sessionToken='sess_'+randomBytes(32).toString('base64url');
      await c.query(
        'UPDATE app_accounts SET password_salt=$2,password_hash=$3,failed_logins=0,locked_until=NULL WHERE id=$1',
        [accountId,salt,nextHash]);
      await c.query(
        'UPDATE account_sessions SET revoked_at=now() WHERE account_id=$1 AND id<>$2 AND revoked_at IS NULL',
        [accountId,active.rows[0].id]);
      await c.query(
        'UPDATE account_sessions SET token_hash=$2,last_used_at=now() WHERE id=$1',
        [active.rows[0].id,hash(sessionToken)]);
      await c.query('UPDATE account_action_tokens SET used_at=now() WHERE account_id=$1 AND used_at IS NULL',
        [accountId]);
      await c.query('INSERT INTO account_security_audit(account_id,event) VALUES($1,$2)',
        [accountId,'password_changed']);
      return {sessionToken};
    });
    if ('error' in response) throw new ApiFault( response.error === 'PASSWORD_UNCHANGED'?400:401,
      response.error ?? 'INVALID_CREDENTIALS');
    return response;
  }

  async sessions(accountId:string,header:string|undefined) {
    const token=bearer(header);
    const result=await this.pool.query<{
      id:string;device_label:string;created_at:Date;last_used_at:Date
      }>(
      `SELECT id,device_label,created_at,last_used_at
         FROM account_sessions WHERE account_id=$1 AND revoked_at IS NULL
         AND (expires_at IS NULL OR expires_at>now())
         ORDER BY last_used_at DESC`,[accountId]);
    const current=await this.pool.query<{id:string}>(
      'SELECT id FROM account_sessions WHERE account_id=$1 AND token_hash=$2 AND revoked_at IS NULL',
      [accountId,hash(token)]);
    if (!current.rows[0]) throw new ApiFault(401,'UNAUTHORIZED');
    return {sessions:result.rows.map(r=>({
      id:r.id,label:r.device_label,createdAt:r.created_at,
      lastUsedAt:r.last_used_at,current:r.id===current.rows[0].id
    }))};
  }

  async revokeSession(accountId:string,header:string|undefined,body:unknown) {
    const p=body as Record<string,unknown>|null;
    if (typeof p?.sessionId!=='string' || !uuidPattern.test(p.sessionId)) {
      throw new ApiFault(400,'INVALID_SESSION');
    }
    const token=bearer(header);
    const own=await this.pool.query<{id:string}>(
      'SELECT id FROM account_sessions WHERE account_id=$1 AND token_hash=$2 AND revoked_at IS NULL',
      [accountId,hash(token)]);
    if (!own.rows[0]) throw new ApiFault(401,'UNAUTHORIZED');
    if (p.sessionId===own.rows[0].id) throw new ApiFault(400,'CURRENT_SESSION');
    const result=await this.pool.query(
      'UPDATE account_sessions SET revoked_at=now() WHERE id=$1 AND account_id=$2 AND revoked_at IS NULL',
      [p.sessionId,accountId]);
    if (!result.rowCount) throw new ApiFault(404,'SESSION_NOT_FOUND');
    return {revoked:true};
  }

  async logoutAll(accountId:string) {
    await this.pool.query(
      'UPDATE account_sessions SET revoked_at=now() WHERE account_id=$1 AND revoked_at IS NULL',[accountId]);
    return {loggedOut:true};
  }

  async requestEmailChange(accountId:string,body:unknown) {
    const p=body as Record<string,unknown>|null;
    const target=normalizeEmail(p?.newEmail);
    if (typeof p?.currentPassword!=='string') throw new ApiFault(401,'INVALID_CREDENTIALS');
    const result=await this.pool.query<{email:string;password_hash:Buffer;password_salt:Buffer}>(
      'SELECT email,password_hash,password_salt FROM app_accounts WHERE id=$1',[accountId]);
    const row=result.rows[0];
    if (!row) throw new ApiFault(401,'UNAUTHORIZED');
    if (row.email===target) throw new ApiFault(400,'EMAIL_UNCHANGED');
    const derived=await derive(p.currentPassword,row.password_salt,64) as Buffer;
    if (!timingSafeEqual(derived,row.password_hash)) throw new ApiFault(401,'INVALID_CREDENTIALS');
    const clash=await this.pool.query('SELECT id FROM app_accounts WHERE email=$1',[target]);
    if (clash.rows.length) throw new ApiFault(409,'ACCOUNT_EXISTS');
    if (!(await this.throttle('email-change',accountId,3))) throw new ApiFault(429,'RATE_LIMITED');
    await this.sendToken(accountId,target,'email_change',target);
    return {requested:true};
  }

  async confirmEmailChange(body:unknown) { return this.consumeAction(body,'email_change'); }
}

