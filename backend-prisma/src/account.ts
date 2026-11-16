import {
  createHash, randomBytes, randomUUID, scrypt, timingSafeEqual
} from 'node:crypto';
import { promisify } from 'node:util';
import type { Pool, PoolClient } from 'pg';
import { ApiFault } from './license.js';

const derive = promisify(scrypt);
const emailPattern = /^[^\s@]{1,64}@[^\s@.]{1,190}\.[^\s@.]{2,24}$/;
const sessionPattern = /^sess_[A-Za-z0-9_-]{43}$/;
const digest = (value: string) => createHash('sha256').update(value).digest();

export function normalizeEmail(email: unknown): string {
  if (typeof email !== 'string') throw new ApiFault(400, 'INVALID_EMAIL');
  const normalized = email.trim().toLowerCase();
  if (normalized.length > 254 || !emailPattern.test(normalized)) {
    throw new ApiFault(400, 'INVALID_EMAIL');
  }
  return normalized;
}

function validPassword(p: unknown): p is string {
  return typeof p === 'string' && p.length >= 12 &&
    Buffer.byteLength(p, 'utf8') <= 256;
}

type LoginRow = {
  id: string;
  email: string;
  password_salt: Buffer;
  password_hash: Buffer;
  failed_logins: number;
  locked_until: Date | null;
  email_verified_at: Date | null;
};
export type AccountIdentity = { id: string; email: string; emailVerified: boolean };

async function transaction<T>(pool: Pool, fn: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export class AccountService {
  constructor(private readonly pool: Pool) {}

  async register(body: unknown) {
    const p = body as Record<string, unknown> | null;
    const email = normalizeEmail(p?.email);
    if (!validPassword(p?.password)) throw new ApiFault(400, 'WEAK_PASSWORD');
    const salt = randomBytes(16);
    const hash = await derive(p.password, salt, 64) as Buffer;
    const id = randomUUID();
    try {
      await this.pool.query(
        'INSERT INTO app_accounts(id,email,password_salt,password_hash) VALUES($1,$2,$3,$4)',
        [id, email, salt, hash]
      );
    } catch (e) {
      if (typeof e === 'object' && e !== null && 'code' in e &&
          (e as {code?:string}).code === '23505') {
        throw new ApiFault(409, 'ACCOUNT_EXISTS');
      }
      throw e;
    }
    return {account: {id, email}};
  }

  async login(body: unknown) {
    const p = body as Record<string, unknown> | null;
    const email = normalizeEmail(p?.email);
    if (typeof p?.password !== 'string' || p.password.length > 256) {
      throw new ApiFault(401, 'INVALID_CREDENTIALS');
    }
    return transaction(this.pool, async client => {
      const result = await client.query<LoginRow>(
        'SELECT id,email,password_salt,password_hash,failed_logins,locked_until,email_verified_at FROM app_accounts WHERE email=$1 FOR UPDATE',
        [email]
      );
      const row = result.rows[0];
      // Do not distinguish unknown accounts from invalid passwords.
      if (!row) {
        await derive(p.password as string, Buffer.alloc(16), 64);
        throw new ApiFault(401, 'INVALID_CREDENTIALS');
      }
      if (row.locked_until && row.locked_until.getTime() > Date.now()) {
        throw new ApiFault(403, 'ACCOUNT_LOCKED');
      }
      const hash = await derive(p.password as string, row.password_salt, 64) as Buffer;
      if (!timingSafeEqual(hash, row.password_hash)) {
        const failures = row.failed_logins + 1;
        // Wrong credentials must persist before reporting 401.
        await client.query(
          'UPDATE app_accounts SET failed_logins=$2,locked_until=$3 WHERE id=$1',
          [row.id, failures >= 5 ? 0 : failures,
           failures >= 5 ? new Date(Date.now() + 15 * 60 * 1000) : null]
        );
        return {error: true as const, account: null, sessionToken: null};
      }
      await client.query(
        'UPDATE app_accounts SET failed_logins=0,locked_until=NULL WHERE id=$1',
        [row.id]
      );
      const sessionToken = 'sess_' + randomBytes(32).toString('base64url');
      // Persist until user logs out or a server-side security revocation.
      // The mobile/Web client stores this only in its secure session vault.
      const label = typeof p.deviceLabel === 'string'
        ? p.deviceLabel.trim().slice(0, 80) : 'Thiết bị đăng nhập';
      await client.query(
        'INSERT INTO account_sessions(id,account_id,token_hash,expires_at,device_label) VALUES ($1,$2,$3,NULL,$4)',
        [randomUUID(), row.id, digest(sessionToken), label]
      );
      return {error: false as const, account: {id: row.id, email: row.email,
        emailVerified: row.email_verified_at !== null}, sessionToken};
    }).then(result => {
      if (result.error) throw new ApiFault(401, 'INVALID_CREDENTIALS');
      return result;
    });
  }

  async authenticate(header: string | undefined): Promise<AccountIdentity> {
    const token = header?.startsWith('Bearer ') ? header.substring(7) : '';
    if (!sessionPattern.test(token)) throw new ApiFault(401, 'UNAUTHORIZED');
    const result = await this.pool.query<AccountIdentity>(
      'SELECT a.id,a.email,(a.email_verified_at IS NOT NULL) AS "emailVerified" FROM account_sessions s JOIN app_accounts a ON a.id=s.account_id WHERE s.token_hash=$1 AND s.revoked_at IS NULL AND (s.expires_at IS NULL OR s.expires_at>now())',
      [digest(token)]
    );
    if (!result.rows[0]) throw new ApiFault(401, 'UNAUTHORIZED');
    // Throttle the last-used write to avoid a write for every read-only request.
    await this.pool.query(
      "UPDATE account_sessions SET last_used_at=now() WHERE token_hash=$1 AND last_used_at < now() - interval '5 minutes'",
      [digest(token)]
    );
    return result.rows[0];
  }

  async logout(header: string | undefined, accountId: string) {
    const token = header?.startsWith('Bearer ') ? header.substring(7) : '';
    if (!sessionPattern.test(token)) throw new ApiFault(401, 'UNAUTHORIZED');
    await this.pool.query(
      'UPDATE account_sessions SET revoked_at=now() WHERE account_id=$1 AND token_hash=$2 AND revoked_at IS NULL',
      [accountId, digest(token)]
    );
    return {loggedOut: true};
  }

  async keys(accountId: string) {
    const result = await this.pool.query<{
      id: string; status: string; grades: number[];
      valid_until: Date | null; max_devices: number; active_devices: string;
    }>(
      `SELECT l.id,l.status,l.entitled_grades AS grades,l.valid_until,l.max_devices,
       count(d.id) FILTER (WHERE d.active) AS active_devices
       FROM licenses l LEFT JOIN device_activations d ON d.license_id=l.id
       WHERE l.account_id=$1
       GROUP BY l.id ORDER BY l.issued_at DESC`,
      [accountId]
    );
    return {keys: result.rows.map(row => ({
      id: row.id, status: row.status, grades: row.grades,
      validUntil: row.valid_until, maxDevices: row.max_devices,
      activeDevices: Number(row.active_devices)
    }))};
  }

  async linkKey(accountId: string, body: unknown) {
    const p = body as Record<string, unknown> | null;
    if (typeof p?.licenseKey !== 'string' ||
        !/^lic_[A-Za-z0-9_-]{32}$/.test(p.licenseKey)) {
      throw new ApiFault(400, 'INVALID_LICENSE_KEY');
    }
    return transaction(this.pool, async client => {
      const result = await client.query<{id: string; account_id: string|null; status: string}>(
        'SELECT id,account_id,status FROM licenses WHERE license_hash=$1 FOR UPDATE',
        [digest(p.licenseKey as string)]
      );
      const row = result.rows[0];
      if (!row) throw new ApiFault(404, 'LICENSE_NOT_FOUND');
      if (row.account_id && row.account_id !== accountId) {
        throw new ApiFault(409, 'KEY_ALREADY_LINKED');
      }
      if (row.status === 'revoked' || row.status === 'expired') {
        throw new ApiFault(403, 'LICENSE_INACTIVE');
      }
      if (!row.account_id) {
        await client.query('UPDATE licenses SET account_id=$1 WHERE id=$2', [accountId, row.id]);
      }
      return {licenseId: row.id, linked: true};
    });
  }
}
